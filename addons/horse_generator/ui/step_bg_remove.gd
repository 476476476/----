@tool
extends "res://addons/horse_generator/ui/step_base.gd"
## 步骤 4：背景抠除（本地 U²-Net，CPU 处理，免费）

var _run_btn: Button
var _preview: TextureRect
var _err_label: Label
var _busy: bool = false


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("4. 抠除背景"))
	_content.add_child(_hint("本地 U²-Net 模型处理（无需联网、不花钱）。首次运行需 ~/.u2net/u2net.onnx 模型（已装好）。"))

	var row = _row()
	_content.add_child(row)
	_run_btn = _button("✂️ 执行抠图", _on_run)
	_style_button(_run_btn)
	row.add_child(_run_btn)
	row.add_child(_label(ProjectSettings.globalize_path("user://horse_generator_workspace/cutout.png"), 11))

	_err_label = _error_label()
	_content.add_child(_err_label)

	_preview = _texture_rect(260)
	_content.add_child(_preview)


func on_enter():
	# 恢复：上次会话的抠图结果
	if not state.has("cutout"):
		var p = ProjectSettings.globalize_path("user://horse_generator_workspace/cutout.png")
		if FileAccess.file_exists(p):
			state["cutout"] = p
	if state.has("cutout") and FileAccess.file_exists(state["cutout"]):
		_show_image(state["cutout"])


func validate() -> String:
	if not state.has("cutout") or not FileAccess.file_exists(state["cutout"]):
		return "请先执行抠图"
	return ""


func _on_run():
	if _busy:
		return
	var source: String = state.get("portrait_raw", "")
	if not FileAccess.file_exists(source):
		_err_label.text = "缺少风格化图片，请返回第 3 步"
		return
	var python = _find_python()
	if python == "":
		_err_label.text = "找不到 Python 环境：请按 ai_pipeline/README 安装虚拟环境"
		return

	# Python 不认 user:// 前缀，必须先转绝对路径
	var src_abs = ProjectSettings.globalize_path(source)
	var out = ProjectSettings.globalize_path("user://horse_generator_workspace/cutout.png")
	_set_busy(true)
	_err_label.text = ""
	wizard.set_status("⏳ 正在抠图（CPU 推理约 3~10 秒，窗口可能短暂无响应）…", Color(0.3, 0.5, 0.8, 1.0))
	_run_sync(python, src_abs, out)


func _run_sync(python: String, source: String, out: String):
	var script = ProjectSettings.globalize_path("res://ai_pipeline/remove_bg.py")
	var output = []
	var code = OS.execute(python, [script, source, out], output, true)
	_set_busy(false)
	if code == 0 and FileAccess.file_exists(out):
		state["cutout"] = out
		_show_image(out)
		wizard.set_status("✅ 抠图完成，背景已透明", Color(0.2, 0.55, 0.25, 1.0))
	else:
		_err_label.text = "抠图失败:\n%s" % "\n".join(output)
		wizard.set_status("❌ 抠图失败", Color(0.8, 0.2, 0.1, 1.0))


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


func _set_busy(v: bool):
	_busy = v
	_run_btn.disabled = v


func _show_image(path: String):
	var img = Image.load_from_file(path)
	if img:
		_preview.texture = ImageTexture.create_from_image(img)
