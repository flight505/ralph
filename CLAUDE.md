# ralph

Long-running agent loop for Claude Code, modeled on Geoffrey Huntley's Ralph pattern. The discipline is brutal simplicity: **a stable prompt + a mutable plan + a loop that runs until the plan is empty.**

---

## Why this exists

This is a fresh rebuild after two previous attempts (`../harness/` and `../sdk-bridge/`) drifted into wizard-driven, multi-agent, YAML-DSL territory. Both have one slash command on the surface but bury the user under 6–25 distinct configuration concepts. This plugin commits to **at most 3 slash commands** and rejects every feature that doesn't earn its place against that budget.

The previous attempts also replaced the long-running loop with native Agent Teams (parallel teammates inside one Claude session). That solves throughput, not endurance. A long-running agent should survive context compaction, crashes, and overnight runs — not just fan work out within one session.

---

## Reference material — `research/`

Two reference implementations are cloned into `research/` for study:

| Path | Repo | Why it's here |
|---|---|---|
| `research/ralph/` | `snarktank/ralph` | The pure bash Ralph — closest to the canonical pattern |
| `research/ralph-claude-code/` | `frankbria/ralph-claude-code` | A Claude Code-shaped variant |

**You can copy or adapt code from `research/` into this plugin.** They exist precisely so we don't reinvent what's already been figured out. Cite the source when you adapt (`# adapted from research/ralph/ralph.sh:14`).

`research/` is in `.gitignore` — it will not be committed to this plugin's repo. It is study material, not source.

---

## Rules of engagement — READ BEFORE WRITING CODE

Before writing any non-trivial code or making any architectural decision, **you must**:

1. **Spawn the `code-studier` agent** with your question. It reads the reference repos and returns patterns + file:line citations. Do this before deciding loop structure, prompt format, state file shape, error handling, signal trapping, exit conditions, or anything else where the references might already have a good answer.

2. **Use the `claude-docs-skill`** for any question about Claude Code CLI flags, hooks, `plugin.json` schema, agent frontmatter, subagent behavior, `claude -p`, MCP, Agent SDK, or the Claude API. Do not WebFetch the docs site if this skill covers it.

If you skip these steps you will repeat the mistakes that made `../harness/` and `../sdk-bridge/` too complicated. The whole point of `research/` and `code-studier` is that the canonical Ralph pattern has been figured out twice already — by people who didn't fall into the wizard trap. Lean on their work.

---

## The 3-command budget

This plugin will ship with **no more than three slash commands.** This is non-negotiable.

When tempted to add a fourth command:

1. First try to collapse two existing commands into one.
2. Then try to remove the feature entirely.
3. Then consider an argument flag, hook, or skill instead of a new command.
4. If after all of that you still need a fourth command, stop and reconsider the design — something upstream is wrong.

Hooks, skills, and agents are also bounded. The previous attempts failed by adding **14 agents and 10+ hooks** — these don't count as "free" just because they aren't commands. Each one is configuration surface the user must understand.

---

## Anti-patterns (from the previous attempts)

- **No YAML DSLs.** No `workflow.yaml`, no phase types, no condition expressions, no state schemas.
- **No multi-agent orchestration** unless it survives the 3-command budget. Agent Teams is a different problem space (parallel throughput within one session) and is what bloated `../harness/`.
- **No multi-checkpoint wizards.** `../sdk-bridge/commands/start.md` is a 6-checkpoint interactive wizard fronting one slash command. Don't.
- **No dashboards or monitoring UIs.** A long-running loop's status fits in `git log` and at most one small state file.
- **No hardware target configuration, no SSH targets, no provider lock-in.** If the loop body needs a specific environment, the user sets it up in their shell — not in the plugin.
- **No PRD generators, no dependency graphs, no story-format enforcement.** The plan is a flat markdown checklist. That is the entire schema.
- **No backwards-compatibility shims, no deprecation notices, no `// removed` comments.** This is v0.1.0 and a clean room.

---

## Stack

- Bash (3.2 compatible — macOS default shell ships with bash 3.2)
- `claude -p` (CLI headless mode) — see `claude-docs-skill` for flags
- `jq` for any JSON parsing
- Nothing else without justification

---

## See also

- `../harness/CLAUDE.md` — previous attempt at composable harness engineering. Read this to understand what *not* to do.
- `../sdk-bridge/CLAUDE.md` — previous PRD-driven multi-agent attempt. Same.
- `research/ralph/README.md` — the canonical bash Ralph (study via `code-studier`).
- `research/ralph-claude-code/README.md` — the Claude Code variant (study via `code-studier`).
- Geoffrey Huntley's original post: <https://ghuntley.com/ralph/>

---

**Status:** v0.1.0 — scaffold only. No commands implemented yet.
**Maintained by:** Jesper Vang (@flight505)
