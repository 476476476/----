extends Control

# 节点引用，名字要和你场景里的节点名对应
@onready var bole = $BoleCharacter
@onready var btn_test_arabian = $Button  # 你之前的测试按钮1
@onready var btn_test_chitu = $Button2   # 你之前的测试按钮2
@onready var btn_back = $Button3         # 返回按钮
@onready var status_label = $StatusLabel

func _ready():
	status_label.text = ""
	
	# 连接按钮信号
	btn_test_arabian.pressed.connect(_on_test_arabian_pressed)
	btn_test_chitu.pressed.connect(_on_test_chitu_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# 连接伯乐介绍完的信号
	bole.introduction_finished.connect(_on_bole_intro_finished)

# 测试：识别到阿拉伯马
func _on_test_arabian_pressed():
	_set_buttons_enabled(false)
	status_label.text = "识别中..."
	
	# 模拟识别等待
	await get_tree().create_timer(1.0).timeout
	
	# 直接加载游戏里已经有的品种资源
	var breed = load("res://resources/breeds/baitiwu.tres")
	var new_horse = HorseData.new()
	new_horse.breed = breed
	new_horse.horse_name = breed.breed_name
	
	# 伯乐介绍
	status_label.text = "伯乐正在相马..."
	var intro = "此马头型清秀，尾巴高翘，聪明伶俐，耐力极佳，乃是阿拉伯马中的上品。"
	bole.introduce_horse(breed.breed_name, intro)
	
	# 把马存起来，等介绍完加进马棚
	_pending_horse = new_horse

# 测试：识别到汗血宝马（传说级）
func _on_test_chitu_pressed():
	_set_buttons_enabled(false)
	status_label.text = "识别中..."
	
	await get_tree().create_timer(1.0).timeout
	
	# 加载游戏里的汗血宝马品种
	var breed = load("res://resources/breeds/chitu.tres")
	var new_horse = HorseData.new()
	new_horse.breed = breed
	new_horse.horse_name = "赤兔马"  # AI识别的名马可以自定义名字
	
	status_label.text = "伯乐正在相马..."
	var intro = "好马！好马！此马浑身赤红，神骏非凡，汗血如血，乃千古名马！人中吕布，马中赤兔，得此马者可横行天下！"
	bole.introduce_horse("赤兔马", intro)
	
	_pending_horse = new_horse

var _pending_horse: HorseData = null

# 伯乐介绍完了，直接调用GameManager的方法把马加进马棚
func _on_bole_intro_finished():
	if _pending_horse != null:
		var gm = get_node("/root/GameManager")
		var success = gm.add_horse_to_stable(_pending_horse)
		if success:
			status_label.text = "✅ 马匹已存入马棚！"
		else:
			status_label.text = "❌ 马棚已满！"
		_pending_horse = null
	
	await get_tree().create_timer(2.0).timeout
	_set_buttons_enabled(true)

# 返回主菜单
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _set_buttons_enabled(enabled: bool):
	btn_test_arabian.disabled = not enabled
	btn_test_chitu.disabled = not enabled
	btn_back.disabled = not enabled
