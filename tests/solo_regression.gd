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
	g.maze.generate(73491)
	g.shifts = g.maze.connections
	g.build_navigation()
	await physics_frame
	await physics_frame
	check(g.maze.ROOMS.x*g.maze.ROOMS.y==162,"162 chambers")
	check(g.shifts.size()==297,"Every interior adjacency has a connection")
	check(g.SHIFT_INTERVAL==6.0,"Six-second shift interval")
	var properties: Array = g.get_property_list().map(func(p): return p.name)
	check(not properties.has("explorers") and not properties.has("active"),"One player; no switchable companion")
	check(g.maze.wall_layer.tile_set.get_source(0).texture.resource_path.ends_with("connected_walls.png"),"Approved wall art retained")
	check(g.move_body(Vector2(224,224),Vector2(-900,0),16).x>=79,"Swept movement blocks outer walls")
	var frozen := -1
	var occupied := -1
	for i in range(g.shifts.size()):
		if g.shifts[i].sector!=0: continue
		if not g.shifts[i].open and frozen<0: frozen = i
		elif g.shifts[i].open and occupied<0: occupied = i
	g.frozen_wall = frozen
	g.player_pos = g.shifts[occupied].rect.get_center()
	var touched := {}
	var opened := 0
	var closed := 0
	for iteration in range(160):
		g.shift_walls()
		await physics_frame
		var sectors := {}
		for index in g.maze.last_changed:
			touched[index] = true
			var edge: Dictionary = g.shifts[index]
			sectors[edge.sector] = true
			if edge.open: opened += 1
			else: closed += 1
			var q := PhysicsPointQueryParameters2D.new()
			q.position = edge.rect.get_center()
			q.collision_mask = 1
			var hits: Array = g.get_world_2d().direct_space_state.intersect_point(q)
			check(hits.is_empty()==edge.open,"Connection and collider agree %d/%d" % [iteration,index])
		check(sectors.has(0) and sectors.has(1) and sectors.has(2),"Shifts affect all three sectors")
		for sector in range(3): check(g.maze.sector_connected(sector),"All 54 rooms in sector remain connected")
		check(not g.shifts[frozen].open,"Closed frozen passage stays closed")
		check(g.shifts[occupied].open,"Occupied open passage stays open")
		var matches := true
		for y in range(g.maze.GRID.y):
			for x in range(g.maze.GRID.x):
				var c := Vector2i(x,y)
				if g.nav.is_point_solid(c)!=g.maze.cells.has(c): matches = false
		check(matches,"Navigation exactly matches current walls")
	check(touched.size()>=270,"Connections throughout the entire maze participate")
	# Both open and closed locks, with explanatory feedback.
	g.frozen_wall = -1
	g.freeze_cooldown = 0
	var edge: Dictionary = g.shifts[frozen]
	g.player_pos = edge.rect.get_center()-(Vector2(80,0) if edge.rect.size.y>edge.rect.size.x else Vector2(0,80))
	g.use_flashlight(edge.rect.get_center())
	check(g.frozen_wall==frozen and "CLOSED" in g.message,"Closed lock is actionable and explained")
	g.frozen_wall = -1
	edge = g.shifts[occupied]
	g.player_pos = edge.rect.get_center()
	g.use_flashlight(edge.rect.get_center())
	check(g.frozen_wall==occupied and "OPEN" in g.message,"Open lock is actionable and explained")
	g.frozen_wall = -1
	# Find a closed adjacency with a short but nontrivial route around it.
	var start := Vector2.ZERO
	var destination := Vector2.ZERO
	var initial_path_length := 0
	for candidate in g.shifts:
		if candidate.sector!=0 or candidate.open: continue
		var a: Vector2 = Vector2(candidate.from)*384+Vector2(224,224)
		var b: Vector2 = Vector2(candidate.to)*384+Vector2(224,224)
		var path: PackedVector2Array = g.nav.get_point_path(g.closest_nav_cell(a),g.closest_nav_cell(b))
		if path.size()>12 and path.size()<45:
			start = a
			destination = b
			initial_path_length = path.size()
			break
	check(initial_path_length>12,"Obstacle pursuit scenario found")
	for enemy in g.enemies: enemy.alive = false
	var spirit: Dictionary = g.enemies[0]
	spirit.alive = true
	spirit.pos = start
	spirit.home = start
	spirit.state = "chase"
	spirit.last_seen = destination
	spirit.memory = 100.0
	spirit.path_time = 0.0
	g.player_pos = destination
	var collided := false
	var steps := 0
	for i in range(2400):
		if i==120:
			g.shift_walls()
			await physics_frame
		g.update_enemies(1.0/60.0)
		steps += 1
		if g.body_collides(spirit.pos,16,g.blocking_rects()): collided = true
		if spirit.pos.distance_to(destination)<100: break
	check(not collided,"Spirit follows paths without entering walls")
	check(spirit.pos.distance_to(destination)<100,"Spirit reaches player around a closed wall without backtracking loop")
	spirit.state = "chase"
	spirit.memory = 0.01
	spirit.last_seen = spirit.pos
	g.player_pos = Vector2(6700,3300)
	g.update_enemies(0.02)
	check(spirit.state=="search","Lost contact enters search")
	g.update_enemies(2.1)
	check(spirit.state=="return","Search expires into return")
	# Projectile geometry and nearest-hit collision.
	for enemy in g.enemies: enemy.alive = false
	g.player_pos = Vector2(224,224)
	g.shot_cooldown = 0
	g.arrows.clear()
	g.enemies[0].alive = true
	g.enemies[0].hp = 50
	g.enemies[0].pos = Vector2(310,229)
	g.enemies[1].alive = true
	g.enemies[1].hp = 50
	g.enemies[1].pos = Vector2(350,229)
	g.shoot(Vector2(500,201))
	check(g.arrows.size()==1,"Bow creates a travelling arrow")
	check(g.arrows[0].pos.distance_to(g.bow_muzzle(g.aim))<0.001,"Arrow originates at rendered bow muzzle")
	g.update_arrows(0.3)
	check(g.enemies[0].hp==25 and g.enemies[1].hp==50,"Arrow hits nearest enemy once")
	check(g.arrows.is_empty(),"Arrow disappears after impact")
	for enemy in g.enemies: enemy.alive = false
	g.player_pos = Vector2(224,224)
	for i in range(8):
		g.arrows.clear()
		g.shot_cooldown = 0
		var direction := Vector2.RIGHT.rotated(i*TAU/8.0)
		g.shoot(g.player_pos+Vector2(0,-23)+direction*120)
		check(g.arrows.size()==1 and g.arrows[0].pos.distance_to(g.bow_muzzle(direction))<0.01,"Bow and projectile agree in direction %d" % i)
	g.arrows.clear()
	g.enemies[0].alive = true
	g.enemies[0].pos = Vector2(-30,229)
	g.enemies[0].hp = 50
	g.shot_cooldown = 0
	g.shoot(Vector2(-100,201))
	g.update_arrows(1.0)
	check(g.enemies[0].hp==50 and g.arrows.is_empty(),"Wall blocks arrow before enemy")
	g.player_pos = Vector2(224,100)
	g.shot_cooldown = 0
	g.shoot(Vector2(224,-100))
	check(g.arrows.is_empty(),"Muzzle cannot spawn a projectile through a wall")
	# Solo progression and guidance update with no reunion dependency.
	for enemy in g.enemies:
		enemy.alive = false
		enemy.pursuing = false
		enemy.state = "idle"
	g.player_pos = g.checkpoints[0]
	g.update_guidance()
	check("shrine" in g.objective_text,"Guidance changes from combat to shrine")
	g.update_shrines()
	check(g.checkpoint==0 and g.gates[0],"Lone explorer opens first gate")
	g.player_pos = g.checkpoints[1]
	g.update_shrines()
	check(g.checkpoint==1 and g.gates[1],"Lone explorer opens second gate")
	var changed_boundaries := {}
	for i in range(30):
		g.shift_walls()
		for index in g.maze.last_changed:
			if g.shifts[index].gate>=0: changed_boundaries[index] = true
		check(g.maze.boundary_connected(0) and g.maze.boundary_connected(1),"Unlocked boundaries never disconnect")
	check(changed_boundaries.size()==18,"All unlocked border connections participate in shifts")
	g.health = 1
	g.respawn()
	check(g.health==100 and g.player_pos.distance_to(g.checkpoints[1])<100,"Solo checkpoint respawn")
	g.player_pos = g.checkpoints[2]
	g.update_shrines()
	check(g.mode=="reveal","Solo campaign reaches Athena")
	g._process(0)
	check(g.player_light.position==g.player_pos and g.world_modulate.color.r<0.4,"Dark world with player-centred light")
	check(g.player_light.range_layer_min==-1 and g.player_light.range_layer_max==-1 and g.material.light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"Lantern illuminates world without lighting HUD")
	g.reset_game()
	check(g.mode=="menu" and g.player_pos==Vector2(224,224) and g.arrows.is_empty(),"Clean solo restart")
	print(JSON.stringify({"checks":checks,"failures":failures,"shift_cycles":191,"opened":opened,"closed":closed,"interior_connections_changed":touched.size(),"border_connections_changed":changed_boundaries.size(),"pursuit_route_tiles":initial_path_length,"pursuit_ticks":steps}))
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
