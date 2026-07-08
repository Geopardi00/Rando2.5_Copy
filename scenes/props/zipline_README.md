# Zipline2D Prototype

Place `res://scenes/props/zipline_2d.tscn` in a level, then move `StartAnchor` and `EndAnchor` to set the cable length and slope.

- Press `E` or Xbox `B` near the cable to attach.
- Press `jump` while riding to detach.
- The lower anchor determines the default downhill direction.
- Main tuning values live on the `Zipline2D` root: sag, rider bend, grab thickness, ride acceleration, maximum speed, and detach jump velocity.

Prototype limitations:
- One rider only.
- No physical rope segments or swinging.
- Collision while riding is intentionally simple for first-pass feel testing.
