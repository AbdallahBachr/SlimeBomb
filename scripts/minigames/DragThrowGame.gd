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
@onready var pause_button = $CanvasLayer/PauseButton

# Scene
@export var ball_scene: PackedScene

# Game state
var score: int = 0
var lives: int = 3
var combo: int = 0
var time_elapsed: float = 0.0
var spawn_rate: float = 2.5  # Commence lent
var game_over: bool = false
var last_difficulty_step: int = 0

# Late-game variants
var walls_inverted: bool = false
var inversion_active: bool = false
var inversion_timer: float = 0.0
const INVERSION_DURATION: float = 15.0  # 15s d'inversion
var accel_pattern_chance: float = 0.0  # % de balles avec pattern accel
var bomb_chance: float = 0.1  # 10% au debut
var spawn_burst_active: bool = false
var burst_count: int = 0

# Warning label for events
var warning_label: Label = null

func _ready():
	# Setup timer - commence lent
	spawn_timer.wait_time = spawn_rate
	spawn_timer.timeout.connect(_spawn_ball)
	spawn_timer.start()
	last_difficulty_step = 0

	# Connect laser walls
	laser_left.ball_destroyed.connect(_on_laser_ball_destroyed)
	laser_right.ball_destroyed.connect(_on_laser_ball_destroyed)

	# Connect kill zone
	if kill_zone:
		kill_zone.ball_missed.connect(_on_ball_missed)

	# Connect pause button
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

	# Create warning label for late-game events
	_setup_warning_label()

	_update_ui()

func _setup_warning_label():
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 60)
	warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	warning_label.anchors_preset = Control.PRESET_CENTER_TOP
	warning_label.offset_left = -300
	warning_label.offset_right = 300
	warning_label.offset_top = 400
	warning_label.offset_bottom = 500
	warning_label.visible = false
	$CanvasLayer.add_child(warning_label)

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

	# Difficulté progressive (une seule fois par palier de 15s)
	var step = int(time_elapsed / 15.0)
	if step > last_difficulty_step:
		last_difficulty_step = step
		_apply_difficulty_step(step)

	# Gestion de l'inversion temporaire
	if inversion_active:
		inversion_timer -= delta
		if inversion_timer <= 0:
			_end_wall_inversion()

func _apply_difficulty_step(step: int):
	# Reduction lente du spawn rate
	spawn_rate = max(0.8, spawn_rate - 0.12)
	spawn_timer.wait_time = spawn_rate

	# Step 3 (45s): debut des patterns d'acceleration
	if step >= 3:
		accel_pattern_chance = min(0.4, (step - 2) * 0.08)

	# Step 4 (60s): plus de bombes
	if step >= 4:
		bomb_chance = min(0.2, 0.1 + (step - 3) * 0.02)

	# Step 5 (75s): premiere inversion de murs possible
	if step >= 5 and not inversion_active and randf() < 0.3:
		_start_wall_inversion()

	# Step 6 (90s): spawn bursts occasionnels
	if step >= 6 and randf() < 0.25:
		_trigger_spawn_burst()

	# Step 8+ (120s+): inversions plus frequentes
	if step >= 8 and not inversion_active and randf() < 0.5:
		_start_wall_inversion()

func _start_wall_inversion():
	walls_inverted = true
	inversion_active = true
	inversion_timer = INVERSION_DURATION

	# Echanger les couleurs des lasers visuellement
	if laser_left:
		laser_left.set_inverted(true)
	if laser_right:
		laser_right.set_inverted(true)

	# Warning visuel
	_show_warning("INVERSION!")

func _end_wall_inversion():
	walls_inverted = false
	inversion_active = false

	if laser_left:
		laser_left.set_inverted(false)
	if laser_right:
		laser_right.set_inverted(false)

	_show_warning("NORMAL")

func _trigger_spawn_burst():
	# Spawn 3-5 balles rapidement
	burst_count = randi_range(3, 5)
	spawn_burst_active = true
	_show_warning("BURST!")

	for i in range(burst_count):
		_spawn_ball()
		await get_tree().create_timer(0.3).timeout

	spawn_burst_active = false

func _show_warning(text: String):
	if not warning_label:
		return
	warning_label.text = text
	warning_label.visible = true
	warning_label.modulate = Color(1, 1, 1, 1)
	warning_label.scale = Vector2(0.5, 0.5)
	warning_label.pivot_offset = Vector2(300, 50)

	var tween = create_tween()
	tween.tween_property(warning_label, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(warning_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(warning_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): warning_label.visible = false)

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

	# Type aléatoire
	var rand = randf()
	if rand < bomb_chance:
		ball.ball_type = BallDragThrow.BallType.BOMB
	elif rand < bomb_chance + 0.3:
		ball.ball_type = BallDragThrow.BallType.CYAN
	elif rand < bomb_chance + 0.6:
		ball.ball_type = BallDragThrow.BallType.MAGENTA
	else:
		ball.ball_type = BallDragThrow.BallType.YELLOW

	# Gravité tres progressive: 0.15 au debut, monte doucement
	var grav = 0.15 + (time_elapsed / 120.0)  # +1.0 apres 2 MINUTES
	grav = min(grav, 0.8)  # Plafond a 0.8
	ball.gravity_scale = grav

	# Late-game: acceleration pattern
	if randf() < accel_pattern_chance:
		ball.has_accel_pattern = true
		ball.base_gravity = grav
		ball.accel_timer = randf() * TAU  # Phase aleatoire

	# Wall inversion
	ball.walls_inverted = walls_inverted

	# Connect signals
	ball.bomb_exploded.connect(_on_bomb_exploded)

	add_child(ball)

func _on_laser_ball_destroyed(points: int):
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

func _on_pause_pressed():
	if not game_over:
		pause_menu.show_pause()

func _game_over():
	game_over = true
	spawn_timer.stop()

	await get_tree().create_timer(1.0).timeout

	# Afficher le menu de game over avec les stats
	game_over_menu.show_game_over(score, combo)

func _update_ui():
	if score_label:
		score_label.text = str(score)
		_animate_label(score_label)

	if lives_label:
		lives_label.text = "I".repeat(max(lives, 0))
		if lives <= 1:
			lives_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
		else:
			lives_label.add_theme_color_override("font_color", Color(1, 0, 1, 0.6))

	if combo_label:
		if combo > 1:
			combo_label.text = "x" + str(combo)
			combo_label.visible = true
			_animate_label(combo_label, 1.2)
		else:
			combo_label.visible = false

func _animate_label(label: Label, scale_to: float = 1.15):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# Pop
	tween.tween_property(label, "scale", Vector2(scale_to, scale_to), 0.1)
	# Return
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
