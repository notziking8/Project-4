# Utility / Inventory MVP — Michael Nearn

Validated with Godot 4.7.2 headless on October 28, 2026:

- Inventory regression: 31 checks, zero failures.
- Existing solo regression: 8,867 checks, zero failures.
- Existing Minotaur regression: 345 checks, zero failures.
- `git diff --check` passed.

Run each suite using the Godot console executable:

```text
godot --headless --path . --script res://tests/inventory_regression.gd
godot --headless --path . --script res://tests/solo_regression.gd
godot --headless --path . --script res://tests/minotaur_regression.gd
```

Open the project in Godot first to import assets on a fresh checkout. Restricted headless runs emitted a Windows certificate-store warning; all three suites completed successfully.

Michael Nearn subsequently confirmed manual testing of the Utility / Inventory system in Godot: everything worked correctly. This confirmation covers the mechanic; a full campaign playthrough was not reported.

## Demonstration

1. Run `project.godot` with F5 and press Enter. Tab opens/closes the icon inventory. The ten HUD squares show occupied (gold) and free (gray) capacity. Starting weapon, light armor and two relics occupy five slots.
2. Collect nearby loot with E. Light/medium/heavy armor cost 2/3/4 slots; each weapon or relic costs one. Equipped gear counts. An item that does not fit remains in the world; pickups never equip automatically.
3. Take enemy damage, then press R: one relic disappears, health increases by 25 up to 100, and one slot becomes free. R cannot consume another for five gameplay seconds, at full health, while dead, or without relics. The cyan cooldown bar shows readiness. Existing pause, map and help overlays pause simulation and the timer.
4. Clear a sector and enter its shrine. With Tab open, left-click armor to equip it or select a spare/relic and press X to drop it. Outside activated shrines or during combat, equipment changes and drops fail. The equipped suit and reusable weapon are protected against dropping; spare weapons can be dropped. Previously activated shrines remain usable.
5. Die with backup armor. Equipped armor, weapons and unused relics remain; all backup suits drop at the death position for E recovery. Healing cooldown resets. Identical suits are interchangeable: the first copy of the equipped type represents the equipped suit, and every additional copy is a backup.
6. Pause with Escape and choose Restart. Initial inventory and world loot return. There are exactly two relic pickups per sector, at local coordinates (992, 992) and (1760, 2912), in existing walkable rooms.

Explorer switching and additional visual polish are deferred. This MVP uses the existing solo player, damage modifiers, checkpoint activation, enemy loot, icon atlas and drawn UI; no new scene wiring is required.
