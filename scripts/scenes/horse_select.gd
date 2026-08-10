extends Control

@onready var horse_list = $CenterContainer/Panel/VBox/HorseList
@onready var info_label = $CenterContainer/Panel/VBox/InfoLabel

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

func _ready():
	_setup_styles()
	_setup_scroll()
	_refresh_list()

func _setup_scroll():
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner_center = CenterContainer.new()
	inner_center.name = "InnerCenter"
	inner_center.size_flags_horizontal = Control.SIZE_FILL
	inner_center.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(inner_center)
	horse_list.custom_minimum_size = Vector2(500, 0)
	horse_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vbox = $CenterContainer/Panel/VBox
	var idx = horse_list.get_index()
	vbox.remove_child(horse_list)
	inner_center.add_child(horse_list)
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

	info_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))

func _make_btn_style():
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6

	return {"normal": normal, "hover": hover}

func _refresh_list():
	for child in horse_list.get_children():
		child.queue_free()

	var gm = get_node("/root/GameManager")
	var style = _make_btn_style()
	horse_list.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in range(gm.stables.size()):
		var horse = gm.stables[i]
		if horse == null:
			continue

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_FILL
		row.add_theme_constant_override("separation", 10)
		horse_list.add_child(row)

		# Thumbnail
		var tex = TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(80, 60)
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var prefix = BREED_FILE_MAP.get(horse.breed.breed_name, "")
		if prefix == "":
			prefix = BreedRegistry.get_prefix(horse.breed.breed_name)
		if prefix == "":
			prefix = "mongolian"
		var frame_path = "res://Art_Resource/Horses/%s_run/frames/1.png" % prefix
		if ResourceLoader.exists(frame_path):
			tex.texture = load(frame_path)
		row.add_child(tex)

		# Select button with info
		var btn = Button.new()
		btn.text = "%s [%s]\n速度: %.0f m/s  耐力: %.0f s" % [
			horse.horse_name, horse.breed.breed_name,
			horse.get_actual_speed() / 10.0, horse.get_actual_stamina()
		]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_stylebox_override("normal", style.normal)
		btn.add_theme_stylebox_override("hover", style.hover)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
		btn.pressed.connect(_on_horse_selected.bind(i))
		row.add_child(btn)

	# Random horse row
	var rand_row = HBoxContainer.new()
	rand_row.add_theme_constant_override("separation", 10)
	horse_list.add_child(rand_row)

	var rand_tex = TextureRect.new()
	rand_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rand_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rand_tex.custom_minimum_size = Vector2(80, 60)
	rand_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rand_path = "res://Art_Resource/Horses/mongolian_run/frames/1.png"
	if ResourceLoader.exists(rand_path):
		rand_tex.texture = load(rand_path)
	rand_row.add_child(rand_tex)

	var rand_btn = Button.new()
	rand_btn.text = "不使用自己的马（随机蒙古马）"
	rand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rand_btn.add_theme_stylebox_override("normal", style.normal)
	rand_btn.add_theme_stylebox_override("hover", style.hover)
	rand_btn.add_theme_color_override("font_color", Color.WHITE)
	rand_btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
	rand_btn.pressed.connect(_on_random_selected)
	rand_row.add_child(rand_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_stylebox_override("normal", style.normal)
	back_btn.add_theme_stylebox_override("hover", style.hover)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
	back_btn.pressed.connect(_on_back_pressed)
	horse_list.add_child(back_btn)

func _on_horse_selected(index):
	var gm = get_node("/root/GameManager")
	gm.selected_horse_index = index
	if index < 0 or index >= gm.stables.size() or gm.stables[index] == null:
		return
	info_label.text = "已选择: %s" % gm.stables[index].horse_name
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")

func _on_random_selected():
	get_node("/root/GameManager").selected_horse_index = -1
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
