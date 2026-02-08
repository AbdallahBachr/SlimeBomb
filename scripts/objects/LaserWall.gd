extends Area2D
class_name LaserWall

enum WallType { CYAN, MAGENTA }

@export var wall_type: WallType = WallType.CYAN

var is_inverted: bool = false
var original_type: WallType

var wall_sound: AudioStream
var particle_sound: AudioStream
var wrong_sound: AudioStream

signal ball_destroyed(points: int)

func _ready():
	original_type = wall_type

	if wall_type == WallType.CYAN:
		wall_sound = load("res://assets/sounds/blue_wall.mp3")
	else:
		wall_sound = load("res://assets/sounds/red_wall.mp3")
	particle_sound = load("res://assets/sounds/particles_short.mp3")
	wrong_sound = load("res://assets/sounds/red_wall.mp3")

	body_entered.connect(_on_body_entered)
	_setup_visuals()

func set_inverted(inverted: bool):
	is_inverted = inverted
	if inverted:
		if original_type == WallType.CYAN:
			wall_type = WallType.MAGENTA
		else:
			wall_type = WallType.CYAN
	else:
		wall_type = original_type
	_setup_visuals()

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

		var match_found = false

		if wall_type == WallType.CYAN and ball.ball_type == BallDragThrow.BallType.CYAN:
			match_found = true
		elif wall_type == WallType.MAGENTA and ball.ball_type == BallDragThrow.BallType.MAGENTA:
			match_found = true
		elif ball.ball_type == BallDragThrow.BallType.YELLOW:
			match_found = true

		if match_found:
			ball_destroyed.emit(50)
			_play_destruction_effect(ball)
			ball.queue_free()
		else:
			_destroy_wrong_ball(ball)

func _play_destruction_effect(ball: BallDragThrow):
	var ball_pos = ball.global_position
	var dir_x = -1.0 if wall_type == WallType.CYAN else 1.0

	_play_sound(wall_sound, ball_pos)

	get_tree().create_timer(0.1).timeout.connect(func():
		_play_sound(particle_sound, ball_pos, -5.0)
	)

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

	for i in range(star_textures.size()):
		var p = _create_explosion_emitter(ball_pos, dir_x, ball_color, star_textures[i])
		get_parent().add_child(p)
		p.emitting = true

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
	particles.finished.connect(particles.queue_free)

	return particles

func _destroy_wrong_ball(ball: BallDragThrow):
	var ball_pos = ball.global_position

	# Wrong wall sound - low-pitched buzz
	_play_sound(wrong_sound, ball_pos, -8.0)

	# Red flash X at impact point
	var x_label = Label.new()
	x_label.text = "X"
	x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_label.add_theme_font_size_override("font_size", 80)
	x_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	x_label.position = ball_pos + Vector2(-25, -50)
	x_label.pivot_offset = Vector2(25, 50)
	x_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(x_label)

	var xt = get_parent().create_tween()
	xt.tween_property(x_label, "scale", Vector2(1.5, 1.5), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	xt.tween_property(x_label, "modulate:a", 0.0, 0.3)
	xt.tween_callback(x_label.queue_free)

	# Ball rejection: shrink + red tint + bounce back
	if ball.has_node("Sprite2D"):
		var sprite = ball.get_node("Sprite2D")
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0), 0.2)
		tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.2)

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(ball):
		ball.queue_free()
