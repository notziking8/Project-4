# Revamp verification — 2026-10-27

Historical verification of the earlier two-explorer build. The current solo build is documented in `SOLO_VERIFICATION.md`; the regression entry point now runs the solo suite.

Godot 4.7.2, Compatibility renderer, Windows.

## Automated integration run

`Godot --headless --path . --script res://tests/grid_regression.gd`

Latest run: **3,017 checks, zero failures**, 200 randomized shifts, 600 connections opened and 599 closed. Counts vary with the initial randomized map and protected occupants.

Checks include actual TileMap physics point queries after changes, swept movement against outer walls, complete navigation/occupancy agreement, connectivity of every chamber, frozen and occupied passages, separate spawns, gate isolation/opening, reunion, checkpoint respawn, Athena reveal and restart.

## Live Godot MCP checks

- Injected WASD in all four directions for both explorers: movement and direction rows correct in all eight cases.
- Q changes the active explorer, clears stale walking, and snaps the camera to the new region.
- Aimed at a closed passage and injected F: selected connection entered the ten-second frozen state.
- Inspected screenshots of both explorers, wall junctions, the Minotaur and the expanded map.
- Gameplay profiler snapshot in the Minotaur chamber: 165 FPS, about 6.4 ms/frame on this machine. This is a local snapshot, not a hardware-independent performance guarantee.
- No new editor errors after the live playtests.

## Asset verification

All 48 walk-frame cells were checked for nonempty alpha and an exact bottom boundary of y=60. Source crops use one scale per explorer and preserve complete directional silhouettes. The old grid importer redirects to the measured importer.

The generated attack poses are not used as directional body animations; a pivoted bow preserves facing and foot placement. Hurt uses a brief tint. These are deliberate presentation choices documented in `POLISH_RULES.md`.
