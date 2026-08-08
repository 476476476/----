extends Control

@onready var slots_container = $CenterContainer/Panel/VBox/Slots
@onready var status_label = $CenterContainer/Panel/VBox/StatusLabel

var selected_slot = -1
var _slot_buttons = []
var _detail_popup = null
var _training_popup = null
var _expand_btn = null

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

const BREED_BASE_PRICE = {
	"蒙古马": 10,
	"伊犁马": 50,
	"纯血马": 100,
	"汗血宝马": 500,
		"赤兔马": 1000,
		"绝影": 250,
		"白蹄乌": 70,
		"爪黄飞电": 8,
		"的卢": 12,
		"乌骓": 900,
}

func _ready():
	$CenterContainer/Panel/VBox/BackButton.pressed.connect(_on_back_pressed)
	_setup_styles()
	_setup_scroll()
	_setup_expand_button()
	_refresh_slots()

func _setup_scroll():
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
	slots_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vbox = $CenterContainer/Panel/VBox
	var idx = slots_container.get_index()
	vbox.remove_child(slots_container)
	inner_center.add_child(slots_container)
	vbox.add_child(scroll)
	vbox.move_child(scroll, idx)

func _setup_expand_button():
	var gm = get_node("/root/GameManager")
	_expand_btn = Button.new()
	_expand_btn.text = "扩容 +1 （1000g）"
	_expand_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_expand_btn.add_theme_font_size_override("font_size", 18)
	_setup_button_style(_expand_btn)
	_expand_btn.pressed.connect(_on_expand_pressed)
	var vbox = $CenterContainer/Panel/VBox
	vbox.add_child(_expand_btn)
	vbox.move_child(_expand_btn, -1)

func _on_expand_pressed():
	var gm = get_node("/root/GameManager")
	if gm.expand_stable():
		_refresh_slots()
		status_label.text = "马棚已扩容至 %d 槽" % gm.max_stable_slots
	else:
		status_label.text = "金币不足！需要 1000g"

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

	status_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_bottom = 6

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 16
	btn_hover.content_margin_right = 16
	btn_hover.content_margin_top = 6
	btn_hover.content_margin_bottom = 6

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.16, 0.1, 1.0)
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.content_margin_left = 16
	btn_pressed.content_margin_right = 16
	btn_pressed.content_margin_top = 6
	btn_pressed.content_margin_bottom = 6

	var btns = [$CenterContainer/Panel/VBox/BackButton]
	for btn in btns:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))

func _refresh_slots():
	for child in slots_container.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var gm = get_node("/root/GameManager")

	var stall_normal = StyleBoxFlat.new()
	stall_normal.bg_color = Color(0.25, 0.15, 0.08, 1.0)
	stall_normal.corner_radius_top_left = 6
	stall_normal.corner_radius_top_right = 6
	stall_normal.corner_radius_bottom_left = 6
	stall_normal.corner_radius_bottom_right = 6
	stall_normal.border_width_left = 2
	stall_normal.border_width_right = 2
	stall_normal.border_width_top = 2
	stall_normal.border_width_bottom = 2
	stall_normal.border_color = Color(0.42, 0.23, 0.16, 1.0)

	for i in range(gm.stables.size()):
		var horse = gm.stables[i]

		var stall = Panel.new()
		stall.name = "Slot%d" % i
		stall.custom_minimum_size = Vector2(180, 150)
		stall.size_flags_horizontal = Control.SIZE_FILL
		stall.size_flags_vertical = Control.SIZE_FILL
		stall.add_theme_stylebox_override("panel", stall_normal)

		var stall_vbox = VBoxContainer.new()
		stall_vbox.name = "VBox"
		stall_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		stall_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stall_vbox.add_theme_constant_override("separation", 4)
		stall.add_child(stall_vbox)

		var tex_rect = TextureRect.new()
		tex_rect.name = "TextureRect"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(0, 110)

		if horse != null:
			var prefix = BREED_FILE_MAP.get(horse.breed.breed_name, "")
			if prefix == "":
				prefix = BreedRegistry.get_prefix(horse.breed.breed_name)
			if prefix == "":
				prefix = "mongolian"
			var frame_path = "res://Art_Resource/Horses/%s_run/frames/1.png" % prefix
			if ResourceLoader.exists(frame_path):
				tex_rect.texture = load(frame_path)
		stall_vbox.add_child(tex_rect)

		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 15)
		if horse != null:
			name_label.text = "%s\n[%s]" % [horse.horse_name, horse.breed.breed_name]
			name_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			name_label.text = "空槽位"
			name_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1.0))
		stall_vbox.add_child(name_label)

		var btn = Button.new()
		btn.name = "Button"
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.pressed.connect(_show_detail_popup.bind(i))
		stall.add_child(btn)

		_slot_buttons.append({"stall": stall, "index": i})
		slots_container.add_child(stall)

func _show_detail_popup(index):
	var gm = get_node("/root/GameManager")
	var horse = gm.stables[index]

	# Remove old popup
	if _detail_popup and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.name = "PopupOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_detail_popup())
	add_child(overlay)

	# Popup panel
	var popup = Panel.new()
	popup.name = "DetailPopup"
	popup.custom_minimum_size = Vector2(320, 440)
	popup.size = Vector2(320, 440)
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
	pvbox.add_theme_constant_override("margin_left", 6)
	pvbox.add_theme_constant_override("margin_right", 6)
	pvbox.add_theme_constant_override("margin_top", 6)
	pvbox.add_theme_constant_override("margin_bottom", 6)
	popup.add_child(pvbox)

	if horse != null:
		# Title
		var title = Label.new()
		title.text = horse.horse_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
		title.add_theme_constant_override("outline_size", 2)
		pvbox.add_child(title)

		# Texture preview with loyalty and affection badges
		var tex_container = Control.new()
		tex_container.custom_minimum_size = Vector2(0, 105)
		tex_container.set_anchors_preset(Control.PRESET_TOP_LEFT)

		var tex = TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		var prefix = BREED_FILE_MAP.get(horse.breed.breed_name, "")
		if prefix == "":
			prefix = BreedRegistry.get_prefix(horse.breed.breed_name)
		if prefix == "":
			prefix = "mongolian"
		var frame_path = "res://Art_Resource/Horses/%s_run/frames/1.png" % prefix
		if ResourceLoader.exists(frame_path):
			tex.texture = load(frame_path)
		tex_container.add_child(tex)

		var loyalty = min(int(horse.distance_run / 1000.0), 100)
		var loyalty_label = Label.new()
		loyalty_label.text = "忠诚度: %d" % loyalty
		loyalty_label.add_theme_font_size_override("font_size", 14)
		loyalty_label.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		loyalty_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
		loyalty_label.add_theme_constant_override("outline_size", 2)
		loyalty_label.position = Vector2(8, 4)
		tex_container.add_child(loyalty_label)

		var affection_label = Label.new()
		affection_label.text = "好感度: %d" % horse.affection
		affection_label.add_theme_font_size_override("font_size", 14)
		affection_label.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		affection_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
		affection_label.add_theme_constant_override("outline_size", 2)
		affection_label.position = Vector2(8, 24)
		tex_container.add_child(affection_label)

		pvbox.add_child(tex_container)

		# Info
		var info = Label.new()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
		info.text = """品种: %s (%s)
速度: %.0f m/s
耐力: %.0f s
奔跑: %.0f m
性格值: %.0f
脾气值: %.0f
顺从值: %.0f""" % [
			horse.breed.breed_name, horse.breed.get_rarity_string(),
			horse.get_actual_speed() / 10.0, horse.get_actual_stamina(),
			horse.distance_run / 10.0,
			horse.personality_mod, horse.temper_mod, horse.obedience_mod
		]
		pvbox.add_child(info)

		# Rename row
		var rename_hbox = HBoxContainer.new()
		rename_hbox.add_theme_constant_override("separation", 8)
		var rename_input = LineEdit.new()
		rename_input.placeholder_text = "输入新名字"
		rename_input.text = horse.horse_name
		rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename_hbox.add_child(rename_input)

		var rename_btn = Button.new()
		rename_btn.text = "改名"
		rename_btn.pressed.connect(func():
			var new_name = rename_input.text.strip_edges()
			if new_name.is_empty():
				return
			horse.horse_name = new_name
			status_label.text = "已改名: %s" % new_name
			get_node("/root/SaveSystem").save_game()
			_close_detail_popup()
			_refresh_slots()
		)
		_setup_button_style(rename_btn)
		rename_hbox.add_child(rename_btn)
		pvbox.add_child(rename_hbox)

		# Sell + Feed row
		var sell_hbox = HBoxContainer.new()
		sell_hbox.add_theme_constant_override("separation", 8)

		# Train + Sell row (equal width, fill full width)
		var train_btn = Button.new()
		train_btn.text = "培养马匹"
		train_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if horse.affection >= 100:
			train_btn.disabled = true
			train_btn.text = "培养已满"
		train_btn.pressed.connect(func(): _show_training_popup(horse, info, affection_label, train_btn, index))
		_setup_button_style(train_btn)
		sell_hbox.add_child(train_btn)

		var price = _calc_sell_price(horse)
		var sell_btn = Button.new()
		sell_btn.text = "卖出 (%d 金币)" % price
		sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_btn.pressed.connect(func(): _show_sell_confirm(index, horse))
		_setup_button_style(sell_btn)
		sell_hbox.add_child(sell_btn)
		pvbox.add_child(sell_hbox)
	else:
		var empty_label = Label.new()
		empty_label.text = "空槽位"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		pvbox.add_child(empty_label)

		var hint = Label.new()
		hint.text = "游戏结束后可将骑过的马放入"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))
		pvbox.add_child(hint)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(_close_detail_popup)
	_setup_button_style(close_btn)
	pvbox.add_child(close_btn)

	_detail_popup = popup

func _close_detail_popup():
	if _detail_popup and is_instance_valid(_detail_popup):
		var parent = _detail_popup.get_parent()
		_detail_popup.queue_free()
		if parent:
			for child in parent.get_children():
				if child.name == "PopupOverlay":
					child.queue_free()
		_detail_popup = null

func _show_training_popup(horse, info_label, affection_label, train_btn, index):
	if _training_popup and is_instance_valid(_training_popup):
		_close_training_popup()

	var gm = get_node("/root/GameManager")

	# Overlay
	var overlay = ColorRect.new()
	overlay.name = "TrainingOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_training_popup())
	add_child(overlay)

	# Panel
	var panel = Panel.new()
	panel.name = "TrainingPopup"
	panel.custom_minimum_size = Vector2(320, 260)
	var vp = get_viewport_rect().size
	panel.position = (vp - panel.custom_minimum_size) / 2.0

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.941, 0.851, 0.710, 0.98)
	ps.corner_radius_top_left = 12
	ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = 12
	ps.corner_radius_bottom_right = 12
	ps.border_width_left = 3
	ps.border_width_right = 3
	ps.border_width_top = 3
	ps.border_width_bottom = 3
	ps.border_color = Color(0.42, 0.23, 0.16, 1.0)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 16)
	vbox.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "培养马匹 - %s" % horse.horse_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# HSeparator
	var sep = HSeparator.new()
	var ss = StyleBoxLine.new()
	ss.color = Color(0.42, 0.23, 0.16, 0.4)
	ss.thickness = 1
	sep.add_theme_stylebox_override("separator", ss)
	vbox.add_child(sep)

	# Affection display
	var aff = Label.new()
	aff.text = "当前好感度: %d / 100" % horse.affection
	aff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aff.add_theme_font_size_override("font_size", 18)
	aff.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	vbox.add_child(aff)

	# Info text
	var info = Label.new()
	info.text = "喂草可提升马匹好感度\n好感度越高，马匹耐力越强\n(每 20 点好感度 +1 耐力)"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))
	vbox.add_child(info)

	# Feed button
	var feed_btn = Button.new()
	feed_btn.text = "喂草 (好感+2, -50 金币)"
	if horse.affection >= 100:
		feed_btn.disabled = true
		feed_btn.text = "好感已满"
	feed_btn.pressed.connect(func():
		if gm.gold < 50:
			status_label.text = "金币不足"
			return
		var old_bonus = int(horse.affection / 20)
		gm.spend_gold(50)
		horse.affection = min(horse.affection + 2, 100)
		aff.text = "当前好感度: %d / 100" % horse.affection
		var new_bonus = int(horse.affection / 20)
		if new_bonus != old_bonus:
			info_label.text = """品种: %s (%s)
速度: %.0f m/s
耐力: %.0f s
奔跑: %.0f m
性格值: %.0f
脾气值: %.0f
顺从值: %.0f""" % [
				horse.breed.breed_name, horse.breed.get_rarity_string(),
				horse.get_actual_speed() / 10.0, horse.get_actual_stamina(),
				horse.distance_run / 10.0,
				horse.personality_mod, horse.temper_mod, horse.obedience_mod
			]
		get_node("/root/SaveSystem").save_game()
		status_label.text = "%s 好感度 +2" % horse.horse_name
		if horse.affection >= 100:
			feed_btn.disabled = true
			feed_btn.text = "好感已满"
			train_btn.disabled = true
			train_btn.text = "培养已满"
	)
	_setup_button_style(feed_btn)
	vbox.add_child(feed_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_training_popup)
	_setup_button_style(close_btn)
	vbox.add_child(close_btn)

	_training_popup = panel

func _close_training_popup():
	for child in get_children():
		if child.name in ["TrainingOverlay", "TrainingPopup"]:
			child.queue_free()
	_training_popup = null

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

func _calc_sell_price(horse) -> int:
	var base = BREED_BASE_PRICE.get(horse.breed.breed_name, 10)
	if base == 10 and not BREED_BASE_PRICE.has(horse.breed.breed_name):
		base = BreedRegistry.get_price(horse.breed.breed_name)
	var speed = horse.get_actual_speed() / 10.0
	var obedience = horse.obedience_mod
	var loyalty = min(int(horse.distance_run / 1000.0), 100)
	var multiplier = 1.0 + speed * 0.01 + obedience * 0.1
	return int(max(base * multiplier, 1)) + horse.affection * 10 + loyalty * 5

func _show_sell_confirm(index: int, horse):
	_close_detail_popup()

	var overlay = ColorRect.new()
	overlay.name = "SellOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_sell_popup())
	add_child(overlay)

	var panel = Panel.new()
	panel.name = "SellPopup"
	panel.custom_minimum_size = Vector2(300, 200)
	var vp = get_viewport_rect().size
	panel.position = (vp - panel.custom_minimum_size) / 2.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.941, 0.851, 0.710, 0.98)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.42, 0.23, 0.16, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 16)
	vbox.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(vbox)

	var price = _calc_sell_price(horse)
	var title = Label.new()
	title.text = "确认卖出"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	vbox.add_child(title)

	var info2 = Label.new()
	info2.text = "卖出 %s [%s] 可获得 %d 金币" % [horse.horse_name, horse.breed.breed_name, price]
	info2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info2.add_theme_font_size_override("font_size", 16)
	info2.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	vbox.add_child(info2)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	var yes_btn = Button.new()
	yes_btn.text = "确认卖出"
	yes_btn.pressed.connect(func(): _do_sell(index, horse, price))
	_setup_button_style(yes_btn)
	hbox.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "取消"
	no_btn.pressed.connect(_close_sell_popup)
	_setup_button_style(no_btn)
	hbox.add_child(no_btn)

	vbox.add_child(hbox)

	_detail_popup = panel

func _do_sell(index: int, horse, price: int):
	var gm = get_node("/root/GameManager")
	gm.add_gold(price)
	gm.stables[index] = null
	get_node("/root/SaveSystem").save_game()
	_close_sell_popup()
	_refresh_slots()
	status_label.text = "已卖出 %s，获得 %d 金币" % [horse.horse_name, price]

func _close_sell_popup():
	for child in get_children():
		if child.name in ["SellOverlay", "SellPopup"]:
			child.queue_free()
	_detail_popup = null

func _on_back_pressed():
	_close_detail_popup()
	_close_training_popup()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
