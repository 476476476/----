extends SceneTree
func _init():
	var src = "C:/Users/杨云博12138/AppData/Roaming/Godot/app_userdata/新建游戏项目/horse_generator_workspace/frames"
	var dst = "F:/AICoding/Xyh/----/Art_Resource/Horses/ai_1_run/frames"
	print("src 1.png exists: ", FileAccess.file_exists(src + "/1.png"))
	var ok = DirAccess.copy_absolute(src + "/1.png", dst + "/1.png")
	print("copy_absolute: ", ok)
	print("dst 1.png exists: ", FileAccess.file_exists(dst + "/1.png"))
	# 手动字节复制对比
	var f = FileAccess.open(src + "/1.png", FileAccess.READ)
	var w = FileAccess.open(dst + "/2.png", FileAccess.WRITE)
	if f and w:
		w.store_buffer(f.get_buffer(f.get_length()))
		w.close(); f.close()
		print("manual copy exists: ", FileAccess.file_exists(dst + "/2.png"))
	DirAccess.remove_absolute(dst + "/1.png")
	DirAccess.remove_absolute(dst + "/2.png")
	DirAccess.remove_absolute(dst)
	DirAccess.remove_absolute("F:/AICoding/Xyh/----/Art_Resource/Horses/ai_1_run")
	print("cleaned")
	quit(0)
