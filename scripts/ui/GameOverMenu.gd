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

func _ready():
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	visible = false

func show_game_over(score: int, combo: int):
	current_score = score
	max_combo = combo

	_load_high_score()

	var is_new_best = current_score > high_score
	if is_new_best:
		high_score = current_score
		_save_high_score()

	visible = true
	_animate_entrance(is_new_best)

func _animate_entrance(is_new_best: bool):
	# Setup initial
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0

	# Panel apparait
	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4)
	t.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	await t.finished

	# Score counter animation (compte de 0 au score final)
	var count_tween = create_tween()
	count_tween.set_ease(Tween.EASE_OUT)
	count_tween.set_trans(Tween.TRANS_CUBIC)

	var counter = {"value": 0}
	count_tween.tween_method(func(val):
		counter.value = int(val)
		score_label.text = str(counter.value)
	, 0.0, float(current_score), 0.8)

	await count_tween.finished

	# Afficher les stats
	if is_new_best:
		high_score_label.text = "NEW BEST!"
		high_score_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		# Pulsation sur new best
		var pulse = create_tween().set_loops(3)
		pulse.tween_property(high_score_label, "modulate:a", 0.4, 0.2)
		pulse.tween_property(high_score_label, "modulate:a", 1.0, 0.2)
	else:
		high_score_label.text = "BEST  " + str(high_score)
		high_score_label.add_theme_color_override("font_color", Color(1, 0, 1, 0.8))

	combo_label.text = "MAX COMBO  x" + str(max_combo)

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
	get_tree().reload_current_scene()

func _on_menu():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
