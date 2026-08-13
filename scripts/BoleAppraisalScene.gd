extends Control

# ========== 节点引用 ==========
@onready var bole = $BoleCharacter
@onready var btn_pick_photo = $PickPhotoButton
@onready var btn_recognize = $RecognizeButton
@onready var btn_back = $Button3
@onready var photo_preview = $PhotoPreview
@onready var status_label = $StatusLabel
@onready var file_dialog = $FileDialog

# 玩家选中的图片路径
var _selected_image_path: String = ""
# 识别出的品种名（中文）
var _recognized_breed: String = ""

# EasyDL标签名 → 游戏内品种名/介绍 的映射表
# 等你模型训练完，把左边的key改成你在EasyDL里打的标签名
const BREED_MAP = {
	"夏尔马": {
		"name": "夏尔马",
		"intro": "此马体型巨大，四肢粗壮，蹄大如碗，是世界上最强壮的马种之一，可负重千斤而日行百里。"
	},
	"弗里斯马": {
		"name": "弗里斯马",
		"intro": "此马通体漆黑，鬃毛长垂，步态优雅高贵，有黑珍珠之美誉，乃是马中贵族。"
	},
	"纯血马": {
		"name": "纯血马",
		"intro": "此马身材修长，肌肉线条分明，是世界上速度最快的马种，天生为奔跑而生。"
	},
	"阿拉伯马": {
		"name": "阿拉伯马",
		"intro": "此马头型清秀，凹面高尾，聪明敏捷，耐力惊人，是所有马种中最古老的品种之一。"
	},
	"阿哈捷金马": {
		"name": "阿哈尔捷金马",
		"intro": "此马皮毛如金属鎏金，身形纤细轻盈，传说中的汗血宝马便是它，极为稀有珍贵。"
	},
	"设特兰矮马": {
		"name": "设特兰矮马",
		"intro": "此马体型小巧，身高不过米许，体格健壮，性格温顺可爱，是马中的小精灵。"
	}
}

func _ready():
	status_label.text = ""
	btn_recognize.disabled = true
	
	# 连接按钮信号
	btn_pick_photo.pressed.connect(_on_pick_photo)
	btn_recognize.pressed.connect(_on_recognize_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	bole.introduction_finished.connect(_on_bole_intro_finished)
	
	# 配置文件选择框
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png ; PNG图片", "*.jpg ; JPG图片", "*.jpeg ; JPEG图片"])
	file_dialog.file_selected.connect(_on_file_selected)

# ========== 选择图片 ==========
func _on_pick_photo():
	file_dialog.popup_centered(Vector2(700, 480))

func _on_file_selected(path: String):
	# 加载并显示预览
	var img = Image.load_from_file(path)
	if img == null:
		status_label.text = "❌ 无法读取图片，请换一张试试"
		return
	
	# 压缩图片到1024以内，加快上传速度
	if img.get_width() > 1024 or img.get_height() > 1024:
		var scale = 1024.0 / max(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale))
	
	# 保存一份到用户目录，生成器要用
	DirAccess.make_dir_recursive_absolute("user://bole_temp/")
	var saved_path = "user://bole_temp/upload.png"
	img.save_png(saved_path)
	_selected_image_path = saved_path
	
	# 显示预览
	photo_preview.texture = ImageTexture.create_from_image(img)
	btn_recognize.disabled = false
	status_label.text = "✅ 图片已选择，点击「开始识马」"

# ========== 调用EasyDL识别 ==========
func _on_recognize_pressed():
	if _selected_image_path.is_empty():
		status_label.text = "请先选择一张马的照片"
		return
	
	_set_buttons_enabled(false)
	status_label.text = "🔍 正在识别马的品种..."
	
	# 读图片转base64
	var img = Image.load_from_file(_selected_image_path)
	var base64_img = Marshalls.raw_to_base64(img.save_png_to_buffer())
	
	# 发请求
	var http = HTTPRequest.new()
	add_child(http)
	
	var url = Config.EASYDL_API_URL + "?access_token=" + Config.EASYDL_ACCESS_TOKEN
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"image": base64_img,
		"top_num": 3
	})
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		status_label.text = "❌ 识别请求失败，请检查网络"
		_set_buttons_enabled(true)
		http.queue_free()
		return
	
	var args = await http.request_completed
	http.queue_free()
	
	var response_code = args[1]
	var resp_body = args[3]
	
	# ========== 调试：打印原始返回结果 ==========
	print("=== EasyDL返回原始数据 ===")
	print("HTTP状态码:", response_code)
	print("返回内容:", resp_body.get_string_from_utf8())
	print("==========================")
	# ========== 调试结束 ==========
	
	if response_code != 200:
		status_label.text = "❌ 识别失败，错误码：%d" % response_code
		_set_buttons_enabled(true)
		return
	
	# 解析结果
	var data = JSON.parse_string(resp_body.get_string_from_utf8())
	if not data.has("results") or data["results"].is_empty():
		status_label.text = "❌ 没有识别出马，请换一张清晰的图片"
		_set_buttons_enabled(true)
		return
	
	var top_result = data["results"][0]
	var label = top_result["name"]
	var confidence = top_result["score"]
	
	# 置信度太低
	if confidence < 0.7:
		status_label.text = "⚠️ 识别置信度较低（%.0f%%），请换一张更清晰的侧面照" % (confidence * 100)
		_set_buttons_enabled(true)
		return
	
	# 查品种映射表
	if not BREED_MAP.has(label):
		status_label.text = "❌ 识别出未知品种：%s" % label
		_set_buttons_enabled(true)
		return
	
	var breed_info = BREED_MAP[label]
	_recognized_breed = breed_info["name"]
	
	# 伯乐开始介绍
	status_label.text = "🎯 识别成功！伯乐正在相马..."
	bole.introduce_horse(breed_info["name"], breed_info["intro"])

# ========== 伯乐介绍完，跳转到生成器 ==========
func _on_bole_intro_finished():
	status_label.text = "✨ 相马完成！正在进入马匹生成..."
	
	# 把图片路径和品种名传给生成器
	var gm = get_node("/root/GameManager")
	gm.set_meta("bole_pending_photo", _selected_image_path)
	gm.set_meta("bole_pending_breed", _recognized_breed)
	
	# 等1秒再跳转，让玩家看到提示
	await get_tree().create_timer(1.0).timeout
	
	# 跳转到队友的AI马匹生成器场景
	get_tree().change_scene_to_file("res://scenes/ai_horse_create.tscn")

# ========== 其他 ==========
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _set_buttons_enabled(enabled: bool):
	btn_pick_photo.disabled = not enabled
	btn_recognize.disabled = not enabled
	btn_back.disabled = not enabled
