+++
title = 'JetPack 7.2.1 Dies at Exit Status 100 on the Orin Nano'
date = 2026-08-29T16:40:00+08:00
draft = false
author = 'Tony Li'
keywords = ['jetpack', 'jetson', 'orin nano', 'nvidia', 'l4t', 'bootloader', 'subiquity', 'sdk manager']
summary = 'A missing glob in a dpkg maintainer script aborts the whole JetPack 7.2 install on a P3767-0005. The real error hides in the journal. Here is the root cause, the patch, and the half nobody mentions: finishing the thirty late-commands subiquity never ran.'
canonicalURL = 'https://blog.atom2ueki.com/posts/jetpack-72-orin-nano-exit-100/'
pin = false
lastmod = 2026-08-29T16:42:55+08:00
+++

If you've booted the JetPack 7.2 / 7.2.1 ISO installer on a Jetson Orin Nano Developer Kit and watched it collapse near the end with:

```
subiquity/Late/run/command_35: curtin in-target -- /bin/bash -c "unset SNAP; DEBIAN_FRONTEND=noninteractive
  apt-get install --reinstall -y --no-install-recommends nvidia-l4t-bootloader"
  returned non-zero exit status 100
An error occurred. Press enter to start a shell
```

…this post is for you. The failure is deterministic on affected boards. Retrying the USB stick will never work. Here's the actual cause and two ways out.

## The error you see is not the error you have

Exit status 100 is apt's generic failure code. The installer log records only that number; the real message goes to the journal. From the crash shell:

```bash
journalctl --no-pager | grep -B5 -A40 nvidia-l4t-bootloader | tail -60
```

On my board this produced the line that explains everything:

```
ERROR. 3767--0005--1--jetson-orin-nx-devkit-16gb- does not match any known boards.
dpkg: error processing package nvidia-l4t-bootloader (--configure):
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

Read that board name carefully. My hardware is a **P3767-0005 — the Orin Nano 8GB developer kit module**. The numeric part is correct. The human-readable suffix says *Orin NX 16GB devkit*. The ISO tagged an Orin Nano with an Orin NX name.

Nearby in the log, possibly the origin:

```
invalid VPD tag 0x00 (size 0) at offset 0; assume missing optional EEPROM
```

## Root cause: a hardcoded glob table

Jetson ships bootloader firmware as a Debian package, and the payload selection happens in a shell `case` statement inside the maintainer script. Look at `select_3767_payload` in `/var/lib/dpkg/info/nvidia-l4t-bootloader.postinst`:

```sh
case "${compat_spec}" in
    *jetson-orin-nano-devkit-)
        capsule_payload="TEGRA_BL_3767.Cap" ;;
    *jetson-orin-nanoe8gb-devkit-)
        capsule_payload="TEGRA_BL_3767_nanoe8gb.Cap" ;;
    *jetson-orin-nano-devkit-super- | *jetson-orin-nano-devkit-super-maxn-)
        capsule_payload="TEGRA_BL_3767_super.Cap" ;;
    *jetson-orin-nanoe8gb-devkit-super-)
        capsule_payload="TEGRA_BL_3767_nanoe8gb_super.Cap" ;;
    *)
        echo "ERROR. ${compat_spec} does not match any known boards."
        exit 1 ;;
esac
```

There is no glob for `jetson-orin-nx-devkit-16gb` — the exact string the ISO's own board detection writes into the spec. The package cannot recognise a name its own installer produced. `exit 1` → apt returns 100 → subiquity aborts the entire install.

This is self-inconsistency inside one image. It is not a bad download, not a corrupt USB stick, and not a wrong ISO — there is only one unified ISO for all boards.

## Before patching: check whether you're about to write firmware

The selected `capsule_payload` isn't cosmetic. It feeds two real writes:

```sh
nv_bootloader_capsule_updater.sh -q "${payload_dir}/${capsule_payload}"
yes N | fwupdtool install-blob "${payload_dir}/${capsule_payload}" "${device_id}"
```

Writing the wrong capsule to QSPI is the one way to actually brick the board, so verify the guard that sits between selection and write:

```sh
# if current_pkg_ver_converted <= current_qspi_ver: do not trigger, else trigger a capsule update.
if [ $((current_pkg_ver_converted)) -le $((current_qspi_ver)) ]; then
    echo "INFO. No need to trigger capsule update."
    return 0
fi
```

If the ISO already updated your QSPI on an earlier pass, versions match and no capsule is written at all. Mine reported:

```
INFO. Current QSPI version: 2556417, Current package version: 2556417,
INFO. No need to trigger capsule update.
```

Also confirm the capsule files exist and which one your board maps to:

```bash
find / -name "TEGRA_BL_3767*.Cap" 2>/dev/null
# /opt/ota_package/t23x/TEGRA_BL_3767_super.Cap
# /opt/ota_package/t23x/TEGRA_BL_3767_nanoe8gb_super.Cap
# /opt/ota_package/t23x/TEGRA_BL_3767.Cap
# /opt/ota_package/t23x/TEGRA_BL_3767_nanoe8gb.Cap
```

`TEGRA_BL_3767_super.Cap` is correct for a P3767-0005 — 7.2.1 flashes the Orin Nano Developer Kit with Super Mode configuration by default. Post-install, MAXN showing up in `nvpmodel` confirmed the mapping was right.

## Set up SSH first

Do this **before** anything else. The crash shell has no scrollback and no paste, and you will be typing long commands. `ssh.socket` is already present in the installer image; the link just isn't managed:

```bash
mkdir -p /run/systemd/network
printf '[Match]\nName=enP8p1s0\n[Network]\nDHCP=yes\n' > /run/systemd/network/10-eth.network
networkctl reload
passwd
ip -4 a show enP8p1s0
systemctl start ssh.socket
```

Then `ssh root@<address>` from your laptop. If you get `PTY allocation request failed` and no prompt, the shell is still working — reconnect with `ssh -tt`.

One warning: I ran `ssh-keygen -A` at one point and the machine rebooted moments later, restarting the installer from scratch and discarding everything set up in the live environment. Whether that was cause or coincidence I can't say, but the lesson holds — sshd will generate host keys on its own, so don't reach for it, and assume anything outside `/target` is lost on reboot.

## The patch

```bash
chroot /target /bin/bash
cp /var/lib/dpkg/info/nvidia-l4t-bootloader.postinst{,.bak}
sed -i 's/\*jetson-orin-nano-devkit-super-maxn-)/*jetson-orin-nano-devkit-super-maxn- | *jetson-orin-nx-devkit-16gb-)/' \
  /var/lib/dpkg/info/nvidia-l4t-bootloader.postinst
bash -n /var/lib/dpkg/info/nvidia-l4t-bootloader.postinst && echo SYNTAX_OK
rm -f /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall
dpkg --configure -a
```

Note that editing `COMPATIBLE_SPEC` in `/etc/nv_boot_control.conf` does **not** work — the postinst regenerates that file from the live device tree on every run. The lookup table is the only thing worth changing.

If the bind mounts were torn down when the installer failed, restore them from outside the chroot first:

```bash
mount --bind /dev /target/dev
mount --bind /dev/pts /target/dev/pts
mount -t proc proc /target/proc
mount -t sysfs sys /target/sys
```

Verify with `dpkg -l nvidia-l4t-bootloader` (you want `ii`) and `dpkg --audit` (you want silence).

## The half nobody mentions: finish the aborted late-commands

Configuring the package does not resume the install. Subiquity already gave up, and roughly thirty late-commands never ran — including the block that sets up first-boot user creation. Skip this and you get a system that boots to nothing.

The live installer has PyYAML, so generate the remainder rather than transcribing it:

```bash
python3 - > /tmp/rest.sh <<'PYEOF'
import yaml, sys
d = yaml.safe_load(open('/autoinstall.yaml'))
c = d.get('late-commands') or d['autoinstall']['late-commands']
start = next(i for i,x in enumerate(c)
             if 'nvidia-l4t-bootloader' in (x if isinstance(x,str) else ' '.join(x))
             and 'apt-get install' in (x if isinstance(x,str) else ' '.join(x))) + 1
print('#!/bin/bash')
for x in c[start:]:
    s = x if isinstance(x,str) else ' '.join(x)
    if 'logger -p info' in s: continue
    print(s.replace('curtin in-target --','chroot /target'))
sys.stderr.write('resuming at %d of %d\n' % (start, len(c)))
PYEOF
cat /tmp/rest.sh          # read it before running it
bash -x /tmp/rest.sh 2>&1 | tee /tmp/rest.log
```

Two translation rules matter: `curtin in-target --` becomes `chroot /target`, and `logger -p info` lines are progress bars you can drop. Commands *without* the `curtin` prefix — the `efibootmgr` calls, `touch /run/casper-no-prompt` — run on the live system and must not be chrooted.

Mine resumed at index 36 of 65. Expect harmless noise: `multipathd.service does not exist`, `|| true` guards firing, and so on.

### One gotcha that will bite you

The oem-config block starts with `touch /etc/nv/nvautoconfig`, and on my target `/etc/nv` didn't exist:

```
touch: cannot touch '/etc/nv/nvautoconfig': No such file or directory
```

That file is the flag the first-boot wizard checks. Without it you boot into nothing. Fix:

```bash
chroot /target /bin/bash -c 'mkdir -p /etc/nv && touch /etc/nv/nvautoconfig'
```

Verify before shutting down:

```bash
ls -l /target/etc/systemd/system/default.target   # → nv-oobe.target
ls -l /target/etc/nv/nvautoconfig
grep -E "EXTRA_GROUPS|ADD_EXTRA_GROUPS" /target/etc/adduser.conf
```

Then unmount, `sync`, `poweroff`, pull the stick, power on.

A note on the first boot: mine sat at a bare dash in the top-left corner for several minutes and looked dead. It wasn't — it answered ping, and the OOBE wizard appeared once the display finished initialising. Before assuming failure, ping it.

## Afterwards: hold the package

The patch lives in an installed package's maintainer script. Any future upgrade of `nvidia-l4t-bootloader` restores the broken table and fails identically.

```bash
sudo apt-mark hold nvidia-l4t-bootloader
nvbootctrl dump-slots-info
```

## The path I'd actually recommend

Everything above is the fallback for people without an x86 machine. If you have one, **flash from a host with SDK Manager instead**. Host flashing selects the bootloader payload from the flash configuration on the host, keyed by board ID, so the broken lookup table never executes. It's what NVIDIA support recommends for this failure, and it avoids both the patch and the manual late-commands.

- Native Ubuntu 22.04 x86_64 (not a VM — USB passthrough breaks recovery mode)
- USB-C to the Jetson's recovery port; jumper FC_REC (pin 9) to GND (pin 10), then power on
- Target: **Jetson Orin Nano [8GB developer kit version] (P3767-0005)** — the wrong module selection gives you a mismatched BSP
- Flash Jetson Linux only first, boot it, then `sudo apt install nvidia-jetpack` over the network

## Closing thought

The interesting part of this bug isn't the missing glob — it's the architecture that let one missing glob take down an entire OS install. Firmware selection lives in a dpkg postinst, so a shell string match decides whether your board boots. The installer's late-commands aren't resumable, so one unordered failure aborts everything with no way to fix and continue. And the actual error went to the journal while only the exit code reached the screen.

The desktop world solved this with A/B slots and atomic rollback. Jetson has `nvbootctrl` slots, but the update path still runs through apt, which was never designed to fail safely on firmware.

If you hit this on a P3767-0005, post your board part number and the exact `COMPATIBLE_SPEC` string to the NVIDIA developer forums. Multiple confirmed reports of the same wrong board name on the same module are much harder to dismiss as a one-off carrier quirk.
