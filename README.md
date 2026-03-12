# Agent Skills

Reusable skills for AI coding agents (Claude Code, Codex, Cursor).

## Skills

| Skill | Description |
|-------|-------------|
| **[cmux](cmux/)** | Terminal multiplexer integration -- orchestrate sessions, stream output, report progress, and interact with browser panels inside [cmux](https://cmux.io) |
| **[review-alerts](review-alerts/)** | Report-only GitHub review queue summary. Shows prioritized pending PR reviews for an explicit `repo` and `user`, plus a lightweight recent-review activity chart. Requires `gh` and `jq`. |

## Install

Clone and symlink the skills you want:

```bash
git clone https://github.com/boundsj/agent-skills.git
ln -s "$(pwd)/agent-skills/review-alerts" ~/.claude/skills/review-alerts
```

For Codex, symlink into `~/.codex/skills/` instead (or in addition).

## Requirements

- `gh` CLI authenticated for GitHub-backed skills such as `review-alerts`
- `jq` installed and available on `PATH`

## Usage Notes

- `review-alerts` requires explicit `repo` and `user` inputs; it does not infer them from the current checkout or authenticated GitHub account

## License

MIT
