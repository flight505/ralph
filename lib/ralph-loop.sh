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
  echo "ralph: no .ralph/ in $(pwd). Run /ralph:init first." >&2
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

# Read one top-level scalar field from a result JSON. Prints one line, or
# nothing if the field is absent or the file is not JSON. jq if available,
# else a grep good enough for the flat fields the loop reads.
_json_field() {
  local field="$1" log="$2" value=""
  if command -v jq >/dev/null 2>&1; then
    value=$(jq -r ".$field // empty" "$log" 2>/dev/null | head -n1)
  else
    value=$(grep -oE "\"$field\"[[:space:]]*:[[:space:]]*(\"([^\"\\\\]|\\\\.)*\"|[^,}[:space:]]+)" "$log" 2>/dev/null \
      | head -n1 \
      | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*//; s/^"(.*)"$/\1/' \
      || true)
  fi
  printf '%s\n' "$value"
}

# Extract total_cost_usd from a JSON log. Always exactly one numeric line,
# even if the log is empty or not JSON.
_extract_cost() {
  local cost
  cost=$(_json_field total_cost_usd "$1")
  [[ "$cost" =~ ^[0-9]+(\.[0-9]+)?$ ]] || cost="0"
  echo "$cost"
}

loop_count=0
cumulative_cost="0"
stale_count=0

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
  err_file="$LOG_DIR/iter-${loop_count}-${ts}.stderr"
  plan_before=$(cat "$PLAN")
  echo "ralph: iter $loop_count starting ($remaining open, model=$RALPH_MODEL)"

  # Fresh context every iteration comes from never passing --continue.
  # Deliberately not --bare: bare mode reads neither OAuth nor keychain
  # login, so subscription users get "Not logged in", and it also hides
  # the project's CLAUDE.md, which the prompt tells the model to follow.
  # The target repo's hooks and settings stay on: they are the project's
  # own guard rails.
  # `< /dev/null` prevents SIGTTIN when backgrounded (lifted from
  # research/ralph-claude-code/ralph_loop.sh:1686). Stderr goes to its own
  # file so the JSON log stays parseable. `|| claude_rc=$?` suppresses
  # set -e on non-zero claude exit (adapted from research/ralph/ralph.sh:92).
  claude_rc=0
  claude -p "$(cat "$PLAN")" \
    --append-system-prompt-file "$PROMPT" \
    --max-turns "$RALPH_MAX_TURNS" \
    --max-budget-usd "$RALPH_BUDGET_USD" \
    --permission-mode "$RALPH_PERMISSION_MODE" \
    --model "$RALPH_MODEL" \
    --output-format json \
    < /dev/null \
    > "$log_file" 2> "$err_file" \
    || claude_rc=$?

  iter_cost=$(_extract_cost "$log_file")
  cumulative_cost=$(awk -v a="$cumulative_cost" -v b="$iter_cost" 'BEGIN { printf "%.4f", a + b }')
  echo "ralph: iter $loop_count done (\$${iter_cost} this iter, \$${cumulative_cost} cumulative)"

  # Stop on a failed iteration instead of re-running it up to the cap.
  # Auth failures report subtype "success" with is_error true, so read both.
  is_error=$(_json_field is_error "$log_file")
  subtype=$(_json_field subtype "$log_file")
  result=$(_json_field result "$log_file")
  if [[ "$claude_rc" -ne 0 || "$is_error" == "true" || ( -n "$subtype" && "$subtype" != "success" ) ]]; then
    echo "ralph: iter $loop_count failed (exit=$claude_rc, subtype=${subtype:-none})." >&2
    [[ -n "$result" ]] && echo "ralph: result: $result" >&2
    [[ -s "$err_file" ]] && echo "ralph: stderr: $(tail -n 5 "$err_file")" >&2
    echo "ralph: see $log_file and $err_file." >&2
    exit 1
  fi

  # No-progress guard: two iterations in a row that leave plan.md untouched
  # means the model is stuck on an item (impossible, ambiguous, or out of turns).
  if [[ "$(cat "$PLAN")" == "$plan_before" ]]; then
    stale_count=$((stale_count + 1))
  else
    stale_count=0
  fi
  if [[ "$stale_count" -ge 2 ]]; then
    echo "ralph: no progress in $stale_count consecutive iterations, stopping." >&2
    [[ -n "$result" ]] && echo "ralph: last result: $result" >&2
    exit 1
  fi
done
