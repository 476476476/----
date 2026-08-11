extends Control
## AI 马匹生成器主向导（游戏运行时版）：7 步流程控制 + 共享状态
## 全屏场景，从主菜单进入，返回主菜单退出。

const STEP_NAMES = ["① 上传照片", "② 属性配置", "③ 风格化生成", "④ 背景抠除", "⑤ 背高验证", "⑥ 动画生成", "⑦ 完成注册"]

const STEP_SCRIPTS = [
	preload("res://scripts/ai_horse/step_upload_game.gd"),
	preload("res://scripts/ai_horse/step_config_game.gd"),
	preload("res://scripts/ai_horse/step_portrait_game.gd"),
	preload("res://scripts/ai_horse/step_bg_remove_game.gd"),
	preload("res://scripts/ai_horse/step_back_verify_game.gd"),
	preload("res://scripts/ai_horse/step_animation_game.gd"),
	preload("res://scripts/ai_horse/step_finalize_game.gd"),
]

const SILICONFLOW_CLIENT = preload("res://scripts/ai_horse/ai_horse_client.gd")
const CONFIG = preload("res://scripts/ai_horse/ai_horse_config.gd")

var state: Dictionary = {}

var _client: Node
var _config: RefCounted
var _step_chips: Array = []
var _step_instances: Array = []
var _current_step: int = 0

var _content_container: Control
var _btn_prev: Button
var _btn_next: Button
var _status_label: Label


func _ready():
	_config = CONFIG.new()
	_client = SILICONFLOW_CLIENT.new()
	_client.api_key = _config.get_api_key()
	add_child(_client)

	_build_ui()
	_refresh_api_status()
	_goto_step(0)


func get_client() -> Node:
	return _client


func get_config() -> RefCounted:
	return _config


# ---------- UI ----------
func _build_ui():
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	# 标题行
	var title_row = _row()
	root.add_child(title_row)
	var title_label = Label.new()
	title_label.text = "🐎 AI 马匹生成管线"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	var close_btn = Button.new()
	close_btn.text = "✕ 返回主菜单"
	close_btn.pressed.connect(_on_back)
	title_row.add_child(close_btn)

	# 步骤指示条
	var chip_row = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	root.add_child(chip_row)
	for i in range(STEP_NAMES.size()):
		var chip = Label.new()
		chip.text = STEP_NAMES[i]
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_constant_override("outline_size", 1)
		chip.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.08, 1.0))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_row.add_child(chip)
		_step_chips.append(chip)

	# 状态行
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	# 内容区
	_content_container = PanelContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.78, 0.66, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_content_container.add_theme_stylebox_override("panel", style)
	root.add_child(_content_container)

	# 内容滚动容器：步骤内容超高时可滚动，底部按钮始终可见
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_container.add_child(scroll)
	var step_host = VBoxContainer.new()
	step_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(step_host)
	_content_container = step_host

	# 底部按钮行
	var btn_row = _row()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)
	_btn_prev = Button.new()
	_btn_prev.text = "← 上一步"
	_btn_prev.pressed.connect(func(): _goto_step(_current_step - 1))
	btn_row.add_child(_btn_prev)
	_btn_next = Button.new()
	_btn_next.text = "下一步 →"
	_btn_next.pressed.connect(_on_next_pressed)
	btn_row.add_child(_btn_next)


func _row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _refresh_api_status():
	if _config.has_api_key():
		_status_label.text = "✅ SiliconFlow API Key 已配置（%s）" % _config.masked_key()
		_status_label.add_theme_color_override("font_color", Color(0.2, 0.55, 0.25, 1.0))
	else:
		_status_label.text = "⚠️ 未配置 API Key：请在「设置」界面填入 SiliconFlow API Key（AI 马匹生成需要）"
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.45, 0.1, 1.0))


func set_status(text: String, color: Color = Color(0.3, 0.3, 0.35, 1.0)):
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


# ---------- 步骤切换 ----------
func _goto_step(index: int):
	index = clampi(index, 0, STEP_NAMES.size() - 1)
	if _current_step < _step_instances.size():
		_step_instances[_current_step].visible = false
	_current_step = index

	while _step_instances.size() <= index:
		var step_script: GDScript = STEP_SCRIPTS[_step_instances.size()]
		var step = step_script.new()
		_content_container.add_child(step)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step.setup(self, state)
		_step_instances.append(step)

	var current = _step_instances[index]
	current.visible = true
	current.on_enter()

	for i in range(_step_chips.size()):
		var chip: Label = _step_chips[i]
		if i == index:
			chip.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1.0))
		elif i < index:
			chip.add_theme_color_override("font_color", Color(0.55, 0.75, 0.5, 1.0))
		else:
			chip.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 1.0))

	_btn_prev.disabled = index == 0
	var is_last = index == STEP_NAMES.size() - 1
	_btn_next.text = "下一步 →"
	_btn_next.visible = not is_last


func _on_next_pressed():
	var step = _step_instances[_current_step]
	var err = step.validate()
	if not err.is_empty():
		set_status("❌ " + err, Color(0.8, 0.2, 0.1, 1.0))
		return
	if _current_step == STEP_NAMES.size() - 1:
		if step.has_method("finish"):
			step.finish()
		return
	_goto_step(_current_step + 1)


func _on_back():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
