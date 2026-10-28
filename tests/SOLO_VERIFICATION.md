# Solo expansion verification — 2026-10-27

Godot 4.7.2 Compatibility, Windows. Run `--headless --path . --script res://tests/solo_regression.gd`.

**8,866 checks passed; zero failures.** The seeded integration test ran 191 shifts. During the first 160 cycles, 3,840 connections opened and 3,839 closed. All 277 unprotected interior connections participated; the remaining two were deliberately frozen/occupied. After unlocking both boundaries, all 18 border connections participated too.

The suite checks actual TileMap physics queries, every navigation cell, connectivity of all 54 chambers in each sector, preservation of occupied/frozen passages, six-second timing, solo progression, guidance after combat, checkpoint respawn, Athena and restart.

Projectile tests cover exact bow-muzzle agreement in eight directions, nearest-enemy damage, first-hit removal, walls blocking enemies behind them and muzzle obstruction preventing shots through walls.

The pursuit test places a spirit and player on opposite sides of a closed wall. The spirit followed a 17-tile detour, including a maze shift at simulation tick 120, and reached attack range in 266 ticks without entering masonry. Additional checks verify search and return after contact is lost.

Live Godot MCP checks confirmed a natural six-second shift affecting 48 connections across all three sectors, full map and field guide controls, visible in-flight arrows aligned with the bow, darkness centred on the player and unlit HUD text. A local gameplay snapshot reported 165 FPS and about 6.3 ms/frame; this is not a hardware-independent performance guarantee.

The existing `connected_walls.png` was not edited. The world now measures 6,976×3,520 pixels and contains 162 chambers, compared with 27 previously. No full manual campaign playthrough was performed; progression through the ending was exercised by the integration suite.
