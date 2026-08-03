extends Node

const DEFAULT_PERSONALITY = 50.0
const DEFAULT_TEMPER = 50.0
const DEFAULT_TAME = 0.0
const DEFAULT_JUMP_POWER = 10.0
const STARTING_GOLD = 200

var max_stable_slots = 5

var personality_pref = DEFAULT_PERSONALITY
var temper_pref = DEFAULT_TEMPER
var tame_ability = DEFAULT_TAME
var jump_power = DEFAULT_JUMP_POWER
var gold = STARTING_GOLD

var sprite_frames_cache = {}

var stables = []
var selected_horse_index = -1

var current_distance = 0.0
var current_horses_ridden = 0
var current_ridden_horses = []

var unlocked_breeds = []

func _ready():
	var ss = get_node("/root/SaveSystem")
	ss.load_game()
	for h in stables:
		if h != null:
			_unlock_breed(h.breed.resource_path)
	ss.save_game()
	if stables.is_empty():
		var starter = HorseData.new()
		starter.horse_name = "小蒙古"
		starter.breed = load("res://resources/breeds/mongolian.tres")
		starter.is_player_owned = true
		starter.speed_mod = 0
		starter.stamina_mod = 0
		stables.append(starter)
		for i in range(max_stable_slots - 1):
			stables.append(null)
		_unlock_breed(starter.breed.resource_path)
		ss.save_game()

func can_afford(cost):
	return gold >= cost

func spend_gold(amount):
	if can_afford(amount):
		gold -= amount
		return true
	return false

func add_gold(amount):
	gold += amount

func modify_personality(delta):
	personality_pref = clamp(personality_pref + delta, 0.0, 100.0)

func modify_temper(delta):
	temper_pref = clamp(temper_pref + delta, 0.0, 100.0)

func modify_tame(delta):
	tame_ability = clamp(tame_ability + delta, 0.0, 100.0)

func modify_jump(delta):
	jump_power = clamp(jump_power + delta, 1.0, 20.0)

func add_horse_to_stable(horse):
	for i in range(stables.size()):
		if stables[i] == null:
			var new_horse = horse.clone()
			new_horse.is_player_owned = true
			if horse.horse_name == "未命名":
				new_horse.horse_name = horse.breed.breed_name
			else:
				new_horse.horse_name = horse.horse_name
			stables[i] = new_horse
			_unlock_breed(horse.breed.resource_path)
			get_node("/root/SaveSystem").save_game()
			return true
	return false


func replace_horse_in_stable(index, new_horse):
	if index < 0 or index >= stables.size():
		return false
	var horse = new_horse.clone()
	horse.is_player_owned = true
	if new_horse.horse_name == "未命名":
		horse.horse_name = new_horse.breed.breed_name
	else:
		horse.horse_name = new_horse.horse_name
	stables[index] = horse
	get_node("/root/SaveSystem").save_game()
	return true


func get_stable_count():
	var count = 0
	for h in stables:
		if h != null:
			count += 1
	return count

func expand_stable():
	if not spend_gold(1000):
		return false
	max_stable_slots += 1
	stables.append(null)
	get_node("/root/SaveSystem").save_game()
	return true

func _unlock_breed(path: String):
	if not path in unlocked_breeds:
		unlocked_breeds.append(path)

func is_breed_unlocked(path: String) -> bool:
	return path in unlocked_breeds

func start_new_game():
	current_distance = 0.0
	current_horses_ridden = 0
	current_ridden_horses.clear()

func add_ridden_horse(horse):
	current_horses_ridden += 1
	current_ridden_horses.append(horse.clone())

func calculate_reward():
	return int(current_distance * 0.1) + current_horses_ridden * 5
