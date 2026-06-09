# claude-config

Personal Claude Code setup as a dotfiles repo — a **self-contained backup** of skills,
plugins, MCP servers, settings, and statusline. Clone it on any machine, drop in
`secrets.env`, run `install.sh`, and you're reproduced.

## What's captured

| Area | How it's stored | Restored by |
|------|-----------------|-------------|
| Global settings | `settings.json` (model, statusline, plugins, marketplaces, permissions) | symlink → `~/.claude/settings.json` |
| Skills | **vendored** real content in `skills/` (20 skills) | symlink → `~/.claude/skills/<name>` |
| Plugins | listed in `settings.json` (`enabledPlugins` + `extraKnownMarketplaces`) | Claude Code reinstalls on launch |
| MCP servers | `mcp-servers.json` (portable, secret-free) | `install.sh` → `claude mcp add-json` (user scope) |
| Secrets | `secrets.env` (**gitignored**), template in `secrets.env.example` | sourced by `install.sh`, injected into MCP config |
| Statusline | `ccstatusline/settings.json` | symlink → `~/.config/ccstatusline/settings.json` |
| Skill provenance | `agents-skill-lock.json` (where each `npx skills` skill came from) | reference / re-pull updates |

## Layout

```
settings.json                # global Claude settings (symlinked into ~/.claude)
settings.local.json.example  # template for machine-local perms (real one is gitignored)
mcp-servers.json             # MCP server defs with $HOME / ${SECRET} placeholders
secrets.env.example          # copy to secrets.env, fill in, never commit
ccstatusline/settings.json   # statusline config (symlinked into ~/.config)
statusline-command.sh        # offline fallback statusline (not wired in by default)
skills/<name>/               # 20 vendored skills (real content)
agents-skill-lock.json       # provenance of the npx-managed skills
install.sh                   # idempotent installer (repo -> machine)
sync.sh                      # capture live config back into the repo (machine -> repo)
```

## How skills resolve

Claude Code loads skills only from `~/.claude/skills/` and from installed plugins.
Everything in `~/.claude/skills/` is a symlink into **this repo's `skills/`** — so the repo
is the single source of truth and a true offline backup (survives upstream deletion).

`agents-skill-lock.json` records where each skill originally came from (the `npx skills`
CLI writes to `~/.agents/skills/`, which Claude Code does *not* read directly). To refresh:

```bash
npx skills update                 # pulls latest into ~/.agents/skills
rsync -a --delete --exclude=.git ~/.agents/skills/<name>/ ~/Dev/claude-config/skills/<name>/
```

`frontend-design` is intentionally **not** vendored — it ships as a plugin; a same-named
skill would collide. `install.sh` also relinks any `~/.agents/skills/*` not yet vendored,
as a convenience.

## MCP servers & secrets

`mcp-servers.json` is committed with placeholders (`$HOME`, `${MAGIC_API_KEY}`) — no secrets.
Real keys live in `secrets.env` (gitignored). `install.sh` sources `secrets.env`, expands the
placeholders, and writes each server into `~/.claude.json` at **user scope** via
`claude mcp add-json`. Any server whose secret is missing is skipped with a warning.

Currently configured: `filesystem` (no secret) and `magic` (needs `MAGIC_API_KEY`).

> The claude.ai **Figma** connector is account-level (not local config); it restores by
> signing into your Claude account, so it isn't tracked here.

## Plugins

Enabled: `frontend-design`, `caveman`, `ui-ux-pro-max`, from marketplaces declared in
`settings.json`. Claude Code reinstalls them automatically on launch — nothing to vendor.

## CLI dependencies

`install.sh` checks these and warns if missing:

| Tool | Used for |
|------|----------|
| `node` / `npx` | MCP servers (`@modelcontextprotocol/server-filesystem`, `@21st-dev/magic`), `npx skills` |
| `bun` | runs `ccstatusline`; `install.sh` will `bun add -g ccstatusline` if absent |
| `ccstatusline` | the statusline (referenced by `settings.json`) |
| `python3` | MCP restore (secret expansion) in `install.sh` |
| `jq` | handy for JSON; used by the fallback statusline script |
| `claude` | the Claude Code CLI (MCP restore) |
| `gh` | only to publish/clone this repo |

## Fresh machine setup

```bash
git clone <this-repo> ~/Dev/claude-config
cd ~/Dev/claude-config
cp secrets.env.example secrets.env   # then fill in real keys (or copy your secrets.env over)
./install.sh
# in Claude Code:  /reload-skills   and   /reload-plugins
```

## Publishing (one-time)

```bash
cd ~/Dev/claude-config
gh repo create claude-config --private --source . --push
# or: git remote add origin <url> && git push -u origin main
```
`secrets.env` is gitignored, so it never leaves your machine — copy it to other machines
out of band (scp / password manager).

## Adding more later

Add things the normal way, then run `./sync.sh` to pull the live state back into the
repo, review the diff, and commit yourself. `sync.sh` only writes files — it never
stages or commits.

- **Skill**: `npx skills add <repo>` → `./sync.sh`
- **MCP server**: `claude mcp add …` (or edit `~/.claude.json`) → `./sync.sh`
- **Plugin / settings**: install via `/plugin` or edit settings — already live in `settings.json` (symlink)

Secrets are auto-scrubbed: any MCP value whose plaintext is in `secrets.env` is rewritten
to `${VAR}`. For a **new** secret-bearing server, add the key to `secrets.env` *before*
syncing — otherwise `sync.sh` writes a `${KEY}` placeholder and warns you to fill it in.

## Permissions

Global allowlist (`settings.json`) stays lean — durable, generic dev perms only.
Project-specific perms belong in each project's own `.claude/settings.local.json`;
the user-level `~/.claude/settings.local.json` is machine-local and gitignored here.
