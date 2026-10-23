# Subway Lahore — Core Demo Verification (2026-10-23)

Engine: Godot 4.4.1 stable (GDScript build) at `~/workspace/tools/godot/Godot_v4.4.1-stable_linux.x86_64`
Project: `~/workspace/subway-godot/` — renderer: GL Compatibility.

## 1. Scripted autotest — PASSED 19/19 (run twice, exit code 0)

Command:
```
Godot_v4.4.1-stable_linux.x86_64 --headless --path . -- --autotest
```
Deterministic run (fixed speed 15 m/s, random spawning disabled, obstacles
placed at exact positions through the track's test API). Assertions, in order:

| # | Assertion | Result |
|---|-----------|--------|
| 1 | Player starts in center lane, x = 0 | PASS |
| 2 | Lane switch right lands on x = +2.2 | PASS |
| 3 | Double lane switch left lands on x = −2.2 | PASS |
| 4 | Return to center lane | PASS |
| 5 | Test API places a low barrier | PASS |
| 6 | Timed jump clears the low barrier (no death) | PASS |
| 7 | Jump height at barrier crossing > 0.9 m | PASS |
| 8 | Test API places a high barrier | PASS |
| 9 | Slide passes under the high barrier (no death) | PASS |
| 10 | Player is in effective slide state while crossing the board | PASS |
| 11 | Test API places 5 coins | PASS |
| 12 | Running the coin line collects ≥ 4 of 5 (got ≥ 4) | PASS |
| 13 | Test API places a train | PASS |
| 14 | Running into the train kills the player | PASS |
| 15 | Score accrues from distance (≥ 50 at death) | PASS |
| 16 | Restart: player alive again | PASS |
| 17 | Restart: coin counter reset | PASS |
| 18 | Restart: player position reset near origin | PASS |
| 19 | Restart: lane reset to center | PASS |

Raw output also saved by the game itself to `autotest_results.txt` in the
project root (overwritten each run). A plain (non-test) headless run for
300 frames also completed with **zero script errors**.

## 2. Visual proof — rendered gameplay frames (Xvfb + movie writer)

Command (self-playing `--capture` AI driving, fixed 30 fps):
```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
  --write-movie <dir>/frame.png --fixed-fps 30 --quit-after 330 -- --capture
```
Two capture runs (330 + 210 frames) rendered successfully under software GL.
Frames were visually inspected by the agent. Kept stills in `screenshots/proof/`:

- `run-early.png` — runner mid-stride on center track, coin line ahead, HUD live.
- `train-ahead.png` — red train with lit headlights on the player's track, high barrier behind it.
- `dodge-and-coins.png` — after polish pass: AI has collected 4 coins, running the right lane
  between a high barrier (left) and a low barrier (center); HUD overlap fixed.
- `late-run.png` — higher speed (52 km/h shown), coin counter at 1 after a restart cycle.

Observed in frames (honest notes):
- Sunset look is intentionally warm; fog gives depth but the palette is
  monochrome-leaning — art direction is a follow-up decision, not a defect.
- During a slide under a high board the runner is briefly hidden behind the
  board from this camera angle (a few frames) — mechanically correct
  (autotest #9/#10), visually acceptable.
- The capture AI dodges most obstacles but is not perfect — it died and
  auto-restarted at least once during the 330-frame run (score/counter reset
  visible between frames 240 and 320 of that run).

## 3. NOT verified (needs a human / future work)

- **Human feel** — lane-switch weight, jump/slide timing comfort, camera lag:
  tuned to genre-standard numbers (0.13 s lane switch, snappy 34 m/s² gravity,
  FOV 68°→82° with speed) and proven mechanically, but only Sehrish playing
  it can judge the feel. This is the demo's whole point — pending her verdict.
- **Touch swipe on a real phone** — swipe handling is implemented
  (touch + mouse-drag fallback) but not yet tested on hardware.
- **Performance on a phone GPU** — desktop software-GL capture ran at ~9% of
  real-time (llvmpipe), which says nothing about a real device.
- **Exports** — none built. Web export needs the Godot export templates
  (~1 GB download, free) — deliberately skipped to protect the demo deadline;
  Android export likewise pending templates + Android SDK.
- **Audio** — none in this demo (by design).

## 4. Reproduce

```
GODOT=~/workspace/tools/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --import --path ~/workspace/subway-godot   # once
$GODOT --headless --path ~/workspace/subway-godot -- --autotest
$GODOT --path ~/workspace/subway-godot                        # play (desktop)
```
