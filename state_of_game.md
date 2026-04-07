# State of Game

Last updated: 2026-04-07

## Implemented Features
- Level 01 layout
- Player movement
- Jump with coyote time and input buffering
- Shooting with fire-rate limit
- Enemy patrol AI
- Bullets damage enemies
- Player respawns on hit

## Current Checkpoint Snapshot
- Updated level scene: `scenes/levels/level_01.tscn`
- Updated player scene and scripts:
  - `scenes/player/main.tscn`
  - `scenes/player/player.gd`
  - `scripts/player/player.gd`
- Added enemy content:
  - `scenes/enemies/enemy_knife_thrower.tscn`
  - `scripts/enemies/enemy_knife_thrower.gd`
  - `art/enemies/Enemy2.png`
- Added hazards content:
  - `scenes/Hazards/`
  - `scripts/Hazards/`
- Added weapons content:
  - `art/Weapons/`
  - `scenes/Weapons/`
  - `scripts/Weapons/`
- Added foreground parallax art:
  - `art/parallax/foreground_plant01.png`
  - `art/parallax/foreground_vines01.png`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
