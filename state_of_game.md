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
- Updated enemy scenes:
  - `scenes/enemies/enemy.tscn`
  - `scenes/enemies/enemy_dog.tscn`
  - `scenes/enemies/enemy_knife_thrower.tscn`
- Updated enemy scripts:
  - `scripts/enemies/enemy.gd`
  - `scripts/enemies/enemy_dog.gd`
  - `scripts/enemies/enemy_knife_thrower.gd`
- Added shader effects:
  - `shaders/hit_flash.gdshader`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
