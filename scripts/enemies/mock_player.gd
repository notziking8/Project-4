extends CharacterBody2D

var hp: float = 100.0
const UNIT: float = 64.0
@export var speed: float = 4.0 * UNIT # 256 px/s

func _ready() -> void:
	add_to_group("Player")
	add_to_group("ActivePlayer")

func _physics_process(_delta: float) -> void:
	var move_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): move_dir.y -= 1
	if Input.is_key_pressed(KEY_S): move_dir.y += 1
	if Input.is_key_pressed(KEY_A): move_dir.x -= 1
	if Input.is_key_pressed(KEY_D): move_dir.x += 1
	
	velocity = move_dir.normalized() * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Left Click fires spectral bow (25 damage, 10-unit range)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shoot()

func _shoot() -> void:
	var space_state = get_world_2d().direct_space_state
	var max_range = 10.0 * UNIT
	var click_pos = get_global_mouse_position()
	var shoot_dir = (click_pos - global_position).normalized()
	var target_pos = global_position + shoot_dir * minf(global_position.distance_to(click_pos), max_range)

	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	var result = space_state.intersect_ray(query)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(25.0)
		print("Bow hit! Enemy HP left: ", result.collider.current_hp)

func take_damage(amount: float, dmg_type: String, _attacker_pos: Vector2) -> void:
	hp -= amount
	print("Player took ", amount, " ", dmg_type, " damage. Current HP: ", hp)
