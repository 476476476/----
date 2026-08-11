extends Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var audio_player = $AudioPlayer

@onready var dialog_box = $CanvasLayer/DialogBox
@onready var dialog_text = $CanvasLayer/DialogBox/DialogText

# 信号：介绍结束时发出，通知游戏其他模块
signal introduction_finished()

func _ready():
	# 默认播放idle动画
	animated_sprite.play("idle")
	
	# 测试：3秒后自动介绍赤兔马
	await get_tree().create_timer(3.0).timeout
	introduce_horse("赤兔马", "此马浑身枣红，日行千里，乃是马中极品，传说中关公的坐骑。")

# 对外调用的入口：传入要介绍的马的名字和介绍文案，伯乐就会开始说话
func introduce_horse(horse_name: String, intro_text: String):
	# 1. 拼接完整的介绍文案
	var full_text = "此马名为%s。%s" % [horse_name, intro_text]

	# 2. 先显示对话框（默认隐藏，说话的时候才弹出来）
	dialog_box.visible = true
	dialog_text.text = ""  # 清空上次的文字

	# 3. 调用TTS生成语音
	await _generate_tts(full_text)

	# 4. 切换到说话动画
	animated_sprite.play("speak")

	# 5. 同时做两件事：播放语音 + 打字机显示文字
	audio_player.play()
	_type_text(full_text)  # 不用await，让它和语音同时跑

	# 6. 等语音播放完
	await audio_player.finished

	# 7. 等打字也打完（防止文字比语音慢）
	await get_tree().create_timer(0.5).timeout

	# 8. 切回idle眨眼动画
	animated_sprite.play("idle")

	# 9. 文字多留2秒再消失，给玩家看完的时间
	await get_tree().create_timer(2.0).timeout

	# 10. 隐藏对话框
	dialog_box.visible = false

	# 11. 发出结束信号，通知游戏其他模块
	introduction_finished.emit()

# 调用百度TTS生成语音
func _generate_tts(text: String):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# 拼接请求参数
	var params = "tex=" + text.uri_encode()
	params += "&tok=" + Config.BAIDU_TTS_TOKEN
	params += "&cuid=godot_bole_game"
	params += "&ctp=1"  # 返回mp3格式
	params += "&lan=zh"
	params += "&per=" + str(Config.TTS_PERSON)  # 音色
	params += "&spd=5"  # 语速，5是正常，慢一点更稳重
	
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	# 发送请求
	var error = http_request.request(Config.BAIDU_TTS_API, headers, HTTPClient.METHOD_POST, params)
	if error != OK:
		print("TTS请求失败")
		http_request.queue_free()
		return
	
	# 等待请求完成（Godot 4语法：await信号返回数组）
	var args = await http_request.request_completed
	http_request.queue_free()

	# 从数组里取出返回值，顺序是：result, response_code, response_headers, body
	var result = args[0]
	var response_code = args[1]
	var response_headers = args[2]
	var body = args[3]

	if response_code != 200:
		print("TTS生成失败，错误码：", response_code)
		return
	
	# 把返回的音频数据转成AudioStreamMP3
	var mp3_stream = AudioStreamMP3.new()
	mp3_stream.data = body
	audio_player.stream = mp3_stream

# 打字机效果：一个字一个字显示文字
# text: 要显示的文字
# speed: 每个字的间隔时间，越小越快
func _type_text(text: String, speed: float = 0.08) -> void:
	dialog_text.text = ""  # 先清空
	for i in range(text.length()):
		dialog_text.text += text[i]  # 每次加一个字
		await get_tree().create_timer(speed).timeout  # 等一下
