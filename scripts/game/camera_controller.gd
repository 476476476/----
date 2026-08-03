extends Camera2D

var base_x: float = 0.0

func _ready() -> void:
	base_x = global_position.x
	add_to_group("game_camera")

func get_scroll_distance() -> float:
	return global_position.x - base_x
