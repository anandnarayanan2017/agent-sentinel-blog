#!/usr/bin/env bash
# Slopsquatting defense (course Day 4): intercept package-install commands and
# verify each package EXISTS on its real registry and is not brand-new before
# any agent may install it. Hallucinated dependency names are a primary
# agent-specific supply-chain attack. Exit 2 = hard block.
set -uo pipefail
ENV_FILE="$CLAUDE_PROJECT_DIR/.claude/sdlc.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

INPUT="$(cat)"
[ "$(echo "$INPUT" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"

MIN_AGE_DAYS="${SLOPSQUAT_MIN_AGE_DAYS:-30}"

check_pypi() {
  local pkg="$1"
  local meta; meta="$(curl -fsS "https://pypi.org/pypi/${pkg}/json" 2>/dev/null)" || {
    echo "BLOCKED (slopsquat guard): '${pkg}' not found on PyPI — possibly hallucinated." >&2; return 1; }
  local first; first="$(echo "$meta" | jq -r '[.releases[][].upload_time_iso_8601] | sort | first // empty')"
  if [ -n "$first" ]; then
    local age=$(( ( $(date +%s) - $(date -d "$first" +%s) ) / 86400 ))
    if [ "$age" -lt "$MIN_AGE_DAYS" ]; then
      echo "BLOCKED (slopsquat guard): '${pkg}' is only ${age}d old (<${MIN_AGE_DAYS}d) — typosquat risk. Human must whitelist." >&2; return 1
    fi
  fi
  return 0
}
check_npm() {
  local pkg="$1"
  local meta; meta="$(curl -fsS "https://registry.npmjs.org/${pkg}" 2>/dev/null)" || {
    echo "BLOCKED (slopsquat guard): '${pkg}' not found on npm — possibly hallucinated." >&2; return 1; }
  local created; created="$(echo "$meta" | jq -r '.time.created // empty')"
  if [ -n "$created" ]; then
    local age=$(( ( $(date +%s) - $(date -d "$created" +%s) ) / 86400 ))
    if [ "$age" -lt "$MIN_AGE_DAYS" ]; then
      echo "BLOCKED (slopsquat guard): '${pkg}' is only ${age}d old (<${MIN_AGE_DAYS}d) — typosquat risk. Human must whitelist." >&2; return 1
    fi
  fi
  return 0
}

extract_pkgs() { # strip flags/versions, keep bare names
  echo "$1" | tr ' ' '\n' | grep -vE '^-|^$' | sed 's/[=<>@].*$//' ; }

FAIL=0
if echo "$CMD" | grep -qE '(^|[;&|] *)(pip3? install|uv (pip install|add))'; then
  PKGS="$(echo "$CMD" | sed -E 's/.*(pip3? install|uv pip install|uv add)//')"
  for p in $(extract_pkgs "$PKGS"); do
    echo "$p" | grep -qE '^(-r|\.|/|git\+)' && continue
    echo " ${SLOPSQUAT_WHITELIST:-} " | grep -q " $p " && continue
    check_pypi "$p" || FAIL=1
  done
fi
if echo "$CMD" | grep -qE '(^|[;&|] *)(npm i(nstall)?|yarn add|pnpm add)'; then
  PKGS="$(echo "$CMD" | sed -E 's/.*(npm i(nstall)?|yarn add|pnpm add)//')"
  for p in $(extract_pkgs "$PKGS"); do
    echo "$p" | grep -qE '^(\.|/)' && continue
    echo " ${SLOPSQUAT_WHITELIST:-} " | grep -q " $p " && continue
    check_npm "$p" || FAIL=1
  done
fi

[ "$FAIL" -eq 1 ] && exit 2
exit 0
