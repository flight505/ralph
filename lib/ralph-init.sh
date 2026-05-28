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

# Add .ralph/ to .gitignore if a repo is present and the entry isn't already there.
if [[ -d .git ]] && [[ -f .gitignore ]] && ! grep -qxF ".ralph/" .gitignore; then
  printf '\n# ralph loop state\n.ralph/\n' >> .gitignore
  echo "ralph: added .ralph/ to .gitignore."
elif [[ -d .git ]] && [[ ! -f .gitignore ]]; then
  printf '# ralph loop state\n.ralph/\n' > .gitignore
  echo "ralph: created .gitignore with .ralph/ entry."
fi

cat <<EOF
ralph: scaffold ready.

  .ralph/plan.md            — edit this to add your tasks
  .ralph/ralph.prompt.md    — the per-iteration system prompt
  .ralph/config             — model, budget, iteration cap
  .ralph/logs/              — one JSONL log per iteration

Next:
  1. Edit .ralph/plan.md and replace the example item.
  2. Run /ralph-run to start the loop.
EOF
