class_name GameHorse
extends CharacterBody2D

signal exhausted
signal died

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

const JUMP_DURATION = 0.5
const JUMP_HEIGHT = 100.0
const AVOID_SPEED = 120.0

var horse_data = null
var is_wild = false
var is_crazy = false
var crazy_timer = 0.0
var crazy_amplitude = 50.0

var is_jumping = false
var _jump_timer = 0.0

var _stamina_timer = 0.0
var _warning_zone = 3.0
var _exhausted = false
var is_ridden = false
var _speed_mul = 0.5
var _sprite: AnimatedSprite2D
var _breed_prefix = ""
var _anim_scales = {}


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


func _setup_sprite():
	_breed_prefix = BREED_FILE_MAP.get(horse_data.breed.breed_name, "")
	if _breed_prefix == "":
		_breed_prefix = BreedRegistry.get_prefix(horse_data.breed.breed_name)
	if _breed_prefix == "":
		_breed_prefix = "mongolian"

	var frames = SpriteFrames.new()
	var base = "res://Art_Resource/Horses/" + _breed_prefix
	var target = Vector2(240, 160)

	for anim in ["run", "exhausted", "crazy"]:
		var first_size: Vector2
		var key = "horse:" + _breed_prefix + ":" + anim
		var cache = GameManager.sprite_frames_cache
		if cache.has(key):
			var cached = cache[key]
			frames.add_animation(anim)
			frames.set_animation_speed(anim, cached.get_animation_speed("default"))
			for j in cached.get_frame_count("default"):
				var tex = cached.get_frame_texture("default", j)
				frames.add_frame(anim, tex)
				if j == 0:
					first_size = tex.get_size()
		else:
			first_size = _load_frame_sequence(frames, anim, base + "_" + anim + "/frames", 15.0, target)

		if target != Vector2.ZERO and first_size.x > 0 and first_size.y > 0:
			_anim_scales[anim] = min(target.x / first_size.x, target.y / first_size.y)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = frames
	_play_anim("run")
	add_child(_sprite)


func _play_anim(anim_name: String):
	_sprite.play(anim_name)
	if _anim_scales.has(anim_name):
		_sprite.scale = Vector2(_anim_scales[anim_name], _anim_scales[anim_name])


func _ready():
	add_to_group("horses")


func setup(data, wild = true):
	horse_data = data
	is_wild = wild
	horse_data.reset_stamina()
	_stamina_timer = horse_data.get_actual_stamina()
	_setup_sprite()


func set_speed_mul(mul: float):
	_speed_mul = mul


func _update_animation():
	if _sprite == null:
		return
	if _exhausted or _stamina_timer <= _warning_zone:
		_play_anim("exhausted")
	elif is_crazy:
		_play_anim("crazy")
	else:
		_play_anim("run")


func _physics_process(delta):
	if _exhausted or horse_data == null:
		return

	if is_jumping:
		_jump_timer -= delta
		if _jump_timer <= 0.0:
			_jump_timer = 0.0
			is_jumping = false
			_sprite.position.y = 0.0
		else:
			var progress = 1.0 - _jump_timer / JUMP_DURATION
			if progress < 0.4:
				var t = progress / 0.4
				_sprite.position.y = -JUMP_HEIGHT * (1.0 - (1.0 - t) * (1.0 - t))
			else:
				var t = (progress - 0.4) / 0.6
				_sprite.position.y = -JUMP_HEIGHT * (1.0 - t * t)

	if is_crazy:
		_crazy_move(delta)
	elif not is_ridden:
		if velocity.x == 0:
			velocity.x = horse_data.get_actual_speed() * _speed_mul

	_stamina_timer -= delta
	if _stamina_timer <= _warning_zone and _stamina_timer > 0.0:
		var ratio = _stamina_timer / _warning_zone
		velocity.x = horse_data.get_actual_speed() * ratio * _speed_mul
	elif _stamina_timer <= 0.0:
		velocity.x = 0.0
		_exhausted = true
		horse_data.is_exhausted = true
		exhausted.emit()
		_update_animation()
		for child in get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
		if not is_wild:
				get_tree().create_timer(3.0).timeout.connect(func(): died.emit())

	if not is_crazy:
		move_and_slide()

	_update_animation()


func _crazy_move(delta):
	crazy_timer += delta
	crazy_amplitude += delta * 80.0
	velocity.y = sin(crazy_timer * 8.0) * crazy_amplitude
	velocity.x = horse_data.get_actual_speed() * _speed_mul
	move_and_slide()


func start_crazy():
	is_crazy = true
	crazy_timer = 0.0
	crazy_amplitude = 50.0
	_update_animation()


func start_jump():
	if is_jumping or _exhausted:
		return
	is_jumping = true
	_jump_timer = JUMP_DURATION


func get_speed():
	return horse_data.get_actual_speed()


func get_stamina_ratio():
	if horse_data.get_actual_stamina() <= 0.0:
		return 0.0
	return _stamina_timer / horse_data.get_actual_stamina()


func is_highlighted():
	return _sprite and _sprite.modulate != Color.WHITE

func is_in_warning():
	return _stamina_timer <= _warning_zone and _stamina_timer > 0.0

func _draw():
	if _sprite and _sprite.modulate != Color.WHITE:
		draw_circle(Vector2.ZERO, 100, Color(1, 0.9, 0.3, 0.4), false, 3.0)

func is_exhausted():
	return _exhausted


func reset_stamina_timer():
	_stamina_timer = horse_data.get_actual_stamina()
	_exhausted = false
	horse_data.is_exhausted = false
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)
