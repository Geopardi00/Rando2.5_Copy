# State of Game

Last updated: 2026-06-20

## Latest Update - 2026-06-20
- Level 03 layout pass continued with newly placed platforms and additional Sprite2D decoration/prop work.
- Foreground depth pass added with Parallax2D layers for near, mid, and far foreground elements.
- Additional Level 03 enemies were placed for the current combat/layout pass.
- Moonbeam visuals were added and adjusted as part of the Level 03 atmosphere pass.
- Laser mine scene was updated again during the current hazard/audio polish pass.

## Latest Update - 2026-06-19
- Level 03 checkpoint respawn added around the checkpoint flag; deaths after activation reload the scene and respawn at the checkpoint marker.
- Reusable laser mine hazard added with beam-only trigger, explosion area, explosion animation, explosion sound, and cleanup that waits for sound playback.
- Level 03 prop and layout pass continued with checkpoint, sandbag, cover, bridge, tower, and environmental asset work.
- Player shooting polish added: muzzle flash follows a Marker2D barrel point and bullet sprite flips correctly when firing left.
- Enemy animation passes added for the basic soldier, knife thrower, and dog work.

## High-Level Status
- Level 01 is in a good playable state.
- Level 01 has been replaced with the newer edited layout from the accidental edit folder and now uses the newer TileMapLayer/dirt tileset pass.
- Core combat loop is working.
- Enemy and hazard systems are now in place and feel good in playtests.
- Basic combat feedback has been added with enemy hit flash, death particles, and hit audio.
- A main menu scene now exists with working scene flow into Level 01.
- Intro slideshow flow is now implemented.
- Main menu music is now implemented.
- Player animation flow is now active (idle/walk/jump/death).
- Level 02 building has started.
- Level 03 now has a first playable watchtower sniper test piece with rotating spotlight, cover blocking, line-of-sight detection, tracking, and shooting.
- A separate boss fight level now exists with a playable boss arena.
- Boss fight core loop is implemented and recently polished: shooting, reload, grenade throws, jump stomp, boss HP, player HP, camera shake, boss jump/stomp animations, grenade explosion animation, and crosshair grenade warnings.
- Current game flow is wired from intro cutscene to main menu, then Level 01, test_room_2, and boss fight.
- Latest Level 03 work is focused on prototyping one stationary non-killable watchtower sniper enemy before building a full level around it.
- Latest Git checkpoint is for the Level 01 layout/art import in this working copy.

## Implemented Features

### Player
- Horizontal movement
- Jumping
- Coyote time
- Jump input buffering
- Double jump
- Shooting
- Fire-rate limit on shooting
- Player now has simple HP support (`max_hp = 3`, `current_hp`, `take_damage()`)
- Player has brief invulnerability / blinking after taking damage
- Player still supports instant-death via `die()` for hazards and legacy systems
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
- Boss uses the same player-bullet-to-`enemy_hurtbox` damage convention as regular enemies
- Boss attacks damage the player through `take_damage(1)`
- Dog contact, knife thrower contact, and thrown knife projectiles now deal 3 damage, making them one-hit kills against the 3 HP player

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

- **Boss fight boss**
  - Separate boss scene: `res://scenes/boss/boss.tscn`
  - Boss AI script: `res://scripts/boss/boss.gd`
  - Uses `CharacterBody2D`
  - Has HP and emits `boss_defeated`
  - Faces the player using `AnimatedSprite2D.flip_h`
  - Uses `AnimatedSprite2D.play()` for animation control; `AnimationTree` remains in the scene as a learning scaffold but is disabled in code for now
  - Starts the fight with shooting
  - Later picks attacks with weighted random logic in `choose_next_attack()`
  - Current attacks: shooting bursts, reload window, grenade throws, jump stomp
  - Jump and stomp now use real boss `AnimatedSprite2D` animations
  - Jump stomp jumps between arena sides and avoids center wobble by locking jump direction
  - Stomp landing creates brief damage area and triggers camera shake
  - Boss remains vulnerable during all attacks and reload

- **Watchtower sentry sniper**
  - First Level 03-specific enemy prototype
  - Stationary sniper placed on a watchtower/high-ground setup
  - Not designed to be killable by the player yet
  - Uses a rotating `VisionPivot` scan between exported angle limits
  - Uses a visual-only `PointLight2D` spotlight cone
  - Gameplay detection is separate from the light visual and uses distance, cone angle checks, and physics ray queries
  - Cover/ground collision can block detection through raycast line of sight
  - Supports exported minimum and maximum vision range
  - Supports alert delay before firing
  - After detection, tracks the player with the beam while line of sight remains clear
  - Holds the last seen angle briefly when the player reaches cover, then returns to scanning
  - Reuses the boss bullet projectile for aimed sniper shots with exported speed and damage
  - Spotlight visual was adjusted to keep the `PointLight2D` origin at the pivot and use `texture_offset` for cone placement, improving LightOccluder2D behavior

### Enemy Projectiles
- Knife projectile scene created
- Knife projectile moves horizontally
- Knife flips correctly based on direction
- Knife deals 3 damage and kills the current 3 HP player on hit
- Knife disappears on collision / lifetime end
- Throw offset adjusted so projectile does not immediately collide with the thrower
- Boss bullet scene/script added
- Boss bullets move in a normalized direction, damage the player, and disappear on collision/lifetime/screen exit
- Boss grenade scene/script added
- Boss grenades use scripted arc movement and explode at target positions
- Boss grenade warning uses `art/props/crosshair.png`
- Boss grenade projectile now uses dedicated grenade art: `art/props/grenade.png`
- Boss grenade explosion now uses a separate animation that plays only when the grenade reaches the floor/target
- Grenade warning time and grenade air time are now separate boss export variables
- Watchtower sniper reuses `scenes/projectiles/boss_bullet.tscn` for aimed test shots

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
- Level 01 layout was imported from `C:\Users\mjket\Godot projects\Rambo2.5\rambo-2.5` into this working copy, with missing referenced `art/level01` assets copied over.
- Level 01 now uses embedded TileSet/TileMapLayer resources for the newer dirt/block tile pass.
- Level 01 enemy and hazard playtests are working well
- Hazard and enemy reset behavior is correct because level reloads on player death
- Parallax background near layer added
- Tile art integration started
- Test room scene added for focused gameplay iteration
- Tunnel door prop art added
- Level 02 building has started
- TileMapLayer setup for gameplay/collision is ready
- TileMapLayer setup for background is ready
- Boss fight level exists as a separate 1920x1080 arena scene
- Boss arena includes player spawn, boss spawn, floor/walls, Camera2D, and boss/grenade limit markers
- Boss fight final stage art added under `art/bosslevel1/`
- Project main scene is now the intro cutscene again
- Level progression is wired: `cut_scene.tscn` -> `main_menu.tscn` -> `level_01.tscn` -> `test_room_2.tscn` -> `boss_fight_level.tscn`
- Level 03 scene/assets have been added and are in progress
- Level 03 test scene now includes player spawn, simple ground/cover setup, watchtower art, stationary sniper, spotlight, LightOccluder2D test objects, and basic goal area
- Level 03 cover testing currently uses normal collision for gameplay ray blocking and LightOccluder2D for visual shadow blocking

### Visual Feedback / VFX
- White hit flash shader created and applied to enemies
- Per-instance material duplication added so enemy flashes do not affect other instances
- Blood burst particle scene created with `GPUParticles2D`
- Blood burst is spawned on enemy death
- Grenade warning FX scene added
- Grenade warning FX now uses the crosshair prop sprite instead of the placeholder polygon/line circle
- Grenade explosion animation frames added under `art/enemies/animations/Boss/grenade/explosion/`
- Boss stomp landing triggers camera shake through the boss fight level script
- Level 03 sniper spotlight currently uses `art/vfx/light_stream.jpg` / related light stream iterations as a cone texture
- Level 03 spotlight is visual-only; actual stealth detection does not depend on rendered light pixels

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
- Main project boot flow now starts from the intro cutscene
- Main menu Start loads Level 01
- Level goals now advance the player from Level 01 to test_room_2, then to the boss fight

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
- Added boss fight level: `scenes/boss/boss_fight_level.tscn`
- Added boss scene/script: `scenes/boss/boss.tscn`, `scripts/boss/boss.gd`
- Added boss projectiles: `scenes/projectiles/boss_bullet.tscn`, `scripts/projectiles/boss_bullet.gd`, `scenes/projectiles/boss_grenade.tscn`, `scripts/projectiles/boss_grenade.gd`
- Added grenade warning FX: `scenes/fx/grenade_warning.tscn`
- Added grenade warning crosshair asset: `art/props/crosshair.png`
- Added grenade projectile art: `art/props/grenade.png`
- Added grenade explosion animation frames: `art/enemies/animations/Boss/grenade/explosion/`
- Added boss jump and stomp animation frames: `art/enemies/animations/Boss/jump/`, `art/enemies/animations/Boss/stomp/`
- Added boss fight level script for camera shake: `scripts/levels/boss_fight_level.gd`
- Added/updated boss arena art: `art/bosslevel1/stage1test.png`, `art/bosslevel1/stage1final.png`
- Added Level 03 scene/script and art assets: `scenes/levels/level_03.tscn`, `scripts/levels/level_03.gd`, `art/level03/`
- Added Level 03 sniper script: `scripts/enemies/enemy_sentry_sniper.gd`
- Added Level 03 watchtower sniper test scene content inside `scenes/levels/level_03.tscn`
- Added/iterated Level 03 watchtower and light beam assets under `art/level03/` and `art/vfx/`
- Updated player health flow in both `scripts/player/player.gd` and `scenes/player/player.gd`
- Latest checkpoint commit: `3ede60c Add boss fight checkpoint`
- Latest working progress includes boss animation/FX polish, final game-flow wiring, and enemy one-hit-kill damage tuning

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
- `enemy_sentry_sniper.gd`
- `knife_projectile.gd`
- `scenes/enemies/knife_projectile.tscn`
- `scenes/enemies/enemy_knife_thrower.tscn`
- `scenes/enemies/enemy_dog.tscn`

### Boss Fight
- `scenes/boss/boss_fight_level.tscn`
- `scenes/boss/boss.tscn`
- `scripts/boss/boss.gd`
- `scripts/levels/boss_fight_level.gd`
- `scenes/projectiles/boss_bullet.tscn`
- `scripts/projectiles/boss_bullet.gd`
- `scenes/projectiles/boss_grenade.tscn`
- `scripts/projectiles/boss_grenade.gd`
- `scenes/fx/grenade_warning.tscn`
- `art/props/crosshair.png`

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
- `res://scenes/fx/grenade_warning.tscn`
- `blood_burst.gd`

### State / Runtime
- Runtime state tracking lives in `scripts/state_of_game.gd`

## Current Design Rules
- Player has 3 HP for boss-fight damage, but `die()` still supports instant-death hazards
- Enemies respawn because the scene reloads on player death
- No health bar / hearts UI yet
- Player animations are in progress and now active in-game
- Enemy animation pass is still pending
- Boss animation currently uses `AnimatedSprite2D.play()` directly; AnimationTree is kept in the boss scene but is not driving gameplay animation yet
- Boss fight camera is currently fixed at 1.0 zoom with no camera follow or parallax; stomp camera shake remains enabled
- Grenades show the airborne grenade sprite until impact, then hide it and play the explosion animation
- Enemy behavior is intentionally simple and production-friendly
- Avoid overbuilding enemy architecture at this stage
- Level 03 sniper is intentionally a focused test enemy, not a full stealth AI system
- Spotlight rendering is visual-only; gameplay visibility must continue to use raycast/physics logic
- Player can hide behind collision cover; LightOccluder2D is for matching the visual beam where practical
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
- Boss fight scene created and playable
- Boss shooting, reload, grenade throw, and jump stomp implemented
- Boss faces player correctly after sprite-facing adjustment
- Stomp warning sign was removed because the fight feels better without it
- Stomp center wobble fixed by choosing arena sides and locking jump direction
- Boss fight camera shake added on stomp landing
- Boss jump/stomp animations added and wired into the jump stomp flow
- Grenade air time separated from warning duration
- Grenade explosion animation fixed so it plays only on impact, not while the grenade is flying
- Grenade warning marker replaced with `crosshair.png`
- Boss fight camera reverted to fixed 1.0 zoom with no follow/parallax after playtesting
- Opening and level progression flow wired through intro, menu, Level 01, test_room_2, and boss fight
- Dog, knife thrower, and knife projectile damage tuned to 3 for one-hit kills
- Boss attack tuning is editable in `choose_next_attack()` and exported variables on the boss
- Level 03 watchtower sniper prototype added and playtested
- Sniper detection was aligned to the `VisionPivot` rather than `ShootPoint` so gameplay visibility better matches the spotlight origin
- Sniper gained a minimum vision range so the player can stand too close/below the tower without being tracked or shot
- Sniper tracking now follows the player after first detection, holds last seen angle briefly behind cover, and then resumes scanning
- Player visibility checks now sample multiple configurable points on the player body via `player_detection_offsets`
- Sniper beam aiming can be tuned separately with `player_aim_offset`
- PointLight2D spotlight was changed to keep its node position near the pivot and use `texture_offset` so visual cone placement does not break shadow origin as badly
- Git remote updated to `https://github.com/Geopardi00/Rando2.5_Copy.git`
- Git checkpoint pushed: `3ede60c Add boss fight checkpoint`
- Level 01 edited layout was recovered from the accidental edit folder and imported into the current working project
- Godot reimported the copied Level 01 textures and a headless load check of `res://scenes/levels/level_01.tscn` passed

## Recommended Next Steps
- Playtest the newly imported Level 01 layout in the editor and do a polish pass on enemy/hazard spacing, collisions, and foreground readability
- Add remaining core sound effects (shoot, throw, UI click, ambient)
- Add boss-specific sound effects for shooting, reload, grenade throw/explosion, stomp, hurt, and death
- Add boss HP UI / player health UI when the fight needs presentation polish
- Add remaining boss animations for reload, throw, hurt, and death
- Decide later whether to wire AnimationTree fully or continue with direct `AnimatedSprite2D.play()`
- Enemy animation pass
- Simple camera / combat juice
- Goal / level-complete presentation polish
- Clean game flow between menu and gameplay
- Continue Level 02 / Level 03 building after Level 01 feels consistently good
- Continue tuning Level 03 sniper spotlight visuals, cover readability, and test layout before expanding into a full level section

## Notes
- Current development priority has been: gameplay first, polish second.
- Full animation polish is still selective; player animation is now active while enemy animation remains pending.
- Current enemy set is enough for meaningful Level 01 gameplay.
- Main menu is now good enough to support a cleaner presentation loop for the project.
- Boss fight is in gameplay prototype state: functional attacks and damage are in, but UI/audio/final animation polish are still pending.

