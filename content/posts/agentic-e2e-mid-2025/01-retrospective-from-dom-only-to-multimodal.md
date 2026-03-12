---
title: "From DOM-Only Agents to Multimodal Orchestration"
date: 2026-03-12T23:30:00+08:00
draft: true
author: "Tony Li"
summary: "A retrospective on my mid-2025 exploration of agentic E2E automation, from LangGraph plus Playwright MCP to multimodal browser agents."
tags:
  - ai
  - agents
  - browser-automation
  - langgraph
  - playwright
  - multimodal
---

# From DOM-Only Agents to Multimodal Orchestration

Mid-2025 was the period when my understanding of browser agents changed the most.

I started with a fairly simple belief: if an LLM could read enough browser state, reason over it, and call the right browser tools, then end-to-end automation should become a mostly solved problem.

That belief was not wrong. It was just incomplete.

## The first phase: LangGraph plus non-vision browser control

My starting point was a non-vision path. I was exploring LangGraph-based orchestration, with browser automation driven by DOM- or accessibility-like representations rather than screenshots.

At the time, this felt like the most practical direction:

- text snapshots were cheaper than image-heavy workflows
- the model could reason over structured state
- browser actions remained deterministic
- programmatic targeting was possible

This was the attraction of Playwright MCP and similar approaches. They let the model operate on structured browser state instead of turning every interaction into a computer-vision problem.

But in practice, the first big limitation appeared quickly: blocker detection.

The agent could often act on visible, clean, well-structured interfaces. It struggled more when the problem was not “what button should I click?” but “what is preventing progress right now?”

That blocker might be:

- a disabled state with weak semantic signals
- a shadow DOM boundary
- a modal rendered in an unexpected way
- a loading overlay
- a canvas-like UI
- an element whose intent is obvious to a human but poorly represented in DOM state

This was the first time I felt the gap between “browser automation” and “UI understanding”.

## The second phase: Browser Use and normalized page snapshots

Then I spent time with Browser Use.

What was interesting was not just the tool itself, but the design idea behind it: instead of feeding raw browser state to the model, normalize the page into a more LLM-friendly intermediate representation.

That idea aged extremely well.

Today it sounds obvious, but at the time it was one of the clearest signals that browser agents needed a translation layer between raw web runtime state and model reasoning. Browser Use popularized a grounded snapshot style where the page is converted into a tagged, referenceable representation that the model can talk about and act against.

I think this was a genuine step forward. But I also hit its limits.

My main issue was not the general direction. It was the cleanup algorithm and the fidelity of the representation.

The problems I kept seeing were:

- the snapshot was cleaner than raw DOM, but still not always semantically correct
- adjacent or similar elements could collapse into ambiguous targets
- the system did not always preserve the right tags or hierarchy
- once the representation drifted, the model could become confidently wrong

In other words: normalization helped, but lossy normalization creates a new failure mode.

You reduce noise, but sometimes you reduce truth as well.

## The third phase: trying to patch the gap with detection models

Because multimodal computer-use models were not yet the obvious default, I started exploring a hybrid path: YOLO plus coordinates plus LLM reasoning.

The idea was straightforward:

- let a vision model detect UI regions or components
- attach coordinates
- use an LLM to reason over those detections
- ground actions back to the screen

At first, it worked better than I expected.

This was especially useful in cases where DOM-based tooling simply did not expose enough useful state. If the page was visually obvious but structurally messy, the image-based path could recover progress.

But it was also hard to maintain.

The moment the UI changed, or the site used patterns outside the pretrained assumptions, the system became brittle again. Pretrained UI understanding helped, but adaptation cost was high. The workflow was technically interesting, but operationally expensive.

That was the second major lesson: if your browser agent requires constant perception retuning to survive normal frontend variation, it will not scale.

## The fourth phase: D2Snap and the idea that DOM should be compressed, not discarded

Around that time I came across D2Snap and the paper behind it, *Beyond Pixels: Exploring DOM Downsampling for LLM-Based Web Agents*.

This clicked with me immediately.

Instead of choosing between:

- raw DOM, which is too large
- or aggressive extraction, which often destroys useful structure

the proposal was to downsample the DOM while preserving more of the hierarchy and interactive semantics that matter for action selection.

That distinction matters a lot.

The D2Snap argument is not simply “make HTML smaller”. It is closer to:

“Preserve the useful UI signal, but compress the useless detail before it reaches the model.”

That felt much closer to the right abstraction.

The most important part for me was not even the benchmark number. It was the framing:

- hierarchy itself is a useful UI feature
- flattening is not always the right optimization
- downsampling can be better than extraction

That matches a lot of what I had been feeling from trial and error.

The screenshot below is one of the visual examples I want to keep in this series because it makes the idea intuitive:

![D2Snap downsampling example](/images/posts/agentic-e2e-mid-2025/downsampling.png)

## The fifth phase: Chrome DevTools MCP changed the execution loop

Later, Chrome DevTools MCP arrived and the browser automation part became much more compelling.

What impressed me most was not only that it could control the browser, but that it tightened the feedback loop around action execution.

In practice, one of the hardest parts of browser agents is not issuing an action. It is determining whether the action actually changed the state in the intended way.

Chrome DevTools MCP improved this a lot:

- it is tightly integrated with a live Chrome session
- it can inspect console, network, screenshots, and runtime state
- it waits for action results more reliably
- it gives the agent a stronger before/after understanding of what changed

This made the agent feel less blind after each step.

Still, the same hard boundary remained: DOM-based understanding always has blind spots.

If the relevant state is not properly expressed in HTML, accessibility structure, or browser-inspectable semantics, a DOM-first agent will eventually hit a wall.

## The sixth phase: multimodal computer use finally became practical

The real shift happened when strong multimodal computer-use capabilities started becoming available in a more practical form.

At that point, the architecture became much clearer to me:

- use a DOM-first agent when the UI is structurally legible
- fall back to a vision-capable agent when the page is visually obvious but structurally weak
- let an orchestrator decide which path to use

This was the direction where my own modified multi-agent setup started working much better.

I was combining:

- a stronger orchestration layer than the early Deep Agents defaults
- DOM-oriented browser control
- a vision sub-agent for screenshot-based reasoning

Once I stopped forcing one representation to solve every case, reliability improved.

That was probably the most important architectural lesson of the whole period.

The best browser agent is not DOM-only or vision-only.

It is a routed system.

## Where I land now

Looking back, I think the journey was really about learning that browser automation is a representation problem before it is a reasoning problem.

The stack kept changing, but the recurring question stayed the same:

How should the UI be represented so that the model can both understand it and act on it reliably?

My current answer is:

- DOM and accessibility snapshots are still the fastest and cheapest path when they are good enough
- downsampled DOM is more promising than raw DOM or naive flattening
- vision is not optional for full coverage
- orchestration matters because no single perception mode is sufficient
- once the agent discovers a stable flow, the end state should usually be a Playwright test, not permanent agent-only execution

That last point is important enough that I turned it into the next posts.

Because the end goal is not to admire an agent solving a problem slowly.

The end goal is to convert exploration into repeatable test coverage.

## References

- Browser Use: <https://github.com/browser-use/browser-use>
- Chrome DevTools MCP: <https://github.com/ChromeDevTools/chrome-devtools-mcp>
- D2Snap paper: <https://arxiv.org/abs/2508.04412>
- D2Snap repository: <https://github.com/webfuse-com/D2Snap>
- Webfuse article on DOM downsampling: <https://www.webfuse.com/blog/dom-downsampling-for-llm-based-web-agents>
- Gemini computer use announcement: <https://blog.google/innovation-and-ai/models-and-research/google-deepmind/gemini-computer-use-model/>
