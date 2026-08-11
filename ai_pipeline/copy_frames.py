"""复制动画帧序列

用法:
    python copy_frames.py <src_dir/> <dst_dir/> <count>

为什么用这个脚本:
    在 Godot 编辑器内用 DirAccess.copy_absolute 复制帧时，编辑器对 res://
    的 import 扫描会锁住目标目录/文件句柄，导致复制间歇失败。
    Python shutil 是独立进程，走系统调用，不受编辑器内部状态影响。
"""
import shutil
import sys


def main():
    if len(sys.argv) < 4:
        print("用法: python copy_frames.py <src_dir/> <dst_dir/> <count>", file=sys.stderr)
        sys.exit(1)
    src, dst, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
    for i in range(1, count + 1):
        shutil.copy("%s/%d.png" % (src, i), "%s/%d.png" % (dst, i))
    print("OK %d 帧" % count)


if __name__ == "__main__":
    main()
