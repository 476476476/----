extends RefCounted
## AI 马匹生成 — Python 环境准备与执行（游戏运行时版）。
##
## 导出游戏后 res:// 只读，PCK 内 PNG 转 ctex（Python 读不了），所以：
##   1. .py 脚本从 res:// 读取文本 → 复制到 user://ai_horses/py/（.py 在 PCK 中是原样文本，可读）
##   2. 嵌入式 Python 在 exe 同目录 embedded_python/（导出时手动放置，见 export 说明）
##   3. 背高参考数据用预生成 ref_breeds.json（res:// 美术帧导出后不可读）
##
## 统一入口：runner.py remove_bg|measure_back|process_video
## 嵌入式模型路径通过 runner.py --model 显式传入。

const PY_DIR = "user://ai_horses/py/"
const WORKSPACE = "user://ai_horses/workspace/"

# res://ai_pipeline 下需要复制到 user:// 的脚本/数据
const PY_FILES = [
	"runner.py", "remove_bg.py", "measure_back.py", "process_video.py",
	"u2net_matting.py", "download.py", "ref_breeds.json",
]


## 查找 Python 解释器（按优先级）：
##   1. exe 同目录 embedded_python/python.exe（导出的游戏）
##   2. 项目 ai_pipeline/.venv（编辑器开发环境）
##   3. 系统 PATH 中的 python
static func find_python() -> String:
	# exe 同目录 embedded_python/ 下找 python.exe（可能是子目录 python-3.13-embed-amd64/，扫描子目录）
	var embedded_root = OS.get_executable_path().get_base_dir() + "/embedded_python"
	var embedded = embedded_root + "/python.exe"
	if FileAccess.file_exists(embedded):
		return embedded
	var dir = DirAccess.open(embedded_root)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if dir.current_is_dir():
				var pe = embedded_root + "/" + fname + "/python.exe"
				if FileAccess.file_exists(pe):
					return pe
			fname = dir.get_next()
		dir.list_dir_end()
	var venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/Scripts/python.exe")
	if FileAccess.file_exists(venv):
		return venv
	venv = ProjectSettings.globalize_path("res://ai_pipeline/.venv/bin/python3")
	if FileAccess.file_exists(venv):
		return venv
	for name in ["python", "python3"]:
		var out = []
		if OS.execute(name, ["--version"], out) == 0:
			return name
	return ""


## 确保 user://ai_horses/py/ 下的脚本就位（从 res:// 复制）。
## 返回错误信息，空字符串 = 成功。
static func ensure_scripts() -> String:
	var py_dir = ProjectSettings.globalize_path(PY_DIR)
	if not DirAccess.dir_exists_absolute(py_dir):
		var err = DirAccess.make_dir_recursive_absolute(py_dir)
		if err != OK:
			return "无法创建脚本目录 %s (%s)" % [py_dir, error_string(err)]
	for fname in PY_FILES:
		var src = "res://ai_pipeline/" + fname
		var dst = py_dir + "/" + fname
		if FileAccess.file_exists(dst):
			continue
		# 注意：不能用 ResourceLoader.exists() —— .py 无资源 loader，恒返回 false。
		# 导出包中 .py 能否进包取决于编辑器文件系统缓存（编辑器开着时才打包）；
		# .txt 也无已知类型（编辑器关闭导出时被跳过）。.json 是 Godot 已知类型，任何导出方式都进包。
		# 所以脚本副本用 .json 包装（{"source": "..."}），运行时解包还原。
		var text = ""
		if FileAccess.file_exists(src):
			var f = FileAccess.open(src, FileAccess.READ)
			if f == null:
				return "无法读取 %s" % src
			text = f.get_as_text()
		else:
			var json_src = "res://ai_pipeline/" + fname.trim_suffix(".py") + ".py.json"
			if not FileAccess.file_exists(json_src):
				return "缺少 %s（导出包不完整）" % fname
			var f = FileAccess.open(json_src, FileAccess.READ)
			if f == null:
				return "无法读取 %s" % json_src
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary and parsed.has("source"):
				text = str(parsed["source"])
			else:
				return "脚本副本损坏: %s" % json_src
		var w = FileAccess.open(dst, FileAccess.WRITE)
		if w == null:
			return "无法写入 %s" % dst
		w.store_string(text)
	return ""


## 执行统一入口：python runner.py <command> <args...>
## 自动附加 --model（嵌入式模型在 exe 同目录时）。
## 返回 {code: int, output: Array[String]}。code == 0 且无 error() 即成功。
static func run(command: String, args: Array) -> Dictionary:
	var python = find_python()
	if python == "":
		return {"code": -1, "output": ["找不到 Python 环境（未捆绑 embedded_python，且系统未安装 Python）"]}
	var err = ensure_scripts()
	if not err.is_empty():
		return {"code": -1, "output": [err]}
	var runner = ProjectSettings.globalize_path(PY_DIR) + "/runner.py"
	var full_args: Array = [runner, command]
	full_args.append_array(args)
	# 嵌入式模型路径（exe 同目录 embedded_python/ 下，可能在子目录 python-3.13-embed-amd64/models/）
	var model = _find_model()
	if model != "":
		full_args.append("--model")
		full_args.append(model)
	var output: Array = []
	var code = OS.execute(python, full_args, output, true)
	return {"code": code, "output": output}


## 查找 exe 同目录 embedded_python/ 下的 u2net.onnx（可能在子目录 python-3.13-embed-amd64/models/）
static func _find_model() -> String:
	var root = OS.get_executable_path().get_base_dir() + "/embedded_python"
	var direct = root + "/models/u2net.onnx"
	if FileAccess.file_exists(direct):
		return direct
	var dir = DirAccess.open(root)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if dir.current_is_dir():
				var m = root + "/" + fname + "/models/u2net.onnx"
				if FileAccess.file_exists(m):
					return m
			fname = dir.get_next()
		dir.list_dir_end()
	return ""


static func ensure_workspace() -> String:
	var p = ProjectSettings.globalize_path(WORKSPACE)
	if not DirAccess.dir_exists_absolute(p):
		DirAccess.make_dir_recursive_absolute(p)
	return p
