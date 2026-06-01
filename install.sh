#!/usr/bin/env bash
# Clawd buddy installer — self-contained, no MCP server / bun / node needed.
# Seeds the buddy state, points Claude Code's status line at Clawd, and wires the
# hooks (persona injection + activity tracking + reactions). Requires: jq.
#
# Re-running is safe: hooks are de-duplicated, settings are backed up first.
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SL="$HERE/statusline/buddy-status.sh"
SETTINGS="$HOME/.claude/settings.json"
STATE_DIR="$HOME/.claude-buddy"

command -v jq >/dev/null || { echo "✗ jq is required (brew install jq)"; exit 1; }
[ -f "$SL" ] || { echo "✗ not found: $SL"; exit 1; }
chmod +x "$SL" "$HERE"/hooks/*.sh

# 1) Seed the companion state (Clawd = the dragon slot) if absent
mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_DIR/status.json" ]; then
  cat > "$STATE_DIR/status.json" <<'JSON'
{"name":"클코","species":"clawd","rarity":"uncommon","stars":"★★","face":"<·~·>","eye":"·","shiny":false,"hat":"none","reaction":"","muted":false,"achievement":""}
JSON
  echo "• seeded $STATE_DIR/status.json (클코 · clawd)"
fi

# 2) Wire status line + hooks into settings.json (backup first)
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
BACKUP="$SETTINGS.bak.$(date +%s)"
cp "$SETTINGS" "$BACKUP"
echo "• backed up settings → $BACKUP"

tmp="$(mktemp)"
jq \
  --arg sl "$SL" \
  --arg persona "$HERE/hooks/clawd-persona.sh" \
  --arg name    "$HERE/hooks/name-react.sh" \
  --arg comment "$HERE/hooks/buddy-comment.sh" \
  --arg react   "$HERE/hooks/react.sh" '
  # append a command-hook to an event group, deduped by command path
  def addhook($event; $matcher; $cmd):
    .hooks[$event] = ((.hooks[$event] // []) as $arr
      | if ($arr | any(.hooks[]?.command == $cmd)) then $arr
        else $arr + [ (if $matcher != "" then {matcher:$matcher} else {} end)
                      + {hooks:[{type:"command", command:$cmd}]} ]
        end);
  .statusLine = {type:"command", command:$sl, padding:1, refreshInterval:1}
  | addhook("SessionStart";    "";     $persona)
  | addhook("UserPromptSubmit"; "";     $name)
  | addhook("Stop";            "";     $comment)
  | addhook("PostToolUse";     "Bash"; $react)
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ Clawd 버디 설치 완료 — 새 세션부터 클코가 상태줄에 등장"
echo "  (되돌리기: cp \"$BACKUP\" \"$SETTINGS\")"
