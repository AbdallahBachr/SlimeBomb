extends RigidBody2D
class_name BallDragThrow

enum BallType { CYAN, MAGENTA, YELLOW, BOMB }

@export var ball_type: BallType = BallType.CYAN
@export var throw_force_multiplier: float = 3.0

var is_grabbed: bool = false
var is_thrown: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var throw_velocity: Vector2 = Vector2.ZERO
var velocity_history: Array[Vector2] = []  # Pour smooth throw

# Trail effect
var trail_line: Line2D = null
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS = 20

signal ball_scored(points: int)
signal ball_missed()
signal bomb_exploded()

func _ready():
	_setup_visuals()
	_setup_trail()

	# Désactiver la gravité quand on grab
	gravity_scale = 0.3

	# Enable input
	input_event.connect(_on_input_event)

	# Rotation pour le fun
	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-2, 2)

func _setup_visuals():
	var sprite = $Sprite2D if has_node("Sprite2D") else null
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
				# Animation de pulsation SMOOTH
				var tween = create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.5).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)

func _setup_trail():
	# Créer le trail line2D pour l'effet de trainée
	trail_line = Line2D.new()
	trail_line.width = 8.0
	trail_line.default_color = Color(1, 1, 1, 0.6)

	# Gradient pour fade effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0))  # Transparent au début
	gradient.add_point(1.0, Color(1, 1, 1, 0.8))  # Opaque à la fin
	trail_line.width_curve = null
	trail_line.gradient = gradient

	# Couleur selon le type de balle (Color Switch style)
	match ball_type:
		BallType.CYAN:
			trail_line.default_color = Color(0.0, 1.0, 1.0, 0.6)  # Cyan
		BallType.MAGENTA:
			trail_line.default_color = Color(1.0, 0.0, 1.0, 0.6)  # Magenta
		BallType.YELLOW:
			trail_line.default_color = Color(1.0, 1.0, 0.0, 0.6)  # Yellow
		BallType.BOMB:
			trail_line.default_color = Color(0.3, 0.3, 0.3, 0.6)

	# Ajout smooth
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true

	# Ajouter au parent pour éviter rotation
	call_deferred("_add_trail_to_parent")

func _add_trail_to_parent():
	if get_parent():
		get_parent().add_child(trail_line)
		trail_line.z_index = -1  # Derrière la balle

func _on_input_event(viewport: Viewport, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_grab()
			else:
				_release()

func _grab():
	if is_thrown:
		return

	is_grabbed = true

	# Stop physics
	freeze = true

	# Effet visuel
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)

	# Clear trail
	trail_points.clear()
	if trail_line:
		trail_line.visible = true

	last_mouse_pos = get_global_mouse_position()

func _release():
	if not is_grabbed:
		return

	is_grabbed = false
	is_thrown = true

	# Réactiver physics
	freeze = false

	# Fade out trail smoothly
	if trail_line:
		var tween = create_tween()
		tween.tween_property(trail_line, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			if trail_line:
				trail_line.visible = false
				trail_line.modulate.a = 1.0
		)

	# Calculer la vélocité moyenne du throw (SMOOTH!)
	if velocity_history.size() > 0:
		var avg_velocity = Vector2.ZERO
		for v in velocity_history:
			avg_velocity += v
		avg_velocity /= velocity_history.size()
		throw_velocity = avg_velocity * throw_force_multiplier
	else:
		# Fallback si pas d'historique
		var current_mouse_pos = get_global_mouse_position()
		throw_velocity = (current_mouse_pos - last_mouse_pos) * throw_force_multiplier

	velocity_history.clear()

	# Vérifier la direction
	_check_throw_direction(throw_velocity)

	# Appliquer la force
	linear_velocity = throw_velocity

	# Effet visuel
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _check_throw_direction(velocity: Vector2):
	"""Vérifie si le throw est dans la bonne direction"""
	var dir_x = velocity.x

	# Si c'est une bombe, c'est toujours un échec
	if ball_type == BallType.BOMB:
		bomb_exploded.emit()
		_explode()
		return

	# Vérifier direction
	var is_right = dir_x > 100  # Jeté vers la droite
	var is_left = dir_x < -100  # Jeté vers la gauche

	var correct = false
	if ball_type == BallType.CYAN and is_right:
		correct = true
	elif ball_type == BallType.MAGENTA and is_left:
		correct = true
	elif ball_type == BallType.YELLOW and (is_left or is_right):
		correct = true  # Yellow accepté des deux côtés

	if correct:
		ball_scored.emit(10)
		_success_effect()
	else:
		ball_missed.emit()
		_fail_effect()

func _input(event):
	# Écouter le relâchement GLOBAL (même si souris sort de la balle)
	if is_grabbed and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release()

func _process(delta):
	if is_grabbed:
		# Suivre la souris SMOOTHLY
		var target_pos = get_global_mouse_position()
		var prev_pos = global_position
		global_position = global_position.lerp(target_pos, 0.3)  # Plus smooth

		# Calculer vélocité pour le throw
		var velocity = (global_position - prev_pos) / delta
		velocity_history.append(velocity)

		# Garder seulement les 5 derniers frames
		if velocity_history.size() > 5:
			velocity_history.pop_front()

		# Update trail
		_update_trail()

		last_mouse_pos = target_pos

func _update_trail():
	if not trail_line:
		return

	# Ajouter la position actuelle
	trail_points.append(global_position)

	# Limiter le nombre de points
	if trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()

	# Mettre à jour la Line2D
	trail_line.clear_points()
	for point in trail_points:
		trail_line.add_point(point)

func _success_effect():
	if has_node("SuccessParticles"):
		$SuccessParticles.emitting = true

func _fail_effect():
	var sprite = $Sprite2D
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func _explode():
	if has_node("ExplosionParticles"):
		$ExplosionParticles.emitting = true

	if has_node("Sprite2D"):
		$Sprite2D.visible = false

	# Nettoyer le trail
	if trail_line:
		trail_line.queue_free()

	await get_tree().create_timer(0.5).timeout
	queue_free()
