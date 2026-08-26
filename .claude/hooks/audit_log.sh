#!/usr/bin/env bash
# Agent-behavior telemetry (course Day 4 / continuous evaluation):
# append-only JSONL of every tool call — the raw data the agent-evaluator
# and any external monitor (e.g. Agent Sentinel) consumes for drift,
# tool-misuse, and blocked-attempt analysis.
set -uo pipefail
INPUT="$(cat)"
AUDIT_DIR="$CLAUDE_PROJECT_DIR/.claude/audit"
mkdir -p "$AUDIT_DIR"
PHASE="$(cat "$CLAUDE_PROJECT_DIR/.claude/pipeline-state/phase" 2>/dev/null || echo unknown)"
echo "$INPUT" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg phase "$PHASE" \
  '{ts:$ts, phase:$phase, tool:(.tool_name // "?"), input_summary:((.tool_input.command // .tool_input.file_path // "") | tostring | .[0:200])}' \
  >> "$AUDIT_DIR/agent_behavior.jsonl" 2>/dev/null || true
exit 0
