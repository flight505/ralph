---
description: Run the Ralph loop. Each iteration is a fresh `claude -p` with no carried context.
---

Start the Ralph loop in the current working directory.

1. Run the loop with the Bash tool:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/ralph-loop.sh"
   ```

2. The loop prints one status line per iteration and writes per-iteration JSON to `.ralph/logs/`. It exits when `.ralph/plan.md` has zero `- [ ]` items, when `RALPH_MAX_ITERATIONS` is hit, or on Ctrl+C.

3. If the Bash tool's timeout cuts the run short before the plan is empty, tell the user the loop is best run from a real shell for long jobs:

   ```bash
   bash ~/.claude/plugins/ralph/lib/ralph-loop.sh
   ```

   The script picks up where it left off — there is no state to resume, just whatever `[ ]` items remain in `.ralph/plan.md`.

4. If `.ralph/` does not exist or `.ralph/plan.md` is missing, the script will say so and exit. Tell the user to run `/ralph-init` first.
