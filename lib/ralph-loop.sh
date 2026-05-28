#!/bin/bash
# ralph-loop — fresh-context-per-iteration loop body.
# Runnable from any directory that contains a .ralph/ scaffold.

set -e

RALPH_DIR=".ralph"
PLAN="$RALPH_DIR/plan.md"
PROMPT="$RALPH_DIR/ralph.prompt.md"
CONFIG="$RALPH_DIR/config"
LOG_DIR="$RALPH_DIR/logs"

if [[ ! -d "$RALPH_DIR" ]]; then
  echo "ralph: no .ralph/ in $(pwd). Run /ralph-init first." >&2
  exit 1
fi
for f in "$PLAN" "$PROMPT" "$CONFIG"; do
  [[ -f "$f" ]] || { echo "ralph: missing $f" >&2; exit 1; }
done

# shellcheck disable=SC1090
source "$CONFIG"

mkdir -p "$LOG_DIR"

# Normalize grep -c to a single integer. Adapted from
# research/ralph-claude-code/ralph_loop.sh:122-133.
_safe_count() {
  local pattern="$1" file="$2" count
  count=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
  count=${count//[^0-9]/}
  echo "${count:-0}"
}

# Extract total_cost_usd from a JSON log without requiring jq.
_extract_cost() {
  local log="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.total_cost_usd // 0' "$log" 2>/dev/null || echo "0"
  else
    grep -oE '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9.]+' "$log" 2>/dev/null \
      | head -1 \
      | grep -oE '[0-9.]+$' \
      || echo "0"
  fi
}

loop_count=0
cumulative_cost="0"

trap 'echo; echo "ralph: interrupted at iteration $loop_count."; exit 130' INT TERM

while :; do
  remaining=$(_safe_count "^- \[ \]" "$PLAN")
  if [[ "$remaining" -eq 0 ]]; then
    echo "ralph: plan is empty after $loop_count iteration(s). Done."
    exit 0
  fi

  loop_count=$((loop_count + 1))
  if [[ "$loop_count" -gt "$RALPH_MAX_ITERATIONS" ]]; then
    echo "ralph: hit RALPH_MAX_ITERATIONS=$RALPH_MAX_ITERATIONS with $remaining item(s) still open." >&2
    exit 1
  fi

  ts=$(date +%s)
  log_file="$LOG_DIR/iter-${loop_count}-${ts}.json"
  echo "ralph: iter $loop_count starting ($remaining open, model=$RALPH_MODEL)"

  # Fresh context every iteration: --bare skips auto-discovery, no --continue.
  # `< /dev/null` prevents SIGTTIN when backgrounded (lifted from
  # research/ralph-claude-code/ralph_loop.sh:1686). `|| true` suppresses set -e
  # on non-zero claude exit (lifted from research/ralph/ralph.sh:92).
  claude --bare -p "$(cat "$PLAN")" \
    --append-system-prompt-file "$PROMPT" \
    --max-turns "$RALPH_MAX_TURNS" \
    --max-budget-usd "$RALPH_BUDGET_USD" \
    --permission-mode "$RALPH_PERMISSION_MODE" \
    --model "$RALPH_MODEL" \
    --output-format json \
    < /dev/null \
    > "$log_file" 2>&1 \
    || true

  iter_cost=$(_extract_cost "$log_file")
  cumulative_cost=$(awk -v a="$cumulative_cost" -v b="$iter_cost" 'BEGIN { printf "%.4f", a + b }')
  echo "ralph: iter $loop_count done (\$${iter_cost} this iter, \$${cumulative_cost} cumulative)"
done
