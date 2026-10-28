# Minotaur release and hunt verification

Godot 4.7.2, Compatibility renderer, Windows.

- Existing solo integration suite: **8,867 checks, zero failures** across 191 shifts.
- Boss suite: **345 checks, zero failures**. The seal survived 50 shifts; all 24 spirits remained reachable. Actual doorway physics queries stayed blocked, and neither F nor projectiles bypassed the seal.
- Keeping one spirit alive in an earlier sector prevented release. Its death immediately opened all three boss doors and began pursuit.
- A player beyond normal spirit detection range and behind walls was reached in 578 simulation ticks, including a mid-hunt maze shift. The boss never entered masonry or fell back into search/return. Respawn preserved the hunt, defeat allowed Athena, and restart restored the seal.
- Live Godot MCP inspection confirmed gray horns in the sealed chamber on the full map. After release, the pink marker moved with the boss from (6662,1760) to (6389.75,1760) over two seconds of pursuit. The same marker renderer is used on the minimap.

Run `--headless --path . --script res://tests/minotaur_regression.gd` for the focused tests. The earlier solo verification document records the preceding version; these results cover the boss changes.
