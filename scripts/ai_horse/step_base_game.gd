extends PanelContainer
## 向导步骤基类（游戏运行时版，无 @tool）。
## 子类实现 _build_content() 构建 UI，
## 通过 wizard 传入的 state 字典读写共享数据。

var wizard: Node
var state: Dictionary = {}

var _content: VBoxContainer


func setup(p_wizard: Node, p_state: Dictionary):
	wizard = p_wizard
	state = p_state
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.87, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.23, 0.16, 1.0)
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	_build_content(_content)


## 子类实现：构建步骤内容
func _build_content(_content: VBoxContainer):
	pass


## 子类实现：进入步骤时刷新（如显示已生成结果）
func on_enter():
	pass


## 子类实现：校验是否可进入下一步，返回错误信息（空 = 通过）
func validate() -> String:
	return ""


# ---------- 工具 ----------
func _title(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.62, 0.4, 0.16, 1.0))
	return label


func _label(text: String, size: int = 13) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	# 内容区是浅色羊皮纸面板，游戏默认主题白字看不清 → 统一深棕
	label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.05, 1.0))
	return label


func _hint(text: String) -> Label:
	var label = _label(text, 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _error_label() -> Label:
	var label = _label("", 13)
	label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.1, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(on_pressed)
	return btn


func _make_btn_style():
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 5
	hover.content_margin_bottom = 5

	return {"normal": normal, "hover": hover}


func _style_button(btn: Button):
	var s = _make_btn_style()
	btn.add_theme_stylebox_override("normal", s.normal)
	btn.add_theme_stylebox_override("hover", s.hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))


func _texture_rect(max_height: int) -> TextureRect:
	var tex = TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(0, max_height)
	tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tex


## 工作区绝对路径（user://ai_horses/workspace/）
func _workspace() -> String:
	return ProjectSettings.globalize_path("user://ai_horses/workspace/")
