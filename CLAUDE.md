# ralph

Long-running agent loop for Claude Code, modeled on Geoffrey Huntley's Ralph pattern. The discipline is brutal simplicity: **a stable prompt + a mutable plan + a loop that runs until the plan is empty.**

---

## Why this exists

This is a fresh rebuild after two previous attempts (`../harness/` and `../sdk-bridge/`) drifted into wizard-driven, multi-agent, YAML-DSL territory. Both have one slash command on the surface but bury the user under 6–25 distinct configuration concepts. This plugin commits to **at most 3 slash commands** and rejects every feature that doesn't earn its place against that budget.

The previous attempts also replaced the long-running loop with native Agent Teams (parallel teammates inside one Claude session). That solves throughput, not endurance. A long-running agent should survive context compaction, crashes, and overnight runs — not just fan work out within one session.

## What changed on 2026-05-28 — read before extending Ralph

On the day Ralph v0.1.0 shipped, Anthropic released **Claude Opus 4.8** and **dynamic workflows in Claude Code**. Both reshape Ralph's niche, and any future work on this plugin needs to be honest about it.

- **Dynamic workflows** ([blog](https://claude.com/blog/introducing-dynamic-workflows-in-claude-code)) is, functionally, the official Anthropic answer to "build a project end-to-end unattended." Claude plans the work, spawns tens to hundreds of parallel subagents, runs adversarial verification, and persists progress across interruptions. It survives context rot because *coordination lives outside the conversation*, not because of fresh iterations. The Bun rewrite (Zig → Rust, 750K LOC, 11 days) was done with it. Available on Max, Team, and admin-enabled Enterprise — not Pro.
- **Opus 4.8** is "4× less likely than its predecessor to allow flaws in code to pass unremarked." Part of Ralph's reason for re-running is to give a fresh model another shot at catching what the previous turn missed. Opus 4.8 misses less, which weakens the case for high iteration counts.

**Implications for Ralph:**

1. **Ralph is no longer "the" Ralph pattern.** Dynamic workflows is. Ralph is now one specific point in the design space: user-authored plan, shell-supervised, sub-Max-tier-friendly, transparent bash.
2. **Don't try to "catch up" to dynamic workflows.** Parallel subagents, dynamic planning, adversarial verification, persistent progress — these would all blow the 3-command budget and the bash-only stack. They are not Ralph's niche.
3. **Ralph's niche tightens, doesn't disappear.** The cases listed in `README.md` § "Should you use Ralph?" (you author the plan, you want a real shell process, you're on Pro) are real. Stay in that lane.
4. **The right next plugin is probably not Ralph v0.2.** It's a separate "Claude Code workflows helper" that wraps `/goal`, `/branch`, worktrees, and dynamic workflows with opinionated defaults. Different problem, different plugin.

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

## Deferred for v0.2+ — revisit deliberately

These were considered for v0.1.0 and consciously left out. They are NOT bugs or oversights. Each one earned its omission against the 3-command budget. Revisit when there is a concrete need a real run surfaced, not because we want more buttons.

### To revisit on real evidence (a run actually needed them)

- **Background sessions** (`claude --bg`, `claude attach`, `claude logs`). Would let `/ralph:run` detach so the interactive Claude session isn't held hostage by the Bash tool timeout. Revisit when: a user reports the 10-min Bash timeout cutting runs short *and* the "use a shell + tmux" workaround feels worse than adding a `--bg` flag to `/ralph:run`.
- **Agent teams** (`agents.md`, `agent-teams.md`). Parallel teammates working on independent plan items at once. Revisit when: someone has a plan whose items are demonstrably independent and the sequential loop is the bottleneck. *Do not* revisit because it sounds cool — that's the trap `../harness/` fell into.
- **SDK session stores** (`agent-sdk/session-storage.md` — S3, Redis, Postgres adapters). Mirror transcripts to external storage so any host can resume any session. Revisit when: someone runs Ralph across multiple machines (CI fleet, serverless) and the on-disk JSONL at `~/.claude/projects/...` actually fails them. Not before.
- **Structured outputs** (`--json-schema`, `agent-sdk/structured-outputs.md`). Force the per-iteration response into a typed envelope (e.g. `{done: bool, next_action: string, blockers: []}`). Revisit when: log-grepping iteration JSON to figure out what happened proves too painful, OR when we want a status command that needs reliable parsing.

### To revisit if real Ralph runs surface these problems

- **PreCompact / PostCompact hooks** (`hooks.md:43108-43164`). The fresh-context design means a single iteration shouldn't grow long enough to compact. If we ever switch to a single continued session — or `/ralph:goal` runs long enough to auto-compact — these become relevant for snapshotting plan state across the compact boundary.
- **SessionStart hook with `additionalContext` / `initialUserMessage`** (`hooks.md:41672-41721`). Currently the plan content goes in as the user prompt every iteration. If we add `--session-id` + `--continue` for any reason, this is how we'd re-inject plan state on resume.
- **Stop hook with `decision: block`** (`hooks.md:42711-42797`). The bash `_safe_count` grep on `plan.md` is the current plan-empty detector. A Stop hook is the in-session equivalent. Revisit if we move loop control inside Claude (e.g. for the `/ralph:goal` path) and want a smarter "should I stop" check than `/goal`'s default evaluator.
- **`--session-id` + `--continue`** (`cli-reference.md:29884,29923`). Carries conversation across iterations. Specifically rejected for `/ralph:run` because it reintroduces context rot — the original Ralph problem. Only revisit if someone proves continued context is *required* for a class of tasks the fresh-context loop can't handle.

### Probably-never list

These were evaluated and look like wrong primitives for Ralph at any version. Document the rejection so we don't re-evaluate them in v0.3.

- **`/loop` + `CronCreate`** — session-scoped, dies when the session ends. Wrong primitive for cross-session endurance.
- **Routines** — runs on Anthropic infrastructure, no local file access. Ralph is a local-file-first tool.
- **Custom subagents via `--agents`** — adds configuration surface; we don't need contextual isolation when each iteration is already fresh.
- **Agent view (`claude agents`)** — UI for managing many background sessions. Useful, but not a Ralph concern.
- **Dynamic workflows integration** — see "What changed on 2026-05-28" above. Dynamic workflows is a different problem space (model plans, parallel subagents, Anthropic-managed coordination). Putting it behind a Ralph command would dilute Ralph's niche and confuse users about which tool to reach for. The right move is a separate plugin.

---

**Status:** v0.1.0 — three commands shipped (`/ralph:init`, `/ralph:run`, `/ralph:goal`).
**Maintained by:** Jesper Vang (@flight505)
