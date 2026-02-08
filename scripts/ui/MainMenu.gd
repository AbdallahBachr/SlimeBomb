extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var title_label = $TitleLabel
@onready var high_score_label = $HighScoreLabel
@onready var subtitle_label = $SubtitleLabel

var settings_menu: Control = null
var music_player: AudioStreamPlayer = null

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_load_settings_overlay()
	_load_high_score()
	_setup_background_particles()
	_start_menu_music()
	_animate_entrance()

func _load_settings_overlay():
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func _load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			var score = file.get_32()
			high_score_label.text = "BEST  " + str(score)
			file.close()
	else:
		high_score_label.text = "BEST  0"

func _start_menu_music():
	music_player = AudioStreamPlayer.new()
	music_player.stream = load("res://assets/sounds/JoshuaMcLean-MountainTrials.mp3")
	music_player.volume_db = -12.0
	music_player.bus = &"Music"
	add_child(music_player)
	music_player.play()
	music_player.finished.connect(func(): music_player.play())

func _setup_background_particles():
	# Floating neon dots in background
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 6.0
	particles.z_index = -10
	particles.position = Vector2(540, 1200)

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 1200, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.particle_flag_disable_z = true

	# Cyan/magenta color range
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(0, 1, 1, 0.15))
	color_ramp.set_color(1, Color(1, 0, 1, 0.15))
	var color_tex = GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	# Fade in/out over lifetime
	var alpha_curve = Gradient.new()
	alpha_curve.set_color(0, Color(1, 1, 1, 0))
	alpha_curve.add_point(0.3, Color(1, 1, 1, 1))
	alpha_curve.add_point(0.7, Color(1, 1, 1, 1))
	alpha_curve.set_color(alpha_curve.get_point_count() - 1, Color(1, 1, 1, 0))
	var alpha_tex = GradientTexture1D.new()
	alpha_tex.gradient = alpha_curve
	mat.alpha_curve = alpha_tex

	particles.process_material = mat

	# Use star particle as texture
	particles.texture = load("res://assets/particles/star4.svg")

	add_child(particles)
	move_child(particles, 1)  # After background

func _animate_entrance():
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	high_score_label.modulate.a = 0.0
	play_button.modulate.a = 0.0
	settings_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	title_label.position.y -= 80
	var orig_title_y = title_label.position.y + 80

	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)

	t.tween_property(title_label, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(title_label, "position:y", orig_title_y, 0.6)
	t.tween_property(subtitle_label, "modulate:a", 1.0, 0.4).set_delay(0.1)
	t.tween_property(high_score_label, "modulate:a", 1.0, 0.4).set_delay(0.1)
	t.tween_property(play_button, "modulate:a", 1.0, 0.3).set_delay(0.1)
	t.tween_property(settings_button, "modulate:a", 1.0, 0.3).set_delay(0.05)
	t.tween_property(quit_button, "modulate:a", 1.0, 0.3).set_delay(0.05)

	await t.finished
	_animate_title_pulse()

func _animate_title_pulse():
	var tween = create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "scale", Vector2(1.03, 1.03), 1.5)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.5)

func _on_play_pressed():
	# Fade out music + visuals
	if music_player:
		var mt = create_tween()
		mt.tween_property(music_player, "volume_db", -40.0, 0.3)

	var t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/minigames/DragThrowGame.tscn")

func _on_settings_pressed():
	if settings_menu:
		settings_menu.show_settings()

func _on_quit_pressed():
	get_tree().quit()
