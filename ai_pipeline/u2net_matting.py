"""U²-Net 抠图模块：直调本地 onnx 模型，不依赖 rembg 的模型下载管理。

rembg 的 pooch 下载器强制从 GitHub 拉模型并校验固定 MD5：
国内网络连不上 GitHub，且镜像源的文件哈希不同导致校验永远失败。
这里改为直接加载本地模型推理（模型路径可由 U2NET_HOME 环境变量覆盖）。

模型获取方式（二选一）:
1. 从 hf-mirror 下载: https://hf-mirror.com/frankminors123/U2Net_ONNX/resolve/main/u2net.onnx
   放入 ~/.u2net/u2net.onnx
2. 或从 GitHub 原版下载（能连通时）:
   https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx
"""
import os

import numpy as np
from PIL import Image

MODEL_PATH = os.path.join(
    os.getenv("U2NET_HOME", os.path.expanduser("~/.u2net")), "u2net.onnx"
)

_session = None
_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def get_session():
    global _session
    if _session is None:
        import onnxruntime as ort

        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                "找不到抠图模型: %s\n"
                "请先下载 u2net.onnx 到该目录（见 u2net_matting.py 头部说明）" % MODEL_PATH
            )
        _session = ort.InferenceSession(MODEL_PATH)
    return _session


def remove_background(img: Image.Image) -> Image.Image:
    """抠图：输入任意模式图，输出透明背景 RGBA 图。"""
    sess = get_session()
    small = img.convert("RGB").resize((320, 320), Image.LANCZOS)
    x = np.array(small, dtype=np.float32) / 255.0
    x = (x - _MEAN) / _STD
    x = x.transpose(2, 0, 1)[None, ...].astype(np.float32)

    out = sess.run(None, {sess.get_inputs()[0].name: x})[0]
    mask = out[0, 0]
    mask = (mask - mask.min()) / (mask.max() - mask.min() + 1e-9)
    mask_img = Image.fromarray((mask * 255).astype(np.uint8), "L").resize(
        img.size, Image.LANCZOS
    )

    rgba = img.convert("RGBA")
    rgba.putalpha(mask_img)
    return rgba
