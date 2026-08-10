@tool
extends "res://addons/horse_generator/ui/step_base.gd"
## 步骤 5：背高验证（本地测量 + 与 10 个品种比对，免费）

var _run_btn: Button
var _result_label: Label
var _err_label: Label
var _busy: bool = false


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("5. 背高验证与对齐"))
	_content.add_child(_hint("测量马的肩隆高度（排除耳朵/头颈），与游戏 10 个品种比对，选出背高最接近的品种作为动画对齐基准。"))

	var row = _row()
	_content.add_child(row)
	_run_btn = _button("📏 测量背高并比对", _on_run)
	_style_button(_run_btn)
	row.add_child(_run_btn)

	_err_label = _error_label()
	_content.add_child(_err_label)

	_result_label = _label("")
	_result_label.add_theme_color_override("font_color", Color(0.2, 0.35, 0.2, 1.0))
	_content.add_child(_result_label)


func on_enter():
	# 恢复：上次会话的背高测量结果
	if not state.has("measure_json"):
		var p = ProjectSettings.globalize_path("user://horse_generator_workspace/measure.json")
		if FileAccess.file_exists(p):
			state["measure_json"] = p
	if state.has("measure_json") and FileAccess.file_exists(state["measure_json"]):
		_show_result(state["measure_json"])


func validate() -> String:
	if not state.has("measure_json") or not FileAccess.file_exists(state["measure_json"]):
		return "请先执行背高测量"
	return ""


func _on_run():
	if _busy:
		return
	var source: String = state.get("cutout", "")
	if not FileAccess.file_exists(source):
		_err_label.text = "缺少抠图结果，请返回第 4 步"
		return
	var python = _find_python()
	if python == "":
		_err_label.text = "找不到 Python 环境"
		return

	var out = ProjectSettings.globalize_path("user://horse_generator_workspace/measure.json")
	var ref_dir = ProjectSettings.globalize_path("res://Art_Resource/Horses")
	var script = ProjectSettings.globalize_path("res://ai_pipeline/measure_back.py")
	_set_busy(true)
	_err_label.text = ""
	wizard.set_status("⏳ 正在测量背高并比对 10 个品种…", Color(0.3, 0.5, 0.8, 1.0))
	var output = []
	var code = OS.execute(python, [script, source, ref_dir, out], output, true)
	_set_busy(false)
	if code == 0 and FileAccess.file_exists(out):
		state["measure_json"] = out
		_show_result(out)
		wizard.set_status("✅ 背高验证完成", Color(0.2, 0.55, 0.25, 1.0))
	else:
		_err_label.text = "测量失败:\n%s" % "\n".join(output)
		wizard.set_status("❌ 测量失败", Color(0.8, 0.2, 0.1, 1.0))


func _show_result(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		return
	state["best_match"] = data["best_match"]
	state["frame_size"] = data["frame_size"]
	var lines = [
		"✅ 最匹配品种: %s" % data["best_match"],
		"   背高: %d px（输入）/ %d px（参考）" % [data["back_height"], data["ref_back_height"]],
		"   对齐帧尺寸: %dx%d" % [data["frame_size"][0], data["frame_size"][1]],
		"   显示背高基准: %.1f" % data["display_back_height"],
	]
	_result_label.text = "\n".join(lines)


func _find_python() -> String:
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
