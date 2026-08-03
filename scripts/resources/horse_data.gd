class_name HorseData
extends Resource

@export var horse_name: String = "未命名"
@export var breed: HorseBreed
@export var speed_mod: int = 0
@export var stamina_mod: int = 0
@export var personality_mod: float = 0.0
@export var temper_mod: float = 0.0
@export var obedience_mod: float = 0.0
@export var current_stamina: float = 0.0
@export var is_player_owned: bool = false
@export var distance_run: float = 0.0
@export var is_exhausted: bool = false
@export var affection: int = 0
@export var drug_resistance: int = 0  # 0-10, hidden cap
@export var drug_use_count: int = 0   # injections applied


func get_actual_speed() -> float:
	var loyalty = min(int(distance_run / 1000.0), 100)
	var loyalty_bonus = loyalty * 1.0
	return (breed.base_speed + speed_mod) * 10.0 + loyalty_bonus

func get_actual_stamina() -> float:
	return breed.base_stamina + stamina_mod + int(affection / 20)

func reset_stamina() -> void:
	is_exhausted = false

func get_personality_range() -> Vector2:
	var lo := breed.personality_min + personality_mod
	var hi := breed.personality_max + personality_mod
	return Vector2(clamp(lo, 0.0, 100.0), clamp(hi, 0.0, 100.0))

func get_temper_range() -> Vector2:
	var lo := breed.temper_min + temper_mod
	var hi := breed.temper_max + temper_mod
	return Vector2(clamp(lo, 0.0, 100.0), clamp(hi, 0.0, 100.0))

func get_obedience_threshold() -> float:
	return breed.obedience_min + obedience_mod

func check_match(personality_pref: float, temper_pref: float, tame_ability: float) -> int:
	var match_count := 0
	var p_range := get_personality_range()
	if personality_pref >= p_range.x and personality_pref <= p_range.y:
		match_count += 1
	var t_range := get_temper_range()
	if temper_pref >= t_range.x and temper_pref <= t_range.y:
		match_count += 1
	if tame_ability > get_obedience_threshold():
		match_count += 1
	return match_count

func is_obedient(personality_pref: float, temper_pref: float, tame_ability: float) -> bool:
	if is_player_owned:
		return true
	return check_match(personality_pref, temper_pref, tame_ability) >= 2

func clone() -> HorseData:
	var data := HorseData.new()
	data.horse_name = horse_name
	data.breed = breed
	data.speed_mod = speed_mod
	data.stamina_mod = stamina_mod
	data.personality_mod = personality_mod
	data.temper_mod = temper_mod
	data.obedience_mod = obedience_mod
	data.distance_run = distance_run
	data.affection = affection
	data.drug_resistance = drug_resistance
	data.drug_use_count = drug_use_count
	data.is_player_owned = is_player_owned
	return data
