#!/usr/bin/env bash
# PreToolUse guard — THE compliance chokepoint.
# Reads tool call JSON from stdin. Exit 2 = hard block (agent sees stderr).
# This is deterministic enforcement: agents cannot talk their way past it.
set -euo pipefail

ENV_FILE="$CLAUDE_PROJECT_DIR/.claude/sdlc.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"

# --- 1. Block dangerous bash commands ---
if [ "$TOOL_NAME" = "Bash" ]; then
  CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"
  PATTERNS="${BLOCKED_COMMAND_PATTERNS:-terraform apply|git push.*--force|rm -rf /}"
  if echo "$CMD" | grep -Eq "$PATTERNS"; then
    echo "BLOCKED by guard_pretooluse: command matches a forbidden pattern." >&2
    echo "Production-affecting operations run only via CI with human approval (Gate 2)." >&2
    exit 2
  fi

  # --- 3. Block `git commit` of SENSITIVE_PATHS changes without a same-
  # session security review. Agents may still freely Edit/Write these files
  # (security-reviewer is read-only and can't author the fix itself — it has
  # to review something an agent already drafted), so the gate sits at the
  # commit boundary, not the edit boundary.
  if echo "$CMD" | grep -Eq '(^|[;&|]|`)[[:space:]]*git[[:space:]]+commit([[:space:]]|$)'; then
    STAGED="$(cd "$CLAUDE_PROJECT_DIR" && git diff --cached --name-only 2>/dev/null || true)"
    SENSITIVE_STAGED=""
    for SPATH in ${SENSITIVE_PATHS:-}; do
      while IFS= read -r F; do
        [ -z "$F" ] && continue
        case "$F" in
          *"$SPATH"*) SENSITIVE_STAGED="$SENSITIVE_STAGED
$F" ;;
        esac
      done <<< "$STAGED"
    done
    SENSITIVE_STAGED="$(echo "$SENSITIVE_STAGED" | sed '/^$/d' | sort -u)"
    if [ -n "$SENSITIVE_STAGED" ]; then
      NEWEST_SENSITIVE=0
      while IFS= read -r F; do
        FP="$CLAUDE_PROJECT_DIR/$F"
        [ -f "$FP" ] || continue
        M="$(stat -c %Y "$FP" 2>/dev/null || echo 0)"
        [ "$M" -gt "$NEWEST_SENSITIVE" ] && NEWEST_SENSITIVE="$M"
      done <<< "$SENSITIVE_STAGED"

      NEWEST_REVIEW=0
      if [ -d "$CLAUDE_PROJECT_DIR/review" ]; then
        for RF in "$CLAUDE_PROJECT_DIR"/review/SECURITY_*.md; do
          [ -f "$RF" ] || continue
          M="$(stat -c %Y "$RF" 2>/dev/null || echo 0)"
          [ "$M" -gt "$NEWEST_REVIEW" ] && NEWEST_REVIEW="$M"
        done
      fi

      if [ "$NEWEST_REVIEW" -le "$NEWEST_SENSITIVE" ]; then
        echo "BLOCKED: staged commit touches SENSITIVE_PATHS file(s) with no" >&2
        echo "review/SECURITY_*.md newer than the edit:" >&2
        echo "$SENSITIVE_STAGED" >&2
        echo "Dispatch security-reviewer on the diff and write its verdict to" >&2
        echo "review/SECURITY_<name>.md before committing." >&2
        exit 2
      fi
    fi
  fi
fi

# --- 2. Block edits to frozen paths (spec/ after sign-off) ---
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
  # Windows tool calls send backslash-delimited paths (e.g. C:\repo\spec\SPEC.md).
  # FROZEN_PATHS/SENSITIVE_PATHS are forward-slash globs — normalize before
  # matching, or this check silently never fires on Windows.
  FILE_PATH="${FILE_PATH//\\//}"
  LOCK_FILE="$CLAUDE_PROJECT_DIR/spec/.signed-off"
  if [ -f "$LOCK_FILE" ]; then
    for FROZEN in ${FROZEN_PATHS:-spec/}; do
      case "$FILE_PATH" in
        *"$FROZEN"*)
          echo "BLOCKED: '$FILE_PATH' is under frozen path '$FROZEN' (spec is signed off)." >&2
          echo "Changing requirements requires a human to delete spec/.signed-off (Gate 1 re-entry)." >&2
          exit 2 ;;
      esac
    done
  fi
fi

exit 0
