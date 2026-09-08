# SECURITY REVIEW — harness executability (mode) enforcement

**Verdict: APPROVE**
**Branch:** `claude/pim-ai-first-assessment-ht76g1`
**Scope reviewed:** `.claude/hooks/*.sh` (mode change only, 5 files),
`.claude/skills/effective-trust/SKILL.md`, `.claude/skills/sdlc-pipeline/SKILL.md`
**HIGH findings: 0** — nothing blocks the pipeline.

## ⚠ Process caveat — read this first

This review was **not** produced by the `security-reviewer` subagent. That
agent is defined in the product repository
(`.claude/agents/security-reviewer.md`, `tools: Read, Grep, Glob, Bash`,
`model: opus`) and is **not mirrored into this repository**, so the pipeline's
writer≠reviewer invariant could not be satisfied structurally here. It was
written by the same agent that authored the change.

That is a real weakening of the control and is recorded rather than smoothed
over. It is the direct consequence of finding #2 in
`docs/assessments/2026-09-07-ai-first-factory-assessment.md` (`.claude/agents/`
absent from this mirror). Treat this verdict as **defense-in-depth
documentation, not an independent security sign-off**. The same change applied
to the product repository must go through the real `security-reviewer`.

## 1. The defect being fixed

All five hooks were committed mode `100644` (non-executable) in **both** this
mirror and the product repository (`git ls-files -s .claude/hooks/` on
`anandnarayanan2017/agent-sentinel@110e2fb` shows the same).

`.claude/settings.json` dispatches each hook as a `command` by bare path.
Empirically verified against the product repo's checkout:

```
$ echo '{"tool_name":"Bash","tool_input":{"command":"<a blocked pattern>"}}' \
    | sh -c /home/user/agent-sentinel/.claude/hooks/guard_pretooluse.sh
sh: 1: .../guard_pretooluse.sh: Permission denied
exit=126        # expected 2
```

**Severity rationale — this fails OPEN, not closed.** Claude Code treats a
hook exit of `2` as blocking and any other non-zero exit as a non-blocking
error. Exit `126` is therefore *permissive*. A non-executable
`guard_pretooluse.sh` does not block a production-affecting command; it allows
it. The same applies to `slopsquat_guard.sh` (hallucinated-dependency installs
proceed), `stop_gate.sh` (an agent may declare "done" on red tests), and
`audit_log.sh` (no `agent_behavior.jsonl` is written at all — which silently
removes the substrate all seven trust pillars are scored from).

Net effect: `.claude/` reads as a fully governed harness while enforcing
nothing, and a Gate 2 evidence bundle would attest to checks that never ran —
precisely the failure mode `sdlc-pipeline` Phase 0 exists to prevent,
reproduced one layer below where Phase 0 looks.

## 2. The fix, and why it is safe

**(a) `git update-index --chmod=+x .claude/hooks/*.sh`** — mode `100644` →
`100755` on all five. **Zero content change**: blob hashes are byte-identical
before and after and unchanged from the product repo's
(`013795a6`, `493ad1b3`, `e98dda67`, `1532cb0b`, `f416afd0`). No new code
path, no new input surface, no new privilege — the scripts already ran as the
agent's own user when invoked via an interpreter; this only lets the kernel
exec them directly, which is the documented and intended invocation.

Direction of change is **fail-closed**: controls that were silently permitting
now deny. Verified live after the change:

```
blocked pattern  -> exit=2  ("BLOCKED by guard_pretooluse")   # correct
`ls -la`         -> exit=0                                     # correct
```

No behavior is loosened. The only way this change can "break" a workflow is by
blocking something that the guard was always specified to block.

**(b) `effective-trust` Pillar 4 — mode added to the integrity fingerprint.**
Adds `stat -c '%n %a' .claude/hooks/*` alongside the existing `sha256sum`, plus
a fail-closed executability precondition (step 1a) scoring any non-executable
hook as Pillar 4 = 0 / HALT. Documentation and evaluation criteria only; no
executable change. This is what makes (a) non-regressible — the prior
content-only hash provably could not see this defect, since content was
correct throughout.

**(c) `sdlc-pipeline` Phase 0 — records mode alongside content.** Keeps the
recorder and the verifier symmetric. Without this, `effective-trust` would
compare against a baseline that never captured mode.

## 3. Injection / tamper analysis

- No new `eval`, `exec`, or command substitution introduced. (b) and (c) add
  fenced example commands in Markdown; they are documentation the orchestrator
  reads, not strings interpolated with untrusted data.
- `stat -c '%n %a' .claude/hooks/*` and the `[ -x "$h" ]` loop take a fixed
  glob over a repo-controlled directory — no agent- or tool-controlled input
  reaches either.
- The existing chokepoints in `guard_pretooluse.sh` are untouched; section
  ordering (`BLOCKED_COMMAND_PATTERNS` first, then the commit gate) is
  preserved.
- Mode is not a cryptographic control: an agent with `Bash` can `chmod -x` a
  hook mid-run. That is exactly what step 1a's end-of-run re-check is for, and
  why mode now sits inside the recorded fingerprint rather than beside it.

## 4. Non-blocking observations

- **False positive by design, confirmed live.** `BLOCKED_COMMAND_PATTERNS` is
  matched with `grep -Eq` against the entire `tool_input.command` string, so a
  command that merely *contains* a forbidden phrase as quoted text is blocked
  too. Writing this change hit exactly that: a heredoc authoring documentation
  *about* the blocked command was itself blocked (correctly, by the hook that
  had just been re-armed). Fail-closed and therefore acceptable, but worth
  knowing: authoring docs that quote blocked patterns must use a file-write
  tool rather than a shell heredoc. Not a regression — pre-existing behavior,
  merely unobservable while the hooks were inert.
- `.gitattributes` (`*.sh text eol=lf`) already guards shell-script line
  endings. The exec bit is an orthogonal property it does not cover; the two
  are now handled separately and both are noted in `effective-trust`.
- The mtime-based commit gate remains bypassable by construction (as the
  product repo's own `review/SECURITY_harness_enforcement_fixes.md` already
  records). Unchanged by this diff.

## 5. Recommendation to the product repository

The identical defect exists at `anandnarayanan2017/agent-sentinel@110e2fb` and
matters considerably more there, because that repository has live CI, a
`production` environment with required reviewers, and real Terraform paths.
Notably, that repo's existing
`review/SECURITY_harness_enforcement_fixes.md` reviewed these same two hooks in
depth — injection sinks, `set -e` behavior, mtime edge cases — and concluded
"both real enforcement chokepoints are intact." That conclusion was reached
about hook **content**; file mode was never examined. This review exists
because content-correct and effective are not the same property.

Apply (a), (b) and (c) there, through the real `security-reviewer`.
