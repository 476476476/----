@tool
extends "res://addons/horse_generator/ui/step_base.gd"
## 步骤 7：注册到游戏（生成 .tres + 帧目录 + breeds.json）

const BREEDS_JSON = "res://resources/ai_generated_breeds/breeds.json"
const BREEDS_DIR = "res://resources/breeds/"
const HORSES_DIR = "res://Art_Resource/Horses/"

var _register_btn: Button
var _summary_label: Label
var _err_label: Label
var _busy: bool = false

var _horse_list: OptionButton
var _delete_btn: Button
var _delete_armed: bool = false
var _delete_timer: float = 0.0


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("7. 注册新马匹"))
	_content.add_child(_hint("把动画帧复制进游戏美术目录，生成 HorseBreed 资源，写入 breeds.json。注册后重启游戏即可在选马界面使用。"))

	var row = _row()
	_content.add_child(row)
	_register_btn = _button("🚀 注册到游戏", _on_register)
	_style_button(_register_btn)
	row.add_child(_register_btn)

	row = _row()
	_content.add_child(row)
	row.add_child(_label("已注册 AI 马匹"))
	_horse_list = OptionButton.new()
	_horse_list.custom_minimum_size = Vector2(200, 0)
	row.add_child(_horse_list)
	_delete_btn = _button("🗑️ 删除选中", _on_delete)
	_style_button(_delete_btn)
	_delete_btn.disabled = true
	row.add_child(_delete_btn)

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
	_refresh_horse_list()


func _process(delta):
	# 删除按钮两段式确认：5 秒内不二次点击则恢复原状
	if _delete_armed:
		_delete_timer -= delta
		if _delete_timer <= 0:
			_reset_delete()


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
	var f = FileAccess.open(BREEDS_JSON, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			for entry in data:
				if entry is Dictionary and entry.has("prefix"):
					used.append(str(entry["prefix"]))
	var n = 1
	while used.has("ai_%d" % n) or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(HORSES_DIR + "ai_%d_run" % n)):
		n += 1
	return "ai_%d" % n


## 向导"完成注册"按钮入口
func finish():
	_on_register()


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

	var tres_path = BREEDS_DIR + prefix + ".tres"
	state["registered"] = { "prefix": prefix, "tres_path": tres_path }
	_summary_label.text = "✅ 注册成功！\n\n" + _summary_label.text + "\n\n帧目录: %s\n资源文件: %s\n\n重启游戏即可在选马界面找到「%s」。\n（若编辑器尚未刷新资源，请让 Godot 扫描文件系统：编辑 → 重新扫描资源文件）" % [
		HORSES_DIR + prefix + "_run/", tres_path, name]
	wizard.set_status("✅ 注册完成：%s（%s）" % [name, prefix], Color(0.2, 0.55, 0.25, 1.0))
	_refresh_horse_list()


## 返回空串表示成功，否则返回错误信息
func _do_register(prefix: String, name: String, attrs: Dictionary) -> String:
	# 1. 复制动画帧到游戏美术目录
	var src = ProjectSettings.globalize_path(state["frames_dir"])
	var dst = ProjectSettings.globalize_path(HORSES_DIR + prefix + "_run/frames")
	# 逐级创建：make_dir_recursive_absolute 在编辑器里对多级新目录不可靠
	# （递归时被编辑器文件系统干扰，建一层就失败）；也避开 get_base_dir
	# 对尾斜杠路径的解析问题。这里用绝对路径单级创建，最直接可靠。
	var cur = ProjectSettings.globalize_path(HORSES_DIR)
	for seg in [prefix + "_run", "frames"]:
		cur = cur + seg + "/"
		if not DirAccess.dir_exists_absolute(cur):
			var err = DirAccess.make_dir_absolute(cur)
			if err != OK:
				return "无法创建目录 %s (%s)" % [cur, error_string(err)]
	var count = 0
	while FileAccess.file_exists(src + "/%d.png" % (count + 1)):
		count += 1
	if count == 0:
		return "没有可复制的帧"
	# 复制走 Python shutil：编辑器对 res:// 的 import 扫描会锁住文件句柄，
	# 导致 DirAccess.copy_absolute 间歇失败（headless 无扫描所以全部成功）。
	var python = _find_python()
	if python == "":
		return "找不到 Python 环境，无法复制帧"
	var copy_script = ProjectSettings.globalize_path("res://ai_pipeline/copy_frames.py")
	var output = []
	var code = OS.execute(python, [copy_script, src, dst, str(count)], output, true)
	if code != 0 or not FileAccess.file_exists(dst + "/1.png"):
		return "复制帧失败: %s" % "\n".join(output).strip_edges()

	# 2. 生成 .tres
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
	var tres_path = BREEDS_DIR + prefix + ".tres"
	var err = ResourceSaver.save(breed, tres_path)
	if err != OK:
		return "保存 .tres 失败: %s" % error_string(err)

	# 3. 追加 breeds.json
	var entries = []
	var f = FileAccess.open(BREEDS_JSON, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			entries = data
	var found = false
	for entry in entries:
		if entry is Dictionary and entry.get("name", "") == name:
			entry["prefix"] = prefix
			entry["price"] = int(attrs.get("price", 0))
			entry["path"] = tres_path
			found = true
	if not found:
		entries.append({
			"name": name,
			"prefix": prefix,
			"price": int(attrs.get("price", 0)),
			"path": tres_path,
		})
	var w = FileAccess.open(BREEDS_JSON, FileAccess.WRITE)
	if w == null:
		return "无法写入 %s" % BREEDS_JSON
	w.store_string(JSON.stringify(entries, "\t"))

	# 4. 若编辑器中有 BreedRegistry autoload 则热更新（编辑态一般没有，静默跳过）
	var reg = Engine.get_singleton("BreedRegistry")
	if reg != null and reg.has_method("register_breed"):
		reg.register_breed(name, prefix, int(attrs.get("price", 0)), tres_path)

	return ""


func _set_busy(v: bool):
	_busy = v
	_register_btn.disabled = v


# ---------- 删除已注册马匹 ----------

func _load_entries() -> Array:
	var f = FileAccess.open(BREEDS_JSON, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		return data
	return []


func _refresh_horse_list():
	_horse_list.clear()
	var entries = _load_entries()
	for entry in entries:
		if entry is Dictionary:
			_horse_list.add_item("%s（%s）" % [entry.get("name", "?"), entry.get("prefix", "?")])
	_delete_btn.disabled = entries.is_empty()
	_reset_delete()


func _on_delete():
	if _horse_list.item_count == 0 or _busy:
		return
	if not _delete_armed:
		_delete_armed = true
		_delete_timer = 5.0
		_delete_btn.text = "⚠️ 再点一次确认"
		_delete_btn.modulate = Color(0.9, 0.3, 0.2, 1.0)
		return
	var entries = _load_entries()
	if _horse_list.selected < 0 or _horse_list.selected >= entries.size():
		return
	var entry = entries[_horse_list.selected]
	var name = str(entry.get("name", ""))
	var prefix = str(entry.get("prefix", ""))

	# 1. 从 breeds.json 移除
	entries = entries.filter(func(e): return e is Dictionary and str(e.get("name", "")) != name)
	var w = FileAccess.open(BREEDS_JSON, FileAccess.WRITE)
	if w == null:
		_err_label.text = "无法写入 breeds.json"
		_reset_delete()
		return
	w.store_string(JSON.stringify(entries, "\t"))

	# 2. 删 .tres + 帧目录（走 Python 带重试，DirAccess.remove_absolute
	#    在编辑器 import 扫描锁文件时静默失败，已证实会残留）
	var python = _find_python()
	if prefix != "" and python != "":
		var tres_abs = ProjectSettings.globalize_path(BREEDS_DIR + prefix + ".tres")
		var dir_abs = ProjectSettings.globalize_path(HORSES_DIR + prefix + "_run")
		var script = ProjectSettings.globalize_path("res://ai_pipeline/delete_asset.py")
		var out = []
		var code = OS.execute(python, [script, tres_abs, dir_abs], out, true)
		if code != 0:
			_err_label.text = "注册记录已移除，但文件残留（%s）" % "\n".join(out).strip_edges()
			wizard.set_status("⚠️ 记录已删，文件残留", Color(0.9, 0.5, 0.1, 1.0))
			return

	_refresh_horse_list()
	wizard.set_status("🗑️ 已删除「%s」" % name, Color(0.7, 0.4, 0.2, 1.0))
	if Engine.has_singleton("EditorInterface"):
		EditorInterface.get_resource_filesystem().scan()


func _reset_delete():
	_delete_armed = false
	_delete_timer = 0.0
	_delete_btn.text = "🗑️ 删除选中"
	_delete_btn.modulate = Color.WHITE


func _find_python() -> String:
	# 优先虚拟环境，其次系统 python
	var venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/Scripts/python.exe")
	if FileAccess.file_exists(venv):
		return venv
	venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/bin/python3")
	if FileAccess.file_exists(venv):
		return venv
	for name in ["python", "python3"]:
		var out = []
		var code = OS.execute(name, ["--version"], out)
		if code == 0:
			return name
	return ""
