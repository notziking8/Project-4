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
	check(g.used_slots() == 5 and g.pickups.size() == 9 and g.heal_cooldown == 0, "Restart restores initial inventory and world pickups")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
