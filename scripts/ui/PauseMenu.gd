extends Control

signal resume_pressed
signal menu_pressed

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var menu_button = $Panel/VBoxContainer/MenuButton
@onready var panel = $Panel

var settings_menu: Control = null

func _ready():
	resume_button.pressed.connect(_on_resume)
	menu_button.pressed.connect(_on_menu)
	visible = false

	# Add settings button dynamically between resume and menu
	_add_settings_button()
	# Load settings overlay
	_load_settings_overlay()

func _add_settings_button():
	var settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(400, 65)
	settings_button.add_theme_font_size_override("font_size", 28)
	settings_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	settings_button.add_theme_color_override("font_hover_color", Color(0, 1, 1, 1))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 1)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.5, 1)
	style.set_corner_radius_all(25)
	settings_button.add_theme_stylebox_override("normal", style)

	var vbox = $Panel/VBoxContainer
	vbox.add_child(settings_button)
	vbox.move_child(settings_button, 1)  # Between Resume and Menu

	settings_button.pressed.connect(_on_settings)

func _load_settings_overlay():
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func show_pause():
	visible = true
	get_tree().paused = true

	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3)
	t.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)

func hide_pause():
	var t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.15)
	t.parallel().tween_property(panel, "modulate:a", 0.0, 0.15)
	await t.finished
	visible = false
	get_tree().paused = false

func _on_resume():
	resume_pressed.emit()
	hide_pause()

func _on_settings():
	if settings_menu:
		settings_menu.show_settings()

func _on_menu():
	menu_pressed.emit()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
