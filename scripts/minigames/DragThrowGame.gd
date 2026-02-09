extends Node2D

# References
@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var game_over_menu = $CanvasLayer/GameOverMenu
@onready var laser_left = $LaserWallLeft
@onready var laser_right = $LaserWallRight
@onready var camera: CameraShake = $Camera2D
@onready var kill_zone = $KillZone
@onready var pause_button = $CanvasLayer/PauseButton
@onready var warning_left = $WarningLeft
@onready var warning_right = $WarningRight
@onready var streak_bar: ProgressBar = $CanvasLayer/StreakBar
@onready var streak_label: Label = $CanvasLayer/StreakLabel
@onready var background: ColorRect = $Background
@onready var scanlines: ColorRect = $Scanlines

@export var ball_scene: PackedScene
@export var powerup_scene: PackedScene

# Game state
var score: int = 0
var lives: int = 3
var combo: int = 0
var max_combo: int = 0
var balls_thrown: int = 0
var balls_scored: int = 0
var time_elapsed: float = 0.0
var spawn_rate: float = 1.8
var game_over: bool = false
var game_started: bool = false
var last_difficulty_step: int = 0

# Late-game
var walls_inverted: bool = false
var inversion_active: bool = false
var inversion_timer: float = 0.0
const INVERSION_DURATION: float = 12.0
var accel_pattern_chance: float = 0.0
var bomb_chance: float = 0.1
var spawn_burst_active: bool = false
var inversion_pending: bool = false
var inversion_countdown: float = 0.0
const INVERSION_WARNING_TIME: float = 1.2
var warning_tween: Tween = null
var first_streak_rewarded: bool = false
const WARMUP_TIME: float = 20.0
const INVERSION_START_TIME: float = 25.0
var guardian_available: bool = true
var next_burst_time: float = 0.0
var tutorial_shown: bool = false
var quick_tip: Label = null
var recent_combo_flash: bool = false
var wrong_wall_streak: int = 0

# UI
var warning_label: Label = null
var timer_label: Label = null
var music_player: AudioStreamPlayer = null
var life_dots: Array[TextureRect] = []
var life_dot_texture: Texture2D = null

# Slow-mo (6 seconds, not permanent)
var slow_mo_active: bool = false
var slow_mo_timer: float = 0.0
const SLOW_MO_DURATION: float = 2.5
var slow_mo_vignette: ColorRect = null
var slow_mo_flash_started: bool = false

# Preloaded sounds
var snd_miss: AudioStream
var snd_grab: AudioStream
var snd_tick: AudioStream
var snd_wall_cyan: AudioStream
var snd_wall_magenta: AudioStream

# Wall edge glow
var left_glow: ColorRect = null
var right_glow: ColorRect = null

# Background particles
var bg_particles_1: GPUParticles2D = null
var bg_particles_2: GPUParticles2D = null
var bg_particles_3: GPUParticles2D = null

# Music notes (piano-ish)
var note_player: AudioStreamPlayer = null
var note_playback: AudioStreamGeneratorPlayback = null
var note_index: int = 0
var chord_index: int = 0
var in_chord_mode: bool = false
const NOTE_SEQUENCE: Array[float] = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88] # C D E F G A B
const CHORD_SEQUENCE: Array = [
	[261.63, 329.63, 392.00], # C
	[349.23, 440.00, 523.25], # F
	[392.00, 493.88, 587.33], # G
	[440.00, 523.25, 659.25], # Am
]

# Powerups
var double_points_active: bool = false
var double_points_timer: float = 0.0
const DOUBLE_POINTS_DURATION: float = 6.0
var overdrive_active: bool = false
var overdrive_timer: float = 0.0
const OVERDRIVE_DURATION: float = 6.0

# First run + audio ducking
var first_run_active: bool = false
var music_base_db: float = -8.0
var music_duck_tween: Tween = null
const DEBUG_SPAWN_SUPER: bool = true
var super_active: bool = false
var super_timer: float = 0.0
var combo_frozen: bool = false
var super_spawn_multiplier: float = 0.5
var bg_saved: Dictionary = {}
var bonus_pitch: float = 1.1

func _ready():
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	last_difficulty_step = 0
	_load_tutorial_flag()

	laser_left.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_right.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_left.wrong_wall_hit.connect(_on_wrong_wall)
	laser_right.wrong_wall_hit.connect(_on_wrong_wall)

	# Misses are handled by BallDragThrow signals to avoid double counting
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

	snd_miss = load("res://assets/sounds/red_wall.mp3")
	snd_grab = load("res://assets/sounds/blue_wall.mp3")
	snd_tick = load("res://assets/sounds/blue_wall.mp3")
	snd_wall_cyan = load("res://assets/sounds/blue_wall.mp3")
	snd_wall_magenta = load("res://assets/sounds/red_wall.mp3")
	life_dot_texture = load("res://assets/particles/life_dot.svg")

	_setup_life_dots()
	_setup_warning_label()
	_setup_timer_label()
	_setup_wall_glow()
	_setup_background_particles()
	_start_music()
	_update_ui()
	_setup_note_player()
	next_burst_time = randf_range(12.0, 18.0)
	_load_first_run()
	if DEBUG_SPAWN_SUPER:
		_spawn_super_powerup()

	score_label.modulate.a = 0.0
	pause_button.modulate.a = 0.0
	for dot in life_dots:
		dot.modulate.a = 0.0
	if timer_label:
		timer_label.modulate.a = 0.0

	_play_countdown()
	_maybe_show_quick_tip()

func _setup_life_dots():
	for i in range(3):
		var dot = TextureRect.new()
		dot.texture = life_dot_texture
		dot.custom_minimum_size = Vector2(40, 40)
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.position = Vector2(40 + i * 50, 75)
		dot.pivot_offset = Vector2(20, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$CanvasLayer.add_child(dot)
		life_dots.append(dot)

func _setup_background_particles():
	# Layer 1: slow drifting dots (subtle)
	bg_particles_1 = GPUParticles2D.new()
	bg_particles_1.amount = 20
	bg_particles_1.lifetime = 10.0
	bg_particles_1.z_index = -90
	bg_particles_1.position = Vector2(540, 1200)

	var mat1 = ParticleProcessMaterial.new()
	mat1.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat1.emission_box_extents = Vector3(600, 1400, 0)
	mat1.direction = Vector3(0, -1, 0)
	mat1.spread = 20.0
	mat1.initial_velocity_min = 8.0
	mat1.initial_velocity_max = 25.0
	mat1.gravity = Vector3(0, 0, 0)
	mat1.scale_min = 0.15
	mat1.scale_max = 0.4
	mat1.particle_flag_disable_z = true

	var ramp1 = Gradient.new()
	ramp1.set_color(0, Color(0, 1, 1, 0.06))
	ramp1.set_color(1, Color(1, 0, 1, 0.06))
	var ramp_tex1 = GradientTexture1D.new()
	ramp_tex1.gradient = ramp1
	mat1.color_ramp = ramp_tex1

	var alpha1 = Gradient.new()
	alpha1.set_color(0, Color(1, 1, 1, 0))
	alpha1.add_point(0.2, Color(1, 1, 1, 1))
	alpha1.add_point(0.8, Color(1, 1, 1, 1))
	alpha1.set_color(alpha1.get_point_count() - 1, Color(1, 1, 1, 0))
	var alpha_tex1 = GradientTexture1D.new()
	alpha_tex1.gradient = alpha1
	mat1.alpha_curve = alpha_tex1

	bg_particles_1.process_material = mat1
	bg_particles_1.texture = load("res://assets/particles/star4.svg")
	add_child(bg_particles_1)

	# Layer 2: tiny sparkles
	bg_particles_2 = GPUParticles2D.new()
	bg_particles_2.amount = 12
	bg_particles_2.lifetime = 6.0
	bg_particles_2.z_index = -89
	bg_particles_2.position = Vector2(540, 1200)

	var mat2 = ParticleProcessMaterial.new()
	mat2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat2.emission_box_extents = Vector3(500, 1200, 0)
	mat2.direction = Vector3(0, -1, 0)
	mat2.spread = 40.0
	mat2.initial_velocity_min = 15.0
	mat2.initial_velocity_max = 40.0
	mat2.gravity = Vector3(0, 0, 0)
	mat2.scale_min = 0.08
	mat2.scale_max = 0.2
	mat2.particle_flag_disable_z = true
	mat2.color = Color(1, 1, 1, 0.04)

	var alpha2 = Gradient.new()
	alpha2.set_color(0, Color(1, 1, 1, 0))
	alpha2.add_point(0.3, Color(1, 1, 1, 1))
	alpha2.add_point(0.7, Color(1, 1, 1, 1))
	alpha2.set_color(alpha2.get_point_count() - 1, Color(1, 1, 1, 0))
	var alpha_tex2 = GradientTexture1D.new()
	alpha_tex2.gradient = alpha2
	mat2.alpha_curve = alpha_tex2

	bg_particles_2.process_material = mat2
	bg_particles_2.texture = load("res://assets/particles/cross_diamond.svg")
	add_child(bg_particles_2)

	# Layer 3: big soft orbs (parallax depth)
	bg_particles_3 = GPUParticles2D.new()
	bg_particles_3.amount = 10
	bg_particles_3.lifetime = 14.0
	bg_particles_3.z_index = -92
	bg_particles_3.position = Vector2(540, 1200)

	var mat3 = ParticleProcessMaterial.new()
	mat3.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat3.emission_box_extents = Vector3(700, 1500, 0)
	mat3.direction = Vector3(0, -1, 0)
	mat3.spread = 15.0
	mat3.initial_velocity_min = 4.0
	mat3.initial_velocity_max = 12.0
	mat3.gravity = Vector3(0, 0, 0)
	mat3.scale_min = 0.6
	mat3.scale_max = 1.4
	mat3.particle_flag_disable_z = true
	mat3.color = Color(0.4, 0.6, 1.0, 0.08)

	var alpha3 = Gradient.new()
	alpha3.set_color(0, Color(1, 1, 1, 0))
	alpha3.add_point(0.25, Color(1, 1, 1, 1))
	alpha3.add_point(0.75, Color(1, 1, 1, 1))
	alpha3.set_color(alpha3.get_point_count() - 1, Color(1, 1, 1, 0))
	var alpha_tex3 = GradientTexture1D.new()
	alpha_tex3.gradient = alpha3
	mat3.alpha_curve = alpha_tex3

	bg_particles_3.process_material = mat3
	bg_particles_3.texture = load("res://assets/particles/star6.svg")
	add_child(bg_particles_3)

func _start_music():
	music_player = AudioStreamPlayer.new()
	music_player.stream = load("res://assets/sounds/JoshuaMcLean-MountainTrials.mp3")
	music_player.volume_db = music_base_db
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
	countdown_label.add_theme_font_size_override("font_size", 160)
	countdown_label.custom_minimum_size = Vector2(400, 300)
	countdown_label.pivot_offset = Vector2(200, 150)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(countdown_label)

	var colors = [Color(0, 1, 1, 1), Color(1, 0, 1, 1), Color(1, 1, 0, 1)]
	for i in range(3):
		var num = 3 - i
		countdown_label.text = str(num)
		countdown_label.add_theme_color_override("font_color", colors[i])
		countdown_label.scale = Vector2(2.5, 2.5)
		countdown_label.modulate = Color(1, 1, 1, 1)

		_play_sfx(snd_tick, -10.0, 1.0 + i * 0.15)
		Input.vibrate_handheld(15)

		var t = create_tween()
		t.tween_property(countdown_label, "scale", Vector2(0.5, 0.5), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		t.parallel().tween_property(countdown_label, "modulate:a", 0.0, 0.35)
		await t.finished
		await get_tree().create_timer(0.05).timeout

	countdown_label.text = "GO!"
	countdown_label.add_theme_font_size_override("font_size", 120)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	countdown_label.scale = Vector2(0.2, 0.2)
	countdown_label.modulate = Color(1, 1, 1, 1)
	_play_sfx(snd_tick, -5.0, 1.4)
	Input.vibrate_handheld(30)

	var t = create_tween()
	t.tween_property(countdown_label, "scale", Vector2(1.6, 1.6), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.08)
	t.tween_interval(0.15)
	t.tween_property(countdown_label, "modulate:a", 0.0, 0.15)
	t.tween_callback(container.queue_free)

	var ui_t = create_tween().set_parallel(true)
	ui_t.tween_property(score_label, "modulate:a", 1.0, 0.2)
	ui_t.tween_property(pause_button, "modulate:a", 1.0, 0.2)
	for dot in life_dots:
		ui_t.tween_property(dot, "modulate:a", 1.0, 0.2)
	if timer_label:
		ui_t.tween_property(timer_label, "modulate:a", 1.0, 0.2)

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
	warning_label.add_theme_font_size_override("font_size", 32)
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
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 0.5))
	timer_label.position = Vector2(860, 115)
	timer_label.size = Vector2(160, 30)
	timer_label.text = "0:00"
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(timer_label)

func _setup_wall_glow():
	left_glow = ColorRect.new()
	left_glow.size = Vector2(8, 2600)
	left_glow.position = Vector2(0, -200)
	left_glow.color = Color(1, 0, 1, 0.2)
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_glow.z_index = -50
	add_child(left_glow)

	right_glow = ColorRect.new()
	right_glow.size = Vector2(8, 2600)
	right_glow.position = Vector2(1072, -200)
	right_glow.color = Color(0, 1, 1, 0.2)
	right_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_glow.z_index = -50
	add_child(right_glow)

func _update_wall_glow():
	if not left_glow or not right_glow:
		return
	var left_col = Color(0, 1, 1, 0.2) if walls_inverted else Color(1, 0, 1, 0.2)
	var right_col = Color(1, 0, 1, 0.2) if walls_inverted else Color(0, 1, 1, 0.2)
	var gt = create_tween().set_parallel(true)
	gt.tween_property(left_glow, "color", left_col, 0.3)
	gt.tween_property(right_glow, "color", right_col, 0.3)

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

	var step = int(time_elapsed / 10.0)
	if step > last_difficulty_step:
		last_difficulty_step = step
		_apply_difficulty_step(step)

	if inversion_active:
		inversion_timer -= delta
		if inversion_timer <= 0:
			_end_wall_inversion()
	elif inversion_pending:
		inversion_countdown -= delta
		if inversion_countdown <= 0.0:
			_start_wall_inversion()
		elif inversion_countdown <= 0.45:
			_flash_screen(Color(1, 0, 1, 0.08))

	# Slow-mo countdown
	if slow_mo_active:
		slow_mo_timer -= delta

		# Flash warning in last 2 seconds
		if slow_mo_timer <= 2.0 and not slow_mo_flash_started:
			slow_mo_flash_started = true
			_start_slow_mo_warning_flash()

		if slow_mo_timer <= 0:
			_end_slow_mo()

	if double_points_active:
		double_points_timer -= delta
		if double_points_timer <= 0:
			double_points_active = false

	if overdrive_active:
		overdrive_timer -= delta
		if overdrive_timer <= 0:
			overdrive_active = false
			_update_streak_bar()

	if super_active:
		super_timer -= delta
		if super_timer <= 0.0:
			_end_super_mode()
		else:
			_auto_direct_balls()

func _apply_difficulty_step(step: int):
	# Gentle early ramp to let players build streaks before chaos
	spawn_rate = max(0.7, spawn_rate - (0.12 if step < 3 else 0.18))
	spawn_timer.wait_time = spawn_rate

	if step >= 2:
		accel_pattern_chance = min(0.5, (step - 1) * 0.1)

	if step >= 3:
		bomb_chance = min(0.25, 0.1 + (step - 2) * 0.03)

	if time_elapsed >= INVERSION_START_TIME and step >= 3 and not inversion_active and not inversion_pending and randf() < 0.35:
		_schedule_wall_inversion()

	if step >= 4 and time_elapsed >= WARMUP_TIME and randf() < 0.25:
		_trigger_spawn_burst()

	if step >= 5:
		_spawn_ball()

	if time_elapsed >= INVERSION_START_TIME and step >= 6 and not inversion_active and not inversion_pending and randf() < 0.55:
		_schedule_wall_inversion()

	if time_elapsed >= next_burst_time and not spawn_burst_active:
		next_burst_time = time_elapsed + randf_range(10.0, 16.0)
		_trigger_spawn_burst()

func _schedule_wall_inversion():
	inversion_pending = true
	inversion_countdown = INVERSION_WARNING_TIME
	_show_warning("SWITCHING!")
	Input.vibrate_handheld(30)
	_start_inversion_warning()

func _start_wall_inversion():
	inversion_pending = false
	_stop_inversion_warning()
	walls_inverted = true
	inversion_active = true
	inversion_timer = INVERSION_DURATION
	if laser_left:
		laser_left.set_inverted(true)
	if laser_right:
		laser_right.set_inverted(true)
	_sync_balls_inversion()
	_update_wall_glow()
	_show_warning("INVERSION!")
	_flash_screen(Color(1, 0, 1, 0.15))
	Input.vibrate_handheld(50)

func _end_wall_inversion():
	walls_inverted = false
	inversion_active = false
	_stop_inversion_warning()
	if laser_left:
		laser_left.set_inverted(false)
	if laser_right:
		laser_right.set_inverted(false)
	_sync_balls_inversion()
	_update_wall_glow()
	_show_warning("NORMAL")

func _trigger_spawn_burst():
	spawn_burst_active = true
	_show_warning("BURST!")
	Input.vibrate_handheld(40)
	var count = randi_range(3, 6)
	for i in range(count):
		_spawn_ball()
		await get_tree().create_timer(0.2).timeout
	spawn_burst_active = false

func _show_warning(text: String):
	if not warning_label:
		return
	warning_label.text = text
	warning_label.visible = true
	warning_label.modulate = Color(1, 1, 1, 1)
	warning_label.scale = Vector2(0.3, 0.3)

	var tween = create_tween()
	tween.tween_property(warning_label, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(warning_label, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_interval(0.7)
	tween.tween_property(warning_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func(): warning_label.visible = false)

func _spawn_ball():
	if not ball_scene:
		return
	var ball = ball_scene.instantiate() as BallDragThrow
	if not ball:
		return

	ball.position = Vector2(randf_range(150, 930), -100)

	var effective_bomb = _get_effective_bomb_chance()
	var rand = randf()
	if rand < effective_bomb:
		ball.ball_type = BallDragThrow.BallType.BOMB
	elif rand < effective_bomb + 0.3:
		ball.ball_type = BallDragThrow.BallType.CYAN
	elif rand < effective_bomb + 0.6:
		ball.ball_type = BallDragThrow.BallType.MAGENTA
	else:
		ball.ball_type = BallDragThrow.BallType.YELLOW

	if super_active and ball.ball_type == BallDragThrow.BallType.BOMB:
		ball.ball_type = BallDragThrow.BallType.YELLOW

	var grav = 0.25 + (time_elapsed / 80.0)
	ball.gravity_scale = min(grav, 1.0)

	if time_elapsed >= WARMUP_TIME and randf() < accel_pattern_chance:
		ball.has_accel_pattern = true
		ball.base_gravity = ball.gravity_scale
		ball.accel_timer = randf() * TAU

	ball.walls_inverted = walls_inverted
	if super_active:
		ball.super_mode = true
		ball.auto_directed = false
	ball.bomb_exploded.connect(_on_bomb_exploded)
	ball.ball_missed.connect(_on_ball_missed)

	ball.scale = Vector2(0.0, 0.0)
	add_child(ball)
	var st = create_tween()
	st.tween_property(ball, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_spawn_direction_hint(ball)

func _on_laser_ball_destroyed(points: int, ball: BallDragThrow):
	if not combo_frozen:
		combo += 1
		balls_scored += 1
		if combo > max_combo:
			max_combo = combo
	wrong_wall_streak = 0

	var multiplier = 1.0 + combo * 0.15
	if overdrive_active:
		multiplier += 0.3
	var total = int(points * multiplier)

	# Perfect bonus: reward fast, accurate throws for addiction loop
	var perfect_bonus = _calculate_perfect_bonus(ball)
	if perfect_bonus > 0:
		total += perfect_bonus
		_show_perfect_popup(perfect_bonus)

	if not combo_frozen:
		if combo == 5 and not first_streak_rewarded:
			first_streak_rewarded = true
			total += 50
			_show_streak_banner("STREAK x5 +50", Color(1, 1, 0.2, 1))
			_spawn_powerup_for_streak()
		elif combo == 10:
			_show_streak_banner("STREAK x10", Color(0, 1, 1, 1))
			_activate_overdrive()
		elif combo == 15:
			_show_streak_banner("STREAK x15", Color(1, 0, 1, 1))
			_grant_shield()
		elif combo == 12:
			_activate_double_points()
		elif combo == 25:
			_spawn_super_powerup()

	if double_points_active:
		total *= 2

	score += total
	_play_note_sequence()
	_maybe_combo_flash()
	_update_streak_bar()
	_duck_music(-10.0, 0.18)

	# Correct-hit sound handled by piano notes

	if combo >= 5:
		Input.vibrate_handheld(40)
	else:
		Input.vibrate_handheld(20)

	# Every x15 combo = regain a life
	if combo > 0 and combo % 15 == 0 and lives < 3:
		_regain_life()

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

func _show_streak_banner(text: String, color: Color):
	if $CanvasLayer.has_node("StreakBanner"):
		$CanvasLayer.get_node("StreakBanner").queue_free()
	var label = Label.new()
	label.name = "StreakBanner"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", color)
	var view = get_viewport_rect().size
	label.size = Vector2(600, 80)
	label.position = Vector2((view.x - label.size.x) * 0.5, 620)
	label.pivot_offset = Vector2(300, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(label)

	label.scale = Vector2(0.3, 0.3)
	var t = create_tween()
	t.tween_property(label, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.08)
	t.tween_interval(0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.3)
	t.tween_callback(label.queue_free)

	_flash_screen(Color(color.r, color.g, color.b, 0.12))

func _update_streak_bar():
	if not streak_bar or not streak_label:
		return
	var milestones = [5, 10, 15, 20]
	var current = 0
	var next = milestones[milestones.size() - 1]
	for m in milestones:
		if combo < m:
			next = m
			break
		current = m
	var progress = 0.0
	if next > current:
		progress = float(combo - current) / float(next - current) * 100.0
	streak_bar.value = clamp(progress, 0.0, 100.0)
	streak_label.text = "STREAK " + str(combo) + " / " + str(next)
	if overdrive_active:
		streak_label.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	else:
		streak_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1, 0.85))

func _activate_double_points():
	double_points_active = true
	double_points_timer = DOUBLE_POINTS_DURATION
	_show_streak_banner("2X POINTS!", Color(1, 1, 0.4, 1))

func _activate_overdrive():
	overdrive_active = true
	overdrive_timer = OVERDRIVE_DURATION
	_show_streak_banner("OVERDRIVE", Color(0, 1, 1, 1))
	_update_streak_bar()

func _grant_shield():
	if guardian_available:
		return
	guardian_available = true
	_show_streak_banner("POWER-UP!", Color(0.4, 1, 0.6, 1))

func _spawn_powerup_for_streak():
	if not powerup_scene:
		return
	var p = powerup_scene.instantiate() as PowerupDrop
	if not p:
		return
	p.position = Vector2(randf_range(200, 880), -120)
	if lives < 3:
		p.powerup_type = PowerupDrop.PowerupType.HEART
	else:
		p.powerup_type = PowerupDrop.PowerupType.SHIELD_WALL
	p.powerup_activated.connect(_on_powerup_activated)
	add_child(p)

func _spawn_super_powerup():
	if super_active:
		return
	if not powerup_scene:
		return
	var p = powerup_scene.instantiate() as PowerupDrop
	if not p:
		return
	p.position = Vector2(randf_range(250, 830), -140)
	p.powerup_type = PowerupDrop.PowerupType.SUPER
	p.powerup_activated.connect(_on_powerup_activated)
	add_child(p)

func _on_powerup_activated(p_type: int):
	match p_type:
		PowerupDrop.PowerupType.HEART:
			if lives < 3:
				lives += 1
				_update_ui()
				_show_streak_banner("+1 LIFE", Color(0.3, 1, 0.4, 1))
		PowerupDrop.PowerupType.SHIELD_WALL:
			_activate_shield_wall()
		PowerupDrop.PowerupType.SUPER:
			_start_super_mode()


func _activate_shield_wall():
	if has_node("ShieldWall"):
		var w = $ShieldWall
		w.queue_free()
	var wall = ShieldWall.new()
	wall.name = "ShieldWall"
	wall.position = Vector2(540, 2350)
	add_child(wall)
	_show_streak_banner("POWER-UP!", Color(1, 1, 0.4, 1))
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(wall):
		wall.queue_free()

func _start_super_mode():
	if super_active:
		return
	super_active = true
	super_timer = 6.5
	combo_frozen = true
	_spawn_super_visuals()
	# Speed up spawns
	spawn_timer.wait_time = max(0.35, spawn_timer.wait_time * super_spawn_multiplier)
	# Bonus music feel (pitch only, actual track later)
	if music_player:
		music_player.pitch_scale = bonus_pitch

func _end_super_mode():
	super_active = false
	combo_frozen = false
	_restore_super_visuals()
	# Restore spawns
	spawn_timer.wait_time = spawn_rate
	if music_player:
		music_player.pitch_scale = 1.0

func _spawn_super_visuals():
	if background and background.material:
		var mat = background.material
		if mat is ShaderMaterial:
			var sm = mat as ShaderMaterial
			bg_saved.color_top = sm.get_shader_parameter("color_top")
			bg_saved.color_bottom = sm.get_shader_parameter("color_bottom")
			bg_saved.accent_color = sm.get_shader_parameter("accent_color")
			bg_saved.accent_strength = sm.get_shader_parameter("accent_strength")
			sm.set_shader_parameter("color_top", Color(0.08, 0.02, 0.12, 1))
			sm.set_shader_parameter("color_bottom", Color(0.01, 0.01, 0.03, 1))
			sm.set_shader_parameter("accent_color", Color(1, 1, 0, 1))
			sm.set_shader_parameter("accent_strength", 0.28)
	if scanlines and scanlines.material:
		var sm2 = scanlines.material
		if sm2 is ShaderMaterial:
			var ss = sm2 as ShaderMaterial
			bg_saved.scan_intensity = ss.get_shader_parameter("intensity")
			ss.set_shader_parameter("intensity", 0.22)

func _restore_super_visuals():
	if background and background.material:
		var mat = background.material
		if mat is ShaderMaterial and bg_saved.has("color_top"):
			var sm = mat as ShaderMaterial
			sm.set_shader_parameter("color_top", bg_saved.color_top)
			sm.set_shader_parameter("color_bottom", bg_saved.color_bottom)
			sm.set_shader_parameter("accent_color", bg_saved.accent_color)
			sm.set_shader_parameter("accent_strength", bg_saved.accent_strength)
	if scanlines and scanlines.material and bg_saved.has("scan_intensity"):
		var sm2 = scanlines.material
		if sm2 is ShaderMaterial:
			var ss = sm2 as ShaderMaterial
			ss.set_shader_parameter("intensity", bg_saved.scan_intensity)

func _auto_direct_balls():
	var mid_y = get_viewport_rect().size.y * 0.5
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			if ball.ball_type == BallDragThrow.BallType.BOMB:
				continue
			ball.super_mode = true
			if not ball.is_grabbed and not ball.is_thrown and ball.global_position.y > mid_y:
				if not ball.auto_directed:
					ball.auto_directed = true
					var target_x = 1000.0
					if ball.ball_type == BallDragThrow.BallType.CYAN:
						target_x = 1040.0 if not walls_inverted else 40.0
					elif ball.ball_type == BallDragThrow.BallType.MAGENTA:
						target_x = 40.0 if not walls_inverted else 1040.0
					elif ball.ball_type == BallDragThrow.BallType.YELLOW:
						target_x = 1040.0 if ball.global_position.x > 540 else 40.0
					var dir = Vector2(target_x - ball.global_position.x, -200.0).normalized()
					ball.apply_central_impulse(dir * 900.0)

func _get_effective_bomb_chance() -> float:
	if super_active:
		return 0.0
	if first_run_active:
		if time_elapsed < 20.0:
			return 0.0
		if time_elapsed < 30.0:
			var t = (time_elapsed - 20.0) / 10.0
			return bomb_chance * t
		return bomb_chance
	if time_elapsed < 15.0:
		return 0.0
	if time_elapsed < 25.0:
		var t = (time_elapsed - 15.0) / 10.0
		return bomb_chance * t
	return bomb_chance

func _load_tutorial_flag():
	if FileAccess.file_exists("user://tutorial_seen.save"):
		tutorial_shown = true

func _save_tutorial_flag():
	var f = FileAccess.open("user://tutorial_seen.save", FileAccess.WRITE)
	if f:
		f.store_8(1)
		f.close()

func _maybe_show_quick_tip():
	if tutorial_shown:
		return
	_show_quick_tip()
	_save_tutorial_flag()

func _show_quick_tip():
	quick_tip = Label.new()
	quick_tip.text = "TAP + DRAG + RELEASE"
	quick_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_tip.add_theme_font_size_override("font_size", 28)
	quick_tip.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	quick_tip.position = Vector2(190, 420)
	quick_tip.size = Vector2(700, 80)
	quick_tip.pivot_offset = Vector2(350, 40)
	quick_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(quick_tip)

	var t = create_tween()
	t.tween_property(quick_tip, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.0)
	t.tween_property(quick_tip, "modulate:a", 0.0, 0.3)
	t.tween_callback(quick_tip.queue_free)

func _maybe_combo_flash():
	if combo >= 8 and not recent_combo_flash:
		recent_combo_flash = true
		_flash_screen(Color(1, 1, 1, 0.08))
		var t = create_tween()
		t.tween_property(Engine, "time_scale", 0.94, 0.05).set_ease(Tween.EASE_OUT)
		t.tween_property(Engine, "time_scale", 1.0, 0.06).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(0.2).timeout
		recent_combo_flash = false

func _use_guardian() -> bool:
	if not guardian_available:
		return false
	guardian_available = false
	lives = max(lives, 1)
	_update_ui()
	_show_streak_banner("SAVE!", Color(0, 1, 0.6, 1))
	_flash_screen(Color(0, 1, 0.6, 0.18))
	Input.vibrate_handheld(80)
	return true

func _load_first_run():
	first_run_active = not FileAccess.file_exists("user://first_run_done.save")

func _mark_first_run_done():
	if FileAccess.file_exists("user://first_run_done.save"):
		return
	var f = FileAccess.open("user://first_run_done.save", FileAccess.WRITE)
	if f:
		f.store_8(1)
		f.close()

func _duck_music(target_db: float, duration: float):
	if not music_player:
		return
	if music_duck_tween and music_duck_tween.is_valid():
		music_duck_tween.kill()
	music_duck_tween = create_tween()
	music_duck_tween.tween_property(music_player, "volume_db", target_db, 0.05).set_ease(Tween.EASE_OUT)
	music_duck_tween.tween_property(music_player, "volume_db", music_base_db, duration).set_ease(Tween.EASE_IN)

func _sync_balls_inversion():
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			ball.walls_inverted = walls_inverted

func _setup_note_player():
	note_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.2
	note_player.stream = gen
	note_player.bus = &"SFX"
	add_child(note_player)
	note_player.play()
	note_playback = note_player.get_stream_playback()

func _play_note_sequence():
	if not note_playback:
		return
	if in_chord_mode:
		var chord = CHORD_SEQUENCE[chord_index % CHORD_SEQUENCE.size()]
		_play_chord(chord, 0.16)
		chord_index += 1
		if chord_index % CHORD_SEQUENCE.size() == 0:
			in_chord_mode = false
			note_index = 0
	else:
		var freq = NOTE_SEQUENCE[note_index % NOTE_SEQUENCE.size()]
		_play_tone(freq, 0.14)
		note_index += 1
		if note_index % NOTE_SEQUENCE.size() == 0:
			in_chord_mode = true
			chord_index = 0

func _play_tone(freq: float, duration: float):
	var rate = 44100.0
	var samples = int(duration * rate)
	var phase = 0.0
	var inc = TAU * freq / rate
	for i in range(samples):
		var env = 1.0 - float(i) / float(samples)
		var s = sin(phase) * env * 0.55
		note_playback.push_frame(Vector2(s, s))
		phase += inc

func _play_chord(freqs: Array, duration: float):
	var rate = 44100.0
	var samples = int(duration * rate)
	var phases = []
	var incs = []
	for f in freqs:
		phases.append(0.0)
		incs.append(TAU * f / rate)
	for i in range(samples):
		var env = 1.0 - float(i) / float(samples)
		var s = 0.0
		for idx in range(freqs.size()):
			s += sin(phases[idx])
			phases[idx] += incs[idx]
		s = (s / freqs.size()) * env * 0.45
		note_playback.push_frame(Vector2(s, s))

func _calculate_perfect_bonus(ball: BallDragThrow) -> int:
	if not ball:
		return 0
	var t = ball.get_time_since_throw()
	if t < 0.0:
		return 0
	if t <= 0.55:
		return 20
	if t <= 0.75:
		return 10
	return 0

func _show_perfect_popup(bonus: int):
	var label = Label.new()
	label.text = "PERFECT +" + str(bonus)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	label.position = Vector2(360, 520)
	label.size = Vector2(360, 60)
	label.pivot_offset = Vector2(180, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(label)

	label.scale = Vector2(0.4, 0.4)
	var t = create_tween()
	t.tween_property(label, "scale", Vector2(1.25, 1.25), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "position:y", label.position.y - 80, 0.5).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	t.tween_callback(label.queue_free)

func _regain_life():
	lives += 1
	Input.vibrate_handheld(60)
	_flash_screen(Color(0, 1, 0, 0.15))

	# Show the life dot that was hidden
	var dot_index = lives - 1
	if dot_index >= 0 and dot_index < life_dots.size():
		var dot = life_dots[dot_index]
		dot.visible = true
		dot.modulate = Color(0, 1, 0, 0)
		dot.scale = Vector2(0.2, 0.2)
		var t = create_tween()
		t.tween_property(dot, "scale", Vector2(1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(dot, "modulate", Color(1, 1, 1, 1), 0.15)
		t.tween_property(dot, "scale", Vector2(1.0, 1.0), 0.1)

	_show_warning("+1 UP!")

	# End slow-mo if it was active and we now have > 1 life
	if slow_mo_active and lives > 1:
		_end_slow_mo()

func _on_wrong_wall():
	wrong_wall_streak += 1
	if wrong_wall_streak >= 2:
		wrong_wall_streak = 0
		_on_ball_missed()
		return
	combo = 0
	_update_ui()
	_flash_screen(Color(1, 0.5, 0, 0.15))
	Input.vibrate_handheld(50)

func _check_milestone():
	var milestones = [100, 250, 500, 1000, 2000, 5000]
	for m in milestones:
		if score >= m and (score - int(50 * (1.0 + combo * 0.15))) < m:
			_show_milestone(m)
			return

func _show_milestone(value: int):
	var label = Label.new()
	label.text = str(value) + "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	label.anchors_preset = Control.PRESET_CENTER
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = 100
	label.offset_bottom = 250
	label.pivot_offset = Vector2(300, 75)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(label)

	label.scale = Vector2(0.2, 0.2)
	var t = create_tween()
	t.tween_property(label, "scale", Vector2(1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	t.tween_interval(0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.3)
	t.tween_callback(label.queue_free)
	_flash_screen(Color(1, 1, 0, 0.1))
	Input.vibrate_handheld(60)

func _spawn_score_popup(points: int):
	var popup = Label.new()
	popup.text = "+" + str(points)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 24)
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

	popup.scale = Vector2(0.4, 0.4)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(popup, "position:y", popup.position.y - 85, 0.55).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_property(popup, "modulate:a", 0.0, 0.25)
	t.tween_callback(popup.queue_free)

func _on_ball_missed():
	lives -= 1
	if not combo_frozen:
		combo = 0
	wrong_wall_streak = 0
	overdrive_active = false
	double_points_active = false
	balls_thrown += 1

	_play_sfx(snd_miss, -6.0, 0.7)
	Input.vibrate_handheld(80)
	_duck_music(-14.0, 0.2)

	if camera:
		camera.medium_shake()

	_update_ui()
	_flash_screen(Color(1, 0, 0, 0.2))
	_spawn_miss_indicator()
	_pop_life_dot(lives)

	if lives == 1 and not slow_mo_active:
		_start_slow_mo()

	if lives <= 0:
		if _use_guardian():
			return
		_game_over()

func _start_slow_mo():
	slow_mo_active = true
	slow_mo_timer = SLOW_MO_DURATION
	slow_mo_flash_started = false

	var t = create_tween()
	t.tween_property(Engine, "time_scale", 0.40, 0.5).set_ease(Tween.EASE_OUT)

	# Red vignette
	slow_mo_vignette = ColorRect.new()
	slow_mo_vignette.name = "LastLifeVignette"
	slow_mo_vignette.color = Color(1, 0, 0, 0.08)
	slow_mo_vignette.anchors_preset = Control.PRESET_FULL_RECT
	slow_mo_vignette.anchor_right = 1.0
	slow_mo_vignette.anchor_bottom = 1.0
	slow_mo_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(slow_mo_vignette)

	var pulse = create_tween().set_loops()
	pulse.tween_property(slow_mo_vignette, "color:a", 0.15, 0.6).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(slow_mo_vignette, "color:a", 0.04, 0.6).set_ease(Tween.EASE_IN_OUT)

	_show_warning("LAST LIFE!")

	# Pulse the remaining life dot
	if life_dots.size() > 0 and life_dots[0].visible:
		var dot_pulse = create_tween().set_loops()
		dot_pulse.tween_property(life_dots[0], "modulate", Color(1, 0.3, 0.3, 1), 0.4)
		dot_pulse.tween_property(life_dots[0], "modulate", Color(1, 1, 1, 1), 0.4)

func _start_slow_mo_warning_flash():
	# Flash the screen border to warn slow-mo is ending
	if not slow_mo_vignette or not is_instance_valid(slow_mo_vignette):
		return
	var flash_tween = create_tween().set_loops(4)
	flash_tween.tween_property(slow_mo_vignette, "color:a", 0.3, 0.15)
	flash_tween.tween_property(slow_mo_vignette, "color:a", 0.05, 0.15)

func _end_slow_mo():
	if not slow_mo_active:
		return
	slow_mo_active = false
	slow_mo_timer = 0.0

	var t = create_tween()
	t.tween_property(Engine, "time_scale", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	if slow_mo_vignette and is_instance_valid(slow_mo_vignette):
		var vt = create_tween()
		vt.tween_property(slow_mo_vignette, "modulate:a", 0.0, 0.3)
		vt.tween_callback(slow_mo_vignette.queue_free)
		slow_mo_vignette = null

func _pop_life_dot(index: int):
	if index < 0 or index >= life_dots.size():
		return
	var dot = life_dots[index]
	var t = create_tween()
	t.tween_property(dot, "scale", Vector2(1.8, 1.8), 0.08).set_ease(Tween.EASE_OUT)
	t.tween_property(dot, "modulate", Color(1, 0.2, 0.2, 0), 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): dot.visible = false)

func _spawn_miss_indicator():
	var miss = Label.new()
	miss.text = "-1"
	miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	miss.add_theme_font_size_override("font_size", 32)
	miss.add_theme_color_override("font_color", Color(1, 0.15, 0.15, 1))
	miss.position = Vector2(390, 750)
	miss.size = Vector2(300, 80)
	miss.pivot_offset = Vector2(150, 40)
	miss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(miss)

	miss.scale = Vector2(0.2, 0.2)
	var t = create_tween()
	t.tween_property(miss, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(miss, "scale", Vector2(1.0, 1.0), 0.08)
	t.tween_property(miss, "position:y", miss.position.y - 100, 0.5).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(miss, "modulate:a", 0.0, 0.5)
	t.tween_callback(miss.queue_free)

func _flash_screen(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(flash)

	var t = create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.25)
	t.tween_callback(flash.queue_free)

func _start_inversion_warning():
	if not warning_left or not warning_right:
		return
	if warning_tween and warning_tween.is_valid():
		warning_tween.kill()

	warning_left.modulate.a = 0.0
	warning_right.modulate.a = 0.0
	warning_left.visible = true
	warning_right.visible = true

	warning_tween = create_tween()
	warning_tween.set_loops(5)
	warning_tween.tween_property(warning_left, "modulate:a", 0.45, 0.12).set_ease(Tween.EASE_OUT)
	warning_tween.parallel().tween_property(warning_right, "modulate:a", 0.45, 0.12).set_ease(Tween.EASE_OUT)
	warning_tween.tween_property(warning_left, "modulate:a", 0.0, 0.12)
	warning_tween.parallel().tween_property(warning_right, "modulate:a", 0.0, 0.12)

func _stop_inversion_warning():
	if warning_tween and warning_tween.is_valid():
		warning_tween.kill()
	warning_tween = null
	if warning_left:
		warning_left.modulate.a = 0.0
	if warning_right:
		warning_right.modulate.a = 0.0

func _on_bomb_exploded():
	if camera:
		camera.big_shake()
	Input.vibrate_handheld(150)
	_play_sfx(snd_miss, -2.0, 0.5)
	_flash_screen(Color(1, 0.3, 0, 0.35))
	_duck_music(-16.0, 0.25)
	if _use_guardian():
		return
	_game_over()

func _on_pause_pressed():
	if not game_over:
		pause_menu.show_pause()

func _game_over():
	game_over = true
	spawn_timer.stop()

	if slow_mo_active:
		_end_slow_mo()
		await get_tree().create_timer(0.3).timeout
	Engine.time_scale = 1.0
	slow_mo_active = false

	if $CanvasLayer.has_node("LastLifeVignette"):
		$CanvasLayer.get_node("LastLifeVignette").queue_free()

	if music_player:
		var mt = create_tween()
		mt.tween_property(music_player, "volume_db", -40.0, 0.6)

	await get_tree().create_timer(0.6).timeout

	var mins = int(time_elapsed) / 60
	var secs = int(time_elapsed) % 60
	var time_str = "%d:%02d" % [mins, secs]
	var accuracy = 0.0
	if balls_thrown + balls_scored > 0:
		accuracy = float(balls_scored) / float(balls_thrown + balls_scored) * 100.0
	_mark_first_run_done()
	game_over_menu.show_game_over(score, max_combo, time_str, accuracy)

func _update_ui():
	if score_label:
		score_label.text = str(score)
		_animate_label(score_label)

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
			_animate_label(combo_label, 1.25 + combo * 0.03)
		else:
			combo_label.visible = false

	_update_streak_bar()

func _animate_label(label: Label, scale_to: float = 1.15):
	scale_to = min(scale_to, 1.6)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2(scale_to, scale_to), 0.08)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)

func _spawn_direction_hint(ball: BallDragThrow):
	if ball.ball_type == BallDragThrow.BallType.BOMB:
		return

	var hint = Label.new()
	hint.add_theme_font_size_override("font_size", 20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cyan_right = not walls_inverted
	match ball.ball_type:
		BallDragThrow.BallType.CYAN:
			hint.text = ">" if cyan_right else "<"
			hint.add_theme_color_override("font_color", Color(0, 1, 1, 0.4))
		BallDragThrow.BallType.MAGENTA:
			hint.text = "<" if cyan_right else ">"
			hint.add_theme_color_override("font_color", Color(1, 0, 1, 0.4))
		BallDragThrow.BallType.YELLOW:
			hint.text = "<>"
			hint.add_theme_color_override("font_color", Color(1, 1, 0, 0.4))

	hint.position = ball.position + Vector2(-18, -65)
	add_child(hint)

	var t = create_tween()
	t.tween_property(hint, "position:y", hint.position.y - 35, 0.4).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(hint, "modulate:a", 0.0, 0.4)
	t.tween_callback(hint.queue_free)
