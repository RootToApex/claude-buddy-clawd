#!/usr/bin/env bash
# claude-buddy status line — animated, right-aligned multi-line companion
#
# Animation matches the original:
#   - 500ms per tick, sequence: [0,0,0,0,1,0,0,0,-1,0,0,2,0,0,0]
#   - Frame -1 = blink (eyes replaced with "-")
#   - Frames 0,1,2 = the 3 idle art variants per species
#   - refreshInterval: 1s in settings.json cycles the animation
#
# Uses Braille Blank (U+2800) for padding — survives JS .trim()
#
# When running inside buddy-shell (the PTY wrapper), skip status line rendering
# so the buddy doesn't show up twice (once in status line, once in wrapper panel).
[ "$BUDDY_SHELL" = "1" ] && exit 0

STATE="$HOME/.claude-buddy/status.json"
# Session ID: sanitized tmux pane number, or "default" outside tmux
SID="${TMUX_PANE#%}"
SID="${SID:-default}"

[ -f "$STATE" ] || exit 0

MUTED=$(jq -r '.muted // false' "$STATE" 2>/dev/null)
[ "$MUTED" = "true" ] && exit 0

NAME=$(jq -r '.name // ""' "$STATE" 2>/dev/null)
[ -z "$NAME" ] && exit 0

SPECIES=$(jq -r '.species // ""' "$STATE" 2>/dev/null)
# Clawd is its own species "clawd" (canonical); "dragon" kept as a legacy alias.
case "$SPECIES" in dragon|clawd) IS_CLAWD=1 ;; *) IS_CLAWD=0 ;; esac
HAT=$(jq -r '.hat // "none"' "$STATE" 2>/dev/null)
RARITY=$(jq -r '.rarity // "common"' "$STATE" 2>/dev/null)
REACTION=$(jq -r '.reaction // ""' "$STATE" 2>/dev/null)
ACHIEVEMENT=$(jq -r '.achievement // ""' "$STATE" 2>/dev/null)
# Clawd (dragon slot): no speech bubble — mood shows via expression/pose only
if [ "$IS_CLAWD" = 1 ]; then REACTION=""; ACHIEVEMENT=""; fi
# eye is written to status.json by writeStatusState (v2+); fall back to "°"
E=$(jq -r '.eye // "°"' "$STATE" 2>/dev/null)

STDIN_JSON=$(cat)  # Claude Code passes session JSON on stdin
# Activity files are keyed by Claude Code session_id (unique per session, even
# outside tmux) so concurrent sessions/projects don't clobber each other; fall
# back to the tmux-pane SID used elsewhere.
ASID=$(printf '%s' "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$ASID" ] && ASID="$SID"

# ─── Clawd activity state: driven by turn lifecycle (prompt/stop hooks) ──────
# Hooks stamp the session's turn boundaries (epoch seconds, per $ASID):
#   activity_prompt.$ASID = user submitted  → a turn STARTED
#   activity_stop.$ASID   = Claude finished → the turn ENDED, idle clock starts
# work = a turn is in progress (prompt newer than stop) — holds the WHOLE turn,
#        no matter how long tools/thinking take. rest = idle <3m, sleep = idle 3m+.
# 우선순위: shower(/clear 직후) > idea(막 입력함) > work(턴 진행) > wait(idle<5m) > sleep
CLAWD_STATE=wait
if [ "$IS_CLAWD" = 1 ]; then
  _now=$(date +%s)
  _p=$(cat "$HOME/.claude-buddy/activity_prompt.$ASID" 2>/dev/null)
  _s=$(cat "$HOME/.claude-buddy/activity_stop.$ASID" 2>/dev/null)
  _c=$(cat "$HOME/.claude-buddy/activity_clear.$ASID" 2>/dev/null)
  case "$_p" in ''|*[!0-9]*) _p=0 ;; esac
  case "$_s" in ''|*[!0-9]*) _s=0 ;; esac
  case "$_c" in ''|*[!0-9]*) _c=0 ;; esac
  WORK_TTL=1800                              # missed Stop(크래시/clear) 시 영구 열일중 방지
  _ref=$_s; [ "$_p" -gt "$_s" ] && _ref=$_p
  if   [ "$_c" -gt 0 ] && [ $(( _now - _c )) -lt 6 ]; then CLAWD_STATE=shower
  elif [ "$_p" -gt "$_s" ] && [ $(( _now - _p )) -lt "$WORK_TTL" ]; then
    if [ $(( _now - _p )) -lt 4 ]; then CLAWD_STATE=idea; else CLAWD_STATE=work; fi
  else
    _idle=$(( _now - _ref )); [ "$_idle" -lt 0 ] && _idle=0
    if   [ "$_ref" -eq 0 ];    then CLAWD_STATE=wait    # 아직 턴 없음
    elif [ "$_idle" -lt 180 ]; then CLAWD_STATE=wait    # 0~3분: 기다리는중(모래시계)
    elif [ "$_idle" -lt 600 ]; then CLAWD_STATE=rest    # 3~10분: 쉬는중(커피)
    else CLAWD_STATE=sleep; fi                          # 10분+: 잠듦(zzz)
  fi
  [ -n "$CLAWD_STATE_OVERRIDE" ] && CLAWD_STATE="$CLAWD_STATE_OVERRIDE"
  # 라벨: 상태별 짧은 드립 풀에서 자동 선택 (상태 인스턴스마다 안정적 = 초당 깜빡임 없음)
  case "$CLAWD_STATE" in
    idea)   POOL=( "오 그거 좋은데" "받았다, 가보자고" "번뜩" );        seed=$_p ;;
    work)   POOL=( "코드 조지는 중" "일하는 척" "키보드 혹사중" );      seed=$_p ;;
    wait)   POOL=( "...아직 안 보냄?" "님 기다리는 중" "타자 구경중" ); seed=$_s ;;
    rest)   POOL=( "커피 타임" "한 박자 쉼" "당 충전중" );              seed=$_s ;;
    sleep)  POOL=( "Zzz 깨우지 마" "충전중" "꿈에서 코딩중" );          seed=$_s ;;
    shower) POOL=( "기억 싹 헹구는 중~" "방금 다 까먹음" "머리 비우니 개운" "새 사람 됐다" ); seed=$_c ;;
    *)      POOL=( "클코" ); seed=0 ;;
  esac
  NAME="${POOL[$(( seed % ${#POOL[@]} ))]}"
fi

# ─── Animation: frame from timestamp ─────────────────────────────────────────
# Original sequence: [0,0,0,0,1,0,0,0,-1,0,0,2,0,0,0] with 500ms ticks
# Since refreshInterval=1s, each call = 2 ticks. We use seconds as index.
SEQ=(0 0 0 0 1 0 0 0 -1 0 0 2 0 0 0)
SEQ_LEN=${#SEQ[@]}
NOW=$(date +%s)
FRAME_IDX=$(( NOW % SEQ_LEN ))
FRAME=${SEQ[$FRAME_IDX]}

BLINK=0
if [ "$FRAME" -eq -1 ]; then
    BLINK=1
    FRAME=0
fi

# ─── Rarity color (pC4 = dark theme, the default) ────────────────────────────
NC=$'\033[0m'
case "$RARITY" in
  common)    C=$'\033[38;2;153;153;153m' ;;
  uncommon)  C=$'\033[38;2;78;186;101m'  ;;
  rare)      C=$'\033[38;2;177;185;249m' ;;
  epic)      C=$'\033[38;2;175;135;255m' ;;
  legendary) C=$'\033[38;2;255;193;7m'   ;;
  *)         C=$'\033[0m' ;;
esac

# ─── Art color (non-Clawd species keep their rarity color) ───────────────────
ACOLOR="$C"

# ─── Clawd (dragon slot) pixel renderer ──────────────────────────────────────
# render_px turns a bitmap (digits = palette colors, 0 = transparent) into
# pre-colored half-block lines; solid cells use a full block █ (fg only) so
# there are no seams. Palette: 1 body #D96526, 2 eye black, 4 laptop screen,
# 5 laptop/keyboard gray, 6 coffee, 7 cup, 8 steam/zzz.
F1=$'\033[38;2;217;101;38m'; G1=$'\033[48;2;217;101;38m'
F2=$'\033[38;2;0;0;0m';       G2=$'\033[48;2;0;0;0m'
F4=$'\033[38;2;70;75;95m';    G4=$'\033[48;2;70;75;95m'
F5=$'\033[38;2;120;120;125m'; G5=$'\033[48;2;120;120;125m'
F6=$'\033[38;2;150;95;55m';   G6=$'\033[48;2;150;95;55m'
F7=$'\033[38;2;220;215;200m'; G7=$'\033[48;2;220;215;200m'
F8=$'\033[38;2;130;160;215m'
fcolor() { case "$1" in 1)RF=$F1;;2)RF=$F2;;4)RF=$F4;;5)RF=$F5;;6)RF=$F6;;7)RF=$F7;;8)RF=$F8;;esac; }
gcolor() { case "$1" in 1)RG=$G1;;2)RG=$G2;;4)RG=$G4;;5)RG=$G5;;6)RG=$G6;;7)RG=$G7;;*)RG="";;esac; }
render_px() {           # args = bitmap rows -> PX_LINES[]
  local rows=("$@") n=${#rows[@]} w=${#rows[0]}
  local r c t b top bot line zeros
  zeros=$(printf '%*s' "$w" ''); zeros=${zeros// /0}
  PX_LINES=()
  for (( r=0; r<n; r+=2 )); do
    top="${rows[$r]}"
    if (( r+1 < n )); then bot="${rows[$((r+1))]}"; else bot="$zeros"; fi
    line=""
    for (( c=0; c<w; c++ )); do
      t="${top:$c:1}"; b="${bot:$c:1}"
      if [ "$t" = 0 ] && [ "$b" = 0 ]; then line+=" "
      elif [ "$t" = "$b" ]; then fcolor "$t"; line+="${RF}█${NC}"
      elif [ "$t" != 0 ] && [ "$b" = 0 ]; then fcolor "$t"; line+="${RF}▀${NC}"
      elif [ "$t" = 0 ] && [ "$b" != 0 ]; then fcolor "$b"; line+="${RF}▄${NC}"
      else fcolor "$t"; gcolor "$b"; line+="${RF}${RG}▀${NC}"; fi
    done
    PX_LINES+=("$line")
  done
}
# Attach the last-rendered prop (PX_LINES) to the right of CLAWD_LINES, bottom-aligned.
# Each Clawd line is a fixed 16 visible cols, so a plain string append stays aligned.
clawd_attach_right() {
  local prop=("${PX_LINES[@]}") nc=${#CLAWD_LINES[@]} np=${#PX_LINES[@]}
  local off i pi p out=()
  off=$(( nc - np )); [ "$off" -lt 0 ] && off=0
  for (( i=0; i<nc; i++ )); do
    p=""; pi=$(( i - off ))
    [ "$pi" -ge 0 ] && [ "$pi" -lt "$np" ] && p="${prop[$pi]}"
    out+=("${CLAWD_LINES[$i]}   ${p}")
  done
  CLAWD_LINES=("${out[@]}")
}
# Clawd bitmaps — work: eyes shifted right (looks at laptop). closed: eyes = low line.
CLAWD_WORK=(   "0011111111111100" "0011111111111100" "0011112211112200" "0111112211112210" "0111111111111110" "0011111111111100" "0011111111111100" "0011011001101100" "0011011001101100" )
CLAWD_CLOSED=( "0011111111111100" "0011111111111100" "0011111111111100" "0111221111221110" "0111111111111110" "0011111111111100" "0011111111111100" "0011011001101100" "0011011001101100" )
# open: eyes emptied (transparent) — same spot/width as closed, just hollow (눈 뜸)
CLAWD_OPEN=(   "0011111111111100" "0011111111111100" "0011001111001100" "0111001111001110" "0111111111111110" "0011111111111100" "0011111111111100" "0011011001101100" "0011011001101100" )
# Props — laptop (thin side, screen tilts right), coffee (cup + steam)
LAPTOP=( "0000000044" "0000000440" "0000004400" "0000044000" "0000440000" "0004400000" "5555550000" "5555550000" )
COFFEE=( "000080800" "000808000" "077777700" "076666700" "077777700" "077777700" "007777700" "000000000" )

B=$'\xe2\xa0\x80'  # Braille Blank U+2800

# ─── Terminal width ──────────────────────────────────────────────────────────
COLS=0
PID=$$
for _ in 1 2 3 4 5; do
    PID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
    [ -z "$PID" ] || [ "$PID" = "1" ] && break
    PTY=$(readlink "/proc/${PID}/fd/0" 2>/dev/null)
    if [ -c "$PTY" ] 2>/dev/null; then
        COLS=$(stty size < "$PTY" 2>/dev/null | awk '{print $2}')
        [ "${COLS:-0}" -gt 40 ] 2>/dev/null && break
    fi
done
[ "${COLS:-0}" -lt 40 ] 2>/dev/null && COLS=${COLUMNS:-0}
[ "${COLS:-0}" -lt 40 ] 2>/dev/null && COLS=125

# ─── Species art: 3 frames each (F0, F1, F2) ────────────────────────────────
# Each frame = 4 lines (L1..L4). Selected by $FRAME.
case "$SPECIES" in
  dragon|clawd)  # Clawd (Claude Code mascot) — work(노트북)/rest(커피)/sleep(zzz). "dragon"=legacy alias
    case "$CLAWD_STATE" in
      work)
        render_px "${CLAWD_WORK[@]}";   CLAWD_LINES=("${PX_LINES[@]}")
        render_px "${LAPTOP[@]}";       clawd_attach_right ;;
      wait)
        render_px "${CLAWD_OPEN[@]}";   CLAWD_LINES=("${PX_LINES[@]}")
        hg=⏳; [ $(( _now % 2 )) -eq 1 ] && hg=⌛   # 모래시계 뒤집기 애니
        CLAWD_LINES[2]="${CLAWD_LINES[2]}   ${hg}" ;;
      rest)
        render_px "${CLAWD_OPEN[@]}";   CLAWD_LINES=("${PX_LINES[@]}")
        render_px "${COFFEE[@]}";       clawd_attach_right ;;
      sleep)
        render_px "${CLAWD_CLOSED[@]}"; CLAWD_LINES=("${PX_LINES[@]}")
        zc=$'\033[38;2;130;160;215m'
        CLAWD_LINES=( "            ${zc}z${NC}" "          ${zc}z${NC}" "${CLAWD_LINES[@]}" ) ;;
      idea)
        render_px "${CLAWD_OPEN[@]}";   CLAWD_LINES=("${PX_LINES[@]}")
        CLAWD_LINES=( "      ✨ 💡 ✨" "${CLAWD_LINES[@]}" ) ;;
      shower)
        render_px "${CLAWD_CLOSED[@]}"; CLAWD_LINES=("${PX_LINES[@]}")
        bc=$'\033[38;2;150;190;230m'                       # 물/거품 색
        if [ $(( _now % 2 )) -eq 0 ]; then w="╎┊╎┊╎"; else w="┊╎┊╎┊"; fi
        lz=( "   " "  ${bc}◦${NC}" "   " "  ${bc}°${NC}" "   " )   # 왼쪽 거품 (3칸 고정)
        rz=( " ${bc}◦${NC}" "  " " ${bc}°${NC}" "  " " ${bc}◦${NC}" )  # 오른쪽 거품 (2칸 고정)
        for i in 0 1 2 3 4; do
          CLAWD_LINES[$i]="${lz[$i]}${CLAWD_LINES[$i]}${rz[$i]}"
        done
        CLAWD_LINES=( "          ${bc}▟▆▆▆▙${NC}" "          ${bc}${w}${NC}" "${CLAWD_LINES[@]}" ) ;;
    esac ;;
  *)
    L1="(${E}${E})"; L2="(  )"; L3=""; L4="" ;;
esac

# ─── Blink: replace eyes with "-" ────────────────────────────────────────────
if [ "$BLINK" -eq 1 ]; then
    L1="${L1//${E}/-}"
    L2="${L2//${E}/-}"
    L3="${L3//${E}/-}"
    L4="${L4//${E}/-}"
fi

# ─── Hat ──────────────────────────────────────────────────────────────────────
HAT_LINE=""
case "$HAT" in
  crown)     HAT_LINE=" \\^^^/" ;;
  tophat)    HAT_LINE=" [___]" ;;
  propeller) HAT_LINE="  -+-" ;;
  halo)      HAT_LINE=" (   )" ;;
  wizard)    HAT_LINE="  /^\\" ;;
  beanie)    HAT_LINE=" (___)" ;;
  tinyduck)  HAT_LINE="  ,>" ;;
esac
# Clawd (dragon slot) wears no hat — its silhouette reads better bare
[ "$IS_CLAWD" = 1 ] && HAT_LINE=""

# ─── Reaction bubble (with TTL check) ────────────────────────────────────────
BUBBLE=""
if [ -n "$ACHIEVEMENT" ] && [ "$ACHIEVEMENT" != "null" ] && [ "$ACHIEVEMENT" != "" ]; then
    BUBBLE=$'\xf0\x9f\x8f\x86'" $ACHIEVEMENT"
fi
REACTION_FILE="$HOME/.claude-buddy/reaction.$SID.json"
REACTION_TTL=0
CONFIG_FILE="$HOME/.claude-buddy/config.json"
if [ -f "$CONFIG_FILE" ]; then
    _ttl=$(jq -r '.reactionTTL // 0' "$CONFIG_FILE" 2>/dev/null || echo 0)
    case "$_ttl" in ''|*[!0-9]*) ;; *) REACTION_TTL="$_ttl" ;; esac
fi
if [ -n "$REACTION" ] && [ "$REACTION" != "null" ] && [ "$REACTION" != "" ]; then
    FRESH=0
    if [ "$REACTION_TTL" -eq 0 ]; then
        FRESH=1
    elif [ -f "$REACTION_FILE" ]; then
        TS=$(jq -r '.timestamp // 0' "$REACTION_FILE" 2>/dev/null || echo 0)
        if [ "$TS" != "0" ]; then
            NOW=$(date +%s)
            AGE=$(( NOW - TS / 1000 ))
            [ "$AGE" -lt "$REACTION_TTL" ] && FRESH=1
        fi
    fi
    if [ "$FRESH" -eq 1 ]; then
        if [ -n "$BUBBLE" ]; then
            BUBBLE="$BUBBLE | \"${REACTION}\""
        else
            BUBBLE="\"${REACTION}\""
        fi
    fi
fi

# ─── Build art lines ─────────────────────────────────────────────────────────
if [ "$IS_CLAWD" = 1 ]; then
    ART_LINES=("${CLAWD_LINES[@]}")   # pre-colored Clawd pixel lines
    CLAWD_PRECOLORED=1
else
    ART_LINES=("$L1" "$L2" "$L3")
    [ -n "$L4" ] && ART_LINES+=("$L4")
fi

# Center the name
NAME_LEN=${#NAME}
ART_CENTER=4
NAME_PAD=$(( ART_CENTER - NAME_LEN / 2 ))
[ "$NAME_PAD" -lt 0 ] && NAME_PAD=0
NAME_LINE="$(printf '%*s%s' "$NAME_PAD" '' "$NAME")"

# ─── Build all art lines ──────────────────────────────────────────────────────
DIM=$'\033[2;3m'

ALL_LINES=()
ALL_COLORS=()
[ -n "$HAT_LINE" ] && { ALL_LINES+=("$HAT_LINE"); ALL_COLORS+=("$C"); }
for line in "${ART_LINES[@]}"; do
    ALL_LINES+=("$line")
    if [ "$CLAWD_PRECOLORED" = 1 ]; then ALL_COLORS+=(""); else ALL_COLORS+=("$ACOLOR"); fi
done
ALL_LINES+=("$NAME_LINE"); ALL_COLORS+=("$DIM")

ART_W=14
[ "$IS_CLAWD" = 1 ] && ART_W=30   # Clawd + side prop (laptop/coffee)
ART_COUNT=${#ALL_LINES[@]}

# ─── Speech bubble (left of art, word-wrapped) ──────────────────────────────
# Strip the quotes we added earlier
BUBBLE_TEXT=""
if [ -n "$BUBBLE" ]; then
    BUBBLE_TEXT="${BUBBLE%\"}"
    BUBBLE_TEXT="${BUBBLE_TEXT#\"}"
fi

# ─── Word-wrap bubble text ────────────────────────────────────────────────────
INNER_W=28
TEXT_LINES=()
if [ -n "$BUBBLE_TEXT" ]; then
    WORDS=($BUBBLE_TEXT)
    CUR_LINE=""
    for word in "${WORDS[@]}"; do
        if [ -z "$CUR_LINE" ]; then
            CUR_LINE="$word"
        elif [ $(( ${#CUR_LINE} + 1 + ${#word} )) -le $INNER_W ]; then
            CUR_LINE="$CUR_LINE $word"
        else
            TEXT_LINES+=("$CUR_LINE")
            CUR_LINE="$word"
        fi
    done
    [ -n "$CUR_LINE" ] && TEXT_LINES+=("$CUR_LINE")
fi

TEXT_COUNT=${#TEXT_LINES[@]}

# Build box as plain strings (no ANSI). Color applied at output time.
# Box display width = INNER_W + 4:  "| " + text(INNER_W) + " |"
BOX_W=$(( INNER_W + 4 ))
BUBBLE_LINES=()
BUBBLE_TYPES=()  # "border" or "text" — determines coloring
if [ $TEXT_COUNT -gt 0 ]; then
    # Top border
    BORDER=$(printf '%*s' "$(( BOX_W - 2 ))" '' | tr ' ' '-')
    BUBBLE_LINES+=(".${BORDER}.")
    BUBBLE_TYPES+=("border")
    # Text rows: "| text padded |"
    for tl in "${TEXT_LINES[@]}"; do
        tpad=$(( INNER_W - ${#tl} ))
        [ "$tpad" -lt 0 ] && tpad=0
        padding=$(printf '%*s' "$tpad" '')
        BUBBLE_LINES+=("| ${tl}${padding} |")
        BUBBLE_TYPES+=("text")
    done
    # Bottom border
    BUBBLE_LINES+=("\`${BORDER}'")
    BUBBLE_TYPES+=("border")
fi

BUBBLE_COUNT=${#BUBBLE_LINES[@]}

# ─── Right-align with bubble box to the left ─────────────────────────────────
GAP=2
if [ $BUBBLE_COUNT -gt 0 ]; then
    TOTAL_W=$(( BOX_W + GAP + ART_W ))
else
    TOTAL_W=$ART_W
fi
MARGIN=8
PAD=$(( COLS - TOTAL_W - MARGIN ))
[ "$PAD" -lt 0 ] && PAD=0

SPACER=$(printf "${B}%${PAD}s" "")
GAP_STR=$(printf '%*s' "$GAP" '')

# Vertically center bubble box on the art
BUBBLE_START=0
if [ $BUBBLE_COUNT -gt 0 ] && [ $BUBBLE_COUNT -lt $ART_COUNT ]; then
    BUBBLE_START=$(( (ART_COUNT - BUBBLE_COUNT) / 2 ))
fi

# ─── Find the connector line (middle text line → points to buddy's mouth) ─────
# The connector goes on the middle text row of the bubble
CONNECTOR_BI=-1
if [ $BUBBLE_COUNT -gt 2 ]; then
    # text rows are indices 1..(BUBBLE_COUNT-2), pick the middle one
    FIRST_TEXT=1
    LAST_TEXT=$(( BUBBLE_COUNT - 2 ))
    CONNECTOR_BI=$(( (FIRST_TEXT + LAST_TEXT) / 2 ))
fi

# ─── Output: merged bubble box + connector + art per line ─────────────────────
for (( i=0; i<ART_COUNT; i++ )); do
    art_part="${ALL_COLORS[$i]}${ALL_LINES[$i]}${NC}"

    if [ $BUBBLE_COUNT -gt 0 ]; then
        bi=$(( i - BUBBLE_START ))
        if [ $bi -ge 0 ] && [ $bi -lt $BUBBLE_COUNT ]; then
            bline="${BUBBLE_LINES[$bi]}"
            btype="${BUBBLE_TYPES[$bi]}"

            # Connector: "-- " on the middle text line, spaces otherwise
            if [ $bi -eq $CONNECTOR_BI ]; then
                gap="${C}--${NC} "
            else
                gap="   "
            fi

            if [ "$btype" = "border" ]; then
                echo "${SPACER}${C}${bline}${NC}${gap}${art_part}"
            else
                pipe_l="${bline:0:1}"
                pipe_r="${bline: -1}"
                inner="${bline:1:$(( ${#bline} - 2 ))}"
                echo "${SPACER}${C}${pipe_l}${NC}${DIM}${inner}${NC}${C}${pipe_r}${NC}${gap}${art_part}"
            fi
        else
            empty=$(printf '%*s' "$BOX_W" '')
            echo "${SPACER}${empty}   ${art_part}"
        fi
    else
        echo "${SPACER}${art_part}"
    fi
done

exit 0
