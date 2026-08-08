@tool
extends Node
## SiliconFlow API 客户端：图生图（风格化）、图生视频（动画）、状态轮询、文件下载。
## 串行请求模式：一次只发一个请求，通过意图回调分发结果。

const API_BASE = "https://api.siliconflow.cn"
const IMG_MODEL = "Qwen/Qwen-Image-Edit-2509"  # 图生图（照片直接风格化）
const T2I_MODEL = "Qwen/Qwen-Image"  # 文生图（特征描述 → 游戏素材）
const VL_MODEL = "Qwen/Qwen3-VL-8B-Instruct"  # 视觉理解（毛色/体态特征提取）
const VID_MODEL = "Wan-AI/Wan2.2-I2V-A14B"

const POLL_INTERVAL = 5.0  # 视频状态轮询间隔（秒）
const MAX_POLL_COUNT = 120  # 最长等待 10 分钟

const VL_PROMPT = "你是马匹特征分析器。分析图片中的马，只输出一行 JSON（不要 markdown 代码块，不要其他文字）：{\"coat\": \"毛色基色\", \"pattern\": \"花纹或标记（无则填无）\", \"mane\": \"鬃毛和尾毛颜色\", \"build\": \"体态体型\"}。每个字段中文，12 字以内。"

var api_key: String = ""
var workspace_dir: String = "user://horse_generator_workspace/"

var _http: HTTPRequest
var _intent: String = ""
var _on_success: Callable
var _on_error: Callable
var _poll_count: int = 0
var _poll_timer: Timer


func _ready():
	_http = HTTPRequest.new()
	_http.timeout = 180.0  # 180 秒上限：VL 分析/视频轮询都可能较慢
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_poll_timer = Timer.new()
	_poll_timer.one_shot = true
	_poll_timer.timeout.connect(_poll_video_status)
	add_child(_poll_timer)


# ---------- 图片生成 ----------
# source_image_path 非空 = 图生图编辑（照片直接风格化）
# 否则 reference_images 非空 = 文生图 + 多图风格参考（Qwen-Image images 数组，已验证）
# 否则 = 纯文生图
# on_success(image_path: String)
func generate_image(prompt: String, source_image_path: String, on_success: Callable, on_error: Callable, reference_images: Array = []):
	var model = IMG_MODEL
	if source_image_path.is_empty():
		model = T2I_MODEL
	var body = {
		"model": model,
		"prompt": prompt,
		"response_format": "url",
	}
	if not source_image_path.is_empty():
		body["image"] = "data:image/png;base64," + _file_to_base64(source_image_path)
	elif not reference_images.is_empty():
		var refs = []
		for p in reference_images:
			refs.append("data:image/png;base64," + _file_to_base64_small(p))
		body["images"] = refs
	_start_request("img_gen", HTTPClient.METHOD_POST, API_BASE + "/v1/images/generations",
		body, on_success, on_error)


# ---------- 视觉理解（毛色/体态特征提取） ----------
# on_success(features: Dictionary) —— {"coat","pattern","mane","build"}
func analyze_horse(image_path: String, on_success: Callable, on_error: Callable):
	var body = {
		"model": VL_MODEL,
		"messages": [{
			"role": "user",
			"content": [
				{"type": "image_url", "image_url": {"url": "data:image/png;base64," + _file_to_base64(image_path)}},
				{"type": "text", "text": VL_PROMPT},
			],
		}],
		"max_tokens": 300,
	}
	_start_request("vl_analyze", HTTPClient.METHOD_POST, API_BASE + "/v1/chat/completions",
		body, on_success, on_error)


# ---------- 视频生成（图生视频，异步） ----------
# on_success(request_id: String)
func submit_video(prompt: String, source_image_path: String, on_success: Callable, on_error: Callable):
	var body = {
		"model": VID_MODEL,
		"image": "data:image/png;base64," + _file_to_base64(source_image_path),
		"prompt": prompt,
	}
	_start_request("vid_submit", HTTPClient.METHOD_POST, API_BASE + "/v1/video/submit",
		body, on_success, on_error)


# ---------- 状态轮询 ----------
# on_success(video_url: String) —— Succeeded 时回调
func poll_video(request_id: String, on_success: Callable, on_error: Callable):
	_poll_count = 0
	_current_request_id = request_id
	_vid_on_success = on_success
	_vid_on_error = on_error
	_poll_video_status()


func _poll_video_status():
	if _poll_count >= MAX_POLL_COUNT:
		_vid_on_error.call("视频生成超时（10 分钟）")
		return
	_poll_count += 1
	_poll_timer.start(POLL_INTERVAL)
	# status 是 POST 接口（文档：POST /v1/video/status，body 为 {"requestId": ...}）
	_start_request("vid_status", HTTPClient.METHOD_POST,
		API_BASE + "/v1/video/status",
		{"requestId": _current_request_id}, _on_video_status_ok, _vid_on_error)


func _on_video_status_ok(result):
	var status = result.get("status", "")
	if status == "Succeed":
		_poll_timer.stop()
		var video_url = ""
		var videos = result.get("results", {}).get("videos", [])
		if videos is Array and videos.size() > 0:
			video_url = str(videos[0].get("url", ""))
		_vid_on_success.call(video_url)
	elif status == "Failed":
		_poll_timer.stop()
		_vid_on_error.call("视频生成失败: %s" % str(result.get("reason", status)))
	else:
		pass  # InQueue / InProgress，等待定时器下次轮询


# ---------- 文件下载 ----------
# on_success(file_path: String)
func download_file(url: String, save_path: String, on_success: Callable, on_error: Callable):
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	if url.find("aliyuncs.com") >= 0 or url.find("Signature=") >= 0:
		# OSS 签名链接（sc-maas.oss-cn-shanghai...?Expires=...&Signature=...）：
		# Godot HTTPRequest 会规范化 URL（百分号解码再编码）导致签名不匹配，
		# OSS 返回 403 SignatureDoesNotMatch。改走 Python urllib（保留 URL 原文）。
		_download_via_python(url, save_path, on_success, on_error)
		return
	_pending_download_path = save_path
	_start_request("download", HTTPClient.METHOD_GET, url,
		{}, on_success, on_error)


func _download_via_python(url: String, save_path: String, on_success: Callable, on_error: Callable):
	var python = _find_python()
	if python == "":
		on_error.call("找不到 Python 环境，无法下载视频")
		return
	var script = ProjectSettings.globalize_path("res://ai_pipeline/download.py")
	var output = []
	var code = OS.execute(python, [script, url, save_path], output, true)
	if code == 0 and FileAccess.file_exists(save_path):
		on_success.call(save_path)
	else:
		on_error.call("视频下载失败: %s" % "\n".join(output))


func _find_python() -> String:
	var venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/Scripts/python.exe")
	if FileAccess.file_exists(venv):
		return venv
	venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/bin/python3")
	if FileAccess.file_exists(venv):
		return venv
	for name in ["python", "python3"]:
		var out = []
		var code = OS.execute(name, ["--version"], out)
		if code == 0:
			return name
	return ""


# ---------- 内部实现 ----------
var _current_request_id: String = ""
var _vid_on_success: Callable
var _vid_on_error: Callable
var _pending_download_path: String = ""


func _start_request(intent: String, method: int, url: String, body: Dictionary, on_success: Callable, on_error: Callable):
	_intent = intent
	_on_success = on_success
	_on_error = on_error
	var headers = ["Authorization: Bearer " + api_key, "Content-Type: application/json"]
	var body_str = JSON.stringify(body)
	var err = _http.request(url, headers, method, body_str)
	if err != OK:
		_on_error.call("请求发起失败: %s" % error_string(err))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_on_error.call("HTTP %d: %s" % [response_code, body.get_string_from_utf8().substr(0, 300)])
		return

	match _intent:
		"img_gen":
			_handle_img_gen(body)
		"vl_analyze":
			_handle_vl_analyze(body)
		"vid_submit":
			_handle_vid_submit(body)
		"vid_status":
			_handle_vid_status(body)
		"download":
			_handle_download(body)


func _handle_img_gen(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("data") or json.data.is_empty():
		_on_error.call("图片生成响应异常")
		return
	var url: String = json.data[0].get("url", "")
	if url.is_empty():
		_on_error.call("图片生成未返回 URL")
		return
	# 下载生成的图片到工作区
	var save_path = _workspace_dir() + "portrait_raw.png"
	download_file(url, save_path, _on_success, _on_error)


func _handle_vl_analyze(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or json.get("choices") == null or json.choices.is_empty():
		_on_error.call("视觉分析响应异常")
		return
	var content: String = json.choices[0].message.content
	var features = _parse_vl_json(content)
	if features == null:
		_on_error.call("无法解析特征结果: " + content.substr(0, 100))
		return
	_on_success.call(features)


## 从 VL 输出中提取 JSON（容忍 markdown 代码块包裹）
func _parse_vl_json(content: String) -> Variant:
	var text = content.strip_edges()
	if text.begins_with("```"):
		var first_nl = text.find("\n")
		if first_nl >= 0:
			text = text.substr(first_nl + 1)
		text = text.trim_suffix("```").strip_edges()
	if not text.begins_with("{"):
		var start = text.find("{")
		if start < 0:
			return null
		text = text.substr(start)
	var end = text.rfind("}")
	if end > 0:
		text = text.substr(0, end + 1)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return null


func _handle_vid_submit(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_on_error.call("视频提交响应异常")
		return
	var request_id: String = str(json.get("requestId", ""))
	if request_id.is_empty():
		_on_error.call("视频提交未返回 requestId")
		return
	_on_success.call(request_id)


func _handle_vid_status(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_on_error.call("视频状态响应异常")
		return
	_on_video_status_ok(json)


func _handle_download(body: PackedByteArray):
	var file = FileAccess.open(_pending_download_path, FileAccess.WRITE)
	if file == null:
		_on_error.call("无法写入文件: " + _pending_download_path)
		return
	file.store_buffer(body)
	file.close()
	_on_success.call(_pending_download_path)


func _file_to_base64(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return Marshalls.raw_to_base64(f.get_buffer(f.get_length()))


## 参考图缩小到 max_w 宽再 base64：10 张参考图必须控制请求体大小
func _file_to_base64_small(path: String, max_w: int = 256) -> String:
	var img = Image.load_from_file(path)
	if img == null:
		return ""
	if img.get_width() > max_w:
		var h = int(max_w * img.get_height() / img.get_width())
		img.resize(max_w, h)
	var png = img.save_png_to_buffer()
	return Marshalls.raw_to_base64(png)


func _workspace_dir() -> String:
	# 工作区在 user:// 下（%APPDATA%/新建游戏项目），按马前缀隔离
	var dir = workspace_dir
	DirAccess.make_dir_recursive_absolute(dir)
	return dir
