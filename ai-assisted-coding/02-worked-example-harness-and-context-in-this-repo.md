# Worked Example: The Harness and Context Design Behind This Repo's Own SDLC

Part 1 defined harness and context engineering in the abstract. This post
points at the actual files — all of them are in this repo under
[`.claude/`](../.claude), copied verbatim from the product repo, not
paraphrased. Agent Sentinel is built and maintained by AI coding agents
under a two-gate SDLC (see [`CLAUDE.md`](../CLAUDE.md)), and the `.claude/`
directory *is* the harness plus the context-engineering design for that
process — not a demo of the concepts, the load-bearing implementation of
them.

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
  (`terraform apply`, `git push --force`, `rm -rf /`, ...), if a `git commit`
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
short list outright (`terraform apply*`, `git push --force*`, reading
`.env*` or anything matching `*secret*`) before a hook even runs, and the
ten agents under `.claude/agents/` (`architect`, `code-reviewer`,
`security-reviewer`, `test-runner`, ...) each declare a narrow `tools:`
list — `agent-evaluator`, for instance, gets `Read, Grep, Glob, Bash` only,
enforced structurally so it *cannot* edit code no matter what its analysis
concludes, because "the evaluator evaluates behavior, reviewers evaluate
code" is a role boundary from `sdlc-pipeline`'s invariants, not a suggestion
in its prompt.

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
- **Scoped-by-default rules.** [`.claude/rules/`](../.claude/rules) are path-scoped via
  frontmatter `globs:` — [`ci-supply-chain.md`](../.claude/rules/ci-supply-chain.md) only loads when workflow files
  are touched, [`mcp-governance.md`](../.claude/rules/mcp-governance.md)'s `globs: ["**/*"]` makes it always-on
  because MCP governance applies everywhere. [`.claude/rules/README.md`](../.claude/rules/README.md) says
  the reasoning plainly: this is "cheaper than putting everything in
  CLAUDE.md." Every rule loaded is a rule that wasn't needed for most tasks
  but would have sat in context anyway under a monolithic-file approach.
- **A hash as a context-integrity check.** Before [Phase 1 starts, the
  pipeline](../.claude/skills/sdlc-pipeline/SKILL.md) records `sha256sum .claude/hooks/* .claude/settings.json`; the
  trust evaluation (Part 3) re-checks that hash at the end. If the
  enforcement layer itself changed mid-run, that's treated as tampering with
  the harness, not a legitimate part of "context" — a detail that shows the
  harness and context-engineering stories aren't actually separate systems
  here, they're checked against each other.

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

Next: [How aligned is this with Google & Kaggle's 5-Day Agents course?](03-alignment-with-the-kaggle-5-day-agents-course.md)
