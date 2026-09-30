---
description: Run a single-session /goal-driven Ralph. For shorter, well-scoped tasks where one continued conversation is enough.
---

The user supplied this goal condition: `$ARGUMENTS`

If the condition is empty, tell the user the usage is `/ralph-goal <condition>` (for example: `/ralph-goal every test in test/auth passes and lint is clean`), then stop.

Otherwise, run the wrapper:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ralph-goal.sh" "$ARGUMENTS"
```

This spawns a single `claude -p "/goal <condition>"` process. The built-in evaluator runs after every turn until the condition holds or the budget cap (`RALPH_GOAL_BUDGET_USD` from `.ralph/config`, default $5; the loop's per-iteration `RALPH_BUDGET_USD` is not used) is hit. The session is continued — it does **not** get a fresh context per turn. Use `/ralph-run` instead for long plans where context rot is a concern.
