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

@export var ball_scene: PackedScene

# Game state
var score: int = 0
var lives: int = 3
var combo: int = 0
var max_combo: int = 0
var balls_thrown: int = 0
var balls_scored: int = 0
var time_elapsed: float = 0.0
var spawn_rate: float = 2.5
var game_over: bool = false
var game_started: bool = false
var last_difficulty_step: int = 0

# Late-game
var walls_inverted: bool = false
var inversion_active: bool = false
var inversion_timer: float = 0.0
const INVERSION_DURATION: float = 15.0
var accel_pattern_chance: float = 0.0
var bomb_chance: float = 0.1
var spawn_burst_active: bool = false

# UI
var warning_label: Label = null
var timer_label: Label = null
var music_player: AudioStreamPlayer = null
var slow_mo_active: bool = false

# Preloaded sounds
var snd_miss: AudioStream
var snd_grab: AudioStream
var snd_tick: AudioStream
var snd_wall_cyan: AudioStream
var snd_wall_magenta: AudioStream

# Wall edge glow
var left_glow: ColorRect = null
var right_glow: ColorRect = null

func _ready():
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	last_difficulty_step = 0

	laser_left.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_right.ball_destroyed.connect(_on_laser_ball_destroyed)

	if kill_zone:
		kill_zone.ball_missed.connect(_on_ball_missed)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

	# Preload sounds once
	snd_miss = load("res://assets/sounds/red_wall.mp3")
	snd_grab = load("res://assets/sounds/blue_wall.mp3")
	snd_tick = load("res://assets/sounds/blue_wall.mp3")
	snd_wall_cyan = load("res://assets/sounds/blue_wall.mp3")
	snd_wall_magenta = load("res://assets/sounds/red_wall.mp3")

	_setup_warning_label()
	_setup_timer_label()
	_setup_wall_glow()
	_start_music()
	_update_ui()

	# Hide game UI during countdown
	score_label.modulate.a = 0.0
	lives_label.modulate.a = 0.0
	pause_button.modulate.a = 0.0
	if timer_label:
		timer_label.modulate.a = 0.0

	_play_countdown()

func _start_music():
	music_player = AudioStreamPlayer.new()
	music_player.stream = load("res://assets/sounds/JoshuaMcLean-MountainTrials.mp3")
	music_player.volume_db = -8.0
	music_player.bus = &"Music"
	add_child(music_player)
	music_player.play()
	music_player.finished.connect(func(): music_player.play())

func _play_countdown():
	var container = CenterContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(container)

	var countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 280)
	countdown_label.custom_minimum_size = Vector2(500, 400)
	countdown_label.pivot_offset = Vector2(250, 200)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(countdown_label)

	var colors = [Color(0, 1, 1, 1), Color(1, 0, 1, 1), Color(1, 1, 0, 1)]
	for i in range(3):
		var num = 3 - i
		countdown_label.text = str(num)
		countdown_label.add_theme_color_override("font_color", colors[i])
		countdown_label.scale = Vector2(2.0, 2.0)
		countdown_label.modulate = Color(1, 1, 1, 1)

		_play_sfx(snd_tick, -12.0)

		var t = create_tween()
		t.tween_property(countdown_label, "scale", Vector2(0.6, 0.6), 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(countdown_label, "modulate:a", 0.0, 0.7)
		await t.finished
		await get_tree().create_timer(0.1).timeout

	# GO!
	countdown_label.text = "GO!"
	countdown_label.add_theme_font_size_override("font_size", 220)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	countdown_label.scale = Vector2(0.3, 0.3)
	countdown_label.modulate = Color(1, 1, 1, 1)
	_play_sfx(snd_tick, -8.0)

	var t = create_tween()
	t.tween_property(countdown_label, "scale", Vector2(1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.1)
	t.tween_interval(0.25)
	t.tween_property(countdown_label, "modulate:a", 0.0, 0.2)
	t.tween_callback(container.queue_free)

	# Fade in game UI
	var ui_t = create_tween().set_parallel(true)
	ui_t.tween_property(score_label, "modulate:a", 1.0, 0.3)
	ui_t.tween_property(lives_label, "modulate:a", 1.0, 0.3)
	ui_t.tween_property(pause_button, "modulate:a", 1.0, 0.3)
	if timer_label:
		ui_t.tween_property(timer_label, "modulate:a", 1.0, 0.3)

	game_started = true
	spawn_timer.start()

func _play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0):
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = &"SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

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
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(warning_label)

func _setup_timer_label():
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.6))
	timer_label.position = Vector2(830, 105)
	timer_label.size = Vector2(180, 35)
	timer_label.text = "0:00"
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(timer_label)

func _setup_wall_glow():
	# Subtle colored glow strips at screen edges to remind players which wall is which
	left_glow = ColorRect.new()
	left_glow.size = Vector2(6, 2600)
	left_glow.position = Vector2(0, -200)
	left_glow.color = Color(1, 0, 1, 0.15)
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_glow.z_index = -50
	add_child(left_glow)

	right_glow = ColorRect.new()
	right_glow.size = Vector2(6, 2600)
	right_glow.position = Vector2(1074, -200)
	right_glow.color = Color(0, 1, 1, 0.15)
	right_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_glow.z_index = -50
	add_child(right_glow)

func _update_wall_glow():
	if not left_glow or not right_glow:
		return
	if walls_inverted:
		left_glow.color = Color(0, 1, 1, 0.15)
		right_glow.color = Color(1, 0, 1, 0.15)
	else:
		left_glow.color = Color(1, 0, 1, 0.15)
		right_glow.color = Color(0, 1, 1, 0.15)

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

	if timer_label:
		var mins = int(time_elapsed) / 60
		var secs = int(time_elapsed) % 60
		timer_label.text = "%d:%02d" % [mins, secs]

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
	_update_wall_glow()
	_show_warning("INVERSION!")
	_flash_screen(Color(1, 0, 1, 0.1))

func _end_wall_inversion():
	walls_inverted = false
	inversion_active = false
	if laser_left:
		laser_left.set_inverted(false)
	if laser_right:
		laser_right.set_inverted(false)
	_update_wall_glow()
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

	ball.position = Vector2(randf_range(150, 930), -100)

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
	ball.gravity_scale = min(grav, 0.8)

	if randf() < accel_pattern_chance:
		ball.has_accel_pattern = true
		ball.base_gravity = ball.gravity_scale
		ball.accel_timer = randf() * TAU

	ball.walls_inverted = walls_inverted
	ball.bomb_exploded.connect(_on_bomb_exploded)

	# Spawn pop: scale from 0
	ball.scale = Vector2(0.0, 0.0)
	add_child(ball)
	var st = create_tween()
	st.tween_property(ball, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Direction indicator arrow
	_spawn_direction_hint(ball)

func _on_laser_ball_destroyed(points: int):
	combo += 1
	balls_scored += 1
	if combo > max_combo:
		max_combo = combo

	var total = int(points * (1.0 + combo * 0.1))
	score += total

	# Combo pitch escalation: higher pitch on longer streaks
	var pitch = min(1.0 + combo * 0.05, 1.8)
	_play_sfx(snd_wall_cyan, -3.0, pitch)

	# Haptic feedback on mobile
	if combo >= 5:
		Input.vibrate_handheld(40)
	else:
		Input.vibrate_handheld(20)

	_update_ui()
	_spawn_score_popup(total)
	_check_milestone()

	if camera:
		if combo >= 10:
			camera.big_shake()
		elif combo >= 5:
			camera.medium_shake()
		else:
			camera.small_shake()

func _check_milestone():
	var milestones = [100, 250, 500, 1000, 2000, 5000]
	for m in milestones:
		if score >= m and (score - int(50 * (1.0 + combo * 0.1))) < m:
			_show_milestone(m)
			return

func _show_milestone(value: int):
	var label = Label.new()
	label.text = str(value) + "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 90)
	label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	label.anchors_preset = Control.PRESET_CENTER
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = 100
	label.offset_bottom = 250
	label.pivot_offset = Vector2(300, 75)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(label)

	label.scale = Vector2(0.3, 0.3)
	var t = create_tween()
	t.tween_property(label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	t.tween_interval(0.8)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)
	_flash_screen(Color(1, 1, 0, 0.08))

	Input.vibrate_handheld(60)

func _spawn_score_popup(points: int):
	var popup = Label.new()
	popup.text = "+" + str(points)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 50)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if combo >= 10:
		popup.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	elif combo >= 5:
		popup.add_theme_color_override("font_color", Color(1, 0, 1, 1))
	else:
		popup.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	popup.position = Vector2(390, 180)
	popup.size = Vector2(300, 60)
	popup.pivot_offset = Vector2(150, 30)
	$CanvasLayer.add_child(popup)

	popup.scale = Vector2(0.5, 0.5)
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
	balls_thrown += 1

	# Miss sound
	_play_sfx(snd_miss, -6.0, 0.7)

	# Haptic feedback
	Input.vibrate_handheld(80)

	if camera:
		camera.medium_shake()

	_update_ui()
	_flash_screen(Color(1, 0, 0, 0.15))

	# Show "-1" miss indicator
	_spawn_miss_indicator()

	# Slow-mo 0.40x on last life
	if lives == 1 and not slow_mo_active:
		slow_mo_active = true
		var t = create_tween()
		t.tween_property(Engine, "time_scale", 0.40, 0.5).set_ease(Tween.EASE_OUT)
		_show_last_life_warning()

	if lives <= 0:
		_game_over()

func _spawn_miss_indicator():
	var miss = Label.new()
	miss.text = "-1"
	miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	miss.add_theme_font_size_override("font_size", 60)
	miss.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	miss.position = Vector2(390, 800)
	miss.size = Vector2(300, 80)
	miss.pivot_offset = Vector2(150, 40)
	miss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(miss)

	miss.scale = Vector2(0.3, 0.3)
	var t = create_tween()
	t.tween_property(miss, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(miss, "scale", Vector2(1.0, 1.0), 0.1)
	t.tween_property(miss, "position:y", miss.position.y - 80, 0.6).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(miss, "modulate:a", 0.0, 0.6)
	t.tween_callback(miss.queue_free)

func _show_last_life_warning():
	var vignette = ColorRect.new()
	vignette.name = "LastLifeVignette"
	vignette.color = Color(1, 0, 0, 0.06)
	vignette.anchors_preset = Control.PRESET_FULL_RECT
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(vignette)

	var pulse = create_tween().set_loops()
	pulse.tween_property(vignette, "color:a", 0.12, 0.8).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(vignette, "color:a", 0.03, 0.8).set_ease(Tween.EASE_IN_OUT)

	_show_warning("LAST LIFE!")

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
	Input.vibrate_handheld(150)
	_play_sfx(snd_miss, -2.0, 0.5)
	_flash_screen(Color(1, 0.3, 0, 0.3))
	_game_over()

func _on_pause_pressed():
	if not game_over:
		pause_menu.show_pause()

func _game_over():
	game_over = true
	spawn_timer.stop()

	if slow_mo_active:
		var t = create_tween()
		t.tween_property(Engine, "time_scale", 1.0, 0.3)
		await t.finished
	Engine.time_scale = 1.0
	slow_mo_active = false

	if $CanvasLayer.has_node("LastLifeVignette"):
		$CanvasLayer.get_node("LastLifeVignette").queue_free()

	# Fade out music
	if music_player:
		var mt = create_tween()
		mt.tween_property(music_player, "volume_db", -40.0, 0.8)

	await get_tree().create_timer(0.8).timeout

	var mins = int(time_elapsed) / 60
	var secs = int(time_elapsed) % 60
	var time_str = "%d:%02d" % [mins, secs]
	var accuracy = 0.0
	if balls_thrown + balls_scored > 0:
		accuracy = float(balls_scored) / float(balls_thrown + balls_scored) * 100.0
	game_over_menu.show_game_over(score, max_combo, time_str, accuracy)

func _update_ui():
	if score_label:
		score_label.text = str(score)
		_animate_label(score_label)

	if lives_label:
		lives_label.text = "I".repeat(max(lives, 0))
		if lives <= 1:
			lives_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
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
	scale_to = min(scale_to, 1.5)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(scale_to, scale_to), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

func _spawn_direction_hint(ball: BallDragThrow):
	if ball.ball_type == BallDragThrow.BallType.BOMB:
		return

	var hint = Label.new()
	hint.add_theme_font_size_override("font_size", 36)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cyan_right = not walls_inverted
	match ball.ball_type:
		BallDragThrow.BallType.CYAN:
			hint.text = ">" if cyan_right else "<"
			hint.add_theme_color_override("font_color", Color(0, 1, 1, 0.5))
		BallDragThrow.BallType.MAGENTA:
			hint.text = "<" if cyan_right else ">"
			hint.add_theme_color_override("font_color", Color(1, 0, 1, 0.5))
		BallDragThrow.BallType.YELLOW:
			hint.text = "<>"
			hint.add_theme_color_override("font_color", Color(1, 1, 0, 0.5))

	hint.position = ball.position + Vector2(-15, -60)
	add_child(hint)

	var t = create_tween()
	t.tween_property(hint, "position:y", hint.position.y - 30, 0.6).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(hint, "modulate:a", 0.0, 0.6)
	t.tween_callback(hint.queue_free)
