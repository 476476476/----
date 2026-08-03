extends Control

@onready var master_slider = $Panel/VBox/MasterVolume/Slider
@onready var master_value = $Panel/VBox/MasterVolume/ValueLabel
@onready var sfx_slider = $Panel/VBox/SFXVolume/Slider
@onready var sfx_value = $Panel/VBox/SFXVolume/ValueLabel
@onready var music_slider = $Panel/VBox/MusicVolume/Slider
@onready var music_value = $Panel/VBox/MusicVolume/ValueLabel
@onready var resolution_option = $Panel/VBox/Resolution/OptionButton
@onready var fullscreen_cb = $Panel/VBox/Fullscreen/CheckBox

func _ready():
	var am = get_node("/root/AudioManager")
	master_slider.value = am.master_volume
	sfx_slider.value = am.sfx_volume
	music_slider.value = am.music_volume
	_update_value_labels()

	# Resolution
	var ss = get_node("/root/SaveSystem")
	for res in ss.RESOLUTIONS:
		resolution_option.add_item(res["label"])
	resolution_option.selected = ss.resolution_index
	resolution_option.item_selected.connect(_on_resolution_changed)

	# Fullscreen
	fullscreen_cb.button_pressed = ss.fullscreen
	fullscreen_cb.toggled.connect(_on_fullscreen_toggled)
	resolution_option.disabled = ss.fullscreen

	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	$Panel/VBox/BackButton.pressed.connect(_on_back_pressed)
	_setup_styles()

func _setup_styles():
	# Panel background - parchment
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
	$Panel.add_theme_stylebox_override("panel", panel_style)

	# Title - gold with dark outline
	var title = $Panel/VBox/TitleLabel
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.173, 0.094, 0.063, 1.0))
	title.add_theme_constant_override("outline_size", 3)

	# Separator
	$Panel/VBox/HSeparator.add_theme_stylebox_override("separator", _make_sep_style())

	# Volume rows
	for row in [$Panel/VBox/MasterVolume, $Panel/VBox/SFXVolume, $Panel/VBox/MusicVolume]:
		var lbl = row.get_node("Label")
		lbl.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
		lbl.custom_minimum_size = Vector2(60, 0)
		var val_lbl = row.get_node("ValueLabel")
		val_lbl.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
		val_lbl.custom_minimum_size = Vector2(48, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Resolution row
	var res_label = $Panel/VBox/Resolution/Label
	res_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	res_label.custom_minimum_size = Vector2(60, 0)

	resolution_option.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))

	# Fullscreen row
	var fs_label = $Panel/VBox/Fullscreen/Label
	fs_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))
	fs_label.custom_minimum_size = Vector2(60, 0)
	fullscreen_cb.add_theme_color_override("font_color", Color(0.25, 0.15, 0.1, 1.0))

	# Back button - leather style
	var btn_back = $Panel/VBox/BackButton
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.42, 0.23, 0.16, 1.0)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 24
	btn_normal.content_margin_right = 24
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.545, 0.37, 0.235, 1.0)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 24
	btn_hover.content_margin_right = 24
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.16, 0.1, 1.0)
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.content_margin_left = 24
	btn_pressed.content_margin_right = 24
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8

	btn_back.add_theme_stylebox_override("normal", btn_normal)
	btn_back.add_theme_stylebox_override("hover", btn_hover)
	btn_back.add_theme_stylebox_override("pressed", btn_pressed)
	btn_back.add_theme_color_override("font_color", Color.WHITE)
	btn_back.add_theme_color_override("font_hover_color", Color(0.855, 0.647, 0.125, 1.0))

func _make_sep_style() -> StyleBoxLine:
	var sb = StyleBoxLine.new()
	sb.color = Color(0.42, 0.23, 0.16, 0.4)
	sb.thickness = 1
	return sb

func _update_value_labels():
	master_value.text = "%d%%" % int(master_slider.value * 100)
	sfx_value.text = "%d%%" % int(sfx_slider.value * 100)
	music_value.text = "%d%%" % int(music_slider.value * 100)

func _on_master_changed(value):
	get_node("/root/AudioManager").set_master_volume(value)
	master_value.text = "%d%%" % int(value * 100)

func _on_sfx_changed(value):
	get_node("/root/AudioManager").set_sfx_volume(value)
	sfx_value.text = "%d%%" % int(value * 100)

func _on_music_changed(value):
	get_node("/root/AudioManager").set_music_volume(value)
	music_value.text = "%d%%" % int(value * 100)

func _on_resolution_changed(index):
	var ss = get_node("/root/SaveSystem")
	ss.resolution_index = index
	ss.apply_resolution()

func _on_fullscreen_toggled(on):
	var ss = get_node("/root/SaveSystem")
	ss.fullscreen = on
	resolution_option.disabled = on
	ss.apply_resolution()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
