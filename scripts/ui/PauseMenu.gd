extends Control

signal resume_pressed
signal menu_pressed

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var menu_button = $Panel/VBoxContainer/MenuButton
@onready var panel = $Panel

func _ready():
	resume_button.pressed.connect(_on_resume)
	menu_button.pressed.connect(_on_menu)
	visible = false

func show_pause():
	visible = true
	get_tree().paused = true

	# Animation d'entrée
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

func _on_menu():
	menu_pressed.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
