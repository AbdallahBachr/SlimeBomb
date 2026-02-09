extends Area2D
class_name KillZone

signal ball_missed()

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is BallDragThrow:
		var ball = body as BallDragThrow

		# Si c'est une bombe qui tombe, on ignore (pas de pénalité)
		if ball.ball_type == BallDragThrow.BallType.BOMB:
			# Pas de pénalité pour les bombes qui tombent
			if is_instance_valid(ball):
				ball.queue_free()
		else:
			# Balle normale ratée
			if ball.has_method("mark_missed"):
				ball.mark_missed()

			# Effet visuel de disparition
			_fade_out_ball(ball)
	elif body is PowerupDrop:
		if is_instance_valid(body):
			body.queue_free()

func _fade_out_ball(ball: BallDragThrow):
	"""Fade out smooth de la balle avant destruction"""
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
