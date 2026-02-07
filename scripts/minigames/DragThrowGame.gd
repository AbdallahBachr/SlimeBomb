extends Node2D

# References
@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var lives_label: Label = $CanvasLayer/LivesLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var game_over_menu = $CanvasLayer/GameOverMenu
@onready var laser_left = $LaserWallLeft
@onready var laser_right = $LaserWallRight
@onready var camera: CameraShake = $Camera2D
@onready var kill_zone = $KillZone
@onready var pause_button = $CanvasLayer/PauseButton

# Scene
@export var ball_scene: PackedScene

# Game state
var score: int = 0
var lives: int = 3
var combo: int = 0
var max_combo: int = 0
var time_elapsed: float = 0.0
var spawn_rate: float = 2.5
var game_over: bool = false
var game_started: bool = false
var last_difficulty_step: int = 0

# Late-game variants
var walls_inverted: bool = false
var inversion_active: bool = false
var inversion_timer: float = 0.0
const INVERSION_DURATION: float = 15.0
var accel_pattern_chance: float = 0.0
var bomb_chance: float = 0.1
var spawn_burst_active: bool = false

# Warning label for events
var warning_label: Label = null

# Background music
var music_player: AudioStreamPlayer = null

# Last life slow-mo
var slow_mo_active: bool = false

func _ready():
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	last_difficulty_step = 0

	# Connect laser walls - use new signal with position
	laser_left.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_right.ball_destroyed.connect(_on_laser_ball_destroyed)

	if kill_zone:
		kill_zone.ball_missed.connect(_on_ball_missed)

	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

	_setup_warning_label()
	_start_music()
	_update_ui()

	# Start with countdown
	_play_countdown()

func _start_music():
	music_player = AudioStreamPlayer.new()
	var stream = load("res://assets/sounds/JoshuaMcLean-MountainTrials.mp3")
	music_player.stream = stream
	music_player.volume_db = -8.0
	music_player.bus = &"Music"
	add_child(music_player)
	music_player.play()
	music_player.finished.connect(func(): music_player.play())

func _play_countdown():
	var countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 180)
	countdown_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	countdown_label.anchors_preset = Control.PRESET_CENTER
	countdown_label.offset_left = -200
	countdown_label.offset_right = 200
	countdown_label.offset_top = -150
	countdown_label.offset_bottom = 150
	countdown_label.pivot_offset = Vector2(200, 150)
	$CanvasLayer.add_child(countdown_label)

	for num in [3, 2, 1]:
		countdown_label.text = str(num)
		countdown_label.scale = Vector2(1.5, 1.5)
		countdown_label.modulate = Color(1, 1, 1, 1)

		var t = create_tween()
		t.tween_property(countdown_label, "scale", Vector2(0.8, 0.8), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(countdown_label, "modulate:a", 0.0, 0.6)
		await t.finished
		await get_tree().create_timer(0.15).timeout

	# GO!
	countdown_label.text = "GO!"
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	countdown_label.add_theme_font_size_override("font_size", 140)
	countdown_label.scale = Vector2(0.5, 0.5)
	countdown_label.modulate = Color(1, 1, 1, 1)

	var t = create_tween()
	t.tween_property(countdown_label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.1)
	t.tween_interval(0.3)
	t.tween_property(countdown_label, "modulate:a", 0.0, 0.3)
	t.tween_callback(countdown_label.queue_free)

	# Start the game
	game_started = true
	spawn_timer.start()

func _setup_warning_label():
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 60)
	warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	warning_label.anchors_preset = Control.PRESET_CENTER_TOP
	warning_label.offset_left = -300
	warning_label.offset_right = 300
	warning_label.offset_top = 400
	warning_label.offset_bottom = 500
	warning_label.pivot_offset = Vector2(300, 50)
	warning_label.visible = false
	$CanvasLayer.add_child(warning_label)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if not game_over:
			if pause_menu.visible:
				pause_menu.hide_pause()
			else:
				pause_menu.show_pause()
			return

	if game_over or get_tree().paused or not game_started:
		return

	time_elapsed += delta

	var step = int(time_elapsed / 15.0)
	if step > last_difficulty_step:
		last_difficulty_step = step
		_apply_difficulty_step(step)

	if inversion_active:
		inversion_timer -= delta
		if inversion_timer <= 0:
			_end_wall_inversion()

func _apply_difficulty_step(step: int):
	spawn_rate = max(0.8, spawn_rate - 0.12)
	spawn_timer.wait_time = spawn_rate

	if step >= 3:
		accel_pattern_chance = min(0.4, (step - 2) * 0.08)

	if step >= 4:
		bomb_chance = min(0.2, 0.1 + (step - 3) * 0.02)

	if step >= 5 and not inversion_active and randf() < 0.3:
		_start_wall_inversion()

	if step >= 6 and randf() < 0.25:
		_trigger_spawn_burst()

	if step >= 8 and not inversion_active and randf() < 0.5:
		_start_wall_inversion()

func _start_wall_inversion():
	walls_inverted = true
	inversion_active = true
	inversion_timer = INVERSION_DURATION

	if laser_left:
		laser_left.set_inverted(true)
	if laser_right:
		laser_right.set_inverted(true)

	_show_warning("INVERSION!")

func _end_wall_inversion():
	walls_inverted = false
	inversion_active = false

	if laser_left:
		laser_left.set_inverted(false)
	if laser_right:
		laser_right.set_inverted(false)

	_show_warning("NORMAL")

func _trigger_spawn_burst():
	spawn_burst_active = true
	_show_warning("BURST!")

	var count = randi_range(3, 5)
	for i in range(count):
		_spawn_ball()
		await get_tree().create_timer(0.3).timeout

	spawn_burst_active = false

func _show_warning(text: String):
	if not warning_label:
		return
	warning_label.text = text
	warning_label.visible = true
	warning_label.modulate = Color(1, 1, 1, 1)
	warning_label.scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(warning_label, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(warning_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(warning_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): warning_label.visible = false)

func _spawn_ball():
	if not ball_scene:
		return

	var ball = ball_scene.instantiate() as BallDragThrow
	if not ball:
		return

	var spawn_x = randf_range(150, 930)
	var spawn_y = -100

	ball.position = Vector2(spawn_x, spawn_y)

	var rand = randf()
	if rand < bomb_chance:
		ball.ball_type = BallDragThrow.BallType.BOMB
	elif rand < bomb_chance + 0.3:
		ball.ball_type = BallDragThrow.BallType.CYAN
	elif rand < bomb_chance + 0.6:
		ball.ball_type = BallDragThrow.BallType.MAGENTA
	else:
		ball.ball_type = BallDragThrow.BallType.YELLOW

	var grav = 0.15 + (time_elapsed / 120.0)
	grav = min(grav, 0.8)
	ball.gravity_scale = grav

	if randf() < accel_pattern_chance:
		ball.has_accel_pattern = true
		ball.base_gravity = grav
		ball.accel_timer = randf() * TAU

	ball.walls_inverted = walls_inverted
	ball.bomb_exploded.connect(_on_bomb_exploded)

	add_child(ball)

func _on_laser_ball_destroyed(points: int):
	combo += 1
	if combo > max_combo:
		max_combo = combo

	var multiplier = 1.0 + combo * 0.1
	var total = int(points * multiplier)
	score += total

	# Freeze frame for impact feel (30ms)
	_hit_freeze(0.03)

	_update_ui()

	# Floating score popup at top
	_spawn_score_popup(total)

	# Camera shake scales with combo
	if camera:
		if combo >= 10:
			camera.big_shake()
		elif combo >= 5:
			camera.medium_shake()
		else:
			camera.small_shake()

func _hit_freeze(duration: float):
	# Brief engine freeze for impact feel
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	if not game_over:
		get_tree().paused = false

func _spawn_score_popup(points: int):
	var popup = Label.new()
	popup.text = "+" + str(points)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 50)

	# Color based on combo level
	if combo >= 10:
		popup.add_theme_color_override("font_color", Color(1, 1, 0, 1))  # Gold
	elif combo >= 5:
		popup.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Cyan
	else:
		popup.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	# Position under score
	popup.position = Vector2(390, 180)
	popup.size = Vector2(300, 60)
	popup.pivot_offset = Vector2(150, 30)

	$CanvasLayer.add_child(popup)

	# Animate: pop up and fade
	popup.scale = Vector2(0.5, 0.5)
	popup.modulate.a = 1.0

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.1, 1.1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(popup, "position:y", popup.position.y - 60, 0.8).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_property(popup, "modulate:a", 0.0, 0.4)
	t.tween_callback(popup.queue_free)

func _on_ball_missed():
	lives -= 1
	combo = 0

	if camera:
		camera.medium_shake()

	_update_ui()

	# Flash screen red briefly
	_flash_screen(Color(1, 0, 0, 0.15))

	# Slow-mo on last life
	if lives == 1 and not slow_mo_active:
		slow_mo_active = true
		Engine.time_scale = 0.7

	if lives <= 0:
		_game_over()

func _flash_screen(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(flash)

	var t = create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)

func _on_bomb_exploded():
	if camera:
		camera.big_shake()
	_flash_screen(Color(1, 0.3, 0, 0.3))
	_game_over()

func _on_pause_pressed():
	if not game_over:
		pause_menu.show_pause()

func _game_over():
	game_over = true
	spawn_timer.stop()

	# Reset slow-mo
	Engine.time_scale = 1.0
	slow_mo_active = false

	await get_tree().create_timer(1.0).timeout
	game_over_menu.show_game_over(score, max_combo)

func _update_ui():
	if score_label:
		score_label.text = str(score)
		_animate_label(score_label)

	if lives_label:
		lives_label.text = "I".repeat(max(lives, 0))
		if lives <= 1:
			lives_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
			# Pulse animation on last life
			if lives == 1:
				var pulse = create_tween().set_loops(3)
				pulse.tween_property(lives_label, "scale", Vector2(1.3, 1.3), 0.15)
				pulse.tween_property(lives_label, "scale", Vector2(1.0, 1.0), 0.15)
		else:
			lives_label.add_theme_color_override("font_color", Color(1, 0, 1, 0.6))

	if combo_label:
		if combo > 1:
			combo_label.text = "x" + str(combo)
			combo_label.visible = true

			# Combo color escalation
			if combo >= 10:
				combo_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
			elif combo >= 5:
				combo_label.add_theme_color_override("font_color", Color(1, 0, 1, 1))
			else:
				combo_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))

			_animate_label(combo_label, 1.2 + combo * 0.02)
		else:
			combo_label.visible = false

func _animate_label(label: Label, scale_to: float = 1.15):
	scale_to = min(scale_to, 1.5)  # Cap max scale
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(scale_to, scale_to), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
