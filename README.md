# Agent Skills

Reusable skills for AI coding agents (Claude Code, Codex, Cursor).

## Skills

| Skill | Description |
|-------|-------------|
| **[cmux](cmux/)** | Terminal multiplexer integration -- orchestrate sessions, stream output, report progress, and interact with browser panels inside [cmux](https://cmux.io) |

## Install

Clone and symlink the skills you want:

```bash
git clone https://github.com/boundsj/agent-skills.git
ln -s "$(pwd)/agent-skills/cmux" ~/.claude/skills/cmux
```

For Codex, symlink into `~/.codex/skills/` instead (or in addition).

## License

MIT
