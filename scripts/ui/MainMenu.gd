extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var title_label = $TitleLabel
@onready var high_score_label = $HighScoreLabel
@onready var subtitle_label = $SubtitleLabel

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_load_high_score()
	_animate_entrance()

func _load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			var score = file.get_32()
			high_score_label.text = "BEST  " + str(score)
			file.close()
	else:
		high_score_label.text = "BEST  0"

func _animate_entrance():
	# Tout invisible au départ
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	high_score_label.modulate.a = 0.0
	play_button.modulate.a = 0.0
	settings_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	# Titre slide depuis le haut
	title_label.position.y -= 80
	var orig_title_y = title_label.position.y + 80

	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)

	# Titre
	t.tween_property(title_label, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(title_label, "position:y", orig_title_y, 0.6)

	# Subtitle
	t.tween_property(subtitle_label, "modulate:a", 1.0, 0.4).set_delay(0.1)

	# High score
	t.tween_property(high_score_label, "modulate:a", 1.0, 0.4).set_delay(0.1)

	# Boutons en cascade
	t.tween_property(play_button, "modulate:a", 1.0, 0.3).set_delay(0.1)
	t.tween_property(settings_button, "modulate:a", 1.0, 0.3).set_delay(0.05)
	t.tween_property(quit_button, "modulate:a", 1.0, 0.3).set_delay(0.05)

	# Pulsation titre
	await t.finished
	_animate_title_pulse()

func _animate_title_pulse():
	var tween = create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "scale", Vector2(1.03, 1.03), 1.5)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.5)

func _on_play_pressed():
	# Transition de sortie
	var t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/minigames/DragThrowGame.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed():
	get_tree().quit()
