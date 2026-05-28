# ralph

Long-running agent loop for Claude Code, in the Ralph pattern.

**Status:** v0.1.0 scaffold — implementation in progress.

---

## What it will be

A Claude Code plugin with **at most 3 slash commands** that runs a long-lived `claude -p` loop against a mutable plan file until the plan is empty.

Modeled on Geoffrey Huntley's [Ralph](https://ghuntley.com/ralph/) pattern and two existing implementations:

- [snarktank/ralph](https://github.com/snarktank/ralph) — pure bash
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) — Claude Code variant

Both are cloned into `research/` (gitignored) as study material.

---

## Development

```bash
# From inside this directory:
claude --plugin-dir .
```

See `CLAUDE.md` for design rules and the discipline this plugin commits to (3-command budget, no YAML DSLs, no wizards, no dashboards).

---

## License

MIT
