"""AI 马匹生成 — 统一 Python 入口（游戏导出环境专用）

用法:
    python runner.py <command> <args...>

可用命令（与各脚本原用法一致，去掉脚本名前缀）:
    remove_bg      <input.png> <output.png>
    measure_back   <horse.png> <reference_dir/> <output.json> [--refs <refs.json>]
    process_video  <video.mp4> <output_dir/> <measure.json> [frame_count] [seconds]

全局可选参数:
    --model <u2net.onnx路径>   指定抠图模型（游戏导出时模型在 exe 同目录，
                               脚本已被复制到 user://，必须显式指定）

游戏端（Godot）只需知道这一个入口，不需要分别构造三个脚本的调用；
嵌入式 Python 的隔离模式路径问题也在这里统一修复。
"""
import importlib.util
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# 嵌入式 Python 的 python.exe 不把脚本目录加入 sys.path，这里手动补上
sys.path.insert(0, _SCRIPT_DIR)

COMMANDS = ("remove_bg", "measure_back", "process_video")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print("用法: python runner.py <command> <args...>")
        print("可用命令: %s" % ", ".join(COMMANDS))
        sys.exit(1)

    name = sys.argv[1]

    # 全局 --model：指定 u2net.onnx 路径（游戏导出时嵌入式模型在 exe 同目录，
    # 脚本已被复制到 user://，无法按"脚本同级 models/"探测）
    if "--model" in sys.argv:
        i = sys.argv.index("--model")
        if i + 1 < len(sys.argv):
            os.environ["U2NET_MODEL_OVERRIDE"] = sys.argv[i + 1]
            del sys.argv[i:i + 2]

    spec = importlib.util.spec_from_file_location(
        "cmd_" + name, os.path.join(_SCRIPT_DIR, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    # argv[0] 换成脚本名（原脚本按 argv[1..] 取参），其余参数原样透传
    sys.argv = [name + ".py"] + sys.argv[2:]
    mod.main()


if __name__ == "__main__":
    main()
