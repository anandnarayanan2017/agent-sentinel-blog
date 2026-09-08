#!/usr/bin/env bash
# Stop hook — the agent may not declare "done" while unit tests are red.
# Only active when a pipeline phase marker says we're in build/debug.
# Includes a circuit breaker so a hopeless run halts with a report
# instead of looping forever.
set -uo pipefail

ENV_FILE="$CLAUDE_PROJECT_DIR/.claude/sdlc.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

PHASE_FILE="$CLAUDE_PROJECT_DIR/.claude/pipeline-state/phase"
[ -f "$PHASE_FILE" ] || exit 0
PHASE="$(cat "$PHASE_FILE")"
case "$PHASE" in build|debug|test) ;; *) exit 0 ;; esac

# Circuit breaker
ITER_FILE="$CLAUDE_PROJECT_DIR/.claude/pipeline-state/stop_iterations"
ITER=$(( $(cat "$ITER_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$ITER" > "$ITER_FILE"
MAX="${MAX_DEBUG_ITERATIONS:-5}"
if [ "$ITER" -gt "$MAX" ]; then
  echo "Circuit breaker: $MAX iterations reached. Halting for human review." >&2
  rm -f "$ITER_FILE"
  exit 0   # allow stop — pipeline skill writes HALT report
fi

cd "$CLAUDE_PROJECT_DIR"
if ! eval "${UNIT_TEST_CMD:-true}" >/tmp/stopgate.out 2>&1; then
  echo "Stop blocked: unit tests failing (iteration $ITER/$MAX). Fix before finishing:" >&2
  tail -40 /tmp/stopgate.out >&2
  exit 2
fi

rm -f "$ITER_FILE"
exit 0
