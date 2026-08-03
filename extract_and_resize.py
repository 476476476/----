"""
Extract zip frames at ORIGINAL resolution. No resizing.
Game code handles scaling via AnimatedSprite2D.scale.
"""
import os, re, zipfile, io
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(BASE, "Art_Resource")


def extract_number(filename):
    name = os.path.splitext(os.path.basename(filename))[0]
    m = re.search(r'(\d+)$', name)
    return int(m.group(1)) if m else 0


def process_zip(zip_path):
    zip_dir = os.path.dirname(zip_path)
    frames_dir = os.path.join(zip_dir, "frames")
    os.makedirs(frames_dir, exist_ok=True)

    zip_name = os.path.basename(zip_path)
    print(f"  Extracting: {zip_name}")

    with zipfile.ZipFile(zip_path, 'r') as zf:
        png_files = [f for f in zf.namelist() if f.lower().endswith('.png')]
        png_files.sort(key=extract_number)

        for i, png_name in enumerate(png_files, start=1):
            data = zf.read(png_name)
            out_path = os.path.join(frames_dir, f"{i}.png")
            with open(out_path, 'wb') as out:
                out.write(data)

        print(f"    -> {len(png_files)} frames (original resolution)")


def main():
    print("=== Extracting frames at original resolution ===\n")
    for root, dirs, files in os.walk(ART):
        for f in files:
            if f.endswith('.zip'):
                process_zip(os.path.join(root, f))
    print("\n=== Done ===")


if __name__ == "__main__":
    main()
