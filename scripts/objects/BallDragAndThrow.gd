extends RigidBody2D
class_name BallDragThrow

enum BallType { CYAN, MAGENTA, YELLOW, BOMB }

@export var ball_type: BallType = BallType.CYAN
@export var throw_speed: float = 1800.0
@export var throw_speed_min: float = 600.0

var is_grabbed: bool = false
var is_thrown: bool = false
var miss_emitted: bool = false
var is_releasing: bool = false
var super_mode: bool = false
var auto_directed: bool = false

# Throw tracking
var mouse_positions: Array[Vector2] = []
var mouse_times: Array[float] = []
const MOUSE_HISTORY_DURATION: float = 0.1

# Trail effect - multi-layer neon
var trail_line: Line2D = null
var trail_glow: Line2D = null
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 35
var trail_fade_timer: float = 0.0
const TRAIL_FADE_DURATION: float = 0.6

# Acceleration pattern (late-game)
var has_accel_pattern: bool = false
var accel_timer: float = 0.0
var base_gravity: float = 0.15

# Wall inversion awareness
var walls_inverted: bool = false

# Input tracking (touch + mouse)
var last_input_pos: Vector2 = Vector2.ZERO
var has_input_pos: bool = false
var last_input_is_touch: bool = false
var last_screen_pos: Vector2 = Vector2.ZERO
var grab_offset: Vector2 = Vector2.ZERO
var pre_grab_collision_layer: int = 0
var pre_grab_collision_mask: int = 0
var pre_grab_gravity: float = 0.0

# Timing
var spawn_time: float = 0.0
var throw_time: float = -1.0

# Preloaded sounds
var snd_grab: AudioStream
var snd_throw: AudioStream

signal ball_scored(points: int)
signal ball_missed()
signal bomb_exploded()

func _ready():
	spawn_time = Time.get_ticks_msec() / 1000.0
	snd_grab = load("res://assets/sounds/blue_wall.mp3")
	snd_throw = load("res://assets/sounds/red_wall.mp3")

	_setup_visuals()
	_setup_trail()

	input_event.connect(_on_input_event)

	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-1.5, 1.5)

func _setup_visuals():
	var sprite = $Sprite2D if has_node("Sprite2D") else null
	var glow = $Glow if has_node("Glow") else null

	if has_node("GlowParticles"):
		$GlowParticles.queue_free()

	if sprite:
		match ball_type:
			BallType.CYAN:
				sprite.texture = load("res://assets/ball_cyan_glow.svg")
				if glow:
					glow.texture = sprite.texture
					_setup_glow_material(glow, Color(0, 1, 1, 0.35))
			BallType.MAGENTA:
				sprite.texture = load("res://assets/ball_magenta_glow.svg")
				if glow:
					glow.texture = sprite.texture
					_setup_glow_material(glow, Color(1, 0, 1, 0.35))
			BallType.YELLOW:
				sprite.texture = load("res://assets/ball_yellow_glow.svg")
				if glow:
					glow.texture = sprite.texture
					_setup_glow_material(glow, Color(1, 1, 0, 0.35))
			BallType.BOMB:
				sprite.texture = load("res://assets/bomb_glow.svg")
				if glow:
					glow.texture = sprite.texture
					_setup_glow_material(glow, Color(1, 0.2, 0.2, 0.35))
				var tween = create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.9, 1.9), 0.5).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.5).set_ease(Tween.EASE_IN_OUT)

func hit_flash(color: Color):
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var original = sprite.self_modulate
		sprite.self_modulate = color
		var t = create_tween()
		t.tween_property(sprite, "self_modulate", original, 0.12)
	if has_node("Glow"):
		var glow = $Glow
		var t2 = create_tween()
		t2.tween_property(glow, "scale", glow.scale * 1.08, 0.08).set_ease(Tween.EASE_OUT)
		t2.tween_property(glow, "scale", glow.scale, 0.12).set_ease(Tween.EASE_IN_OUT)

func _setup_glow_material(glow: Sprite2D, col: Color):
	var mat = glow.material
	if not mat or not (mat is ShaderMaterial):
		var shader = load("res://assets/shaders/ball_glow.gdshader")
		var sm = ShaderMaterial.new()
		sm.shader = shader
		glow.material = sm
		mat = sm
	var smat = mat as ShaderMaterial
	smat.set_shader_parameter("glow_color", col)
	smat.set_shader_parameter("intensity", 1.25)
	smat.set_shader_parameter("pulse_speed", 2.0)
	smat.set_shader_parameter("pulse_strength", 0.22)

func _get_ball_color() -> Color:
	match ball_type:
		BallType.CYAN:
			return Color(0.0, 1.0, 1.0, 1.0)
		BallType.MAGENTA:
			return Color(1.0, 0.0, 1.0, 1.0)
		BallType.YELLOW:
			return Color(1.0, 1.0, 0.0, 1.0)
		BallType.BOMB:
			return Color(1.0, 0.2, 0.2, 1.0)
	return Color.WHITE

func _setup_trail():
	var ball_color = _get_ball_color()

	# Outer glow layer (wide, soft)
	trail_glow = Line2D.new()
	trail_glow.width = 28.0
	trail_glow.z_index = -2

	var glow_gradient = Gradient.new()
	glow_gradient.set_color(0, Color(ball_color.r, ball_color.g, ball_color.b, 0))
	glow_gradient.set_color(1, Color(ball_color.r, ball_color.g, ball_color.b, 0.25))
	trail_glow.gradient = glow_gradient

	var glow_curve = Curve.new()
	glow_curve.add_point(Vector2(0, 0.1))
	glow_curve.add_point(Vector2(0.5, 0.6))
	glow_curve.add_point(Vector2(1, 1.0))
	trail_glow.width_curve = glow_curve
	trail_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_glow.antialiased = true
	trail_glow.visible = false

	# Inner core trail (thin, bright)
	trail_line = Line2D.new()
	trail_line.width = 10.0
	trail_line.z_index = -1

	var core_gradient = Gradient.new()
	var bright = Color(
		lerp(ball_color.r, 1.0, 0.5),
		lerp(ball_color.g, 1.0, 0.5),
		lerp(ball_color.b, 1.0, 0.5),
		0
	)
	var bright_end = Color(bright.r, bright.g, bright.b, 0.9)
	core_gradient.set_color(0, bright)
	core_gradient.set_color(1, bright_end)
	trail_line.gradient = core_gradient

	var core_curve = Curve.new()
	core_curve.add_point(Vector2(0, 0.1))
	core_curve.add_point(Vector2(0.6, 0.5))
	core_curve.add_point(Vector2(1, 1.0))
	trail_line.width_curve = core_curve
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true
	trail_line.visible = false

	call_deferred("_add_trail_to_parent")

func _add_trail_to_parent():
	if get_parent():
		get_parent().add_child(trail_glow)
		get_parent().add_child(trail_line)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if is_grabbed or is_thrown or is_releasing:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			last_screen_pos = event.position
			last_input_pos = _screen_to_world(event.position)
			has_input_pos = true
			last_input_is_touch = false
			_grab()
	elif event is InputEventScreenTouch:
		last_screen_pos = event.position
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = true
		if event.pressed:
			_grab()

func _input(event):
	if is_grabbed and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release()
	elif is_grabbed and event is InputEventMouseMotion:
		last_screen_pos = event.position
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = false
	elif is_grabbed and event is InputEventScreenTouch:
		last_screen_pos = event.position
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = true
		if not event.pressed:
			_release()
	elif is_grabbed and event is InputEventScreenDrag:
		last_screen_pos = event.position
		last_input_pos = _screen_to_world(event.position)
		has_input_pos = true
		last_input_is_touch = true

func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0):
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = &"SFX"
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _grab():
	if is_thrown:
		return

	is_grabbed = true
	freeze = true
	pre_grab_collision_layer = collision_layer
	pre_grab_collision_mask = collision_mask
	pre_grab_gravity = gravity_scale
	collision_layer = 0
	collision_mask = 0
	gravity_scale = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	var pointer_pos = _get_pointer_world_pos()
	grab_offset = global_position - pointer_pos

	_play_sfx(snd_grab, -18.0, 1.5)
	Input.vibrate_handheld(12)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)

	mouse_positions.clear()
	mouse_times.clear()
	trail_points.clear()
	trail_fade_timer = 0.0

	if trail_line:
		trail_line.visible = true
		trail_line.modulate.a = 1.0
		trail_line.clear_points()
	if trail_glow:
		trail_glow.visible = true
		trail_glow.modulate.a = 1.0
		trail_glow.clear_points()

func _release():
	if not is_grabbed:
		return

	is_grabbed = false
	is_thrown = true
	is_releasing = true
	freeze = false
	collision_layer = pre_grab_collision_layer
	collision_mask = pre_grab_collision_mask
	throw_time = Time.get_ticks_msec() / 1000.0

	var throw_vel = _calculate_throw_velocity()
	var min_throw = throw_speed_min * 0.6
	if throw_vel.length() < min_throw or abs(throw_vel.x) < 120.0:
		# Cancel throw if too short (prevents double-click vanish)
		is_thrown = false
		is_releasing = false
		gravity_scale = pre_grab_gravity
		linear_velocity = Vector2.ZERO
		return

	var speed_ratio = throw_vel.length() / (throw_speed * 2.0)
	_play_sfx(snd_throw, -14.0, 0.8 + speed_ratio * 0.6)
	_boost_trail_for_speed(speed_ratio)
	Input.vibrate_handheld(20)

	_check_throw_direction(throw_vel)

	linear_velocity = throw_vel
	gravity_scale = 0.0

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

	trail_fade_timer = TRAIL_FADE_DURATION
	is_releasing = false

func _calculate_throw_velocity() -> Vector2:
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
	var speed = direction.length() / dt

	speed = clamp(speed, throw_speed_min, throw_speed * 2.0)

	if direction.length() > 0:
		return direction.normalized() * speed
	return Vector2.ZERO

func _check_throw_direction(velocity: Vector2):
	var dir_x = velocity.x

	if ball_type == BallType.BOMB:
		bomb_exploded.emit()
		_explode()
		return

	var is_right = dir_x > 50
	var is_left = dir_x < -50

	var cyan_goes_right = not walls_inverted
	var magenta_goes_left = not walls_inverted

	var correct = false
	if ball_type == BallType.CYAN:
		if cyan_goes_right and is_right:
			correct = true
		elif not cyan_goes_right and is_left:
			correct = true
	elif ball_type == BallType.MAGENTA:
		if magenta_goes_left and is_left:
			correct = true
		elif not magenta_goes_left and is_right:
			correct = true
	elif ball_type == BallType.YELLOW and (is_left or is_right):
		correct = true

	if correct:
		ball_scored.emit(10)
	else:
		_emit_miss()
		_discard_wrong_throw()

func _emit_miss():
	if miss_emitted:
		return
	miss_emitted = true
	ball_missed.emit()

func mark_missed():
	_emit_miss()

func _process(delta):
	var now = Time.get_ticks_msec() / 1000.0

	if has_accel_pattern and not is_grabbed and not is_thrown:
		accel_timer += delta
		var wave = sin(accel_timer * 3.0)
		gravity_scale = base_gravity * (1.0 + wave * 0.7)

	if is_grabbed:
		var target_pos = _get_pointer_world_pos()
		target_pos += grab_offset
		global_position = global_position.lerp(target_pos, 0.4)

		mouse_positions.append(target_pos)
		mouse_times.append(now)

		while mouse_times.size() > 0 and (now - mouse_times[0]) > MOUSE_HISTORY_DURATION:
			mouse_positions.pop_front()
			mouse_times.pop_front()

		_update_trail()

	elif is_thrown:
		_update_trail()

		if trail_fade_timer > 0:
			trail_fade_timer -= delta
			var alpha = trail_fade_timer / TRAIL_FADE_DURATION
			if trail_line:
				trail_line.modulate.a = alpha
			if trail_glow:
				trail_glow.modulate.a = alpha
		elif trail_line and trail_line.visible:
			trail_line.visible = false
			if trail_glow:
				trail_glow.visible = false

		_check_out_of_bounds()

	if super_mode and ball_type != BallType.BOMB:
		_animate_super_colors()

func _update_trail():
	if not trail_line:
		return

	trail_points.append(global_position)

	while trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()

	trail_line.clear_points()
	if trail_glow:
		trail_glow.clear_points()

	for point in trail_points:
		trail_line.add_point(point)
		if trail_glow:
			trail_glow.add_point(point)

func _animate_super_colors():
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var h = fmod(Time.get_ticks_msec() / 1000.0 + float(get_instance_id()) * 0.001, 1.0)
		sprite.self_modulate = Color.from_hsv(h, 0.9, 1.0)
	if has_node("Glow"):
		var glow = $Glow
		var h2 = fmod(Time.get_ticks_msec() / 1000.0 + float(get_instance_id()) * 0.001 + 0.2, 1.0)
		glow.self_modulate = Color.from_hsv(h2, 0.8, 1.0, 0.6)

func _boost_trail_for_speed(speed_ratio: float):
	if not trail_line:
		return
	var r = clamp(speed_ratio, 0.2, 1.0)
	trail_line.width = lerp(8.0, 14.0, r)
	if trail_glow:
		trail_glow.width = lerp(22.0, 34.0, r)

func _screen_to_world(pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pos

func _get_pointer_world_pos() -> Vector2:
	if has_input_pos:
		return last_input_pos
	return get_global_mouse_position()

func _check_out_of_bounds():
	var view = get_viewport_rect().size
	var margin = 240.0
	if global_position.y > view.y + margin or global_position.x < -margin or global_position.x > view.x + margin:
		if ball_type != BallType.BOMB:
			_emit_miss()
		queue_free()

func _discard_wrong_throw():
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO

	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0), 0.18)
		tween.tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.18)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func get_time_since_throw() -> float:
	if throw_time < 0.0:
		return -1.0
	return (Time.get_ticks_msec() / 1000.0) - throw_time

func _explode():
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

	if trail_line:
		trail_line.queue_free()
		trail_line = null
	if trail_glow:
		trail_glow.queue_free()
		trail_glow = null

	await get_tree().create_timer(0.5).timeout
	queue_free()

func _exit_tree():
	if trail_line and is_instance_valid(trail_line):
		trail_line.queue_free()
	if trail_glow and is_instance_valid(trail_glow):
		trail_glow.queue_free()
