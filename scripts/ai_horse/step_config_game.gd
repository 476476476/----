extends "res://scripts/ai_horse/step_base_game.gd"
## 步骤 2：属性配置（决定游戏内表现，游戏运行时版）

const RARITY_NAMES = ["常见", "稀有", "史诗", "传说"]

var _price_spin: SpinBox
var _rarity_opt: OptionButton
var _speed_spin: SpinBox
var _stamina_spin: SpinBox
var _person_min: SpinBox
var _person_max: SpinBox
var _temper_min: SpinBox
var _temper_max: SpinBox
var _obedience_min: SpinBox
var _encyclopedia: TextEdit


func _build_content(_content: VBoxContainer):
	_content.add_child(_title("2. 设置马匹属性"))
	_content.add_child(_hint("这些数值会写进游戏品种数据，影响速度、耐力和可骑乘条件。稀有度影响野外遇到概率：常见最常见，传说最稀有。"))

	_content.add_child(HSeparator.new())
	_content.add_child(_label("基础数值（参考：蒙古马速度 40 / 耐力 20，赤兔马速度 140+）", 12))

	var row = _row()
	_content.add_child(row)
	row.add_child(_label("基础速度（内部值，÷10 为 m/s）"))
	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 20
	_speed_spin.max_value = 400
	_speed_spin.step = 5
	_speed_spin.value = 60
	row.add_child(_speed_spin)

	row.add_child(_label("基础耐力（秒）"))
	_stamina_spin = SpinBox.new()
	_stamina_spin.min_value = 5
	_stamina_spin.max_value = 120
	_stamina_spin.step = 1
	_stamina_spin.value = 25
	row.add_child(_stamina_spin)

	row = _row()
	_content.add_child(row)
	row.add_child(_label("马厩售价（金币）"))
	_price_spin = SpinBox.new()
	_price_spin.min_value = 5
	_price_spin.max_value = 5000
	_price_spin.step = 5
	_price_spin.value = 120
	row.add_child(_price_spin)

	row.add_child(_label("稀有度"))
	_rarity_opt = OptionButton.new()
	for name in RARITY_NAMES:
		_rarity_opt.add_item(name)
	_rarity_opt.selected = 0  # 默认常见：野外更容易遇到
	row.add_child(_rarity_opt)

	_content.add_child(HSeparator.new())
	_content.add_child(_label("骑乘条件要求（0~100，数值越高越难驾驭）", 12))

	row = _row()
	_content.add_child(row)
	row.add_child(_label("性格区间"))
	_person_min = _spin(0, 100, 0)
	row.add_child(_person_min)
	row.add_child(_label("~"))
	_person_max = _spin(0, 100, 100)
	row.add_child(_person_max)

	row = _row()
	_content.add_child(row)
	row.add_child(_label("脾气区间"))
	_temper_min = _spin(0, 100, 0)
	row.add_child(_temper_min)
	row.add_child(_label("~"))
	_temper_max = _spin(0, 100, 100)
	row.add_child(_temper_max)

	row = _row()
	_content.add_child(row)
	row.add_child(_label("顺从度最低要求"))
	_obedience_min = _spin(0, 100, 20)
	row.add_child(_obedience_min)

	_content.add_child(HSeparator.new())
	_content.add_child(_label("图鉴介绍（可选，显示在图鉴详情页）", 12))
	_encyclopedia = TextEdit.new()
	_encyclopedia.custom_minimum_size = Vector2(0, 70)
	_encyclopedia.placeholder_text = "例如：雪原上的稀有骏马，传说中只在暴风雪中出现…"
	_content.add_child(_encyclopedia)


func _spin(min_v: float, max_v: float, default: float) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value = default
	return spin


func validate() -> String:
	if _person_min.value > _person_max.value:
		return "性格区间最小值不能大于最大值"
	if _temper_min.value > _temper_max.value:
		return "脾气区间最小值不能大于最大值"
	state["attributes"] = {
		"price": int(_price_spin.value),
		"rarity": _rarity_opt.selected,
		"base_speed": float(_speed_spin.value),
		"base_stamina": float(_stamina_spin.value),
		"personality_min": _person_min.value,
		"personality_max": _person_max.value,
		"temper_min": _temper_min.value,
		"temper_max": _temper_max.value,
		"obedience_min": _obedience_min.value,
		"encyclopedia_text": _encyclopedia.text.strip_edges(),
	}
	return ""
