+++
title = 'Why Websites Should Expose MCP to Agents'
date = 2026-03-12T10:57:00+08:00
draft = false
author = 'Tony Li'
keywords = ['ai', 'agents', 'mcp', 'webmcp', 'chrome-devtools-mcp', 'agent-browser']
summary = 'The long-term goal for browser agents is not better crawling alone, but better agent-facing interfaces: website-exposed capability, cleaner browser snapshots, multimodal fallback, and compiled tests.'
canonicalURL = 'https://blog.atom2ueki.com/posts/why-websites-should-expose-mcp-to-agents/'
+++

After exploring DOM-first control, visual grounding, and later computer-use systems, the biggest conclusion I arrived at was not about a single tool.

It was about interface design.

The central problem in browser agents is not only making the model smarter.

It is improving the quality of what the model consumes.

## Better crawling is only one layer of the solution

There is real value in making page representations smaller and more meaningful.

That is why D2Snap matters. It argues that DOM should not only be flattened or aggressively extracted. It should be downsampled in a way that preserves useful structure while reducing token cost.

That is a meaningful step forward. It is better than sending raw HTML, and better than throwing away too much context through naive simplification.

But I no longer think it is the end state.

I now see D2Snap as an important transitional idea. It proved that better representations matter. But newer agent-oriented browser interfaces suggest a stronger direction: instead of compressing raw browser output after the fact, provide a cleaner agent-facing interface from the start.

## The stronger idea is to expose capability directly

The more durable idea is this:

if a website can expose useful capability directly to an agent, the agent should not need to reconstruct everything from the UI.

That is why WebMCP is so interesting.

The WebMCP proposal and Google’s early preview make the direction explicit: websites can expose structured tools so agents can act with greater speed, reliability, and precision than raw DOM actuation alone.

I think this is the right long-term framing.

The future is not only helping agents crawl better. The future is making websites more agent-ready.

## Clean browser snapshots are already changing the middle layer

Even when a site does not expose capability directly, the next-best option is no longer necessarily raw DOM plus compression.

Tools like `agent-browser` show a cleaner pattern: expose a small, agent-oriented snapshot with stable references and readable text, so the model can work with useful page structure without reconstructing everything from noisy HTML.

That matters because it reduces the need for heavy DOM cleanup in the common case. The browser layer itself becomes more intentional about what the agent consumes.

This is why my current view is different from where I started. I still think D2Snap is important, but I now treat it as part of the evolution toward cleaner agent interfaces, not as the final shape of the stack.

## Where `chrome-devtools-mcp` fits

This is also where `chrome-devtools-mcp` becomes important, but for a different reason.

`chrome-devtools-mcp` is not mainly about exposing higher-level website capability. It is about strengthening the browser-control and inspection loop. According to the official repository, it gives agents access to live Chrome inspection, screenshots, console messages, network analysis, performance tooling, and reliable automation with built-in waiting for action results.

That matters because even when an agent still has to work through the browser directly, it should get a much better execution loop than blind click-and-guess automation.

## The stack that follows from this

I think of the modern stack in layers:

1. if the site exposes agent-ready capability, use it
2. if the agent must work through the browser, prefer clean agent-oriented snapshots with stable refs and readable state
3. if structure is insufficient, route to multimodal perception
4. once the flow is understood, compile it into fast Playwright tests

![Use the highest-quality interface available](/images/posts/agentic-e2e-public-series/agent-interface-stack.svg)

That sequence reflects the main lesson of the whole journey: reduce inference whenever the environment can expose something better than raw UI.

## The lesson that should still matter in a few years

The goal is not to make agents heroic crawlers.

The goal is to reduce how much crawling is necessary.

That principle should survive individual tools, model releases, and framework churn.

The strongest systems will be the ones that minimize guesswork whenever the environment can expose better interfaces than raw pages alone.

## References

- D2Snap paper: <https://arxiv.org/abs/2508.04412>
- D2Snap repository: <https://github.com/webfuse-com/D2Snap>
- Webfuse article on DOM downsampling: <https://www.webfuse.com/blog/dom-downsampling-for-llm-based-web-agents>
- WebMCP early preview from Chrome Developers: <https://developer.chrome.com/blog/webmcp-epp>
- WebMCP proposal repository: <https://github.com/webmachinelearning/webmcp>
- WebMCP draft spec: <https://webmachinelearning.github.io/webmcp>
- agent-browser repository: <https://github.com/vercel-labs/agent-browser>
- `chrome-devtools-mcp` repository: <https://github.com/ChromeDevTools/chrome-devtools-mcp>
- Playwright Test Agents: <https://playwright.dev/docs/test-agents>
