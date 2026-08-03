extends CharacterBody2D

signal landed_on_horse(horse)
signal player_fell

const VERTICAL_SPEED = 600.0
const JUMP_DURATION = 2.0
const WINDUP_DURATION = 1.0
const MOUNT_RANGE = 100.0

var on_horse = null
var jumping = false
var _jump_windup = false
var jump_velocity = Vector2.ZERO
var _jump_timer = 0.0
var _windup_timer = 0.0

var _touch_start = Vector2.ZERO
var _touch_active = false
var _touch_index = -1
var _min_swipe = 30.0
var _riding_input_dir = 0.0
var _anim_scales = {}
var _jumped_from = null
var _collision_fall = false
var _warning_label: Label
var _mount_highlight: GameHorse = null
var _circle_angle = 0.0
var _ride_start_dist = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _load_frame_sequence(frames: SpriteFrames, anim_name: String, dir_path: String, speed: float, target_size: Vector2 = Vector2.ZERO) -> Vector2:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	var i = 1
	var first_size = Vector2.ZERO
	while i <= 50:
		var path = dir_path + "/" + str(i) + ".png"
		if not ResourceLoader.exists(path):
			break
		var tex = load(path)
		if not tex:
			break
		if first_size == Vector2.ZERO:
			first_size = tex.get_size()
		frames.add_frame(anim_name, tex)
		i += 1
	if target_size != Vector2.ZERO and first_size.x > 0 and first_size.y > 0:
		_anim_scales[anim_name] = min(target_size.x / first_size.x, target_size.y / first_size.y)
	return first_size


func _setup_animations():
	var frames = SpriteFrames.new()
	var cache = GameManager.sprite_frames_cache
	var target_sizes = {"ride": Vector2(90, 120), "jump": Vector2(9999, 120), "fall": Vector2(9999, 120)}
	var speeds = {"ride": 10.0, "jump": 15.0, "fall": 10.0}

	for anim in ["ride", "jump", "fall"]:
		var key = "rider:" + anim
		if cache.has(key):
			var cached = cache[key]
			frames.add_animation(anim)
			frames.set_animation_speed(anim, speeds[anim])
			var first_size: Vector2
			for j in cached.get_frame_count("default"):
				var tex = cached.get_frame_texture("default", j)
				frames.add_frame(anim, tex)
				if j == 0:
					first_size = tex.get_size()
			var target = target_sizes[anim]
			if target != Vector2.ZERO and first_size.x > 0:
				_anim_scales[anim] = min(target.x / first_size.x, target.y / first_size.y)
		else:
			_load_frame_sequence(frames, anim, "res://Art_Resource/Rider/rider_" + anim + "/frames", speeds[anim], target_sizes[anim])

	_sprite.sprite_frames = frames
	_play_anim("ride")


func _play_anim(anim_name: String):
	_sprite.play(anim_name)
	if _anim_scales.has(anim_name):
		_sprite.scale = Vector2(_anim_scales[anim_name], _anim_scales[anim_name])


func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var col = $CollisionShape
	if col.shape == null:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(60, 80)
		col.shape = rect
	_setup_animations()

	_warning_label = Label.new()
	_warning_label.text = "你的马好累！\n你马要没了！"
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.add_theme_font_size_override("font_size", 22)
	_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0, 1))
	_warning_label.hide()
	add_child(_warning_label)
	queue_redraw()


func _physics_process(delta):
	if on_horse and not jumping:
		if not is_instance_valid(on_horse) or on_horse.is_queued_for_deletion():
			on_horse = null
			_play_anim("fall")
			return
		if on_horse.is_exhausted():
			hit_obstacle()
		else:
			_update_riding(delta)
			var sprite_offset = on_horse._sprite.position.y if on_horse._sprite else 0.0
			global_position = on_horse.global_position + Vector2(0, -30 + sprite_offset)
			if on_horse.is_in_warning():
				_warning_label.global_position = global_position + Vector2(40, -90)
				_warning_label.show()
			else:
				_warning_label.hide()
		_play_anim("ride")
		return

	if jumping:
		if _collision_fall:
			velocity.y += 500.0 * delta
			move_and_slide()
			_jump_timer -= delta
			if _jump_timer <= 0.0:
				jumping = false
				_collision_fall = false
			return

		if _jump_windup:
			_windup_timer -= delta
			if _windup_timer > 0:
				if _jumped_from and is_instance_valid(_jumped_from):
					global_position = _jumped_from.global_position + Vector2(0, -30)
				_play_anim("jump")
				_circle_angle += delta * 3.0
				queue_redraw()
				return
			_jump_windup = false
			global_position += jump_velocity.normalized() * 50.0
			$CollisionShape.disabled = false
			velocity = jump_velocity

		velocity = jump_velocity
		move_and_slide()
		_jump_timer -= delta
		_circle_angle += delta * 3.0
		_update_mount_highlight()

		if _jump_timer <= 0.0:
			jumping = false
			_clear_mount_highlight()
		_play_anim("jump")
		queue_redraw()
		return

	# not on horse, not jumping -> dead
	_play_anim("fall")
	player_fell.emit()


func _update_riding(_delta):
	if on_horse.is_crazy:
		return
	var vy = _riding_input_dir * VERTICAL_SPEED
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		vy = -VERTICAL_SPEED
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		vy = VERTICAL_SPEED

	on_horse.velocity.y = vy
	if not on_horse.is_crazy:
		on_horse.velocity.x = on_horse.horse_data.get_actual_speed()


func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index < 0:
				_touch_start = event.position
				_touch_active = true
				_touch_index = event.index
		else:
			if event.index == _touch_index:
				if _touch_active:
					var swipe = event.position - _touch_start
					if swipe.length() > _min_swipe:
						_try_jump(swipe.normalized())
				_touch_active = false
				_touch_index = -1
				_riding_input_dir = 0.0

	if event is InputEventScreenDrag:
		if event.index == _touch_index and on_horse and not jumping:
			var d = event.relative
			if abs(d.y) > 5:
				_riding_input_dir = sign(d.y)

	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if on_horse and not jumping and not on_horse.is_exhausted():
			on_horse.start_jump()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if jumping and not _jump_windup and not _collision_fall:
			_try_mount_nearest()
			return
		if on_horse:
			var mouse_world = get_global_mouse_position()
			var dir = (mouse_world - global_position).normalized()
			_try_jump(dir)


func _try_jump(direction):
	if on_horse == null:
		return
	if not is_instance_valid(on_horse) or on_horse.is_queued_for_deletion():
		return
	if on_horse.is_exhausted():
		return
	var speed = abs(on_horse.velocity.x) + get_node("/root/GameManager").jump_power * 10.0
	jump_off(direction.normalized() * speed)


func jump_off(vel):
	if on_horse and is_instance_valid(on_horse):
		_save_ride_distance()
		var gm = get_node("/root/GameManager")
		var hdata = on_horse.horse_data
		if hdata and not hdata.is_obedient(gm.personality_pref, gm.temper_pref, gm.tame_ability):
			on_horse.start_crazy()
		on_horse.is_ridden = true
		on_horse.velocity = Vector2.ZERO
		on_horse.set_speed_mul(0.5)
		for child in on_horse.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		_jumped_from = on_horse
	on_horse = null
	jumping = true
	_jump_windup = true
	_clear_mount_highlight()
	jump_velocity = vel
	_jump_timer = JUMP_DURATION
	_windup_timer = WINDUP_DURATION
	queue_redraw()


func mount(horse):
	if horse == null:
		return
	_jumped_from = null
	jumping = false
	_jump_windup = false
	jump_velocity = Vector2.ZERO
	on_horse = horse
	horse.set_speed_mul(1.0)
	horse.reset_stamina_timer()
	_ride_start_dist = _get_game_distance()
	global_position = horse.global_position + Vector2(0, -30)
	var gm = get_node("/root/GameManager")
	var obedient = horse.horse_data.is_obedient(gm.personality_pref, gm.temper_pref, gm.tame_ability)
	if not obedient or horse.is_ridden:
		horse.start_crazy()
	gm.add_ridden_horse(horse.horse_data)
	$CollisionShape.disabled = true
	_clear_mount_highlight()
	queue_redraw()
	landed_on_horse.emit(horse)


func _on_horse_collision(collider):
	if collider == on_horse:
		return
	if collider == _jumped_from:
		return
	if not is_instance_valid(collider):
		return
	if collider.horse_data and collider.horse_data.is_exhausted:
		return
	mount(collider)


func is_on_horse():
	return on_horse != null and is_instance_valid(on_horse) and not on_horse.is_queued_for_deletion()

func hit_obstacle():
	if on_horse and is_instance_valid(on_horse):
		_save_ride_distance()
		on_horse.velocity = Vector2.ZERO
		on_horse.is_crazy = false
	on_horse = null
	jumping = true
	_jump_windup = false
	_collision_fall = true
	jump_velocity = Vector2(80, -100)
	_jump_timer = 0.6
	velocity = jump_velocity
	_play_anim("fall")
	$CollisionShape.disabled = false
	queue_redraw()

func _try_mount_nearest():
	var closest = _find_nearest_in_range()
	if closest:
		mount(closest)

func _update_mount_highlight():
	var nearest = _find_nearest_in_range()
	if nearest == _mount_highlight:
		return
	_clear_mount_highlight()
	if nearest:
		nearest.get_node("Sprite").modulate = Color(1, 0.95, 0.4, 1)
		nearest.queue_redraw()
		_mount_highlight = nearest

func _clear_mount_highlight():
	if _mount_highlight and is_instance_valid(_mount_highlight):
		var sprite = _mount_highlight.get_node_or_null("Sprite")
		if sprite:
			sprite.modulate = Color.WHITE
		_mount_highlight.queue_redraw()
	_mount_highlight = null

func _find_nearest_in_range() -> GameHorse:
	var horses = get_tree().get_nodes_in_group("horses")
	var closest: GameHorse = null
	var closest_dist = MOUNT_RANGE
	for horse in horses:
		if not is_instance_valid(horse) or horse.is_queued_for_deletion():
			continue
		if horse == _jumped_from:
			continue
		if horse.horse_data and horse.horse_data.is_exhausted:
			continue
		var dist = global_position.distance_to(horse.global_position) - 48
		if dist < closest_dist:
			closest_dist = dist
			closest = horse
	return closest

func _get_game_distance() -> float:
	var nodes = get_tree().get_nodes_in_group("game_scene")
	if nodes.is_empty():
		return 0.0
	return nodes[0].distance_traveled

func _save_ride_distance():
	if on_horse and on_horse.horse_data:
		var dist = _get_game_distance() - _ride_start_dist
		if dist > 0:
			on_horse.horse_data.distance_run += dist
		_ride_start_dist = 0.0

func _draw():
	if jumping and not _collision_fall:
		var r = MOUNT_RANGE
		if _jump_windup:
			r = MOUNT_RANGE * (1.0 - _windup_timer / WINDUP_DURATION)
		var segments = 12
		var arc_span = PI * 2.0 / segments * 0.5
		var center = Vector2(0, 30)
		for i in range(segments):
			var a = _circle_angle + i * PI * 2.0 / segments
			draw_arc(center, r, a, a + arc_span, 16, Color.BLACK, 2.0)
