"""马背高度测量 + 与游戏品种比对

用法:
    python measure_back.py <horse.png> <reference_dir/> <output.json>

- horse.png: 任意图片（静态图/照片均可，内部自动抠图）
- reference_dir: 游戏马匹帧目录（Art_Resource/Horses/），自动扫描 *_run/frames/1.png
- output.json: 输出 JSON:
    {
      "back_height": 245,          # 输入马的背高（像素，距图底边）
      "best_match": "chitu",       # 背高最接近的品种 prefix
      "ref_back_height": 240,      # 最佳匹配品种的背高
      "frame_size": [836, 480],    # 最佳匹配品种的帧尺寸（动画对齐目标）
      "match_scores": {...}        # 每个品种的背高
    }

背高定义: 马躯干最高点（肩隆，排除耳朵/头部细窄部分）到图底边的像素距离。

注意: 游戏各品种帧分辨率不同（如 chitu 836x480、mongolian 836x704），
游戏内按 min(240/w, 160/h) 等比缩放显示。因此"背高相等"的语义是
缩放后的显示背高相等 —— 比对和 best_match 全部基于显示背高。
"""
import json
import os
import sys

# 嵌入式 Python 的 python.exe 不把脚本目录加入 sys.path，这里手动补上
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np
from PIL import Image

from u2net_matting import remove_background

# 游戏内贴图目标尺寸（与 horse.gd 的 target Vector2(240, 160) 一致）
GAME_TARGET_W, GAME_TARGET_H = 240, 160


def ensure_rgba(image_path: str) -> np.ndarray:
    """读图，必要时抠图，返回 RGBA 数组。"""
    img = Image.open(image_path)
    if img.mode != "RGBA":
        img = remove_background(img.convert("RGB"))
    return np.array(img)


def measure_back_height(rgba: np.ndarray) -> int:
    """测量背高: alpha 前景中"躯干"最顶部行到底边的距离。

    启发式: 按行统计前景宽度，宽度 >= 最大行宽的 40% 视为躯干
    （排除耳朵、头颈等细窄部位）。
    """
    alpha = rgba[:, :, 3]
    h = alpha.shape[0]
    ys, xs = np.where(alpha > 128)
    if len(ys) == 0:
        return 0

    widths = {}
    for y in np.unique(ys):
        sel = xs[ys == y]
        widths[y] = sel.max() - sel.min()
    max_width = max(widths.values())
    trunk_rows = [y for y, w in widths.items() if w >= max_width * 0.4]
    if not trunk_rows:
        return int(h - ys.min())
    return int(h - min(trunk_rows))


def display_scale(w: int, h: int) -> float:
    """游戏内缩放系数: min(240/w, 160/h)"""
    return min(GAME_TARGET_W / w, GAME_TARGET_H / h)


def find_reference(ref_dir: str):
    """扫描参考目录，返回 {prefix: {"back": 帧内背高, "display": 显示背高, "size": [w,h]}}。"""
    refs = {}
    if not os.path.isdir(ref_dir):
        print("参考目录不存在: %s" % ref_dir, file=sys.stderr)
        return refs
    for entry in sorted(os.listdir(ref_dir)):
        if not entry.endswith("_run"):
            continue
        prefix = entry[: -len("_run")]
        frame_path = os.path.join(ref_dir, entry, "frames", "1.png")
        if not os.path.exists(frame_path):
            continue
        rgba = ensure_rgba(frame_path)
        w, h = rgba.shape[1], rgba.shape[0]
        back = measure_back_height(rgba)
        scale = display_scale(w, h)
        refs[prefix] = {
            "back": back,
            "display": back * scale,
            "scale": scale,
            "size": [w, h],
        }
    return refs


def load_refs(json_path: str):
    """从预生成 JSON 读参考数据（导出游戏用：res:// 美术帧在 PCK 里 Python 读不到）。"""
    with open(json_path, encoding="utf-8") as f:
        return json.load(f)


def dump_refs(ref_dir: str, out_path: str):
    """预生成参考数据 JSON：python measure_back.py --dump-refs <out.json> <reference_dir/>"""
    refs = find_reference(ref_dir)
    if not refs:
        print("没有找到参考品种", file=sys.stderr)
        sys.exit(2)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(refs, f, indent=2, ensure_ascii=False)
    print("OK: %d 个品种参考数据写入 %s" % (len(refs), out_path))


def main():
    # 预生成模式：--dump-refs <out.json> <reference_dir/>
    if "--dump-refs" in sys.argv:
        i = sys.argv.index("--dump-refs")
        if i + 2 >= len(sys.argv):
            print("用法: python measure_back.py --dump-refs <out.json> <reference_dir/>")
            sys.exit(1)
        dump_refs(sys.argv[i + 2], sys.argv[i + 1])
        return

    if len(sys.argv) < 4:
        print("用法: python measure_back.py <horse.png> <reference_dir/> <output.json> [--refs <refs.json>]")
        sys.exit(1)

    input_path, ref_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    rgba = ensure_rgba(input_path)
    back = measure_back_height(rgba)
    print("输入马背高: %d px (图 %dx%d)" % (back, rgba.shape[1], rgba.shape[0]))

    # 导出游戏：美术帧在 PCK 里是 ctex，Python 读不到 → 用预生成 JSON
    if "--refs" in sys.argv:
        i = sys.argv.index("--refs")
        refs = load_refs(sys.argv[i + 1])
    else:
        refs = find_reference(ref_dir)
    if not refs:
        print("没有找到参考品种", file=sys.stderr)
        sys.exit(2)

    # 按显示背高比对（帧尺寸不同，帧内像素不可直接比）
    # 输入马用自身帧尺寸的显示缩放推算显示背高
    in_w, in_h = rgba.shape[1], rgba.shape[0]
    in_scale = display_scale(in_w, in_h)
    in_display = back * in_scale
    best = min(refs, key=lambda k: abs(refs[k]["display"] - in_display))
    best_info = refs[best]
    print("最匹配品种: %s (显示背高 %.0f, 帧 %dx%d)" % (
        best, best_info["display"], best_info["size"][0], best_info["size"][1]))

    result = {
        "back_height": int(back),             # 输入马帧内背高
        "display_back_height": round(in_display, 1),  # 输入马显示背高（语义基准）
        "best_match": best,
        "ref_back_height": best_info["back"],  # 参考马帧内背高（process_video 对齐目标）
        "frame_size": best_info["size"],       # 参考马帧尺寸（新帧输出尺寸）
        "match_scores": {k: round(v["display"], 1) for k, v in refs.items()},
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print("OK: %s" % out_path)


if __name__ == "__main__":
    main()
