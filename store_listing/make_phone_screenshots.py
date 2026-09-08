"""Fits phone captures (2400x1080, 2.22:1) into 1920x1080 (exactly 16:9),
which Play Console's Phone assets slot requires the same way the tablet slot
does. Same letterbox-with-matching-background treatment as
make_tablet_screenshots.py.

    python store_listing/make_phone_screenshots.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = "C:/Users/Rajkumar/AppData/Local/Temp/claude/D--Developer-Workspace-Flutter-kids-tamil-ezhuthu-school/ad76a8ef-4171-48f1-8fcf-5802e8d987ae/scratchpad/tablet"
OUT_DIR = os.path.join(HERE, "screenshots")

TARGET_W, TARGET_H = 1920, 1080  # exactly 16:9
BACKGROUND = (255, 246, 226)  # #FFF6E2, the app's own light-theme background

SOURCES = [
    ("p_home.png", "1_home.png"),
    ("p_letter_list.png", "2_letter_list.png"),
    ("p_tracing.png", "3_tracing.png"),
    ("p_word_cards.png", "4_word_cards.png"),
    ("p_word_builder.png", "5_word_builder.png"),
]


def fit_and_pad(src_path, out_path):
    im = Image.open(src_path).convert("RGB")
    scale = TARGET_W / im.width
    scaled = im.resize((TARGET_W, round(im.height * scale)), Image.LANCZOS)

    canvas = Image.new("RGB", (TARGET_W, TARGET_H), BACKGROUND)
    y = (TARGET_H - scaled.height) // 2
    canvas.paste(scaled, (0, y))
    canvas.save(out_path)
    print(f"wrote {out_path} ({canvas.size[0]}x{canvas.size[1]})")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for src_name, out_name in SOURCES:
        fit_and_pad(os.path.join(SRC_DIR, src_name), os.path.join(OUT_DIR, out_name))


if __name__ == "__main__":
    main()
