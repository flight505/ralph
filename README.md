# ralph

Long-running agent loop for Claude Code, in the [Ralph pattern](https://ghuntley.com/ralph/).

A stable prompt, a mutable plan, a loop that runs until the plan is empty.

---

## Install

```bash
# As a one-off, from this directory:
claude --plugin-dir .

# Or symlink into your plugins:
ln -s "$PWD" ~/.claude/plugins/ralph
```

---

## Commands

### `/ralph-init`

Scaffolds `.ralph/` in the current working directory:

```
.ralph/
├── plan.md            — flat markdown checklist of tasks
├── ralph.prompt.md    — per-iteration system-prompt rules
├── config             — model, budget, iteration cap
└── logs/              — one JSON file per iteration
```

Adds `.ralph/` to `.gitignore` if a repo is present. Idempotent — does nothing if `.ralph/` already exists.

### `/ralph-run`

Runs the loop. Each iteration is an independent `claude -p` invocation with a **fresh context window**: no `--continue`, no carried conversation. The plan file is the only state between iterations.

The model's job each turn:

1. Read `.ralph/plan.md`
2. Pick the first `- [ ]` item
3. Do the work
4. Edit `.ralph/plan.md` to flip it to `- [x]`
5. Stop

The loop exits when the plan has zero `- [ ]` items, `RALPH_MAX_ITERATIONS` is hit, or Ctrl+C.

### `/ralph-goal <condition>`

Single-session alternate mode. Spawns one `claude -p "/goal <condition>"` process whose built-in evaluator decides when the condition holds. Unlike `/ralph-run`, this rides on **one continued conversation** — useful for shorter, well-scoped work where one session is enough.

```
/ralph-goal every test in test/auth passes and lint is clean
```

---

## When to use which mode

| | `/ralph-run` | `/ralph-goal` |
|---|---|---|
| Context per turn | Fresh every iteration | One continued conversation |
| Exit decided by | Bash grep of `plan.md` for `- [ ]` | Fast-model evaluator after every turn |
| Scales to | Long plans (hours, days, overnight) | Short well-scoped tasks |
| Resistant to context rot | Yes — no context to rot | No — accumulates until auto-compact |
| State between iterations | `plan.md` only | Full conversation |

Default to `/ralph-run` for anything substantial. Reach for `/ralph-goal` when the work is small enough to fit comfortably in one session and the success condition is easy to phrase.

---

## Configuration

`.ralph/config` is a shell-sourceable file with sensible defaults:

```bash
RALPH_MAX_ITERATIONS=100                  # hard cap on loop count
RALPH_MAX_TURNS=10                        # agentic turns per claude -p call
RALPH_BUDGET_USD=2.00                     # per-iteration USD cap
RALPH_MODEL=sonnet                        # sonnet | opus | full model ID
RALPH_PERMISSION_MODE=bypassPermissions   # canonical Ralph: model runs anything
```

The `bypassPermissions` default matches canonical Ralph (snarktank uses `--dangerously-skip-permissions`). It's the only mode where the loop can build a project end-to-end without stalling on the first `npm install` or `pytest`. **Run Ralph in a worktree, a container, or a disposable directory.** Less-risky options (`acceptEdits`, `auto`, `dontAsk`) are documented in the config file.

---

## Subscription note

Until **2026-06-15**, `claude -p` usage on Claude subscriptions counts against the same monthly limits as interactive use. After that date, `-p` usage draws from a separate monthly Agent SDK credit. A runaway Ralph loop on a subscription can push you onto paid overage credits before then — keep `RALPH_BUDGET_USD` set.

Source: [Claude Code headless mode docs](https://docs.claude.com/en/docs/claude-code/headless).

---

## Running long jobs

The slash commands are convenient inside an interactive Claude session, but the Bash tool's timeout will cut runs short. For overnight Ralph, run the loop directly from a shell in `tmux` or `screen`:

```bash
cd <your-project>
bash ~/.claude/plugins/ralph/lib/ralph-loop.sh
```

The script has no resumable state — it just reads `.ralph/plan.md` and picks the next `- [ ]`. Killing and restarting it is safe.

---

## Design rules

Three commands, no hooks, no agents, no MCP servers, no skills. The plan is a flat markdown checklist. If you want to know why these constraints exist, read `CLAUDE.md`.

Reference implementations studied during the rebuild are cloned into `research/` (gitignored): `snarktank/ralph` and `frankbria/ralph-claude-code`.

---

## License

MIT
