# Agent Sentinel — 5-part LinkedIn series

> This is the **public docs mirror** for Agent Sentinel's blog series. The
> product source code lives in a private repository — file paths referenced
> below (`app/...`, `docs/...`, `evidence/...`) point there, not here. This
> repo exists so the write-ups themselves, and their diagrams, have a public,
> shareable home for LinkedIn without exposing the source repo.

**Positioning:** Agent Sentinel is an explainable runtime control plane for
AI-agent behavior. It detects, explains, enforces, and exports evidence-rich
findings into existing SOC platforms such as Microsoft Sentinel and Splunk.

**Product line:** Detect. Explain. Enforce. Export.

Each part below is the full technical writeup (diagrams render natively on
GitHub). The matching LinkedIn Article should carry the same hook, 1-2 of
the diagrams re-exported as images, and a link back to the file here.

| # | Part | LinkedIn hook |
|---|---|---|
| 1 | [Why AI Agents Need a Flight Recorder](01-why-agents-need-a-flight-recorder.md) | Your payment reconciliation agent just called an LLM, invoked a ledger tool, and sent 250KB to a host nobody approved. Could you prove what happened? |
| 2 | [From Simulated Traffic to Real Model Calls](02-simulation-to-real-models.md) | Start small: before blocking agent behavior, record it well enough that a CISO can trust the evidence. |
| 3 | [Rules First, Statistics Second](03-rules-first-statistics-second.md) | A wire-transfer tool call is legal. A wire-transfer tool call *before* the identity-verification step is a breach. No YAML allow-list can tell the difference. |
| 4 | [The Enterprise Foundation](04-enterprise-foundation.md) | The difference between a demo and an enterprise platform is not prettier charts. It is identity, storage, auditability, approvals, and operations. |
| 5 | [Feeding the SOC, and What's Next](05-soc-and-whats-next.md) | Agent Sentinel should not be another SIEM. It should produce the AI-agent evidence your SIEM does not have natively. |

A companion series, [AI-Assisted Coding: Harness, Context, and Course
Alignment](ai-assisted-coding/README.md), covers the meta-process — the
`.claude/` SDLC pipeline used to build this product — rather than the
product itself.

## Publishing plan

| Week | Part | Goal |
|---|---|---|
| 1 | Why AI Agents Need a Flight Recorder | Establish the problem |
| 2 | Simulation to Real Models | Show the working MVP and the real-SDK pivot |
| 3 | Rules First, Statistics Second | Build technical credibility, including the sequence-model pivot |
| 4 | The Enterprise Foundation | Show what makes it serious for CISOs |
| 5 | Feeding the SOC, and What's Next | Clarify positioning and roadmap |

## Part 3 gate status — cleared and merged

Part 3 covers the `sentinel_sequence` sequence-anomaly model, including the
second-role (`payments_bot_demo`) evaluation
(`app/sentinel_sequence/data_gen_payments.py`, `docs/EVAL_PAYMENTS_BOT.md`,
`examples/phase2/sequence_eval_payments_demo.py`). That work went through its
own full Gate 1 → Gate 2 spec cycle (retroactively, since it was found as
untracked scope-creep) — signed-off spec, architect/critic design rounds,
code review, UAT (15/17 pass; the 2 failures were a stale test-fixture bug in
frozen `spec/UAT.md`, not a defect in the shipped code), and a trust
evaluation that surfaced and correctly remediated one process violation
mid-cycle. Gate 2 was approved by the human reviewer
(`evidence/GATE2_BUNDLE.md`, `evidence/.gate2-approved`), and the work has
since merged to the product repo's `master` — **fully shipped, safe to
publish**, no open gate or pending PR left to track.

The already-committed `kyc_bot_demo` hardening results (94 tests, 95%+
coverage, mean-NLL → top-k-surprise fix) were always safe to publish.

## Closing narrative

Agent Sentinel starts as a local flight recorder for AI agents, but the
enterprise product is bigger than logging. The durable value is the
combination of:

1. Runtime visibility into model, tool, and data behavior.
2. Deterministic policy enforcement.
3. Evidence-rich findings mapped to compliance controls.
4. Clean export into Microsoft Sentinel, Splunk, and SOAR workflows.

```text
Detect. Explain. Enforce. Export.
```

Let the SIEM be the SIEM. Agent Sentinel should be the AI-agent control
plane that gives the SIEM evidence it never had before.
