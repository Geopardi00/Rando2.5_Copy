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
- Updated player scene: `scenes/player/main.tscn`
- Updated player scripts:
  - `scenes/player/player.gd`
  - `scripts/player/player.gd`
- Updated knife-thrower enemy logic: `scripts/enemies/enemy_knife_thrower.gd`
- Added dog enemy content:
  - `art/enemies/enemy_dog.png`
  - `scenes/enemies/enemy_dog.tscn`
  - `scripts/enemies/enemy_dog.gd`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
