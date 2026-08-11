@tool
extends "res://addons/horse_generator/ui/step_base.gd"
## 步骤 6：run 动画生成（SiliconFlow Wan2.2 图生视频 → 本地抽帧对齐）

const ANIM_PROMPT = (
	"Animated galloping horse, side view, full body visible, " +
	"stylized 2D game art matching the source image style, " +
	"solid pure white background, no ground, no grass, no scene elements, " +
	"running loop, character consistent, " +
	"no text, no watermark"
)

const FRAME_COUNT = 24
const FRAME_SECONDS = 1.5  # 只取视频前 1.5 秒抽帧：帧间隔 62ms，动画更平滑

var _prompt_edit: TextEdit
var _gen_btn: Button
var _preview: TextureRect
var _err_label: Label
var _busy: bool = false

var _frame_index: int = 0
var _frame_count: int = 0
var _anim_timer: Timer


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("6. 生成奔跑动画（run）"))
	_content.add_child(_hint("图生视频（Wan2.2-I2V，约 ¥2/条，5 秒）→ 本地抽帧 24 帧 → 按背高对齐到参考品种帧尺寸。生成约需 1~3 分钟。"))

	_content.add_child(_label("动作提示词（可修改）：", 12))
	_prompt_edit = TextEdit.new()
	_prompt_edit.text = ANIM_PROMPT
	_prompt_edit.custom_minimum_size = Vector2(0, 70)
	_content.add_child(_prompt_edit)

	var row = _row()
	_content.add_child(row)
	_gen_btn = _button("🎬 生成 run 动画（¥2）", _on_generate)
	_style_button(_gen_btn)
	row.add_child(_gen_btn)

	_err_label = _error_label()
	_content.add_child(_err_label)

	_preview = _texture_rect(240)
	_content.add_child(_preview)

	# 循环预览：逐帧播放跑动动画
	_anim_timer = Timer.new()
	_anim_timer.wait_time = 1.0 / 12.0
	_anim_timer.timeout.connect(_next_frame)
	_content.add_child(_anim_timer)


func on_enter():
	# 恢复：工作区已有帧（视频已生成但向导中断时，直接沿用，不再花 ¥2）
	if not state.has("frames_dir"):
		var p = ProjectSettings.globalize_path("user://horse_generator_workspace/frames")
		if FileAccess.file_exists(p + "/1.png"):
			state["frames_dir"] = p
	if state.has("frames_dir") and FileAccess.file_exists(state["frames_dir"] + "/1.png"):
		_start_preview()


func validate() -> String:
	if not state.has("frames_dir") or not FileAccess.file_exists(state["frames_dir"] + "/1.png"):
		return "请先生成 run 动画"
	return ""


func _on_generate():
	if _busy:
		return
	var source: String = state.get("cutout", "")
	if not FileAccess.file_exists(source):
		_err_label.text = "缺少抠图结果，请返回第 4 步"
		return
	if not state.has("measure_json"):
		_err_label.text = "缺少背高测量结果，请返回第 5 步"
		return
	if not wizard.get_config().has_api_key():
		_err_label.text = "未配置 API Key（见窗口顶部提示）"
		return

	_set_busy(true)
	_err_label.text = ""
	wizard.set_status("⏳ 正在提交视频生成任务…", Color(0.3, 0.5, 0.8, 1.0))
	wizard.get_client().submit_video(
		_prompt_edit.text, source,
		_on_submitted, _on_api_error)


func _on_submitted(request_id: String):
	wizard.set_status("⏳ 视频生成中（约 1~3 分钟），自动轮询状态…", Color(0.3, 0.5, 0.8, 1.0))
	wizard.get_client().poll_video(request_id, _on_video_ok, _on_api_error)


func _on_video_ok(video_url: String):
	wizard.set_status("⏳ 视频完成，正在下载…", Color(0.3, 0.5, 0.8, 1.0))
	var mp4 = ProjectSettings.globalize_path("user://horse_generator_workspace/run.mp4")
	wizard.get_client().download_file(video_url, mp4, _on_downloaded, _on_api_error)


func _on_downloaded(mp4_path: String):
	_frames_from_video(mp4_path)


func _frames_from_video(mp4_path: String):
	var python = _find_python()
	if python == "":
		_err_label.text = "找不到 Python 环境"
		_set_busy(false)
		return
	var frames_dir = ProjectSettings.globalize_path("user://horse_generator_workspace/frames")
	var script = ProjectSettings.globalize_path("res://ai_pipeline/process_video.py")
	var measure_path = ProjectSettings.globalize_path(state["measure_json"])
	wizard.set_status("⏳ 正在抽帧并对齐（24 帧 × 本地抠图，约 30~90 秒）…", Color(0.3, 0.5, 0.8, 1.0))
	var output = []
	var code = OS.execute(python, [script, mp4_path, frames_dir, measure_path, str(FRAME_COUNT), str(FRAME_SECONDS)], output, true)
	_set_busy(false)
	if code == 0 and FileAccess.file_exists(frames_dir + "/1.png"):
		state["frames_dir"] = frames_dir
		_start_preview()
		wizard.set_status("✅ 动画生成完成：%d 帧" % _frame_count, Color(0.2, 0.55, 0.25, 1.0))
	else:
		_err_label.text = "抽帧失败:\n%s" % "\n".join(output)
		wizard.set_status("❌ 抽帧失败", Color(0.8, 0.2, 0.1, 1.0))


func _on_api_error(msg: String):
	_set_busy(false)
	_err_label.text = "动画生成失败: " + msg
	wizard.set_status("❌ " + msg, Color(0.8, 0.2, 0.1, 1.0))


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
	_gen_btn.disabled = v


func _show_frame(index: int):
	var path: String = state["frames_dir"] + "/%d.png" % index
	var img = Image.load_from_file(path)
	if img:
		_preview.texture = ImageTexture.create_from_image(img)


func _start_preview():
	_frame_count = 0
	while FileAccess.file_exists(state["frames_dir"] + "/%d.png" % (_frame_count + 1)):
		_frame_count += 1
	_frame_index = 0
	_show_frame(1)
	if _frame_count > 1:
		_anim_timer.start()


func _next_frame():
	if _frame_count <= 1:
		return
	_frame_index = (_frame_index + 1) % _frame_count
	_show_frame(_frame_index + 1)
