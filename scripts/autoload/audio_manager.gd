extends Node

var master_volume = 1.0
var sfx_volume = 1.0
var music_volume = 1.0

func set_master_volume(v):
	master_volume = clamp(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

func set_sfx_volume(v):
	sfx_volume = clamp(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))

func set_music_volume(v):
	music_volume = clamp(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))

func play_sfx(sound):
	if sound == null:
		return
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_music(music):
	if music == null:
		return
	for child in get_children():
		if child is AudioStreamPlayer and child.bus == "Music":
			child.stop()
			child.queue_free()
	var player = AudioStreamPlayer.new()
	player.stream = music
	player.bus = "Music"
	add_child(player)
	player.play()
