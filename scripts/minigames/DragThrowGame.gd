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
var guardian_used_once: bool = false
var next_burst_time: float = 0.0
var tutorial_shown: bool = false
var quick_tip: Label = null
var recent_combo_flash: bool = false
var wrong_wall_streak: int = 0

# Adaptive flow director (keeps tension high without unfair spikes)
var adaptive_flow_score: float = 0.5
var adaptive_eval_timer: float = 0.0
const ADAPTIVE_EVAL_INTERVAL: float = 3.0
var adaptive_spawn_offset: float = 0.0
const ADAPTIVE_SPAWN_MIN: float = -0.22
const ADAPTIVE_SPAWN_MAX: float = 0.28
var assist_window_timer: float = 0.0
const ASSIST_WINDOW_DURATION: float = 6.0
var bomb_pause_timer: float = 0.0
const BOMB_PAUSE_ON_MISS: float = 5.0
var recent_hit_window: int = 0
var recent_miss_window: int = 0

# UI
var warning_label: Label = null
var timer_label: Label = null
var music_player: AudioStreamPlayer = null
var life_dots: Array[TextureRect] = []
var life_dot_texture: Texture2D = null
var guardian_label: Label = null
var lane_hint_left: Label = null
var lane_hint_right: Label = null

# Slow-mo (short clutch window, not permanent)
var slow_mo_active: bool = false
var slow_mo_timer: float = 0.0
const SLOW_MO_DURATION: float = 2.5
var slow_mo_vignette: ColorRect = null
var slow_mo_flash_started: bool = false
var slow_mo_vignette_tween: Tween = null
var slow_mo_life_dot_tween: Tween = null

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
var shield_pending: bool = false
var shield_pending_timer: float = 0.0
const SHIELD_PENDING_DURATION: float = 6.0
const SHIELD_ACTIVE_DURATION: float = 3.0
const SHIELD_TRIGGER_TIME: float = 0.7

# First run + audio ducking
var first_run_active: bool = false
var music_base_db: float = -8.0
var music_duck_tween: Tween = null
const DEBUG_SPAWN_SUPER: bool = false
var super_active: bool = false
var super_timer: float = 0.0
var combo_frozen: bool = false
var super_spawn_multiplier: float = 0.2
const SUPER_DURATION: float = 6.0
const SUPER_COOLDOWN: float = 1.5
const SUPER_GRAVITY_MULT: float = 2.2
var super_cooldown_active: bool = false
var bg_saved: Dictionary = {}
var bonus_pitch: float = 1.1
var super_vignette: ColorRect = null
var super_pulse_tween: Tween = null
const SUPER_BOUNDS_MARGIN: float = 70.0
var super_fx_phase: float = 0.0
var super_spark_timer: float = 0.0
const SUPER_SPARK_INTERVAL: float = 0.55

# Adaptive FX profile (mobile + user particle quality)
var fx_quality: int = 2
var fx_is_mobile: bool = false
var fx_particle_scale: float = 1.0
var fx_flash_scale: float = 1.0
var fx_super_pulse_scale: float = 1.0
var fx_scanline_scale: float = 1.0
var fx_super_spark_interval_scale: float = 1.0
var fx_super_spark_amount_scale: float = 1.0

# Cached textures for frequently spawned particles
var tex_star4: Texture2D = null
var tex_star6: Texture2D = null
var tex_cross: Texture2D = null

func _ready():
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	spawn_timer.stop()
	last_difficulty_step = 0
	_load_tutorial_flag()
	_configure_fx_profile()
	tex_star4 = load("res://assets/particles/star4.svg")
	tex_star6 = load("res://assets/particles/star6.svg")
	tex_cross = load("res://assets/particles/cross_diamond.svg")

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
	_setup_guardian_label()
	_setup_warning_label()
	_setup_timer_label()
	_setup_wall_glow()
	_setup_lane_hud()
	_setup_background_particles()
	_start_music()
	_update_ui()
	_setup_note_player()
	next_burst_time = randf_range(12.0, 18.0)
	adaptive_eval_timer = ADAPTIVE_EVAL_INTERVAL
	_load_first_run()
	_update_spawn_wait_time()
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
		dot.position = Vector2(30 + i * 50, 30)
		dot.pivot_offset = Vector2(20, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$CanvasLayer.add_child(dot)
		life_dots.append(dot)

func _setup_background_particles():
	# Layer 1: slow drifting dots (subtle)
	bg_particles_1 = GPUParticles2D.new()
	bg_particles_1.amount = int(max(8.0, round(20.0 * fx_particle_scale)))
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
	bg_particles_1.texture = tex_star4
	add_child(bg_particles_1)

	# Layer 2: tiny sparkles
	bg_particles_2 = GPUParticles2D.new()
	bg_particles_2.amount = int(max(5.0, round(12.0 * fx_particle_scale)))
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
	bg_particles_2.texture = tex_cross
	add_child(bg_particles_2)

	# Layer 3: big soft orbs (parallax depth)
	bg_particles_3 = GPUParticles2D.new()
	bg_particles_3.amount = int(max(4.0, round(10.0 * fx_particle_scale)))
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
	bg_particles_3.texture = tex_star6
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
		_vibrate(15)

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
	_vibrate(30)

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

func _configure_fx_profile():
	fx_is_mobile = OS.has_feature("mobile")
	fx_quality = 2
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs:
		fx_quality = int(clamp(float(gs.get("particle_quality")), 0.0, 2.0))

	match fx_quality:
		0:
			fx_particle_scale = 0.58
			fx_flash_scale = 0.86
			fx_super_pulse_scale = 0.78
			fx_scanline_scale = 0.80
			fx_super_spark_interval_scale = 1.50
			fx_super_spark_amount_scale = 0.56
		1:
			fx_particle_scale = 0.78
			fx_flash_scale = 0.93
			fx_super_pulse_scale = 0.90
			fx_scanline_scale = 0.90
			fx_super_spark_interval_scale = 1.24
			fx_super_spark_amount_scale = 0.76
		_:
			fx_particle_scale = 1.00
			fx_flash_scale = 1.00
			fx_super_pulse_scale = 1.00
			fx_scanline_scale = 1.00
			fx_super_spark_interval_scale = 1.00
			fx_super_spark_amount_scale = 1.00

	if fx_is_mobile:
		fx_particle_scale *= 0.88
		fx_flash_scale *= 0.92
		fx_super_pulse_scale *= 0.90
		fx_scanline_scale *= 0.92
		fx_super_spark_interval_scale *= 1.12
		fx_super_spark_amount_scale *= 0.90

func _vibrate(duration_ms: int):
	var d = duration_ms
	if fx_is_mobile:
		d = int(round(float(duration_ms) * 0.90))
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.has_method("vibrate"):
		gs.vibrate(d)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(d)

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
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7, 0.8))
	timer_label.position = Vector2(30, 78)
	timer_label.size = Vector2(160, 30)
	timer_label.text = "0:00"
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(timer_label)

func _setup_guardian_label():
	guardian_label = Label.new()
	guardian_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	guardian_label.add_theme_font_size_override("font_size", 20)
	guardian_label.position = Vector2(700, 78)
	guardian_label.size = Vector2(240, 26)
	guardian_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(guardian_label)
	_update_guardian_label()

func _update_guardian_label():
	if not guardian_label:
		return
	if guardian_used_once:
		guardian_label.text = "GUARDIAN: USED"
		guardian_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 0.7))
	elif guardian_available:
		guardian_label.text = "GUARDIAN: READY"
		guardian_label.add_theme_color_override("font_color", Color(0.4, 1, 0.6, 0.8))
	else:
		guardian_label.text = "GUARDIAN: NONE"
		guardian_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.6))

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

func _setup_lane_hud():
	lane_hint_left = Label.new()
	lane_hint_left.name = "LaneHintLeft"
	lane_hint_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_hint_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lane_hint_left.size = Vector2(200, 42)
	lane_hint_left.position = Vector2(10, 185)
	lane_hint_left.add_theme_font_size_override("font_size", 22)
	lane_hint_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(lane_hint_left)

	lane_hint_right = Label.new()
	lane_hint_right.name = "LaneHintRight"
	lane_hint_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_hint_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lane_hint_right.size = Vector2(200, 42)
	lane_hint_right.position = Vector2(870, 185)
	lane_hint_right.add_theme_font_size_override("font_size", 22)
	lane_hint_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(lane_hint_right)

	_update_lane_hud(false)

func _update_lane_hud(pulse: bool = true):
	if not lane_hint_left or not lane_hint_right:
		return

	if super_active:
		lane_hint_left.text = "ANY"
		lane_hint_right.text = "ANY"
		lane_hint_left.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 0.9))
		lane_hint_right.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 0.9))
	else:
		var left_is_cyan = walls_inverted
		lane_hint_left.text = "CYAN" if left_is_cyan else "MAGENTA"
		lane_hint_right.text = "MAGENTA" if left_is_cyan else "CYAN"
		lane_hint_left.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 0.8) if left_is_cyan else Color(1.0, 0.0, 1.0, 0.8))
		lane_hint_right.add_theme_color_override("font_color", Color(1.0, 0.0, 1.0, 0.8) if left_is_cyan else Color(0.0, 1.0, 1.0, 0.8))

	if pulse:
		_pulse_lane_hud()

func _pulse_lane_hud():
	if not lane_hint_left or not lane_hint_right:
		return
	lane_hint_left.scale = Vector2(0.9, 0.9)
	lane_hint_right.scale = Vector2(0.9, 0.9)
	lane_hint_left.modulate.a = 0.65
	lane_hint_right.modulate.a = 0.65
	var t = create_tween().set_parallel(true)
	t.tween_property(lane_hint_left, "scale", Vector2(1.0, 1.0), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(lane_hint_right, "scale", Vector2(1.0, 1.0), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(lane_hint_left, "modulate:a", 1.0, 0.2)
	t.tween_property(lane_hint_right, "modulate:a", 1.0, 0.2)

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

	if assist_window_timer > 0.0:
		assist_window_timer -= delta
	if bomb_pause_timer > 0.0:
		bomb_pause_timer -= delta

	adaptive_eval_timer -= delta
	if adaptive_eval_timer <= 0.0:
		adaptive_eval_timer = ADAPTIVE_EVAL_INTERVAL
		_evaluate_adaptive_flow()

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
			if assist_window_timer > 0.0:
				inversion_pending = false
				_stop_inversion_warning()
				_show_warning("HOLD")
			else:
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

	if shield_pending:
		shield_pending_timer -= delta
		if shield_pending_timer <= 0.0:
			shield_pending = false
		elif _should_trigger_shield():
			shield_pending = false
			_activate_shield_wall()

	if super_active:
		super_timer -= delta
		if super_timer <= 0.0:
			_end_super_mode()
		else:
			_tick_super_fx(delta)
			_auto_direct_balls()

func _apply_difficulty_step(step: int):
	# Gentle early ramp to let players build streaks before chaos
	spawn_rate = max(0.7, spawn_rate - (0.12 if step < 3 else 0.18))
	_update_spawn_wait_time()

	if step >= 2:
		accel_pattern_chance = min(0.5, (step - 1) * 0.1)

	if step >= 3:
		bomb_chance = min(0.25, 0.1 + (step - 2) * 0.03)

	if time_elapsed >= INVERSION_START_TIME and step >= 3 and assist_window_timer <= 0.0 and not inversion_active and not inversion_pending and randf() < 0.35:
		_schedule_wall_inversion()

	if step >= 4 and time_elapsed >= WARMUP_TIME and assist_window_timer <= 0.0 and randf() < 0.25:
		_trigger_spawn_burst()

	if step >= 5 and assist_window_timer <= 0.0:
		_spawn_ball()

	if time_elapsed >= INVERSION_START_TIME and step >= 6 and assist_window_timer <= 0.0 and not inversion_active and not inversion_pending and randf() < 0.55:
		_schedule_wall_inversion()

	if time_elapsed >= next_burst_time and assist_window_timer <= 0.0 and not spawn_burst_active:
		next_burst_time = time_elapsed + randf_range(10.0, 16.0)
		_trigger_spawn_burst()

func _schedule_wall_inversion():
	if assist_window_timer > 0.0 or super_active:
		return
	inversion_pending = true
	inversion_countdown = INVERSION_WARNING_TIME
	_show_warning("SWITCHING!")
	_vibrate(30)
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
	_update_lane_hud(true)
	_show_warning("INVERSION!")
	_flash_screen(Color(1, 0, 1, 0.15))
	_vibrate(50)

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
	_update_lane_hud(true)
	_show_warning("NORMAL")

func _trigger_spawn_burst():
	spawn_burst_active = true
	_show_warning("BURST!")
	_vibrate(40)
	var count = randi_range(2, 4) if assist_window_timer > 0.0 else randi_range(3, 6)
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

func _update_spawn_wait_time():
	var wait_target = spawn_rate + adaptive_spawn_offset
	if assist_window_timer > 0.0:
		wait_target += 0.12
	wait_target = clamp(wait_target, 0.55, 2.4)

	if super_active:
		spawn_timer.wait_time = max(0.35, wait_target * super_spawn_multiplier)
	elif not super_cooldown_active:
		spawn_timer.wait_time = wait_target

func _evaluate_adaptive_flow():
	var pressure = clamp(float(2 - lives) / 2.0, 0.0, 1.0)
	var performance = clamp(float(recent_hit_window - recent_miss_window * 2) / 8.0, -1.0, 1.0)
	var target_flow = clamp(0.5 + performance * 0.35 - pressure * 0.22, 0.0, 1.0)

	adaptive_flow_score = lerp(adaptive_flow_score, target_flow, 0.35)
	var target_offset = lerp(ADAPTIVE_SPAWN_MAX, ADAPTIVE_SPAWN_MIN, adaptive_flow_score)
	adaptive_spawn_offset = clamp(lerp(adaptive_spawn_offset, target_offset, 0.45), ADAPTIVE_SPAWN_MIN, ADAPTIVE_SPAWN_MAX)

	recent_hit_window = int(round(float(recent_hit_window) * 0.55))
	recent_miss_window = int(round(float(recent_miss_window) * 0.60))
	_update_spawn_wait_time()

func _spawn_ball():
	if super_cooldown_active:
		return
	if super_active:
		_spawn_super_stream_pair()
		return
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
	if super_active:
		grav *= SUPER_GRAVITY_MULT
	ball.gravity_scale = min(grav, 2.4)

	if time_elapsed >= WARMUP_TIME and randf() < accel_pattern_chance:
		ball.has_accel_pattern = true
		ball.base_gravity = ball.gravity_scale
		ball.accel_timer = randf() * TAU

	ball.walls_inverted = walls_inverted
	if super_active:
		ball.super_mode = true
		ball.universal_wall_match = true
		ball.auto_directed = false
	ball.bomb_exploded.connect(_on_bomb_exploded)
	ball.ball_missed.connect(_on_ball_missed)

	ball.scale = Vector2(0.0, 0.0)
	add_child(ball)
	var st = create_tween()
	st.tween_property(ball, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_spawn_direction_hint(ball)

	if super_active:
		_super_direct_ball(ball)

func _spawn_super_stream_pair():
	if not ball_scene:
		return

	var bounds = _get_super_bounds()
	var left_bound = bounds.x
	var right_bound = bounds.y
	var mid_x = (left_bound + right_bound) * 0.5

	var base_y = -120.0
	var end_y = randf_range(900.0, 1200.0)
	var amp_scale = lerp(0.82, 1.0, fx_super_pulse_scale)
	var duration_scale = lerp(1.12, 1.0, fx_super_pulse_scale)
	var amplitude = randf_range(80.0, 160.0) * amp_scale
	var duration = randf_range(0.9, 1.2) * duration_scale

	var cyan = ball_scene.instantiate() as BallDragThrow
	var magenta = ball_scene.instantiate() as BallDragThrow
	if not cyan or not magenta:
		return

	cyan.ball_type = BallDragThrow.BallType.CYAN
	magenta.ball_type = BallDragThrow.BallType.MAGENTA

	cyan.position = Vector2(mid_x - 40.0, base_y)
	magenta.position = Vector2(mid_x + 40.0, base_y)

	_setup_super_stream_ball(cyan, right_bound - 10.0, end_y, amplitude, duration, 0.0)
	_setup_super_stream_ball(magenta, left_bound + 10.0, end_y, amplitude, duration, PI)

	add_child(cyan)
	add_child(magenta)

	_spawn_direction_hint(cyan)
	_spawn_direction_hint(magenta)

func _setup_super_stream_ball(ball: BallDragThrow, target_x: float, end_y: float, amp: float, duration: float, phase: float):
	var pre_layer = ball.collision_layer
	var pre_mask = ball.collision_mask

	ball.walls_inverted = walls_inverted
	ball.super_mode = true
	ball.universal_wall_match = true
	ball.auto_directed = true
	ball.freeze = true
	ball.gravity_scale = 0.0
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.angular_velocity = randf_range(-8.0, 8.0)
	ball.is_thrown = true
	ball.throw_time = Time.get_ticks_msec() / 1000.0

	var start = ball.global_position
	var end = Vector2(target_x, end_y)
	var lateral_freq = randf_range(1.6, 2.4)
	var detail_freq = randf_range(4.2, 6.8)
	var vertical_freq = randf_range(2.6, 4.0)
	var roll_sign = -1.0 if randf() < 0.5 else 1.0

	var tween = create_tween()
	tween.tween_method(func(t):
		if not is_instance_valid(ball):
			return
		var env = sin(t * PI)
		var primary = sin(t * TAU * lateral_freq + phase) * amp
		var detail = sin(t * TAU * detail_freq + phase * 1.7) * (amp * 0.24)
		var x = lerp(start.x, end.x, t) + (primary + detail) * env
		var y = lerp(start.y, end.y, t) + sin(t * TAU * vertical_freq + phase * 0.35) * (amp * 0.12) * env
		ball.global_position = Vector2(x, y)
		ball.rotation = roll_sign * (0.18 * sin(t * TAU * 3.2 + phase) + 0.08 * sin(t * TAU * 7.4 + phase * 0.7))
	, 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	tween.tween_callback(func():
		if not is_instance_valid(ball):
			return
		ball.freeze = false
		ball.collision_layer = pre_layer
		ball.collision_mask = pre_mask
		var dir = Vector2(target_x - ball.global_position.x, randf_range(520.0, 760.0)).normalized()
		ball.linear_velocity = dir * randf_range(1700.0, 2000.0)
	)

func _on_laser_ball_destroyed(points: int, ball: BallDragThrow):
	if not combo_frozen:
		combo += 1
		balls_scored += 1
		if combo > max_combo:
			max_combo = combo
	wrong_wall_streak = 0
	recent_hit_window = min(recent_hit_window + 1, 20)
	if assist_window_timer > 0.0 and combo >= 6:
		assist_window_timer = max(0.0, assist_window_timer - 1.5)

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
			_show_streak_banner("BONUS +50", Color(1, 1, 0.2, 1))
			_spawn_powerup_for_streak()
		elif combo == 10:
			_show_streak_banner("OVERDRIVE READY", Color(0, 1, 1, 1))
			_activate_overdrive()
		elif combo == 15:
			_show_streak_banner("SHIELD READY", Color(1, 0, 1, 1))
			_grant_shield()
		elif combo == 12:
			_activate_double_points()
		elif combo == 25:
			_show_streak_banner("MEGA BONUS", Color(1.0, 0.95, 0.35, 1.0))
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
		_vibrate(40)
	else:
		_vibrate(20)

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
	var milestones = [5, 10, 12, 15, 25]
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
	var goal_name = _get_goal_name(next)
	streak_label.text = "GOAL  " + goal_name + "   " + str(min(combo, next)) + "/" + str(next)
	match next:
		5:
			streak_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.9))
		10:
			streak_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 0.95))
		12:
			streak_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.45, 0.95))
		15:
			streak_label.add_theme_color_override("font_color", Color(1.0, 0.5, 1.0, 0.95))
		25:
			streak_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
		_:
			streak_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1, 0.85))
	if overdrive_active:
		streak_label.add_theme_color_override("font_color", Color(1, 1, 0.55, 1))

func _get_goal_name(milestone: int) -> String:
	match milestone:
		5:
			return "POWER DROP"
		10:
			return "OVERDRIVE"
		12:
			return "2X BOOST"
		15:
			return "SHIELD"
		25:
			return "MEGA BONUS"
	return "SURVIVE"

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
	if guardian_available or guardian_used_once:
		return
	guardian_available = true
	_update_guardian_label()
	_show_streak_banner("SHIELD CHARGED", Color(0.4, 1, 0.6, 1))

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
	for child in get_children():
		if child is PowerupDrop:
			var p_child = child as PowerupDrop
			if p_child.powerup_type == PowerupDrop.PowerupType.SUPER:
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
				_regain_life()
				_update_ui()
				_show_streak_banner("+1 LIFE", Color(0.3, 1, 0.4, 1))
		PowerupDrop.PowerupType.SHIELD_WALL:
			_arm_shield()
		PowerupDrop.PowerupType.SUPER:
			_start_super_mode()


func _arm_shield():
	shield_pending = true
	shield_pending_timer = SHIELD_PENDING_DURATION
	_show_streak_banner("SHIELD READY", Color(0.4, 1, 0.6, 1))

func _should_trigger_shield() -> bool:
	if not kill_zone:
		return false
	var kill_y = kill_zone.global_position.y - 20.0
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			if ball.ball_type == BallDragThrow.BallType.BOMB:
				continue
			if ball.is_grabbed or ball.is_thrown:
				continue
			var vy = ball.linear_velocity.y
			if vy < 80.0:
				continue
			var dist = kill_y - ball.global_position.y
			if dist <= 0.0:
				return true
			var t = dist / vy
			if t <= SHIELD_TRIGGER_TIME:
				return true
	return false

func _activate_shield_wall():
	if has_node("ShieldWall"):
		var w = $ShieldWall
		w.queue_free()
	var wall = ShieldWall.new()
	wall.name = "ShieldWall"
	wall.position = Vector2(540, 2350)
	add_child(wall)
	_show_streak_banner("SHIELD!", Color(0.4, 1, 0.6, 1))
	await get_tree().create_timer(SHIELD_ACTIVE_DURATION).timeout
	if is_instance_valid(wall):
		wall.queue_free()

func _start_super_mode():
	if super_active:
		return
	if inversion_pending:
		inversion_pending = false
		_stop_inversion_warning()
	super_active = true
	super_timer = SUPER_DURATION
	combo_frozen = true
	super_fx_phase = randf() * TAU
	super_spark_timer = 0.18 * fx_super_spark_interval_scale
	_sync_balls_super_state(true)
	_capture_existing_balls_for_super()
	_spawn_super_visuals()
	_update_lane_hud(true)
	_show_warning("MEGA BONUS!")
	_flash_screen(Color(1, 0.95, 0.35, 0.18))
	_update_spawn_wait_time()
	# Bonus music feel (pitch only, actual track later)
	if music_player:
		music_player.pitch_scale = bonus_pitch

func _capture_existing_balls_for_super():
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			if ball.ball_type == BallDragThrow.BallType.BOMB:
				continue
			if ball.is_grabbed:
				continue
			if ball.auto_directed:
				continue
			_super_direct_ball(ball)

func _end_super_mode():
	super_active = false
	combo_frozen = false
	super_spark_timer = 0.0
	_sync_balls_super_state(false)
	_restore_super_visuals()
	_update_wall_glow()
	_update_lane_hud(true)
	_show_warning("RULES BACK")
	_update_spawn_wait_time()
	if music_player:
		music_player.pitch_scale = 1.0
	_start_super_cooldown()

func _start_super_cooldown():
	if super_cooldown_active:
		return
	super_cooldown_active = true
	spawn_timer.stop()
	var cooldown = get_tree().create_timer(SUPER_COOLDOWN)
	cooldown.timeout.connect(func():
		super_cooldown_active = false
		if not game_over and game_started:
			_update_spawn_wait_time()
			spawn_timer.start()
	)

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
			ss.set_shader_parameter("intensity", 0.22 * fx_scanline_scale)
	_spawn_super_vignette()
	_spawn_super_burst()

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
	_clear_super_vignette()

func _spawn_super_vignette():
	if super_vignette and is_instance_valid(super_vignette):
		super_vignette.queue_free()
	super_vignette = ColorRect.new()
	super_vignette.name = "SuperVignette"
	super_vignette.color = Color(1, 0.95, 0.25, 0.07)
	super_vignette.anchors_preset = Control.PRESET_FULL_RECT
	super_vignette.anchor_right = 1.0
	super_vignette.anchor_bottom = 1.0
	super_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(super_vignette)

	if super_pulse_tween and super_pulse_tween.is_valid():
		super_pulse_tween.kill()
	super_pulse_tween = null

func _clear_super_vignette():
	if super_pulse_tween and super_pulse_tween.is_valid():
		super_pulse_tween.kill()
	super_pulse_tween = null
	if super_vignette and is_instance_valid(super_vignette):
		var vt = create_tween()
		vt.tween_property(super_vignette, "modulate:a", 0.0, 0.3)
		vt.tween_callback(super_vignette.queue_free)
	super_vignette = null

func _spawn_super_burst():
	var center = Vector2(540, 920)
	var textures = [tex_star4, tex_star6, tex_cross]
	for i in range(textures.size()):
		var p = GPUParticles2D.new()
		p.position = center
		p.emitting = false
		p.amount = int(max(8.0, round(18.0 * fx_super_spark_amount_scale)))
		p.lifetime = lerp(0.8, 1.1, fx_super_pulse_scale)
		p.one_shot = true
		p.explosiveness = 1.0
		p.texture = textures[i]

		var mat = ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 30.0
		mat.spread = 180.0
		mat.initial_velocity_min = lerp(170.0, 220.0, fx_super_pulse_scale)
		mat.initial_velocity_max = lerp(300.0, 420.0, fx_super_pulse_scale)
		mat.gravity = Vector3(0, 260, 0)
		mat.scale_min = 0.5
		mat.scale_max = 1.3
		mat.color = Color(1.0, 0.95, 0.4, 1.0)
		mat.angular_velocity_min = -120.0
		mat.angular_velocity_max = 120.0
		mat.particle_flag_disable_z = true

		p.process_material = mat
		add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)

func _tick_super_fx(delta: float):
	super_fx_phase += delta

	if super_vignette and is_instance_valid(super_vignette):
		var beat = 0.5 + 0.5 * sin(super_fx_phase * 5.6)
		var tint = 0.5 + 0.5 * sin(super_fx_phase * 2.3 + 0.8)
		super_vignette.color = Color(
			1.0,
			lerp(0.88, 1.0, tint),
			lerp(0.20, 0.40, beat),
			lerp(0.05, 0.15, beat) * fx_flash_scale
		)

	if background and background.material and background.material is ShaderMaterial:
		var sm = background.material as ShaderMaterial
		var accent = 0.23 + 0.11 * (0.5 + 0.5 * sin(super_fx_phase * 4.2))
		sm.set_shader_parameter("accent_strength", accent * fx_super_pulse_scale)

	if scanlines and scanlines.material and scanlines.material is ShaderMaterial:
		var ss = scanlines.material as ShaderMaterial
		var scan = 0.16 + 0.10 * (0.5 + 0.5 * sin(super_fx_phase * 6.8 + 1.1))
		ss.set_shader_parameter("intensity", scan * fx_scanline_scale)

	if left_glow and right_glow:
		var glow_beat = 0.5 + 0.5 * sin(super_fx_phase * 7.2)
		var alpha = lerp(0.22, 0.42, glow_beat) * fx_super_pulse_scale
		left_glow.color = Color(0, 1, 1, alpha) if walls_inverted else Color(1, 0, 1, alpha)
		right_glow.color = Color(1, 0, 1, alpha) if walls_inverted else Color(0, 1, 1, alpha)

	super_spark_timer -= delta
	if super_spark_timer <= 0.0:
		super_spark_timer = (SUPER_SPARK_INTERVAL + randf_range(-0.12, 0.12)) * fx_super_spark_interval_scale
		var spark_pos = Vector2(randf_range(220.0, 860.0), randf_range(420.0, 1550.0))
		_spawn_super_spark(spark_pos)

func _spawn_super_spark(pos: Vector2):
	var p = GPUParticles2D.new()
	p.position = pos
	p.emitting = false
	var min_amount = int(max(4.0, round(8.0 * fx_super_spark_amount_scale)))
	var max_amount = int(max(float(min_amount), round(12.0 * fx_super_spark_amount_scale)))
	p.amount = randi_range(min_amount, max_amount)
	p.lifetime = lerp(0.4, 0.55, fx_super_pulse_scale)
	p.one_shot = true
	p.explosiveness = 1.0
	p.texture = tex_star4 if randi() % 2 == 0 else tex_cross

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.spread = 180.0
	mat.initial_velocity_min = lerp(90.0, 130.0, fx_super_pulse_scale)
	mat.initial_velocity_max = lerp(180.0, 260.0, fx_super_pulse_scale)
	mat.gravity = Vector3(0, 160, 0)
	mat.scale_min = 0.25
	mat.scale_max = 0.85
	var color_pick = randi() % 3
	if color_pick == 0:
		mat.color = Color(1.0, 0.95, 0.45, 0.95)
	elif color_pick == 1:
		mat.color = Color(0.4, 1.0, 1.0, 0.9)
	else:
		mat.color = Color(1.0, 0.45, 1.0, 0.9)
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.particle_flag_disable_z = true

	p.process_material = mat
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _auto_direct_balls():
	var mid_y = get_viewport_rect().size.y * 0.5
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			if ball.ball_type == BallDragThrow.BallType.BOMB:
				continue
			ball.super_mode = true
			ball.universal_wall_match = true
			if ball.is_grabbed:
				continue
			if ball.auto_directed:
				continue

			if ball.is_thrown:
				_super_direct_ball(ball)
				continue

			if ball.global_position.y > mid_y:
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

func _super_direct_ball(ball: BallDragThrow):
	if not ball:
		return
	if ball.ball_type == BallDragThrow.BallType.BOMB:
		return
	ball.super_mode = true
	ball.universal_wall_match = true

	var bounds = _get_super_bounds()
	var left_bound = bounds.x
	var right_bound = bounds.y

	var target_x = right_bound - 10.0
	if ball.ball_type == BallDragThrow.BallType.CYAN:
		target_x = right_bound - 10.0 if not walls_inverted else left_bound + 10.0
	elif ball.ball_type == BallDragThrow.BallType.MAGENTA:
		target_x = left_bound + 10.0 if not walls_inverted else right_bound - 10.0
	elif ball.ball_type == BallDragThrow.BallType.YELLOW:
		target_x = right_bound - 10.0 if ball.global_position.x > 540 else left_bound + 10.0

	var start = ball.global_position
	var end = Vector2(target_x, randf_range(900.0, 1200.0))
	var dir_x = 1.0 if target_x > start.x else -1.0

	var tight = randf() < 0.5
	var mid1 = start + Vector2(
		randf_range(60.0, 140.0) * dir_x if tight else randf_range(120.0, 260.0) * dir_x,
		randf_range(140.0, 220.0) if tight else randf_range(220.0, 360.0)
	)
	var mid2 = start + Vector2(
		randf_range(180.0, 320.0) * dir_x if tight else randf_range(300.0, 520.0) * dir_x,
		randf_range(280.0, 460.0) if tight else randf_range(420.0, 660.0)
	)
	if randi() % 2 == 0:
		var arc = randf_range(120.0, 200.0) if tight else randf_range(200.0, 320.0)
		mid1.y -= arc
		mid2.y += arc

	var min_y = 120.0
	var max_y = 2200.0
	mid1.x = clamp(mid1.x, left_bound, right_bound)
	mid2.x = clamp(mid2.x, left_bound, right_bound)
	mid1.y = clamp(mid1.y, min_y, max_y)
	mid2.y = clamp(mid2.y, min_y, max_y)
	end.x = clamp(end.x, left_bound + 5.0, right_bound - 5.0)
	end.y = clamp(end.y, min_y, max_y)

	# Choreo: disable collisions while we arc, then re-enable and fling into the wall
	var pre_layer = ball.collision_layer
	var pre_mask = ball.collision_mask
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.freeze = true
	ball.gravity_scale = 0.0
	ball.angular_velocity = randf_range(-6.0, 6.0)
	ball.auto_directed = true
	ball.is_thrown = true
	ball.throw_time = Time.get_ticks_msec() / 1000.0

	var t = create_tween()
	t.tween_property(ball, "global_position", mid1, randf_range(0.18, 0.26)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(ball, "global_position", mid2, randf_range(0.18, 0.26)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(ball, "global_position", end, randf_range(0.2, 0.3)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func():
		if not is_instance_valid(ball):
			return
		ball.freeze = false
		ball.collision_layer = pre_layer
		ball.collision_mask = pre_mask
		var dir = Vector2(target_x - ball.global_position.x, randf_range(520.0, 760.0)).normalized()
		ball.linear_velocity = dir * randf_range(1600.0, 1850.0)
	)

func _get_super_bounds() -> Vector2:
	var left = 40.0
	var right = 1040.0
	if laser_left and laser_right:
		left = laser_left.global_position.x + 25.0 + SUPER_BOUNDS_MARGIN
		right = laser_right.global_position.x - 25.0 - SUPER_BOUNDS_MARGIN
	return Vector2(left, right)

func _get_effective_bomb_chance() -> float:
	if super_active or bomb_pause_timer > 0.0:
		return 0.0
	var chance = bomb_chance
	if first_run_active:
		if time_elapsed < 20.0:
			return 0.0
		if time_elapsed < 30.0:
			var t = (time_elapsed - 20.0) / 10.0
			chance = bomb_chance * t
		else:
			chance = bomb_chance
	elif time_elapsed < 15.0:
		return 0.0
	elif time_elapsed < 25.0:
		var t2 = (time_elapsed - 15.0) / 10.0
		chance = bomb_chance * t2

	if assist_window_timer > 0.0:
		chance *= 0.45
	if lives <= 1:
		chance *= 0.55

	var flow_scale = lerp(0.7, 1.15, adaptive_flow_score)
	chance *= flow_scale
	return clamp(chance, 0.0, 0.30)

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
	if not guardian_available or guardian_used_once:
		return false
	guardian_available = false
	guardian_used_once = true
	lives = 1
	assist_window_timer = max(assist_window_timer, ASSIST_WINDOW_DURATION + 2.0)
	bomb_pause_timer = max(bomb_pause_timer, BOMB_PAUSE_ON_MISS + 2.0)
	_update_spawn_wait_time()
	_restore_guardian_life_dot()
	_update_guardian_label()
	_update_ui()
	_show_streak_banner("SAVE!", Color(0, 1, 0.6, 1))
	_flash_screen(Color(0, 1, 0.6, 0.18))
	_vibrate(80)
	return true

func _restore_guardian_life_dot():
	if life_dots.size() == 0:
		return
	var dot = life_dots[0]
	dot.visible = true
	dot.modulate = Color(0, 1, 0, 0)
	dot.scale = Vector2(0.2, 0.2)
	var t = create_tween()
	t.tween_property(dot, "scale", Vector2(1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(dot, "modulate", Color(1, 1, 1, 1), 0.15)
	t.tween_property(dot, "scale", Vector2(1.0, 1.0), 0.1)

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

func _sync_balls_super_state(active: bool):
	for child in get_children():
		if child is BallDragThrow:
			var ball = child as BallDragThrow
			if ball.ball_type == BallDragThrow.BallType.BOMB:
				ball.super_mode = false
				ball.universal_wall_match = false
				continue
			ball.super_mode = active
			ball.universal_wall_match = active
			if not active:
				ball.auto_directed = false

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
	recent_hit_window = min(recent_hit_window + 2, 20)
	assist_window_timer = max(0.0, assist_window_timer - 1.0)
	_update_spawn_wait_time()
	_vibrate(60)
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
	recent_miss_window = min(recent_miss_window + 1, 20)
	adaptive_flow_score = max(0.0, adaptive_flow_score - 0.08)
	if wrong_wall_streak >= 2:
		wrong_wall_streak = 0
		_on_ball_missed()
		return
	combo = 0
	if lives <= 2:
		assist_window_timer = max(assist_window_timer, 2.0)
		_update_spawn_wait_time()
	_update_ui()
	_flash_screen(Color(1, 0.5, 0, 0.15))
	_vibrate(50)

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
	_vibrate(60)

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
	recent_miss_window = min(recent_miss_window + 2, 20)

	adaptive_flow_score = max(0.0, adaptive_flow_score - 0.2)
	adaptive_spawn_offset = clamp(adaptive_spawn_offset + 0.08, ADAPTIVE_SPAWN_MIN, ADAPTIVE_SPAWN_MAX)
	assist_window_timer = max(assist_window_timer, ASSIST_WINDOW_DURATION + (1.5 if lives <= 1 else 0.0))
	bomb_pause_timer = max(bomb_pause_timer, BOMB_PAUSE_ON_MISS + (1.5 if lives <= 1 else 0.0))
	if inversion_pending:
		inversion_pending = false
		_stop_inversion_warning()
	_update_spawn_wait_time()
	if lives <= 2:
		_show_warning("BREATHING ROOM")

	_play_sfx(snd_miss, -6.0, 0.7)
	_vibrate(80)
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

	if slow_mo_vignette_tween and slow_mo_vignette_tween.is_valid():
		slow_mo_vignette_tween.kill()
	slow_mo_vignette_tween = create_tween().set_loops()
	slow_mo_vignette_tween.tween_property(slow_mo_vignette, "color:a", 0.15, 0.6).set_ease(Tween.EASE_IN_OUT)
	slow_mo_vignette_tween.tween_property(slow_mo_vignette, "color:a", 0.04, 0.6).set_ease(Tween.EASE_IN_OUT)

	_show_warning("LAST LIFE!")

	# Pulse the remaining life dot
	if life_dots.size() > 0 and life_dots[0].visible:
		if slow_mo_life_dot_tween and slow_mo_life_dot_tween.is_valid():
			slow_mo_life_dot_tween.kill()
		slow_mo_life_dot_tween = create_tween().set_loops()
		slow_mo_life_dot_tween.tween_property(life_dots[0], "modulate", Color(1, 0.3, 0.3, 1), 0.4)
		slow_mo_life_dot_tween.tween_property(life_dots[0], "modulate", Color(1, 1, 1, 1), 0.4)

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

	if slow_mo_vignette_tween and slow_mo_vignette_tween.is_valid():
		slow_mo_vignette_tween.kill()
	slow_mo_vignette_tween = null
	if slow_mo_life_dot_tween and slow_mo_life_dot_tween.is_valid():
		slow_mo_life_dot_tween.kill()
	slow_mo_life_dot_tween = null
	if life_dots.size() > 0:
		life_dots[0].modulate = Color(1, 1, 1, 1)

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
	var a = clamp(color.a * fx_flash_scale, 0.0, 0.45)
	flash.color = Color(color.r, color.g, color.b, a)
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
	_vibrate(150)
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
	if game_over:
		return
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
		if combo > 3:
			combo_label.text = "CHAIN x" + str(combo)
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

	if super_active or ball.universal_wall_match:
		hint.text = "ANY"
		hint.add_theme_color_override("font_color", Color(1, 0.95, 0.35, 0.55))
		hint.position = ball.position + Vector2(-24, -65)
		add_child(hint)

		var t_super = create_tween()
		t_super.tween_property(hint, "position:y", hint.position.y - 35, 0.4).set_ease(Tween.EASE_OUT)
		t_super.parallel().tween_property(hint, "modulate:a", 0.0, 0.4)
		t_super.tween_callback(hint.queue_free)
		return

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
