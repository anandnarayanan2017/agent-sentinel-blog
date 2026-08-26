#!/usr/bin/env bash
# PostToolUse — deterministic hygiene. Formatting/linting is never
# "Claude remembered to"; it always happens after Edit/Write.
set -uo pipefail

ENV_FILE="$CLAUDE_PROJECT_DIR/.claude/sdlc.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"

# NOTE: *.py only, enforced by the inner if/elif below — ruff also handles
# .pyi/.ipynb, but this repo has none today. If either type is added later,
# this gate will silently skip them (no format/lint enforcement, but also no
# corruption risk either way).
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  cd "$CLAUDE_PROJECT_DIR"
  # Scope whole-repo commands (conventionally end in a bare ".") to just the
  # edited file when we have one — running ruff over the entire repo on every
  # single Edit/Write reformats unrelated files as a side effect.
  FMT_CMD="${FORMAT_CMD:-true}"
  LNT_CMD="${LINT_CMD:-true}"
  # FORMAT_CMD/LINT_CMD are language-specific (ruff, here, for PRIMARY_LANGUAGE
  # python). Running a Python formatter against a non-.py file is not a no-op:
  # ruff format will happily "format" any file whose lines are coincidentally
  # valid Python syntax (e.g. sdlc.env's KEY="value" lines), silently
  # corrupting it (spaces around `=`, paren line-wrapping) since this hook's
  # own stderr is suppressed. Only run the per-file path against .py files.
  if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] && [[ "$FILE_PATH" == *.py ]]; then
    # File path is untrusted (agent/tool-controlled) — never let it reach the
    # shell parser. Word-split only the trusted FORMAT_CMD/LINT_CMD config and
    # pass the path as a literal argument, not through eval.
    read -ra FMT_ARR <<< "${FMT_CMD% .}"
    read -ra LNT_ARR <<< "${LNT_CMD% .}"
    "${FMT_ARR[@]}" "$FILE_PATH" >/dev/null 2>&1 || true
    LINT_OUT="$("${LNT_ARR[@]}" "$FILE_PATH" 2>&1)" || echo "Lint issues detected:
$LINT_OUT" >&2
  elif [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    # A real, existing file that isn't .py — nothing to format/lint for this
    # stack. Do NOT fall through to the whole-repo branch below: that would
    # reformat every Python file in the repo as a side effect of editing an
    # unrelated file (the exact bug this per-file scoping exists to prevent).
    :
  else
    # No usable file_path (rare for Edit/Write) — whole-repo fallback.
    eval "$FMT_CMD" >/dev/null 2>&1 || true
    # Lint failures are surfaced to the agent (stderr), not blocking (exit 0):
    LINT_OUT="$(eval "$LNT_CMD" 2>&1)" || echo "Lint issues detected:
$LINT_OUT" >&2
  fi
fi

exit 0
