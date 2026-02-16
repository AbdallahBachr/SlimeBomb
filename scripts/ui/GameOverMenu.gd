extends Control

@onready var score_label = $Panel/VBoxContainer/ScoreLabel
@onready var high_score_label = $Panel/VBoxContainer/HighScoreLabel
@onready var combo_label = $Panel/VBoxContainer/ComboLabel
@onready var retry_button = $Panel/VBoxContainer/RetryButton
@onready var menu_button = $Panel/VBoxContainer/MenuButton
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel

var current_score: int = 0
var high_score: int = 0
var max_combo: int = 0
var time_survived: String = "0:00"
var accuracy_pct: float = 0.0
var run_report: Dictionary = {}
var settings_menu: Control = null
var ui_sfx: AudioStream = preload("res://assets/sounds/UImenu.wav")

func _ready():
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	visible = false

	_add_settings_button()
	_load_settings_overlay()

func _add_settings_button():
	var settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 55)
	settings_button.add_theme_font_size_override("font_size", 18)
	settings_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	settings_button.add_theme_color_override("font_hover_color", Color(0, 1, 1, 1))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.35, 0.45, 1)
	style.set_corner_radius_all(25)
	settings_button.add_theme_stylebox_override("normal", style)

	var vbox = $Panel/VBoxContainer
	vbox.add_child(settings_button)
	settings_button.pressed.connect(_on_settings)

func _load_settings_overlay():
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func _on_settings():
	_play_ui()
	if settings_menu:
		settings_menu.show_settings()

func show_game_over(score: int, combo: int, time_str: String = "0:00", accuracy: float = 0.0, report: Dictionary = {}):
	current_score = score
	max_combo = combo
	time_survived = time_str
	accuracy_pct = accuracy
	run_report = report.duplicate(true)

	_load_high_score()

	var is_new_best = current_score > high_score
	if is_new_best:
		high_score = current_score
		_save_high_score()

	visible = true
	_animate_entrance(is_new_best)

func _animate_entrance(is_new_best: bool):
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0

	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4)
	t.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	await t.finished

	# Score counter animation
	var count_tween = create_tween()
	count_tween.set_ease(Tween.EASE_OUT)
	count_tween.set_trans(Tween.TRANS_CUBIC)

	var counter = {"value": 0}
	count_tween.tween_method(func(val):
		counter.value = int(val)
		score_label.text = str(counter.value)
	, 0.0, float(current_score), 0.8)

	await count_tween.finished

	if is_new_best:
		high_score_label.text = "NEW BEST!"
		high_score_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		var pulse = create_tween().set_loops(3)
		pulse.tween_property(high_score_label, "modulate:a", 0.4, 0.2)
		pulse.tween_property(high_score_label, "modulate:a", 1.0, 0.2)
	else:
		high_score_label.text = "BEST  " + str(high_score)
		high_score_label.add_theme_color_override("font_color", Color(1, 0, 1, 0.8))

	combo_label.text = "MAX COMBO  x" + str(max_combo)

	# Stats row: time + accuracy
	var vbox = $Panel/VBoxContainer
	if vbox.has_node("StatsRow"):
		vbox.get_node("StatsRow").queue_free()
	var stats_container = HBoxContainer.new()
	stats_container.name = "StatsRow"
	stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_container.add_theme_constant_override("separation", 40)
	vbox.add_child(stats_container)
	vbox.move_child(stats_container, combo_label.get_index() + 1)

	var time_label = Label.new()
	time_label.text = time_survived
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", Color(0, 1, 1, 0.8))
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(time_label)

	var accuracy_label = Label.new()
	accuracy_label.text = "%d%%" % [int(accuracy_pct)]
	accuracy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accuracy_label.add_theme_font_size_override("font_size", 18)
	if accuracy_pct >= 80:
		accuracy_label.add_theme_color_override("font_color", Color(1, 1, 0, 0.8))
	elif accuracy_pct >= 50:
		accuracy_label.add_theme_color_override("font_color", Color(0, 1, 0, 0.8))
	else:
		accuracy_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 0.8))
	accuracy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_container.add_child(accuracy_label)

	# Animate stats fade in
	stats_container.modulate.a = 0.0
	var st = create_tween()
	st.tween_property(stats_container, "modulate:a", 1.0, 0.4).set_delay(0.2)

	if vbox.has_node("RankLabel"):
		vbox.get_node("RankLabel").queue_free()
	var rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.text = _build_rank_text()
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 22)
	rank_label.add_theme_color_override("font_color", _get_rank_color(rank_label.text))
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rank_label)
	vbox.move_child(rank_label, stats_container.get_index() + 1)

	rank_label.modulate.a = 0.0
	var rt = create_tween()
	rt.tween_property(rank_label, "modulate:a", 1.0, 0.45).set_delay(0.35)
	_render_run_rewards(vbox, rank_label.get_index())
	if retry_button:
		retry_button.grab_focus()

func _render_run_rewards(vbox: VBoxContainer, insert_after_index: int):
	var dynamic_nodes = [
		"RunRewardLabel",
		"SessionLabel",
		"LevelRewardLabel",
		"MissionClearLabel",
		"MissionHeader",
		"MissionRow0",
		"MissionRow1",
		"MissionRow2"
	]
	for node_name in dynamic_nodes:
		if vbox.has_node(node_name):
			vbox.get_node(node_name).queue_free()

	if run_report.is_empty():
		return

	var next_index = insert_after_index + 1
	var run_coins = int(run_report.get("run_coins", 0))
	var base_run_coins = int(run_report.get("base_run_coins", run_coins))
	var coin_multiplier = float(run_report.get("coin_multiplier", 1.0))
	var session_coin_multiplier = float(run_report.get("coin_multiplier_session", 1.0))
	var run_xp = int(run_report.get("run_xp", 0))
	if run_coins > 0 or run_xp > 0:
		var reward_label = Label.new()
		reward_label.name = "RunRewardLabel"
		if base_run_coins != run_coins and base_run_coins > 0:
			reward_label.text = "REWARD  +%d COINS (x%.2f)  +%d XP" % [run_coins, coin_multiplier, run_xp]
		else:
			reward_label.text = "REWARD  +%d COINS  +%d XP" % [run_coins, run_xp]
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.add_theme_font_size_override("font_size", 18)
		reward_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9, 0.92))
		reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(reward_label)
		vbox.move_child(reward_label, next_index)
		next_index += 1

	var session_streak = int(run_report.get("session_streak", 0))
	if session_streak > 0:
		var session_label = Label.new()
		session_label.name = "SessionLabel"
		session_label.text = "SESSION STREAK x%d  |  REMATCH BONUS +%d%%" % [session_streak, int(round((session_coin_multiplier - 1.0) * 100.0))]
		session_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		session_label.add_theme_font_size_override("font_size", 15)
		session_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.95))
		session_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(session_label)
		vbox.move_child(session_label, next_index)
		next_index += 1

	var level_ups = int(run_report.get("level_ups", 0))
	if level_ups > 0:
		var level_bonus_coins = int(run_report.get("level_bonus_coins", 0))
		var level_label = Label.new()
		level_label.name = "LevelRewardLabel"
		level_label.text = "LEVEL UP x%d  +%d COINS" % [level_ups, level_bonus_coins]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 0.95))
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(level_label)
		vbox.move_child(level_label, next_index)
		next_index += 1

	var mission_completions = run_report.get("mission_completions", [])
	if mission_completions is Array and mission_completions.size() > 0:
		var clear_label = Label.new()
		clear_label.name = "MissionClearLabel"
		clear_label.text = "DAILY CLEARS  +%d" % mission_completions.size()
		clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clear_label.add_theme_font_size_override("font_size", 16)
		clear_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 0.95))
		clear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(clear_label)
		vbox.move_child(clear_label, next_index)
		next_index += 1

	var missions = run_report.get("daily_missions", [])
	if not (missions is Array) or missions.is_empty():
		return

	var completed_count = 0
	for mission in missions:
		if mission is Dictionary and bool(mission.get("completed", false)):
			completed_count += 1

	var mission_header = Label.new()
	mission_header.name = "MissionHeader"
	mission_header.text = "DAILY MISSIONS  %d/%d" % [completed_count, missions.size()]
	mission_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_header.add_theme_font_size_override("font_size", 15)
	mission_header.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0, 0.9))
	mission_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(mission_header)
	vbox.move_child(mission_header, next_index)
	next_index += 1

	for i in range(min(3, missions.size())):
		var mission_data = missions[i]
		if not (mission_data is Dictionary):
			continue
		var title = str(mission_data.get("title", "Mission"))
		var completed = bool(mission_data.get("completed", false))
		var progress = float(mission_data.get("progress", 0.0))
		var target = float(mission_data.get("target", 1.0))
		var unit = str(mission_data.get("unit", ""))
		var line = Label.new()
		line.name = "MissionRow" + str(i)
		line.text = "%s %s  %s" % ["OK" if completed else "..", title.to_upper(), _format_mission_progress(progress, target, unit)]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 14)
		line.add_theme_color_override("font_color", Color(0.62, 0.95, 0.72, 0.9) if completed else Color(0.82, 0.86, 0.95, 0.8))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line)
		vbox.move_child(line, next_index)
		next_index += 1

func _format_mission_progress(progress: float, target: float, unit: String) -> String:
	var p = int(round(progress))
	var t = int(round(max(target, 1.0)))
	if unit == "sec":
		return "%ds/%ds" % [p, t]
	if unit.is_empty():
		return "%d/%d" % [p, t]
	return "%d/%d %s" % [p, t, unit]

func _load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			high_score = file.get_32()
			file.close()

func _save_high_score():
	var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()

func _on_retry():
	_play_ui()
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.has_method("begin_retry_run"):
		gs.begin_retry_run()
	get_tree().change_scene_to_file("res://scenes/minigames/DragThrowGame.tscn")

func _on_menu():
	_play_ui()
	var gs = get_node_or_null("/root/GlobalSettings")
	if gs and gs.has_method("end_retry_session"):
		gs.end_retry_session()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_retry()
		get_viewport().set_input_as_handled()

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

func _build_rank_text() -> String:
	var sec_parts = time_survived.split(":")
	var total_seconds = 0
	if sec_parts.size() == 2:
		total_seconds = int(sec_parts[0]) * 60 + int(sec_parts[1])

	var perf = float(current_score) * 0.0012 + float(max_combo) * 1.8 + accuracy_pct * 0.55 + float(total_seconds) * 0.04
	if perf >= 360.0:
		return "RANK S+  |  LEGENDARY RUN"
	if perf >= 280.0:
		return "RANK S  |  ELITE CONTROL"
	if perf >= 210.0:
		return "RANK A  |  SHARP PLAY"
	if perf >= 145.0:
		return "RANK B  |  SOLID RUN"
	if perf >= 95.0:
		return "RANK C  |  KEEP PUSHING"
	return "RANK D  |  WARMUP"

func _get_rank_color(rank_text: String) -> Color:
	if rank_text.begins_with("RANK S+"):
		return Color(1.0, 0.95, 0.35, 1.0)
	if rank_text.begins_with("RANK S"):
		return Color(0.4, 1.0, 1.0, 1.0)
	if rank_text.begins_with("RANK A"):
		return Color(0.6, 1.0, 0.7, 0.95)
	if rank_text.begins_with("RANK B"):
		return Color(1.0, 1.0, 1.0, 0.9)
	if rank_text.begins_with("RANK C"):
		return Color(1.0, 0.75, 0.45, 0.9)
	return Color(1.0, 0.45, 0.45, 0.9)
