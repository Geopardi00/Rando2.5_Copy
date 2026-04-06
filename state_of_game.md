# State of Game

Last updated: 2026-04-06

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
- Updated level scene: `scenes/levels/level_01.tscn`
- Updated bullet sprite: `art/characters/bullet.png`
- Added hazard art folder: `art/hazards/`
- Added parallax background near layer: `art/parallax/background_near.png`
- Added tile art: `art/tiles/b01_stonechunk_flat_04.png`
- Added tile art: `art/tiles/wood_pillar_long.png`

## Notes
- Runtime state tracking lives in `scripts/state_of_game.gd`.
