# Agent Sentinel

<!-- CLAUDE.md is always-on memory: short, standing FACTS only.
     Procedures -> skills. Path-scoped conventions -> .claude/rules/.
     Enforcement -> hooks. Do not bloat this file. -->

## What this repo is
An explainable flight-recorder and behavioral firewall for AI agents and
machine-to-machine (M2M) identities, aimed at regulated environments
(fintech: reconciliation bots, KYC assistants, payments copilots). It
intercepts LLM calls, tool/MCP calls, and network egress, baselines normal
behavior, and raises explainable findings mapped to regulatory controls
(DORA, EU AI Act, CSSF). Detection is rules-first (deterministic
policy-as-code); statistics are a secondary signal, never the sole detector.

## Layout
See `README.md`'s Repository layout tree for the directory map.
- `spec/`, `design/`, `evidence/` — **transient SDLC pipeline artifacts**
  for the CURRENT in-flight change under this two-gate model (see below),
  not permanent product documentation. They get regenerated per pipeline
  run. Product-level design docs live in `docs/` instead
  (`docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/COMPLIANCE.md`).

## Commands
All toolchain commands live in `.claude/sdlc.env` — read it; never guess commands.

## SDLC operating model (two human gates)
- Gate 1: human writes requirements; spec-agent produces spec/; human creates
  `spec/.signed-off`. Spec is then hook-frozen.
- Everything between gates is agent-run via the `sdlc-pipeline` skill.
- Gate 2: human approves `evidence/GATE2_BUNDLE.md`; prod apply happens only in
  CI behind a required-reviewer environment.

## Non-negotiables (enforced by hooks — listed here for context, not as the enforcement)
- No `terraform apply` / prod deployment from any agent session.
- No force-push. No edits to frozen spec/. No secrets in code or logs.
- Writer never reviews own work: reviews go to code-reviewer / security-reviewer.

## Conventions
- Findings are always `Finding` objects carrying `control_refs`; never raw
  anomaly scores surfaced to a user without an explanation.
- Detection is policy-first: `detection/policy.py` (deterministic) runs
  before `detection/baseline.py` (statistical/advisory) — baseline never
  overrides a policy verdict.
- New collector front-ends normalize into the single `AgentEvent` schema
  (`schema/events.py`) — no transport-specific fields leak past `parsers.py`.
