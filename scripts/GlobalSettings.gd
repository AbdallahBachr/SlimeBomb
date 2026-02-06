extends Node

# Settings globaux du jeu (Autoload / Singleton)
# À ajouter dans Project > Project Settings > Autoload

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var is_muted: bool = false

# Gameplay
var vibration_enabled: bool = true
var show_fps: bool = false
var particle_quality: int = 2  # 0=low, 1=medium, 2=high

# Monétisation
var ads_disabled: bool = false  # True si achat "Remove Ads"
var coins: int = 0
var premium: bool = false

# Progression
var player_level: int = 1
var player_xp: int = 0
var total_games_played: int = 0
var total_score: int = 0

# Skins
var unlocked_skins: Array = ["default"]
var current_skin: String = "default"

# Power-ups possédés
var powerups: Dictionary = {
	"slow_motion": 0,
	"shield": 0,
	"double_points": 0,
	"magnet": 0,
	"bomb_immunity": 0
}

# Missions quotidiennes
var daily_missions_completed: Array = []
var last_daily_reset: String = ""

# Statistiques
var stats: Dictionary = {
	"total_swipes": 0,
	"correct_swipes": 0,
	"bombs_avoided": 0,
	"max_combo": 0,
	"total_playtime": 0.0
}

const SAVE_PATH = "user://savegame.save"

func _ready():
	load_game()

func save_game():
	var save_data = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"is_muted": is_muted,
		"vibration_enabled": vibration_enabled,
		"show_fps": show_fps,
		"particle_quality": particle_quality,
		"ads_disabled": ads_disabled,
		"coins": coins,
		"premium": premium,
		"player_level": player_level,
		"player_xp": player_xp,
		"total_games_played": total_games_played,
		"total_score": total_score,
		"unlocked_skins": unlocked_skins,
		"current_skin": current_skin,
		"powerups": powerups,
		"daily_missions_completed": daily_missions_completed,
		"last_daily_reset": last_daily_reset,
		"stats": stats
	}

	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file:
		var json_string = JSON.stringify(save_data)
		save_file.store_line(json_string)
		save_file.close()
		print("Game saved successfully")
	else:
		push_error("Failed to save game")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, using defaults")
		return

	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file:
		var json_string = save_file.get_line()
		save_file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var save_data = json.data
			# Charger toutes les valeurs
			master_volume = save_data.get("master_volume", 1.0)
			music_volume = save_data.get("music_volume", 0.7)
			sfx_volume = save_data.get("sfx_volume", 1.0)
			is_muted = save_data.get("is_muted", false)
			vibration_enabled = save_data.get("vibration_enabled", true)
			show_fps = save_data.get("show_fps", false)
			particle_quality = save_data.get("particle_quality", 2)
			ads_disabled = save_data.get("ads_disabled", false)
			coins = save_data.get("coins", 0)
			premium = save_data.get("premium", false)
			player_level = save_data.get("player_level", 1)
			player_xp = save_data.get("player_xp", 0)
			total_games_played = save_data.get("total_games_played", 0)
			total_score = save_data.get("total_score", 0)
			unlocked_skins = save_data.get("unlocked_skins", ["default"])
			current_skin = save_data.get("current_skin", "default")
			powerups = save_data.get("powerups", {})
			daily_missions_completed = save_data.get("daily_missions_completed", [])
			last_daily_reset = save_data.get("last_daily_reset", "")
			stats = save_data.get("stats", {})

			print("Game loaded successfully")
		else:
			push_error("Failed to parse save file")
	else:
		push_error("Failed to open save file")

# Fonctions utilitaires

func add_coins(amount: int):
	coins += amount
	save_game()

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		save_game()
		return true
	return false

func unlock_skin(skin_name: String):
	if not unlocked_skins.has(skin_name):
		unlocked_skins.append(skin_name)
		save_game()

func is_skin_unlocked(skin_name: String) -> bool:
	return unlocked_skins.has(skin_name)

func equip_skin(skin_name: String):
	if is_skin_unlocked(skin_name):
		current_skin = skin_name
		save_game()

func add_powerup(powerup_name: String, amount: int = 1):
	if powerup_name in powerups:
		powerups[powerup_name] += amount
	else:
		powerups[powerup_name] = amount
	save_game()

func use_powerup(powerup_name: String) -> bool:
	if powerup_name in powerups and powerups[powerup_name] > 0:
		powerups[powerup_name] -= 1
		save_game()
		return true
	return false

func add_xp(amount: int):
	player_xp += amount
	var xp_needed = player_level * 100

	while player_xp >= xp_needed:
		player_xp -= xp_needed
		player_level += 1
		xp_needed = player_level * 100
		# Récompense level up
		_on_level_up()

	save_game()

func _on_level_up():
	# Récompenses pour level up
	add_coins(50 * player_level)
	print("Level up! Now level ", player_level)

func reset_daily_missions():
	var today = Time.get_date_string_from_system()
	if today != last_daily_reset:
		daily_missions_completed = []
		last_daily_reset = today
		save_game()

func complete_daily_mission(mission_id: String, reward: int):
	if not daily_missions_completed.has(mission_id):
		daily_missions_completed.append(mission_id)
		add_coins(reward)
		save_game()

# Statistiques

func increment_stat(stat_name: String, amount: float = 1.0):
	if stat_name in stats:
		stats[stat_name] += amount
	else:
		stats[stat_name] = amount
	save_game()

func get_accuracy() -> float:
	if stats.total_swipes > 0:
		return (float(stats.correct_swipes) / float(stats.total_swipes)) * 100.0
	return 0.0

# Audio

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	save_game()

func toggle_mute():
	is_muted = not is_muted
	AudioServer.set_bus_mute(0, is_muted)
	save_game()

# Vibration

func vibrate(duration_ms: int = 50):
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
