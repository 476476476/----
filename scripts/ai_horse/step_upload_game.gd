extends "res://scripts/ai_horse/step_base_game.gd"
## 步骤 1：上传马照片 + 命名（游戏运行时版）
## 附带"已注册 AI 马匹"管理（删除功能，原在第 7 步，移到这里方便随时清理）。

const USER_BREEDS_JSON = "user://ai_horses/breeds.json"
const USER_BREEDS_DIR = "user://ai_horses/breeds/"
const USER_FRAMES_DIR = "user://ai_horses/frames/"
const BREED_REGISTRY = preload("res://scripts/autoload/breed_registry.gd")

var _file_dialog: FileDialog
var _preview: TextureRect
var _name_edit: LineEdit
var _err_label: Label

var _horse_list: OptionButton
var _delete_btn: Button
var _delete_armed: bool = false
var _delete_timer: float = 0.0


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("1. 上传马的照片"))
	_content.add_child(_hint("上传一张清晰的马侧面全身照（奔跑姿态最佳）。照片只用于生成，不上传任何隐私信息。"))

	var row = _row()
	_content.add_child(row)
	var pick_btn = _button("📁 选择照片…", _on_pick_photo)
	_style_button(pick_btn)
	row.add_child(pick_btn)
	row.add_child(_label(_workspace(), 11))

	_preview = _texture_rect(150)
	_content.add_child(_preview)

	_content.add_child(HSeparator.new())
	_content.add_child(_label("种类名（可修改）："))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "例如：雪原飞骏"
	_content.add_child(_name_edit)

	_err_label = _error_label()
	_content.add_child(_err_label)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png ; PNG 图片", "*.jpg ; JPG 图片", "*.jpeg ; JPEG 图片"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

	# 已注册 AI 马匹管理（删除）
	_content.add_child(HSeparator.new())
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


func on_enter():
	# 恢复：上次会话的工作区产物（向导重开/翻页时自动找回，不重复花钱）
	if not state.has("photo_path"):
		for ext in ["jpg", "png"]:
			var p = _workspace() + "upload." + ext
			if FileAccess.file_exists(p):
				state["photo_path"] = p
				break
	if state.has("photo_path") and not state["photo_path"].is_empty():
		_refresh_preview()
	_refresh_horse_list()


func _process(delta):
	# 删除按钮两段式确认：5 秒内不二次点击则恢复原状
	if _delete_armed:
		_delete_timer -= delta
		if _delete_timer <= 0:
			_reset_delete()


func validate() -> String:
	if not state.has("photo_path") or state["photo_path"].is_empty():
		return "请先选择一张马的照片"
	var name = _name_edit.text.strip_edges()
	if name.is_empty():
		return "请给新马起个名字"
	state["breed_name"] = name
	return ""


func _on_pick_photo():
	_file_dialog.popup_centered(Vector2(700, 480))


func _on_file_selected(path: String):
	var img = Image.load_from_file(path)
	if img == null:
		_err_label.text = "无法读取图片文件（格式不支持或文件损坏）"
		return
	# 统一转 PNG + 限制尺寸：AI 接口对图片大小有上限，且 MIME 前缀恒为 image/png
	if img.get_width() > 1024 or img.get_height() > 1024:
		var scale = 1024.0 / max(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale))
	DirAccess.make_dir_recursive_absolute(_workspace())
	var dst = _workspace() + "upload.png"
	var err = img.save_png(dst)
	if err != OK:
		_err_label.text = "保存照片失败: %s" % error_string(err)
		return
	state["photo_path"] = dst
	_refresh_preview()
	_err_label.text = ""


func _refresh_preview():
	var path: String = state["photo_path"]
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			_preview.texture = ImageTexture.create_from_image(img)


# ---------- 已注册 AI 马匹：删除 ----------

func _load_entries() -> Array:
	var f = FileAccess.open(USER_BREEDS_JSON, FileAccess.READ)
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
	if _horse_list.item_count == 0:
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

	# 1. 从 user:// breeds.json 移除（按 prefix 精确删：同名多匹马只删选中的那匹）
	entries = entries.filter(func(e): return e is Dictionary and str(e.get("prefix", "")) != prefix)
	var w = FileAccess.open(USER_BREEDS_JSON, FileAccess.WRITE)
	if w == null:
		_err_label.text = "无法写入 breeds.json"
		_reset_delete()
		return
	w.store_string(JSON.stringify(entries, "\t"))
	w.close()  # 必须先关闭句柄落盘，否则 reload 读到的是被截断的空文件
	get_node("/root/BreedRegistry").reload()

	# 2. 删 .tres + 帧目录（user:// 无文件锁，DirAccess 直接删）
	if prefix != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_BREEDS_DIR + prefix + ".tres"))
		_remove_recursive(ProjectSettings.globalize_path(USER_FRAMES_DIR + prefix + "_run"))

	# 3. 同步清理马棚：凡 breed_path 反推前缀等于被删前缀的马整匹移除
	var gm = get_node("/root/GameManager")
	for i in range(gm.stables.size()):
		var horse = gm.stables[i]
		if horse == null or horse.breed == null:
			continue
		if BREED_REGISTRY.prefix_from_path(horse.breed.resource_path) != prefix:
			continue
		gm.stables[i] = null
	if gm.selected_horse_index < 0 or gm.selected_horse_index >= gm.stables.size() \
			or gm.stables[gm.selected_horse_index] == null:
		gm.selected_horse_index = -1
		for i in range(gm.stables.size()):
			if gm.stables[i] != null:
				gm.selected_horse_index = i
				break
	get_node("/root/SaveSystem").save_game()

	_refresh_horse_list()
	_err_label.text = "🗑️ 已删除「%s」" % name


## DirAccess.remove_absolute 只能删空目录，这里递归删除
func _remove_recursive(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			var full = path + "/" + fname
			if dir.current_is_dir():
				_remove_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _reset_delete():
	_delete_armed = false
	_delete_timer = 0.0
	_delete_btn.text = "🗑️ 删除选中"
	_delete_btn.modulate = Color.WHITE
