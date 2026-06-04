#!/usr/bin/env bash

# safe to re-run.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
AGENTS_SKILLS="$HOME/.agents/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$CLAUDE/skills"

link() {
    # link <target> <linkpath>
    local target="$1" linkpath="$2"
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

# 2. vendored skills owned by this repo (real dirs under repo/skills)
for d in "$REPO"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    link "$d" "$CLAUDE/skills/$name"
done

# 3. relink npx-managed skills from ~/.agents/skills (source of truth = npx).
#    Run `npx skills add <repo>` to add, or restore from agents-skill-lock.json.
#    frontend-design is skipped: it ships as a plugin, linking it would collide.
if [ -d "$AGENTS_SKILLS" ]; then
    for d in "$AGENTS_SKILLS"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        [ "$name" = "frontend-design" ] && continue
        [ -e "$CLAUDE/skills/$name" ] && continue
        ln -s "$d" "$CLAUDE/skills/$name"
        echo "linked $CLAUDE/skills/$name -> $d (npx)"
    done
else
    echo "note: ~/.agents/skills missing. Restore npx skills from agents-skill-lock.json, then re-run."
fi

echo "done. Run /reload-skills and /reload-plugins in Claude Code."
