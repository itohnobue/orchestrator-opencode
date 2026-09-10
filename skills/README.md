# Repo-level skills (tracked)

Skills live in `.opencode/skills/` are gitignored in this repo (machine-local by design). Skills that must be versioned live here in `skills/` and are symlinked into `.opencode/skills/` on each machine:

| Skill | Symlink to create |
|-------|-------------------|
| `single-session-workflow` | `.opencode/skills/single-session-workflow` → `../../skills/single-session-workflow` |
| `handoff` | `.opencode/skills/handoff` → `../../skills/handoff` |

On a fresh clone, create the symlinks (macOS/Linux):
```bash
ln -s ../../skills/single-session-workflow .opencode/skills/single-session-workflow
ln -s ../../skills/handoff .opencode/skills/handoff
```
