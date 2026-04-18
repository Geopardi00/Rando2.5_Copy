# State of Game

Last updated: 2026-04-17

## High-Level Status
- Level 01 is in a good playable state.
- Core combat loop is working.
- Enemy and hazard systems are now in place and feel good in playtests.
- Basic combat feedback has been added with enemy hit flash, death particles, and hit audio.
- A main menu scene now exists with working scene flow into Level 01.
- Intro slideshow flow is now implemented.
- Main menu music is now implemented.
- Player animation flow is now active (idle/walk/jump/death).
- Level 02 building has started.

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
- AnimatedSprite2D-based player animation state handling
- Player uses idle/walk/jump/death animations in gameplay

### Combat
- Player bullets spawn correctly based on facing direction
- Bullets damage enemies
- Enemy hurtbox-based damage flow is working
- Enemy hit flash added via shader material parameter (`flash_amount`)
- Enemy death blood burst particles added
- Enemy hit sound now plays reliably, including on the killing hit, by spawning a one-shot `AudioStreamPlayer2D` in code

### Enemies
- **Patrol enemy**
  - Patrols left/right
  - Turns at walls
  - Turns at ledges
  - Takes bullet damage
  - Dies and registers defeat in `StateOfGame`
  - Uses white hit flash on damage
  - Spawns blood burst on death
  - Plays hit sound on damage

- **Knife thrower enemy**
  - Stationary ground enemy
  - Faces player
  - Throws knife projectile on cooldown
  - Range and throw offset tuned
  - Takes 3 bullets to kill
  - Uses enemy hurtbox for bullet damage
  - Uses white hit flash on damage
  - Spawns blood burst on death
  - Plays hit sound on damage

- **Dog enemy**
  - Patrol state
  - Chase state
  - Aggro / lose range logic
  - Vertical tolerance check for chasing
  - Turns at walls and ledges
  - Takes bullet damage
  - Uses white hit flash on damage
  - Spawns blood burst on death
  - Plays hit sound on damage

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

- **Falling stalactite hazard**
  - First Level 02 hazard has been added
  - Designed as an overhead falling threat for traversal pressure

### Level / World
- Level 01 layout exists and is playable
- Level 01 enemy and hazard playtests are working well
- Hazard and enemy reset behavior is correct because level reloads on player death
- Parallax background near layer added
- Tile art integration started
- Test room scene added for focused gameplay iteration
- Tunnel door prop art added
- Level 02 building has started
- TileMapLayer setup for gameplay/collision is ready
- TileMapLayer setup for background is ready

### Visual Feedback / VFX
- White hit flash shader created and applied to enemies
- Per-instance material duplication added so enemy flashes do not affect other instances
- Blood burst particle scene created with `GPUParticles2D`
- Blood burst is spawned on enemy death

### Audio
- Enemy hit sound workflow added
- Hit sound now survives enemy death by spawning a separate `AudioStreamPlayer2D` in code instead of relying on the enemy-local player
- Main menu background music playback is now implemented
- Audio setup approach favors simple per-scene source nodes with code-spawned one-shot playback when needed

### UI / Main Menu
- Main menu scene created
- Background image displays correctly at runtime via forced full-rect setup in script
- TextureButton-based menu buttons implemented
- Buttons: **Start**, **Options**, **Exit**
- Hover scale animation works
- Click press animation works
- `Start` loads Level 01
- `Exit` quits the game
- Minimal `OptionsPanel` implemented and can be opened/closed
- Fog / smoke particle layers added to menu background
- Menu presentation is now visually functional and atmospheric

### Intro / Story Flow
- Intro slideshow scene created
- Intro slideshow script and image sequence implemented
- Intro flow currently feeds into the main menu

## Current Checkpoint Snapshot
- Updated player scene: `scenes/player/main.tscn`
- Updated level scene: `scenes/levels/level_01.tscn`
- Updated bullet sprite: `art/characters/bullet.png`
- Added hazard art folder: `art/hazards/`
- Added parallax background near layer: `art/parallax/background_near.png`
- Added tile art: `art/tiles/b01_stonechunk_flat_04.png`
- Added tile art: `art/tiles/wood_pillar_long.png`
- Added menu scene: `scenes/ui/main_menu.tscn`
- Added menu script: `main_menu.gd`
- Added hit flash shader: `res://shaders/hit_flash.gdshader`
- Added blood burst FX scene: `res://scenes/fx/blood_burst.tscn`
- Added intro cutscene scene/script: `scenes/Intro/cut_scene.tscn`, `scripts/Intro/cut_scene.gd`
- Added intro art sequence: `art/intro/pic1.png` to `art/intro/pic5.png`
- Added intro voiceover: `audio/intro/opening_monologue.wav`
- Added main menu music: `audio/music/Shadow Over Hope.mp3`
- Added player animation frames: `art/characters/animations/idle`, `walk`, `jump`, `death`
- Added test room scene: `scenes/levels/test_room.tscn`
- Added tunnel door prop: `art/props/tunneldoor.png`
- Level 02 building started
- TileMapLayer for gameplay/collision is ready
- TileMapLayer for background is ready
- Added first new Level 02 hazard: falling stalactite

## Important Scenes / Scripts

### Player
- `scenes/player/main.tscn`
- `player.gd`
- `scenes/player/player.tscn`
- `scripts/player/player.gd`

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
- Falling stalactite hazard (Level 02)

### UI
- `scenes/ui/main_menu.tscn`
- `main_menu.gd`

### Intro
- `scenes/Intro/cut_scene.tscn`
- `scripts/Intro/cut_scene.gd`

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
- Player animations are in progress and now active in-game
- Enemy animation pass is still pending
- Enemy behavior is intentionally simple and production-friendly
- Avoid overbuilding enemy architecture at this stage
- Menu/UI implementation should stay lightweight and presentation-focused for now

## Things Tuned / Solved Recently
- Spike kill detection working
- Fall killzone working
- Knife projectile spawn offset fixed
- Knife thrower attack range increased
- Shared shader-material issue fixed by duplicating material per enemy instance
- Enemy respawn problem solved by reloading the current scene on player death
- Main menu background runtime sizing fixed by forcing full-rect setup in script
- Button spacing and menu positioning tuned
- Menu fog visibility/debug issues solved
- Enemy hit sound cutting off on death solved by code-spawned one-shot audio playback
- Player idle/walk/jump/death animation sets imported and wired into player logic
- Player death animation integrated into death flow
- Level 02 building started
- TileMapLayer setup for gameplay/collision and background completed
- First Level 02 hazard (falling stalactite) added

## Recommended Next Steps
- Level 01 polish pass
- Add remaining core sound effects (shoot, throw, UI click, ambient)
- Enemy animation pass
- Simple camera / combat juice
- Goal / level-complete presentation polish
- Clean game flow between menu and gameplay
- Start Level 02 after Level 01 feels consistently good

## Notes
- Current development priority has been: gameplay first, polish second.
- Full animation polish is still selective; player animation is now active while enemy animation remains pending.
- Current enemy set is enough for meaningful Level 01 gameplay.
- Main menu is now good enough to support a cleaner presentation loop for the project.
