"""背景移除（U²-Net 本地推理）

用法:
    python remove_bg.py <input.png> <output.png>

输入任意格式图片，输出透明背景 RGBA PNG。
依赖本地模型 ~/.u2net/u2net.onnx（获取方式见 u2net_matting.py 头部说明）。
"""
import sys

from PIL import Image

from u2net_matting import remove_background


def main():
    if len(sys.argv) < 3:
        print("用法: python remove_bg.py <input.png> <output.png>")
        sys.exit(1)

    input_path, output_path = sys.argv[1], sys.argv[2]

    img = Image.open(input_path)
    result = remove_background(img)
    result.save(output_path)
    print("OK: %s -> %s (%dx%d)" % (
        input_path, output_path, result.width, result.height))


if __name__ == "__main__":
    main()
