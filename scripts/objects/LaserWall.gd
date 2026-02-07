extends Area2D
class_name LaserWall

enum WallType { CYAN, MAGENTA }

@export var wall_type: WallType = WallType.CYAN

var is_inverted: bool = false
var original_type: WallType

var wall_sound: AudioStream
var particle_sound: AudioStream

signal ball_destroyed(points: int)

func _ready():
	original_type = wall_type

	# Load sounds
	if wall_type == WallType.CYAN:
		wall_sound = load("res://assets/sounds/blue_wall.mp3")
	else:
		wall_sound = load("res://assets/sounds/red_wall.mp3")
	particle_sound = load("res://assets/sounds/particles_short.mp3")

	# Connecter le signal de collision
	body_entered.connect(_on_body_entered)

	# Setup visuals selon le type
	_setup_visuals()

func set_inverted(inverted: bool):
	is_inverted = inverted
	if inverted:
		# Swap visual: CYAN becomes MAGENTA and vice versa
		if original_type == WallType.CYAN:
			wall_type = WallType.MAGENTA
		else:
			wall_type = WallType.CYAN
	else:
		wall_type = original_type
	_setup_visuals()

	# Flash animation on swap
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.3)

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

		# Vérifier si la balle correspond au mur (current type, not original)
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
	var ball_pos = ball.global_position
	var dir_x = -1.0 if wall_type == WallType.CYAN else 1.0

	# Wall hit sound
	_play_sound(wall_sound, ball_pos)

	# Particle sound slightly delayed
	get_tree().create_timer(0.1).timeout.connect(func():
		_play_sound(particle_sound, ball_pos, -5.0)
	)

	# Couleur selon le type de balle
	var ball_color = Color(0, 1, 1, 1)
	match ball.ball_type:
		BallDragThrow.BallType.CYAN:
			ball_color = Color(0, 1, 1, 1)
		BallDragThrow.BallType.MAGENTA:
			ball_color = Color(1, 0, 1, 1)
		BallDragThrow.BallType.YELLOW:
			ball_color = Color(1, 1, 0, 1)

	var star_textures = [
		load("res://assets/particles/star4.svg"),
		load("res://assets/particles/star6.svg"),
		load("res://assets/particles/cross_diamond.svg"),
	]

	# Colored star explosions (3 emitters)
	for i in range(star_textures.size()):
		var p = _create_explosion_emitter(ball_pos, dir_x, ball_color, star_textures[i])
		get_parent().add_child(p)
		p.emitting = true

	# White star explosions (3 emitters)
	for i in range(star_textures.size()):
		var p = _create_explosion_emitter(ball_pos, dir_x, Color(1, 1, 1, 1), star_textures[i])
		get_parent().add_child(p)
		p.emitting = true

func _play_sound(stream: AudioStream, pos: Vector2, volume_db: float = 0.0):
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.position = pos
	player.bus = &"SFX"
	get_parent().add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _create_explosion_emitter(pos: Vector2, dir_x: float, color: Color, tex: Texture2D) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.amount = 8
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.texture = tex

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(dir_x, 0, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = 250.0
	mat.initial_velocity_max = 500.0
	mat.gravity = Vector3(0, 250, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.5
	mat.color = color
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.particle_flag_disable_z = true

	particles.process_material = mat

	# Auto-cleanup
	particles.finished.connect(particles.queue_free)

	return particles

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
