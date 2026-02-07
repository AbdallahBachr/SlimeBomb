extends Control

## Settings popup overlay - can be embedded in any screen

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var shake_toggle: CheckButton = $Panel/VBox/ShakeRow/ShakeToggle
@onready var close_button: Button = $Panel/CloseButton
@onready var panel: Panel = $Panel

# Settings values
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var screen_shake: bool = true

func _ready():
	visible = false
	_load_settings()
	_apply_audio()

	music_slider.value = music_volume
	sfx_slider.value = sfx_volume
	shake_toggle.button_pressed = screen_shake

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	shake_toggle.toggled.connect(_on_shake_toggled)
	close_button.pressed.connect(hide_settings)

func show_settings():
	visible = true
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0

	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25)
	t.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)

func hide_settings():
	var t = create_tween()
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.15)
	t.parallel().tween_property(panel, "modulate:a", 0.0, 0.15)
	await t.finished
	visible = false

func _on_music_changed(value: float):
	music_volume = value
	_apply_audio()
	_save_settings()

func _on_sfx_changed(value: float):
	sfx_volume = value
	_apply_audio()
	_save_settings()

func _on_shake_toggled(enabled: bool):
	screen_shake = enabled
	_save_settings()

func _apply_audio():
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")

	if music_idx >= 0:
		if music_volume <= 0.01:
			AudioServer.set_bus_mute(music_idx, true)
		else:
			AudioServer.set_bus_mute(music_idx, false)
			AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))

	if sfx_idx >= 0:
		if sfx_volume <= 0.01:
			AudioServer.set_bus_mute(sfx_idx, true)
		else:
			AudioServer.set_bus_mute(sfx_idx, false)
			AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

func _load_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		if file:
			music_volume = file.get_float()
			sfx_volume = file.get_float()
			screen_shake = file.get_8() == 1
			file.close()

func _save_settings():
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	if file:
		file.store_float(music_volume)
		file.store_float(sfx_volume)
		file.store_8(1 if screen_shake else 0)
		file.close()
