# Worked Example: The Harness and Context Design Behind This Repo's Own SDLC

Part 1 defined harness and context engineering in the abstract. This post
points at the actual files. Agent Sentinel is built and maintained by AI
coding agents under a two-gate SDLC (see [`CLAUDE.md`](../CLAUDE.md)), and
the `.claude/` directory *is* the harness plus the context-engineering
design for that process — not a demo of the concepts, the load-bearing
implementation of them.

> **What is and isn't in this public mirror.** The files linked below —
> [`.claude/hooks/`](../.claude/hooks), [`.claude/rules/`](../.claude/rules),
> [`.claude/sdlc.env`](../.claude/sdlc.env),
> [`.claude/settings.json`](../.claude/settings.json), and the
> `sdlc-pipeline` / `effective-trust` skills — are copied from the product
> repo and are byte-identical to it (verified by git blob hash), with one
> deliberate exception noted at the end of this post. The **ten agent
> definitions** under `.claude/agents/` and four further skills
> (`new-adr`, `uat-evidence`, `design-from-adr`, `deploy`) live only in the
> product repository, which is private. Where this post describes them, it
> is describing files you cannot open from here.

## The harness: hooks, permissions, and scoped subagents

[`.claude/settings.json`](../.claude/settings.json) wires four hook points to shell scripts under
`.claude/hooks/`:

```
PreToolUse  (Bash|Edit|Write)  -> guard_pretooluse.sh
PreToolUse  (Bash)              -> slopsquat_guard.sh
PostToolUse (Edit|Write)        -> format_posttooluse.sh
PostToolUse (*)                  -> audit_log.sh
Stop                              -> stop_gate.sh
```

Each one is plain deterministic shell code, not a model asked nicely to
behave:

- **[`guard_pretooluse.sh`](../.claude/hooks/guard_pretooluse.sh)** reads the tool call as JSON off stdin and exits
  `2` (a hard block, agent sees stderr and cannot proceed) if a `Bash`
  command matches `BLOCKED_COMMAND_PATTERNS` from [`.claude/sdlc.env`](../.claude/sdlc.env)
  (a production Terraform apply, a force-push, a recursive root delete, ...),
  if a `git commit`
  stages a `SENSITIVE_PATHS` file with no `review/SECURITY_*.md` newer than
  that file's last edit, or if an `Edit`/`Write` targets anything under
  `spec/` after `spec/.signed-off` exists — the frozen-spec rule from
  `CLAUDE.md` enforced as code, not as a norm agents are trusted to
  remember.
- **[`slopsquat_guard.sh`](../.claude/hooks/slopsquat_guard.sh)** intercepts `pip install` / `npm install` and
  friends, hits the real PyPI/npm registry, and blocks any package that
  doesn't exist (likely a hallucinated dependency name) or is younger than
  `SLOPSQUAT_MIN_AGE_DAYS` (a fresh package is typosquat/slopsquat risk). The
  file's own comment calls this out explicitly as "course Day 4" — more on
  that in Part 3.
- **[`stop_gate.sh`](../.claude/hooks/stop_gate.sh)** refuses to let the agent declare itself "done" while
  `.claude/pipeline-state/phase` says `build`/`debug`/`test` and
  `UNIT_TEST_CMD` is still failing — with its own circuit breaker
  (`MAX_DEBUG_ITERATIONS`) so a hopeless loop halts with a report instead of
  spinning forever.
- **[`audit_log.sh`](../.claude/hooks/audit_log.sh)** appends every tool call to
  `.claude/audit/agent_behavior.jsonl` unconditionally, on every hook —
  the substrate the trust evaluation in Part 3 is built on.

Layered on top, `.claude/settings.json`'s `permissions.deny` hard-denies a
short list outright (production applies, force-pushes, reading
`.env*` or anything matching `*secret*`) before a hook even runs, and the
ten agents under `.claude/agents/` each declare a narrow `tools:` list.
Those declarations are worth quoting exactly, because the scoping is the
point:

| Agent | `tools:` | Model | Why scoped this way |
|---|---|---|---|
| `spec-agent` | Read, Write, Grep, Glob | opus | Writes the contract; no shell |
| `architect` | Read, Grep, Glob, Write | opus | Investigates broadly, writes only `DESIGN.md` |
| `adr-critic` | Read, Grep, Glob | opus | **No Write at all** — a critic that cannot edit what it critiques |
| `code-reviewer` | Read, Grep, Glob, Bash | sonnet | "Read-only: you report, you never patch" |
| `security-reviewer` | Read, Grep, Glob, Bash | opus | Same — the gate cannot author the fix it approves |
| `test-writer` | Read, Write, Grep, Glob, Bash | sonnet | Writes tests from spec, deliberately not from implementation |
| `test-runner` | Bash, Read, Grep | haiku | Cheapest model; returns only failures, keeping logs out of the main context |
| `debugger` | Read, Edit, Write, Grep, Glob, Bash | sonnet | The only agent with a full write loop — and it is circuit-broken |
| `uat-runner` | Bash, Read, Write, Grep | sonnet | Executes frozen UAT definitions; "you do not reinterpret, weaken, or skip" |
| `agent-evaluator` | Read, Grep, Glob, Bash | opus | Read-only by construction — it judges behavior, so it must not be able to change code |

`agent-evaluator` getting `Read, Grep, Glob, Bash` and no write tool is the
clearest case: it *cannot* edit code no matter what its analysis concludes,
because "the evaluator evaluates behavior, reviewers evaluate code" is a role
boundary from `sdlc-pipeline`'s invariants enforced structurally, not a
suggestion in its prompt. The same instinct explains why `adr-critic` has no
`Write` and why the two reviewers are read-only: a reviewer that can silently
patch the thing it reviews is not a gate.

This is the harness definition from Part 1, concretely instantiated: tool
visibility scoped per agent, gates before and after every call, a permission
boundary the model doesn't control, and a definition of "done" the model
doesn't get to assert unilaterally.

## Context engineering: sessions, memory, and scoped loading

The same directory encodes the context side just as concretely:

- **Memory that outlives the session.** `.claude/pipeline-state/phase` is a
  one-line file recording which of the ten SDLC phases the pipeline is in —
  durable state a crashed run can resume from, instead of trusting a
  conversation to still remember where it left off. `spec/`, `design/`, and
  `evidence/` are the same idea at a larger grain: each phase's output is
  written to a file *before* the next phase starts, so the next phase reads
  from that artifact rather than from upstream conversational history. Once
  `spec/.signed-off` exists, `spec/` is frozen (enforced by the hook above)
  — a piece of memory the harness makes tamper-evident.
- **Isolation via subagents.** `sdlc-pipeline`'s own invariants say it
  directly: *"keep verbose output in subagents; if the main thread degrades
  (repeating itself, re-reading same files), compact/summarize state to the
  phase file and artifacts, then continue from artifacts — never from stale
  conversational memory."* A test run's full log, a broad codebase search, a
  security scan's raw output — all of that stays inside the subagent that
  produced it; only the verdict crosses back into the orchestrating context.
  `test-runner` running on `haiku` and returning *only* failures is that
  principle priced out: the cheap model reads the noisy output so the
  expensive one never has to.
- **Scoped-by-default rules.** [`.claude/rules/`](../.claude/rules) are path-scoped via
  frontmatter `globs:` — [`ci-supply-chain.md`](../.claude/rules/ci-supply-chain.md) only loads when workflow files
  are touched, [`mcp-governance.md`](../.claude/rules/mcp-governance.md)'s `globs: ["**/*"]` makes it always-on
  because MCP governance applies everywhere. [`.claude/rules/README.md`](../.claude/rules/README.md) says
  the reasoning plainly: this is "cheaper than putting everything in
  CLAUDE.md." Every rule loaded is a rule that wasn't needed for most tasks
  but would have sat in context anyway under a monolithic-file approach.
- **A hash as a context-integrity check.** Before [Phase 1 starts, the
  pipeline](../.claude/skills/sdlc-pipeline/SKILL.md) records a fingerprint of `.claude/hooks/*` and
  `.claude/settings.json`; the
  trust evaluation (Part 3) re-checks it at the end. If the
  enforcement layer itself changed mid-run, that's treated as tampering with
  the harness, not a legitimate part of "context" — a detail that shows the
  harness and context-engineering stories aren't actually separate systems
  here, they're checked against each other.

## Postscript: the harness that wasn't running

Everything above was true of the *design* and, for a while, false of the
*deployment*. An architecture review of this repository in September 2026
found all five hooks committed with file mode `644` — not executable — in
both this mirror and the product repository.

That sounds cosmetic. It isn't, because of which way it fails. A `command`
hook is dispatched through the shell by path. A non-executable script exits
**126 ("Permission denied"), not 2** — and Claude Code treats `2` as
*blocking* and every other non-zero exit as a *non-blocking error*. So the
guard did not deny a forbidden command; it permitted it, silently, with
nothing surfaced in the transcript. `slopsquat_guard.sh` waved through
package installs. `stop_gate.sh` let an agent call itself done on red tests.
`audit_log.sh` wrote nothing at all — which quietly removed the substrate
all seven trust pillars are scored from, while the evidence bundle went on
citing them.

Two things are worth taking from it beyond the one-line fix
(`git update-index --chmod=+x .claude/hooks/*.sh`).

First: **the integrity check couldn't see it.** The pipeline hashed hook
*content*, and the content was byte-perfect throughout. Executability isn't
content, so a `sha256sum` fingerprint was structurally blind to it. The fix
was to record `stat -c '%n %a'` alongside the hash and to refuse to start
when any hook is not executable — the change to Pillar 4 in
[`effective-trust`](../.claude/skills/effective-trust/SKILL.md) and Phase 0 of
[`sdlc-pipeline`](../.claude/skills/sdlc-pipeline/SKILL.md). (Those two files
are the deliberate exception to the byte-identical claim at the top of this
post: this mirror carries the fix ahead of the product repo.)

Second: **a rigorous review can still miss it.** The product repo's own
`review/SECURITY_harness_enforcement_fixes.md` had already examined these
exact two hooks in real depth — injection sinks, `set -euo pipefail`
behavior, mtime edge cases, whether backslash normalization failed open or
closed — and concluded that "both real enforcement chokepoints are intact."
Every word of that was correct about the code. Nobody checked whether the
code could execute. The repo had even solved the *neighbouring* problem:
`.gitattributes` pins `*.sh text eol=lf` so a CRLF checkout can't break a
hook. Line endings were governed; the exec bit wasn't.

The generalizable lesson is uncomfortably close to this product's own
thesis. Agent Sentinel exists because a policy that describes correct agent
behavior proves nothing about actual agent behavior — you have to record what
happened. The harness had the same gap about itself: it verified that its
guards *said* the right thing, never that they *ran*. A control you have not
observed firing is a control you are assuming, and the honest fix is the
boring one — assert the precondition, fail closed, and write down what you
saw.

## The pattern worth generalizing

Nothing above is Agent-Sentinel-specific in spirit. The transferable shape
is: put the harness in code the model doesn't author or control (hooks,
permission denies, per-agent tool scoping), and put context discipline in
durable artifacts plus explicit isolation boundaries (phase files, frozen
specs, subagent dispatch, scoped rule loading) rather than in "the model
should remember this." Whether your stack is Claude Code, a custom agent
loop, or something built on Google's ADK, the same two questions are worth
asking of it: *what can this agent's tool calls never do, regardless of what
the model decides?* and *what is this agent looking at right now, and did
anyone actually choose that?*

And now a third, learned the hard way: *how would I know if none of it were
running?*

Next: [How aligned is this with Google & Kaggle's 5-Day Agents course?](03-alignment-with-the-kaggle-5-day-agents-course.md)
