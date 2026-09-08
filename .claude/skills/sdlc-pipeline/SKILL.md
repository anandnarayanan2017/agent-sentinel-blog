---
name: sdlc-pipeline
description: Orchestrates the full agent SDLC - spec, design, critic approval, build, review, test, debug, UAT, trust evaluation, evidence bundle. Use when the user says "run the pipeline", "start sdlc", or provides new requirements to build end-to-end.
---
# SDLC Pipeline Orchestrator (v2 — course-aligned)

You are the coordinator. You DISPATCH; you do not do phase work yourself.
Track state in `.claude/pipeline-state/phase` so a crashed run resumes.
Read HITL_MODE from `.claude/sdlc.env`:
- `two-gate` (default): humans appear only at phase 1 and phase 10.
- `per-phase` (course-style ongoing HITL): ALSO stop for human confirmation
  after phase 3 (design approved) and after phase 5 (reviews clean).

## Phase 0 — enforcement baseline
Before anything else: refuse to run if `.claude/sdlc.env` is byte-identical to
`.claude/sdlc.env.example` (`diff -q` or a hash compare). An unfilled-in
sdlc.env means every downstream command — `SECURITY_SCAN_CMD`, `IAC_PLAN_CMD`,
`BUILD_CMD` default to `"true"` in the template — passes silently without
actually checking anything, and Gate 2's evidence bundle would attest to
checks that never ran. STOP and tell the human to fill in `sdlc.env` for real
before proceeding; do not run the pipeline against placeholder values.

Record BOTH the content hash and the file mode of the enforcement layer into
`.claude/pipeline-state/enforcement.sha256`:

```sh
sha256sum .claude/hooks/* .claude/settings.json
stat -c '%n %a' .claude/hooks/*
```

The trust evaluation verifies this is unchanged at the end — a mutated
enforcement layer mid-run is a HALT. Mode is recorded alongside content
because a content hash alone cannot detect a hook that is byte-perfect but
not executable, which fails **open** (exit 126, which Claude Code treats as
non-blocking) rather than closed. Also refuse to start if any hook is not
executable — see `effective-trust` step 1a.

## Phases (each gates on the prior phase's artifact)
1. **spec** — `spec/.signed-off` missing → dispatch spec-agent, STOP for human
   sign-off. GATE 1.
2. **design** — architect → `design/DESIGN.md`.
3. **critique** — adr-critic; architect↔critic max 3 rounds; else HALT.
   (per-phase mode: pause for human here.)
4. **build** — phase file = build. Implement per DESIGN.md; independent
   components → parallel subagents/worktrees, one worker per checkout.
5. **review** — code-reviewer on diff; security-reviewer too if SENSITIVE_PATHS
   touched. BLOCKER/HIGH → back to build. (per-phase mode: pause here.)
6. **test** — test-writer (spec-derived) → test-runner.
7. **debug** — debugger with circuit breaker; DEBUG_HALT.md → PIPELINE_HALT.
8. **uat** — uat-runner → `evidence/UAT_RESULTS.md`. Fail-closed.
9. **trust-eval** — effective-trust skill → agent-evaluator →
   `evidence/TRUST_REPORT.md`. Any pillar scored 0 → HALT. Verify enforcement
   hash from Phase 0.
10. **gate2** — assemble `evidence/GATE2_BUNDLE.md` (uat-evidence skill,
    now INCLUDING the trust report). STOP: human approves via CI
    required-reviewer environment. Deploy skill is human-invoked only.

## Invariants
- Never skip a phase; never proceed on a missing artifact.
- Writer and reviewer are never the same agent; evaluator evaluates behavior,
  reviewers evaluate code — never merged into one role.
- Context hygiene (course Day 3): keep verbose output in subagents; if the main
  thread degrades (repeating itself, re-reading same files), compact/summarize
  state to the phase file and artifacts, then continue from artifacts — never
  from stale conversational memory.
- Honest HALT reports are a success condition.
