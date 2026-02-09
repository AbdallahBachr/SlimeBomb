extends Area2D
class_name ShieldWall

func _ready():
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual():
	if has_node("ColorRect") and has_node("CollisionShape2D"):
		return
	var rect = ColorRect.new()
	rect.name = "ColorRect"
	rect.size = Vector2(1200, 60)
	rect.color = Color(1, 1, 0.2, 0.5)
	rect.position = Vector2(-600, -30)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	var shape = RectangleShape2D.new()
	shape.size = Vector2(1200, 60)
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
		# Bounce up
		ball.linear_velocity = Vector2(ball.linear_velocity.x, 0)
		ball.apply_central_impulse(Vector2(0, -1200))
