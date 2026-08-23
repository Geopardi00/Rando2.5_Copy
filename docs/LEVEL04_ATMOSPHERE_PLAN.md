# Level04 Atmosphere

## Current structure

Level04 uses `Parallax2D` bands at background scroll scales `0.90`, `0.93`, and `0.95`, followed by gameplay at the default canvas depth and foreground bands from `1.10` through `1.30`. The level currently has no authored `PointLight2D`; `RedLight01` is a painted background sprite.

The project fog shader remains unchanged because Level03 depends on its hard-coded motion. The menu `FogFront` particle scene is also intentionally not reused because its 300 large smoke particles are too dense for gameplay.

## Implemented architecture

```text
World
├── BackgroundObjectsFar (0.90, z -8)
│   └── FogFar
├── BackgroundMid (0.93, z -7)
│   ├── FogMid
│   └── DustMid
├── BackgroundNear (0.95, z -6)
├── Gameplay (z 0)
└── ForegroundNear (1.20, z 8)
    └── DustNear
```

- `FogFar` is broad, cool, slow, low-opacity haze that ignores 2D lights.
- `FogMid` is slightly denser, moves in the opposing direction, and accepts atmosphere lights.
- `DustMid` uses 60 small, slow motes over a warehouse-sized box emitter.
- `DustNear` uses 23 larger, softer motes with quicker apparent motion.
- Near fog and extreme-foreground atmosphere are omitted to protect gameplay readability.

## Shared resources and tuning

Both fog sprites use `atmosphere_noise.tres` and separate local materials backed by `atmospheric_fog.gdshader`. The five intended tuning controls are `fog_tint`, `opacity`, `uv_scale`, `scroll_velocity`, and `distortion_strength`. Dust uses the shared 64×64 `dust_mote.png` texture and inspector-authored `ParticleProcessMaterial` resources.

The fog shader uses normal CanvasItem lighting and deliberately has no custom `light()` function. Broad fog coverage is limited to two sprites. Ambient particle simulation is limited to 83 particles total and runs at a fixed 30 FPS.

## Lighting convention

- Far fog: `light_mask = 0`.
- Mid fog and both dust layers: `light_mask = 2`.
- Gameplay remains on the default mask bit 1.
- Future warehouse lights that should affect both gameplay and atmosphere must use `range_item_cull_mask = 3`.
- Existing enemy and combat lights should stay on bit 1 unless their atmospheric interaction is deliberately art-directed.

Visible warehouse beams should use the project's textured `PointLight2D` technique with a low-energy `light_stream` texture and cull mask `3`. Permanent lamp placement is a separate lighting pass.

## Verification checklist

- Load Level04 without resource or shader errors.
- Traverse the camera path and check that far, mid, and near atmosphere move at distinct parallax rates.
- Toggle each atmosphere node to verify its contribution and confirm platform, hazard, enemy, and player silhouettes remain clear.
- With a temporary mask-2 light, confirm that mid fog and dust brighten while far fog does not.
- Check for seams, camera-edge gaps, obvious repetition, or particle spawning gaps.
- Compare the 1920×1080 profiler baseline with atmosphere enabled and disabled; target less than a 5% frame-rate change and no new spikes.
- Keep at most two broad transparent fog surfaces and 83 ambient particles active.
