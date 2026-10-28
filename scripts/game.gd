extends Control

const UNIT := 64.0
const INVENTORY_CAPACITY := 10
const WORLD := Vector2(6976, 3520)
const SHIFT_INTERVAL := 6.0
const SECTOR_WIDTH := 2304.0
const SECTOR_NAMES := ["Owl Galleries", "Sunken Halls", "Bull Sanctuary"]
const MAZE_SCRIPT := preload("res://scripts/maze_grid.gd")
const DETAIL_ATLAS := preload("res://assets/art/environment/props/polished_props.png")
const INK := Color("111723")
const STONE := Color("343f51")
const STONE_EDGE := Color("75869b")
const GOLD := Color("e9bf72")
const CYAN := Color("79d7db")
const RED := Color("e37e78")
const PALE := Color("e6e3d5")
const FLOOR_ATLAS := preload("res://assets/art/environment/tiles/floor_variations.png")
const TILE_ATLAS := preload("res://assets/art/environment/tiles/labyrinth_tiles.png")
const PROP_ATLAS := preload("res://assets/art/environment/props/labyrinth_props.png")
const EXPLORER_A_IDLE := preload("res://assets/art/characters/explorer_a/explorer_a_idle.png")
const EXPLORER_A_WALK := preload("res://assets/art/characters/explorer_a/explorer_a_walk.png")
const EXPLORER_A_ATTACK := preload("res://assets/art/characters/explorer_a/explorer_a_attack.png")
const EXPLORER_A_HURT := preload("res://assets/art/characters/explorer_a/explorer_a_hurt.png")
const EXPLORER_B_IDLE := preload("res://assets/art/characters/explorer_b/explorer_b_idle.png")
const EXPLORER_B_WALK := preload("res://assets/art/characters/explorer_b/explorer_b_walk.png")
const EXPLORER_B_ATTACK := preload("res://assets/art/characters/explorer_b/explorer_b_attack.png")
const EXPLORER_B_HURT := preload("res://assets/art/characters/explorer_b/explorer_b_hurt.png")
const SPIRIT_ATLAS := preload("res://assets/art/enemies/spirits/spirit_animation.png")
const MINOTAUR_ATLAS := preload("res://assets/art/enemies/minotaur/minotaur_animation.png")
const OWL_ATLAS := preload("res://assets/art/characters/companion/owl_animation.png")
const ATHENA_ATLAS := preload("res://assets/art/characters/companion/athena_reveal.png")
const ICON_ATLAS := preload("res://assets/art/ui/item_icons.png")

var mode := "menu"
var player_pos := Vector2(224,224)
var owl := Vector2(140, 290)
var camera := Vector2(170, 310)
var health := 100.0
var inventory := ["weapon", "light", "relic", "relic"]
var equipped := "light"
var inventory_open := false
var selected_item := -1
var checkpoint := -1
var checkpoints := [Vector2(2144,1760), Vector2(4448,1760), Vector2(6752,1760)]
var gates := [false, false]
var shrine_rewards := [false, false, false]
var pickups := []
var enemies := []
var walls := []
var shifts := []
var nav := AStarGrid2D.new()
var shift_clock := SHIFT_INTERVAL
var frozen_wall := -1
var freeze_left := 0.0
var freeze_cooldown := 0.0
var shot_cooldown := 0.0
var heal_cooldown := 0.0
var aim := Vector2.RIGHT
var shot_fx := 0.0
var shot_end := Vector2.ZERO
var message := ""
var message_left := 0.0
var ending_time := 0.0
var respawn_flash := 0.0
var path_clock := 0.0
var beat_player: AudioStreamPlayer
var athena_caption := true
var anim_clock := 0.0
var player_facing := 0 # Down, Left, Right, Up.
var player_moving := false
var attack_anim_left := 0.0
var hurt_anim_left := 0.0
var world_modulate: CanvasModulate
var player_light: PointLight2D
var occluder_root: Node2D
var maze: Node2D
var world_canvas: CanvasLayer
var player_phase := 0.0
var shift_flash := 0.0
var motion_shape := CircleShape2D.new()
var arrows: Array = []
var route := PackedVector2Array()
var route_clock := 0.0
var objective_target := Vector2.ZERO
var objective_text := ""
var route_text := ""
var show_route := true
var help_open := false
var map_open := false
var darkness: GradientTexture2D
var shot_origin := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var interface_material := CanvasItemMaterial.new()
	interface_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = interface_material
	world_canvas = CanvasLayer.new()
	world_canvas.name = "WorldCanvas"
	world_canvas.layer = -1
	add_child(world_canvas)
	maze = MAZE_SCRIPT.new()
	maze.name = "LabyrinthGrid"
	world_canvas.add_child(maze)
	reset_game()
	beat_player = AudioStreamPlayer.new()
	var hoofbeat_stream: AudioStreamWAV = load("res://assets/hoofbeats.wav")
	hoofbeat_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	beat_player.stream = hoofbeat_stream
	beat_player.volume_db = -14.0
	add_child(beat_player)
	setup_lighting()

func setup_lighting() -> void:
	world_modulate = CanvasModulate.new()
	world_modulate.color = Color(0.28, 0.32, 0.40, 1.0)
	world_canvas.add_child(world_modulate)
	player_light = PointLight2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.84, 0.59, 1.0))
	gradient.set_color(1, Color(1.0, 0.70, 0.40, 0.0))
	var texture := GradientTexture2D.new()
	texture.width = 768
	texture.height = 768
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.gradient = gradient
	player_light.texture = texture
	player_light.energy = 1.4
	player_light.range_layer_min = -1
	player_light.range_layer_max = -1
	player_light.shadow_enabled = true
	player_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	maze.add_child(player_light)
	for row in range(maze.ROOMS.y):
		for col in range(maze.ROOMS.x):
			if (col + row) % 3 != 0: continue
			var torch := PointLight2D.new()
			torch.name = "Torch_%d_%d" % [col,row]
			torch.texture = texture
			torch.texture_scale = 0.35
			torch.position = Vector2(col*384+96,row*384+66)
			torch.color = Color(1.0,0.74,0.40)
			torch.energy = 0.12
			torch.range_layer_min = -1
			torch.range_layer_max = -1
			torch.shadow_enabled = true
			maze.add_child(torch)
	var shade := Gradient.new()
	shade.set_color(0, Color(0.01,0.02,0.04,0.0))
	shade.add_point(0.28,Color(0.01,0.02,0.04,0.06))
	shade.add_point(0.65,Color(0.01,0.02,0.04,0.45))
	shade.set_color(shade.get_point_count()-1,Color(0.01,0.02,0.04,0.86))
	darkness = GradientTexture2D.new()
	darkness.width = 256
	darkness.height = 256
	darkness.fill = GradientTexture2D.FILL_RADIAL
	darkness.fill_from = Vector2(0.5,0.5)
	darkness.fill_to = Vector2(1.0,0.5)
	darkness.gradient = shade

func rebuild_light_occluders() -> void:
	# Occluders live on the same TileData as wall collision polygons.
	pass

func reset_game() -> void:
	mode = "menu"
	player_pos = Vector2(224,224)
	owl = player_pos + Vector2(-35,-33)
	camera = player_pos
	health = 100.0
	inventory = ["weapon", "light", "relic", "relic"]
	equipped = "light"
	inventory_open = false
	selected_item = -1
	checkpoint = -1
	gates = [false, false]
	shrine_rewards = [false, false, false]
	shift_clock = SHIFT_INTERVAL
	frozen_wall = -1
	freeze_left = 0.0
	freeze_cooldown = 0.0
	shot_cooldown = 0.0
	heal_cooldown = 0.0
	message = "Follow the gold route to the wardens. Press H for a field guide."
	message_left = 7.0
	ending_time = 0.0
	respawn_flash = 0.0
	anim_clock = 0.0
	player_phase = 0.0
	shift_flash = 0.0
	arrows.clear()
	route.clear()
	route_clock = 0.0
	help_open = false
	map_open = false
	player_facing = 0
	player_moving = false
	attack_anim_left = 0.0
	hurt_anim_left = 0.0
	if beat_player != null: beat_player.stop()
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): DisplayServer.tts_stop()
	build_level()
	build_navigation()
	queue_redraw()

func build_level() -> void:
	maze.generate(randi())
	shifts = maze.connections
	walls = maze.blockers
	pickups = []
	enemies = []
	for sector in range(3):
		var offset := sector * SECTOR_WIDTH
		for point in [Vector2(992,992),Vector2(1760,2912)]:
			pickups.append({"kind":"relic","pos":point+Vector2(offset,0),"locked":false,"sector":sector})
		pickups.append({"kind":"heavy" if sector==1 else "medium","pos":Vector2(offset+2070,1850),"locked":true,"sector":sector})
		var rooms := [Vector2i(1,0),Vector2i(2,2),Vector2i(4,1),Vector2i(1,4),Vector2i(3,5),Vector2i(4,7),Vector2i(2,8),Vector2i(5,6)]
		for i in range(rooms.size()):
			var point := Vector2(rooms[i])*384.0+Vector2(224+offset,224)
			spawn_enemy(point,"heavy" if i%4==3 else "light",sector,i%4==3,i%3==0)
	spawn_enemy(checkpoints[2]+Vector2(-90,0),"heavy",2,false,false,true)

func spawn_enemy(pos: Vector2, kind: String, sector: int, elite: bool, electrical: bool, boss: bool = false) -> void:
	enemies.append({"pos": pos, "home": pos, "kind": kind, "sector": sector, "hp": 50.0 if kind == "light" else 100.0, "alive": true, "pursuing": false, "attack_timer": 0.0, "elite": elite, "electrical": electrical, "boss": boss, "path": PackedVector2Array(), "path_time": 0.0, "path_index":0, "state":"idle", "memory":0.0, "last_seen":pos, "state_time":randf_range(1.0,3.0), "patrol_target":pos, "phase":randf()*TAU, "windup":0.0})

func blocking_rects() -> Array:
	return maze.blockers

func build_navigation() -> void:
	maze.rebuild(gates)
	walls = maze.blockers
	# AStarGrid2D.update() does not clear solids when its dimensions are unchanged.
	nav = AStarGrid2D.new()
	nav.region = Rect2i(Vector2i.ZERO, maze.GRID)
	nav.cell_size = Vector2(UNIT, UNIT)
	nav.offset = Vector2(32,32)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for cell in maze.cells: nav.set_point_solid(cell)
	route_clock = 0.0
	for enemy in enemies:
		enemy.path_time = 0.0
		enemy.path = PackedVector2Array()
		enemy.path_index = 0

func _process(delta: float) -> void:
	if mode in ["playing", "reveal"]: anim_clock += delta
	shift_flash = maxf(0.0, shift_flash - delta)
	attack_anim_left = maxf(0.0, attack_anim_left - delta)
	hurt_anim_left = maxf(0.0, hurt_anim_left - delta)
	if mode == "reveal":
		ending_time -= delta
		if ending_time <= 0.0 and (athena_caption or not DisplayServer.tts_is_speaking()): mode = "victory"
	update_ambience()
	if message_left > 0.0: message_left -= delta
	if respawn_flash > 0.0: respawn_flash -= delta
	if shot_fx > 0.0: shot_fx -= delta
	var target: Vector2 = player_pos
	camera = camera.lerp(target, minf(1.0, delta * 5.0))
	camera.x = clampf(camera.x, size.x * 0.5, WORLD.x - size.x * 0.5)
	camera.y = clampf(camera.y, size.y * 0.5, WORLD.y - size.y * 0.5)
	if player_light != null:
		player_light.position = player_pos
		player_light.visible = mode in ["playing", "reveal"]
	if world_modulate != null:
		world_modulate.visible = mode in ["playing", "reveal"]
	world_canvas.transform = Transform2D(0.0, (size * 0.5 - camera).round())
	world_canvas.visible = mode not in ["menu", "controls"]
	queue_redraw()

func _physics_process(delta: float) -> void:
	if mode == "playing" and not help_open and not map_open: update_game(delta)

func update_ambience() -> void:
	if beat_player == null: return
	var boss_alive := false
	for enemy in enemies:
		if enemy["boss"] and enemy["alive"]: boss_alive = true
	var should_play: bool = mode == "playing" and player_pos.distance_to(checkpoints[2]) < 1100.0 and boss_alive
	if should_play and not beat_player.playing: beat_player.play()
	elif not should_play and beat_player.playing: beat_player.stop()

func update_game(delta: float) -> void:
	update_boss_unlock()
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if freeze_left > 0.0:
		freeze_left -= delta
		if freeze_left <= 0.0:
			freeze_left = 0.0
			frozen_wall = -1
			freeze_cooldown = 5.0
	else:
		freeze_cooldown = maxf(0.0, freeze_cooldown - delta)
	shift_clock -= delta
	if shift_clock <= 0.0:
		shift_clock += SHIFT_INTERVAL
		shift_walls()
	var motion := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	motion.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	motion.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	if motion.length_squared() > 1.0: motion = motion.normalized()
	var speed := 4.0 * UNIT
	if equipped == "light": speed *= 1.1
	elif equipped == "heavy": speed *= 0.85
	var old_pos: Vector2 = player_pos
	player_pos = move_body(old_pos, motion * speed * delta, 16.0)
	update_player_pose(player_pos-old_pos)
	var owl_target := player_pos + Vector2(-35,-45)
	owl = owl.lerp(owl_target,minf(1.0,delta*3.0))
	var hand := player_pos + Vector2(0,-23)
	var mouse := screen_to_world(get_local_mouse_position())
	if hand.distance_to(mouse) > 10.0: aim = (mouse-hand).normalized()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not inventory_open: shoot()
	update_arrows(delta)
	route_clock -= delta
	if route_clock <= 0.0:
		route_clock = 0.7
		update_guidance()
	update_enemies(delta)
	update_shrines()

func move_body(pos: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Swept circle queries use the TileMap's real physics polygons, not visual bounds.
	motion_shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = motion_shape
	query.collision_mask = 1
	query.margin = 0.08
	var space := get_world_2d().direct_space_state
	for motion in [Vector2(displacement.x,0),Vector2(0,displacement.y)]:
		if motion.length_squared() < 0.000001: continue
		query.transform = Transform2D(0.0, pos)
		query.motion = motion
		var fractions := space.cast_motion(query)
		pos += motion * fractions[0]
	return pos

func update_player_pose(displacement: Vector2) -> void:
	player_moving = displacement.length_squared() > 0.002
	if not player_moving:
		player_phase = 0.0
		return
	player_phase += displacement.length()/28.0
	if attack_anim_left > 0.0: return
	if absf(displacement.x)>absf(displacement.y): player_facing = 2 if displacement.x>0.0 else 1
	else: player_facing = 0 if displacement.y>0.0 else 3

func body_collides(pos: Vector2, radius: float, blockers: Array) -> bool:
	for r in blockers:
		var nearest := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		if pos.distance_squared_to(nearest) < radius * radius: return true
	return false

func has_line_of_sight(a: Vector2, b: Vector2, ignored: Rect2 = Rect2()) -> bool:
	# Sample cell occupancy in O(ray length), independent of total maze size.
	var count := maxi(1,ceili(a.distance_to(b)/12.0))
	for i in range(1,count):
		var point := a.lerp(b,float(i)/count)
		if ignored.has_area() and ignored.has_point(point): continue
		if maze.cells.has(Vector2i((point/UNIT).floor())): return false
	return true

func update_enemies(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive: continue
		if enemy.boss and maze.boss_sealed:
			enemy.state = "sealed"
			enemy.pursuing = false
			continue
		var pos: Vector2 = enemy.pos
		var distance := pos.distance_to(player_pos)
		var sees := distance < 8.0*UNIT and has_line_of_sight(pos,player_pos)
		enemy.attack_timer = maxf(0.0,enemy.attack_timer-delta)
		enemy.state_time -= delta
		if enemy.state == "attack":
			enemy.windup -= delta
			if enemy.windup <= 0.0:
				if distance < 110.0 and has_line_of_sight(pos,player_pos): take_damage(20.0 if enemy.kind=="heavy" else 10.0,enemy.electrical,pos)
				enemy.attack_timer = 2.2 if enemy.kind=="heavy" else 1.1
				enemy.state = "chase"
			continue
		# Once freed, the Minotaur tracks the player through the entire maze,
		# including behind walls and across shifts. Spirits still use sight/memory.
		if enemy.boss or sees:
			enemy.last_seen = player_pos
			enemy.memory = 7.0
			enemy.state = "chase"
		elif enemy.state == "chase":
			enemy.memory -= delta
			if enemy.memory <= 0.0 or pos.distance_to(enemy.last_seen)<28.0:
				enemy.state = "search"
				enemy.state_time = 2.0
		elif enemy.state == "search" and enemy.state_time <= 0.0:
			enemy.state = "return"
			enemy.path_time = 0.0
		enemy.pursuing = enemy.state in ["chase","search","attack"]
		if sees and distance < 90.0 and enemy.attack_timer <= 0.0:
			enemy.state = "attack"
			enemy.windup = 0.8 if enemy.kind=="heavy" else 0.55
			continue
		var target: Vector2 = enemy.home
		match enemy.state:
			"chase": target = enemy.last_seen
			"search": continue
			"return":
				if pos.distance_to(enemy.home)<20.0:
					enemy.state = "idle"
					enemy.state_time = 2.0
			"idle":
				if enemy.state_time > 0.0: continue
				enemy.patrol_target = enemy.home+Vector2(72,0).rotated(randf()*TAU)
				enemy.state = "patrol"
				enemy.path_time = 0.0
			"patrol":
				target = enemy.patrol_target
				if pos.distance_to(target)<18.0:
					enemy.state = "idle"
					enemy.state_time = randf_range(1.0,3.0)
					continue
		if sees and distance < 70.0: continue
		var direction := path_direction(enemy,target,delta)
		var speed := 135.0 if enemy.kind=="heavy" else 185.0
		if enemy.state in ["patrol","return"]: speed *= 0.55
		enemy.pos = move_body(pos,direction*speed*delta,23.0 if enemy.boss else 17.0)

func path_direction(enemy: Dictionary, target: Vector2, delta: float) -> Vector2:
	enemy.path_time -= delta
	if enemy.path_time <= 0.0:
		enemy.path_time = 0.45
		var start := closest_nav_cell(enemy.pos)
		var finish := closest_nav_cell(target)
		enemy.path = nav.get_point_path(start,finish)
		# Do not walk back to the start-cell centre at every refresh.
		enemy.path_index = 1 if enemy.path.size()>1 else 0
	var path: PackedVector2Array = enemy.path
	if path.is_empty(): return Vector2.ZERO
	while enemy.path_index < path.size() and enemy.pos.distance_to(path[enemy.path_index]) < 12.0:
		enemy.path_index += 1
	if enemy.path_index < path.size(): return (path[enemy.path_index]-enemy.pos).normalized()
	if has_line_of_sight(enemy.pos,target): return (target-enemy.pos).normalized()
	return Vector2.ZERO

func closest_nav_cell(pos: Vector2) -> Vector2i:
	var cell := Vector2i(clampi(int(pos.x / UNIT), 1, maze.GRID.x-2), clampi(int(pos.y / UNIT), 1, maze.GRID.y-2))
	if not nav.is_point_solid(cell): return cell
	for radius in range(1, 4):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if nav.is_in_boundsv(candidate) and not nav.is_point_solid(candidate): return candidate
	return cell

func take_damage(base: float, electrical: bool, attacker: Vector2) -> void:
	hurt_anim_left = 0.20
	var reduction := 0.15 if equipped == "light" else (0.35 if equipped == "medium" else 0.60)
	var amount := base * (1.0 - reduction)
	if electrical and equipped == "medium": amount *= 0.75
	health -= amount
	if equipped != "heavy":
		var push: Vector2 = (player_pos - attacker).normalized() * (0.5 * UNIT)
		player_pos = move_body(player_pos, push, 19.0)
	if health <= 0.0: respawn()

func respawn() -> void:
	var death_pos: Vector2 = player_pos
	# Identical suits are interchangeable; retain exactly one equipped suit.
	var equipped_index := inventory.find(equipped)
	for i in range(inventory.size() - 1, -1, -1):
		var item: String = inventory[i]
		if item in ["light", "medium", "heavy"] and i != equipped_index:
			pickups.append({"kind": item, "pos": death_pos, "locked": false, "sector": -1})
			inventory.remove_at(i)
	selected_item = -1
	health = 100.0
	heal_cooldown = 0.0
	shot_cooldown = 0.0
	var respawn_point: Vector2 = checkpoints[checkpoint] if checkpoint >= 0 else Vector2(224,224)
	player_pos = safe_respawn(respawn_point)
	for enemy in enemies:
		enemy["pursuing"] = false
		enemy.state = "return"
		enemy.path_time = 0.0
	arrows.clear()
	respawn_flash = 2.0

func safe_respawn(point: Vector2) -> Vector2:
	var blockers := blocking_rects()
	if not body_collides(point, 20.0, blockers): return point
	for radius in range(1, 7):
		for angle in range(8):
			var candidate := point + Vector2.RIGHT.rotated(float(angle) * TAU / 8.0) * radius * 32.0
			if not body_collides(candidate, 20.0, blockers): return candidate
	return point

func sector_clear(sector: int) -> bool:
	for enemy in enemies:
		if enemy["sector"] == sector and enemy["alive"]: return false
	return true

func spirits_remaining() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.alive and not enemy.boss: count += 1
	return count

func get_minotaur() -> Dictionary:
	for enemy in enemies:
		if enemy.boss: return enemy
	return {}

func update_boss_unlock() -> void:
	if not maze.boss_sealed or spirits_remaining() > 0: return
	maze.release_boss()
	build_navigation()
	var boss := get_minotaur()
	if not boss.is_empty() and boss.alive:
		boss.state = "chase"
		boss.pursuing = true
		boss.last_seen = player_pos
		boss.path_time = 0.0
		show_message("All spirits have fallen. The Minotaur's chamber opens. It is hunting you — follow the horn marker on the map!")
	update_guidance()

func combat_active() -> bool:
	for enemy in enemies:
		if enemy["alive"] and enemy["pursuing"]: return true
	return false

func update_shrines() -> void:
	for i in range(3):
		if checkpoint >= i: continue
		if not sector_clear(i): continue
		if i > 0 and checkpoint < i - 1: continue
		if combat_active(): continue
		if player_pos.distance_to(checkpoints[i]) <= 55.0:
			checkpoint = i
			if i < 2:
				gates[i] = true
				build_navigation()
			if not shrine_rewards[i]:
				shrine_rewards[i] = true
				pickups.append({"kind": ["medium", "heavy", "heavy"][i], "pos": checkpoints[i] + Vector2(75, 35), "locked": false, "sector": -1})
			if i == 2:
				mode = "reveal"
				ending_time = 7.0
				speak_athena()
			else:
				show_message("A shrine glows; the onward passage opens.")

func speak_athena() -> void:
	athena_caption = true
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return
	var voices := DisplayServer.tts_get_voices()
	if voices.is_empty(): return
	var voice: String = voices[0]["id"]
	for candidate in voices:
		if "Zira" in candidate["name"]:
			voice = candidate["id"]
			break
	DisplayServer.tts_speak("I am Athena. I sent you here to end the Minotaur's reign. You broke the labyrinth's curse. Now I will bring you home.", voice, 72, 1.0, 0.92)
	athena_caption = false

func shift_walls() -> void:
	var occupied: Array = []
	occupied.append({"pos":player_pos,"radius":20.0})
	for enemy in enemies:
		if enemy.alive: occupied.append({"pos":enemy.pos,"radius":25.0})
	for pickup in pickups: occupied.append({"pos":pickup.pos,"radius":25.0})
	if maze.shift(occupied, frozen_wall, gates) > 0:
		build_navigation()
		shift_flash = 1.0
		update_guidance()

func use_flashlight(mouse: Vector2 = Vector2.INF) -> void:
	if frozen_wall >= 0 or freeze_cooldown > 0.0:
		show_message("Passage lock is active or recharging.")
		return
	var player: Vector2 = player_pos
	if not mouse.is_finite(): mouse = screen_to_world(get_local_mouse_position())
	var nearest := -1
	var nearest_distance := 3.048 * UNIT
	for i in range(shifts.size()):
		var shift: Dictionary = shifts[i]
		if shift.gate >= 0 and not gates[shift.gate]: continue
		if shift.boss_gate and maze.boss_sealed: continue
		var r: Rect2 = shift.rect
		var point := r.get_center()
		var distance := player.distance_to(point)
		if distance < nearest_distance and r.grow(28.0).has_point(mouse) and has_line_of_sight(player, point, r):
			nearest = i
			nearest_distance = distance
	if nearest >= 0:
		frozen_wall = nearest
		freeze_left = 10.0
		show_message("Passage locked %s for 10 seconds." % ("OPEN" if shifts[nearest].open else "CLOSED"))
	else:
		show_message("Aim at a nearby socket or passage, then press F. Sealed gates cannot be frozen.")

func bow_muzzle(direction: Vector2) -> Vector2:
	return player_pos+Vector2(0,-23)+direction*23.0

func shoot(target: Vector2 = Vector2.INF) -> void:
	if shot_cooldown > 0.0 or help_open or map_open: return
	var hand := player_pos+Vector2(0,-23)
	if not target.is_finite(): target = screen_to_world(get_local_mouse_position())
	var direction := (target-hand).normalized()
	if target.distance_to(hand)<10.0: direction = aim
	aim = direction
	shot_cooldown = 0.5
	attack_anim_left = 0.25
	player_facing = (2 if direction.x>0 else 1) if absf(direction.x)>absf(direction.y) else (0 if direction.y>0 else 3)
	shot_origin = bow_muzzle(direction)
	var obstruction := wall_hit(hand,shot_origin)
	if not obstruction.is_empty():
		shot_end = obstruction.position
		shot_fx = 0.12
		return
	arrows.append({"pos":shot_origin,"direction":direction,"remaining":640.0})
	for enemy in enemies:
		if enemy.alive and not (enemy.boss and maze.boss_sealed) and enemy.pos.distance_to(player_pos)<320.0:
			enemy.last_seen = player_pos
			enemy.memory = 7.0
			enemy.state = "chase"
			enemy.pursuing = true

func wall_hit(a: Vector2, b: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(a,b,1)
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query)

func update_arrows(delta: float) -> void:
	for i in range(arrows.size()-1,-1,-1):
		var arrow: Dictionary = arrows[i]
		var start: Vector2 = arrow.pos
		var travel: float = minf(900.0*delta,arrow.remaining)
		var end: Vector2 = start+arrow.direction*travel
		var wall := wall_hit(start,end)
		var nearest: float = start.distance_to(wall.position) if not wall.is_empty() else travel+1.0
		var victim: Dictionary = {}
		for enemy in enemies:
			if not enemy.alive: continue
			if enemy.boss and maze.boss_sealed: continue
			var center: Vector2 = enemy.pos+Vector2(0,-48 if enemy.boss else -28)
			var radius := 35.0 if enemy.boss else 22.0
			var offset: Vector2 = start-center
			var projection: float = offset.dot(arrow.direction)
			var discriminant: float = projection*projection-offset.length_squared()+radius*radius
			if discriminant < 0.0: continue
			var hit_distance := maxf(0.0,-projection-sqrt(discriminant))
			if projection > 0.0 and offset.length_squared()>radius*radius: continue
			if hit_distance <= travel and hit_distance < nearest:
				nearest = hit_distance
				victim = enemy
		if nearest <= travel:
			shot_end = start+arrow.direction*nearest
			shot_fx = 0.12
			if not victim.is_empty():
				victim.hp -= 25.0
				victim.last_seen = player_pos
				victim.memory = 7.0
				victim.state = "chase"
				if victim.hp<=0.0: defeat_enemy(victim)
			arrows.remove_at(i)
			continue
		arrow.pos = end
		arrow.remaining -= travel
		if arrow.remaining<=0.0: arrows.remove_at(i)

func defeat_enemy(enemy: Dictionary) -> void:
	if enemy.boss and maze.boss_sealed: return
	route_clock = 0.0
	enemy["alive"] = false
	enemy["pursuing"] = false
	var drop := "heavy" if enemy["elite"] else ("medium" if enemy["boss"] else "weapon")
	pickups.append({"kind": drop, "pos": enemy["pos"], "locked": false, "sector": -1})
	if enemy["boss"]: show_message("The bull court falls silent.")
	else: update_boss_unlock()

func item_cost(kind: String) -> int:
	if kind == "light": return 2
	if kind == "medium": return 3
	if kind == "heavy": return 4
	return 1

func used_slots() -> int:
	var result := 0
	for item in inventory: result += item_cost(item)
	return result

func pick_up() -> void:
	if mode != "playing" or health <= 0.0: return
	var player: Vector2 = player_pos
	var best := -1
	var best_distance := 92.0
	for i in range(pickups.size()):
		var pickup: Dictionary = pickups[i]
		if pickup["locked"] and not sector_clear(pickup["sector"]): continue
		var distance := player.distance_to(pickup["pos"])
		if distance < best_distance:
			best = i
			best_distance = distance
	if best < 0: return
	var kind: String = pickups[best]["kind"]
	if used_slots() + item_cost(kind) > INVENTORY_CAPACITY:
		show_message("The satchel is full.")
		return
	inventory.append(kind)
	pickups.remove_at(best)

func heal() -> void:
	if mode != "playing" or health <= 0.0 or health >= 100.0 or heal_cooldown > 0.0: return
	var index := inventory.find("relic")
	if index < 0: return
	inventory.remove_at(index)
	selected_item = -1
	health = minf(100.0, health + 25.0)
	heal_cooldown = 5.0

func at_active_shrine() -> bool:
	if mode != "playing" or health <= 0.0 or checkpoint < 0 or combat_active(): return false
	for i in range(checkpoint + 1):
		if player_pos.distance_to(checkpoints[i]) <= 105.0: return true
	return false

func equip_selected() -> void:
	if not at_active_shrine() or selected_item < 0 or selected_item >= inventory.size(): return
	var kind: String = inventory[selected_item]
	if kind in ["light", "medium", "heavy"]: equipped = kind

func drop_selected() -> void:
	if not at_active_shrine() or selected_item < 0 or selected_item >= inventory.size(): return
	var kind: String = inventory[selected_item]
	if selected_item == inventory.find(equipped) or (kind == "weapon" and inventory.count("weapon") <= 1): return
	pickups.append({"kind": kind, "pos": player_pos, "locked": false, "sector": -1})
	inventory.remove_at(selected_item)
	selected_item = -1

func show_message(text: String) -> void:
	message = text
	message_left = 4.0

func screen_to_world(point: Vector2) -> Vector2:
	return point - (size * 0.5 - camera).round()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if help_open: help_open = false
		elif map_open: map_open = false
		elif mode == "playing": mode = "paused"
		elif mode == "paused": mode = "playing"
		elif mode == "controls": mode = "menu"
		elif mode == "victory": reset_game()
		return
	if mode != "playing":
		if mode == "menu" and event.keycode == KEY_ENTER: mode = "playing"
		return
	match event.keycode:
		KEY_H:
			help_open = not help_open
		KEY_M:
			map_open = not map_open
		KEY_G:
			show_route = not show_route
		KEY_E:
			pick_up()
		KEY_F:
			use_flashlight()
		KEY_R:
			heal()
		KEY_TAB:
			inventory_open = not inventory_open
			get_viewport().set_input_as_handled()
		KEY_X:
			if inventory_open and not help_open and not map_open: drop_selected()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var p: Vector2 = event.position
	if mode == "menu":
		if Rect2(size.x * 0.5 - 135, size.y * 0.5 + 62, 270, 48).has_point(p): mode = "playing"
		elif Rect2(size.x * 0.5 - 135, size.y * 0.5 + 122, 270, 48).has_point(p): mode = "controls"
		elif Rect2(size.x * 0.5 - 135, size.y * 0.5 + 182, 270, 48).has_point(p): get_tree().quit()
	elif mode == "controls": mode = "menu"
	elif mode == "paused":
		if Rect2(size.x * 0.5 - 130, size.y * 0.5 + 20, 260, 45).has_point(p): mode = "playing"
		elif Rect2(size.x * 0.5 - 130, size.y * 0.5 + 75, 260, 45).has_point(p): reset_game()
	elif mode == "victory": reset_game()
	elif mode == "playing":
		if help_open or map_open: return
		if inventory_open and Rect2(size.x - 330, 98, 300, 460).has_point(p):
			for index in range(inventory.size()):
				if inventory_item_rect(index).has_point(p):
					selected_item = index
					equip_selected()
					break
		elif not inventory_open: shoot()

func _draw() -> void:
	var screen := size
	if mode in ["menu", "controls"]:
		draw_rect(Rect2(Vector2.ZERO, screen), INK)
		draw_menu()
		return
	draw_set_transform((screen * 0.5 - camera).round())
	draw_world()
	draw_set_transform(Vector2.ZERO)
	draw_darkness()
	draw_hud()
	if help_open: draw_help()
	if map_open: draw_full_map()
	if mode == "paused": draw_pause()
	elif mode == "reveal": draw_reveal()
	elif mode == "victory": draw_victory()
	if respawn_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.65, 0.16, 0.14, minf(0.5, respawn_flash * 0.2)))
		label("Lost, but not forgotten.", screen * 0.5 + Vector2(-150, 100), 25, PALE)

func draw_world() -> void:
	# TileMap layers retain the approved wall artwork.
	var visible := Rect2(camera-size*0.5,size).grow(100)
	if show_route:
		for point in route:
			if point.distance_to(player_pos)<360 and visible.has_point(point): draw_circle(point,2.5,Color(0.95,0.76,0.36,0.65))
	for row in range(maze.ROOMS.y):
		for col in range(maze.ROOMS.x):
			var origin := Vector2(col * 384, row * 384)
			if not visible.intersects(Rect2(origin,Vector2(384,384))): continue
			draw_detail(7 if (col+row)%3==0 else 6, origin + Vector2(96,64), 1.0)
			if (row+col)%2 == 0: draw_detail((col+row)%6, origin + Vector2(325,318), 0.75)
	for i in range(shifts.size()):
		var edge: Dictionary = shifts[i]
		var rect: Rect2 = edge.rect
		if not visible.intersects(rect): continue
		var center: Vector2 = rect.get_center()
		var tint := CYAN if i == frozen_wall else Color("8c987c")
		var eligible: bool = (edge.gate < 0 or gates[edge.gate]) and not (edge.boss_gate and maze.boss_sealed)
		if not eligible: tint = GOLD.darkened(0.5)
		if eligible and shift_clock < 2.0 and i != frozen_wall: tint = GOLD * (0.70 + 0.30 * sin(anim_clock * 12.0))
		var vertical: bool = rect.size.y > rect.size.x
		var ends := [Vector2(center.x, rect.position.y-8), Vector2(center.x, rect.end.y+8)] if vertical else [Vector2(rect.position.x-8,center.y),Vector2(rect.end.x+8,center.y)]
		for socket in ends:
			draw_rect(Rect2(socket-Vector2(6,6),Vector2(12,12)),Color("222f30"))
			draw_rect(Rect2(socket-Vector2(3,3),Vector2(6,6)),tint)
		if i == frozen_wall:
			draw_rect(rect.grow(-6),Color(0.4,0.85,0.95,0.12))
			draw_rect(rect.grow(-5),CYAN,false,2)
		if shift_flash > 0.0 and maze.last_changed.has(i):
			for n in range(9):
				var dust := center + Vector2(sin(i*3+n*8)*60,cos(n*4+i)*65)*(1.5-shift_flash)
				draw_rect(Rect2(dust,Vector2(3,3)),Color(0.8,0.7,0.48,shift_flash*0.6))
	for edge in shifts:
		if ((edge.gate >= 0 and not gates[edge.gate]) or (edge.boss_gate and maze.boss_sealed)) and visible.intersects(edge.rect):
			var rect: Rect2 = edge.rect
			for y in range(int(rect.position.y)+10,int(rect.end.y)-5,24):
				draw_line(Vector2(rect.get_center().x-17,y),Vector2(rect.get_center().x+17,y),GOLD.darkened(0.3),3)
	for i in range(3): draw_shrine(i)
	for pickup in pickups:
		if pickup["locked"] and not sector_clear(pickup["sector"]):
			draw_texture_rect_region(ICON_ATLAS,Rect2(pickup["pos"]-Vector2(24,32),Vector2(48,48)),Rect2(7*32,0,32,32))
		else:
			draw_icon(pickup["kind"], pickup["pos"], 1.0)
	for enemy in enemies:
		if enemy["alive"] and visible.has_point(enemy.pos): draw_enemy(enemy)
	draw_player()
	if mode != "victory": draw_owl()
	if mode == "reveal": draw_athena(checkpoints[2] + Vector2(75, -70))
	if shot_fx > 0.0:
		draw_circle(shot_end, 5.0, CYAN)
	for arrow in arrows:
		var tip: Vector2 = arrow.pos
		var direction: Vector2 = arrow.direction
		draw_line((tip-direction*20).round(),tip.round(),GOLD,2)
		draw_line(tip-direction*6+direction.orthogonal()*3,tip,PALE,2)
		draw_line(tip-direction*6-direction.orthogonal()*3,tip,PALE,2)
	if mode == "playing":
		var target := screen_to_world(get_local_mouse_position())
		draw_arc(target, 13, 0, TAU, 24, CYAN, 2)
		draw_line(target + Vector2(-19, 0), target + Vector2(-9, 0), CYAN, 2)
		draw_line(target + Vector2(9, 0), target + Vector2(19, 0), CYAN, 2)

func draw_detail(index: int, pos: Vector2, scale_factor: float) -> void:
	var extent := Vector2.ONE * 64.0 * scale_factor
	draw_texture_rect_region(DETAIL_ATLAS,Rect2((pos-Vector2(extent.x*0.5,extent.y-10)).round(),extent),Rect2(index*64,0,64,64))

func draw_minimap() -> void:
	var origin := Vector2(size.x-244,18)
	var map_scale := 2.0
	draw_rect(Rect2(origin-Vector2(10,10),Vector2(240,132)),Color(0.025,0.04,0.06,0.95))
	for cell in maze.cells: draw_rect(Rect2(origin+Vector2(cell)*map_scale,Vector2.ONE*map_scale),Color("686858"))
	if show_route and route.size()>1:
		var points := PackedVector2Array()
		for point in route: points.append(origin+point/UNIT*map_scale)
		draw_polyline(points,Color(0.7,0.57,0.24),1)
	for i in range(3): draw_circle(origin+checkpoints[i]/UNIT*map_scale,2,CYAN if checkpoint>=i else GOLD)
	var boss := get_minotaur()
	if maze.boss_sealed or boss.is_empty() or not boss.alive:
		draw_circle(origin+objective_target/UNIT*map_scale,3,RED)
	draw_circle(origin+player_pos/UNIT*map_scale,3,CYAN)
	draw_boss_marker(origin,map_scale,4.0)

func draw_boss_marker(origin: Vector2, map_scale: float, radius: float) -> void:
	var boss := get_minotaur()
	if boss.is_empty() or not boss.alive: return
	var pos: Vector2 = origin + boss.pos / UNIT * map_scale
	var tint := Color("969da7") if maze.boss_sealed else Color("f071b5")
	draw_circle(pos,radius+2,Color("0b111a"))
	draw_circle(pos,radius*0.65,tint)
	for side in [-1.0,1.0]:
		draw_polyline(PackedVector2Array([pos+Vector2(side*radius*0.35,-radius*0.2),pos+Vector2(side*radius,-radius*0.7),pos+Vector2(side*radius,-radius*1.5)]),tint,2.0)
	if maze.boss_sealed: draw_line(pos+Vector2(-radius,radius),pos+Vector2(radius,radius),tint,2.0)

func draw_shrine(index: int) -> void:
	var pos: Vector2 = checkpoints[index]
	var ready := sector_clear(index) and (index == 0 or checkpoint >= index - 1)
	var activated := checkpoint >= index
	var color := CYAN if activated else (GOLD if ready else Color("626b62"))
	draw_circle(pos,42,Color(0.02,0.06,0.06,0.5))
	draw_arc(pos,42,0,TAU,32,color,2)
	draw_detail(10 if activated else 11,pos+Vector2(0,-10),1.2)

func draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var boss: bool = enemy["boss"]
	var heavy: bool = enemy["kind"] == "heavy"
	var frame := int(anim_clock * (5.0 if boss else 7.0))
	draw_circle(pos, 24 if boss else 13, Color(0,0,0,0.25))
	if boss:
		frame = posmod(frame, 6)
		draw_texture_rect_region(MINOTAUR_ATLAS, Rect2(pos.round() - Vector2(64, 122), Vector2(128, 128)), Rect2(frame * 128, 0, 128, 128))
	else:
		frame = 0
		pos.y += sin(anim_clock*2.4+enemy.phase)*1.5
		var enemy_size := 78.0 if heavy else 64.0
		draw_texture_rect_region(SPIRIT_ATLAS, Rect2((pos - Vector2(enemy_size * 0.5, enemy_size * 61.0 / 64.0)).round(), Vector2(enemy_size, enemy_size)), Rect2(frame * 64, 0, 64, 64))
	if enemy.state == "attack":
		draw_arc(enemy.pos,30,0,TAU,24,RED,3)
	if enemy["hp"] < (50.0 if not heavy else 100.0) or boss:
		var radius := 112.0 if boss else 62.0
		draw_rect(Rect2(pos.x - 27, pos.y - radius - 16, 54, 5), INK)
		draw_rect(Rect2(pos.x - 27, pos.y - radius - 16, 54 * enemy["hp"] / (50.0 if not heavy else 100.0), 5), RED)

func draw_player() -> void:
	var pos := player_pos.round()
	var texture: Texture2D = EXPLORER_A_WALK if player_moving else EXPLORER_A_IDLE
	var frame := posmod(int(player_phase),6) if player_moving else 0
	var source := Rect2(frame*64,player_facing*64,64,64)
	draw_set_transform((size*0.5-camera).round()+pos,0,Vector2(1,0.35))
	draw_circle(Vector2.ZERO,18,Color(0,0,0,0.38))
	draw_set_transform((size*0.5-camera).round())
	var tint := Color(1.0,0.65,0.6) if hurt_anim_left>0.0 else Color.WHITE
	draw_texture_rect_region(texture,Rect2(pos-Vector2(32,60),Vector2(64,64)),source,tint)
	draw_arc(pos,21,0.15,PI-0.15,24,CYAN,1.5)
	draw_bow(player_pos,aim,clampf(1.0-attack_anim_left/0.25,0,1))

func draw_bow(pos: Vector2, direction: Vector2, phase: float) -> void:
	# The weapon is posed around a stable hand pivot, independently of the feet.
	var pivot := pos + Vector2(0,-23) + direction * 14.0
	var side := direction.orthogonal()
	var pull := (1.0-phase)*5.0
	var points := PackedVector2Array([pivot+side*14,pivot+direction*6+side*8,pivot+direction*9,pivot+direction*6-side*8,pivot-side*14])
	draw_polyline(points,GOLD.darkened(0.15),3)
	draw_line(points[0],pivot-direction*pull,PALE,1)
	draw_line(pivot-direction*pull,points[4],PALE,1)
	if shot_cooldown <= 0.0: draw_line(pivot-direction*10,pivot+direction*9,PALE,2)

func draw_owl() -> void:
	var frame := posmod(int(anim_clock * 7.0), 10)
	draw_texture_rect_region(OWL_ATLAS, Rect2(owl - Vector2(24, 37), Vector2(48, 48)), Rect2(frame * 64, 0, 64, 64))

func draw_athena(pos: Vector2) -> void:
	var frame := clampi(int((7.0 - ending_time) * 1.7), 0, 11)
	var pulse := 72.0 + sin(anim_clock * 4.0) * 8.0
	draw_circle(pos, pulse, Color(1.0, 0.78, 0.35, 0.12))
	for i in range(12):
		var angle := float(i) * TAU / 12.0 + anim_clock * 0.35
		var feather := pos + Vector2.from_angle(angle) * (56.0 + sin(anim_clock * 2.0 + i) * 16.0)
		draw_circle(feather, 3.0, Color(1.0, 0.86, 0.52, 0.72))
	draw_texture_rect_region(ATHENA_ATLAS, Rect2(pos.round() - Vector2(64, 123), Vector2(128, 128)), Rect2(frame * 128, 0, 128, 128))

func footprint(pos: Vector2, color: Color, scale_factor: float) -> void:
	draw_circle(pos + Vector2(-9, -5) * scale_factor, 8 * scale_factor, color)
	draw_circle(pos + Vector2(10, 6) * scale_factor, 8 * scale_factor, color)

func draw_icon(kind: String, pos: Vector2, scale_factor: float) -> void:
	var icon_index: int = int({"light":0, "medium":1, "heavy":2, "weapon":5, "relic":6}.get(kind, 7))
	var icon_size := 38.0 * scale_factor
	draw_circle(pos, icon_size * 0.58, Color(0.03, 0.08, 0.12, 0.86))
	draw_texture_rect_region(ICON_ATLAS, Rect2(pos - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), Rect2(icon_index * 32, 0, 32, 32))

func label(value: String, pos: Vector2, font_size: int = 20, color: Color = PALE) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func update_guidance() -> void:
	var sector := clampi(checkpoint+1,0,2)
	var remaining := 0
	var closest := INF
	objective_target = checkpoints[sector]
	for enemy in enemies:
		if enemy.alive and not enemy.boss and enemy.sector == sector:
			remaining += 1
			var distance: float = player_pos.distance_squared_to(enemy.pos)
			if distance < closest:
				closest = distance
				objective_target = enemy.pos
	if remaining > 0:
		objective_text = "%s: defeat %d remaining warden%s." % [SECTOR_NAMES[sector],remaining,"" if remaining==1 else "s"]
	else:
		objective_text = "%s cleared. Stand on the gold shrine to %s." % [SECTOR_NAMES[sector],"open the next sector" if sector<2 else "summon Athena"]
	var boss := get_minotaur()
	if not maze.boss_sealed and not boss.is_empty() and boss.alive:
		objective_target = boss.pos
		remaining = 1
		objective_text = "The Minotaur is hunting you. Defeat it, then return to Athena's shrine."
	route = nav.get_point_path(closest_nav_cell(player_pos),closest_nav_cell(objective_target))
	var direction := Vector2.ZERO
	for point in route:
		if player_pos.distance_to(point)>42.0:
			direction = point-player_pos
			break
	var compass := ("east" if direction.x>0 else "west") if absf(direction.x)>absf(direction.y) else ("south" if direction.y>0 else "north")
	if player_pos.distance_to(objective_target)<90.0:
		route_text = "Warden nearby: aim at its body and hold click. Dodge the red attack ring." if remaining>0 else "Step into the shrine's ring. It becomes your respawn checkpoint."
	elif route.is_empty():
		route_text = "Route is being recalculated. Wait for the next shift or return to the last shrine."
	else:
		route_text = "Head %s along the gold trail (%d tiles). M: map | G: toggle trail." % [compass,route.size()]
	for i in range(2):
		if not gates[i] and absf(player_pos.x-(i+1)*SECTOR_WIDTH)<150.0:
			route_text = "Bronze gate sealed: clear the wardens in %s, then activate its shrine. F cannot unlock this gate." % SECTOR_NAMES[i]
	if maze.boss_sealed and player_pos.distance_to(checkpoints[2]) < 500.0:
		route_text = "Minotaur's chamber sealed: defeat ALL %d remaining spirits across the labyrinth to release it." % spirits_remaining()

func wrapped_label(value: String, pos: Vector2, width: float, font_size: int, color: Color, max_lines: int = 3) -> void:
	var line := ""
	var row := 0
	for word in value.split(" "):
		var candidate := line+word+" "
		if ThemeDB.fallback_font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width and not line.is_empty():
			label(line,pos+Vector2(0,row*(font_size+5)),font_size,color)
			row += 1
			line = ""
			if row >= max_lines: return
		line += word+" "
	if not line.is_empty(): label(line,pos+Vector2(0,row*(font_size+5)),font_size,color)

func draw_guidance() -> void:
	var x := 448.0
	var width := size.x-x-272.0
	draw_rect(Rect2(x-12,14,width+24,126),Color(0.025,0.04,0.06,0.92))
	wrapped_label(objective_text,Vector2(x,38),width,17,GOLD,2)
	wrapped_label(route_text,Vector2(x,86),width,15,PALE,3)
	var lock_text := "F: lock aimed passage for 10s"
	if frozen_wall>=0: lock_text = "LOCKED %s: %ds" % ["OPEN" if shifts[frozen_wall].open else "CLOSED",ceili(freeze_left)]
	elif freeze_cooldown>0.0: lock_text = "Lock recharging: %ds" % ceili(freeze_cooldown)
	label(lock_text,Vector2(size.x-252,181),14,CYAN)
	var boss := get_minotaur()
	var boss_status := "Minotaur defeated"
	if not boss.is_empty() and boss.alive:
		boss_status = "Minotaur sealed: %d spirits" % spirits_remaining() if maze.boss_sealed else "Minotaur: HUNTING YOU"
	label(boss_status,Vector2(size.x-252,204),14,Color("969da7") if maze.boss_sealed else Color("f071b5"))
	if message_left>0.0:
		draw_rect(Rect2(200,size.y-133,size.x-400,55),Color(0.025,0.04,0.06,0.94))
		wrapped_label(message,Vector2(218,size.y-111),size.x-436,16,PALE,2)

func draw_darkness() -> void:
	if darkness == null: return
	var center := player_pos+(size*0.5-camera).round()
	var area := Rect2(center-Vector2.ONE*420,Vector2.ONE*840)
	var shade := Color(0.01,0.02,0.04,0.86)
	if area.position.x>0: draw_rect(Rect2(0,0,area.position.x,size.y),shade)
	if area.end.x<size.x: draw_rect(Rect2(area.end.x,0,size.x-area.end.x,size.y),shade)
	var left := maxf(0,area.position.x)
	var width := minf(size.x,area.end.x)-left
	if area.position.y>0: draw_rect(Rect2(left,0,width,area.position.y),shade)
	if area.end.y<size.y: draw_rect(Rect2(left,area.end.y,width,size.y-area.end.y),shade)
	draw_texture_rect(darkness,area,false)

func draw_help() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.02,0.04,0.94))
	var origin := size*0.5-Vector2(440,250)
	label("FIELD GUIDE",origin,30,GOLD)
	var paragraphs := [
		"Defeat each sector's spirits, then use its shrine to advance. Kill ALL spirits to unseal the Minotaur's chamber. It then hunts you through the maze. Its horn map marker turns pink. Defeat it and return to Athena's shrine.",
		"The labyrinth changes every 6 seconds. Amber sockets warn of a shift. Every chamber keeps a route out. Bronze sector gates unlock through shrines, not through waiting.",
		"F locks the passage under your cursor in its CURRENT state for 10 seconds. Keep an open route open, or keep a closed route closed. Aim within three tiles. Cyan sockets show the lock; it then recharges for 5 seconds.",
		"Follow the gold trail and the live directions at the top. M opens the full map. G toggles the trail. Red map marks your current objective; gold marks shrines; cyan marks you.",
		"WASD moves. Aim at a spirit's body and hold left click to fire arrows from the bow. Spirits investigate noise, pursue through passages and search where they last saw you. Move out of red attack rings.",
		"E collects items. R consumes a healing relic. Tab opens inventory: click armor to equip, or press X to drop the selected item, at an activated shrine outside combat. H closes this guide. Escape pauses."
	]
	for i in range(paragraphs.size()): wrapped_label(paragraphs[i],origin+Vector2(0,44+i*75),880,17,PALE,3)

func draw_full_map() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.02,0.04,0.96))
	var scale_factor := minf((size.x-100)/maze.GRID.x,(size.y-170)/maze.GRID.y)
	var origin := (size-Vector2(maze.GRID)*scale_factor)*0.5
	label("THE SHIFTING LABYRINTH",Vector2(50,42),26,GOLD)
	label("Cyan: you   Red: objective   Gold: shrines   Horns: Minotaur (gray = sealed, pink = hunting)   M: close",Vector2(50,size.y-35),16,PALE)
	for cell in maze.cells: draw_rect(Rect2(origin+Vector2(cell)*scale_factor,Vector2.ONE*scale_factor),Color("77715d"))
	if route.size()>1:
		var points := PackedVector2Array()
		for point in route: points.append(origin+point/UNIT*scale_factor)
		draw_polyline(points,GOLD,2)
	for i in range(3): draw_circle(origin+checkpoints[i]/UNIT*scale_factor,5,GOLD)
	var boss := get_minotaur()
	if maze.boss_sealed or boss.is_empty() or not boss.alive:
		draw_circle(origin+objective_target/UNIT*scale_factor,6,RED)
	draw_circle(origin+player_pos/UNIT*scale_factor,6,CYAN)
	draw_boss_marker(origin,scale_factor,7.0)

func draw_hud() -> void:
	draw_minimap()
	draw_guidance()
	label("SHIFT  %02d" % ceili(shift_clock), Vector2(size.x-241,158),16,GOLD if shift_clock<2.0 else PALE)
	label("WASD Move   Hold click Fire   F Lock passage   E Collect   R Heal   Tab Inventory   M Map   H Help",Vector2(26,size.y-20),14,Color("a0aca8"))
	draw_rect(Rect2(16, 14, 304, 112), Color(0.04, 0.07, 0.12, 0.88))
	label("The Explorer", Vector2(34,42),22,CYAN)
	label("Health", Vector2(34, 69), 16)
	draw_rect(Rect2(104, 55, 190, 18), Color("3d4552"))
	draw_rect(Rect2(104, 55, 190.0 * health / 100.0, 18), RED if health < 35 else CYAN)
	label("Slots", Vector2(34, 105), 16)
	for i in range(INVENTORY_CAPACITY):
		draw_rect(Rect2(104 + i * 19, 92, 14, 13), GOLD if i < used_slots() else Color("465260"))
	# Cooldown indicators remain graphical.
	draw_rect(Rect2(335, 22, 90, 5), Color("465260"))
	draw_rect(Rect2(335, 22, 90.0 * (1.0 - shot_cooldown / 0.5), 5), GOLD)
	draw_rect(Rect2(335, 34, 90, 5), Color("465260"))
	draw_rect(Rect2(335, 34, 90.0 * (1.0 - heal_cooldown / 5.0), 5), CYAN)
	draw_rect(Rect2(335, 46, 90, 5), Color("465260"))
	draw_rect(Rect2(335, 46, 90.0 * (freeze_left / 10.0 if freeze_left > 0.0 else 1.0 - freeze_cooldown / 5.0), 5), Color("a2d4ee"))
	if inventory_open: draw_inventory()
	for enemy in enemies:
		if enemy["boss"] and enemy["alive"] and player_pos.distance_to(enemy["pos"]) < 11 * UNIT:
			label("Minotaur", Vector2(size.x * 0.5 - 48, size.y - 68), 22, RED)
			draw_rect(Rect2(size.x * 0.5 - 145, size.y - 54, 290, 10), Color("48505e"))
			draw_rect(Rect2(size.x * 0.5 - 145, size.y - 54, 290 * enemy["hp"] / 100.0, 10), RED)
	if mode == "playing":
		var world_mouse := screen_to_world(get_local_mouse_position())
		for pickup in pickups:
			if not pickup["locked"] and player_pos.distance_to(pickup["pos"]) < 90:
				var screen_pos: Vector2 = pickup["pos"] + (size * 0.5 - camera).round()
				draw_icon(pickup["kind"], screen_pos + Vector2(0, -39), 0.55)
				break

func inventory_item_rect(index: int) -> Rect2:
	return Rect2(size.x - 317.0 + float(index % 2) * 143.0, 139.0 + floori(float(index) / 2.0) * 44.0, 128, 38)

func draw_inventory() -> void:
	var x := size.x - 330.0
	draw_rect(Rect2(x, 98, 300, 460), Color(0.04, 0.07, 0.12, 0.94))
	draw_rect(Rect2(x, 98, 300, 3), GOLD)
	label("Inventory", Vector2(x + 20, 129), 24, GOLD)
	for i in range(inventory.size()):
		var y := 158.0 + floori(float(i) / 2.0) * 44.0
		var item_x := x + 38.0 + float(i % 2) * 143.0
		if i == selected_item: draw_rect(inventory_item_rect(i), Color(0.28, 0.4, 0.48, 0.55))
		draw_icon(inventory[i], Vector2(item_x, y), 0.55)
		if i == inventory.find(equipped) or i == inventory.find("weapon"): draw_arc(Vector2(item_x, y), 17, 0, TAU, 20, GOLD, 2)
	# The fixed legend is the only textual equipment list.
	var legend_y := 389.0
	var legend := ["Light Armor", "Medium Armor", "Heavy Armor", "Weapon", "Healing Relic"]
	var kinds := ["light", "medium", "heavy", "weapon", "relic"]
	for i in range(legend.size()):
		draw_icon(kinds[i], Vector2(x + 33, legend_y + i * 29), 0.38)
		label(legend[i], Vector2(x + 56, legend_y + 6 + i * 29), 15)

func draw_menu() -> void:
	var center := size * 0.5
	for i in range(21):
		var x := float(i) * 100.0 - 250.0
		draw_line(Vector2(x, 0), Vector2(x + 350, size.y), Color(0.5, 0.68, 0.73, 0.04), 3)
	draw_circle(center + Vector2(0, -120), 115, Color(0.17, 0.25, 0.33, 0.5))
	draw_arc(center + Vector2(0, -120), 101, 0, TAU, 48, GOLD, 3)
	draw_line(center + Vector2(-68, -168), center + Vector2(0, -98), CYAN, 8)
	draw_line(center + Vector2(68, -168), center + Vector2(0, -98), GOLD, 8)
	draw_line(center + Vector2(0, -98), center + Vector2(0, -40), RED, 8)
	if mode == "controls":
		label("Controls", center + Vector2(-92, -193), 36, GOLD)
		var controls := ["Move: W A S D", "Aim: Mouse", "Fire: Left Click", "Pick up: E", "Lock nearby passage for 10 seconds: F", "Heal: R", "Inventory: Tab", "Map: M | Field guide: H | Route: G", "At shrine, select equipment: Left Click", "At shrine, drop selected item: X", "Pause: Escape"]
		for i in range(controls.size()): label(controls[i], center + Vector2(-185, -155 + i * 32), 18)
		button("Back", center + Vector2(-135, 215), 270, 48)
		return
	label("The Shifting Labyrinth", center + Vector2(-245, 17), 42, PALE)
	button("Play", center + Vector2(-135, 62), 270, 48)
	button("Controls", center + Vector2(-135, 122), 270, 48)
	button("Quit", center + Vector2(-135, 182), 270, 48)

func button(value: String, pos: Vector2, width: float, height: float) -> void:
	draw_rect(Rect2(pos, Vector2(width, height)), Color("334657"))
	draw_rect(Rect2(pos, Vector2(width, 3)), GOLD)
	var text_width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	label(value, pos + Vector2((width - text_width) * 0.5, 31), 22)

func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07, 0.75))
	button("Back", size * 0.5 + Vector2(-130, 20), 260, 45)
	button("Restart", size * 0.5 + Vector2(-130, 75), 260, 45)

func draw_reveal() -> void:
	draw_rect(Rect2(size.x * 0.5 - 360, size.y - 160, 720, 112), Color(0.04, 0.07, 0.12, 0.92))
	draw_rect(Rect2(size.x * 0.5 - 360, size.y - 160, 720, 3), GOLD)
	label("I am Athena. I sent you here to end the Minotaur's reign.", Vector2(size.x * 0.5 - 328, size.y - 120), 20, GOLD)
	label("You broke the labyrinth's curse. Now I will bring you home.", Vector2(size.x * 0.5 - 328, size.y - 82), 20)

func draw_victory() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.1, 0.13, 0.9))
	draw_circle(size * 0.5, 160, Color(0.64, 0.53, 0.32, 0.1))
	draw_arc(size * 0.5, 160, 0, TAU, 48, GOLD, 3)
	label("The way home.", size * 0.5 + Vector2(-125, 8), 34, PALE)
	button("Restart", size * 0.5 + Vector2(-130, 55), 260, 45)
