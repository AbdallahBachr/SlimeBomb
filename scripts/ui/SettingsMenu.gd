extends Control

@onready var music_slider = $VBoxContainer/MusicSlider
@onready var sfx_slider = $VBoxContainer/SFXSlider
@onready var back_button = $BackButton

func _ready():
	# Load saved settings
	_load_settings()

	# Connect signals
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	back_button.pressed.connect(_on_back_pressed)

func _load_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		if file:
			music_slider.value = file.get_float()
			sfx_slider.value = file.get_float()
			file.close()
	else:
		music_slider.value = 0.7
		sfx_slider.value = 1.0

func _save_settings():
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	if file:
		file.store_float(music_slider.value)
		file.store_float(sfx_slider.value)
		file.close()

func _on_music_changed(value: float):
	# TODO: Appliquer au volume de la musique
	print("🎵 Music volume: ", value)
	_save_settings()

func _on_sfx_changed(value: float):
	# TODO: Appliquer au volume SFX
	print("🔊 SFX volume: ", value)
	_save_settings()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
