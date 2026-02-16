extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var title_label = $TitleLabel
@onready var high_score_label = $HighScoreLabel
@onready var subtitle_label = $SubtitleLabel
@onready var how_to_button = $HowToButton

var settings_menu: Control = null
var music_player: AudioStreamPlayer = null
var tutorial_overlay: Control = null
var ui_sfx: AudioStream = preload("res://assets/sounds/UImenu.wav")
var profile_panel: Panel = null
var profile_level_label: Label = null
var profile_daily_label: Label = null
var store_button: Button = null
var store_overlay: Control = null
var upgrade_panel: Panel = null
var upgrade_coin_label: Label = null
var upgrade_rows: Dictionary = {}
const UPGRADE_ORDER: Array[String] = ["coin_boost", "clutch_window", "drop_luck"]
const UPGRADE_TITLE: Dictionary = {
	"coin_boost": "COIN BOOST",
	"clutch_window": "CLUTCH",
	"drop_luck": "DROP LUCK"
}

func _ready():
	_reset_retry_session()
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if how_to_button:
		how_to_button.pressed.connect(_on_how_to_pressed)

	_load_settings_overlay()
	_load_high_score()
	_setup_profile_hud()
	_refresh_profile_hud()
	_setup_store_button()
	_setup_upgrade_shop()
	_refresh_upgrade_shop()
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
	if store_button:
		store_button.modulate.a = 0.0

	title_label.position.y -= 80
	var orig_title_y = title_label.position.y + 80

	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)

	t.tween_property(title_label, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(title_label, "position:y", orig_title_y, 0.6)
	t.tween_property(subtitle_label, "modulate:a", 1.0, 0.4).set_delay(0.1)
	t.tween_property(high_score_label, "modulate:a", 1.0, 0.4).set_delay(0.1)
	if store_button:
		t.tween_property(store_button, "modulate:a", 1.0, 0.28).set_delay(0.04)
	t.tween_property(play_button, "modulate:a", 1.0, 0.3).set_delay(0.06)
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
	_play_ui()
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.has_method("begin_fresh_run"):
		gs.begin_fresh_run()
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
	_play_ui()
	if settings_menu:
		settings_menu.show_settings()

func _on_quit_pressed():
	_play_ui()
	get_tree().quit()

func _on_how_to_pressed():
	_play_ui()
	_show_tutorial()

func _setup_store_button():
	store_button = Button.new()
	store_button.name = "StoreButton"
	store_button.text = "STORE"
	store_button.anchor_left = 1.0
	store_button.anchor_top = 0.0
	store_button.anchor_right = 1.0
	store_button.anchor_bottom = 0.0
	store_button.offset_left = -300.0
	store_button.offset_top = 40.0
	store_button.offset_right = -40.0
	store_button.offset_bottom = 114.0
	store_button.mouse_filter = Control.MOUSE_FILTER_STOP
	store_button.focus_mode = Control.FOCUS_ALL
	store_button.add_theme_font_size_override("font_size", 22)
	store_button.add_theme_color_override("font_color", Color(0.07, 0.08, 0.12, 1.0))
	store_button.add_theme_color_override("font_hover_color", Color(0.03, 0.04, 0.08, 1.0))
	store_button.add_theme_color_override("font_pressed_color", Color(0.03, 0.04, 0.08, 1.0))
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.86, 0.36, 0.98)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.96, 0.74, 0.18, 1.0)
	normal.set_corner_radius_all(26)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.92, 0.52, 1.0)
	hover.set_border_width_all(2)
	hover.border_color = Color(1.0, 0.82, 0.26, 1.0)
	hover.set_corner_radius_all(26)
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.96, 0.78, 0.28, 0.98)
	pressed.set_border_width_all(2)
	pressed.border_color = Color(0.94, 0.7, 0.16, 1.0)
	pressed.set_corner_radius_all(26)
	store_button.add_theme_stylebox_override("normal", normal)
	store_button.add_theme_stylebox_override("hover", hover)
	store_button.add_theme_stylebox_override("pressed", pressed)
	add_child(store_button)
	store_button.pressed.connect(_on_store_pressed)

func _on_store_pressed():
	_play_ui()
	_refresh_profile_hud()
	_refresh_upgrade_shop()
	if store_overlay:
		store_overlay.visible = true
		var row = upgrade_rows.get(UPGRADE_ORDER[0], {})
		var btn = row.get("button") as Button
		if btn:
			btn.grab_focus()

func _hide_store_overlay():
	if store_overlay:
		store_overlay.visible = false

func _show_tutorial():
	if tutorial_overlay and is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = true
		return
	_build_tutorial_overlay()

func _build_tutorial_overlay():
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.anchors_preset = Control.PRESET_FULL_RECT
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tutorial_overlay)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.68)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(overlay)

	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390.0
	panel.offset_top = -480.0
	panel.offset_right = 390.0
	panel.offset_bottom = 480.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.985)
	style.set_border_width_all(3)
	style.border_color = Color(0.9, 0.95, 1.0, 0.55)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)
	tutorial_overlay.add_child(panel)

	var title = Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(780, 88)
	title.position = Vector2(0, 24)
	panel.add_child(title)

	var body = Label.new()
	body.text = "1. Catch a falling ball.\n2. Drag to aim.\n3. Release to throw.\n\nRULES\n- Match the ball color with the wall color.\n- YELLOW can go to either wall.\n- Never touch a BOMB.\n\nSCORING\n- Keep your chain alive to multiply points.\n- Perfect and clutch hits give bonus score."
	body.add_theme_font_size_override("font_size", 27)
	body.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0, 1.0))
	body.add_theme_constant_override("line_spacing", 8)
	body.position = Vector2(52, 138)
	body.size = Vector2(676, 630)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(body)

	var close = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(260, 70)
	close.position = Vector2(260, 860)
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", Color(0.08, 0.1, 0.16, 1.0))
	close.add_theme_color_override("font_hover_color", Color(0.05, 0.07, 0.12, 1.0))
	var close_normal = StyleBoxFlat.new()
	close_normal.bg_color = Color(1.0, 0.88, 0.42, 1.0)
	close_normal.set_border_width_all(2)
	close_normal.border_color = Color(0.96, 0.78, 0.22, 1.0)
	close_normal.set_corner_radius_all(20)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(1.0, 0.93, 0.56, 1.0)
	close_hover.set_border_width_all(2)
	close_hover.border_color = Color(1.0, 0.84, 0.3, 1.0)
	close_hover.set_corner_radius_all(20)
	var close_pressed = StyleBoxFlat.new()
	close_pressed.bg_color = Color(0.96, 0.8, 0.3, 1.0)
	close_pressed.set_border_width_all(2)
	close_pressed.border_color = Color(0.92, 0.72, 0.18, 1.0)
	close_pressed.set_corner_radius_all(20)
	close.add_theme_stylebox_override("normal", close_normal)
	close.add_theme_stylebox_override("hover", close_hover)
	close.add_theme_stylebox_override("pressed", close_pressed)
	panel.add_child(close)
	close.pressed.connect(func():
		_play_ui()
		tutorial_overlay.visible = false
	)

func _play_ui():
	if not ui_sfx:
		return
	var p = AudioStreamPlayer.new()
	p.stream = ui_sfx
	p.volume_db = -6.0
	p.bus = &"SFX"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _setup_profile_hud():
	profile_panel = Panel.new()
	profile_panel.name = "ProfileHud"
	profile_panel.position = Vector2(28, 28)
	profile_panel.size = Vector2(720, 130)
	profile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.78)
	style.set_border_width_all(2)
	style.border_color = Color(0.0, 1.0, 1.0, 0.28)
	style.set_corner_radius_all(20)
	profile_panel.add_theme_stylebox_override("panel", style)
	add_child(profile_panel)

	var box = VBoxContainer.new()
	box.name = "ProfileBox"
	box.position = Vector2(20, 18)
	box.size = Vector2(680, 94)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	profile_panel.add_child(box)

	profile_level_label = Label.new()
	profile_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	profile_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_level_label.add_theme_font_size_override("font_size", 20)
	profile_level_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.95))
	profile_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_level_label.clip_text = true
	profile_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(profile_level_label)

	profile_daily_label = Label.new()
	profile_daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	profile_daily_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_daily_label.add_theme_font_size_override("font_size", 17)
	profile_daily_label.add_theme_color_override("font_color", Color(0.58, 0.93, 0.88, 0.92))
	profile_daily_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_daily_label.clip_text = true
	profile_daily_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(profile_daily_label)

func _refresh_profile_hud():
	if not profile_level_label or not profile_daily_label:
		return

	var gs = get_node_or_null("/root/GlobalSettings")
	if not gs:
		profile_level_label.text = "LEVEL 1  |  COINS 0"
		profile_daily_label.text = "DAILY MISSIONS UNAVAILABLE"
		return

	var level_value = int(gs.get("player_level"))
	var coin_value = int(gs.get("coins"))
	profile_level_label.text = "LEVEL %d  |  COINS %d" % [level_value, coin_value]

	var missions: Array = []
	if gs.has_method("get_daily_mission_status"):
		missions = gs.call("get_daily_mission_status")
	if missions.is_empty():
		profile_daily_label.text = "DAILY MISSIONS UNAVAILABLE"
		return

	var completed = 0
	var next_text = "ALL DAILY MISSIONS COMPLETE"
	for mission_data in missions:
		if not (mission_data is Dictionary):
			continue
		if bool(mission_data.get("completed", false)):
			completed += 1
			continue
		var title = str(mission_data.get("title", "MISSION")).to_upper()
		var progress = float(mission_data.get("progress", 0.0))
		var target = float(mission_data.get("target", 1.0))
		var unit = str(mission_data.get("unit", ""))
		next_text = "%s  %s" % [title, _format_mission_progress(progress, target, unit)]
		break

	profile_daily_label.text = "DAILY %d/%d  |  %s" % [completed, missions.size(), next_text]

func _setup_upgrade_shop():
	store_overlay = Control.new()
	store_overlay.name = "StoreOverlay"
	store_overlay.anchors_preset = Control.PRESET_FULL_RECT
	store_overlay.anchor_right = 1.0
	store_overlay.anchor_bottom = 1.0
	store_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	store_overlay.visible = false
	add_child(store_overlay)

	var dim = ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.56)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	store_overlay.add_child(dim)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_hide_store_overlay()
	)

	upgrade_panel = Panel.new()
	upgrade_panel.name = "UpgradePanel"
	upgrade_panel.anchor_left = 0.5
	upgrade_panel.anchor_top = 0.5
	upgrade_panel.anchor_right = 0.5
	upgrade_panel.anchor_bottom = 0.5
	upgrade_panel.offset_left = -390.0
	upgrade_panel.offset_top = -310.0
	upgrade_panel.offset_right = 390.0
	upgrade_panel.offset_bottom = 310.0
	upgrade_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.985)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.84, 0.32, 0.9)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	upgrade_panel.add_theme_stylebox_override("panel", style)
	store_overlay.add_child(upgrade_panel)

	var title = Label.new()
	title.text = "UPGRADE STORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.66, 1.0))
	title.position = Vector2(0, 24)
	title.size = Vector2(780, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_child(title)

	upgrade_coin_label = Label.new()
	upgrade_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_coin_label.add_theme_font_size_override("font_size", 23)
	upgrade_coin_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	upgrade_coin_label.position = Vector2(0, 70)
	upgrade_coin_label.size = Vector2(780, 34)
	upgrade_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_child(upgrade_coin_label)

	var close = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(140, 52)
	close.position = Vector2(614, 22)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0, 1.0))
	close.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.68, 1.0))
	var close_normal = StyleBoxFlat.new()
	close_normal.bg_color = Color(0.12, 0.15, 0.22, 0.98)
	close_normal.set_border_width_all(2)
	close_normal.border_color = Color(0.55, 0.66, 0.9, 0.72)
	close_normal.set_corner_radius_all(18)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(0.18, 0.22, 0.3, 1.0)
	close_hover.set_border_width_all(2)
	close_hover.border_color = Color(0.92, 0.8, 0.34, 0.9)
	close_hover.set_corner_radius_all(18)
	var close_pressed = StyleBoxFlat.new()
	close_pressed.bg_color = Color(0.1, 0.12, 0.18, 0.98)
	close_pressed.set_border_width_all(2)
	close_pressed.border_color = Color(0.46, 0.58, 0.84, 0.8)
	close_pressed.set_corner_radius_all(18)
	close.add_theme_stylebox_override("normal", close_normal)
	close.add_theme_stylebox_override("hover", close_hover)
	close.add_theme_stylebox_override("pressed", close_pressed)
	close.pressed.connect(func():
		_play_ui()
		_hide_store_overlay()
	)
	upgrade_panel.add_child(close)

	var list = VBoxContainer.new()
	list.position = Vector2(30, 128)
	list.size = Vector2(720, 454)
	list.add_theme_constant_override("separation", 16)
	upgrade_panel.add_child(list)

	for upgrade_id in UPGRADE_ORDER:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 124)
		row.add_theme_constant_override("separation", 16)
		list.add_child(row)

		var info = Label.new()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 23)
		info.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.clip_text = false
		row.add_child(info)

		var buy = Button.new()
		buy.custom_minimum_size = Vector2(216, 72)
		buy.add_theme_font_size_override("font_size", 22)
		buy.add_theme_color_override("font_color", Color(0.05, 0.06, 0.1, 1.0))
		buy.add_theme_color_override("font_hover_color", Color(0.03, 0.04, 0.08, 1.0))
		buy.add_theme_color_override("font_pressed_color", Color(0.03, 0.04, 0.08, 1.0))
		buy.add_theme_color_override("font_disabled_color", Color(0.72, 0.76, 0.84, 0.82))
		var buy_normal = StyleBoxFlat.new()
		buy_normal.bg_color = Color(0.95, 0.86, 0.36, 0.98)
		buy_normal.set_border_width_all(2)
		buy_normal.border_color = Color(0.94, 0.76, 0.2, 1.0)
		buy_normal.set_corner_radius_all(20)
		var buy_hover = StyleBoxFlat.new()
		buy_hover.bg_color = Color(1.0, 0.92, 0.5, 1.0)
		buy_hover.set_border_width_all(2)
		buy_hover.border_color = Color(0.98, 0.8, 0.24, 1.0)
		buy_hover.set_corner_radius_all(20)
		var buy_pressed = StyleBoxFlat.new()
		buy_pressed.bg_color = Color(0.93, 0.8, 0.3, 0.98)
		buy_pressed.set_border_width_all(2)
		buy_pressed.border_color = Color(0.9, 0.7, 0.18, 1.0)
		buy_pressed.set_corner_radius_all(20)
		var buy_disabled = StyleBoxFlat.new()
		buy_disabled.bg_color = Color(0.16, 0.18, 0.24, 0.95)
		buy_disabled.set_border_width_all(2)
		buy_disabled.border_color = Color(0.36, 0.4, 0.5, 0.8)
		buy_disabled.set_corner_radius_all(20)
		buy.add_theme_stylebox_override("normal", buy_normal)
		buy.add_theme_stylebox_override("hover", buy_hover)
		buy.add_theme_stylebox_override("pressed", buy_pressed)
		buy.add_theme_stylebox_override("disabled", buy_disabled)
		buy.mouse_filter = Control.MOUSE_FILTER_STOP
		buy.focus_mode = Control.FOCUS_ALL
		buy.pressed.connect(_on_upgrade_buy.bind(upgrade_id))
		row.add_child(buy)

		upgrade_rows[upgrade_id] = {"label": info, "button": buy}

func _refresh_upgrade_shop():
	if upgrade_rows.is_empty():
		return
	var gs = get_node_or_null("/root/GlobalSettings")
	if upgrade_coin_label:
		if gs:
			upgrade_coin_label.text = "COINS  %d" % [int(gs.get("coins"))]
		else:
			upgrade_coin_label.text = "COINS  0"
	for upgrade_id in UPGRADE_ORDER:
		if not upgrade_rows.has(upgrade_id):
			continue
		var row: Dictionary = upgrade_rows[upgrade_id]
		var info = row.get("label") as Label
		var buy = row.get("button") as Button
		if not info or not buy:
			continue
		if not gs:
			info.text = "%s  Lv0/0\nData unavailable" % [str(UPGRADE_TITLE.get(upgrade_id, upgrade_id))]
			buy.text = "--"
			buy.disabled = true
			continue
		var level = 0
		var max_level = 0
		var price = -1
		if gs.has_method("get_upgrade_level"):
			level = int(gs.call("get_upgrade_level", upgrade_id))
		if gs.has_method("get_upgrade_max_level"):
			max_level = int(gs.call("get_upgrade_max_level", upgrade_id))
		if gs.has_method("get_upgrade_price"):
			price = int(gs.call("get_upgrade_price", upgrade_id))
		var effect_text = ""
		match upgrade_id:
			"coin_boost":
				effect_text = "Gain +8% run coins per level."
			"clutch_window":
				effect_text = "Adds +0.26s clutch window per level."
			"drop_luck":
				effect_text = "Spawns useful drops more often."
		info.text = "%s  Lv%d/%d\n%s" % [str(UPGRADE_TITLE.get(upgrade_id, upgrade_id)), level, max_level, effect_text]
		if price <= 0 or level >= max_level:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "BUY  %d C" % [price]
			buy.disabled = int(gs.get("coins")) < price

func _on_upgrade_buy(upgrade_id: String):
	_play_ui()
	var gs = get_node_or_null("/root/GlobalSettings")
	if not gs or not gs.has_method("buy_upgrade"):
		return
	var result = gs.call("buy_upgrade", upgrade_id)
	if result is Dictionary and bool(result.get("ok", false)):
		_refresh_profile_hud()
	_refresh_upgrade_shop()

func _reset_retry_session():
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.has_method("end_retry_session"):
		gs.end_retry_session()

func _format_mission_progress(progress: float, target: float, unit: String) -> String:
	var p = int(round(progress))
	var t = int(round(max(target, 1.0)))
	if unit == "sec":
		return "%ds/%ds" % [p, t]
	if unit.is_empty():
		return "%d/%d" % [p, t]
	return "%d/%d %s" % [p, t, unit]
