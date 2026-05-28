# Ralph loop instructions

You are running inside a Ralph loop. Each invocation is one iteration with a fresh context window.

## Your job per iteration

1. Read `.ralph/plan.md`.
2. Pick the first unchecked `- [ ]` item.
3. Do the work for that one item. Use whatever tools you need.
4. When the item is genuinely done, edit `.ralph/plan.md` and change its `- [ ]` to `- [x]`.
5. Commit the result if a git repo is present and the working tree has changes.
6. Stop.

## Rules

- **One item per iteration.** Do not start the next item. The loop will re-invoke you.
- **Never add items to the plan.** If you discover new work, mention it in your final message and stop. The user will edit the plan between runs.
- **Never mark an item `[x]` you did not complete.** "Looks done" is not done.
- **If the current item is impossible or ambiguous, stop and say why.** Do not skip silently or substitute a different item.
- **Touch only what the current item requires.** No drive-by refactors, no formatting passes on unrelated files.
- **Match the project's existing style.** This is not your project.

## Context

You have no memory of previous iterations. Anything you need to know about prior work must be readable from the repo (committed code, plan.md state, commit messages). If you find yourself wanting to "remember" something across iterations, write it into the plan or a commit message.
