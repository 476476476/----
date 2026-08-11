extends "res://scripts/ai_horse/step_base_game.gd"
## 步骤 3：特征描述 → 图生图编辑（以游戏马帧为源图，只换毛色）
## 照片只作为特征来源：AI 分析或手填毛色/体态。
## 编辑继承源图的像素画风、奔跑姿势、朝向和构图。
## 游戏运行时版：源帧经 ResourceLoader 提取（导出后 res:// PNG 是 ctex，FileAccess 读不了）。

var _coat_edit: LineEdit
var _pattern_edit: LineEdit
var _mane_edit: LineEdit
var _build_edit: LineEdit
var _analyze_btn: Button
var _generate_btn: Button
var _preview: TextureRect
var _err_label: Label
var _busy: bool = false


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("3. 生成游戏风格静态图"))
	_content.add_child(_hint("先描述马的毛色/体态（可点 AI 自动分析照片，也可手填）。生成时以游戏自带马的像素画帧为源图直接编辑——只换毛色花纹，像素画风、奔跑姿势、朝右构图全部继承。每次约 ¥0.3，不满意可重新生成。"))

	_content.add_child(_label("马匹特征：", 12))
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)

	grid.add_child(_label("毛色"))
	_coat_edit = LineEdit.new()
	_coat_edit.placeholder_text = "如：栗色"
	_coat_edit.text = "栗色"
	grid.add_child(_coat_edit)

	grid.add_child(_label("花纹/标记"))
	_pattern_edit = LineEdit.new()
	_pattern_edit.placeholder_text = "如：额头白星，四蹄白袜"
	_pattern_edit.text = "无"
	grid.add_child(_pattern_edit)

	grid.add_child(_label("鬃毛/尾毛"))
	_mane_edit = LineEdit.new()
	_mane_edit.placeholder_text = "如：深棕色"
	_mane_edit.text = "深棕色"
	grid.add_child(_mane_edit)

	grid.add_child(_label("体态"))
	_build_edit = LineEdit.new()
	_build_edit.placeholder_text = "如：体型健壮，腿长"
	_build_edit.text = "体型健壮"
	grid.add_child(_build_edit)

	var row = _row()
	_content.add_child(row)
	_analyze_btn = _button("🔍 AI 自动分析照片", _on_analyze)
	_style_button(_analyze_btn)
	row.add_child(_analyze_btn)

	row = _row()
	_content.add_child(row)
	_generate_btn = _button("✨ 生成风格化图片（¥0.3）", _on_generate)
	_style_button(_generate_btn)
	row.add_child(_generate_btn)

	_err_label = _error_label()
	_content.add_child(_err_label)

	_preview = _texture_rect(150)
	_content.add_child(_preview)


func on_enter():
	if _busy:
		return
	# 恢复：上次会话已生成的风格化图片
	if not state.has("portrait_raw"):
		var p = _workspace() + "portrait_raw.png"
		if FileAccess.file_exists(p):
			state["portrait_raw"] = p
	if state.has("portrait_raw") and FileAccess.file_exists(state["portrait_raw"]):
		_show_image(state["portrait_raw"])


func validate() -> String:
	if not state.has("portrait_raw") or not FileAccess.file_exists(state["portrait_raw"]):
		return "请先生成风格化图片"
	return ""


## 编辑 prompt：源图是游戏马帧，只换毛色/体态，其他保持不动。
## 颜色指令必须强硬：图生图模型倾向保留源图毛色，措辞模糊会被理解成微调。
func _build_prompt() -> String:
	var parts = []
	for v in [_coat_edit.text, _pattern_edit.text, _mane_edit.text, _build_edit.text]:
		var t = v.strip_edges()
		if not t.is_empty() and t != "无":
			parts.append(t)
	var desc = "相同的毛色" if parts.is_empty() else "一匹%s的马" % "，".join(parts)
	return ("把图中的马改成为" + desc + "。马的毛色必须彻底更换为新毛色，画面中整匹马的颜色只能是新描述的颜色，"
		+ "保持原来的像素画风、奔跑姿势、朝向和构图不变，"
		+ "只改变毛色和花纹细节，其他一切保持不变，干净背景，无文字无水印")


## 取游戏自带的一匹马的 run 帧作为编辑源图（像素风/姿势/构图都继承它）。
## 固定用蒙古马帧（棕/栗色调）：源图颜色中性，改任何目标色都比红色源图可靠；
## 且避免遍历目录顺序不定（可能选到赤兔等红色帧，导致改色被源图颜色带偏）。
## 导出后 res:// PNG 转 ctex：FileAccess 读不到，必须 ResourceLoader.load() 走 remap 提取。
func _pick_base_frame() -> String:
	var cached = _workspace() + "base_frame.png"
	if FileAccess.file_exists(cached):
		return cached
	var res_path = "res://Art_Resource/Horses/mongolian_run/frames/1.png"
	var tex = ResourceLoader.load(res_path)
	if tex is Texture2D:
		var img = tex.get_image()
		if img:
			DirAccess.make_dir_recursive_absolute(_workspace())
			img.save_png(cached)
			return cached
	return ""


func _on_analyze():
	if _busy:
		return
	var source: String = state.get("photo_path", "")
	if not FileAccess.file_exists(source):
		_err_label.text = "缺少上传的照片，请返回第 1 步"
		return
	if not wizard.get_config().has_api_key():
		_err_label.text = "未配置 API Key（见窗口顶部提示）"
		return

	_set_busy(true, "analyze")
	_err_label.text = ""
	wizard.set_status("⏳ AI 正在分析照片毛色/体态（约 30~60 秒，请耐心等待）…", Color(0.3, 0.5, 0.8, 1.0))
	wizard.get_client().analyze_horse(source, _on_analyze_ok, _on_api_error)


func _on_analyze_ok(features: Dictionary):
	_set_busy(false)
	_coat_edit.text = str(features.get("coat", _coat_edit.text))
	_pattern_edit.text = str(features.get("pattern", _pattern_edit.text))
	_mane_edit.text = str(features.get("mane", _mane_edit.text))
	_build_edit.text = str(features.get("build", _build_edit.text))
	wizard.set_status("✅ 特征已填入表单，确认后可生成", Color(0.2, 0.55, 0.25, 1.0))


func _on_generate():
	if _busy:
		return
	if _build_prompt().length() < 10:
		_err_label.text = "请至少填写一个特征字段"
		return
	if not wizard.get_config().has_api_key():
		_err_label.text = "未配置 API Key（见窗口顶部提示）"
		return

	_set_busy(true, "generate")
	_err_label.text = ""
	# 每次生成（含重新生成）先删旧产物：源图缓存重新提取、旧结果清掉，避免旧图残留/颜色带偏
	var base_cache = _workspace() + "base_frame.png"
	if FileAccess.file_exists(base_cache):
		DirAccess.remove_absolute(base_cache)
	var old_portrait = _workspace() + "portrait_raw.png"
	if FileAccess.file_exists(old_portrait):
		DirAccess.remove_absolute(old_portrait)
	var base = _pick_base_frame()
	if base == "":
		_err_label.text = "找不到游戏马匹帧，无法作为编辑源图"
		_set_busy(false)
		return
	wizard.set_status("⏳ 正在基于游戏马图编辑生成（约 10~40 秒）…", Color(0.3, 0.5, 0.8, 1.0))
	# 图生图编辑：源图 = 游戏马帧，只换毛色，风格/姿势/构图继承
	wizard.get_client().generate_image(_build_prompt(), base, _on_portrait_ok, _on_api_error)


func _on_portrait_ok(path: String):
	_set_busy(false)
	state["portrait_raw"] = path
	_show_image(path)
	wizard.set_status("✅ 风格化图片生成完成，点击下一步继续", Color(0.2, 0.55, 0.25, 1.0))


func _on_api_error(msg: String):
	_set_busy(false)
	_err_label.text = "请求失败: " + msg
	if msg.find("balance") >= 0:
		_err_label.text += "\n提示：账户余额不足——可在 https://cloud.siliconflow.cn 充值，或直接手填特征表单"
	wizard.set_status("❌ " + msg, Color(0.8, 0.2, 0.1, 1.0))


func _set_busy(v: bool, _which: String = ""):
	_busy = v
	_analyze_btn.disabled = v
	_generate_btn.disabled = v


func _show_image(path: String):
	var img = Image.load_from_file(path)
	if img:
		_preview.texture = ImageTexture.create_from_image(img)
