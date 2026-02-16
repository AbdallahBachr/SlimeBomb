extends Node

# Global game settings (Autoload / Singleton)

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var is_muted: bool = false

# Gameplay
var vibration_enabled: bool = true
var show_fps: bool = false
var particle_quality: int = 2  # 0=low, 1=medium, 2=high

# Monetization
var ads_disabled: bool = false
var coins: int = 0
var premium: bool = false
const DEFAULT_UPGRADES: Dictionary = {
	"coin_boost": 0,
	"clutch_window": 0,
	"drop_luck": 0
}
const UPGRADE_MAX_LEVELS: Dictionary = {
	"coin_boost": 5,
	"clutch_window": 4,
	"drop_luck": 4
}
const UPGRADE_BASE_COSTS: Dictionary = {
	"coin_boost": 120.0,
	"clutch_window": 170.0,
	"drop_luck": 145.0
}
var upgrades: Dictionary = DEFAULT_UPGRADES.duplicate(true)

# Progression
var player_level: int = 1
var player_xp: int = 0
var total_games_played: int = 0
var total_score: int = 0

# Skins
var unlocked_skins: Array = ["default"]
var current_skin: String = "default"

# Owned powerups
const DEFAULT_POWERUPS: Dictionary = {
	"slow_motion": 0,
	"shield": 0,
	"double_points": 0,
	"magnet": 0,
	"bomb_immunity": 0
}
var powerups: Dictionary = DEFAULT_POWERUPS.duplicate(true)

# Daily missions
const DAILY_MISSION_SLOTS: int = 3
const DAILY_MISSION_LIBRARY: Dictionary = {
	"score_rush": {
		"title": "Score Rush",
		"description": "Earn 5000 score in total",
		"metric": "score",
		"target": 5000.0,
		"reward": 120,
		"xp": 70,
		"unit": "pts"
	},
	"combo_builder": {
		"title": "Combo Builder",
		"description": "Build 35 combo across runs",
		"metric": "combo",
		"target": 35.0,
		"reward": 100,
		"xp": 65,
		"unit": "combo"
	},
	"survivor": {
		"title": "Survivor",
		"description": "Survive 180 seconds total",
		"metric": "time",
		"target": 180.0,
		"reward": 110,
		"xp": 80,
		"unit": "sec"
	},
	"clean_hits": {
		"title": "Clean Hits",
		"description": "Score 90 clean hits",
		"metric": "hits",
		"target": 90.0,
		"reward": 90,
		"xp": 55,
		"unit": "hits"
	},
	"sharp_runs": {
		"title": "Sharp Runs",
		"description": "Finish 2 runs at 70%+ accuracy",
		"metric": "clean_run",
		"target": 2.0,
		"reward": 140,
		"xp": 95,
		"unit": "runs"
	}
}
var daily_missions_completed: Array = []
var daily_missions_active: Array = []
var daily_mission_progress: Dictionary = {}
var last_daily_reset: String = ""

# Runtime-only report for UI
var last_run_report: Dictionary = {}
var retry_session_streak: int = 0

# Stats
const DEFAULT_STATS: Dictionary = {
	"total_swipes": 0,
	"correct_swipes": 0,
	"bombs_avoided": 0,
	"max_combo": 0,
	"total_playtime": 0.0,
	"best_retry_streak": 0
}
var stats: Dictionary = DEFAULT_STATS.duplicate(true)

const SAVE_PATH = "user://savegame.save"

func _ready():
	load_game()
	reset_daily_missions()

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
		"upgrades": upgrades,
		"player_level": player_level,
		"player_xp": player_xp,
		"total_games_played": total_games_played,
		"total_score": total_score,
		"unlocked_skins": unlocked_skins,
		"current_skin": current_skin,
		"powerups": powerups,
		"daily_missions_completed": daily_missions_completed,
		"daily_missions_active": daily_missions_active,
		"daily_mission_progress": daily_mission_progress,
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
	if not save_file:
		push_error("Failed to open save file")
		return

	var json_string = save_file.get_line()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file")
		return

	var save_data = json.data
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
	upgrades = DEFAULT_UPGRADES.duplicate(true)
	var saved_upgrades = save_data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		upgrades.merge(saved_upgrades, true)
	_sanitize_upgrades()
	player_level = max(1, int(save_data.get("player_level", 1)))
	player_xp = max(0, int(save_data.get("player_xp", 0)))
	total_games_played = max(0, int(save_data.get("total_games_played", 0)))
	total_score = max(0, int(save_data.get("total_score", 0)))

	unlocked_skins = save_data.get("unlocked_skins", ["default"])
	if unlocked_skins.is_empty():
		unlocked_skins = ["default"]
	elif not unlocked_skins.has("default"):
		unlocked_skins.append("default")
	current_skin = save_data.get("current_skin", "default")

	powerups = DEFAULT_POWERUPS.duplicate(true)
	var saved_powerups = save_data.get("powerups", {})
	if saved_powerups is Dictionary:
		powerups.merge(saved_powerups, true)

	daily_missions_completed = save_data.get("daily_missions_completed", [])
	daily_missions_active = save_data.get("daily_missions_active", [])
	daily_mission_progress = save_data.get("daily_mission_progress", {})
	last_daily_reset = save_data.get("last_daily_reset", "")
	_sanitize_daily_missions()

	stats = DEFAULT_STATS.duplicate(true)
	var saved_stats = save_data.get("stats", {})
	if saved_stats is Dictionary:
		stats.merge(saved_stats, true)

	print("Game loaded successfully")

# Utilities

func add_coins(amount: int):
	coins += max(0, amount)
	save_game()

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
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

func get_upgrade_level(upgrade_id: String) -> int:
	if not DEFAULT_UPGRADES.has(upgrade_id):
		return 0
	return int(max(0, upgrades.get(upgrade_id, 0)))

func get_upgrade_max_level(upgrade_id: String) -> int:
	if not UPGRADE_MAX_LEVELS.has(upgrade_id):
		return 0
	return int(max(0, UPGRADE_MAX_LEVELS.get(upgrade_id, 0)))

func get_upgrade_price(upgrade_id: String) -> int:
	if not DEFAULT_UPGRADES.has(upgrade_id):
		return -1
	var level = get_upgrade_level(upgrade_id)
	var max_level = get_upgrade_max_level(upgrade_id)
	if level >= max_level:
		return -1
	var base_cost = float(UPGRADE_BASE_COSTS.get(upgrade_id, 100.0))
	var scaled = base_cost * pow(1.55, float(level))
	return int(max(1.0, round(scaled)))

func can_buy_upgrade(upgrade_id: String) -> bool:
	var price = get_upgrade_price(upgrade_id)
	if price <= 0:
		return false
	return coins >= price

func buy_upgrade(upgrade_id: String) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"upgrade_id": upgrade_id,
		"price": 0,
		"new_level": get_upgrade_level(upgrade_id),
		"coins_left": coins
	}
	if not DEFAULT_UPGRADES.has(upgrade_id):
		return result
	var price = get_upgrade_price(upgrade_id)
	result["price"] = price
	if price <= 0:
		return result
	if coins < price:
		return result
	coins -= price
	var new_level = min(get_upgrade_level(upgrade_id) + 1, get_upgrade_max_level(upgrade_id))
	upgrades[upgrade_id] = new_level
	save_game()
	result["ok"] = true
	result["new_level"] = new_level
	result["coins_left"] = coins
	return result

func get_upgrade_effect(upgrade_id: String) -> float:
	var level = get_upgrade_level(upgrade_id)
	match upgrade_id:
		"coin_boost":
			return 1.0 + 0.08 * float(level)
		"clutch_window":
			return 0.26 * float(level)
		"drop_luck":
			return float(level)
	return 0.0

func get_coin_reward_multiplier() -> float:
	return get_upgrade_effect("coin_boost")

func get_clutch_window_bonus_sec() -> float:
	return get_upgrade_effect("clutch_window")

func get_drop_luck_level() -> int:
	return int(round(get_upgrade_effect("drop_luck")))

func begin_fresh_run():
	retry_session_streak = 0

func begin_retry_run():
	retry_session_streak += 1
	var best = int(stats.get("best_retry_streak", 0))
	if retry_session_streak > best:
		stats["best_retry_streak"] = retry_session_streak
	save_game()

func end_retry_session():
	retry_session_streak = 0

func get_retry_session_streak() -> int:
	return retry_session_streak

func get_retry_session_coin_multiplier() -> float:
	var bonus = min(0.30, float(retry_session_streak) * 0.06)
	return 1.0 + bonus

func use_powerup(powerup_name: String) -> bool:
	if powerup_name in powerups and powerups[powerup_name] > 0:
		powerups[powerup_name] -= 1
		save_game()
		return true
	return false

func add_xp(amount: int):
	_add_xp_internal(amount)
	save_game()

func _add_xp_internal(amount: int) -> Dictionary:
	var gained = max(0, amount)
	var level_ups = 0
	var level_bonus_coins = 0
	player_xp += gained

	var xp_needed = player_level * 100
	while player_xp >= xp_needed:
		player_xp -= xp_needed
		player_level += 1
		level_ups += 1
		level_bonus_coins += _on_level_up()
		xp_needed = player_level * 100

	return {
		"xp_gained": gained,
		"level_ups": level_ups,
		"level_bonus_coins": level_bonus_coins
	}

func _on_level_up() -> int:
	var reward = 50 * player_level
	coins += reward
	print("Level up! Now level ", player_level)
	return reward

# Daily missions

func reset_daily_missions():
	var today = _get_today_key()
	if last_daily_reset != today or daily_missions_active.is_empty():
		last_daily_reset = today
		daily_missions_completed = []
		daily_mission_progress = {}
		_roll_daily_missions()
		save_game()
	else:
		_sanitize_daily_missions()

func complete_daily_mission(mission_id: String, reward: int):
	reset_daily_missions()
	if not daily_missions_active.has(mission_id):
		return
	if not daily_missions_completed.has(mission_id):
		daily_missions_completed.append(mission_id)
		daily_mission_progress[mission_id] = _get_mission_target(mission_id)
		coins += max(0, reward)
		save_game()

func get_daily_mission_status() -> Array:
	reset_daily_missions()
	var out: Array = []
	for mission_id in daily_missions_active:
		var id = str(mission_id)
		var mission = DAILY_MISSION_LIBRARY.get(id, {})
		if mission.is_empty():
			continue
		var target = float(mission.get("target", 1.0))
		var progress = min(target, float(daily_mission_progress.get(id, 0.0)))
		out.append({
			"id": id,
			"title": str(mission.get("title", id)),
			"description": str(mission.get("description", "")),
			"metric": str(mission.get("metric", "")),
			"target": target,
			"progress": progress,
			"completed": daily_missions_completed.has(id),
			"reward": int(mission.get("reward", 0)),
			"xp": int(mission.get("xp", 0)),
			"unit": str(mission.get("unit", ""))
		})
	return out

func get_daily_completion_count() -> int:
	return daily_missions_completed.size()

func get_daily_mission_count() -> int:
	return daily_missions_active.size()

func register_run(score: int, max_combo_run: int, time_survived_sec: float, accuracy: float, balls_scored_run: int, total_attempts: int) -> Dictionary:
	reset_daily_missions()

	var safe_score = max(0, score)
	var safe_combo = max(0, max_combo_run)
	var safe_time = max(0.0, time_survived_sec)
	var safe_hits = max(0, balls_scored_run)
	var safe_attempts = max(safe_hits, total_attempts)
	var safe_accuracy = clamp(accuracy, 0.0, 100.0)

	total_games_played += 1
	total_score += safe_score

	stats["max_combo"] = max(int(stats.get("max_combo", 0)), safe_combo)
	stats["total_playtime"] = float(stats.get("total_playtime", 0.0)) + safe_time
	stats["total_swipes"] = int(stats.get("total_swipes", 0)) + safe_attempts
	stats["correct_swipes"] = int(stats.get("correct_swipes", 0)) + safe_hits

	var base_run_coins = int(clamp(round(float(safe_score) * 0.015 + float(safe_combo) * 0.9 + min(safe_time, 180.0) * 0.07), 8.0, 320.0))
	var upgrade_coin_mult = get_coin_reward_multiplier()
	var session_coin_mult = get_retry_session_coin_multiplier()
	var coin_mult = upgrade_coin_mult * session_coin_mult
	var run_coins = int(clamp(round(float(base_run_coins) * coin_mult), 8.0, 560.0))
	var run_xp = int(clamp(round(float(safe_score) * 0.035 + float(safe_combo) * 2.0 + min(safe_time, 240.0) * 0.2), 12.0, 420.0))

	coins += run_coins
	var run_xp_report = _add_xp_internal(run_xp)
	var mission_completions = _apply_daily_progress(safe_score, safe_combo, safe_time, safe_accuracy, safe_hits, safe_attempts)

	last_run_report = {
		"run_coins": run_coins,
		"base_run_coins": base_run_coins,
		"coin_multiplier": coin_mult,
		"coin_multiplier_upgrade": upgrade_coin_mult,
		"coin_multiplier_session": session_coin_mult,
		"session_streak": retry_session_streak,
		"run_xp": run_xp,
		"level_ups": int(run_xp_report.get("level_ups", 0)),
		"level_bonus_coins": int(run_xp_report.get("level_bonus_coins", 0)),
		"player_level": player_level,
		"player_xp": player_xp,
		"coins_total": coins,
		"mission_completions": mission_completions,
		"daily_missions": get_daily_mission_status()
	}

	save_game()
	return last_run_report.duplicate(true)

func get_last_run_report() -> Dictionary:
	return last_run_report.duplicate(true)

func _apply_daily_progress(score_value: int, combo_value: int, time_value: float, accuracy_value: float, hits_value: int, attempts_value: int) -> Array:
	var completed_now: Array = []
	for mission_id in daily_missions_active:
		var id = str(mission_id)
		if daily_missions_completed.has(id):
			continue

		var mission = DAILY_MISSION_LIBRARY.get(id, {})
		if mission.is_empty():
			continue
		var target = float(mission.get("target", 1.0))
		if target <= 0.0:
			continue

		var metric = str(mission.get("metric", ""))
		var gain = _get_metric_progress(metric, score_value, combo_value, time_value, accuracy_value, hits_value, attempts_value)
		if gain <= 0.0:
			continue

		var current = float(daily_mission_progress.get(id, 0.0))
		var updated = min(target, current + gain)
		daily_mission_progress[id] = updated

		if updated >= target:
			daily_missions_completed.append(id)
			var reward_coins = int(mission.get("reward", 0))
			var reward_xp = int(mission.get("xp", 0))
			coins += max(0, reward_coins)
			var xp_report = _add_xp_internal(reward_xp)
			completed_now.append({
				"id": id,
				"title": str(mission.get("title", id)),
				"reward_coins": reward_coins,
				"reward_xp": reward_xp,
				"level_ups": int(xp_report.get("level_ups", 0)),
				"level_bonus_coins": int(xp_report.get("level_bonus_coins", 0))
			})

	return completed_now

func _get_metric_progress(metric: String, score_value: int, combo_value: int, time_value: float, accuracy_value: float, hits_value: int, attempts_value: int) -> float:
	match metric:
		"score":
			return float(score_value)
		"combo":
			return float(combo_value)
		"time":
			return time_value
		"hits":
			return float(hits_value)
		"clean_run":
			if attempts_value >= 20 and accuracy_value >= 70.0:
				return 1.0
			return 0.0
	return 0.0

func _roll_daily_missions():
	var ids: Array = DAILY_MISSION_LIBRARY.keys()
	ids.shuffle()
	daily_missions_active = []
	for i in range(min(DAILY_MISSION_SLOTS, ids.size())):
		var id = str(ids[i])
		daily_missions_active.append(id)
		daily_mission_progress[id] = 0.0

func _sanitize_daily_missions():
	var valid_ids = DAILY_MISSION_LIBRARY.keys()

	var cleaned_active: Array = []
	for mission_id in daily_missions_active:
		var id = str(mission_id)
		if valid_ids.has(id) and not cleaned_active.has(id):
			cleaned_active.append(id)
	if cleaned_active.size() > DAILY_MISSION_SLOTS:
		cleaned_active.resize(DAILY_MISSION_SLOTS)
	daily_missions_active = cleaned_active

	if daily_missions_active.is_empty():
		_roll_daily_missions()

	var cleaned_completed: Array = []
	for mission_id in daily_missions_completed:
		var id = str(mission_id)
		if daily_missions_active.has(id) and not cleaned_completed.has(id):
			cleaned_completed.append(id)
	daily_missions_completed = cleaned_completed

	var cleaned_progress: Dictionary = {}
	for mission_id in daily_missions_active:
		var id = str(mission_id)
		var target = _get_mission_target(id)
		var value = clamp(float(daily_mission_progress.get(id, 0.0)), 0.0, target)
		cleaned_progress[id] = value
	daily_mission_progress = cleaned_progress

func _sanitize_upgrades():
	var cleaned: Dictionary = DEFAULT_UPGRADES.duplicate(true)
	for upgrade_id in DEFAULT_UPGRADES.keys():
		var id = str(upgrade_id)
		var max_level = int(UPGRADE_MAX_LEVELS.get(id, 0))
		var level = int(clamp(float(upgrades.get(id, 0)), 0.0, float(max_level)))
		cleaned[id] = level
	upgrades = cleaned

func _get_mission_target(mission_id: String) -> float:
	var mission = DAILY_MISSION_LIBRARY.get(mission_id, {})
	return float(mission.get("target", 1.0))

func _get_today_key() -> String:
	return Time.get_date_string_from_system()

# Stats

func increment_stat(stat_name: String, amount: float = 1.0):
	if stat_name in stats:
		stats[stat_name] += amount
	else:
		stats[stat_name] = amount
	save_game()

func get_accuracy() -> float:
	var total_swipes = float(stats.get("total_swipes", 0.0))
	if total_swipes > 0.0:
		var correct_swipes = float(stats.get("correct_swipes", 0.0))
		return (correct_swipes / total_swipes) * 100.0
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
