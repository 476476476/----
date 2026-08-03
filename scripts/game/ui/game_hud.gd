extends CanvasLayer

@onready var distance_label = $VBox/DistanceLabel
@onready var best_dist_label = $VBox/BestDistLabel
@onready var horse_label = $VBox/HorseLabel
@onready var stamina_bar = $VBox/StaminaBar

func _process(_delta):
	var nodes = get_tree().get_nodes_in_group("game_scene")
	if nodes.is_empty():
		return
	var scene = nodes[0]
	if not scene.game_running:
		return

	distance_label.text = "距离: %.0f m" % (scene.distance_traveled / 10.0)
	best_dist_label.text = "最远: %.0f m" % (SaveSystem.best_distance / 10.0)
	var p = scene.player
	if p and p.on_horse:
		var h = p.on_horse.horse_data
		horse_label.text = "%s [%s] 速度:%.0f m/s" % [h.horse_name, h.breed.breed_name, h.get_actual_speed() / 10.0]
		stamina_bar.max_value = h.get_actual_stamina()
		stamina_bar.value = p.on_horse.get_stamina_ratio() * h.get_actual_stamina()
	else:
		horse_label.text = "未骑马！"
		stamina_bar.value = 0
