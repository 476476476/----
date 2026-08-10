"""删除已注册马匹的文件资产（.tres + 帧目录）

用法:
    python delete_asset.py <tres_path> <frames_dir>

为什么用这个脚本:
    删除时机恰逢 Godot 编辑器 import 扫描，Windows 下文件句柄被锁，
    DirAccess.remove_absolute 静默失败（返回值常被忽略）。
    Python 带重试：锁通常在 1~2 秒内释放，重试 5 次可绕过；
    彻底失败时退出码非 0，Godot 侧可把真实原因展示给用户。
"""
import os
import shutil
import sys
import time


def retry(fn, tries=5, delay=0.5):
    last = None
    for i in range(tries):
        try:
            fn()
            return True
        except OSError as e:
            last = e
            time.sleep(delay)
    print("重试 %d 次后仍失败: %s" % (tries, last), file=sys.stderr)
    return False


def main():
    tres = sys.argv[1] if len(sys.argv) > 1 else ""
    frames = sys.argv[2] if len(sys.argv) > 2 else ""
    if tres and os.path.isfile(tres):
        if not retry(lambda: os.remove(tres)):
            sys.exit(1)
    if frames and os.path.isdir(frames):
        if not retry(lambda: shutil.rmtree(frames)):
            sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()
