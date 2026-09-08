"""Fits phone captures (2400x1080, 2.22:1 -- wider than 16:9) into 1920x1080,
which Play Console's 10-inch tablet slot requires exactly: 16:9 or 9:16, each
side between 1080px and 7680px.

Scales to fill the width and pads top/bottom with the app's own cream
background color, so the letterbox bars blend into the screenshot's own
background rather than reading as an obvious black bar.

    python store_listing/make_tablet_screenshots.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = "C:/Users/Rajkumar/AppData/Local/Temp/claude/D--Developer-Workspace-Flutter-kids-tamil-ezhuthu-school/ad76a8ef-4171-48f1-8fcf-5802e8d987ae/scratchpad/tablet"
OUT_DIR = os.path.join(HERE, "screenshots", "tablet_10in")

TARGET_W, TARGET_H = 1920, 1080  # exactly 16:9
BACKGROUND = (255, 246, 226)  # #FFF6E2, the app's own light-theme background

SOURCES = [
    ("home_light.png", "1_home.png"),
    ("gate.png", "2_parental_gate.png"),
    ("parent_zone.png", "3_parent_zone.png"),
]


def fit_and_pad(src_path, out_path):
    im = Image.open(src_path).convert("RGB")
    scale = TARGET_W / im.width
    scaled = im.resize((TARGET_W, round(im.height * scale)), Image.LANCZOS)

    canvas = Image.new("RGB", (TARGET_W, TARGET_H), BACKGROUND)
    y = (TARGET_H - scaled.height) // 2
    canvas.paste(scaled, (0, y))
    canvas.save(out_path)
    print(f"wrote {out_path} ({canvas.size[0]}x{canvas.size[1]}, source scaled to "
          f"{scaled.size[0]}x{scaled.size[1]}, {y}px padding top/bottom)")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for src_name, out_name in SOURCES:
        fit_and_pad(os.path.join(SRC_DIR, src_name), os.path.join(OUT_DIR, out_name))


if __name__ == "__main__":
    main()
