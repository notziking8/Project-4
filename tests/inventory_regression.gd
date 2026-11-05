extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.mode = "playing"
	check(g.used_slots() == 5 and g.inventory.count("relic") == 2, "Initial inventory occupies five slots")
	check(g.item_cost("light") == 2 and g.item_cost("medium") == 3 and g.item_cost("heavy") == 4 and g.item_cost("weapon") == 1 and g.item_cost("relic") == 1, "Weighted costs")
	for sector in range(3):
		var count := 0
		for pickup in g.pickups:
			if pickup.kind == "relic" and pickup.sector == sector:
				count += 1
				check(not g.maze.cells.has(Vector2i((pickup.pos / g.UNIT).floor())), "Relic on walkable floor")
		check(count == 2, "Two relics per sector")
	var original_pickups: Array = g.pickups.duplicate(true)
	for kind in g.ARMOR_KINDS:
		g.inventory = ["weapon", "light"]
		g.pickups = [{"kind":kind, "pos":g.player_pos, "locked":false, "sector":-1}]
		check(g.nearest_pickup() == 0 and "Pick up" in g.pickup_prompt(0), "Each armor has a pickup option: " + kind)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = g.pickup_button_rect().get_center()
		g._gui_input(click)
		check(g.pickups.is_empty() and g.inventory.back() == kind, "Click collects armor: " + kind)
	g.pickups = [
		{"kind":"light", "pos":g.player_pos + Vector2(80, 0), "locked":false, "sector":-1},
		{"kind":"heavy", "pos":g.player_pos + Vector2(20, 0), "locked":false, "sector":-1},
	]
	check(g.nearest_pickup() == 1 and "Heavy" in g.pickup_prompt(1), "Prompt targets nearest item regardless of array order")
	g.inventory = ["weapon", "light"]
	var collect := InputEventKey.new()
	collect.keycode = KEY_E
	collect.pressed = true
	g._unhandled_key_input(collect)
	check(g.inventory.back() == "heavy" and g.pickups.size() == 1, "E collects the prompted armor")
	g.pickups[0].pos = g.player_pos + Vector2(100, 0)
	check(g.nearest_pickup() == -1, "Out of reach items have no pickup target")
	g.pickups = original_pickups
	g.inventory = ["weapon", "light", "relic", "relic"]
	g.inventory.append_array(["medium", "relic", "relic"])
	check(g.used_slots() == 10, "Exact full capacity")
	g.pickups = [{"kind":"heavy", "pos":g.player_pos, "locked":false, "sector":-1}]
	g.pick_up()
	check(g.pickups.size() == 1 and g.used_slots() == 10 and g.equipped == "light", "Oversized pickup remains unchanged")
	g.health = 60
	g.heal()
	check(g.health == 85 and g.used_slots() == 9 and g.heal_cooldown == 5, "Heal consumes one slot and starts cooldown")
	g.heal()
	check(g.health == 85 and g.used_slots() == 9, "Cooldown blocks consumption")
	g.heal_cooldown = 0
	g.heal()
	check(g.health == 100 and g.used_slots() == 8, "Healing capped at 100")
	g.heal_cooldown = 0
	g.heal()
	check(g.used_slots() == 8 and g.heal_cooldown == 0, "Full health does not consume")
	g.health = 0
	g.heal()
	check(g.health == 0 and g.used_slots() == 8, "Dead player cannot heal")
	g.health = 50
	g.inventory = ["weapon", "light"]
	g.heal()
	check(g.health == 50 and g.heal_cooldown == 0, "No relic does not heal")
	g.inventory.append("medium")
	g.selected_item = 2
	g.equip_selected()
	g.drop_selected()
	check(g.equipped == "light" and g.inventory.size() == 3, "Outside checkpoint cannot equip or drop")
	for enemy in g.enemies:
		enemy.alive = false
		enemy.pursuing = false
	g.checkpoint = 1
	g.player_pos = g.checkpoints[0]
	g.inventory_open = true
	var select := InputEventMouseButton.new()
	select.button_index = MOUSE_BUTTON_LEFT
	select.pressed = true
	select.position = g.inventory_item_rect(2).get_center()
	g._gui_input(select)
	check(g.selected_item == 2 and g.equipped == "light", "Selecting backup armor does not equip it")
	select.position = g.inventory_drop_rect().get_center()
	g._gui_input(select)
	check(not g.inventory.has("medium") and g.pickups.back().kind == "medium", "Drop button drops selected backup armor at shrine")
	g.inventory.append("medium")
	g.selected_item = 2
	select.position = g.inventory_equip_rect().get_center()
	g._gui_input(select)
	check(g.equipped == "medium", "Equip button equips selected suit")
	g.drop_selected()
	check(g.inventory.has("medium") and "wearing" in g.message, "Equipped suit protection explains how to drop it")
	g.inventory_open = false
	g.equip_selected()
	check(g.equipped == "medium", "Earlier activated checkpoint permits equip")
	g.inventory.append("medium")
	g.selected_item = 3
	g.drop_selected()
	check(g.inventory.count("medium") == 1, "Duplicate backup may be dropped")
	g.inventory.append_array(["medium", "light", "relic"])
	var death_pos: Vector2 = g.player_pos
	var before: int = g.pickups.size()
	g.heal_cooldown = 4
	g.respawn()
	check(g.inventory == ["weapon", "medium", "relic"] and g.health == 100 and g.heal_cooldown == 0, "Death retains one equipped suit, weapon and relic")
	check(g.pickups.size() == before + 3, "Every backup suit drops once")
	for i in range(before, g.pickups.size()):
		check(g.pickups[i].pos == death_pos, "Armor drops at death location")
	g.player_pos = death_pos
	g.pick_up()
	check(g.inventory.size() == 4 and g.equipped == "medium", "Dropped armor recoverable without auto equip")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	g._unhandled_key_input(key)
	check(g.inventory_open, "Tab opens inventory")
	g._unhandled_key_input(key)
	check(not g.inventory_open, "Tab closes inventory")
	g.reset_game()
	check(g.used_slots() == 5 and g.pickups.size() == 9 + g.ARMOR_REMNANTS[0].size() + g.ARMOR_REMNANTS[1].size() + g.ARMOR_REMNANTS[2].size() and g.heal_cooldown == 0, "Restart restores initial inventory and world pickups")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
