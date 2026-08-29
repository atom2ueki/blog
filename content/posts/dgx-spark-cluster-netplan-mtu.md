+++
title = 'Clustering Two DGX Sparks: The Netplan File That Ships Broken'
date = 2026-08-29T16:03:31+08:00
draft = false
author = 'Tony Li'
keywords = ['dgx spark', 'gb10', 'netplan', 'nvidia', 'nccl', 'roce', 'mtu', 'cluster']
summary = 'Cluster Assistant failed on both DGX Sparks at once. The cause was a netplan file full of NUL bytes baked into the factory image, and the fix most people reach for will strand a headless machine. Plus the RoCE ports every recipe gets wrong and the jumbo-frame setting nobody turns on.'
canonicalURL = 'https://blog.atom2ueki.com/posts/dgx-spark-cluster-netplan-mtu/'
pin = false
lastmod = 2026-08-29T16:42:55+08:00
+++

NVIDIA Sync's Cluster Assistant is meant to make this boring: cable two DGX Sparks together over their ConnectX-7 ports, run the wizard, get a cluster. Instead it reported **"Network configuration failed"** on both nodes, at the same step, with no useful detail.

Two identical machines failing identically is actually a good sign. It means the problem shipped with them rather than something either box did.

It did. And three more things were waiting behind it, one of which roughly doubled the fabric throughput once fixed.

## 1. A netplan file full of NUL bytes

Run netplan by hand and you get the real error the wizard swallows:

```bash
$ sudo netplan generate
Error in network definition: Invalid YAML: control characters are not allowed
/etc/netplan/90-NM-2edf06d6-a4d8-4336-95d9-d76c293f806f.yaml
$ echo $?
78
```

Netplan parses *every* file in `/etc/netplan`. One unreadable file fails the whole set, so nothing that touches networking works.

And the file is not subtly malformed. It is empty in the worst possible way:

```bash
$ sudo head -c 32 /etc/netplan/90-NM-2edf06d6-*.yaml | od -c
0000000  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0
0000020  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0  \0
0000040
```

Not truncated, not corrupted in transit — allocated and never written.

The detail worth pausing on: **the UUID is the same on every unit I've seen** — `2edf06d6-a4d8-4336-95d9-d76c293f806f`, dated Sep 29 2025. This isn't a machine that went bad. It is in the image, which means every Spark has it, and it comes back after any factory reset or system recovery.

It is also safe to remove. The UUID appears in no `nmcli con show` output — it is an orphan stub that no NetworkManager connection references.

### Don't delete the glob

The advice you will find first is to delete all `90-NM*.yaml` files. **On a headless Spark that strands the machine.** Those files also back the Wi-Fi connection, which on a box with no monitor is your only way back in.

Remove exactly one file: the one that is both unparseable *and* unreferenced. Those two conditions are worth checking in code rather than by eye:

```bash
UUID="2edf06d6-a4d8-4336-95d9-d76c293f806f"
F="/etc/netplan/90-NM-${UUID}.yaml"

# Guard 1: never touch a file that parses as real netplan
if head -c 8 "$F" | grep -q 'network:'; then
  echo "[ABORT] starts with 'network:' - looks valid. Not touching it."
  exit 1
fi

# Guard 2: never touch a stub backing a live NetworkManager connection
if nmcli -g UUID con show 2>/dev/null | grep -qx "$UUID"; then
  echo "[ABORT] $UUID is a live NetworkManager connection. Not touching it."
  exit 1
fi

mkdir -p /root/netplan-broken
mv -v "$F" /root/netplan-broken/
netplan generate
```

Quarantine, don't delete. A `mv` is reversible at 3am; an `rm` isn't.

No reboot needed. `netplan generate` passes immediately and Cluster Assistant completes.

## 2. The published port names are the dead ones

With netplan fixed the cluster came up, and then multi-node NCCL jobs hung at init.

Every published DGX Spark serving recipe I checked pins the RoCE fabric to `rocep1s0f1` / `enp1s0f1np1`. On these units the **f1 ports are down**. The cabled pair is **f0**:

```bash
$ ip -br link show | grep -E 'enp1s0f|enP2p1s0f'
enp1s0f0np0     UP        <BROADCAST,MULTICAST,UP,LOWER_UP>
enp1s0f1np1     DOWN      <NO-CARRIER,BROADCAST,MULTICAST,UP>
enP2p1s0f0np0   UP        <BROADCAST,MULTICAST,UP,LOWER_UP>
enP2p1s0f1np1   DOWN      <NO-CARRIER,BROADCAST,MULTICAST,UP>
```

Check yours before copying anyone's `NCCL_IB_HCA`, including mine.

There is a second, less obvious part. The GB10's single QSFP port enumerates as **two virtual NICs**, each roughly 100 Gb over PCIe Gen5 x4. Naming only one HCA runs the link at half the port. List both:

```bash
NCCL_IB_HCA==rocep1s0f0,roceP2p1s0f0   # note '==' — NCCL's exact-match prefix
NCCL_SOCKET_IFNAME=enp1s0f0np0
```

The doubled `=` is not a typo. A single `=` is a prefix match and will grab interfaces you did not mean.

One more: leave `NCCL_IB_GID_AUTO=1` alone rather than pinning `NCCL_IB_GID_INDEX`. The resolver reads it per node from sysfs, and the index can drift after a reboot — a shared literal will eventually wedge NCCL at init on one node and not the other.

## 3. Nobody turns on jumbo frames

NVIDIA Sync configures the cluster links and leaves them at **MTU 1500**. The official playbook doesn't raise it either. On a 200 Gb fabric this is the single largest number left unclaimed.

Measured on this pair, 4-stream TCP:

| Link | MTU 1500 | MTU 9000 | Change |
|---|---|---|---|
| `enp1s0f0np0` | 63.9 Gb/s | 108 Gb/s | +69% |
| `enP2p1s0f0np0` | 38.5 Gb/s | 108 Gb/s | +181% |

Two details make this stick without risking the box.

**Write an overlay, not an edit.** Sync owns `99-nvidia-sync-cluster.yaml` and will overwrite it. A file named `99-zz-cx7-mtu.yaml` sorts after it, and netplan merges with the later file winning per key, so your setting survives Sync rewriting its own config:

```yaml
# /etc/netplan/99-zz-cx7-mtu.yaml
network:
  version: 2
  ethernets:
    enp1s0f0np0:
      mtu: 9000
    enP2p1s0f0np0:
      mtu: 9000
```

**Apply with `ip link`, not `netplan apply`.** Applying netplan reloads NetworkManager, which blips the Wi-Fi management link — the one you are SSH'd over. Setting the MTU directly changes nothing else:

```bash
sudo ip link set dev enp1s0f0np0 mtu 9000
sudo ip link set dev enP2p1s0f0np0 mtu 9000

# verify the path end to end — 8972 = 9000 - 20 (IP) - 8 (ICMP)
ping -M do -s 8972 10.100.224.2
```

Both ends must match. Mismatched MTUs do not error, they silently drop packets.

## 4. What the fabric actually does

With all of the above in place, measured on idle nodes:

| Test | Size | Result |
|---|---|---|
| iperf3 `-P 8`, per link | — | 111 Gb/s, 0 retransmits |
| NCCL all_gather | 16 GB | 23.9 GB/s busbw |
| NCCL all_reduce | 8 GB | 24.2 GB/s |
| NCCL sendrecv | 8 GB | 23.0 GB/s |

That is the ceiling for this hardware, not a shortfall. Community `ib_write_bw` reports land near 98 Gb/s per link, about 24.5 GB/s combined, so the pair is performing correctly rather than underperforming.

One widely repeated claim did not hold here. You will read that `NCCL_IB_MERGE_NICS=1` is required to exceed ~13.5 GB/s. NCCL 2.30.7 already used both NICs by default. The flag helped **all_gather only** — 21.8 to 23.9 GB/s, about +10% — and made no measurable difference to all_reduce (24.24 vs 24.23).

## Two more that will cost you an evening

**The NCCL playbook defaults to a dead interface.** NVIDIA's `nccl/assets/launch.sh` sets `MGMT_IFNAME=enP7s7`. On these nodes that interface is down — management is Wi-Fi (`wlP9s9`), because the boxes are headless. Bootstrap fails before any GPU work starts, so override it. Multi-node `mpirun` also needs passwordless SSH *between the nodes*, not just from your laptop to each of them.

**Docker doesn't survive an unclean reboot.** After a hard power cycle, `dockerd` failed every start with `error initializing buildkit: invalid database` — a corrupt BoltDB under `/var/lib/docker/buildkit/` — and systemd gave up after three retries. That directory is pure build cache and gets regenerated; images, containers and volumes live elsewhere. Move it aside and Docker starts.

The `Deleting nftables rules ... exit status 1` lines just above it in the log are benign noise, not the cause. They will send you down the wrong path if you let them.

## If you're doing this yourself

- Run `netplan generate` by hand before trusting any wizard's error message.
- Quarantine one file, never a glob — `90-NM*.yaml` includes your way back in.
- Confirm which CX-7 ports are actually cabled before copying anyone's NCCL config.
- Set MTU 9000 on both ends, via an overlay that sorts last, applied with `ip link`.
- Expect the netplan stub to return after a factory reset. It is in the image.

Measured on two DGX Sparks (GB10, DGX OS 7, Ubuntu 24.04) joined by a single direct ConnectX-7 cable. Interface names, UUIDs and IPs are from these units — check yours rather than pasting mine.
