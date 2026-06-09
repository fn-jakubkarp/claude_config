#!/usr/bin/env bash
# Capture current live Claude config INTO this repo so changes show up as git diffs.
# Does NOT stage or commit — you review + commit manually.
#   - MCP servers:  ~/.claude.json  ->  mcp-servers.json  (secrets scrubbed to ${VAR})
#   - skills:       ~/.agents/skills/*  ->  skills/   (+ refresh agents-skill-lock.json)
# Settings/plugins need no capture: settings.json is a live symlink into this repo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SKILLS="$HOME/.agents/skills"

# --- 1. MCP servers (secret-safe) ---
python3 - "$REPO" <<'PY'
import json, os, re, sys
repo = sys.argv[1]
home = os.path.expanduser("~")

live = json.load(open(os.path.join(home, ".claude.json"))).get("mcpServers", {})

# value -> VARNAME, from secrets.env
secrets = {}
secf = os.path.join(repo, "secrets.env")
if os.path.exists(secf):
    for line in open(secf):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip()
        if v:
            secrets[v] = k.strip()

SECRETY = re.compile(r"(KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTH)", re.I)
warnings = []

def descrub(obj):
    s = json.dumps(obj)
    for val, var in secrets.items():          # known secrets -> ${VAR}
        s = s.replace(val, "${" + var + "}")
    s = s.replace(home + "/", "$HOME/").replace('"' + home + '"', '"$HOME"')  # portable home
    return json.loads(s)

out = {}
for name, cfg in live.items():
    c = descrub(cfg)
    for k, v in (c.get("env") or {}).items():  # guard: unmapped secret-looking env values
        if isinstance(v, str) and v and "${" not in v and SECRETY.search(k):
            c["env"][k] = "${" + k + "}"
            warnings.append(f"{name}.env.{k}: not in secrets.env — wrote ${{{k}}} placeholder; add the real value to secrets.env")
    out[name] = c

with open(os.path.join(repo, "mcp-servers.json"), "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")

print(f"captured {len(out)} MCP server(s): {', '.join(out) or '(none)'}")
for w in warnings:
    print("WARN:", w)
PY

# --- 2. skills (vendor each ~/.agents skill; never touch repo-owned ones like humanizer) ---
if [ -d "$AGENTS_SKILLS" ]; then
    n=0
    for d in "$AGENTS_SKILLS"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        [ "$name" = "frontend-design" ] && continue   # ships as plugin, would collide
        rsync -a --delete --exclude='.git' "$d" "$REPO/skills/$name/"
        n=$((n+1))
    done
    [ -f "$HOME/.agents/.skill-lock.json" ] && cp "$HOME/.agents/.skill-lock.json" "$REPO/agents-skill-lock.json"
    echo "vendored $n skill(s) from ~/.agents + refreshed lockfile"
else
    echo "note: ~/.agents/skills missing — skipped skill capture"
fi

# --- 3. show what changed (no staging) ---
echo
echo "--- changes in repo (review, then commit yourself) ---"
git -C "$REPO" status -s || true
echo
git -C "$REPO" --no-pager diff --stat || true
