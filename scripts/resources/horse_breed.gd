class_name HorseBreed
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var breed_name: String = ""
@export var base_speed: float = 40.0
@export var base_stamina: float = 20.0
@export var personality_min: float = 0.0
@export var personality_max: float = 100.0
@export var temper_min: float = 0.0
@export var temper_max: float = 100.0
@export var obedience_min: float = 0.0
@export var rarity: int = Rarity.COMMON
@export var spawn_weight: float = 75.0
@export var color: Color = Color.BROWN
@export var encyclopedia_text: String = ""

func get_rarity_string() -> String:
	match rarity:
		Rarity.COMMON:
			return "常见"
		Rarity.RARE:
			return "稀有"
		Rarity.EPIC:
			return "史诗"
		Rarity.LEGENDARY:
			return "传说"
	return "未知"
