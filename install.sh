#!/usr/bin/env bash
# Reproduce this Claude Code config on any machine. Safe to re-run (idempotent).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
AGENTS_SKILLS="$HOME/.agents/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$CLAUDE/skills"

link() {
    # link <target> <linkpath> — replace symlinks, back up real files
    local target="$1" linkpath="$2"
    mkdir -p "$(dirname "$linkpath")"
    if [ -L "$linkpath" ]; then
        rm "$linkpath"
    elif [ -e "$linkpath" ]; then
        mv "$linkpath" "$linkpath.bak-$STAMP"
        echo "backed up existing $linkpath -> $linkpath.bak-$STAMP"
    fi
    ln -s "$target" "$linkpath"
    echo "linked $linkpath -> $target"
}

# 1. global settings
link "$REPO/settings.json" "$CLAUDE/settings.json"

# 2. statusline config (ccstatusline reads ~/.config/ccstatusline/settings.json)
link "$REPO/ccstatusline/settings.json" "$HOME/.config/ccstatusline/settings.json"

# 3. vendored skills owned by this repo (real dirs under repo/skills) — the source of truth
for d in "$REPO"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    link "$d" "$CLAUDE/skills/$name"
done

# 4. bonus: relink any npx-managed skill from ~/.agents/skills that isn't vendored yet.
#    (Add new ones with `npx skills add <repo>`, then copy into repo/skills to vendor.)
#    frontend-design is skipped: it ships as a plugin, linking it would collide.
if [ -d "$AGENTS_SKILLS" ]; then
    for d in "$AGENTS_SKILLS"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        [ "$name" = "frontend-design" ] && continue
        [ -e "$CLAUDE/skills/$name" ] && continue
        ln -s "$d" "$CLAUDE/skills/$name"
        echo "linked $CLAUDE/skills/$name -> $d (npx, not yet vendored)"
    done
fi

# 5. MCP servers — restore into ~/.claude.json (user scope) from mcp-servers.json.
#    Secrets come from secrets.env (gitignored); servers with a missing secret are skipped.
if command -v claude >/dev/null 2>&1; then
    set -a; [ -f "$REPO/secrets.env" ] && . "$REPO/secrets.env"; set +a
    [ -f "$REPO/secrets.env" ] || echo "note: secrets.env missing — MCP servers needing a key will be skipped."
    python3 - "$REPO/mcp-servers.json" <<'PY'
import json, os, sys, subprocess
servers = json.load(open(sys.argv[1]))
for name, cfg in servers.items():
    raw = os.path.expandvars(json.dumps(cfg))      # expands $HOME and ${SECRET}
    if "${" in raw:
        print(f"skip MCP '{name}': unresolved secret (set it in secrets.env)")
        continue
    subprocess.run(["claude", "mcp", "remove", name, "-s", "user"], capture_output=True)
    r = subprocess.run(["claude", "mcp", "add-json", name, raw, "-s", "user"])
    print(f"{'added' if r.returncode == 0 else 'FAILED'} MCP '{name}'")
PY
else
    echo "note: 'claude' CLI not found — skipping MCP restore."
fi

# 6. dependency check (warn only; auto-install ccstatusline if bun is present)
echo "--- dependency check ---"
for dep in node npx bun jq python3 claude; do
    if command -v "$dep" >/dev/null 2>&1; then echo "ok   $dep"; else echo "MISSING $dep"; fi
done
# uvx (from uv) runs the 'fetch' MCP server — warn but don't block.
command -v uvx >/dev/null 2>&1 && echo "ok   uvx" || echo "MISSING uvx (needed by 'fetch' MCP — install: curl -LsSf https://astral.sh/uv/install.sh | sh)"
command -v gh >/dev/null 2>&1 && echo "ok   gh (for publishing)" || echo "note gh missing (only needed to publish the repo)"
if ! command -v ccstatusline >/dev/null 2>&1; then
    if command -v bun >/dev/null 2>&1; then
        echo "installing ccstatusline via bun..."; bun add -g ccstatusline
    else
        echo "MISSING ccstatusline (install bun, then: bun add -g ccstatusline)"
    fi
else
    echo "ok   ccstatusline"
fi

echo
echo "done. In Claude Code run: /reload-skills  and  /reload-plugins"
echo "plugins (frontend-design, caveman, ui-ux-pro-max) reinstall from settings.json on launch."
