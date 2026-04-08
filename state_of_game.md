# State of Game

Last updated: 2026-04-08

## High-Level Status
- Level 01 is in a good playable state.
- Core combat loop is working.
- Enemy and hazard systems are now in place and feel good in playtests.
- Basic combat feedback has been added with enemy hit flash and death particles.

## Implemented Features

### Player
- Horizontal movement
- Jumping
- Coyote time
- Jump input buffering
- Double jump
- Shooting
- Fire-rate limit on shooting
- Player dies in one hit
- Player death reloads the current scene
- Scene reload resets enemies, hazards, bullets, and temporary level state

### Combat
- Player bullets spawn correctly based on facing direction
- Bullets damage enemies
- Enemy hurtbox-based damage flow is working
- Enemy hit flash added via shader material parameter (`flash_amount`)
- Enemy death blood burst particles added

### Enemies
- **Patrol enemy**
  - Patrols left/right
  - Turns at walls
  - Turns at ledges
  - Takes bullet damage
  - Dies and registers defeat in `StateOfGame`
  - Uses white hit flash on damage
  - Spawns blood burst on death

- **Knife thrower enemy**
  - Stationary ground enemy
  - Faces player
  - Throws knife projectile on cooldown
  - Range and throw offset tuned
  - Takes 3 bullets to kill
  - Uses enemy hurtbox for bullet damage
  - Uses white hit flash on damage
  - Spawns blood burst on death

- **Dog enemy**
  - Patrol state
  - Chase state
  - Aggro / lose range logic
  - Vertical tolerance check for chasing
  - Turns at walls and ledges
  - Takes bullet damage
  - Uses white hit flash on damage
  - Spawns blood burst on death

### Enemy Projectiles
- Knife projectile scene created
- Knife projectile moves horizontally
- Knife flips correctly based on direction
- Knife kills player on hit
- Knife disappears on collision / lifetime end
- Throw offset adjusted so projectile does not immediately collide with the thrower

### Hazards
- **Spike hazard**
  - Built as `Area2D` kill zone
  - Kills player on contact by calling player death flow

- **Fall killzone**
  - Invisible `Area2D` below level
  - Kills player if they fall off the level

### Level / World
- Level 01 layout exists and is playable
- Level 01 enemy and hazard playtests are working well
- Hazard and enemy reset behavior is correct because level reloads on player death
- Parallax background near layer added
- Tile art integration started

### Visual Feedback / VFX
- White hit flash shader created and applied to enemies
- Per-instance material duplication added so enemy flashes do not affect other instances
- Blood burst particle scene created with `GPUParticles2D`
- Blood burst is spawned on enemy death

## Current Checkpoint Snapshot
- Updated player scene: `scenes/player/main.tscn`
- Updated level scene: `scenes/levels/level_01.tscn`
- Updated bullet sprite: `art/characters/bullet.png`
- Added hazard art folder: `art/hazards/`
- Added parallax background near layer: `art/parallax/background_near.png`
- Added tile art: `art/tiles/b01_stonechunk_flat_04.png`
- Added tile art: `art/tiles/wood_pillar_long.png`

## Important Scenes / Scripts

### Player
- `scenes/player/main.tscn`
- `player.gd`

### Enemies
- `enemy.gd` (basic patrol enemy)
- `enemy_dog.gd`
- `enemy_knife_thrower.gd`
- `knife_projectile.gd`
- `scenes/enemies/knife_projectile.tscn`
- `scenes/enemies/enemy_knife_thrower.tscn`
- `scenes/enemies/enemy_dog.tscn`

### Hazards
- Spike hazard scene / script
- Fall killzone scene / script

### FX
- `res://shaders/hit_flash.gdshader`
- `res://scenes/fx/blood_burst.tscn`
- `blood_burst.gd`

### State / Runtime
- Runtime state tracking lives in `scripts/state_of_game.gd`

## Current Design Rules
- Player dies in one hit
- Enemies respawn because the scene reloads on player death
- No health bar / hearts system yet
- No player or enemy animations yet
- Enemy behavior is intentionally simple and production-friendly
- Avoid overbuilding enemy architecture at this stage

## Things Tuned / Solved Recently
- Spike kill detection working
- Fall killzone working
- Knife projectile spawn offset fixed
- Knife thrower attack range increased
- Shared shader-material issue fixed by duplicating material per enemy instance
- Enemy respawn problem solved by reloading the current scene on player death

## Recommended Next Steps
- Level 01 polish pass
- Sound effects (shoot, hit, throw, death, hazard)
- Simple camera / combat juice
- Goal / level-complete presentation polish
- Start Level 02 after Level 01 feels consistently good

## Notes
- Current development priority has been: gameplay first, polish second.
- Full animation work has intentionally been postponed.
- Current enemy set is enough for meaningful Level 01 gameplay.
