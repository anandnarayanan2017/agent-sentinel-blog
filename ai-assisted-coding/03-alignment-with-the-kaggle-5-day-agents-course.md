# How Aligned Is This With Google & Kaggle's 5-Day Agents Course?

Google and Kaggle's free ["5-Day AI Agents: Intensive Vibe Coding
Course"](https://www.kaggle.com/learn-guide/5-day-agents-vibecoding) pairs a
whitepaper with two codelabs per day, built on Gemini and Google's Agent
Development Kit. Its five days, per the course's own materials and public
summaries:

| Day | Theme | Whitepaper |
|---|---|---|
| 1 | Introduction to Agents & Vibe Coding — "natural language as the new coding language" | — |
| 2 | Agent Tools & Interoperability — "10x agents" via MCP, Agent2Agent (A2A), Agent-to-UI (A2UI), Agent Payments Protocol (AP2), Universal Commerce Protocol (UCP) | tool invocation & MCP architecture |
| 3 | Agent Skills — long-term memory, state, and token-use strategy | "Context Engineering: Sessions & Memory" |
| 4 | Agent Quality & Security — guardrails, evaluation, new agent-specific threat vectors | "Vibe Coding Agent Security and Evaluation" ("Effective Trust," a 7-pillar model) |
| 5 | Prototype to Production — deployment, scaling, observability | "Prototype to Production" |

*(I could not load the Kaggle page directly in this session — it returned an
access error — so this table is reconstructed from the course's public
description and third-party write-ups, not a first-hand read of the
whitepapers themselves. Treat the day themes as reliable, the exact
whitepaper wording as approximate.)*

What makes this comparison unusually direct: this repository's own
[`.claude/sdlc.env`](../.claude/sdlc.env) has a section literally labeled `# --- Course-alignment
additions (v2) ---`, and [`.claude/skills/effective-trust/SKILL.md`](../.claude/skills/effective-trust/SKILL.md) opens with
*"Seven pillars, mapped from the Google/Kaggle course Day 4 failure-mode
themes."* This isn't an outside reviewer squinting for parallels — the
pipeline was deliberately built to track this course. The interesting
question isn't *whether* it's aligned, it's *how* and *where it diverges on
purpose*.

## Day 1 — Vibe coding

The course's framing is natural language as the primary programming
interface. This repo uses natural language the same way — spec-agent,
architect, and every other phase are dispatched through plain-English
instructions — but it refuses the "vibe" part of vibe coding for anything
that reaches production. [`CLAUDE.md`](../CLAUDE.md)'s two-gate model requires a human to
write `spec/.signed-off` before any build work starts, and a second human
gate (`evidence/GATE2_BUNDLE.md`) before prod. That's the repo's own
product philosophy — "rules-first, not model-first," "statistics are
secondary signal, never the sole detector" — turned back on its own
development process. Alignment: **directional, not literal.** Same input
modality, opposite risk posture.

## Day 2 — Tools & interoperability

Strong, direct alignment on the governance half. [`.claude/rules/mcp-governance.md`](../.claude/rules/mcp-governance.md)
requires every MCP server to appear in both `.mcp.json` and `sdlc.env`'s
`MCP_ALLOWED_SERVERS`, prefers gateway-routed MCP over direct backend calls,
and treats MCP tool results as untrusted data — never instructions to
execute. `new-adr` requires a new ADR for any new MCP server, matching the
course's framing of MCP as a supply-chain decision, not a convenience.

Where it doesn't reach: the course's Day 2 also covers A2A (agent-to-agent),
A2UI (generative UI), AP2/UCP (agent-driven commerce). None of those have an
analog here. The closest thing — subagent dispatch (`architect` handing off
to `adr-critic`, `code-reviewer`, etc.) — is in-process orchestration inside
one Claude Code session, not the cross-organization, cross-vendor agent
negotiation A2A/AP2 describe. That's an honest gap, not a hidden one: this
repo's tool-interoperability story is single-tenant.

## Day 3 — Context engineering

This is the closest match, and it shows up almost verbatim.
[`sdlc-pipeline`](../.claude/skills/sdlc-pipeline/SKILL.md)'s invariants use the phrase *"context hygiene (course Day
3)"* directly, and the mechanism described — keep verbose output in
subagents, compact to the phase file and artifacts when the main thread
degrades, continue from artifacts rather than stale conversational memory —
is a working implementation of the course's Sessions-vs-Memory distinction:
`spec/`, `design/`, `evidence/`, and `.claude/pipeline-state/phase` are the
"memory" layer; the live conversation is the "session" layer.

Where the repo is coarser than the course's likely treatment: there's no
explicit token-budget accounting or automatic summarization trigger here —
"if the main thread degrades" is a qualitative judgment call made by the
orchestrating skill, not a measured threshold. The Day 3 whitepaper's
premise is described as *dynamically* assembling context; this repo's
version is closer to *staged* context handoff at fixed pipeline
checkpoints. Real alignment in concept, a less dynamic implementation in
practice.

## Day 4 — Quality & security

The tightest alignment in the whole repo, to the point of shared
vocabulary. [`slopsquat_guard.sh`](../.claude/hooks/slopsquat_guard.sh)'s own comment says *"Slopsquatting defense
(course Day 4)"* and blocks package installs against live registry checks
plus a minimum-age threshold, directly implementing the course's
hallucinated-dependency threat model. The `effective-trust` skill's seven
pillars — dependency integrity, context integrity, tool-use containment,
sandboxing/blast radius, human-in-the-loop integrity, output evaluation,
observability — map to the course's stated Day 4 failure modes (slopsquatting,
context rot, tool misuse, sandboxing, HITL, evaluation, observability)
almost one-to-one, and `agent-evaluator` scores each pillar 0–2 from the
append-only audit log as a distinct, code-reviewer-independent role.

The skill file itself carries an honesty caveat worth repeating rather than
smoothing over: *"pillar names here are our mapping of the course's themes,
not Google's verbatim list."* That's the right level of rigor for a claim
like this — alignment in structure and intent, explicitly not a claim of
reproducing Google's exact taxonomy.

## Day 5 — Prototype to production

Aligned in spirit, weaker in depth. The repo has a real path from local dev
to a governed prod apply — CI behind a required-reviewer environment, never
an agent session — which matches the course's emphasis on graduating from
local prototypes to a "governed, scalable, observable production-ready
fleet." But `sdlc.env`'s own comments are candid that `infra/terraform/` is
"a documented skeleton... with no state backend or CI credentials wired up"
and `IAC_PLAN_CMD="true"` is a placeholder pending real cloud credentials.
Observability exists (`docs/ARCHITECTURE.md`'s storage/audit-trail
distinction between DuckDB and Postgres/TimescaleDB backends), but the
scaling and multi-worker story is flagged in the same doc as a known
follow-up, not yet solved. This is the one day where the gap is about
maturity, not intent.

## Overall verdict

| Day | Alignment |
|---|---|
| 1. Vibe coding | Directional — same NL-first interface, opposite (gated) risk posture |
| 2. Tools & interop | Strong on MCP governance; no A2A/A2UI/AP2/UCP analog |
| 3. Context engineering | Strong conceptually; staged rather than dynamic in practice |
| 4. Quality & security | Tightest match — shared vocabulary, explicit pillar mapping |
| 5. Prototype to production | Aligned in intent; infra maturity is an acknowledged gap |

The honest summary: this repo didn't invent its own AI-coding governance
model and discover after the fact that it resembles Google/Kaggle's course.
It read the course's Day 2–4 failure modes and built `sdlc.env` knobs
(`SLOPSQUAT_MIN_AGE_DAYS`, `MCP_ALLOWED_SERVERS`, `HITL_MODE`) directly
against them — `HITL_MODE` even ships two settings, `two-gate` (this
template's stricter default) and `per-phase` ("course-style ongoing HITL"),
as an explicit dial for how closely to track the course's more
continuous-human-oversight posture versus this repo's default of only two
human checkpoints. Where it diverges, it diverges on purpose: a fintech
compliance product's own "rules-first, statistics-second" stance, applied
reflexively to the process that builds it, is always going to sit stricter
and slower than a course whose organizing metaphor is "vibe coding." That
tension is the actual finding here — not a gap to close, but a design
choice worth stating explicitly rather than leaving implicit.

---

**Sources:** [Kaggle — 5-Day AI Agents: Intensive Vibe Coding Course With
Google](https://www.kaggle.com/learn-guide/5-day-agents-vibecoding),
[KDnuggets — Kaggle + Google's Free 5-Day Agentic AI
Course](https://www.kdnuggets.com/kaggle-googles-free-5-day-agentic-ai-course).
Repo-side claims are drawn directly from [`.claude/sdlc.env`](../.claude/sdlc.env),
[`.claude/hooks/*.sh`](../.claude/hooks), [`.claude/skills/effective-trust/SKILL.md`](../.claude/skills/effective-trust/SKILL.md),
[`.claude/skills/sdlc-pipeline/SKILL.md`](../.claude/skills/sdlc-pipeline/SKILL.md), [`.claude/rules/*.md`](../.claude/rules), and
`docs/ARCHITECTURE.md` in the (private) product repository — all copied
verbatim into this mirror's [`.claude/`](../.claude) except `docs/ARCHITECTURE.md` itself, which
stays product-repo-only.
