@tool
extends "res://addons/horse_generator/ui/step_base.gd"
## 步骤 1：上传马照片 + 命名

var _file_dialog: FileDialog
var _preview: TextureRect
var _name_edit: LineEdit
var _err_label: Label


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("1. 上传马的照片"))
	_content.add_child(_hint("上传一张清晰的马侧面全身照（奔跑姿态最佳）。照片只用于生成，不上传任何隐私信息。"))

	var row = _row()
	_content.add_child(row)
	var pick_btn = _button("📁 选择照片…", _on_pick_photo)
	_style_button(pick_btn)
	row.add_child(pick_btn)
	row.add_child(_label(ProjectSettings.globalize_path(_workspace()), 11))

	_preview = _texture_rect(220)
	_content.add_child(_preview)

	_content.add_child(HSeparator.new())
	_content.add_child(_label("给这匹新马起个名字（中文，将显示在游戏中）："))
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


func on_enter():
	# 恢复：上次会话的工作区产物（向导重开/翻页时自动找回，不重复花钱）
	if not state.has("photo_path"):
		for ext in ["jpg", "png"]:
			var p = ProjectSettings.globalize_path(_workspace()) + "upload." + ext
			if FileAccess.file_exists(p):
				state["photo_path"] = p
				break
	if state.has("photo_path") and not state["photo_path"].is_empty():
		_refresh_preview()


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
	# 复制到工作区，保留原扩展名（jpg/jpeg/png），Godot 按扩展名选择解码器
	var ext = path.get_extension().to_lower()
	if ext != "png":
		ext = "jpg"
	var dst = ProjectSettings.globalize_path(_workspace()) + "upload." + ext
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_workspace()))
	var err = DirAccess.copy_absolute(path, dst)
	if err != OK:
		_err_label.text = "复制照片失败: %s" % error_string(err)
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


func _workspace() -> String:
	return "user://horse_generator_workspace/"
