extends Node2D

# Références aux nodes
@onready var spawner_marker: Marker2D = $Spawner
@onready var spawn_timer: Timer = $SpawnTimer
@onready var difficulty_timer: Timer = $DifficultyTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var high_score_label: Label = $CanvasLayer/HighScoreLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var lives_label: Label = $CanvasLayer/LivesLabel
@onready var swipe_input: SwipeInputManager = $SwipeInputManager
@onready var camera: Camera2D = $Camera2D

# Scene de la balle
@export var ball_scene: PackedScene

# Paramètres de spawn
@export var initial_spawn_rate: float = 1.5  # Secondes entre chaque spawn
@export var min_spawn_rate: float = 0.4  # Spawn rate minimum (max difficulté)
@export var spawn_rate_decrease: float = 0.05  # Diminution tous les X secondes

# Paramètres de difficulté
@export var difficulty_increase_interval: float = 10.0  # Augmenter difficulté tous les 10s
@export var bomb_spawn_chance: float = 0.15  # 15% de chance de spawn bombe

# Variables de jeu
var score: int = 0
var high_score: int = 0
var lives: int = 3
var combo: int = 0
var max_combo: int = 0
var current_spawn_rate: float
var game_over: bool = false
var time_elapsed: float = 0.0

# Screen shake
var shake_amount: float = 0.0
var shake_decay: float = 5.0

func _ready():
	# Charger le high score
	_load_high_score()

	# Init spawn rate
	current_spawn_rate = initial_spawn_rate
	spawn_timer.wait_time = current_spawn_rate

	# Connecter les timers
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	difficulty_timer.timeout.connect(_on_difficulty_timer_timeout)

	# Démarrer les timers
	spawn_timer.start()
	difficulty_timer.wait_time = difficulty_increase_interval
	difficulty_timer.start()

	# UI
	_update_ui()

	# Camera setup
	if camera:
		camera.position = Vector2(540, 1200)  # Centre de l'écran

func _process(delta):
	if game_over:
		return

	time_elapsed += delta

	# Screen shake
	if shake_amount > 0:
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
	else:
		if camera:
			camera.offset = Vector2.ZERO

func _on_spawn_timer_timeout():
	if game_over:
		return

	_spawn_ball()

func _spawn_ball():
	if not ball_scene:
		push_error("Ball scene not assigned!")
		return

	var ball = ball_scene.instantiate() as Ball
	if not ball:
		return

	# Position aléatoire en haut de l'écran
	# Pour mobile 1080px: spawner entre 80 et 1000 pour laisser de la marge
	var spawn_x = randf_range(80, 1000)  # Marge de sécurité pour mobile
	var spawn_y = -100  # Au-dessus de l'écran

	ball.position = Vector2(spawn_x, spawn_y)

	# Debug: vérifier la position de spawn
	print("🎲 Spawning ball at X=", spawn_x)

	# Déterminer le type de balle
	var rand_val = randf()
	if rand_val < bomb_spawn_chance:
		ball.ball_type = Ball.BallType.BOMB
	elif rand_val < 0.35 + (bomb_spawn_chance / 2):
		ball.ball_type = Ball.BallType.CYAN
	elif rand_val < 0.7 + (bomb_spawn_chance / 2):
		ball.ball_type = Ball.BallType.MAGENTA
	else:
		ball.ball_type = Ball.BallType.YELLOW

	# Augmenter la gravité avec la difficulté (commence lent, devient rapide)
	var difficulty_factor = 0.3 + (time_elapsed / 30.0)  # Commence à 0.3, +1.0 après 30s
	ball.gravity_scale = difficulty_factor

	# Connecter les signaux
	ball.ball_swiped_correctly.connect(_on_ball_swiped_correctly)
	ball.ball_swiped_wrong.connect(_on_ball_swiped_wrong)
	ball.bomb_touched.connect(_on_bomb_touched)

	add_child(ball)

func _on_difficulty_timer_timeout():
	# Augmenter la difficulté
	if current_spawn_rate > min_spawn_rate:
		current_spawn_rate -= spawn_rate_decrease
		current_spawn_rate = max(current_spawn_rate, min_spawn_rate)
		spawn_timer.wait_time = current_spawn_rate

	# Augmenter la chance de bombes progressivement
	bomb_spawn_chance = min(bomb_spawn_chance + 0.02, 0.35)  # Max 35%

func _on_ball_swiped_correctly(points: int):
	# Bon swipe !
	combo += 1
	max_combo = max(max_combo, combo)

	# Bonus de combo
	var combo_multiplier = 1.0 + (combo * 0.1)  # +10% par combo
	var total_points = int(points * combo_multiplier)

	score += total_points
	_update_ui()

	# Feedback visuel
	_show_score_popup(total_points, true)

	# Son (à implémenter)
	# play_sound("swipe_success")

func _on_ball_swiped_wrong():
	# Mauvais swipe ou balle ratée
	combo = 0
	lives -= 1
	_update_ui()

	# Petit shake
	add_screen_shake(10.0)

	# Feedback visuel
	_flash_screen(Color(1, 0, 0, 0.3))

	# Son (à implémenter)
	# play_sound("swipe_fail")

	if lives <= 0:
		_game_over()

func _on_bomb_touched():
	# GAME OVER IMMÉDIAT !
	add_screen_shake(50.0)
	_flash_screen(Color(1, 0.5, 0, 0.5))
	_game_over()

func _game_over():
	game_over = true
	spawn_timer.stop()
	difficulty_timer.stop()

	# Sauvegarder high score
	if score > high_score:
		high_score = score
		_save_high_score()

	# Afficher écran de game over
	await get_tree().create_timer(1.0).timeout
	_show_game_over_screen()

func _show_game_over_screen():
	# Créer un écran de game over simple
	var game_over_panel = ColorRect.new()
	game_over_panel.color = Color(0, 0, 0, 0.8)
	game_over_panel.size = get_viewport_rect().size
	game_over_panel.z_index = 100

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 200)
	vbox.size = Vector2(400, 400)

	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var score_text = Label.new()
	score_text.text = "Score: " + str(score)
	score_text.add_theme_font_size_override("font_size", 40)
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var high_score_text = Label.new()
	high_score_text.text = "Best: " + str(high_score)
	high_score_text.add_theme_font_size_override("font_size", 30)
	high_score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var combo_text = Label.new()
	combo_text.text = "Max Combo: " + str(max_combo) + "x"
	combo_text.add_theme_font_size_override("font_size", 30)
	combo_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var retry_button = Button.new()
	retry_button.text = "RETRY"
	retry_button.custom_minimum_size = Vector2(300, 80)
	retry_button.add_theme_font_size_override("font_size", 40)
	retry_button.pressed.connect(_restart_game)

	vbox.add_child(title)
	vbox.add_child(score_text)
	vbox.add_child(high_score_text)
	vbox.add_child(combo_text)
	vbox.add_child(retry_button)

	game_over_panel.add_child(vbox)
	$CanvasLayer.add_child(game_over_panel)

func _restart_game():
	get_tree().reload_current_scene()

func _update_ui():
	if score_label:
		score_label.text = "Score: " + str(score)

	if high_score_label:
		high_score_label.text = "Best: " + str(high_score)

	if combo_label:
		if combo > 1:
			combo_label.text = "Combo x" + str(combo)
			combo_label.visible = true
			# Animer le combo
			var tween = create_tween()
			tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)
		else:
			combo_label.visible = false

	if lives_label:
		lives_label.text = "❤️ " + str(lives)

func _show_score_popup(points: int, is_success: bool):
	# Popup de score qui apparaît et disparaît
	var popup = Label.new()
	popup.text = "+" + str(points)
	popup.add_theme_font_size_override("font_size", 50)
	popup.add_theme_color_override("font_color", Color.YELLOW if is_success else Color.RED)
	popup.position = Vector2(get_viewport_rect().size.x / 2 - 50, 500)
	popup.z_index = 50

	$CanvasLayer.add_child(popup)

	# Animation
	var tween = create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 100, 0.8)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
	await tween.finished
	popup.queue_free()

func add_screen_shake(amount: float):
	shake_amount = amount

func _flash_screen(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport_rect().size
	flash.z_index = 99
	$CanvasLayer.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	await tween.finished
	flash.queue_free()

func _save_high_score():
	var save_file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if save_file:
		save_file.store_32(high_score)
		save_file.close()

func _load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var save_file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if save_file:
			high_score = save_file.get_32()
			save_file.close()
