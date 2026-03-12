+++
title = 'Why Web Agents Need Vision'
date = 2026-03-12T10:56:00+08:00
draft = false
author = 'Tony Li'
keywords = ['ai', 'agents', 'browser automation', 'vision', 'multimodal', 'yolo']
summary = 'Vision is not a replacement for structured browser state, but it is a necessary complement when the DOM does not expose what the interface is actually telling the user.'
canonicalURL = 'https://blog.atom2ueki.com/posts/why-web-agents-need-vision/'
+++

Once the limits of DOM-only agents become visible, the next question follows naturally:

if the browser cannot expose the right state, how else should the agent understand the interface?

That question pulled me toward vision.

## Browser Use clarified the next step

One of the most important transitions for me came from Browser Use.

Its most valuable idea was not simply browser automation. It was the idea that raw browser state is usually a poor interface for an LLM, and that a normalized, model-friendly representation is often much better than raw DOM.

That insight still matters.

Looking at the Browser Use documentation now, the system clearly supports configurable vision behavior and screenshot-based context in the loop. That validates the broader direction: browser agents were already moving beyond text-only page snapshots.

But during the period when I was exploring it, the vision side still felt early. What I took away at the time was not that Browser Use had already solved multimodal computer use. It was that better interfaces between browser state and model reasoning were essential.

## My bridge into vision was YOLO

Before mature computer-use systems became the obvious path, I explored a more manual route.

I tried using YOLO-style detection with coordinates to give the model a visual view of the interface.

The logic was straightforward:

- detect UI regions or components visually
- attach coordinates to those detections
- let the LLM reason over the detected layout
- ground actions back onto the screen

![Why YOLO was a bridge, not the destination](/images/posts/agentic-e2e-public-series/vision-bridge.svg)

This worked better than I expected in exactly the places where DOM-first systems were weakest.

That mattered because it exposed the real shape of the problem: some browser-agent failures are not tool failures. They are perception failures.

The downside was equally clear. The moment the interface changed, or the page moved outside the assumptions of the detector, the system became expensive to adapt. It was an interesting bridge, but not a durable solution on its own.

## Why multimodal computer use changed the category

Later, stronger computer-use systems made the broader direction unmistakable.

Anthropic helped define the category by making screenshot-based interaction, cursor control, typing, and scrolling feel like a coherent product capability rather than an isolated demo. Google pushed the same direction further with Gemini computer use. Qwen3-VL reinforced that GUI interaction was becoming a serious multimodal capability across model families, not a one-vendor novelty.

This changed the architecture question.

The real question was no longer whether DOM or vision would win.

The better question became:

which representation is best for the current obstacle?

That is a much more useful way to think about browser agents.

## The lesson that survives the hype cycle

Vision is not a replacement for structured browser state.

It is a necessary complement to it.

DOM remains valuable because it is fast, grounded, and easier to convert into stable tests.

Vision matters because it can recover what the DOM does not express well.

That is why the strongest browser-agent systems are not DOM-only and not vision-only.

They are routed systems.

They know when visual understanding should take over.

And once that becomes clear, the next question is no longer just how to improve perception. It is how to improve the interface the agent consumes in the first place.

## References

- Browser Use agent settings: <https://docs.browser-use.com/open-source/customize/agent/all-parameters>
- Browser Use discussion on vision with non-vision models: <https://github.com/browser-use/browser-use/discussions/1621>
- Anthropic computer use docs: <https://docs.anthropic.com/en/docs/build-with-claude/computer-use>
- Anthropic computer use announcement: <https://www.anthropic.com/news/3-5-models-and-computer-use>
- Google Gemini 2.5 Computer Use announcement: <https://blog.google/innovation-and-ai/models-and-research/google-deepmind/gemini-computer-use-model/>
- Qwen3-VL repository: <https://github.com/QwenLM/Qwen3-VL>
- Comet updates: <https://www.perplexity.ai/comet/whats-new/what-we-shipped-september-19th>
