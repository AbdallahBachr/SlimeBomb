extends Camera2D
class_name CameraShake

var shake_amount: float = 0.0
var default_offset: Vector2 = Vector2.ZERO

func _ready():
	default_offset = offset

func _process(delta):
	if shake_amount > 0:
		# Shake aléatoire
		offset = default_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

		# Diminuer le shake progressivement (smooth decay)
		shake_amount = lerp(shake_amount, 0.0, 10.0 * delta)

		# Stop quand c'est trop petit
		if shake_amount < 0.1:
			shake_amount = 0.0
			offset = default_offset
	else:
		offset = default_offset

func shake(intensity: float = 10.0, duration: float = 0.3):
	# Check if shake is disabled in settings
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		if file:
			file.get_float()  # music
			file.get_float()  # sfx
			var shake_enabled = file.get_8() == 1
			file.close()
			if not shake_enabled:
				return

	shake_amount = intensity

	# Optional: fade out progressif avec tween
	var tween = create_tween()
	tween.tween_property(self, "shake_amount", 0.0, duration).set_ease(Tween.EASE_OUT)

func small_shake():
	shake(5.0, 0.2)

func medium_shake():
	shake(10.0, 0.3)

func big_shake():
	shake(20.0, 0.5)
