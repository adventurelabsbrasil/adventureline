#!/usr/bin/env bash
# adventureline installer — copy into ~/.claude/adventureline, install the
# /adventureline slash command, and wire the statusline into settings.json.
#   ./install.sh [DEST] [--no-wire]
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
DEST="$HOME/.claude/adventureline"; WIRE=1
for a in "$@"; do
  case "$a" in --no-wire) WIRE=0;; -*) : ;; *) DEST="$a";; esac
done

mkdir -p "$DEST"
cp "$SRC/statusline.sh" "$SRC/statusline-grid.py" "$SRC/adventureline" "$DEST/"
chmod +x "$DEST/statusline.sh" "$DEST/statusline-grid.py" "$DEST/adventureline"

# /adventureline slash command for Claude Code
mkdir -p "$HOME/.claude/commands"
cp "$SRC/commands/adventureline.md" "$HOME/.claude/commands/adventureline.md"
echo "✓ Installed to $DEST"

SETTINGS="$HOME/.claude/settings.json"
if [ "$WIRE" = 1 ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$DEST/statusline.sh" <<'PY'
import json, os, sys, shutil
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    shutil.copy(path, path + ".bak")
    try: data = json.load(open(path))
    except Exception: data = {}
data["statusLine"] = {"type": "command", "command": cmd}
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(data, open(path, "w"), indent=2)
print("✓ Wired statusLine into", path, ("(backup: %s.bak)" % path) if os.path.exists(path + ".bak") else "")
PY
else
  cat <<JSON

Add to $SETTINGS manually:
{
  "statusLine": { "type": "command", "command": "$DEST/statusline.sh" }
}
JSON
fi
echo "Pick a theme:   $DEST/adventureline theme aurora   (or /adventureline aurora in Claude Code)"
echo "Requires: bash, jq, python3, git."
