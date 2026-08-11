extends RefCounted
## AI 马匹生成 — API Key 管理（游戏运行时版本）。
## 读取 SaveSystem 持久化的 api_key（玩家在设置界面填写），
## 兼容 addons/horse_generator/config.gd 的接口（编辑器插件仍用 .env）。

const KEY_NAME = "SILICONFLOW_API_KEY"

var _save: Node = null


func _save_system() -> Node:
	if _save == null:
		_save = Engine.get_main_loop().root.get_node_or_null("SaveSystem")
	return _save


func get_api_key() -> String:
	var ss = _save_system()
	return ss.api_key if ss else ""


func has_api_key() -> bool:
	return not get_api_key().is_empty()


## 保存并立即落盘（save.dat）
func set_api_key(key: String) -> void:
	var ss = _save_system()
	if ss == null:
		return
	ss.api_key = key.strip_edges()
	ss.save_game()


## 显示用：Key 打码，避免在界面上泄露完整 key
func masked_key() -> String:
	var key = get_api_key()
	if key.is_empty():
		return ""
	if key.length() <= 8:
		return key[0] + "***"
	return key.substr(0, 4) + "***" + key.substr(key.length() - 4)
