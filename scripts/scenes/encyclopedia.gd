extends Control

const BREED_PATHS = [
	"res://resources/breeds/mongolian.tres",
	"res://resources/breeds/zhuahuang.tres",
	"res://resources/breeds/dilu.tres",
	"res://resources/breeds/yili.tres",
	"res://resources/breeds/baitiwu.tres",
	"res://resources/breeds/thoroughbred.tres",
	"res://resources/breeds/jueying.tres",
	"res://resources/breeds/ferghana.tres",
	"res://resources/breeds/wuzhui.tres",
	"res://resources/breeds/chitu.tres",
]

const BREED_FILE_MAP = {
	"蒙古马": "mongolian",
	"伊犁马": "yili",
	"纯血马": "thoroughbred",
	"汗血宝马": "ferghana",
	"赤兔马": "chitu",
	"绝影": "jueying",
	"白蹄乌": "baitiwu",
	"爪黄飞电": "zhuahuang",
	"的卢": "dilu",
	"乌骓": "wuzhui",
}

var _detail_popup = null
var _detail_overlay = null

@onready var cards_container = $CenterContainer/Panel/VBox/Cards

func _ready():
	$CenterContainer/Panel/VBox/BackButton.pressed.connect(_on_back_pressed)
	_setup_styles()
	_setup_scroll()
	_build_cards()

func _setup_scroll():
	var cards = cards_container
	var vbox = $CenterContainer/Panel/VBox
	var idx = cards.get_index()
	vbox.remove_child(cards)

	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var inner_center = CenterContainer.new()
	inner_center.name = "InnerCenter"
	inner_center.size_flags_horizontal = Control.SIZE_FILL
	inner_center.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(inner_center)
	inner_center.add_child(cards)

	vbox.add_child(scroll)
	vbox.move_child(scroll, idx)

func _setup_styles():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.941, 0.851, 0.710, 0.96)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.42, 0.23, 0.16, 1.0)
	$CenterContainer/Panel.add_theme_stylebox_override("panel", panel_style)

	var title = $CenterContainer/Panel/VBox/TitleLabel
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title.add_theme_constant_override("outline_size", 3)

func _build_cards():
	var gm = get_node("/root/GameManager")
	var unlock_hint = $CenterContainer/Panel/VBox/UnlockHint

	for child in cards_container.get_children():
		child.queue_free()

	# 按品种名分组：同名（内置 + 玩家重名注册）合并为一张卡片
	var all_paths = BREED_PATHS + BreedRegistry.get_all_breed_paths()
	var groups: Dictionary = {}  # name -> Array[breed]
	var breed_paths: Dictionary = {}  # breed 实例 -> 来源 path
	for path in all_paths:
		var breed = load(path)
		if breed == null:
			continue
		breed_paths[breed] = path
		if not groups.has(breed.breed_name):
			groups[breed.breed_name] = []
		groups[breed.breed_name].append(breed)

	var unlocked_count = 0
	for group in groups.values():
		# 解锁判定：组内任一品种已解锁即算
		var unlocked = false
		for b in group:
			if gm.is_breed_unlocked(breed_paths[b]):
				unlocked = true
				break
		if unlocked:
			unlocked_count += 1

		# 卡片显示实例：优先玩家注册版（有 user:// 来源时）
		var display = group[0]
		for b in group:
			if str(breed_paths[b]).begins_with("user://"):
				display = b
				break

		var card = Panel.new()
		card.custom_minimum_size = Vector2(190, 160)
		card.size_flags_horizontal = Control.SIZE_FILL
		card.size_flags_vertical = Control.SIZE_FILL

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.25, 0.15, 0.08, 1.0)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0.42, 0.23, 0.16, 1.0)
		card.add_theme_stylebox_override("panel", card_style)

		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)

		if unlocked:
			var tex = TextureRect.new()
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(0, 100)
			var thumb = _load_thumb(_breed_frame_path(display, breed_paths[display]))
			if thumb:
				tex.texture = thumb
			vbox.add_child(tex)

			var name_label = Label.new()
			name_label.text = "%s%s\n[%s]" % [
				display.breed_name,
				" ×%d" % group.size() if group.size() > 1 else "",
				display.get_rarity_string()]
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 15)
			name_label.add_theme_color_override("font_color", Color.WHITE)
			vbox.add_child(name_label)
		else:
			var qmark = Label.new()
			qmark.text = "???"
			qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qmark.add_theme_font_size_override("font_size", 40)
			qmark.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3, 1.0))
			qmark.custom_minimum_size = Vector2(0, 100)
			qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vbox.add_child(qmark)

			var hint = Label.new()
			hint.text = display.breed_name
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", 14)
			hint.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))
			vbox.add_child(hint)

		var btn = Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		if unlocked:
			btn.pressed.connect(_show_detail_group.bind(group, breed_paths, 0))
		else:
			btn.pressed.connect(func():
				unlock_hint.text = "尚未发现该品种，将马匹收入马厩即可解锁"
				unlock_hint.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
			)
		card.add_child(btn)

		cards_container.add_child(card)

	unlock_hint.text = "已解锁 %d / %d 种" % [unlocked_count, groups.size()]


## 按实例来源取帧路径：user:// 实例 → 玩家帧（registry 前缀）；res:// → 内置帧（BREED_FILE_MAP）。
## 重名时两个版本必须各取各的帧，不能只按名字查（名字会被 registry 的 user 条目覆盖）。
func _breed_frame_path(breed, path: String) -> String:
	# 前缀从 .tres 路径反推：同名多匹马各取各的帧
	var prefix = BreedRegistry.prefix_from_path(path)
	if prefix == "":
		prefix = "mongolian"
	return BreedRegistry.get_frame_path(prefix, "run", 1)


func _load_thumb(path: String) -> Texture2D:
	if path.begins_with("user://"):
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
		return null
	if ResourceLoader.exists(path):
		return load(path)
	return null

## 详情弹窗：同名多品种（内置 + 玩家重名）时顶部有切换按钮，分别查看各自信息
func _show_detail_group(group: Array, breed_paths: Dictionary, index: int = 0):
	# 切换/重开时清掉旧的弹窗和遮罩（queue_free 延迟释放，遮罩必须单独跟踪清理，否则累积黑屏）
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
		_detail_popup = null
	if _detail_overlay and is_instance_valid(_detail_overlay):
		_detail_overlay.queue_free()
		_detail_overlay = null

	var overlay = ColorRect.new()
	overlay.name = "PopupOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_detail())
	add_child(overlay)
	_detail_overlay = overlay

	var popup = Panel.new()
	popup.name = "DetailPopup"
	popup.custom_minimum_size = Vector2(360, 480)
	popup.size = Vector2(360, 480)
	var vp = get_viewport_rect().size
	popup.position = (vp - popup.size) / 2.0

	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.941, 0.851, 0.710, 0.98)
	popup_style.corner_radius_top_left = 12
	popup_style.corner_radius_top_right = 12
	popup_style.corner_radius_bottom_left = 12
	popup_style.corner_radius_bottom_right = 12
	popup_style.border_width_left = 3
	popup_style.border_width_right = 3
	popup_style.border_width_top = 3
	popup_style.border_width_bottom = 3
	popup_style.border_color = Color(0.42, 0.23, 0.16, 1.0)
	popup.add_theme_stylebox_override("panel", popup_style)
	add_child(popup)

	var pvbox = VBoxContainer.new()
	pvbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	pvbox.add_theme_constant_override("separation", 2)
	pvbox.add_theme_constant_override("margin_left", 10)
	pvbox.add_theme_constant_override("margin_right", 10)
	pvbox.add_theme_constant_override("margin_top", 10)
	pvbox.add_theme_constant_override("margin_bottom", 10)
	popup.add_child(pvbox)

	var breed = group[clampi(index, 0, group.size() - 1)]
	var src_path = str(breed_paths.get(breed, ""))

	# 内容区可滚动：切换按钮+标题+图+属性+介绍超高时不截断，关闭按钮固定底部
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pvbox.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	scroll.add_child(content)

	# 同名多品种时：编号切换按钮 1、2、3…（当前查看的编号高亮；以后加更多同名马自动按顺序编号）
	if group.size() > 1:
		var tab_row = HBoxContainer.new()
		tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
		tab_row.add_theme_constant_override("separation", 6)
		content.add_child(tab_row)
		for i in range(group.size()):
			var tab = Button.new()
			tab.text = str(i + 1)
			tab.pressed.connect(_show_detail_group.bind(group, breed_paths, i))
			_setup_button_style(tab)
			if i == index:
				tab.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1.0))
			tab_row.add_child(tab)

	# Title
	var title = Label.new()
	title.text = breed.breed_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	content.add_child(title)

	# Image（按实例来源取帧：重名时内置/玩家各显示各的图）
	var tex = TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(0, 100)
	var thumb = _load_thumb(_breed_frame_path(breed, src_path))
	if thumb:
		tex.texture = thumb
	content.add_child(tex)

	# Stats
	var stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_constant_override("line_spacing", -6)
	stats.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	stats.text = """稀有度: %s
基础速度: %.0f m/s
基础耐力: %.0f s
性格要求: %.0f ~ %.0f
脾气要求: %.0f ~ %.0f
顺从度要求: > %.0f""" % [
		breed.get_rarity_string(),
		breed.base_speed, breed.base_stamina,
		breed.personality_min, breed.personality_max,
		breed.temper_min, breed.temper_max,
		breed.obedience_min,
	]
	content.add_child(stats)

	# Encyclopedia text
	if not breed.encyclopedia_text.is_empty():
		var sep = HSeparator.new()
		content.add_child(sep)

		var enc_label = Label.new()
		enc_label.add_theme_font_size_override("font_size", 12)
		enc_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15, 1.0))
		enc_label.text = breed.encyclopedia_text
		enc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(enc_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_detail)
	_setup_button_style(close_btn)
	pvbox.add_child(close_btn)

	_detail_popup = popup

func _close_detail():
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
		_detail_popup = null
	if _detail_overlay and is_instance_valid(_detail_overlay):
		_detail_overlay.queue_free()
		_detail_overlay = null

func _setup_button_style(btn: Button):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
