extends CanvasLayer

var _ridden_horses = []
var _distance = 0.0
var _reward = 0
var _reason = ""
var _built = false

var _panel: Panel
var _vbox: VBoxContainer
var _current_horse_index = 0
var _pending_horse_data = null

func show_game_over(distance, _ridden, reward, reason):
	_distance = distance
	_reward = reward
	_ridden_horses = get_node("/root/GameManager").current_ridden_horses.duplicate()
	_reason = reason
	show()
	_build()

func _build():
	if _built:
		return
	_built = true

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.173, 0.094, 0.063, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Parchment panel - centered
	var vs = get_viewport().get_visible_rect().size
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(500, 420)
	_panel.size = Vector2(500, 420)
	_panel.position = (vs - _panel.size) / 2.0

	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.941, 0.851, 0.710, 0.96)
	ps.corner_radius_top_left = 12
	ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = 12
	ps.corner_radius_bottom_right = 12
	ps.border_width_left = 3
	ps.border_width_right = 3
	ps.border_width_top = 3
	ps.border_width_bottom = 3
	ps.border_color = Color(0.42, 0.23, 0.16, 1.0)
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 10)
	_vbox.add_theme_constant_override("margin_left", 24)
	_vbox.add_theme_constant_override("margin_right", 24)
	_vbox.add_theme_constant_override("margin_top", 20)
	_vbox.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(_vbox)

	_show_info()

# ── helpers ──────────────────────────────────────────────

func _clear_vbox():
	for child in _vbox.get_children():
		child.queue_free()

func _make_title(text: String, size := 32) -> Label:
	var lb = Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	lb.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	lb.add_theme_constant_override("outline_size", 2)
	return lb

func _make_label(text: String, size := 16) -> Label:
	var lb = Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	return lb

func _make_btn(text: String, size := 18) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", size)

	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	n.corner_radius_top_left = 6
	n.corner_radius_top_right = 6
	n.corner_radius_bottom_left = 6
	n.corner_radius_bottom_right = 6
	n.content_margin_left = 20
	n.content_margin_right = 20
	n.content_margin_top = 6
	n.content_margin_bottom = 6

	var h = StyleBoxFlat.new()
	h.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	h.corner_radius_top_left = 6
	h.corner_radius_top_right = 6
	h.corner_radius_bottom_left = 6
	h.corner_radius_bottom_right = 6
	h.content_margin_left = 20
	h.content_margin_right = 20
	h.content_margin_top = 6
	h.content_margin_bottom = 6

	var p = StyleBoxFlat.new()
	p.bg_color = Color(0.3, 0.16, 0.1, 1.0)
	p.corner_radius_top_left = 6
	p.corner_radius_top_right = 6
	p.corner_radius_bottom_left = 6
	p.corner_radius_bottom_right = 6
	p.content_margin_left = 20
	p.content_margin_right = 20
	p.content_margin_top = 6
	p.content_margin_bottom = 6

	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
	return btn

func _make_hsep() -> HSeparator:
	var sep = HSeparator.new()
	var s = StyleBoxLine.new()
	s.color = Color(0.42, 0.23, 0.16, 0.3)
	s.thickness = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep

# ── screens ──────────────────────────────────────────────

func _show_info():
	_clear_vbox()

	_vbox.add_child(_make_title("游戏结束"))

	var info = _make_label("原因: %s\n距离: %.0f m\n骑马: %d 匹\n金币: +%d" % [_reason, _distance / 10.0, _ridden_horses.size(), _reward], 20)
	_vbox.add_child(info)

	_vbox.add_child(_make_hsep())

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for horse in _ridden_horses:
		var owned = " (已有)" if horse.is_player_owned else " (可捕获)"
		var hl = _make_label("  %s [%s]%s" % [horse.horse_name, horse.breed.breed_name, owned], 15)
		scroll_vbox.add_child(hl)
	scroll.add_child(scroll_vbox)
	_vbox.add_child(scroll)

	var wild_count = 0
	for h in _ridden_horses:
		if not h.is_player_owned:
			wild_count += 1

	if wild_count > 0:
		_vbox.add_child(_make_label("有 %d 匹马可以收入马厩" % wild_count, 18))

		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)

		var yes_btn = _make_btn("逐一确认")
		yes_btn.pressed.connect(_start_horse_confirmations)
		hbox.add_child(yes_btn)

		var skip_btn = _make_btn("全部跳过")
		skip_btn.pressed.connect(_show_final_buttons)
		hbox.add_child(skip_btn)

		_vbox.add_child(hbox)
	else:
		_show_final_buttons()

func _start_horse_confirmations():
	_current_horse_index = 0
	_show_next_horse_confirmation()

func _show_next_horse_confirmation():
	while _current_horse_index < _ridden_horses.size():
		if not _ridden_horses[_current_horse_index].is_player_owned:
			break
		_current_horse_index += 1

	if _current_horse_index >= _ridden_horses.size():
		_show_final_buttons()
		return

	var horse = _ridden_horses[_current_horse_index]
	_clear_vbox()

	_vbox.add_child(_make_title("收入马厩", 28))

	var info = _make_label("是否将 %s [%s] 收入马厩？\n速度: %.0f m/s  耐力: %.0f" % [horse.horse_name, horse.breed.breed_name, horse.get_actual_speed() / 10.0, horse.get_actual_stamina()], 20)
	_vbox.add_child(info)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(spacer)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)

	var h_data = horse
	var yes_btn = _make_btn("收入")
	yes_btn.pressed.connect(func(): _try_add_horse(h_data))
	hbox.add_child(yes_btn)

	var no_btn = _make_btn("跳过")
	no_btn.pressed.connect(func():
		_current_horse_index += 1
		_show_next_horse_confirmation()
	)
	hbox.add_child(no_btn)

	_vbox.add_child(hbox)

func _try_add_horse(horse_data):
	var gm = get_node("/root/GameManager")
	if gm.add_horse_to_stable(horse_data):
		_show_add_result(horse_data, "")
	else:
		_pending_horse_data = horse_data
		_show_replace_dialog()

func _show_add_result(horse_data, replaced_name):
	_clear_vbox()

	_vbox.add_child(_make_title("收入马厩", 28))

	var msg = "%s [%s] 已收入\n替换了 %s" % [horse_data.horse_name, horse_data.breed.breed_name, replaced_name] if not replaced_name.is_empty() else "%s [%s] 已收入马厩" % [horse_data.horse_name, horse_data.breed.breed_name]
	_vbox.add_child(_make_label(msg, 20))

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(spacer)

	var ok_btn = _make_btn("继续")
	ok_btn.pressed.connect(func():
		_current_horse_index += 1
		_show_next_horse_confirmation()
	)
	_vbox.add_child(ok_btn)

func _show_replace_dialog():
	_clear_vbox()

	_vbox.add_child(_make_title("马厩已满", 28))
	_vbox.add_child(_make_label("选择要替换的马：", 18))

	var gm = get_node("/root/GameManager")
	for i in range(gm.stables.size()):
		var horse = gm.stables[i]
		if horse == null:
			continue
		var btn = _make_btn("%s [%s]  速度:%.0f  耐力:%.0f" % [horse.horse_name, horse.breed.breed_name, horse.get_actual_speed() / 10.0, horse.get_actual_stamina()], 14)
		var idx = i
		var old_name = horse.horse_name
		btn.pressed.connect(func():
			var gm2 = get_node("/root/GameManager")
			gm2.replace_horse_in_stable(idx, _pending_horse_data)
			_show_add_result(_pending_horse_data, old_name)
		)
		_vbox.add_child(btn)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_vbox.add_child(spacer)

	var cancel_btn = _make_btn("取消", 16)
	cancel_btn.pressed.connect(func():
		_current_horse_index += 1
		_show_next_horse_confirmation()
	)
	_vbox.add_child(cancel_btn)

func _show_final_buttons():
	_clear_vbox()

	_vbox.add_child(_make_title("游戏结束"))

	var info = _make_label("原因: %s\n距离: %.0f m\n骑马: %d 匹\n金币: +%d" % [_reason, _distance / 10.0, _ridden_horses.size(), _reward], 20)
	_vbox.add_child(info)

	_vbox.add_child(_make_hsep())

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var has_unowned = false
	for horse in _ridden_horses:
		if not horse.is_player_owned:
			has_unowned = true
			var hl = _make_label("  %s [%s] (未收入)" % [horse.horse_name, horse.breed.breed_name], 14)
			scroll_vbox.add_child(hl)
	scroll.add_child(scroll_vbox)
	if has_unowned:
		_vbox.add_child(scroll)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_vbox.add_child(spacer)

	var restart_btn = _make_btn("再来一局", 22)
	restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game_scene.tscn"))
	_vbox.add_child(restart_btn)

	var menu_btn = _make_btn("返回主页", 22)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_vbox.add_child(menu_btn)
