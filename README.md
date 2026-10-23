# Subway Lahore — Core Demo (Godot 4.4.1, GDScript)

An original 3-lane endless runner built to judge one thing: **feel**.
Golden-hour railway through a Lahore-flavoured city — dodge trains, jump the
low boards, slide under the high boards, grab coins, go faster until you don't.

100% free stack: Godot engine, zero imported assets — the runner, trains,
barriers, coins and city are all built procedurally in code. No third-party IP.

## Play

```
~/workspace/tools/godot/Godot_v4.4.1-stable_linux.x86_64 --path ~/workspace/subway-godot
```

Controls: **Arrows / WASD** (or swipe / mouse-drag) — left/right switch lane,
up jumps, down slides; **R** restarts after a crash (tap also works).

## Layout

- `scripts/player.gd` — kinematic runner + fully procedural animated character
  (two-segment arms/legs, run cycle, jump tuck, slide, fall).
- `scripts/track.gd` — recycled 24 m track segments (9 = ~216 m), obstacle and
  coin spawning, data-driven collision (no physics bodies — deterministic).
- `scripts/main.gd` — game state, camera feel (lag + speed FOV), HUD, input,
  plus `--autotest` verification driver and `--capture` self-playing mode.
- `VERIFY.md` — what was actually proven, and what still needs a human.
- `screenshots/proof/` — rendered gameplay stills from the capture runs.

Gameplay tuning lives at the top of `player.gd`
(speed/ramp/gravity/jump/lane-speed constants).
