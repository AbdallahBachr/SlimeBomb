extends RigidBody2D
class_name PowerupDrop

enum PowerupType { HEART, SHIELD_WALL, SUPER }

@export var powerup_type: PowerupType = PowerupType.HEART
@export var throw_speed: float = 1600.0
@export var throw_speed_min: float = 500.0

var is_grabbed: bool = false
var is_thrown: bool = false
var grab_offset: Vector2 = Vector2.ZERO
var pre_layer: int = 0
var pre_mask: int = 0
var last_input_pos: Vector2 = Vector2.ZERO
var has_input_pos: bool = false
var last_input_is_touch: bool = false

var mouse_positions: Array[Vector2] = []
var mouse_times: Array[float] = []
const MOUSE_HISTORY_DURATION: float = 0.1

signal powerup_activated(powerup_type: int)

func _ready():
	collision_layer = 1
	collision_mask = 1
	_setup_visual()
	input_event.connect(_on_input_event)
	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-1.0, 1.0)

func _setup_visual():
	if not has_node("Sprite2D"):
		return
	var sprite = $Sprite2D
	var base_scale = Vector2(1.0, 1.0)
	match powerup_type:
		PowerupType.HEART:
			sprite.texture = load("res://assets/heart.svg")
			sprite.scale = base_scale
			sprite.self_modulate = Color(1, 1, 1, 1)
		PowerupType.SHIELD_WALL:
			sprite.texture = load("res://assets/shield.svg")
			sprite.scale = base_scale
			sprite.self_modulate = Color(1, 1, 1, 1)
		PowerupType.SUPER:
			sprite.texture = load("res://assets/Bonus.svg")
			sprite.scale = base_scale
			sprite.self_modulate = Color(1, 1, 1, 1)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if is_grabbed or is_thrown:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			last_input_pos = _screen_to_world(event.position)
			has_input_pos = true
			last_input_is_touch = false
			_grab()
	elif event is InputEventScreenTouch:
		if event.pressed:
			last_input_pos = _screen_to_world(event.position)
			has_input_pos = true
			last_input_is_touch = true
			_grab()

func _input(event):
	if is_grabbed and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release()
	elif is_grabbed and event is InputEventMouseMotion:
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = false
	elif is_grabbed and event is InputEventScreenTouch:
		if not event.pressed:
			_release()
		else:
			last_input_pos = _screen_to_world(event.position)
			has_input_pos = true
			last_input_is_touch = true
	elif is_grabbed and event is InputEventScreenDrag:
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = true

func _grab():
	is_grabbed = true
	freeze = true
	pre_layer = collision_layer
	pre_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	var pointer = _get_pointer_world_pos()
	grab_offset = global_position - pointer
	mouse_positions.clear()
	mouse_times.clear()

func _release():
	if not is_grabbed:
		return
	is_grabbed = false
	is_thrown = true
	freeze = false
	collision_layer = pre_layer
	collision_mask = pre_mask
	var vel = _calculate_throw_velocity()
	if vel.length() < throw_speed_min * 0.6:
		is_thrown = false
		return
	linear_velocity = vel
	gravity_scale = 0.0

func _calculate_throw_velocity() -> Vector2:
	var now = Time.get_ticks_msec() / 1000.0
	mouse_positions.append(_get_pointer_world_pos())
	mouse_times.append(now)
	while mouse_times.size() > 0 and (now - mouse_times[0]) > MOUSE_HISTORY_DURATION:
		mouse_positions.pop_front()
		mouse_times.pop_front()
	if mouse_positions.size() < 2:
		return Vector2.ZERO
	var oldest_pos = mouse_positions[0]
	var newest_pos = mouse_positions[mouse_positions.size() - 1]
	var oldest_time = mouse_times[0]
	var newest_time = mouse_times[mouse_times.size() - 1]
	var dt = newest_time - oldest_time
	if dt < 0.001:
		return Vector2.ZERO
	var direction = (newest_pos - oldest_pos)
	var speed = clamp(direction.length() / dt, throw_speed_min, throw_speed * 2.0)
	if direction.length() > 0:
		return direction.normalized() * speed
	return Vector2.ZERO

func _process(delta):
	if is_grabbed:
		var pointer = _get_pointer_world_pos()
		global_position = global_position.lerp(pointer + grab_offset, 0.4)

func _screen_to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos

func _get_pointer_world_pos() -> Vector2:
	if has_input_pos:
		return last_input_pos
	return get_global_mouse_position()

func apply_wall_hit():
	powerup_activated.emit(powerup_type)
	queue_free()
