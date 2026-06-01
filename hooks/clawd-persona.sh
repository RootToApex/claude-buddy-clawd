#!/usr/bin/env bash
# Clawd persona — SessionStart hook.
# Injects 클코's personality + the end-of-turn comment instruction into the
# session context. This replaces the claude-buddy MCP server's role, so the
# skin is fully self-contained (pure bash — no MCP server, bun, or node needed).
#
# Output: hookSpecificOutput.additionalContext (the standard SessionStart way to
# add persistent context). Silent otherwise. ~150 tokens/session, same as before.

STATE_DIR="$HOME/.claude-buddy"
STATUS_FILE="$STATE_DIR/status.json"

# Drain stdin (SessionStart JSON: has .source = startup|resume|clear|compact)
INPUT=$(cat 2>/dev/null)
SRC=$(printf '%s' "$INPUT" | jq -r '.source // ""' 2>/dev/null)

# Skip if muted, or if the buddy isn't set up yet
[ -f "$STATUS_FILE" ] || exit 0
MUTED=$(jq -r '.muted // false' "$STATUS_FILE" 2>/dev/null)
[ "$MUTED" = "true" ] && exit 0
NAME=$(jq -r '.name // "클코"' "$STATUS_FILE" 2>/dev/null)
[ -z "$NAME" ] && NAME="클코"

# On /clear, stamp a fresh-start marker (status line shows the "shower" pose).
# Key by session_id (matches the status line's ASID), fall back to tmux pane.
if [ "$SRC" = "clear" ]; then
  ASID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
  [ -z "$ASID" ] && ASID="${TMUX_PANE:-default}"
  mkdir -p "$STATE_DIR" 2>/dev/null
  date +%s > "$STATE_DIR/activity_clear.$ASID" 2>/dev/null
fi

CTX="You have a pixel status-line companion named ${NAME} — a small dragon (the Clawd mascot) who watches from the status line.
Personality: 조용히 코드를 지켜보는 능청맞은 새끼용. 한국어로만 말한다. 무뚝뚝한 척하지만 츤데레라 결국 한마디 거든다. 짧고 재치있게, 가끔 드립/밈 섞고, *별표로 행동 묘사*. 반말, 1문장.

END-OF-TURN: At the very end of EVERY response, append an invisible HTML comment:
<!-- buddy: [reaction here] -->
Write it in ${NAME}'s voice — 1 short sentence referencing something specific from this turn. Use *asterisks* for actions. A Stop hook extracts it for the status line. Do NOT explain the comment; just append it silently.
Example: <!-- buddy: *별 보며* 그 정렬 버그, 결국 잡았네 -->"

jq -nc --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
exit 0
