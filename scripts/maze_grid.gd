extends Node2D
## Authoritative cell occupancy: rendering, physics, sight and paths use this grid.
const CELL := 64
const ROOMS := Vector2i(18, 9)
const SECTOR_COLUMNS := 6
const GRID := Vector2i(109, 55)
const BOSS_ROOM := Vector2i(17, 4)
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOOR := preload("res://assets/art/environment/tiles/polished_floor.png")
const WALL := preload("res://assets/art/environment/tiles/connected_walls.png")
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var cells := {}
var base_cells := {}
var connections: Array = []
var blockers: Array = []
var rng := RandomNumberGenerator.new()
var adjacency := {}
var revision := 0
var last_changed: Array = []
var boss_sealed := true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorTiles"
	floor_layer.tile_set = make_tileset(FLOOR, 6, false)
	floor_layer.z_index = -2
	add_child(floor_layer)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "ConnectedWalls"
	wall_layer.tile_set = make_tileset(WALL, 16, true)
	wall_layer.z_index = 1
	add_child(wall_layer)
	for y in range(GRID.y):
		for x in range(GRID.x):
			var variant := 0
			if posmod(x * 73 + y * 31, 13) == 0: variant = 1 + posmod(x + y, 3)
			if x > 18 and x % 6 == 3 and y == 9: variant = 4
			if x > 36 and x % 6 == 3 and y == 16: variant = 5
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))

func make_tileset(texture: Texture2D, count: int, solid: bool) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(CELL, CELL)
	if solid:
		tiles.add_physics_layer()
		tiles.set_physics_layer_collision_layer(0, 1)
		tiles.set_physics_layer_collision_mask(0, 0)
		tiles.add_occlusion_layer()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(CELL, CELL)
	tiles.add_source(atlas, 0)
	var polygon := PackedVector2Array([Vector2(-32,-32), Vector2(32,-32), Vector2(32,32), Vector2(-32,32)])
	for i in range(count):
		atlas.create_tile(Vector2i(i, 0))
		if solid:
			var data := atlas.get_tile_data(Vector2i(i, 0), 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, polygon)
			var occluder := OccluderPolygon2D.new()
			occluder.polygon = polygon
			data.set_occluder(0, occluder)
	return tiles

func generate(seed_value: int = 73491) -> void:
	rng.seed = seed_value
	boss_sealed = true
	connections.clear()
	adjacency.clear()
	base_cells.clear()
	for y in range(GRID.y):
		for x in range(GRID.x):
			if x % 6 == 0 or y % 6 == 0: base_cells[Vector2i(x,y)] = true
	for y in range(ROOMS.y):
		for x in range(ROOMS.x):
			var room := Vector2i(x,y)
			var sector := x / SECTOR_COLUMNS
			if x < ROOMS.x-1:
				var border := (x+1) % SECTOR_COLUMNS == 0
				add_connection(room,room+Vector2i.RIGHT,-1 if border else sector)
			if y < ROOMS.y-1: add_connection(room,room+Vector2i.DOWN,sector)
	for i in shuffled_indices():
		var edge: Dictionary = connections[i]
		if edge.boss_gate:
			edge.open = false
		elif edge.sector < 0:
			edge.open = edge.from.y == ROOMS.y / 2
		elif rng.randf() < 0.85:
			edge.open = false
			if not sector_connected(edge.sector): edge.open = true
	revision = 0
	last_changed.clear()
	rebuild([false,false])

func add_connection(a: Vector2i, b: Vector2i, sector: int) -> void:
	var door: Array = []
	if b.x != a.x:
		for n in range(2,5): door.append(Vector2i(b.x * 6, a.y * 6 + n))
	else:
		for n in range(2,5): door.append(Vector2i(a.x * 6 + n, b.y * 6))
	var rect := Rect2(Vector2(door[0]) * CELL, Vector2(64,192) if b.x != a.x else Vector2(192,64))
	connections.append({"from":a, "to":b, "sector":sector, "open":true, "cells":door, "rect":rect, "gate":a.x / SECTOR_COLUMNS if sector < 0 else -1, "boss_gate":a == BOSS_ROOM or b == BOSS_ROOM})
	var index := connections.size()-1
	if not adjacency.has(a): adjacency[a] = []
	if not adjacency.has(b): adjacency[b] = []
	adjacency[a].append(index)
	adjacency[b].append(index)

func shuffled_indices() -> Array:
	var order: Array = range(connections.size())
	for i in range(order.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var temp: int = order[i]
		order[i] = order[j]
		order[j] = temp
	return order

func sector_connected(sector: int) -> bool:
	var visited := {Vector2i(sector*SECTOR_COLUMNS,0):true}
	var queue: Array = visited.keys()
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for index in adjacency[current]:
			var edge: Dictionary = connections[index]
			if edge.sector != sector or not edge.open: continue
			if boss_sealed and edge.boss_gate: continue
			var next: Vector2i = edge.to if edge.from == current else edge.from
			if not visited.has(next):
				visited[next] = true
				queue.append(next)
	# The sealed boss chamber is intentionally isolated; all spirit rooms stay reachable.
	return visited.size() == SECTOR_COLUMNS * ROOMS.y - (1 if sector == 2 and boss_sealed else 0)

func release_boss() -> void:
	boss_sealed = false
	for edge in connections:
		if edge.boss_gate: edge.open = true

func boundary_connected(gate: int) -> bool:
	for edge in connections:
		if edge.gate == gate and edge.open: return true
	return false

func shift(occupied: Array, frozen: int, gates: Array) -> int:
	last_changed.clear()
	var order := shuffled_indices()
	# Distribute changes across every sector, not just near the player.
	for desired in [true,false]:
		var changes := [0,0,0,0,0]
		for i in order:
			var edge: Dictionary = connections[i]
			if i == frozen or edge.open == desired or last_changed.has(i): continue
			if boss_sealed and edge.boss_gate: continue
			if edge.gate >= 0 and not gates[edge.gate]: continue
			var bucket: int = edge.sector if edge.sector >= 0 else 3+edge.gate
			if changes[bucket] >= (8 if bucket < 3 else 2): continue
			var unsafe := false
			if not desired:
				for body in occupied:
					if edge.rect.grow(body.radius+4.0).has_point(body.pos): unsafe = true
			if unsafe: continue
			edge.open = desired
			var connected := sector_connected(edge.sector) if edge.sector >= 0 else boundary_connected(edge.gate)
			if not connected:
				edge.open = not desired
				continue
			last_changed.append(i)
			changes[bucket] += 1
	if not last_changed.is_empty():
		revision += 1
		rebuild(gates)
	return last_changed.size()

func rebuild(gates: Array) -> void:
	var old_cells := cells
	cells = base_cells.duplicate()
	for edge in connections:
		if edge.open and (edge.gate < 0 or gates[edge.gate]) and not (boss_sealed and edge.boss_gate):
			for cell in edge.cells: cells.erase(cell)
	for cell in old_cells:
		if not cells.has(cell): wall_layer.erase_cell(cell)
	blockers.clear()
	for cell in cells:
		var mask := 0
		for n in range(4):
			if cells.has(cell+DIRECTIONS[n]): mask |= 1 << n
		if wall_layer.get_cell_atlas_coords(cell) != Vector2i(mask,0):
			wall_layer.set_cell(cell,0,Vector2i(mask,0))
		blockers.append(Rect2(Vector2(cell)*CELL,Vector2.ONE*CELL))
	wall_layer.update_internals()
	queue_redraw()

func _draw() -> void:
	for cell in cells:
		if not cells.has(cell + Vector2i.DOWN):
			draw_rect(Rect2(Vector2(cell)*CELL + Vector2(4,64),Vector2(64,10)),Color(0,0,0,0.35))
