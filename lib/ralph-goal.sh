#!/bin/bash
# ralph-goal — single-session /goal-driven Ralph variant.
# One `claude -p` process whose built-in evaluator decides when the goal holds.
# Unlike ralph-loop.sh, this is NOT --bare: /goal depends on the hooks subsystem.

set -e

if [[ $# -eq 0 ]]; then
  echo "ralph-goal: missing goal condition." >&2
  echo "usage: bash ralph-goal.sh <condition>" >&2
  exit 2
fi

# Defaults; overridden by .ralph/config if present.
RALPH_MODEL="sonnet"
RALPH_PERMISSION_MODE="dontAsk"
# Whole-session cap. RALPH_BUDGET_USD in the same config is the loop's
# per-iteration cap and is deliberately not used here.
RALPH_GOAL_BUDGET_USD="5.00"

CONFIG=".ralph/config"
if [[ -f "$CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi
: "${RALPH_GOAL_BUDGET_USD:=5.00}"

GOAL="$*"
echo "ralph-goal: starting (\$${RALPH_GOAL_BUDGET_USD} cap, model=$RALPH_MODEL)"
echo "ralph-goal: condition = $GOAL"

claude -p "/goal $GOAL" \
  --permission-mode "$RALPH_PERMISSION_MODE" \
  --model "$RALPH_MODEL" \
  --max-budget-usd "$RALPH_GOAL_BUDGET_USD" \
  < /dev/null
