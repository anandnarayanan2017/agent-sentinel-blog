# Agent Sentinel — 5-part blog series

**Agent Sentinel** is an explainable flight recorder and behavioral firewall
for AI agents in regulated environments. It records every model call, tool
call, and network egress an agent makes, checks them against readable
policy, and exports evidence-rich findings to the SOC.

```text
Detect. Explain. Enforce. Export.
```

This repo is the public home of the write-ups. Each part is short,
written for both technical and non-technical readers, and links into the
[product source repo](https://github.com/anandnarayanan2017/agent-sentinel)
for the technical detail.

## The series

| # | Part | One-line hook |
|---|---|---|
| 1 | [Why AI Agents Need a Flight Recorder](01-why-agents-need-a-flight-recorder.md) | Your reconciliation agent just sent 250KB to a host nobody approved. Could you prove what happened? |
| 2 | [Record First, Enforce Later](02-simulation-to-real-models.md) | Install the dashcam before you hand out fines: trustworthy recording comes before blocking. |
| 3 | [Rules First, Statistics Second](03-rules-first-statistics-second.md) | The rulebook decides; the anomaly model only advises. A black box shouldn't shut down a payment bot. |
| 4 | [The Enterprise Foundation](04-enterprise-foundation.md) | A demo answers "does it work?" A bank asks "who saw it, who approved it, can you prove it?" |
| 5 | [Feeding the SOC, and What's Next](05-soc-and-whats-next.md) | Not another SIEM — the missing camera feed your SIEM doesn't have: your AI agents. |

A companion series, [AI-Assisted Coding: Harness, Context, and Course
Alignment](ai-assisted-coding/README.md), covers the `.claude/` SDLC
pipeline used to build the product.

## Not yet mirrored: Series 2 (Parts 6-10)

The product repo carries a second five-part run — the network-visibility
collector added in ADR-0008 — that has **not** been mirrored here yet:

| # | Part |
|---|---|
| 6 | The Blind Spot Every AI-Agent Firewall Has |
| 7 | Visibility Without a Blank Check |
| 8 | From Open Port to Explainable Finding |
| 9 | Built to Fail Safe, Not Fail Quiet |
| 10 | What This Doesn't Do Yet |

The sync between the product repo's `docs/blog/` and this mirror is manual
(the product repo's own `docs/blog/README.md` says so: *"no automated sync
exists yet"*), and it has drifted. Parts 1-5 here are the shorter
dual-audience rewrite, not stale copies — that divergence is deliberate.
Parts 6-10 are simply absent. Closing this is tracked in
[the factory assessment](docs/assessments/2026-09-07-ai-first-factory-assessment.md).

## Publishing notes (LinkedIn ↔ GitHub alignment)

- Each part is written to work **verbatim as a LinkedIn article**: hook,
  plain-terms section, technical section, one diagram, code links.
- Diagrams are Mermaid and render natively on GitHub. For LinkedIn,
  export each diagram as an image (screenshot or `mmdc`) and drop it in
  place of the code block; pre-exported images live in `images/`.
- End each LinkedIn article with a link back to the matching file here
  ("full version with code links on GitHub").
- The code links point to the product repo, which must be **public** for
  readers to follow them; until then they resolve only for the owner.

## Publishing plan

| Week | Part | Goal |
|---|---|---|
| 1 | Why AI Agents Need a Flight Recorder | Establish the problem |
| 2 | Record First, Enforce Later | Show the working MVP and the real-SDK pivot |
| 3 | Rules First, Statistics Second | Technical credibility, incl. the sequence-model lessons |
| 4 | The Enterprise Foundation | What makes it serious for CISOs |
| 5 | Feeding the SOC, and What's Next | Positioning and roadmap |

All content in the series covers work that has fully cleared the product
repo's two-gate SDLC (signed-off specs, reviews, UAT, approved Gate 2
evidence bundles) — everything described here is shipped and safe to publish.
