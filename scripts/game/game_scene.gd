extends Node2D

@onready var player = $Player
@onready var horses_container = $Horses
@onready var obstacles_container = $Obstacles
@onready var camera = $Camera2D
@onready var hud = $GameHUD
@onready var game_over_panel = $GameOverPanel

var game_running = false
var distance_traveled = 0.0

var _spawn_timer = 0.0
var _obstacle_timer = 0.0
var _tripwire_timer = 0.0
var _initialized = false
var _viewport_size: Vector2

# Loading system
var _loading = true
var _load_queue = []
var _load_total = 0
var _load_done = 0
var _load_ui = null

# Game over delay
var _go_pending = false
var _go_delay = 0.0
var _go_reward = 0
var _go_reason = ""
var _go_horses = 0
var _initial_horse_stable_index = -1
var _initial_horse_data: HorseData = null
var _load_progress_bar = null
var _load_count_label = null
var _dir_frame_counts = {}

const HORSE_SCRIPT = preload("res://scripts/game/horse.gd")
const SPAWN_INTERVAL = 2.0
const OBSTACLE_INTERVAL = 3.0
const TRIPWIRE_INTERVAL = 5.0
const MAX_HORSES = 6

const FENCE_TRIGGER_RANGE = 300.0
const FENCE_EXTEND_DURATION = 1.0
const FENCE_SIZE = 122.0
const FENCE_SCALE = 0.09

func _ready():
	game_over_panel.hide()
	add_to_group("game_scene")

	_viewport_size = get_viewport().get_visible_rect().size

	camera.enabled = true
	camera.position_smoothing_enabled = false

	player.global_position = Vector2(_viewport_size.x * 0.3, _viewport_size.y * 0.5)
	camera.global_position = player.global_position
	camera.global_position.x += _viewport_size.x * 0.2

	_show_loading_screen()
	_start_preloading()

func _show_loading_screen():
	var canvas = CanvasLayer.new()
	canvas.name = "LoadingCanvas"
	canvas.layer = 100
	add_child(canvas)

	var overlay = ColorRect.new()
	overlay.name = "LoadingOverlay"
	overlay.color = Color(0.173, 0.094, 0.063, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.name = "LoadingVBox"
	vbox.add_theme_constant_override("separation", 12)

	var title = Label.new()
	title.name = "LoadingTitle"
	title.text = "加载中..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.855, 0.647, 0.125, 1.0))
	vbox.add_child(title)

	var bar = ProgressBar.new()
	bar.name = "LoadingBar"
	bar.custom_minimum_size = Vector2(300, 24)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	vbox.add_child(bar)

	var count = Label.new()
	count.name = "LoadingCount"
	count.text = "0 / 0"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7, 1.0))
	vbox.add_child(count)

	overlay.add_child(vbox)
	var vsize = _viewport_size
	vbox.position = Vector2((vsize.x - 300) / 2.0, (vsize.y - 80) / 2.0)

	_load_ui = overlay
	_load_progress_bar = bar
	_load_count_label = count

func _discover_textures():
	var paths = []

	# Obstacles
	paths.append("res://Art_Resource/Obstacles/rock.png")
	paths.append("res://Art_Resource/Obstacles/fence.png")

	# Horse frame directories to scan
	var horse_dirs = [
		"res://Art_Resource/Horses/mongolian_run/frames",
		"res://Art_Resource/Horses/mongolian_exhausted/frames",
		"res://Art_Resource/Horses/mongolian_crazy/frames",
		"res://Art_Resource/Horses/yili_run/frames",
		"res://Art_Resource/Horses/yili_exhausted/frames",
		"res://Art_Resource/Horses/yili_crazy/frames",
		"res://Art_Resource/Horses/thoroughbred_run/frames",
		"res://Art_Resource/Horses/thoroughbred_exhausted/frames",
		"res://Art_Resource/Horses/thoroughbred_crazy/frames",
		"res://Art_Resource/Horses/ferghana_run/frames",
		"res://Art_Resource/Horses/ferghana_exhausted/frames",
		"res://Art_Resource/Horses/ferghana_crazy/frames",
		"res://Art_Resource/Horses/chitu_run/frames",
		"res://Art_Resource/Horses/chitu_exhausted/frames",
		"res://Art_Resource/Horses/chitu_crazy/frames",
		"res://Art_Resource/Horses/jueying_run/frames",
		"res://Art_Resource/Horses/jueying_exhausted/frames",
		"res://Art_Resource/Horses/jueying_crazy/frames",
		"res://Art_Resource/Horses/baitiwu_run/frames",
		"res://Art_Resource/Horses/baitiwu_exhausted/frames",
		"res://Art_Resource/Horses/baitiwu_crazy/frames",
		"res://Art_Resource/Horses/zhuahuang_run/frames",
		"res://Art_Resource/Horses/zhuahuang_exhausted/frames",
		"res://Art_Resource/Horses/zhuahuang_crazy/frames",
		"res://Art_Resource/Horses/dilu_run/frames",
		"res://Art_Resource/Horses/dilu_exhausted/frames",
		"res://Art_Resource/Horses/dilu_crazy/frames",
		"res://Art_Resource/Horses/wuzhui_run/frames",
		"res://Art_Resource/Horses/wuzhui_exhausted/frames",
		"res://Art_Resource/Horses/wuzhui_crazy/frames",
	]

	var rider_dirs = [
		"res://Art_Resource/Rider/rider_ride/frames",
		"res://Art_Resource/Rider/rider_jump/frames",
		"res://Art_Resource/Rider/rider_fall/frames",
	]

	for dir_path in horse_dirs + rider_dirs:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if not dir.current_is_dir() and fname.ends_with(".png"):
					paths.append(dir_path + "/" + fname)
				fname = dir.get_next()
			dir.list_dir_end()

	return paths

func _start_preloading():
	_load_queue = _discover_textures()
	_load_total = _load_queue.size()
	_load_done = 0

	for p in _load_queue:
		var d = p.get_base_dir()
		_dir_frame_counts[d] = _dir_frame_counts.get(d, 0) + 1

	if _load_total == 0:
		_finish_loading()
		return

	var failed = 0
	for i in range(_load_queue.size() - 1, -1, -1):
		var path = _load_queue[i]
		var err = ResourceLoader.load_threaded_request(path)
		if err != OK:
			_load_queue.remove_at(i)
			failed += 1
	_load_total = _load_queue.size()
	_load_done = failed

func _poll_loading():
	if not _loading:
		return

	var still_loading = false

	for i in range(_load_queue.size()):
		var path = _load_queue[i]
		var status = ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				if path not in _load_queue:  # already counted
					continue
				# Mark as done (uses polled status internally, just track count)
				pass
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				still_loading = true
			_:
				# Failed or invalid - count as done
				pass

	if still_loading:
		_update_loading_progress()
		return false

	# All done - finalize
	for path in _load_queue:
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
		# Failed loads are just skipped

	_finish_loading()
	return true

func _update_loading_progress():
	if _load_progress_bar == null or _load_count_label == null:
		return

	# Count how many are loaded or failed
	var done = 0
	for path in _load_queue:
		var status = ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			done += 1

	var pct = int(float(done) / max(_load_total, 1) * 100.0)
	_load_progress_bar.value = pct
	_load_count_label.text = "%d / %d" % [done, _load_total]

func _build_sprite_frames_cache():
	if not GameManager.sprite_frames_cache.is_empty():
		return

	# Horse frames: 10 breeds × 3 states
	var breeds = ["mongolian", "yili", "thoroughbred", "ferghana", "chitu", "jueying", "baitiwu", "zhuahuang", "dilu", "wuzhui"]
	var states = ["run", "exhausted", "crazy"]
	var total = breeds.size() * states.size() + 3
	var done = 0
	for breed in breeds:
		for state in states:
			var key = "horse:" + breed + ":" + state
			var dir = "res://Art_Resource/Horses/" + breed + "_" + state + "/frames"
			GameManager.sprite_frames_cache[key] = _make_sprite_frames(dir, 15.0)
			done += 1
			_update_cache_progress(done, total)

	# Rider frames: 3 states
	var rider_states = {"ride": 10.0, "jump": 15.0, "fall": 10.0}
	for state in rider_states:
		var key = "rider:" + state
		var dir = "res://Art_Resource/Rider/rider_" + state + "/frames"
		GameManager.sprite_frames_cache[key] = _make_sprite_frames(dir, rider_states[state])
		done += 1
		_update_cache_progress(done, total)

func _make_sprite_frames(dir_path: String, speed: float) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default", speed)
	var count = _dir_frame_counts.get(dir_path, 0)
	for i in range(1, count + 1):
		var path = dir_path + "/" + str(i) + ".png"
		var tex = load(path)
		if tex:
			frames.add_frame("default", tex)
	return frames

func _update_cache_progress(done: int, total: int):
	if _load_progress_bar:
		_load_progress_bar.value = int(float(done) / total * 100.0)
	if _load_count_label:
		_load_count_label.text = "精灵缓存: %d / %d" % [done, total]

func _finish_loading():
	_build_sprite_frames_cache()
	if not _initialized:
		_init_game()
	if _load_ui and is_instance_valid(_load_ui):
		var canvas = _load_ui.get_parent()
		if canvas:
			canvas.queue_free()
		_load_ui = null
	_loading = false

func _physics_process(delta):
	if _loading:
		_poll_loading()
		return

	if not _initialized:
		_init_game()

	if not game_running:
		if _go_pending:
			_go_delay -= delta
			if _go_delay <= 0.0:
				_go_pending = false
				game_over_panel.show_game_over(distance_traveled, _go_horses, _go_reward, _go_reason)
		return

	var prev_x = camera.global_position.x
	_update_camera()
	distance_traveled += camera.global_position.x - prev_x

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL + randf_range(-0.5, 0.5)
		_try_spawn_horses()

	_obstacle_timer -= delta
	if _obstacle_timer <= 0.0:
		_obstacle_timer = OBSTACLE_INTERVAL + randf_range(-0.5, 0.5)
		_spawn_obstacle()

	_tripwire_timer -= delta
	if _tripwire_timer <= 0.0:
		_tripwire_timer = TRIPWIRE_INTERVAL + randf_range(-2.0, 2.0)
		_spawn_tripwire()

	_cleanup_offscreen()
	_update_walls()

	if not player.is_on_horse() and not player.jumping:
		_game_over("无马可骑")

func _init_game():
	_start_game()
	_initialized = true

func _update_camera():
	var target = player.global_position
	target.x += _viewport_size.x * 0.2
	camera.global_position = target

func _update_walls():
	var cam_x = camera.global_position.x
	for child in get_children():
		if child.name == "TopWall":
			child.global_position.x = cam_x
		elif child.name == "BottomWall":
			child.global_position.x = cam_x

func _start_game():
	get_node("/root/GameManager").start_new_game()
	game_running = true

	# Size sky and grass to viewport
	$Background/SkyLayer/Sky.size = _viewport_size
	var grass = $Background/GroundLayer/Grass
	grass.size = Vector2(grass.size.x, _viewport_size.y)

	_spawn_walls()
	_spawn_initial_horse()
	player.landed_on_horse.connect(_on_player_landed)
	player.player_fell.connect(func(): _game_over("无马可骑"))

func _spawn_walls():
	var grass = $Background/GroundLayer/Grass
	var w = _viewport_size.x * 1.5
	var h = 80.0
	var grass_top = 0.0
	var grass_bottom = grass.size.y

	var top = StaticBody2D.new()
	top.name = "TopWall"
	var ts = CollisionShape2D.new()
	var top_rect = RectangleShape2D.new()
	top_rect.size = Vector2(w, h)
	ts.shape = top_rect
	top.add_child(ts)
	top.global_position = Vector2(0, grass_top)
	add_child(top)

	var bot = StaticBody2D.new()
	bot.name = "BottomWall"
	var bcs = CollisionShape2D.new()
	var br = RectangleShape2D.new()
	br.size = Vector2(w, h)
	bcs.shape = br
	bot.add_child(bcs)
	bot.global_position = Vector2(0, grass_bottom - h + 40)
	add_child(bot)

func _spawn_initial_horse():
	var gm = get_node("/root/GameManager")
	var horse_data = null
	if gm.selected_horse_index >= 0 and gm.selected_horse_index < gm.stables.size():
		var owned = gm.stables[gm.selected_horse_index]
		if owned != null:
			horse_data = owned.clone()
			_initial_horse_stable_index = gm.selected_horse_index
	if horse_data == null:
		horse_data = _create_random_horse()
		horse_data.is_player_owned = true
	_initial_horse_data = horse_data
	var pos = Vector2(_viewport_size.x * 0.3, _viewport_size.y * 0.5)
	var horse_node = _spawn_horse(horse_data, pos)
	player.mount(horse_node)

func _try_spawn_horses():
	var current_count = horses_container.get_child_count()
	var to_spawn = randi_range(1, 2)
	for _i in range(to_spawn):
		if current_count >= MAX_HORSES:
			break
		var data = _create_random_horse()
		var y_pos = randf_range(80, _viewport_size.y - 80)
		var pos = Vector2(camera.global_position.x + _viewport_size.x + randf_range(100, 400), y_pos)
		_spawn_horse(data, pos)
		current_count += 1

const BREED_PATHS = [
	"res://resources/breeds/mongolian.tres",
	"res://resources/breeds/yili.tres",
	"res://resources/breeds/thoroughbred.tres",
	"res://resources/breeds/ferghana.tres",
	"res://resources/breeds/chitu.tres",
	"res://resources/breeds/jueying.tres",
	"res://resources/breeds/baitiwu.tres",
	"res://resources/breeds/zhuahuang.tres",
	"res://resources/breeds/dilu.tres",
	"res://resources/breeds/wuzhui.tres",
]

func _create_random_horse():
	var breeds = []
	for path in BREED_PATHS:
		breeds.append(load(path))

	var breeds_by_rarity = {0: [], 1: [], 2: [], 3: []}
	for b in breeds:
		breeds_by_rarity[b.rarity].append(b)

	var rarity_weights = {0: 75.0, 1: 15.0, 2: 8.0, 3: 2.0}
	var roll = randf() * 100.0
	var cumulative = 0.0
	var selected_rarity = 0
	for rarity in [0, 1, 2, 3]:
		cumulative += rarity_weights[rarity]
		if roll < cumulative:
			selected_rarity = rarity
			break

	var candidates = breeds_by_rarity[selected_rarity]
	var breed = candidates[randi() % candidates.size()]

	var data = HorseData.new()
	data.breed = breed
	data.horse_name = breed.breed_name
	data.speed_mod = randi_range(-10, 10)
	data.stamina_mod = randi_range(-5, 5)
	data.personality_mod = randi_range(-10, 10)
	data.temper_mod = randi_range(-10, 10)
	data.obedience_mod = randi_range(-10, 10)
	data.current_stamina = data.get_actual_stamina()
	return data

func _spawn_horse(data, pos):
	var horse = HORSE_SCRIPT.new()
	horse.setup(data, true)
	horse.global_position = pos

	var avoid_area = Area2D.new()
	avoid_area.name = "AvoidArea"
	var avoid_cs = CollisionShape2D.new()
	var avoid_circle = CircleShape2D.new()
	avoid_circle.radius = 60
	avoid_cs.shape = avoid_circle
	avoid_area.add_child(avoid_cs)
	horse.add_child(avoid_area)

	avoid_area.body_entered.connect(func(body):
		if game_running and body is GameHorse and body != horse and body == player.on_horse:
			var dy = body.global_position.y - horse.global_position.y
			horse.velocity.y = -horse.AVOID_SPEED if dy > 0 else horse.AVOID_SPEED
	)
	avoid_area.body_exited.connect(func(body):
		if game_running and body is GameHorse and body != horse and body == player.on_horse:
			horse.velocity.y = 0.0
	)

	var body_cs = CollisionShape2D.new()
	var body_rect = RectangleShape2D.new()
	body_rect.size = Vector2(96, 24)
	body_cs.shape = body_rect
	body_cs.position = Vector2(0, 0)
	horse.add_child(body_cs)

	horse.died.connect(_on_horse_died.bind(horse))
	horse.exhausted.connect(_on_horse_exhausted.bind(horse))

	horses_container.add_child(horse)
	return horse

func _spawn_obstacle():
	var r = randf()
	if r < 0.25:
		_spawn_rock_or_fence("rock")
	elif r < 0.5:
		_spawn_rock_or_fence("fence")
	elif r < 0.75:
		_spawn_fence_trigger("up")
	else:
		_spawn_fence_trigger("down")

func _spawn_rock_or_fence(type: String):
	var obs = Area2D.new()
	obs.name = "Obstacle"
	var sprite = Sprite2D.new()
	var tex_path = "res://Art_Resource/Obstacles/" + type + ".png"
	sprite.texture = load(tex_path)
	sprite.scale = Vector2(0.09, 0.09)
	sprite.name = "Sprite"
	obs.add_child(sprite)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 65
	shape.shape = circle
	obs.add_child(shape)
	var x = camera.global_position.x + _viewport_size.x + randf_range(100, 300)
	var y = randf_range(80, _viewport_size.y - 80)
	obs.global_position = Vector2(x, y)
	obs.body_entered.connect(_on_obstacle_hit)
	obstacles_container.add_child(obs)

func _spawn_tripwire():
	var obs = Area2D.new()
	obs.name = "TripWire"
	obs.set_meta("type", "tripwire")
	var sprite = Sprite2D.new()
	sprite.texture = load("res://Art_Resource/Obstacles/heel_roop.png")
	sprite.scale = Vector2(0.2832, 0.2832)
	sprite.name = "Sprite"
	obs.add_child(sprite)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(30, 580)
	shape.shape = rect
	obs.add_child(shape)
	var x = camera.global_position.x + _viewport_size.x + randf_range(100, 300)
	var y = _viewport_size.y * 0.5
	obs.global_position = Vector2(x, y)
	obs.body_entered.connect(_on_tripwire_hit)
	obstacles_container.add_child(obs)

func _spawn_fence_trigger(type: String):
	var trigger = Area2D.new()
	trigger.name = "FenceTrigger"
	trigger.set_meta("type", "fence_trigger")

	var tex_path = "res://Art_Resource/Obstacles/fence_" + type + ".png"

	var base_sprite = Sprite2D.new()
	base_sprite.texture = load(tex_path)
	base_sprite.scale = Vector2(FENCE_SCALE, FENCE_SCALE)
	base_sprite.name = "Sprite"
	trigger.add_child(base_sprite)

	var base_cs = CollisionShape2D.new()
	var base_circle = CircleShape2D.new()
	base_circle.radius = 65
	base_cs.shape = base_circle
	trigger.add_child(base_cs)

	var detect_area = Area2D.new()
	detect_area.name = "DetectionArea"
	var detect_cs = CollisionShape2D.new()
	var detect_circle = CircleShape2D.new()
	detect_circle.radius = FENCE_TRIGGER_RANGE
	detect_cs.shape = detect_circle
	detect_area.add_child(detect_cs)
	trigger.add_child(detect_area)

	var ext = Area2D.new()
	ext.name = "Extension"
	var ext_sprite = Sprite2D.new()
	ext_sprite.texture = load(tex_path)
	ext_sprite.scale = Vector2(FENCE_SCALE, FENCE_SCALE)
	ext_sprite.name = "Sprite"
	ext.add_child(ext_sprite)
	var ext_cs = CollisionShape2D.new()
	var ext_circle = CircleShape2D.new()
	ext_circle.radius = 65
	ext_cs.shape = ext_circle
	ext_cs.disabled = true
	ext.add_child(ext_cs)
	trigger.add_child(ext)

	var x = camera.global_position.x + _viewport_size.x + randf_range(100, 300)
	var y: float
	var ext_dir: float
	if type == "up":
		y = _viewport_size.y - 200
		ext_dir = -1.0
	else:
		y = 200.0
		ext_dir = 1.0

	trigger.global_position = Vector2(x, y)

	var triggered = false
	detect_area.body_entered.connect(func(body):
		if triggered:
			return
		if not game_running:
			return
		if body is GameHorse and player.on_horse == body:
			triggered = true
			ext_cs.set_deferred("disabled", false)
			var tween = trigger.create_tween()
			tween.tween_property(ext, "position:y", ext_dir * FENCE_SIZE, FENCE_EXTEND_DURATION)
	)

	trigger.body_entered.connect(_on_obstacle_hit)
	ext.body_entered.connect(_on_obstacle_hit)
	obstacles_container.add_child(trigger)

func _cleanup_offscreen():
	var cam_x = camera.global_position.x
	var w = _viewport_size.x
	for horse in horses_container.get_children():
		if horse.global_position.x < cam_x - w - 200 or horse.global_position.x > cam_x + w + 400:
			horse.queue_free()
	for obs in obstacles_container.get_children():
		if obs.global_position.x < cam_x - w - 200:
			obs.queue_free()

func _on_player_landed(_horse):
	pass

func _spawn_smoke(pos: Vector2):
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 15
	particles.lifetime = 1.0
	particles.preprocess = 0.0
	particles.speed_scale = 1.0
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	particles.process_material = _make_smoke_material()
	particles.texture = _make_smoke_texture()
	add_child(particles)

func _make_smoke_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.spread = 360.0
	mat.gravity = Vector3(0, -80, 0)
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 100.0
	mat.direction = Vector3(0, 1, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.2
	var scale_crv = Curve.new()
	scale_crv.add_point(Vector2(0, 1))
	scale_crv.add_point(Vector2(1, 0))
	mat.scale_curve = scale_crv
	mat.color = Color(0.55, 0.42, 0.28, 1.0)
	var ramp = Gradient.new()
	ramp.add_point(0.0, Color(0.65, 0.50, 0.35, 0.9))
	ramp.add_point(0.5, Color(0.45, 0.35, 0.25, 0.5))
	ramp.add_point(1.0, Color(0.35, 0.25, 0.18, 0.0))
	mat.color_ramp = ramp
	return mat

func _make_smoke_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.0, 0.5)
	var grad = Gradient.new()
	grad.add_point(0.0, Color.WHITE)
	grad.add_point(0.3, Color(1, 1, 1, 0.6))
	grad.add_point(1.0, Color(1, 1, 1, 0.0))
	tex.gradient = grad
	return tex

func _on_horse_died(horse):
	if player.on_horse == horse:
		player.jump_off(Vector2.UP * 400)
	horse.queue_free()

func _on_horse_exhausted(horse):
	if player.on_horse == horse and not player.jumping:
		_spawn_smoke(player.global_position)
		_game_over("马匹力竭")

func _on_obstacle_hit(body):
	if body == player or (body is GameHorse and player.on_horse == body):
		player.hit_obstacle()
		_spawn_smoke(player.global_position)
		_game_over("撞到障碍物")

func _on_tripwire_hit(body):
	if body == player or (body is GameHorse and player.on_horse == body):
		if player.jumping:
			return
		if player.on_horse and player.on_horse.is_jumping:
			return
		player.hit_obstacle()
		_spawn_smoke(player.global_position)
		_game_over("撞到障碍物")

func _game_over(reason):
	if not game_running:
		return
	game_running = false
	var gm = get_node("/root/GameManager")
	_go_reward = int(distance_traveled / 100.0) + gm.current_horses_ridden * 5
	_go_reason = reason
	_go_horses = gm.current_horses_ridden
	gm.add_gold(_go_reward)
	if _initial_horse_stable_index >= 0 and _initial_horse_data:
		var si = _initial_horse_stable_index
		if si < gm.stables.size() and gm.stables[si]:
			gm.stables[si].distance_run = _initial_horse_data.distance_run
	get_node("/root/SaveSystem").update_best_distance(distance_traveled)
	get_node("/root/SaveSystem").save_game()
	_go_pending = true
	_go_delay = 1.0
