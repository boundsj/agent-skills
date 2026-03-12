# Agent Skills

## Installing Skills

Clone this repo and symlink individual skill directories into your agent's skills folder:

```bash
# Claude Code
ln -s /path/to/agent-skills/cmux ~/.claude/skills/cmux

# Codex
ln -s /path/to/agent-skills/cmux ~/.codex/skills/cmux
```

Each skill is a self-contained directory. Symlink only the ones you need.

## Writing a Skill

### Directory structure

```
skill-name/
  SKILL.md              # Required -- the skill definition
  references/           # Optional -- detailed reference docs
    topic-a.md
    topic-b.md
  helper-script.sh      # Optional -- scripts the skill invokes
```

### SKILL.md format

Every `SKILL.md` must start with YAML frontmatter:

```yaml
---
name: skill-name
description: |
  One-paragraph description of when this skill should be used.
  This is matched against user prompts to decide whether to load the skill,
  so write it as trigger conditions, not a summary.
---
```

**`name`** -- kebab-case identifier, must match the directory name.

**`description`** -- the agent uses this to decide whether to activate the skill. Be specific about trigger conditions. Examples:
- "Use when orchestrating terminal sessions or running parallel commands inside cmux."
- "Use when building features with TCA, structuring reducers, or testing TCA features."

### Body content

After the frontmatter, write instructions for the agent:

- **Be directive.** Write "Do X" and "Never Y", not "You might want to consider X."
- **Include tool names.** If the skill wraps MCP tools or CLI commands, list exact names and signatures.
- **Show patterns.** Short code/command snippets are more useful than prose explanations.
- **Keep it scannable.** Use headers, tables, and bullet lists. Agents parse markdown structure.

### Reference files

Use a `references/` directory for detailed docs that would bloat `SKILL.md`:

- Link from SKILL.md with a table mapping topic to file and when to load it
- The agent reads reference files on demand, not all at once
- Good for: API references, testing patterns, advanced topics

### Helper scripts

Skills can include scripts that the agent invokes (e.g., `log-pretty.sh` for log formatting). Reference them by path relative to the skill directory -- the agent knows the skill's base directory at runtime.

## Repo conventions

- One directory per skill at the repo root
- Update the table in `README.md` when adding a skill
- Keep skills agent-agnostic where possible (Claude Code, Codex, Cursor)
- Published skill internals must be self-contained: do not reference `~/.claude`, `~/.codex`, or private checkout paths from `SKILL.md` files or bundled helper scripts in this repo
- Keep personal or org-specific values out of public skills unless the skill is explicitly a private wrapper
- Helper scripts should live inside the owning skill directory unless the shared helper also lives in this repo and is documented here
