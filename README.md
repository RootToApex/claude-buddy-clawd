# claude-buddy-clawd

> **Clawd** — a Korean-flavored Claude Code status-line companion. Reskins the `/buddy` pet as Anthropic's orange pixel mascot, who reacts to what Claude Code is doing (idea → work → wait → rest → sleep, plus a shower on `/clear`). Pure bash, self-contained.

Claude Code 상태줄에 사는 작은 마스코트 **클코(Clawd)**. 클로드 코드가 일하는지
쉬는지에 맞춰 포즈·소품·표정이 바뀜. 작업 주면 번뜩이고, 일하고, 끝나면 기다리다
쉬다 잠듦. `/clear` 하면 샤워하고 새 출발. 말풍선 대신 **포즈와 소품**으로 보여줌.

## 미리보기

각 그림 아래 한 줄은 상태별 드립 라벨 — 자동으로 골라서 매번 달라짐.

**💡 아이디어** — 막 작업 지시받음 (몇 초 반짝)
```
      ✨ 💡 ✨
    ████████████
   ▄██  ████  ██▄
   ▀████████████▀
    ██▀██▀▀██▀██
    ▀▀ ▀▀  ▀▀ ▀▀
   오 그거 좋은데
```

**💻 열일중** — 턴 진행 중 (노트북 응시)
```
    ████████████
   ▄████████████▄           ▄█▀
   ▀████████████▀         ▄█▀
    ██▀██▀▀██▀██        ▄█▀
    ▀▀ ▀▀  ▀▀ ▀▀     ██████
   코드 조지는 중
```

**⌛ 기다리는중** — 끝나고 너 기다리는 중 (모래시계 뒤집힘)
```
    ████████████
   ▄██  ████  ██▄
   ▀████████████▀    ⏳
    ██▀██▀▀██▀██
    ▀▀ ▀▀  ▀▀ ▀▀
   ...아직 안 보냄?
```

**☕ 쉬는중** — 자리 잡고 한숨 (커피)
```
    ████████████
   ▄██  ████  ██▄       ▄▀▄▀
   ▀████████████▀     █▀▀▀▀█
    ██▀██▀▀██▀██      ██████
    ▀▀ ▀▀  ▀▀ ▀▀       ▀▀▀▀▀
   커피 타임
```

**💤 잠듦** — 한참 자리 비움 (눈 감고 zzz)
```
              z
            z
    ████████████
   ▄██▀▀████▀▀██▄
   ▀████████████▀
    ██▀██▀▀██▀██
    ▀▀ ▀▀  ▀▀ ▀▀
   Zzz 깨우지 마
```

**🚿 샤워** — `/clear` 하면 깨끗하게 리셋 (샤워기 + 물줄기 + 거품)
```
          ▟▆▆▆▙
          ┊╎┊╎┊
     ████████████   ◦
  ◦ ▄██▀▀████▀▀██▄
    ▀████████████▀  °
  °  ██▀██▀▀██▀██
     ▀▀ ▀▀  ▀▀ ▀▀   ◦
   기억 싹 헹구는 중~
```

## 무엇을 하나

**클로드 코드가 지금 뭘 하는지**를 상태줄의 클코로 보여줌.

| 상태 | 언제 | 모습 |
| --- | --- | --- |
| 💡 아이디어 | 작업 지시 직후 (몇 초) | 눈 뜸 + 전구·반짝 |
| 💻 열일중 | 턴 진행 중 (지시 → 응답 끝까지) | 노트북 보는 클코 |
| ⌛ 기다리는중 | 끝나고 idle 3분 안 | 눈 뜸 + 모래시계 |
| ☕ 쉬는중 | idle 3~10분 | 눈 뜸 + 커피 |
| 💤 잠듦 | idle 10분+ | 눈 감고 zzz |
| 🚿 샤워 | `/clear` 직후 | 샤워기 + 물줄기 + 거품 |

- 라벨은 상태별 드립 풀에서 자동 선택 — 고정 문구 없이 매번 달라짐
- 트루컬러 반칸블록 픽셀 아트 (몸통 `#D96526`)
- 임계값·색·아트·라벨 전부 스크립트 상단에서 수정 가능

## 요구사항

- `jq`
- 트루컬러 터미널 (24-bit ANSI; macOS Terminal/iTerm2에서 테스트됨)
- bash (macOS / Linux)

**이게 전부.** MCP 서버·bun·node 불필요 — 순수 bash, self-contained.

## 설치

```bash
git clone https://github.com/RootToApex/claude-buddy-clawd.git
cd claude-buddy-clawd
./install.sh
```

`install.sh`가 하는 일: `~/.claude-buddy/status.json` 시드(`species: clawd`) + Claude Code
`settings.json`에 상태줄과 훅 자동 등록 (기존 설정은 `settings.json.bak.*`로 백업됨).

설치 후 **새 Claude Code 세션**을 열면 클코가 상태줄에 등장함. 되돌리려면 백업 파일을
복원하면 됨.

## 작동 방식

- **상태줄** `statusline/buddy-status.sh` 가 ~1초마다 클코를 다시 그림.
- **상태 판정**은 훅이 찍는 타임스탬프 도장으로:
  - `UserPromptSubmit` → "턴 시작" 도장 (`hooks/name-react.sh`)
  - `Stop` → "턴 끝" 도장 (`hooks/buddy-comment.sh`)
  - `SessionStart`(`source=clear`) → "샤워" 마커 (`hooks/clawd-persona.sh`)
  - 셋을 비교 → 아이디어 / 열일중 / 기다리는중 / 쉬는중 / 잠듦 / 샤워
  - 도장은 `session_id`로 키잉됨 → 여러 세션·프로젝트가 서로 섞이지 않음
- **성격**은 `clawd-persona.sh`(SessionStart)가 컨텍스트에 주입함 — MCP 서버 없이 클코가 말함.
- **라벨**은 상태별 드립 풀에서 자동으로 골라짐 (턴/idle 시각 기준이라 초당 깜빡이지 않음).

> 이전 버전은 트랜스크립트 파일 수정시각으로 idle을 추측해서, 긴 도구 실행이나 생각
> 중에 "쉬는중"으로 새고 작업이 끝나야 "열일중"이 뜨는 거꾸로 버그가 있었음. 지금은
> 실제 턴 상태로 판정해서 해결됨.

## 커스터마이즈

`statusline/buddy-status.sh` 상단:
- idle 임계값 `180` / `600`(초) — 기다리는중 → 쉬는중 → 잠듦 속도
- `F1`/`F2`… 팔레트 — 몸통/눈/소품 색
- `CLAWD_WORK` / `CLAWD_OPEN` / `CLAWD_CLOSED` 비트맵 — 클코 아트와 눈 표정
- `LAPTOP` / `COFFEE` 비트맵 — 소품
- 각 상태의 `POOL=( … )` — 라벨 드립 문구

## 라이선스

MIT 라이선스 — 상세는 [LICENSE](./LICENSE). "Clawd"는 Anthropic의 픽셀 마스코트.
