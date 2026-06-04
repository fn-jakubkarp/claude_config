# claude-config

Personal Claude Code config as a dotfiles repo. `install.sh` symlinks it into `~/.claude`.

## Layout

| Path | What |
|------|------|
| `settings.json` | Global Claude Code settings — symlinked to `~/.claude/settings.json`. Tracks model, status line, enabled plugins, known marketplaces, generic permission allowlist. |
| `skills/` | Skills this repo *owns* (real dirs, vendored). Each is symlinked into `~/.claude/skills/<name>`. Currently: `humanizer`. |
| `agents-skill-lock.json` | Snapshot of `~/.agents/.skill-lock.json` — the manifest of skills installed via the `npx skills` CLI. Lets a fresh machine reproduce them. |
| `install.sh` | Idempotent. Symlinks settings + vendored skills, then relinks `~/.agents/skills/*` into `~/.claude/skills`. Backs up any real file it would clobber. |

## How skills resolve

Claude Code only loads skills from `~/.claude/skills/` and installed plugins. Two sources feed `~/.claude/skills/`:

1. **Vendored** (`skills/` here) — owned by this repo.
2. **npx-managed** — `npx skills add <repo>` writes to `~/.agents/skills/` (a cross-agent dir Claude Code does *not* read). `install.sh` symlinks each one into `~/.claude/skills/` so Claude Code sees it. Updates via `npx skills update` flow through the symlink automatically.

`frontend-design` is intentionally skipped in the relink — it ships as a plugin; a skill of the same name would collide.

## Fresh machine setup

```bash
git clone <this-repo> ~/Dev/claude-config

# restore npx-managed skills listed in agents-skill-lock.json:
#   for each entry: npx skills add <source>
# (or copy agents-skill-lock.json to ~/.agents/.skill-lock.json and run npx skills restore)

~/Dev/claude-config/install.sh
# then in Claude Code: /reload-skills && /reload-plugins
```

Plugins (frontend-design, caveman, ui-ux-pro-max) restore from `enabledPlugins` +
`extraKnownMarketplaces` in `settings.json` — Claude Code reinstalls them on launch.

## Permissions

Global allowlist is kept lean: only durable, generic dev perms (`bun run`, `tsc`,
`python3`, …). Project-specific perms live in each project's
`.claude/settings.local.json`, not here.
