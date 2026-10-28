extends SceneTree
# Armor Types regression suite (Zion King).
# Run: godot --headless --path . --script res://tests/armor_regression.gd
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.maze.generate(73491)
	g.shifts = g.maze.connections
	g.build_navigation()
	await physics_frame
	await physics_frame

	# Damage: general reduction first, then medium's electrical resistance.
	var expected_physical := {"light": 17.0, "medium": 13.0, "heavy": 8.0}
	for kind in expected_physical:
		g.equipped = kind
		check(near(g.armor_damage(20.0, false), expected_physical[kind]), "20-point physical hit in %s armor" % kind)
	g.equipped = "medium"
	check(near(g.armor_damage(20.0, true), 9.75), "Medium armor: 20 x 0.65 x 0.75 = 9.75 electrical")
	check(near(g.armor_damage(10.0, true), 4.875), "Medium armor vs electrical Light spirit (10 dmg)")
	g.equipped = "light"
	check(near(g.armor_damage(10.0, true), 8.5), "Light armor gives no electrical resistance")
	g.equipped = "heavy"
	check(near(g.armor_damage(10.0, true), 4.0), "Heavy armor gives no extra electrical resistance")

	# Fractional health is retained.
	g.equipped = "medium"
	g.health = 100.0
	g.player_pos = Vector2(224, 224)
	g.take_damage(20.0, true, Vector2(224, 300))
	check(near(g.health, 90.25), "Fractional health retained after a 9.75 hit")

	# Movement speed in Godot units per second (64 px = 1 unit).
	var expected_speed := {"light": 4.4, "medium": 4.0, "heavy": 3.4}
	for kind in expected_speed:
		g.equipped = kind
		check(near(g.move_speed() / g.UNIT, expected_speed[kind]), "%s armor speed is %s units/s" % [kind, expected_speed[kind]])

	# Knockback: 0.5 unit away from the attacker unless wearing heavy armor.
	g.equipped = "light"
	g.health = 100.0
	g.player_pos = Vector2(224, 224)
	g.take_damage(10.0, false, Vector2(124, 224))
	check(near(g.player_pos.x - 224.0, 0.5 * g.UNIT), "Light armor is knocked back 0.5 unit")
	g.equipped = "heavy"
	g.player_pos = Vector2(224, 224)
	g.take_damage(20.0, false, Vector2(124, 224))
	check(g.player_pos == Vector2(224, 224), "Heavy armor prevents knockback")

	# Armor appears in the world: remnants, sealed chests and shrine rewards.
	var remnants := 0
	var chests := 0
	for pickup in g.pickups:
		if pickup.get("remnant", false):
			remnants += 1
			check(pickup.kind in g.ARMOR_KINDS, "Remnant is armor")
			check(not g.body_collides(pickup.pos, 16.0, g.blocking_rects()), "Remnant is reachable floor")
		if pickup.get("chest", false):
			chests += 1
			check(pickup.locked and pickup.kind in g.ARMOR_KINDS, "Chest holds armor and starts sealed")
	check(remnants == 6, "Two armor remnants per sector")
	check(chests == 3, "One sealed stone chest per sector")

	# Sealed chest cannot be opened until its sector is cleared.
	var chest: Dictionary = {}
	for pickup in g.pickups:
		if pickup.get("chest", false) and pickup.sector == 0: chest = pickup
	g.inventory = ["weapon", "light"]
	g.equipped = "light"
	g.player_pos = chest.pos
	var before: int = g.inventory.size()
	g.pick_up()
	check(g.inventory.size() == before and "sealed" in g.message, "Sealed chest refuses pickup and explains why")
	for enemy in g.enemies:
		if enemy.sector == 0:
			enemy.alive = false
			enemy.pursuing = false
	g.pick_up()
	check(g.inventory.size() == before + 1 and g.inventory.back() == chest.kind, "Chest opens after sector 0 is cleared")
	check(g.opened_chests.size() == 1, "Opened chest is remembered for drawing")
	check(g.equipped == "light", "Pickups never auto-equip")

	# Changing armor: only at an activated shrine, outside combat.
	g.inventory = ["weapon", "light", "heavy"]
	g.equipped = "light"
	g.checkpoint = -1
	g.player_pos = g.checkpoints[0]
	g.selected_item = 2
	g.equip_selected()
	check(g.equipped == "light" and "shrine" in g.message, "Cannot equip at an inactive shrine")
	g.update_shrines()
	check(g.checkpoint == 0, "Shrine 0 activates")
	var rewards := 0
	for pickup in g.pickups:
		if pickup.get("reward", false): rewards += 1
	check(rewards == 1, "Activated shrine spawns one armor reward")
	g.selected_item = 2
	g.equip_selected()
	check(g.equipped == "heavy", "Equip works at an activated shrine")
	g.player_pos = Vector2(224, 224)
	g.selected_item = 1
	g.equip_selected()
	check(g.equipped == "heavy" and "shrine" in g.message, "Cannot equip away from shrines")
	g.player_pos = g.checkpoints[0]
	var foe: Dictionary = g.enemies[20]
	foe.alive = true
	foe.pursuing = true
	g.equip_selected()
	check(g.equipped == "heavy" and "combat" in g.message, "Cannot equip during combat")
	foe.pursuing = false
	foe.alive = false
	# An older activated shrine still counts after a newer one is activated.
	for enemy in g.enemies:
		if enemy.sector == 1: enemy.alive = false
	g.player_pos = g.checkpoints[1]
	g.update_shrines()
	check(g.checkpoint == 1, "Shrine 1 activates")
	g.player_pos = g.checkpoints[0]
	g.equip_selected()
	check(g.equipped == "light", "Earlier activated shrine still allows armor changes")
	# The shrine reward is one-time.
	g.checkpoint = -1
	g.player_pos = g.checkpoints[0]
	g.update_shrines()
	rewards = 0
	for pickup in g.pickups:
		if pickup.get("reward", false): rewards += 1
	check(rewards == 2, "Re-entering a shrine does not grant a second reward")

	# Death keeps the equipped suit, drops every unequipped backup suit.
	g.checkpoint = 1
	g.inventory = ["weapon", "medium", "medium", "heavy", "relic"]
	g.equipped = "medium"
	g.player_pos = Vector2(224, 224)
	var pickups_before: int = g.pickups.size()
	g.respawn()
	check(g.inventory.count("medium") == 1 and not g.inventory.has("heavy"), "Respawn keeps only the equipped suit")
	check(g.inventory.has("weapon") and g.inventory.has("relic"), "Respawn keeps weapon and relics")
	check(g.pickups.size() == pickups_before + 2, "Backup suits are left at the death location")
	check(g.equipped == "medium", "Respawn keeps the equipped armor")

	# Slot costs: light 2, medium 3, heavy 4.
	check(g.item_cost("light") == 2 and g.item_cost("medium") == 3 and g.item_cost("heavy") == 4, "Armor slot costs")

	g.reset_game()
	check(g.equipped == "light" and g.opened_chests.is_empty(), "Restart resets armor state")
	print(JSON.stringify({"armor_checks": checks, "failures": failures}))
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
