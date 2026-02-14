extends Area2D
class_name KillZone

signal ball_missed()

func _ready():
	collision_layer = 1
	collision_mask = 0
	set_collision_mask_value(1, true) # powerups
	set_collision_mask_value(2, true) # cyan balls
	set_collision_mask_value(3, true) # magenta balls
	set_collision_mask_value(4, true) # yellow balls
	set_collision_mask_value(5, true) # bombs
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is BallDragThrow:
		var ball = body as BallDragThrow
		if ball.is_grabbed:
			return
		if ball.ball_type != BallDragThrow.BallType.BOMB:
			ball.mark_missed()
		_fade_out_ball(ball)
	elif body is PowerupDrop:
		if is_instance_valid(body):
			body.queue_free()

func _fade_out_ball(ball: BallDragThrow):
	# Smooth fade out before destruction
	if not is_instance_valid(ball):
		return
	if ball.has_node("Sprite2D"):
		var sprite = ball.get_node("Sprite2D")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tween.finished.connect(func():
			if is_instance_valid(ball):
				ball.queue_free()
		)
	else:
		if is_instance_valid(ball):
			ball.queue_free()
