@tool
extends RefCounted
## 配置：从项目 ai_pipeline/.env 读取 SiliconFlow API Key。
## .env 不进 git（见项目 .gitignore），组员从组长处获取 key 后填入一次即可。

const ENV_PATH = "res://ai_pipeline/.env"
const KEY_NAME = "SILICONFLOW_API_KEY"


var _env: Dictionary = {}


func _init():
	_load_env()


func _load_env():
	_env = {}
	if not FileAccess.file_exists(ENV_PATH):
		return
	var f = FileAccess.open(ENV_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("#") or line.is_empty():
			continue
		var eq = line.find("=")
		if eq > 0:
			_env[line.substr(0, eq).strip_edges()] = line.substr(eq + 1).strip_edges()


func get_api_key() -> String:
	return _env.get(KEY_NAME, "")


func has_api_key() -> bool:
	return not get_api_key().is_empty()


func get_env_path() -> String:
	return ProjectSettings.globalize_path(ENV_PATH)
