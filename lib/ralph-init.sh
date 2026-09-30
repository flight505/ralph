#!/bin/bash
# ralph-init — scaffold .ralph/ in the current working directory.
# Invoked by the /ralph-init slash command, also runnable directly.

set -e

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATES="$PLUGIN_ROOT/templates"
TARGET=".ralph"

if [[ -d "$TARGET" ]]; then
  echo "ralph: .ralph/ already exists in $(pwd). Not touching it."
  echo "ralph: edit .ralph/plan.md to add items, then run /ralph-run."
  exit 0
fi

mkdir -p "$TARGET/logs"
cp "$TEMPLATES/plan.md"          "$TARGET/plan.md"
cp "$TEMPLATES/ralph.prompt.md"  "$TARGET/ralph.prompt.md"
cp "$TEMPLATES/config"           "$TARGET/config"

# .ralph/ ignores itself. This works in a plain repo, a git worktree (where
# .git is a file), and a subdirectory of a repo, with no repo detection.
printf '*\n' > "$TARGET/.gitignore"

cat <<EOF2
ralph: scaffold ready.

  .ralph/plan.md            — edit this to add your tasks
  .ralph/ralph.prompt.md    — the per-iteration system prompt
  .ralph/config             — model, budget, iteration cap
  .ralph/logs/              — one JSON result + one stderr file per iteration
  .ralph/.gitignore         — keeps .ralph/ out of git

Next:
  1. Edit .ralph/plan.md and replace the example item.
  2. Run /ralph-run to start the loop.
EOF2
