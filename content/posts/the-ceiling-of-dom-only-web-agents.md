+++
title = 'The Ceiling of DOM-Only Web Agents'
date = 2026-03-12T10:55:00+08:00
draft = false
author = 'Tony Li'
keywords = ['ai', 'agents', 'browser automation', 'playwright', 'dom']
summary = 'DOM-first web agents are efficient and grounded, but they hit a ceiling when browser-visible state is too incomplete to explain what is actually blocking progress.'
canonicalURL = 'https://blog.atom2ueki.com/posts/the-ceiling-of-dom-only-web-agents/'
+++

Most browser-agent systems begin with a sensible assumption:

if the browser can expose enough structured state, an LLM should be able to reason over that state and complete UI tasks reliably.

That assumption is not wrong. It is simply not enough.

## Why DOM-first systems are so attractive

DOM-first and accessibility-first systems have several real advantages.

They are:

- cheaper than screenshot-heavy loops
- more deterministic than pixel-based control
- easier to map to actions, assertions, and test code
- closer to the abstractions that existing browser automation systems already use

This is part of what makes tools like Playwright MCP appealing. They give agents structured browser state and deterministic control instead of forcing every decision through visual inference.

For clean interfaces, it works well.

## Where the ceiling appears

The problem is that browser automation is not only about selecting the next action.

It is also about understanding why progress has stopped.

That is where DOM-only systems begin to fail.

In many real interfaces, the important signal is only partially represented in browser-visible structure. The issue might be:

- a disabled control whose meaning is visually obvious but semantically weak
- a modal or overlay that changes the page without providing clean structure
- a shadow DOM boundary
- a canvas-heavy interface
- a custom component whose visible intent is clearer than its DOM representation

At that point, the agent still has tools. What it lacks is a faithful enough picture of the interface.

## Why looping is a structural problem

One of the clearest failure modes in DOM-first agents is looping.

The agent keeps retrying nearby actions, rereading nearly identical state, or following a path that looks plausible in the current representation but never resolves the real blocker.

![Why DOM-only agents loop](/images/posts/agentic-e2e-public-series/loop-trap.svg)

It is tempting to describe this as a reasoning problem.

I think that is usually the wrong diagnosis.

More often, it is a representation problem.

If the browser-visible state does not reveal what actually matters, the model can keep making locally reasonable decisions inside a fundamentally incomplete picture of the UI.

That is why looping is so common in brittle browser agents. The system is not necessarily irrational. It is acting on the wrong abstraction.

## The lesson that survives the tool cycle

The durable lesson is not that DOM is a bad interface.

The durable lesson is that DOM is a useful interface, but not a sufficient one.

Whenever the browser exposes enough meaningful structure, DOM-first systems are efficient, grounded, and easy to operationalize.

But once the critical signal is missing, ambiguous, or more visible than semantic, better parsing alone stops helping.

That is the point where the agent needs another way to understand the screen.

And that is exactly why the next phase of browser agents had to move toward visual grounding.

## References

- Playwright MCP repository: <https://github.com/microsoft/playwright-mcp>
- Playwright MCP docs: <https://playwright.dev/docs/mcp>
- LangGraph overview: <https://docs.langchain.com/oss/python/langgraph/overview>
