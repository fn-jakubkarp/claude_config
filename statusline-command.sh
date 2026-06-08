#!/bin/sh
# Claude Code status line — mirrors Powerlevel10k lean layout:
#   dir  git-branch  model  context%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Git branch (skip optional locks so it never stalls)
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree -q --no-optional-locks >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build output with ANSI colors (terminal renders these dimmed)
dir_part=$(printf '\033[34m%s\033[0m' "$short_cwd")

git_part=""
if [ -n "$branch" ]; then
  git_part=$(printf '  \033[32m\xef\xab\xa5 %s\033[0m' "$branch")
fi

model_part=""
if [ -n "$model" ]; then
  model_part=$(printf '  \033[35m%s\033[0m' "$model")
fi

ctx_part=""
if [ -n "$remaining" ]; then
  ctx_part=$(printf '  \033[33mctx:%s%%\033[0m' "$(printf '%.0f' "$remaining")")
fi

printf '%b%b%b%b\n' "$dir_part" "$git_part" "$model_part" "$ctx_part"
