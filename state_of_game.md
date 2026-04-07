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
- Updated project config: `project.godot`
- Updated level scene: `scenes/levels/level_01.tscn`
- Updated player scenes and scripts:
  - `scenes/player/main.tscn`
  - `scenes/player/player.tscn`
  - `scenes/player/player.gd`
  - `scripts/player/player.gd`
- Updated enemy logic: `scripts/enemies/enemy.gd`
- Added hazard kill zone:
  - `scenes/Hazards/fall_kill_zone.tscn`
  - `scripts/Hazards/fall_kill_zone.gd`
- Added environment art:
  - `art/props/tree01.png`
  - `art/tiles/sand.png`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
