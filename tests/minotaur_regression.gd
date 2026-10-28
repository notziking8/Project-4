extends SceneTree
var checks := 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
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
	g.gates = [true,true]
	g.build_navigation()
	await physics_frame
	await physics_frame
	var boss: Dictionary = g.get_minotaur()
	var origin: Vector2 = boss.pos
	g.player_pos = Vector2(6368,1760)
	check(g.spirits_remaining()==24 and g.maze.boss_sealed,"Boss begins sealed behind all 24 spirits")
	check(g.nav.get_point_path(g.closest_nav_cell(g.player_pos),g.closest_nav_cell(boss.pos)).is_empty(),"Boss chamber is unreachable even with sector gates open")
	for enemy in g.enemies:
		if enemy.boss: continue
		check(not g.nav.get_point_path(g.closest_nav_cell(g.player_pos),g.closest_nav_cell(enemy.home)).is_empty(),"Every spirit remains reachable outside sealed chamber")
	for cycle in range(50):
		g.shift_walls()
		await physics_frame
		g.update_enemies(0.1)
		check(boss.pos==origin and boss.state=="sealed" and not boss.pursuing,"Sealed boss cannot patrol or pursue")
		check(g.maze.sector_connected(2),"All non-boss rooms remain connected")
		check(g.nav.get_point_path(g.closest_nav_cell(g.player_pos),g.closest_nav_cell(boss.pos)).is_empty(),"Random shifts cannot open the boss chamber")
		for edge in g.shifts:
			if not edge.boss_gate: continue
			var query := PhysicsPointQueryParameters2D.new()
			query.position = edge.rect.get_center()
			query.collision_mask = 1
			check(not g.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"Sealed boss doorway has actual collider")
	for edge in g.shifts:
		if edge.boss_gate and edge.rect.size.y>edge.rect.size.x:
			g.player_pos = edge.rect.get_center()-Vector2(80,0)
			g.use_flashlight(edge.rect.get_center())
			check(g.frozen_wall==-1,"F cannot bypass the boss seal")
			break
	# Defensive projectile test from inside the sealed room (unreachable in normal play).
	g.player_pos = boss.pos+Vector2(-90,0)
	g.shot_cooldown = 0
	g.shoot(boss.pos+Vector2(0,-48))
	g.update_arrows(0.3)
	check(boss.hp==100 and boss.alive,"Sealed boss cannot be damaged by arrows")
	g.defeat_enemy(boss)
	check(boss.alive,"Sealed boss cannot be defeated early")
	var final_spirit: Dictionary = g.enemies[0]
	for enemy in g.enemies:
		if not enemy.boss and enemy != final_spirit: enemy.alive = false
	g.update_boss_unlock()
	check(g.maze.boss_sealed and g.spirits_remaining()==1,"A surviving spirit in an earlier sector keeps the boss sealed")
	g.player_pos = Vector2(6368,1760)
	g.defeat_enemy(final_spirit)
	await physics_frame
	check(not g.maze.boss_sealed and boss.state=="chase" and boss.pursuing,"Last spirit immediately releases the boss")
	check("hunting" in g.message,"Release announcement explains the hunt")
	for edge in g.shifts:
		if not edge.boss_gate: continue
		var query := PhysicsPointQueryParameters2D.new()
		query.position = edge.rect.get_center()
		query.collision_mask = 1
		check(g.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"Released doorway collider removed")
	check(g.maze.sector_connected(2),"Boss chamber joins the full connected sector")
	# Pick a distant player position behind walls, beyond the normal spirit detection radius.
	var found := false
	for row in range(1,8):
		for col in range(13,17):
			var target := Vector2(col*384+224,row*384+224)
			var path: PackedVector2Array = g.nav.get_point_path(g.closest_nav_cell(boss.pos),g.closest_nav_cell(target))
			if boss.pos.distance_to(target)>650 and not g.has_line_of_sight(boss.pos,target) and path.size()>15 and path.size()<45:
				g.player_pos = target
				found = true
				break
		if found: break
	check(found,"Distant occluded hunt scenario found")
	var ticks := 0
	var inside_wall := false
	var abandoned := false
	for i in range(6000):
		if i==120:
			g.shift_walls()
			await physics_frame
		g.update_enemies(1.0/60.0)
		ticks += 1
		if boss.state in ["search","return","idle"]: abandoned = true
		if g.body_collides(boss.pos,22,g.blocking_rects()): inside_wall = true
		if boss.pos.distance_to(g.player_pos)<100: break
	check(not abandoned,"Boss never abandons the hunt outside sight range")
	check(not inside_wall,"Boss pathfinding respects wall collisions")
	check(boss.pos.distance_to(g.player_pos)<100,"Boss reaches player through obstacles and a mid-hunt shift")
	g.update_guidance()
	check(g.objective_target==boss.pos and "Minotaur" in g.objective_text,"Objective follows the moving boss")
	check(g.get_minotaur().pos!=origin,"Map marker source follows live boss position")
	g.checkpoint = 1
	g.respawn()
	g.update_enemies(1.0/60.0)
	check(not g.maze.boss_sealed and boss.state=="chase","Respawning does not reseal or reset the hunt")
	g.defeat_enemy(boss)
	g.player_pos = g.checkpoints[2]
	g.update_shrines()
	check(not boss.alive and g.mode=="reveal","Boss victory still leads to Athena")
	g.reset_game()
	check(g.maze.boss_sealed and g.spirits_remaining()==24 and g.get_minotaur().alive,"Restart restores spirits and boss seal")
	print(JSON.stringify({"checks":checks,"failures":failures,"sealed_shifts":50,"hunt_ticks":ticks}))
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
