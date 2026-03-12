---
title: "The E2E Agent Stack I Would Build Today"
date: 2026-03-12T23:30:00+08:00
draft: true
author: "Tony Li"
summary: "The architecture I would build now for agentic E2E automation: DOM-first control, multimodal fallback, orchestration, and test generation."
tags:
  - ai
  - agents
  - playwright
  - testing
  - browser-automation
  - architecture
---

# The E2E Agent Stack I Would Build Today

After spending a lot of time exploring browser agents around mid-2025, my conclusion today is much less romantic and much more practical:

the best browser agent is not the final product.

The final product should be a system that uses agents to discover, diagnose, and formalize E2E coverage, then hands repeatable execution to a fast test runner.

That means the core goal is not:

“Can the agent operate a browser?”

The real goal is:

“Can the system convert uncertain UI exploration into reliable automated coverage?”

## The architecture in one sentence

If I were building this now, I would build:

a UI for configuring an E2E agent pipeline that uses `agent-browser` for structured browser control, multimodal models for screenshot-based analysis, an orchestrator built with LangChain/LangGraph-style routing, Playwright Test Agents to generate and heal tests, and an exploratory bug-finding layer for gaps not yet covered by authored scenarios.

That is the architecture I currently believe in.

## Why `agent-browser` is the right browser substrate

Right now, `agent-browser` feels closest to the shape I would want for a productized browser-agent runtime.

Why:

- it uses Playwright rather than being locked to Chrome-only automation
- it gives AI-friendly snapshots with refs
- it supports deterministic interactions
- it is designed for repeated agent workflows instead of one-off demos
- it benefits from Playwright's browser portability

This matters because browser-agent systems should not inherit unnecessary platform narrowness if they do not have to.

Chrome DevTools MCP is excellent for Chrome-specific inspection and debugging. But for a broader testing platform, I would rather start from a Playwright-native control layer unless I specifically need DevTools-only capabilities.

## Why multimodal fallback is non-optional

The cleanest mistake in browser-agent design is assuming one representation mode is enough.

It is not.

DOM and accessibility snapshots are excellent when:

- the UI is semantically well-formed
- elements are exposed properly
- structure matches visible intent
- the action target is programmatically addressable

They fail when:

- the critical clue is visual, not semantic
- the UI is canvas-heavy or custom-rendered
- overlays, transitions, or states are poorly represented
- the browser exposes too little to reconstruct the real blocker

That is exactly why multimodal analysis is now useful enough to be first-class.

Not because vision should replace browser structure.

Because it should rescue the cases structure cannot cover.

So the runtime should be:

- DOM-first
- vision-assisted
- orchestrated

not vision-only and not DOM-only.

## Why orchestration matters more than model choice

People often overfocus on which model is best.

My experience is that routing and delegation matter more than model branding.

The orchestrator should decide:

- whether the current state is structurally legible
- whether the DOM path is failing
- whether the issue is likely semantic, visual, timing-related, or environment-related
- whether to continue exploring
- whether to synthesize a Playwright test from the successful path

This is where I found early multi-agent systems promising but immature.

The right architecture is not just “many agents”. It is explicit role separation.

For example:

### Browser execution agent

Responsibilities:

- navigate
- snapshot
- click, type, extract
- produce structured step histories

### Vision analysis agent

Responsibilities:

- inspect screenshots
- explain blockers
- identify visually obvious affordances
- compare before/after screens

### Test authoring agent

Responsibilities:

- convert discovered flows into Playwright tests
- choose stable locators
- add meaningful assertions
- write maintainable fixtures

### Gap-finding agent

Responsibilities:

- explore uncovered paths
- search for probable bugs
- identify mismatch between expected and observed behavior
- produce reviewable reports

That is a better shape than asking one giant agent to do everything end to end.

## Why Playwright Test Agents change the game

One of the most important recent shifts is Playwright's own Test Agents workflow.

The planner, generator, and healer pattern is exactly the kind of bridge I wanted to see between:

- agentic exploration
- and classical automated testing

This matters because agents are powerful, but they are slow.

Playwright tests are fast.

So the right loop is:

1. agent explores
2. planner turns coverage ideas into scenarios
3. generator turns scenarios into Playwright tests
4. healer repairs breakage over time
5. CI runs fast deterministic tests, not full agent loops, on every change

That is how you make the economics work.

I do not want a team paying agent latency for every regression run if the path is already known.

## What the product should look like

If I turned this into a real tool, I would not ship it as “an autonomous browser agent”.

I would ship it as an E2E test workbench.

The UI would help a team configure:

- target environments
- auth/session setup
- browser substrate
- model routing rules
- vision fallback rules
- coverage goals
- export targets for Playwright tests

And then the product would expose four top-level workflows.

### 1. Explore a flow

Given a goal like “test signup with email verification”, the system should:

- open the site
- attempt the flow
- route between DOM and vision reasoning as needed
- record the successful path

### 2. Explain a blocker

If the flow fails, the system should not just stop. It should explain:

- what changed on screen
- what it expected to happen
- what likely blocked progress
- whether the failure looks like app behavior, selector drift, timing, auth, or perception failure

### 3. Generate tests

Once a path is accepted, the system should:

- generate Playwright tests
- store fixtures and helpers
- attach screenshots or traces if needed
- propose assertions instead of only copying clicks

### 4. Hunt for gaps

This is where your mention of a `dogfood`-style skill is interesting.

I could not verify a public official page for that exact Vercel skill, so this section is partly an inference from your description rather than a sourced product claim.

But the idea is sound:

- let an exploratory agent roam the app
- log suspicious outcomes
- cluster failures or weird states
- generate a report of probable bugs or untested branches

That should sit beside authored test generation, not replace it.

## The role of D2Snap in this architecture

Even in a multimodal-first era, I do not think D2Snap-style work becomes irrelevant.

Quite the opposite.

If you are building a serious browser-agent platform, you still want:

- smaller inputs
- preserved hierarchy
- lower token cost
- better structured context for reasoning

D2Snap is important because it pushes the DOM path forward instead of conceding everything to screenshots.

My guess is that the strongest long-term systems will combine:

- accessibility snapshots for fast structured interaction
- DOM downsampling for richer context when needed
- screenshots for ambiguity resolution and visual diagnosis

## My current design principle

The design principle I trust most now is:

use agents for discovery, not for repetitive execution.

That means:

- agents should inspect and explore
- agents should diagnose and propose
- agents should convert working flows into tests
- agents should revisit failures when tests drift

But the steady state should be a test suite.

That is what makes the system operationally sane.

## Closing thought

If I compare what I believed in mid-2025 with what I believe now, the biggest change is this:

I used to think the problem was building a browser agent that could do everything.

Now I think the problem is building a workflow that knows when to use:

- structure
- vision
- orchestration
- and plain old test code

The most useful E2E agent is the one that knows how to disappear into Playwright once it has learned enough.

## References

- agent-browser: <https://github.com/vercel-labs/agent-browser>
- Playwright MCP: <https://github.com/microsoft/playwright-mcp>
- Playwright Test Agents: <https://playwright.dev/docs/test-agents>
- Chrome DevTools MCP: <https://github.com/ChromeDevTools/chrome-devtools-mcp>
- Vercel skills docs: <https://vercel.com/docs/agent-resources/skills>
- Vercel skills changelog: <https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem>
- Gemini computer use announcement: <https://blog.google/innovation-and-ai/models-and-research/google-deepmind/gemini-computer-use-model/>
- Gemini 2.5 I/O update: <https://blog.google/technology/google-deepmind/google-gemini-updates-io-2025/>
- Qwen3-VL repository: <https://github.com/QwenLM/Qwen2.5-VL>
- D2Snap paper: <https://arxiv.org/abs/2508.04412>
