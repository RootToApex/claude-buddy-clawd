# claude-buddy-clawd

> **Clawd** — a Korean-flavored Claude Code status-line companion. Reskins the `/buddy` pet as Anthropic's orange pixel mascot, who works / rests / sleeps in sync with what Claude Code is doing. Pure bash, self-contained.

Claude Code 상태줄에 사는 작은 드래곤 **클코(Clawd)**. 작업을 시키면 일하고, 끝나면
쉬고, 한참 자리를 비우면 잠듦. 말풍선 대신 **포즈와 소품**으로 현재 상태를 보여줌.

## 미리보기

**열일중** — 노트북 보며 작업 중
```
    ████████████
   ▄████████████▄           ▄█▀
   ▀████████████▀         ▄█▀
    ██▀██▀▀██▀██        ▄█▀
    ▀▀ ▀▀  ▀▀ ▀▀     ██████
   클코 열일중
```

**쉬는중** — 턴 끝, 커피 한 잔
```
    ████████████
   ▄██▀▀████▀▀██▄       ▄▀▄▀
   ▀████████████▀     █▀▀▀▀█
    ██▀██▀▀██▀██      ██████
    ▀▀ ▀▀  ▀▀ ▀▀       ▀▀▀▀▀
  클코 쉬는중...
```

**잠듦** — 한참 자리 비움
```
              z
            z
    ████████████
   ▄██▀▀████▀▀██▄
   ▀████████████▀
    ██▀██▀▀██▀██
    ▀▀ ▀▀  ▀▀ ▀▀
  클코 잠듦...
```

## 무엇을 하나

**클로드 코드가 지금 일하는 상태**를 상태줄의 클코로 보여줌.

| 상태 | 언제 | 모습 |
| --- | --- | --- |
| **열일중** | 턴 진행 중 (지시 → 응답 끝까지) | 노트북 보는 클코 |
| **쉬는중** | 턴 끝나고 3분 안 | 눈 감고 커피 |
| **잠듦** | 3분 넘게 idle | 클코 위로 zzz |

- 트루컬러 반칸블록 픽셀 아트 (몸통 `#D96526`, 눈 검정)
- 말풍선·깜빡임 없음 — 포즈·눈·소품으로만 기분 표현
- 임계값·색·아트 전부 스크립트 상단에서 수정 가능

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

`install.sh`가 하는 일: `~/.claude-buddy/status.json` 시드(클코·dragon) + Claude Code
`settings.json`에 상태줄과 훅 자동 등록 (`species: clawd`로 시드; 기존 설정은 `settings.json.bak.*`로 백업됨).

설치 후 **새 Claude Code 세션**을 열면 클코가 상태줄에 등장함. 되돌리려면 백업 파일을
복원하면 됨.

## 작동 방식

- **상태줄** `statusline/buddy-status.sh` 가 ~1초마다 클코를 다시 그림.
- **상태 판정**은 턴 생명주기 훅이 찍는 타임스탬프 도장으로 결정됨:
  - `UserPromptSubmit` → "턴 시작" 도장 (`hooks/name-react.sh`)
  - `Stop` → "턴 끝" 도장 (`hooks/buddy-comment.sh`)
  - 상태줄은 둘을 비교 → 시작이 최신이면 **열일중**, 아니면 끝난 뒤 경과로 **쉬는중 → 잠듦**
  - 도장은 `session_id`로 키잉됨 → 여러 세션/프로젝트가 서로 섞이지 않음
- **성격·말풍선**은 `hooks/clawd-persona.sh`(SessionStart)가 컨텍스트에 주입함 — MCP 서버 없이 클코가 말함.

> 이전 버전은 트랜스크립트 파일 수정시각으로 idle을 추측해서, 긴 도구 실행이나 생각
> 중에 "쉬는중"으로 새고 작업이 끝나야 "열일중"이 뜨는 거꾸로 버그가 있었음. 지금은
> 실제 턴 상태로 판정해서 해결됨.

## 커스터마이즈

`statusline/buddy-status.sh` 상단:
- 상태 임계값 `180`(초) — 쉬는중 → 잠듦 속도
- `F1`/`F2`… 팔레트 — 몸통/눈/소품 색
- `CLAWD_WORK` / `CLAWD_CLOSED` 비트맵 — 클코 아트와 눈 표정
- `LAPTOP` / `COFFEE` 비트맵 — 소품

## 크레딧 · 라이선스

[1270011/claude-buddy](https://github.com/1270011/claude-buddy)(MIT) 기반. "Clawd"는 Anthropic의 픽셀 마스코트. MIT 라이선스 — 상세는 [LICENSE](./LICENSE).
