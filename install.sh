#!/usr/bin/env bash
# Point Claude Code's status line at the Clawd buddy script.
# Backs up ~/.claude/settings.json first. Requires: jq.
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/statusline/buddy-status.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null || { echo "✗ jq is required (brew install jq)"; exit 1; }
[ -f "$SCRIPT" ] || { echo "✗ not found: $SCRIPT"; exit 1; }
chmod +x "$SCRIPT"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

BACKUP="$SETTINGS.bak.$(date +%s)"
cp "$SETTINGS" "$BACKUP"
echo "• backed up settings → $BACKUP"

tmp="$(mktemp)"
jq --arg cmd "$SCRIPT" '.statusLine = {type:"command", command:$cmd, padding:1, refreshInterval:1}' \
   "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ status line set to: $SCRIPT"
echo "  Make sure your buddy is a dragon:  /buddy pick dragon"
echo "  (restore anytime:  cp \"$BACKUP\" \"$SETTINGS\")"
