# State of Game

Last updated: 2026-04-08

## Implemented Features
- Level 01 layout
- Player movement
- Jump with coyote time and input buffering
- Shooting with fire-rate limit
- Enemy patrol AI
- Bullets damage enemies
- Player respawns on hit

## Current Checkpoint Snapshot
- Updated player scene: `scenes/player/main.tscn`
- Updated enemy scripts:
  - `scripts/enemies/enemy.gd`
  - `scripts/enemies/enemy_dog.gd`
  - `scripts/enemies/enemy_knife_thrower.gd`
- Added blood FX assets and scene:
  - `art/FX/blood.png`
  - `scenes/fx/blood_burst.tscn`
  - `scenes/fx/blood_burst.gd`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
