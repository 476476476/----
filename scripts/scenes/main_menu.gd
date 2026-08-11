extends Control

@onready var gold_label = $Panel/VBox/GoldLabel
@onready var best_dist_label = $Panel/VBox/BestDistLabel
@onready var stats_label = $Panel/VBox/StatsLabel
@onready var activity_status = $Panel/VBox/Activities/StatusLabel

var _tutorial_overlay: Control = null
var _tutorial_panel: Control = null
var _tutorial_detail_label: RichTextLabel = null
var _tutorial_buttons: Array[Button] = []

const TUTORIAL_DATA = [
	{"category": "游戏内操作", "items": [
		{"title": "游戏操作", "text": "点击 W/S 可以控制马的方向，点击鼠标左键，骑手向指定方向跳出，躲避出现的障碍物，争取跑得更远吧！"},
		{"title": "跳跃换马", "text": "点击鼠标左键，骑手向指定方向跳出，当马在人的可骑乘范围内，再次点击鼠标左键，即可骑上另一匹马，原先的马将会停下。不停换马是保证跑得更远的基石。"},
		{"title": "马的耐力", "text": "不管是自己骑的马还是野马都有自己的耐力。当你发现自己的马快要没耐力了，你需要马上再找一匹有活力的马。不要怕，你骑上的新马都是有活力的。但如果你发现一匹跑得越来越慢的野马，它可能马上没力气了，尽管你骑上它耐力会恢复，但这不是一个好选择，因为它可能正好累了导致你无马可骑。"},
		{"title": "游戏结束", "text": "当你的马累死了、无马可骑、撞上障碍物的时候，游戏将结束。\n• 马累死了：即你骑的马没有耐力了，在没耐力的最后三秒会有提示\n• 无马可骑：当你跳起来直到落地都没有骑上马的时候，你将无马可骑\n• 撞上障碍物：对你来说，前方的马、石头、栅栏都是障碍物，撞上游戏将会结束"},
		{"title": "金币获取", "text": "在游戏结束的时候，你会根据当前游戏中跑的距离获得奖励，这些金币可以用于提升自己、培养马匹。"},
		{"title": "马匹获取", "text": "在一局游戏中，你可以不停换马。在游戏结束的时候，这些马将被你捕获，你可以选择其中的一匹放入你的马厩，这匹马将成为你的忠实伙伴。"},
		{"title": "马匹狂暴", "text": "当你的能力或者性格不足以驯服这匹马，那么当你跳到它身上的那一刻，它就会试图反抗——狂躁地左右摇晃，这个时候你没有办法控制它的方向。你需要尽快换到别的马身上，不然它可能带你撞到其他东西上。"},
	]},
	{"category": "马", "items": [
		{"title": "马的品种", "text": "不同的马有着不同的稀有度：普通、稀有、史诗、传说。根据马匹品种的不同，基础属性也将不同。\n• 蒙古马（普通）：基础速度 40，耐力 20，性格和脾气范围较宽\n• 伊犁马（稀有）：基础速度 55，耐力 15\n• 纯血马（史诗）：基础速度 72，耐力 15\n• 汗血宝马（传说）：基础速度 65，耐力 30，性格和脾气范围极窄，最难驯服"},
		{"title": "马的速度", "text": "不同品种的马有着基础的速度，但在这基础之上，有些马可能天赋异禀，有些马可能生性懒惰，因此即使是同一品种，速度也各不相同。此外，马的忠诚度越高，速度加成也越高——每 1 点忠诚度提升 1 点速度。"},
		{"title": "马的性格与脾气", "text": "每匹马都有性格值和脾气值，性格温顺或暴躁、脾气柔和或刚烈各不相同。骑手的性格和脾气属性需要与马匹匹配，否则骑上后马匹可能狂暴反抗。不同品种的马性格和脾气的范围也不同——传说级别的马性格脾气范围更窄，意味着它们更难驯服。"},
		{"title": "马的顺从度", "text": "顺从度是衡量马匹是否容易驾驭的标准。驯服能力高的骑手更容易驾驭顺从度门槛高的马。如果骑手不能满足马匹的顺从条件（三项中至少满足两项），骑上后马匹就会进入狂暴状态。"},
		{"title": "马的耐力", "text": "不同品种的马基础耐力各不相同，同一品种的马耐力也有个体差异——有的天生耐力充沛，有的则稍显不足。当耐力耗尽时马匹会力竭倒下。在马棚中喂养马匹提升好感度，可以少量增加马的耐力上限——每 20 点好感度增加 1 点耐力。"},
		{"title": "马的忠诚", "text": "每匹马都有忠诚度，根据它累计奔跑的距离增长——跑得越多，忠诚度越高。忠诚的马跑得更快，忠诚度最高可提升至 100 点。"},
		{"title": "马的好感", "text": "在马棚中花费金币喂养马匹可以提升好感度（每次花费 50 金币，好感度 +2，最高 100）。好感度越高，马的耐力越高。善待你的马，它会在关键时刻跑得更久。"},
	]},
	{"category": "骑手", "items": [
		{"title": "骑手属性", "text": "骑手有四种可培养的属性：\n• 性格偏好：影响你与马匹性格的匹配程度。性格偏好落在马匹的性格范围内，满足一项驯服条件\n• 脾气偏好：影响你与马匹脾气的匹配程度。脾气偏好落在马匹的脾气范围内，满足一项驯服条件\n• 驯服能力：决定了你能驾驭多高顺从门槛的马。驯服能力超过马的顺从门槛，满足一项驯服条件\n• 跳跃力量：影响你从马上跳起时的飞行速度和距离，取值范围 1-20\n以上三项（性格、脾气、驯服能力）满足至少两项，马匹才不会狂暴。"},
		{"title": "属性提升", "text": "在主页面中通过每日活动消耗金币来提升属性。\n• 读书：性格 -2，花费 50g\n• 喝酒：性格 +2，花费 50g\n• 冥想：脾气 -2，花费 50g\n• 打拳：脾气 +2，花费 50g\n• 驯马：驯服能力 +2，花费 100g"},
	]},
	{"category": "马棚", "items": [
		{"title": "马棚容量", "text": "马棚最多可以容纳 5 匹马。初始会赠送你一匹蒙古马作为起步伙伴，帮助你踏上征程。"},
		{"title": "马匹管理", "text": "在马棚中你可以查看每匹马的详细信息：品种、速度、耐力、奔跑距离、忠诚度和好感度。你可以给马匹改名、花费 50 金币喂养提升好感度，也可以将不需要的马匹出售换取金币。"},
		{"title": "马匹来源", "text": "游戏中骑过的野马在结算时可以捕获放入马棚。只有放入马棚的马才会成为你的永久伙伴，下次可以从选马界面选择它出战。"},
	]},
	{"category": "主页面", "items": [
		{"title": "开始游戏", "text": "点击「开始游戏」进入选马界面。你可以选择一匹马棚中的马出战，也可以选择随机野马直接开始冒险。"},
		{"title": "马棚与设置", "text": "点击「马棚」管理你的马匹收藏；点击「设置」调整主音量、音效和音乐的独立音量，找到最适合你的听觉体验。"},
		{"title": "每日活动", "text": "主页面下方是每日活动区。消耗金币可以锻炼骑手的不同属性。注意规划金币的使用——属性值直接影响你驯服马匹的成功率和跳跃能力。"},
		{"title": "最远记录", "text": "主页面顶部显示当前金币数和历史最远奔跑距离记录，它会一直激励你不断超越自己，挑战更远的距离！"},
	]},
]

func _ready():
	$EncyclopediaBtn.pressed.connect(_on_encyclopedia_pressed)
	$Panel/VBox/StartButton.pressed.connect(_on_start_pressed)
	$Panel/VBox/SubButtons/StableButton.pressed.connect(_on_stable_pressed)
	$Panel/VBox/SubButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	$Panel/VBox/SubButtons/TutorialButton.pressed.connect(_on_tutorial_pressed)
	$Panel/VBox/SubButtons/AiCreateButton.pressed.connect(_on_ai_create_pressed)
	$Panel/VBox/QuitButton.pressed.connect(_on_quit_pressed)
	$Panel/VBox/Activities/HBox/ReadButton.pressed.connect(_on_read_pressed)
	$Panel/VBox/Activities/HBox/DrinkButton.pressed.connect(_on_drink_pressed)
	$Panel/VBox/Activities/HBox/MeditateButton.pressed.connect(_on_meditate_pressed)
	$Panel/VBox/Activities/HBox/BoxButton.pressed.connect(_on_box_pressed)
	$Panel/VBox/Activities/HBox/RideButton.pressed.connect(_on_ride_pressed)
#	添加伯乐相马
	$Panel/VBox/SubButtons/BoleAppraisalButton.pressed.connect(_on_bole_appraisal_pressed)
	_setup_styles()
	update_display()
	get_node("/root/SaveSystem").apply_resolution()

func _setup_styles():
	# Panel background - parchment card
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.941, 0.851, 0.710, 0.96)       # #F0D9B5
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.42, 0.23, 0.16, 1.0)        # #6B3A2A leather
	$Panel.add_theme_stylebox_override("panel", panel_style)

	# Title - gold with dark outline
	var title = $Panel/VBox/TitleLabel
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title.add_theme_constant_override("outline_size", 3)

	# Gold label - gold
	gold_label.add_theme_color_override("font_color", Color(0.91, 0.773, 0.278, 1.0))
	gold_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	gold_label.add_theme_constant_override("outline_size", 2)

	best_dist_label.add_theme_color_override("font_color", Color(0.91, 0.773, 0.278, 1.0))
	best_dist_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	best_dist_label.add_theme_constant_override("outline_size", 2)

	# Stats label - muted
	stats_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))

	# Button style templates
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)             # #6B3A2A
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 20
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)            # #8B5E3C
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 20
	btn_hover.content_margin_right = 20
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.16, 0.1, 1.0)
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.content_margin_left = 20
	btn_pressed.content_margin_right = 20
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8

	var buttons = [
		$Panel/VBox/StartButton,
		$Panel/VBox/SubButtons/StableButton,
		$Panel/VBox/SubButtons/SettingsButton,
		$Panel/VBox/SubButtons/TutorialButton,
		$Panel/VBox/SubButtons/AiCreateButton,
		$Panel/VBox/QuitButton,
		$Panel/VBox/Activities/HBox/ReadButton,
		$Panel/VBox/Activities/HBox/DrinkButton,
		$Panel/VBox/Activities/HBox/MeditateButton,
		$Panel/VBox/Activities/HBox/BoxButton,
		$Panel/VBox/Activities/HBox/RideButton,
	]

	for btn in buttons:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))

	# Activities header
	$Panel/VBox/Activities/ActivitiesLabel.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))

func update_display():
	var gm = get_node("/root/GameManager")
	gold_label.text = "金币: %d" % gm.gold
	best_dist_label.text = "最远记录: %.0f m" % (get_node("/root/SaveSystem").best_distance / 10.0)
	stats_label.text = "性格: %.0f  脾气: %.0f  驯服: %.0f  跳跃: %.0f" % [
		gm.personality_pref, gm.temper_pref, gm.tame_ability, gm.jump_power
	]

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/horse_select.tscn")

func _on_stable_pressed():
	get_tree().change_scene_to_file("res://scenes/stable_menu.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_encyclopedia_pressed():
	get_tree().change_scene_to_file("res://scenes/encyclopedia.tscn")

func _on_quit_pressed():
	var dialog = ConfirmationDialog.new()
	dialog.title = "退出游戏"
	dialog.dialog_text = "确定要退出游戏吗？"
	dialog.confirmed.connect(func(): get_tree().quit())
	add_child(dialog)
	dialog.popup_centered()

func do_activity(activity_name, p_delta, t_delta, tame_delta, cost):
	var gm = get_node("/root/GameManager")
	if not gm.can_afford(cost):
		activity_status.text = "金币不足！"
		return
	gm.spend_gold(cost)
	gm.modify_personality(p_delta)
	gm.modify_temper(t_delta)
	gm.modify_tame(tame_delta)
	activity_status.text = "%s 完成！" % activity_name
	update_display()
	get_node("/root/SaveSystem").save_game()

func _on_read_pressed():
	do_activity("读书", -2.0, 0.0, 0.0, 50)

func _on_drink_pressed():
	do_activity("喝酒", 2.0, 0.0, 0.0, 50)

func _on_meditate_pressed():
	do_activity("冥想", 0.0, -2.0, 0.0, 50)

func _on_box_pressed():
	do_activity("打拳", 0.0, 2.0, 0.0, 50)

func _on_ride_pressed():
	do_activity("驯马", 0.0, 0.0, 2.0, 100)

func _on_ai_create_pressed():
	get_tree().change_scene_to_file("res://scenes/ai_horse_create.tscn")

func _on_tutorial_pressed():
	# Clean up old popup
	_close_tutorial()
	_tutorial_buttons.clear()

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.name = "TutorialOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_tutorial())
	add_child(overlay)

	# Popup panel
	var popup = Panel.new()
	popup.name = "TutorialPopup"
	var popup_size = Vector2(700, 480)
	popup.custom_minimum_size = popup_size
	popup.size = popup_size
	var vp = get_viewport_rect().size
	popup.position = (vp - popup_size) / 2.0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.941, 0.851, 0.710, 0.98)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.42, 0.23, 0.16, 1.0)
	popup.add_theme_stylebox_override("panel", panel_style)
	add_child(popup)

	# Root VBox inside popup: title bar + content
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	popup.add_child(root_vbox)

	# Title bar
	var title_bar = HBoxContainer.new()
	title_bar.add_theme_constant_override("margin_left", 16)
	title_bar.add_theme_constant_override("margin_right", 8)
	title_bar.add_theme_constant_override("margin_top", 8)
	title_bar.add_theme_constant_override("margin_bottom", 4)
	root_vbox.add_child(title_bar)

	var title_label = Label.new()
	title_label.text = "教程"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title_label.add_theme_constant_override("outline_size", 3)
	title_bar.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
	close_btn.pressed.connect(_close_tutorial)
	title_bar.add_child(close_btn)

	# Separator under title
	var title_sep = HSeparator.new()
	title_sep.add_theme_stylebox_override("separator", _make_h_line_stylebox(Color(0.42, 0.23, 0.16, 0.4)))
	root_vbox.add_child(title_sep)

	# Main HBox: left (nav) + right (detail)
	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 0)
	root_vbox.add_child(main_hbox)

	# === LEFT: Category/Item list ===
	var left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(180, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_scroll)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	left_scroll.add_child(left_vbox)

	# === RIGHT: Detail text ===
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_scroll)

	_tutorial_detail_label = RichTextLabel.new()
	_tutorial_detail_label.bbcode_enabled = true
	_tutorial_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_detail_label.add_theme_font_size_override("normal_font_size", 16)
	_tutorial_detail_label.add_theme_color_override("default_color", Color(0.25, 0.15, 0.1, 1.0))
	_tutorial_detail_label.add_theme_constant_override("margin_left", 16)
	_tutorial_detail_label.add_theme_constant_override("margin_right", 16)
	_tutorial_detail_label.add_theme_constant_override("margin_top", 12)
	_tutorial_detail_label.add_theme_constant_override("margin_bottom", 12)
	right_scroll.add_child(_tutorial_detail_label)

	# Separator between left and right
	var sep = VSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_line_stylebox(Color(0.42, 0.23, 0.16, 0.5)))
	main_hbox.add_child(sep)

	# Build left-side items
	var is_first = true
	for cat in TUTORIAL_DATA:
		# Category header
		var cat_label = Label.new()
		cat_label.text = cat["category"]
		cat_label.add_theme_font_size_override("font_size", 20)
		cat_label.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		cat_label.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
		cat_label.add_theme_constant_override("outline_size", 2)
		cat_label.add_theme_constant_override("margin_left", 8)
		cat_label.add_theme_constant_override("margin_top", 2 if is_first else 8)
		cat_label.add_theme_constant_override("margin_bottom", 2)
		left_vbox.add_child(cat_label)
		is_first = false

		for item in cat["items"]:
			var item_btn = Button.new()
			item_btn.text = "  " + item["title"]
			item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item_btn.flat = true
			item_btn.add_theme_font_size_override("font_size", 14)
			item_btn.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
			item_btn.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))
			item_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
			item_btn.add_theme_constant_override("margin_left", 16)
			_tutorial_buttons.append(item_btn)
			item_btn.pressed.connect(_on_tutorial_item_pressed.bind(item_btn, item["text"]))
			left_vbox.add_child(item_btn)

	# References for cleanup
	_tutorial_overlay = overlay
	_tutorial_panel = popup

	# Show first item by default
	if _tutorial_buttons.size() > 0:
		_tutorial_buttons[0].emit_signal("pressed")

func _on_tutorial_item_pressed(btn: Button, text: String):
	# Update button highlight
	for b in _tutorial_buttons:
		if b == btn:
			var selected_style = StyleBoxFlat.new()
			selected_style.bg_color = Color(0.42, 0.23, 0.16, 0.5)
			b.add_theme_stylebox_override("normal", selected_style)
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			b.remove_theme_stylebox_override("normal")
			b.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	# Update detail text
	if _tutorial_detail_label:
		_tutorial_detail_label.text = text

func _close_tutorial():
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
	_tutorial_overlay = null
	_tutorial_panel = null
	_tutorial_detail_label = null
	_tutorial_buttons.clear()

func _make_line_stylebox(color: Color) -> StyleBoxLine:
	var sb = StyleBoxLine.new()
	sb.color = color
	sb.thickness = 1
	sb.vertical = true
	return sb

func _make_h_line_stylebox(color: Color) -> StyleBoxLine:
	var sb = StyleBoxLine.new()
	sb.color = color
	sb.thickness = 1
	sb.vertical = false
	return sb

# 伯乐相马
func _on_bole_appraisal_pressed():
	get_tree().change_scene_to_file("res://scenes/BoleAppraisalScene.tscn")
