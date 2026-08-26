# AI-Assisted Coding: Harness, Context, and Course Alignment — 3-part series

A short series on the two concepts that determine whether AI-assisted coding
is trustworthy in a regulated environment — the deterministic **harness**
around the model, and deliberate **context engineering** of what it sees —
using this repository's own `.claude/` SDLC pipeline as the worked example.

| # | Part | What it covers |
|---|---|---|
| 1 | [Harness and Context: The Two Words That Actually Matter](01-harness-and-context-the-two-words-that-matter.md) | Definitions: harness as deterministic scaffolding, context engineering as deliberate curation of the context window (session vs. memory, isolation, compaction, scoped loading). |
| 2 | [Worked Example: The Harness and Context Design Behind This Repo's Own SDLC](02-worked-example-harness-and-context-in-this-repo.md) | Concrete walkthrough of `.claude/settings.json` hooks, `sdlc.env`, per-agent tool scoping, `pipeline-state/phase`, frozen `spec/`, and path-scoped `rules/`. |
| 3 | [How Aligned Is This With Google & Kaggle's 5-Day Agents Course?](03-alignment-with-the-kaggle-5-day-agents-course.md) | Day-by-day comparison against the course's public curriculum, grounded in this repo's explicit "course-alignment" additions (`sdlc.env`, `effective-trust`, `slopsquat_guard.sh`). |

This series is distinct from the product-focused
[5-part Agent Sentinel series](../README.md) one directory up — that one
pitches the product; this one is about the meta-process used to build it.
