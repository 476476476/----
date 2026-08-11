"""背景移除（U²-Net 本地推理）

用法:
    python remove_bg.py <input.png> <output.png> [--model <u2net.onnx路径>]

输入任意格式图片，输出透明背景 RGBA PNG。
模型查找顺序见 u2net_matting.py 头部说明（默认优先脚本同级 models/）。
"""
import os
import sys

# 嵌入式 Python 的 python.exe 不把脚本目录加入 sys.path，这里手动补上
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image

from u2net_matting import remove_background


def main():
    if len(sys.argv) < 3:
        print("用法: python remove_bg.py <input.png> <output.png> [--model <path>]")
        sys.exit(1)

    input_path, output_path = sys.argv[1], sys.argv[2]
    model_path = None
    if "--model" in sys.argv:
        i = sys.argv.index("--model")
        if i + 1 < len(sys.argv):
            model_path = sys.argv[i + 1]

    img = Image.open(input_path)
    result = remove_background(img, model_path)
    result.save(output_path)
    print("OK: %s -> %s (%dx%d)" % (
        input_path, output_path, result.width, result.height))


if __name__ == "__main__":
    main()
