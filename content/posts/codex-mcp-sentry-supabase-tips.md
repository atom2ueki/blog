+++
title = 'Codex MCP Tips: Sentry and Supabase Setup'
date = 2026-03-11T18:05:00+08:00
draft = false
pin = true
author = 'Tony Li'
keywords = ['codex', 'mcp', 'sentry', 'supabase', 'oauth']
cover = '/images/posts/codex-mcp-sentry-supabase-tips/cover.png'
canonicalURL = 'https://blog.atom2ueki.com/posts/codex-mcp-sentry-supabase-tips/'
summary = 'How to set up Sentry MCP and Supabase MCP in Codex with OAuth, and how to match the plugin-style experience from Claude Code.'
lastmod = 2026-03-11T21:32:00+08:00
+++

![Codex MCP Tips cover image with Sentry and Supabase setup](/images/posts/codex-mcp-sentry-supabase-tips/cover.png)

If you are coming from Claude Code plugins, Codex can feel "lower level" at first.

The good news: you can get a very similar experience by wiring the same remote MCP servers directly in Codex.

## Why it feels different

Claude Code plugins are packaged integrations.

Codex exposes MCP directly, so you configure servers yourself:

- add server
- login with OAuth
- use tools

Same MCP server, different UX.

## One-time OAuth support in Codex

For remote OAuth MCP servers, make sure `rmcp_client` is enabled.

In `~/.codex/config.toml`:

```toml
[features]
rmcp_client = true
```

Then restart Codex.

## Install Sentry MCP (Cloud)

```bash
codex mcp add sentry --url "https://mcp.sentry.dev/mcp"
codex mcp login sentry
```

Optional experimental endpoint used by Sentry's `.mcp.json`:

```bash
codex mcp add sentry --url "https://mcp.sentry.dev/mcp/sentry/mcp-server?experimental=1"
```

## Install Supabase MCP (Cloud)

### A) Full power (closest to Claude plugin "manage everything")

```bash
codex mcp add supabase --url "https://mcp.supabase.com/mcp"
codex mcp login supabase
```

### B) Safer scoped mode (project + read-only)

```bash
codex mcp add supabase --url "https://mcp.supabase.com/mcp?project_ref=<YOUR_PROJECT_REF>&read_only=true"
codex mcp login supabase
```

If you want write operations, remove `read_only=true`.

If you want account-level and multi-project tools, do not scope by `project_ref`.

## Verify setup

```bash
codex mcp list
codex mcp get sentry
codex mcp get supabase
```

## Quick parity checklist (Claude Code -> Codex)

1. Use the same MCP endpoint URL.
2. Enable OAuth support (`rmcp_client`).
3. Run `codex mcp login <name>`.
4. Keep one server per integration (`sentry`, `supabase`) for clean mental model.

## References

- Sentry MCP: <https://github.com/getsentry/sentry-mcp>
- Supabase MCP: <https://github.com/supabase-community/supabase-mcp>
- Supabase MCP docs: <https://supabase.com/docs/guides/getting-started/mcp>
- Codex MCP docs: <https://platform.openai.com/docs/docs-mcp>
- OpenAI Docs MCP page: <https://platform.openai.com/docs/docs-mcp>
- OpenAI MCP integration guide: <https://platform.openai.com/docs/mcp>
