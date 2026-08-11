# BreedRegistry — AI 生成品种的补充注册层
# 不替代原有硬编码字典，只负责 AI 管线生成的新品种。
#
# 双来源合并：
#   - res://resources/ai_generated_breeds/breeds.json  开发版（编辑器插件写入，导出时打包进 pck）
#   - user://ai_horses/breeds.json                     玩家版（导出的游戏运行时写入）
#
# 支持同名多条目：一个中文名下可有多匹马（内置 + 多个玩家注册同名马）。
# 所有"按实例"查询（取帧、取价）一律用 .tres 路径反推前缀，不用名字——同名才可区分。
extends Node

const CONFIG_PATH = "res://resources/ai_generated_breeds/breeds.json"
const USER_CONFIG_PATH = "user://ai_horses/breeds.json"
const USER_FRAMES_DIR = "user://ai_horses/frames/"
const RES_FRAMES_DIR = "res://Art_Resource/Horses/"

var _generated_breeds: Dictionary = {}  # chinese_name -> Array[{name, prefix, price, path}]


func _ready():
	_load_config()


## 重新加载（向导注册/删除后调用，刷新内存缓存）
func reload():
	_load_config()


func _load_config():
	_generated_breeds.clear()
	_load_from_file(CONFIG_PATH)
	_load_from_file(USER_CONFIG_PATH)


func _load_from_file(path: String):
	# 注意：不能用 ResourceLoader.exists() —— .json 无资源 loader 恒 false。
	# 纯文本文件，编辑器走磁盘、导出后 PCK 中原样保留，FileAccess 可读。
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("name") and entry.has("prefix"):
				_append_entry(entry)


## 同名条目追加进数组（不再按名字覆盖——支持多匹同名马）
func _append_entry(entry: Dictionary):
	var name = str(entry.get("name", ""))
	if not _generated_breeds.has(name):
		_generated_breeds[name] = []
	_generated_breeds[name].append(entry)


## 从 .tres 路径反推品种前缀：user://ai_horses/breeds/ai_5.tres → ai_5；
## res://resources/breeds/mongolian.tres → mongolian。天然唯一，不受重名影响。
static func prefix_from_path(path: String) -> String:
	return path.get_file().trim_suffix(".tres")


func get_all_breed_paths() -> Array:
	var paths = []
	for entries in _generated_breeds.values():
		for entry in entries:
			var p = str(entry.get("path", ""))
			if p.is_empty():
				p = "res://resources/breeds/%s.tres" % entry.get("prefix", "")
			paths.append(p)
	return paths


func get_all_prefixes() -> Array:
	var prefixes = []
	for entries in _generated_breeds.values():
		for entry in entries:
			prefixes.append(entry.get("prefix", ""))
	return prefixes


## 按 .tres 路径查价格（同名多马时价格各自独立）
func get_price_for_path(path: String) -> int:
	for entries in _generated_breeds.values():
		for entry in entries:
			if str(entry.get("path", "")) == path:
				return int(entry.get("price", 0))
	return 0


## 动画帧路径：玩家马 → user://，开发马 → res://。
## frame 从 1 开始（目录内 1.png, 2.png, ...）。
func get_frame_path(prefix: String, anim: String, frame: int) -> String:
	return get_frames_base(prefix, anim) + "%d.png" % frame


## 帧目录基址（含尾斜杠），用于 DirAccess 扫描目录内文件
func get_frames_base(prefix: String, anim: String) -> String:
	var user_dir = USER_FRAMES_DIR + "%s_%s/" % [prefix, anim]
	if DirAccess.dir_exists_absolute(user_dir):
		return user_dir + "frames/"
	return RES_FRAMES_DIR + "%s_%s/" % [prefix, anim] + "frames/"


## 注册新品种。编辑器（@tool 插件）写 res:// 开发版，
## 导出的游戏运行时写 user:// 玩家版。同名马追加为新条目。
func register_breed(name: String, prefix: String, price: int, tres_path: String):
	var entry = {
		"name": name,
		"prefix": prefix,
		"price": price,
		"path": tres_path,
	}
	_append_entry(entry)
	if Engine.is_editor_hint():
		_save_config(CONFIG_PATH)
	else:
		_save_config(USER_CONFIG_PATH)


func _save_config(path: String):
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var data = []
	var only_user = path == USER_CONFIG_PATH
	for entries in _generated_breeds.values():
		for entry in entries:
			var p = str(entry.get("path", ""))
			if only_user and not p.begins_with("user://"):
				continue  # 玩家文件只保存玩家条目
			data.append(entry)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()  # 确保落盘：reload 会立即重读，未 close 会读到空文件
