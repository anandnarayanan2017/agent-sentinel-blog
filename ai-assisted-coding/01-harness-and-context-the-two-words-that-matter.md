# Harness and Context: The Two Words That Actually Matter in AI-Assisted Coding

Most conversations about AI-assisted coding get stuck on the model: which one,
how big its context window is, whether it "hallucinates" less than last
quarter's release. That's the least interesting variable. The same model,
dropped into two different setups, produces wildly different outcomes —
one setup ships regulated fintech code with an audit trail, the other lets
an agent quietly `rm -rf` a directory it misread. The difference isn't the
model. It's the **harness** wrapped around it and the **context** fed into it.

This post defines both terms plainly. The next post walks through a real
harness and a real context-engineering setup — this repository's own —
so the definitions land as something you can point at, not just something
you can recite.

## The harness: deterministic scaffolding around a nondeterministic core

An LLM is a nondeterministic component: give it the same prompt twice and you
may get two different tool calls. A **harness** is everything mechanical
wrapped around that core to make the *system* behave predictably even though
the model inside it doesn't:

- **What tools the agent can even see** — a narrowly scoped agent (say, one
  that only reads and greps) cannot do damage a broadly scoped one could,
  regardless of what the model "decides" to do.
- **Gates that run before and after every tool call** — a pre-check that can
  hard-block a command outright, and a post-check that can react to what just
  happened, both running as plain deterministic code, not model judgment.
- **A permission boundary** — an explicit allow/deny list that isn't a
  suggestion to the model, it's enforced by something the model doesn't
  control.
- **A definition of "done" that isn't the model's opinion** — a check that
  runs when the agent claims to be finished and can refuse to let it stop.

None of this is exotic — it's the same instinct as input validation or a
firewall in any other system. The insight specific to agentic coding is that
the harness has to sit *outside* the model's control entirely. A prompt that
says "never run `terraform apply`" is advice; a hook that inspects the actual
command string and exits with a blocking error code is enforcement. Harnesses
matter precisely because models can be talked into, confused into, or simply
drift into doing the thing you told them not to do in natural language. This
is the same "rules-first, statistics-second" instinct this repository's own
product (an AI-agent behavioral firewall) applies to *other* agents' traffic
— see [`docs/ARCHITECTURE.md`](../../ARCHITECTURE.md) — turned reflexively on
the coding agent itself.

## Context engineering: what the model is allowed to see, right now

If the harness is about what the agent is *allowed to do*, context
engineering is about what the agent *knows* at the moment it decides to do
it. A context window is finite and every token in it is a choice, whether or
not anyone made that choice deliberately. Left unmanaged, a long-running
agentic session accumulates irrelevant history, stale file reads, and
repeated failed attempts — a failure mode commonly called **context rot**:
the signal-to-noise ratio inside the window degrades until the agent starts
making worse decisions not because the model got worse, but because what it's
looking at got worse.

Context engineering is the discipline of deliberately managing that window
instead of letting it accumulate by default. In practice that means drawing
a few real distinctions:

- **Session vs. memory.** A session is the live, disposable back-and-forth of
  the current run. Memory is what should survive past it — a decision, a
  constraint, a fact — written somewhere durable instead of trusted to still
  be "in mind" three hundred messages later.
- **Isolation.** Work that produces a lot of noisy intermediate output (a
  test run, a broad search, a long build log) belongs in a subagent whose
  verbose output never touches the main thread — only its conclusion does.
- **Compaction over accumulation.** When a long-running thread starts
  repeating itself or re-reading files it already read, the fix isn't a
  bigger context window, it's summarizing what's been learned into a durable
  artifact and continuing from *that*, not from the increasingly noisy
  conversation.
- **Scoped-by-default loading.** Not every convention needs to be in context
  for every task. Loading a rule only when it's relevant to the files being
  touched is cheaper and cleaner than one giant always-on prompt.

Notice these aren't abstract ideas — each one maps onto a concrete mechanism
you can build: a durable state file instead of relying on conversational
memory, a subagent boundary instead of one long thread, a path-scoped
convention file instead of one monolithic instructions file. Part 2 shows all
four of these mechanisms as they actually exist in this repository's
`.claude/` configuration.

## Why both, together

A harness with no context discipline still lets the model make bad calls
inside its allowed sandbox — it just fails safely instead of failing openly.
Context discipline with no harness is just a well-organized way to feed
instructions to a system that can still be argued out of following them.
Durable, auditable AI-assisted coding — the kind you'd trust in a regulated
environment — needs both: a deterministic boundary the model cannot argue
its way past, and a deliberately curated view of the world so the model's
*judgment*, operating inside that boundary, stays sound.

Next: [Worked example — the harness and context design behind this
repository's own SDLC pipeline](02-worked-example-harness-and-context-in-this-repo.md).
