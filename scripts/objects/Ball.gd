extends RigidBody2D
class_name Ball

enum BallType { GREEN, RED, BOMB }

@export var ball_type: BallType = BallType.GREEN
@export var swipe_force: float = 2000.0  # Augmenté pour être plus visible
@export var upward_boost: float = -500.0  # Augmenté pour être plus visible

var is_swiped: bool = false
var particle_scene: PackedScene

signal ball_swiped_correctly(points: int)
signal ball_swiped_wrong()
signal bomb_touched()

func _ready():
	# Setup visual selon le type
	_setup_visuals()

	# Connect au body_entered pour détecter collision avec KillZone
	body_entered.connect(_on_body_entered)

	# Rotation aléatoire pour le fun
	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-3, 3)

func _setup_visuals():
	var sprite = $Sprite2D if has_node("Sprite2D") else null
	var collision = $CollisionShape2D if has_node("CollisionShape2D") else null

	if sprite:
		match ball_type:
			BallType.GREEN:
				sprite.self_modulate = Color(0.2, 1.0, 0.3)  # Vert éclatant
			BallType.RED:
				sprite.self_modulate = Color(1.0, 0.2, 0.2)  # Rouge vif
			BallType.BOMB:
				sprite.self_modulate = Color(0.1, 0.1, 0.1)  # Noir
				# Ajouter une petite animation de pulsation pour la bombe
				var tween = create_tween().set_loops()
				tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.5)
				tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5)

func handle_swipe(swipe_direction: Vector2):
	"""
	Gère le swipe sur cette balle
	swipe_direction: vecteur normalisé de la direction du swipe
	"""
	print("🎯 Ball touched! Type: ", ball_type, " Direction: ", swipe_direction)

	if is_swiped:
		return  # Déjà swipée

	is_swiped = true

	# Si c'est une BOMBE → GAME OVER !
	if ball_type == BallType.BOMB:
		_explode()
		bomb_touched.emit()
		return

	# Vérifier si le swipe est dans la bonne direction
	var is_swipe_right = swipe_direction.x > 0.3
	var is_swipe_left = swipe_direction.x < -0.3

	var correct_swipe = false

	if ball_type == BallType.GREEN and is_swipe_right:
		correct_swipe = true
	elif ball_type == BallType.RED and is_swipe_left:
		correct_swipe = true

	if correct_swipe:
		# CORRECT ! Appliquer la force
		var impulse_direction = Vector2(swipe_direction.x * swipe_force, upward_boost)
		apply_central_impulse(impulse_direction)

		# Effet visuel de succès
		_spawn_success_particles()
		_flash_success()

		# Points
		var points = _calculate_points()
		ball_swiped_correctly.emit(points)

		# Détruire après un délai
		await get_tree().create_timer(2.0).timeout
		queue_free()
	else:
		# MAUVAIS SWIPE
		ball_swiped_wrong.emit()
		_flash_wrong()
		# Quand même appliquer une petite force pour le feedback
		apply_central_impulse(swipe_direction * swipe_force * 0.3)

func _calculate_points() -> int:
	# Plus la balle est haute, plus de points (récompense la rapidité)
	var screen_height = get_viewport_rect().size.y
	var height_ratio = 1.0 - (global_position.y / screen_height)
	var base_points = 10
	var bonus = int(height_ratio * 20)  # Jusqu'à +20 points
	return base_points + bonus

func _spawn_success_particles():
	# Particules de succès
	if has_node("SuccessParticles"):
		$SuccessParticles.emitting = true

func _flash_success():
	# Flash blanc pour feedback instantané
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var original_modulate = sprite.self_modulate
		sprite.self_modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(sprite, "self_modulate", original_modulate, 0.2)

func _flash_wrong():
	# Flash rouge pour mauvais swipe
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var original_modulate = sprite.self_modulate
		sprite.self_modulate = Color(1, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "self_modulate", original_modulate, 0.3)

func _explode():
	# Explosion de la bombe - EFFET DRAMATIQUE
	if has_node("ExplosionParticles"):
		$ExplosionParticles.emitting = true

	# Screen shake sera géré par le SwipeGame

	# Cacher la balle mais garder les particules
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

	# Détruire après l'explosion
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _on_body_entered(body):
	# Si touche le sol sans être swipée → perte de vie
	if body.is_in_group("killzone") and not is_swiped and ball_type != BallType.BOMB:
		# Émettre signal de perte
		ball_swiped_wrong.emit()
		queue_free()
