extends Node

const SAVE_PATH = "user://save.dat"

var best_distance = 0.0
var resolution_index = 0  # 0=4:3, 1=16:9, 2=16:10
var fullscreen = false
var api_key = ""  # SiliconFlow API Key（AI 马匹生成用，玩家在设置界面填写）

const RESOLUTIONS = [
	{"label": "4:3 (1024×768)",   "window": Vector2i(1024, 768), "viewport": Vector2i(800, 600)},
	{"label": "16:9 (1280×720)",  "window": Vector2i(1280, 720), "viewport": Vector2i(960, 540)},
	{"label": "16:10 (1280×800)", "window": Vector2i(1280, 800), "viewport": Vector2i(960, 600)},
]

func apply_resolution():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		var r = RESOLUTIONS[resolution_index]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
		get_window().content_scale_size = r["viewport"]
		DisplayServer.window_set_size(r["window"])

func update_best_distance(dist: float):
	if dist > best_distance:
		best_distance = dist

func save_game():
	var config = ConfigFile.new()
	var gm = get_node("/root/GameManager")
	config.set_value("player", "personality_pref", gm.personality_pref)
	config.set_value("player", "temper_pref", gm.temper_pref)
	config.set_value("player", "tame_ability", gm.tame_ability)
	config.set_value("player", "jump_power", gm.jump_power)
	config.set_value("player", "gold", gm.gold)

	var stable_data = []
	for horse in gm.stables:
		if horse != null:
			stable_data.append(_horse_to_dict(horse))
		else:
			stable_data.append(null)
	config.set_value("stable", "horses", stable_data)
	config.set_value("stable", "max_slots", gm.max_stable_slots)
	config.set_value("stable", "selected_index", gm.selected_horse_index)
	config.set_value("meta", "best_distance", best_distance)
	config.set_value("meta", "resolution_index", resolution_index)
	config.set_value("meta", "fullscreen", fullscreen)
	config.set_value("meta", "api_key", api_key)
	config.set_value("collection", "unlocked_breeds", gm.unlocked_breeds)
	config.save(SAVE_PATH)

func load_game():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var gm = get_node("/root/GameManager")
	gm.personality_pref = float(config.get_value("player", "personality_pref", 50.0))
	gm.temper_pref = float(config.get_value("player", "temper_pref", 50.0))
	gm.tame_ability = float(config.get_value("player", "tame_ability", 0.0))
	gm.jump_power = float(config.get_value("player", "jump_power", 10.0))
	gm.gold = int(config.get_value("player", "gold", 200))

	gm.stables.clear()
	var stable_data = config.get_value("stable", "horses", [])
	for data in stable_data:
		if data != null:
			gm.stables.append(_dict_to_horse(data))
		else:
			gm.stables.append(null)
	gm.max_stable_slots = int(config.get_value("stable", "max_slots", 5))
	gm.selected_horse_index = int(config.get_value("stable", "selected_index", -1))

	best_distance = float(config.get_value("meta", "best_distance", 0.0))
	resolution_index = int(config.get_value("meta", "resolution_index", 0))
	fullscreen = bool(config.get_value("meta", "fullscreen", false))
	api_key = config.get_value("meta", "api_key", "")
	gm.unlocked_breeds = config.get_value("collection", "unlocked_breeds", [])

func _horse_to_dict(horse):
	return {
		"horse_name": horse.horse_name,
		"breed_path": horse.breed.resource_path,
		"speed_mod": horse.speed_mod,
		"stamina_mod": horse.stamina_mod,
		"personality_mod": horse.personality_mod,
		"temper_mod": horse.temper_mod,
		"obedience_mod": horse.obedience_mod,
		"distance_run": horse.distance_run,
		"affection": horse.affection,
		"drug_resistance": horse.drug_resistance,
		"drug_use_count": horse.drug_use_count,
		"is_player_owned": horse.is_player_owned,
	}

func _dict_to_horse(dict):
	var horse = HorseData.new()
	horse.horse_name = dict["horse_name"]
	horse.breed = load(dict["breed_path"])
	horse.speed_mod = int(dict.get("speed_mod", 0))
	horse.stamina_mod = int(dict.get("stamina_mod", 0))
	horse.personality_mod = float(dict.get("personality_mod", 0.0))
	horse.temper_mod = float(dict.get("temper_mod", 0.0))
	horse.obedience_mod = float(dict.get("obedience_mod", 0.0))
	horse.distance_run = float(dict.get("distance_run", 0.0))
	horse.affection = int(dict.get("affection", 0))
	horse.drug_resistance = int(dict.get("drug_resistance", 0))
	horse.drug_use_count = int(dict.get("drug_use_count", 0))
	horse.is_player_owned = dict.get("is_player_owned", true)
	return horse
