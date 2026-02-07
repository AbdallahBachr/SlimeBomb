extends RigidBody2D
class_name BallDragThrow

enum BallType { CYAN, MAGENTA, YELLOW, BOMB }

@export var ball_type: BallType = BallType.CYAN
@export var throw_speed: float = 1800.0  # Vitesse max du jet
@export var throw_speed_min: float = 600.0  # Vitesse min du jet

var is_grabbed: bool = false
var is_thrown: bool = false

# Throw tracking - on stocke les positions souris avec timestamps
var mouse_positions: Array[Vector2] = []
var mouse_times: Array[float] = []
const MOUSE_HISTORY_DURATION: float = 0.1  # Seulement les 100ms recents

# Trail effect
var trail_line: Line2D = null
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS: int = 25
var trail_fade_timer: float = 0.0
const TRAIL_FADE_DURATION: float = 0.5

# Acceleration pattern (late-game)
var has_accel_pattern: bool = false
var accel_timer: float = 0.0
var base_gravity: float = 0.15

# Wall inversion awareness
var walls_inverted: bool = false

signal ball_scored(points: int)
signal ball_missed()
signal bomb_exploded()

func _ready():
	_setup_visuals()
	_setup_trail()

	input_event.connect(_on_input_event)

	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-1.5, 1.5)

func _setup_visuals():
	var sprite = $Sprite2D if has_node("Sprite2D") else null

	# Remove GlowParticles - no ambient particles on balls
	if has_node("GlowParticles"):
		$GlowParticles.queue_free()

	if sprite:
		match ball_type:
			BallType.CYAN:
				sprite.texture = load("res://assets/ball_cyan_glow.svg")
			BallType.MAGENTA:
				sprite.texture = load("res://assets/ball_magenta_glow.svg")
			BallType.YELLOW:
				sprite.texture = load("res://assets/ball_yellow_glow.svg")
			BallType.BOMB:
				sprite.texture = load("res://assets/bomb_glow.svg")
				var tween = create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.9, 1.9), 0.5).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.5).set_ease(Tween.EASE_IN_OUT)

func _setup_trail():
	trail_line = Line2D.new()
	trail_line.width = 12.0

	# Gradient: transparent -> opaque
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0.7))
	trail_line.gradient = gradient

	# Width curve: thin -> thick
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(1, 1.0))
	trail_line.width_curve = curve

	# Couleur selon le type
	match ball_type:
		BallType.CYAN:
			trail_line.default_color = Color(0.0, 1.0, 1.0, 0.7)
		BallType.MAGENTA:
			trail_line.default_color = Color(1.0, 0.0, 1.0, 0.7)
		BallType.YELLOW:
			trail_line.default_color = Color(1.0, 1.0, 0.0, 0.7)
		BallType.BOMB:
			trail_line.default_color = Color(0.4, 0.4, 0.4, 0.5)

	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true
	trail_line.visible = false

	call_deferred("_add_trail_to_parent")

func _add_trail_to_parent():
	if get_parent():
		get_parent().add_child(trail_line)
		trail_line.z_index = -1

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_grab()

func _input(event):
	if is_grabbed and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release()

func _grab():
	if is_thrown:
		return

	is_grabbed = true
	freeze = true

	# Scale up smooth
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)

	# Reset tracking
	mouse_positions.clear()
	mouse_times.clear()
	trail_points.clear()
	trail_fade_timer = 0.0

	if trail_line:
		trail_line.visible = true
		trail_line.modulate.a = 1.0
		trail_line.clear_points()

func _release():
	if not is_grabbed:
		return

	is_grabbed = false
	is_thrown = true
	freeze = false

	# Calculer la velocite a partir des positions recentes
	var throw_vel = _calculate_throw_velocity()

	# Verifier la direction (avec prise en compte de l'inversion)
	_check_throw_direction(throw_vel)

	# Appliquer - smooth, pas de spike
	linear_velocity = throw_vel
	gravity_scale = 0.0  # Pas de gravite pendant le vol

	# Scale back
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

	# Start trail fade timer
	trail_fade_timer = TRAIL_FADE_DURATION

func _calculate_throw_velocity() -> Vector2:
	if mouse_positions.size() < 2:
		return Vector2.ZERO

	# Prendre le deplacement total sur la periode
	var oldest_pos = mouse_positions[0]
	var newest_pos = mouse_positions[mouse_positions.size() - 1]
	var oldest_time = mouse_times[0]
	var newest_time = mouse_times[mouse_times.size() - 1]

	var dt = newest_time - oldest_time
	if dt < 0.001:
		return Vector2.ZERO

	var direction = (newest_pos - oldest_pos)
	var speed = direction.length() / dt

	# Clamp la vitesse pour eviter les spikes
	speed = clamp(speed, throw_speed_min, throw_speed * 2.0)

	# Normaliser et appliquer la vitesse
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

	# Si murs inversés, on inverse la logique
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
		ball_missed.emit()

func _process(delta):
	var now = Time.get_ticks_msec() / 1000.0

	# Acceleration pattern: sin wave on gravity
	if has_accel_pattern and not is_grabbed and not is_thrown:
		accel_timer += delta
		var wave = sin(accel_timer * 3.0)  # Oscillation ~2s cycle
		gravity_scale = base_gravity * (1.0 + wave * 0.7)  # 0.3x to 1.7x

	if is_grabbed:
		# Suivre la souris smooth
		var target_pos = get_global_mouse_position()
		global_position = global_position.lerp(target_pos, 0.4)

		# Enregistrer positions pour le throw
		mouse_positions.append(get_global_mouse_position())
		mouse_times.append(now)

		# Garder seulement les positions recentes
		while mouse_times.size() > 0 and (now - mouse_times[0]) > MOUSE_HISTORY_DURATION:
			mouse_positions.pop_front()
			mouse_times.pop_front()

		# Update trail
		_update_trail()

	elif is_thrown:
		# La balle vole - continuer le trail
		_update_trail()

		# Fade out progressif du trail
		if trail_fade_timer > 0:
			trail_fade_timer -= delta
			if trail_line:
				trail_line.modulate.a = trail_fade_timer / TRAIL_FADE_DURATION
		elif trail_line and trail_line.visible:
			trail_line.visible = false

func _update_trail():
	if not trail_line or not trail_line.visible:
		return

	# Ajouter la position actuelle
	trail_points.append(global_position)

	# Limiter le nombre de points
	while trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()

	# Mettre a jour la Line2D
	trail_line.clear_points()
	for point in trail_points:
		trail_line.add_point(point)

func _explode():
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

	if trail_line:
		trail_line.queue_free()
		trail_line = null

	await get_tree().create_timer(0.5).timeout
	queue_free()

func _exit_tree():
	# Nettoyer le trail quand la balle est detruite
	if trail_line and is_instance_valid(trail_line):
		trail_line.queue_free()
