extends "res://scripts/ai_horse/step_base_game.gd"
## 步骤 4：背景抠除（本地 U²-Net，CPU 处理，免费，游戏运行时版）
## 走嵌入式 Python（exe 同目录 embedded_python/），模型路径自动附加。

const AI_HORSE_ENV = preload("res://scripts/ai_horse/ai_horse_env.gd")

var _run_btn: Button
var _preview: TextureRect
var _err_label: Label
var _busy: bool = false


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("4. 抠除背景"))
	_content.add_child(_hint("本地 U²-Net 模型处理（无需联网、不花钱）。模型随游戏分发。"))

	var row = _row()
	_content.add_child(row)
	_run_btn = _button("✂️ 执行抠图", _on_run)
	_style_button(_run_btn)
	row.add_child(_run_btn)
	row.add_child(_label(_workspace() + "cutout.png", 11))

	_err_label = _error_label()
	_content.add_child(_err_label)

	_preview = _texture_rect(260)
	_content.add_child(_preview)


func on_enter():
	# 恢复：上次会话的抠图结果
	if not state.has("cutout"):
		var p = _workspace() + "cutout.png"
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
	var out = _workspace() + "cutout.png"
	_set_busy(true)
	_err_label.text = ""
	wizard.set_status("⏳ 正在抠图（CPU 推理约 3~10 秒，窗口可能短暂无响应）…", Color(0.3, 0.5, 0.8, 1.0))
	var result = AI_HORSE_ENV.run("remove_bg", [source, out])
	_set_busy(false)
	if result.code == 0 and FileAccess.file_exists(out):
		state["cutout"] = out
		_show_image(out)
		wizard.set_status("✅ 抠图完成，背景已透明", Color(0.2, 0.55, 0.25, 1.0))
	else:
		_err_label.text = "抠图失败:\n%s" % "\n".join(result.output)
		wizard.set_status("❌ 抠图失败", Color(0.8, 0.2, 0.1, 1.0))


func _set_busy(v: bool):
	_busy = v
	_run_btn.disabled = v


func _show_image(path: String):
	var img = Image.load_from_file(path)
	if img:
		_preview.texture = ImageTexture.create_from_image(img)
