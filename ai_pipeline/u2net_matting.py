"""U²-Net 抠图模块：直调本地 onnx 模型，不依赖 rembg 的模型下载管理。

rembg 的 pooch 下载器强制从 GitHub 拉模型并校验固定 MD5：
国内网络连不上 GitHub，且镜像源的文件哈希不同导致校验永远失败。
这里改为直接加载本地模型推理。

模型查找顺序（优先级从高到低）：
1. --model 命令行参数
2. U2NET_MODEL_OVERRIDE 环境变量（runner.py 设置）
3. 脚本同级目录 models/u2net.onnx（嵌入式 Python 随游戏分发时用这个）
4. U2NET_HOME 环境变量
5. ~/.u2net/u2net.onnx（编辑器开发环境用这个）

模型获取方式（二选一）:
1. 从 hf-mirror 下载: https://hf-mirror.com/frankminors123/U2Net_ONNX/resolve/main/u2net.onnx
   放入 ~/.u2net/u2net.onnx
2. 或从 GitHub 原版下载（能连通时）:
   https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx
"""
import os
import sys

import numpy as np
from PIL import Image

_script_dir = os.path.dirname(os.path.abspath(__file__))


def default_model_path() -> str:
    """按查找顺序返回模型路径，返回的路径存在性由 get_session() 检查。"""
    # 1. 命令行 --model
    if "--model" in sys.argv:
        i = sys.argv.index("--model")
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    # 2. U2NET_MODEL_OVERRIDE 环境变量（runner.py 统一注入）
    override = os.getenv("U2NET_MODEL_OVERRIDE")
    if override and os.path.exists(override):
        return override
    # 3. 脚本同级 models/（嵌入式 Python 随游戏分发）
    bundled = os.path.join(_script_dir, "models", "u2net.onnx")
    if os.path.exists(bundled):
        return bundled
    # 4. U2NET_HOME
    return os.path.join(
        os.getenv("U2NET_HOME", os.path.expanduser("~/.u2net")), "u2net.onnx"
    )


_session = None
_session_path = None


def get_session(model_path: str | None = None):
    global _session, _session_path
    path = model_path or default_model_path()
    if _session is None or _session_path != path:
        import onnxruntime as ort

        if not os.path.exists(path):
            raise FileNotFoundError(
                "找不到抠图模型: %s\n"
                "请先下载 u2net.onnx 到该目录（见 u2net_matting.py 头部说明）" % path
            )
        _session = ort.InferenceSession(path)
        _session_path = path
    return _session


_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def remove_background(img: Image.Image, model_path: str | None = None) -> Image.Image:
    """抠图：输入任意模式图，输出透明背景 RGBA 图。"""
    sess = get_session(model_path)
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
