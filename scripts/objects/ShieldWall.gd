extends Area2D
class_name ShieldWall

func _ready():
	collision_layer = 1
	collision_mask = 0
	set_collision_mask_value(2, true) # cyan balls
	set_collision_mask_value(3, true) # magenta balls
	set_collision_mask_value(4, true) # yellow balls
	set_collision_mask_value(5, true) # bombs
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual():
	if has_node("CoreRect") and has_node("CollisionShape2D"):
		return
	var glow = ColorRect.new()
	glow.name = "GlowRect"
	glow.size = Vector2(1180, 44)
	glow.color = Color(0.9, 0.95, 1.0, 0.16)
	glow.position = Vector2(-590, -22)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var core = ColorRect.new()
	core.name = "CoreRect"
	core.size = Vector2(1120, 14)
	core.color = Color(1.0, 1.0, 1.0, 0.7)
	core.position = Vector2(-560, -7)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(core)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(1120, 18)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _on_body_entered(body):
	if body is BallDragThrow:
		var ball = body as BallDragThrow
		if ball.ball_type == BallDragThrow.BallType.BOMB:
			return
		if ball.is_grabbed:
			return
		# Consume the ball without affecting score/combo/lives
		ball.queue_free()
