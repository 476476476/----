# BreedRegistry — AI 生成品种的补充注册层
# 不替代原有硬编码字典，只负责 AI 管线生成的新品种。
# 原字典查不到时，各场景脚本回退到这里查询。
extends Node

const CONFIG_PATH = "res://resources/ai_generated_breeds/breeds.json"

var _generated_breeds: Dictionary = {}  # chinese_name -> {name, prefix, price, path}


func _ready():
	_load_config()


func _load_config():
	_generated_breeds.clear()
	if not ResourceLoader.exists(CONFIG_PATH):
		return
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("name") and entry.has("prefix"):
				_generated_breeds[entry["name"]] = entry


func get_prefix(chinese_name: String) -> String:
	if _generated_breeds.has(chinese_name):
		return str(_generated_breeds[chinese_name].get("prefix", ""))
	return ""


func get_price(chinese_name: String) -> int:
	if _generated_breeds.has(chinese_name):
		return int(_generated_breeds[chinese_name].get("price", 0))
	return 0


func get_all_breed_paths() -> Array:
	var paths = []
	for entry in _generated_breeds.values():
		var p = str(entry.get("path", ""))
		if p.is_empty():
			p = "res://resources/breeds/%s.tres" % entry.get("prefix", "")
		paths.append(p)
	return paths


func get_all_prefixes() -> Array:
	var prefixes = []
	for entry in _generated_breeds.values():
		prefixes.append(entry.get("prefix", ""))
	return prefixes


func register_breed(name: String, prefix: String, price: int, tres_path: String):
	_generated_breeds[name] = {
		"name": name,
		"prefix": prefix,
		"price": price,
		"path": tres_path,
	}
	_save_config()


func _save_config():
	var dir_path = CONFIG_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var data = []
	for entry in _generated_breeds.values():
		data.append(entry)
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
