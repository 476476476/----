@tool
extends EditorPlugin

const WIZARD_SCRIPT = preload("res://addons/horse_generator/ui/wizard.gd")

var _toolbar_btn: Button
var _wizard: Window


func _enter_tree():
	_toolbar_btn = Button.new()
	_toolbar_btn.text = "🐎 AI 马匹生成器"
	_toolbar_btn.pressed.connect(_open_wizard)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_btn)


func _exit_tree():
	if _toolbar_btn:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_btn)
		_toolbar_btn.queue_free()
		_toolbar_btn = null
	if _wizard and is_instance_valid(_wizard):
		_wizard.queue_free()
		_wizard = null


func _open_wizard():
	if _wizard and is_instance_valid(_wizard):
		_wizard.queue_free()
	_wizard = WIZARD_SCRIPT.new()
	EditorInterface.get_base_control().add_child(_wizard)
	_wizard.popup_centered(Vector2(860, 620))
