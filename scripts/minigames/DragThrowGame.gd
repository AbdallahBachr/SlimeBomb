extends Node2D

# Références
@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var lives_label: Label = $CanvasLayer/LivesLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var game_over_menu = $CanvasLayer/GameOverMenu
@onready var laser_left = $LaserWallLeft
@onready var laser_right = $LaserWallRight
@onready var camera: CameraShake = $Camera2D
@onready var kill_zone = $KillZone

# Scene
@export var ball_scene: PackedScene

# Game state
var score: int = 0
var lives: int = 3
var combo: int = 0
var time_elapsed: float = 0.0
var spawn_rate: float = 1.5
var game_over: bool = false

func _ready():
	# Setup timer
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	spawn_timer.start()

	# Connect laser walls
	laser_left.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_right.ball_destroyed.connect(_on_laser_ball_destroyed)

	# Connect kill zone
	if kill_zone:
		kill_zone.ball_missed.connect(_on_ball_missed)

	_update_ui()

func _process(delta):
	# Gestion de la pause
	if Input.is_action_just_pressed("ui_cancel"):  # ESC
		if not game_over:
			if pause_menu.visible:
				pause_menu.hide_pause()
			else:
				pause_menu.show_pause()
			return

	if game_over or get_tree().paused:
		return

	time_elapsed += delta

	# Difficulté progressive
	if int(time_elapsed) % 10 == 0 and int(time_elapsed) > 0:
		spawn_rate = max(0.5, spawn_rate - 0.05)
		spawn_timer.wait_time = spawn_rate

func _spawn_ball():
	if not ball_scene:
		return

	var ball = ball_scene.instantiate() as BallDragThrow
	if not ball:
		return

	# Position dans la zone visible
	var spawn_x = randf_range(100, 980)
	var spawn_y = -100

	ball.position = Vector2(spawn_x, spawn_y)

	# Type aléatoire (Color Switch style)
	var rand = randf()
	if rand < 0.1:
		ball.ball_type = BallDragThrow.BallType.BOMB
	elif rand < 0.4:
		ball.ball_type = BallDragThrow.BallType.CYAN
	elif rand < 0.7:
		ball.ball_type = BallDragThrow.BallType.MAGENTA
	else:
		ball.ball_type = BallDragThrow.BallType.YELLOW

	# Augmenter gravité avec temps
	var grav = 0.3 + (time_elapsed / 30.0)
	ball.gravity_scale = grav

	# Connect signals (seulement bombe maintenant)
	ball.bomb_exploded.connect(_on_bomb_exploded)

	add_child(ball)

func _on_laser_ball_destroyed(points: int):
	# Appelé quand une balle est détruite par un laser
	combo += 1
	var total = int(points * (1.0 + combo * 0.1))
	score += total
	_update_ui()

	# Camera shake selon le combo
	if camera:
		if combo > 5:
			camera.medium_shake()
		else:
			camera.small_shake()

func _on_ball_missed():
	# Balle ratée, perd 1 vie
	lives -= 1
	combo = 0  # Reset combo

	# Camera shake pour feedback
	if camera:
		camera.small_shake()

	_update_ui()

	if lives <= 0:
		_game_over()

func _on_bomb_exploded():
	# Gros shake pour l'explosion!
	if camera:
		camera.big_shake()

	_game_over()

func _game_over():
	game_over = true
	spawn_timer.stop()

	await get_tree().create_timer(1.0).timeout

	# Afficher le menu de game over avec les stats
	game_over_menu.show_game_over(score, combo)

func _update_ui():
	if score_label:
		score_label.text = str(score)
		# Animation de pop sur le score
		_animate_label(score_label)

	if lives_label:
		lives_label.text = "❤️ " + str(lives)

	if combo_label:
		if combo > 1:
			combo_label.text = "x" + str(combo)
			combo_label.visible = true
			# Animation de pop sur le combo
			_animate_label(combo_label, 1.2)
		else:
			combo_label.visible = false

func _animate_label(label: Label, scale_to: float = 1.15):
	"""Animation smooth de pop pour les labels"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Pop
	tween.tween_property(label, "scale", Vector2(scale_to, scale_to), 0.1)
	# Return
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
