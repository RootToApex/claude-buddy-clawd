# claude-buddy-clawd

A **Clawd** status-line skin for the Claude Code companion (the `/buddy` pet).
Reskins the buddy as the orange pixel **Clawd** mascot and makes him *react to what
you're doing* — working, resting, or asleep — with props and expressions instead
of a speech bubble.

```
열일중 (working)            쉬는중 (resting)        잠듬 (sleeping)
 ████████████                ████████████                   z
▄████  ██  ████▄  ▄█▀       ▄██▀▀████▀▀██▄  ▄▀▄▀          z
▀████████████▀  ▄█▀         ▀████████████▀  █▀▀▀█      ████████████
 ██▀██▀▀██▀██ ▄█▀            ██▀██▀▀██▀██   ██████     ▀██▀▀████▀▀██▀
 ▀▀ ▀▀  ▀▀ ▀▀ ██████         ▀▀ ▀▀  ▀▀ ▀▀    ▀▀▀▀      ...
 클코 열일중                  클코 쉬는중...              클코 잠듬...
   Clawd + laptop              Clawd + coffee            zzz + Clawd
```

## What it does

The buddy's **dragon** slot is reskinned as Clawd (rounded pixel body, dark square
eyes, four legs). The status line then shows one of three states, chosen
automatically from how recently your session transcript was written:

| State | Detected when | Shows |
| --- | --- | --- |
| **Working** (`열일중`) | transcript written < 30s ago | Clawd looking right at a **laptop** |
| **Resting** (`쉬는중`) | idle 30s – 3min | Clawd with `- -` eyes + **coffee** |
| **Sleeping** (`잠듬`) | idle 3min+ | **zzz** rising above a sleeping Clawd |

- True-color half-block pixel art (body `#D96526`, eyes black)
- No blinking / no speech bubble — mood is shown through pose, eyes, and props
- Thresholds, colors, art, and labels are all easy to tweak near the top of the script

## Requirements

- [claude-buddy](https://github.com/1270011/claude-buddy) installed (this script reads
  its `~/.claude-buddy/status.json`)
- Your active companion set to the **dragon** species (that slot renders as Clawd)
- A true-color terminal (the colors need 24-bit ANSI; tested on macOS Terminal/iTerm2)

## Install

```bash
git clone https://github.com/RootToApex/claude-buddy-clawd.git
cd claude-buddy-clawd
./install.sh        # backs up your current statusline + points Claude Code at this one
```

…or do it manually — set your Claude Code status line to the script:

```jsonc
// ~/.claude/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/claude-buddy-clawd/statusline/buddy-status.sh",
    "padding": 1,
    "refreshInterval": 1
  }
}
```

Then make sure your buddy is a dragon (e.g. `/buddy pick dragon`) and start coding —
Clawd flips to **열일중** while the transcript is being written and drifts to
**쉬는중 → 잠듬** as you go idle.

## Tweaks

Open `statusline/buddy-status.sh` and look for:
- `CLAWD_STATE` thresholds (`30` / `180` seconds) — how fast he rests/sleeps
- `F1`/`F2`… palette — body/eye/prop colors
- `CLAWD_WORK` / `CLAWD_CLOSED` bitmaps — the Clawd art and eye expressions
- `LAPTOP` / `COFFEE` bitmaps — the props

## Credits

- The **/buddy** companion was originally an Anthropic feature in Claude Code.
- This builds on **[1270011/claude-buddy](https://github.com/1270011/claude-buddy)**
  (MIT), which preserves the buddy after it was removed.
- "Clawd" is Anthropic's pixel mascot; this is a fan reskin of the status-line art.

MIT licensed — see [LICENSE](./LICENSE). Original copyright retained.
