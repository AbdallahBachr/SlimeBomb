extends Node2D
class_name SwipeInputManager

signal swipe_detected(position: Vector2, direction: Vector2, velocity: float)

@export var min_swipe_distance: float = 50.0  # Pixels minimum pour détecter un swipe
@export var max_swipe_time: float = 0.5  # Temps max pour un swipe (secondes)

var touch_start_pos: Vector2 = Vector2.ZERO
var touch_current_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
var touch_trail: Array[Vector2] = []  # Pour détecter la direction moyenne

func _ready():
	# Rien de spécial
	pass

func _input(event):
	# Gestion du tactile ET de la souris (pour testing sur PC)
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	# Support souris pour le développement
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_touch(event.position)
			else:
				_end_touch(event.position)
	elif event is InputEventMouseMotion and is_touching:
		_update_touch(event.position)

func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		_start_touch(event.position)
	else:
		_end_touch(event.position)

func _handle_drag(event: InputEventScreenDrag):
	_update_touch(event.position)

func _start_touch(pos: Vector2):
	is_touching = true
	# Convertir position écran en position monde IMMÉDIATEMENT
	var world_pos = _screen_to_world(pos)
	touch_start_pos = world_pos
	touch_current_pos = world_pos
	touch_start_time = Time.get_ticks_msec() / 1000.0
	touch_trail.clear()
	touch_trail.append(world_pos)

func _update_touch(pos: Vector2):
	if is_touching:
		# Convertir position écran en position monde
		var world_pos = _screen_to_world(pos)
		touch_current_pos = world_pos
		touch_trail.append(world_pos)

		# Limiter la taille du trail
		if touch_trail.size() > 10:
			touch_trail.pop_front()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convertit une position écran en position monde"""
	# Maintenant qu'on est un Node2D, on peut utiliser get_global_mouse_position()
	# qui donne directement la position dans le monde 2D
	return get_global_mouse_position()

func _end_touch(pos: Vector2):
	if not is_touching:
		return

	is_touching = false
	touch_current_pos = pos

	var swipe_vector = touch_current_pos - touch_start_pos
	var swipe_distance = swipe_vector.length()
	var swipe_time = (Time.get_ticks_msec() / 1000.0) - touch_start_time

	# Vérifier si c'est un swipe valide
	if swipe_distance >= min_swipe_distance and swipe_time <= max_swipe_time:
		var swipe_direction = swipe_vector.normalized()
		var swipe_velocity = swipe_distance / max(swipe_time, 0.01)  # Pixels/seconde

		print("👆 SWIPE DETECTED! Distance: ", swipe_distance, " Direction: ", swipe_direction)

		# Émettre le signal
		swipe_detected.emit(touch_start_pos, swipe_direction, swipe_velocity)

		# Vérifier si on a touché une balle
		_check_ball_hit(touch_start_pos, swipe_direction)
	else:
		print("❌ Swipe trop court ou trop lent. Distance: ", swipe_distance, " (min: ", min_swipe_distance, ")")

func _check_ball_hit(start_pos: Vector2, direction: Vector2):
	"""
	Vérifie si le swipe a touché une balle
	"""
	var space_state = get_viewport().get_world_2d().direct_space_state

	print("🔍 Checking ", touch_trail.size(), " positions for ball hit...")

	# On fait plusieurs raycasts le long du trail pour être sûr
	# Les positions sont déjà en coordonnées monde !
	for world_pos in touch_trail:
		print("📍 World pos: ", world_pos)

		var query = PhysicsPointQueryParameters2D.new()
		query.position = world_pos
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = 1  # Layer 1 (default pour RigidBody2D)

		var result = space_state.intersect_point(query, 1)

		# Debug: voir ce qu'on trouve
		if result.size() > 0:
			print("🔎 Found object: ", result[0].collider.name, " Type: ", result[0].collider.get_class())
			var collider = result[0].collider
			if collider is Ball:
				# On a touché une balle !
				print("✅ BALL FOUND at position: ", world_pos)
				collider.handle_swipe(direction)
				return  # Une seule balle par swipe

	print("❌ No ball found in trail")

func get_swipe_direction_name(direction: Vector2) -> String:
	"""
	Retourne le nom de la direction du swipe (pour debug)
	"""
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			return "RIGHT"
		else:
			return "LEFT"
	else:
		if direction.y > 0:
			return "DOWN"
		else:
			return "UP"
