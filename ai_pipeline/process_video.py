"""视频 → 动画帧序列（对齐 + 抠图）

用法:
    python process_video.py <video.mp4> <output_dir/> <measure.json> [frame_count] [seconds]

- video.mp4: 马匹奔跑视频（AI 生成或实拍）
- measure.json: measure_back.py 的输出（提供目标背高/帧尺寸）
- frame_count: 抽帧数量，默认 24（与游戏帧率一致）
- seconds: 只取视频开头 seconds 秒内的片段抽帧（默认 0 = 用完整视频）。
  视频长 5 秒但只需 1.5 秒时，用 1.5：帧间隔从 5/24≈208ms 降到 1.5/24≈62ms，
  相邻帧马位移小，游戏里动画更平滑、不像"快进"。

流程:
    1. OpenCV 抽帧（均匀采样，可选限定前 seconds 秒）
    2. 每帧 rembg 抠图 → RGBA
    3. 逐帧测背高 → 等比缩放使背高 == 参考品种背高
    4. 按前景质心水平居中
    5. 裁剪/填充到参考帧尺寸
    6. 输出 1.png, 2.png, ... 到 output_dir

注意: 不用 ffmpeg（避免额外依赖），纯 OpenCV + rembg。
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

from measure_back import measure_back_height
from u2net_matting import remove_background


def sample_frames(video_path: str, count: int, seconds: float = 0.0):
    """从视频前 seconds 秒内均匀抽 count 帧（seconds<=0 用完整视频），返回 BGR 帧列表。"""
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("无法打开视频: %s" % video_path, file=sys.stderr)
        sys.exit(2)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    if total <= 0:
        print("视频帧数未知，逐帧读取", file=sys.stderr)
        frames = []
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            frames.append(frame)
        cap.release()
        return frames

    end = total
    if seconds > 0:
        end = max(2, min(total, int(seconds * fps)))
        print("取前 %.1f 秒（第 0~%d 帧 / 共 %d 帧）" % (seconds, end - 1, total))

    idxs = [int(i * (end - 1) / max(count - 1, 1)) for i in range(count)]
    frames = []
    for idx in sorted(set(idxs)):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, frame = cap.read()
        if ok:
            frames.append(frame)
    cap.release()
    return frames


def align_and_pad(rgba: np.ndarray, target_back: int, target_w: int, target_h: int) -> Image.Image:
    """缩放使背高 == target_back，水平居中，完整放入目标画布。"""
    h, w = rgba.shape[:2]
    cur_back = measure_back_height(rgba)
    scale = target_back / cur_back if cur_back > 0 else 1.0
    new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))

    # 马的完整高度 = 背高 + 头部以上部分，必然 > target_back。
    # 若按"背距画布底 = target_back"摆放，马顶会算出负坐标，上半身被裁掉。
    # 画布放不下（头顶溢出）时整体等比缩小到画布 92% 高，保证完整显示。
    if new_h > int(target_h * 0.92):
        scale *= target_h * 0.92 / new_h
        new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))

    resized = cv2.resize(rgba, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)

    # 水平居中（前景质心）
    alpha = resized[:, :, 3]
    ys, xs = np.where(alpha > 128)
    cx = int(xs.mean()) if len(xs) else new_w // 2
    x0 = target_w // 2 - cx
    x1 = x0 + new_w

    # 垂直放置: 马蹄贴画布底（保留完整马身）
    y0 = target_h - new_h
    y1 = target_h

    canvas = np.zeros((target_h, target_w, 4), dtype=np.uint8)
    ox0, oy0 = max(0, x0), max(0, y0)
    ox1, oy1 = min(target_w, x1), min(target_h, y1)
    if ox1 > ox0 and oy1 > oy0:
        sx0, sy0 = ox0 - x0, oy0 - y0
        sw, sh = ox1 - ox0, oy1 - oy0
        canvas[oy0:oy1, ox0:ox1] = resized[sy0:sy0 + sh, sx0:sx0 + sw]

    return Image.fromarray(canvas, "RGBA")


def main():
    if len(sys.argv) < 4:
        print("用法: python process_video.py <video.mp4> <output_dir/> <measure.json> [frame_count] [seconds]")
        sys.exit(1)

    video_path, out_dir, measure_path = sys.argv[1], sys.argv[2], sys.argv[3]
    frame_count = int(sys.argv[4]) if len(sys.argv) > 4 else 24
    seconds = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0

    with open(measure_path, encoding="utf-8") as f:
        measure = json.load(f)
    target_back = measure["ref_back_height"]
    target_w, target_h = measure["frame_size"]

    os.makedirs(out_dir, exist_ok=True)
    frames = sample_frames(video_path, frame_count, seconds)
    print("抽帧 %d 张" % len(frames))

    for i, frame in enumerate(frames, start=1):
        bgr = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        rgba = remove_background(Image.fromarray(bgr))
        out = align_and_pad(np.array(rgba), target_back, target_w, target_h)
        out.save(os.path.join(out_dir, "%d.png" % i))
        if i % 5 == 0:
            print("  已处理 %d/%d" % (i, len(frames)))

    print("OK: %d 帧输出到 %s" % (len(frames), out_dir))


if __name__ == "__main__":
    main()
