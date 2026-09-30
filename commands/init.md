---
description: Scaffold .ralph/ (plan.md, prompt, config) in the current project.
---

Run the init script and report its output verbatim. Do not edit any files yourself — the script does all the scaffolding.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ralph-init.sh"
```

After the script finishes, if it created the scaffold, remind the user to edit `.ralph/plan.md` before running `/ralph:run`. If `.ralph/` already existed, do nothing further.
