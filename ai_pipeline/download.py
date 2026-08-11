"""下载文件到指定路径

用法:
    python download.py <url> <output_path>

为什么需要这个脚本:
    OSS 签名链接（sc-maas.oss-cn-shanghai.aliyuncs.com/?Expires=...&Signature=...）
    在 Godot HTTPRequest 中会被 URL 规范化（百分号解码再编码），导致签名不匹配
    返回 403 SignatureDoesNotMatch。urllib 保留 URL 原文，可正常下载。
"""
import sys
import urllib.request


def main():
    if len(sys.argv) < 3:
        print("用法: python download.py <url> <output_path>", file=sys.stderr)
        sys.exit(1)
    url, out = sys.argv[1], sys.argv[2]
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")
    with urllib.request.urlopen(req, timeout=300) as resp, open(out, "wb") as f:
        f.write(resp.read())
    print("OK: %s" % out)


if __name__ == "__main__":
    main()
