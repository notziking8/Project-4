class_name Enemy
extends CharacterBody2D

enum EnemyType { LIGHT, HEAVY }
enum DamageType { PHYSICAL, ELECTRICAL }

@export var enemy_type: EnemyType = EnemyType.LIGHT
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var drop_item_scene: PackedScene

# Team 3 scale constant: 1 Godot unit / meter = 64 pixels
const UNIT: float = 64.0

# Base stats governed by the Team 3 specifications
var max_hp: float = 50.0
var current_hp: float = 50.0
var move_speed: float = 4.0 * UNIT # Light: 4 units/s, Heavy: 2 units/s
var attack_damage: float = 10.0
var attack_interval: float = 1.5

# Distances converted to pixels using UNIT
const DETECTION_RANGE: float = 6.0 * UNIT # 384 px
const ATTACK_RANGE: float = 2.0 * UNIT    # 128 px
const LEASH_DISTANCE: float = 10.0 * UNIT  # 640 px

var spawn_position: Vector2
var attack_timer: float = 0.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var los_ray: RayCast2D = $RayCast2D

signal enemy_defeated(enemy_ref)

func _ready() -> void:
	spawn_position = global_position
	_configure_stats()
	current_hp = max_hp

func _configure_stats() -> void:
	match enemy_type:
		EnemyType.LIGHT:
			max_hp = 50.0
			move_speed = 4.0 * UNIT
			attack_damage = 10.0
			attack_interval = 1.5
		EnemyType.HEAVY:
			max_hp = 100.0
			move_speed = 2.0 * UNIT
			attack_damage = 20.0
			attack_interval = 3.0
			damage_type = DamageType.PHYSICAL

func _physics_process(delta: float) -> void:
	var player = _get_active_player()
	if not player:
		_idle_or_return()
		return

	var dist_from_spawn = global_position.distance_to(spawn_position)
	var dist_to_player = global_position.distance_to(player.global_position)
	var has_los = _check_line_of_sight(player.global_position)

	# 1. Leash check: over 10 units triggers return without healing
	if dist_from_spawn > LEASH_DISTANCE or dist_to_player > LEASH_DISTANCE:
		_return_to_spawn()
		return

	# 2. Combat / Detection: Within 6 units with clear line of sight
	if dist_to_player <= DETECTION_RANGE and has_los:
		if dist_to_player <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			_handle_attack(player, delta)
		else:
			attack_timer = 0.0
			_navigate_towards(player.global_position)
	else:
		_idle_or_return()

	move_and_slide()

func _handle_attack(player: Node2D, delta: float) -> void:
	attack_timer += delta
	# Waits initial interval, then repeats at interval
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		if player.has_method("take_damage"):
			var dmg_type_str = "electrical" if damage_type == DamageType.ELECTRICAL else "physical"
			player.take_damage(attack_damage, dmg_type_str, global_position)

func _navigate_towards(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	if not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		velocity = (next_pos - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO

func _return_to_spawn() -> void:
	attack_timer = 0.0
	if global_position.distance_to(spawn_position) > 8.0:
		_navigate_towards(spawn_position)
	else:
		velocity = Vector2.ZERO

func _idle_or_return() -> void:
	attack_timer = 0.0
	if global_position.distance_to(spawn_position) > 8.0:
		_return_to_spawn()
	else:
		velocity = Vector2.ZERO

func _check_line_of_sight(target_pos: Vector2) -> bool:
	los_ray.global_position = global_position
	los_ray.target_position = target_pos - global_position
	los_ray.force_raycast_update()
	return not los_ray.is_colliding() or los_ray.get_collider().is_in_group("Player")

func take_damage(amount: float) -> void:
	current_hp -= amount
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if drop_item_scene:
		var drop = drop_item_scene.instantiate()
		drop.global_position = global_position
		get_parent().add_child(drop)

	enemy_defeated.emit(self)
	queue_free()

func _get_active_player() -> Node2D:
	return get_tree().get_first_node_in_group("ActivePlayer")
