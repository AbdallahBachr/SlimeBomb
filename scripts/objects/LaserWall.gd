extends Area2D
class_name LaserWall

enum WallType { CYAN, MAGENTA }

@export var wall_type: WallType = WallType.CYAN

signal ball_destroyed(points: int)

func _ready():
	# Connecter le signal de collision
	body_entered.connect(_on_body_entered)

	# Setup visuals selon le type
	_setup_visuals()

func _setup_visuals():
	var sprite = $Sprite2D if has_node("Sprite2D") else null
	if sprite:
		match wall_type:
			WallType.CYAN:
				sprite.texture = load("res://assets/laser_cyan.svg")
			WallType.MAGENTA:
				sprite.texture = load("res://assets/laser_magenta.svg")

func _on_body_entered(body):
	if body is BallDragThrow:
		var ball = body as BallDragThrow

		# Vérifier si la balle correspond au mur
		var match_found = false

		if wall_type == WallType.CYAN and ball.ball_type == BallDragThrow.BallType.CYAN:
			match_found = true
		elif wall_type == WallType.MAGENTA and ball.ball_type == BallDragThrow.BallType.MAGENTA:
			match_found = true
		elif ball.ball_type == BallDragThrow.BallType.YELLOW:
			match_found = true  # Yellow accepté partout

		if match_found:
			# SUCCESS ! Détruire la balle et donner des points
			ball_destroyed.emit(50)

			# Effet visuel de succès
			_play_destruction_effect(ball)

			# Détruire la balle
			ball.queue_free()
		else:
			# Mauvaise couleur, détruire la balle avec effet d'échec
			_destroy_wrong_ball(ball)

func _play_destruction_effect(ball: BallDragThrow):
	# Créer des particules à la position de la balle
	var particles = GPUParticles2D.new()
	particles.position = ball.global_position
	particles.emitting = false
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0

	# Material des particules
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1 if wall_type == WallType.CYAN else 1, 0, 0)
	material.spread = 60.0
	material.initial_velocity_min = 200.0
	material.initial_velocity_max = 400.0
	material.gravity = Vector3(0, 300, 0)
	material.scale_min = 1.0
	material.scale_max = 2.0

	# Couleur selon le type de laser (Color Switch style)
	if wall_type == WallType.CYAN:
		material.color = Color(0.0, 1.0, 1.0, 1.0)  # Cyan néon
	else:
		material.color = Color(1.0, 0.0, 1.0, 1.0)  # Magenta néon

	particles.process_material = material

	# Ajouter au monde
	get_parent().add_child(particles)
	particles.emitting = true

	# Détruire après l'animation
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _destroy_wrong_ball(ball: BallDragThrow):
	# Mauvaise couleur = destruction immédiate sans points
	# Effet visuel rapide de rejet
	if ball.has_node("Sprite2D"):
		var sprite = ball.get_node("Sprite2D")
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.15)
		tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.15)

	await get_tree().create_timer(0.15).timeout
	ball.queue_free()
