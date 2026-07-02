#!/usr/bin/env bash
# adventureline installer — copy into ~/.claude/adventureline and print the
# settings.json snippet to wire it into Claude Code.
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
DEST="${1:-$HOME/.claude/adventureline}"
mkdir -p "$DEST"
cp "$SRC/statusline.sh" "$SRC/statusline-grid.py" "$SRC/adventureline" "$DEST/"
chmod +x "$DEST/statusline.sh" "$DEST/statusline-grid.py" "$DEST/adventureline"

# optional: install the /adventureline slash command for Claude Code
mkdir -p "$HOME/.claude/commands"
cp "$SRC/commands/adventureline.md" "$HOME/.claude/commands/adventureline.md"
echo "✓ Installed to $DEST"
echo
echo "Add to ~/.claude/settings.json (create if missing):"
cat <<JSON

{
  "statusLine": {
    "type": "command",
    "command": "$DEST/statusline.sh"
  }
}
JSON
echo
echo "Pick a theme:   $DEST/adventureline theme aurora"
echo "Preview all:    $DEST/adventureline preview"
echo "Requires: bash, jq, python3, git."
