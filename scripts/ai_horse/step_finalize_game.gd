extends "res://scripts/ai_horse/step_base_game.gd"
## 步骤 7：注册新马匹（游戏运行时版）
## 注册写 user://ai_horses/（导出后 res:// 只读）：
##   frames/<prefix>_run/frames/*.png   动画帧
##   breeds/<prefix>.tres               HorseBreed 资源
##   breeds.json                        BreedRegistry 注册（自动写 user://）

const USER_FRAMES_DIR = "user://ai_horses/frames/"
const USER_BREEDS_DIR = "user://ai_horses/breeds/"
const USER_BREEDS_JSON = "user://ai_horses/breeds.json"
const RES_BREEDS_JSON = "res://resources/ai_generated_breeds/breeds.json"

var _register_btn: Button
var _summary_label: Label
var _err_label: Label
var _busy: bool = false


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("7. 注册新马匹"))
	_content.add_child(_hint("把动画帧存入游戏数据目录，生成品种资源并注册。注册后回到主菜单即可在选马界面使用。"))

	var row = _row()
	_content.add_child(row)
	_register_btn = _button("🚀 注册到游戏", _on_register)
	_style_button(_register_btn)
	row.add_child(_register_btn)

	_err_label = _error_label()
	_content.add_child(_err_label)

	_summary_label = _label("")
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_summary_label)


func validate() -> String:
	if not state.has("frames_dir") or not FileAccess.file_exists(state["frames_dir"] + "/1.png"):
		return "请先生成动画（第 6 步）"
	return ""


func on_enter():
	_show_summary()


func _show_summary():
	var attrs: Dictionary = state.get("attributes", {})
	var lines = [
		"马名: %s" % state.get("breed_name", "?"),
		"前缀: %s" % (_next_prefix()),
		"速度: %s  耐力: %s  售价: %s" % [attrs.get("base_speed", "?"), attrs.get("base_stamina", "?"), attrs.get("price", "?")],
		"稀有度: %s" % ["常见", "稀有", "史诗", "传说"][int(attrs.get("rarity", 0))],
		"对齐品种: %s  帧尺寸: %s" % [state.get("best_match", "?"), state.get("frame_size", "?")],
	]
	_summary_label.text = "\n".join(lines)


func _next_prefix() -> String:
	var used = []
	for json_path in [RES_BREEDS_JSON, USER_BREEDS_JSON]:
		var f = FileAccess.open(json_path, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Array:
				for entry in data:
					if entry is Dictionary and entry.has("prefix"):
						used.append(str(entry["prefix"]))
	var n = 1
	while used.has("ai_%d" % n) or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(USER_FRAMES_DIR + "ai_%d_run" % n)):
		n += 1
	return "ai_%d" % n


## 向导"完成注册"按钮入口
func finish():
	_on_register()


func _set_busy(v: bool):
	_busy = v
	_register_btn.disabled = v


func _on_register():
	if _busy:
		return
	var prefix = _next_prefix()
	var attrs: Dictionary = state.get("attributes", {})
	var name: String = state.get("breed_name", "")
	if name.strip_edges() == "":
		_err_label.text = "缺少马名，请返回第 1 步"
		return
	if not attrs.has("base_speed"):
		_err_label.text = "缺少属性配置，请返回第 2 步"
		return

	_set_busy(true)
	_err_label.text = ""
	wizard.set_status("⏳ 正在注册…", Color(0.3, 0.5, 0.8, 1.0))
	var err = _do_register(prefix, name, attrs)
	_set_busy(false)
	if err != "":
		_err_label.text = err
		wizard.set_status("❌ 注册失败", Color(0.8, 0.2, 0.1, 1.0))
		return

	var tres_path = USER_BREEDS_DIR + prefix + ".tres"
	state["registered"] = { "prefix": prefix, "tres_path": tres_path }
	_summary_label.text = "✅ 注册成功！\n\n" + _summary_label.text + "\n\n帧目录: %s\n资源文件: %s" % [
		USER_FRAMES_DIR + prefix + "_run/", tres_path]
	wizard.set_status("✅ 注册完成：%s（%s），正在重启游戏…" % [name, prefix], Color(0.2, 0.55, 0.25, 1.0))
	# 注册数据已写入 user://，重启游戏进程以全新状态加载
	OS.set_restart_on_exit(true)
	get_tree().quit()


## 返回空串表示成功，否则返回错误信息
func _do_register(prefix: String, name: String, attrs: Dictionary) -> String:
	# 1. 复制动画帧到 user://ai_horses/frames/<prefix>_run/frames/
	#    导出后无编辑器 import 扫描，DirAccess 直接可用（不需要 Python 复制）
	var src = ProjectSettings.globalize_path(state["frames_dir"])
	var dst = ProjectSettings.globalize_path(USER_FRAMES_DIR + prefix + "_run/frames")
	var err = DirAccess.make_dir_recursive_absolute(dst)
	if err != OK:
		return "无法创建目录 %s (%s)" % [dst, error_string(err)]
	var count = 0
	while FileAccess.file_exists(src + "/%d.png" % (count + 1)):
		count += 1
	if count == 0:
		return "没有可复制的帧"
	for i in range(1, count + 1):
		var e = DirAccess.copy_absolute(src + "/%d.png" % i, dst + "/%d.png" % i)
		if e != OK:
			return "复制帧 %d 失败: %s" % [i, error_string(e)]
	if not FileAccess.file_exists(dst + "/1.png"):
		return "复制帧失败（目标帧缺失）"

	# 2. 生成 .tres 到 user://ai_horses/breeds/
	var breed = load("res://scripts/resources/horse_breed.gd").new()
	breed.breed_name = name
	breed.base_speed = float(attrs.get("base_speed", 60.0))
	breed.base_stamina = float(attrs.get("base_stamina", 25.0))
	breed.personality_min = float(attrs.get("personality_min", 0.0))
	breed.personality_max = float(attrs.get("personality_max", 100.0))
	breed.temper_min = float(attrs.get("temper_min", 0.0))
	breed.temper_max = float(attrs.get("temper_max", 100.0))
	breed.obedience_min = float(attrs.get("obedience_min", 0.0))
	breed.rarity = int(attrs.get("rarity", 0))
	breed.spawn_weight = 40.0
	breed.color = Color.BROWN
	breed.encyclopedia_text = str(attrs.get("encyclopedia_text", ""))
	var tres_dir = ProjectSettings.globalize_path(USER_BREEDS_DIR)
	if not DirAccess.dir_exists_absolute(tres_dir):
		DirAccess.make_dir_recursive_absolute(tres_dir)
	var tres_path = USER_BREEDS_DIR + prefix + ".tres"
	err = ResourceSaver.save(breed, tres_path)
	if err != OK:
		return "保存 .tres 失败: %s" % error_string(err)

	# 3. 注册到 BreedRegistry（运行时自动写 user://ai_horses/breeds.json）
	get_node("/root/BreedRegistry").register_breed(name, prefix, int(attrs.get("price", 0)), tres_path)
	return ""


# （删除功能已移到第 1 步"上传马的照片"页）
