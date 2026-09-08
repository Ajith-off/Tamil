"""Builds feature_graphic.html — same design as make_feature_graphic.py, but
rendered as real HTML/SVG so a proper browser engine (with full Tamil text
shaping) draws the Tamil text, instead of Pillow, which lacks raqm/HarfBuzz
and mis-renders Tamil conjuncts and vowel signs.

    python store_listing/build_feature_graphic_html.py
    "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
        --headless --disable-gpu --screenshot="store_listing/feature_graphic.png" \
        --window-size=1024,500 --default-background-color=0 \
        "file:///.../store_listing/feature_graphic.html"
"""
import base64
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

W, H = 1024, 500

BACKGROUND = "#FFF6E2"
BACKGROUND_GLOW = "#FFE7AE"
TRACE_START = "#FFD166"
TRACE_END = "#FF8C42"
TUBE_EDGE = "#D3C6A4"
INK = "#4A3F2A"
TEXT_SECONDARY = "#8A7A55"
STAR_FILLED = "#FFC53D"


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def load_letter_svg_paths(letter_id, box):
    """Real stroke data -> SVG path 'd' strings, scaled into `box` (x, y, side)."""
    with open(os.path.join(ROOT, "lib", "data", "letters", "strokes", f"{letter_id}.json"),
              encoding="utf-8") as f:
        data = json.load(f)
    ox, oy, side = box
    paths = []
    for stroke in data["strokes"]:
        pts = stroke["points"]
        if len(pts) == 1:
            continue  # dots not needed for this letter (அ has none)
        d = f"M {ox + pts[0]['x'] * side:.2f} {oy + pts[0]['y'] * side:.2f} "
        d += " ".join(f"L {ox + p['x'] * side:.2f} {oy + p['y'] * side:.2f}" for p in pts[1:])
        paths.append(d)
    return paths, data["tubeWidthFactor"] * side


def main():
    font_b64 = b64(os.path.join(ROOT, "assets", "fonts", "NotoSansTamil-Regular.ttf"))
    icon_b64 = b64(os.path.join(ROOT, "assets", "images", "app_icon.png"))

    letter_paths, tube_w = load_letter_svg_paths("uyir_01", box=(620, 50, 380))

    letter_svg_strokes = "\n".join(
        f'<path d="{d}" fill="none" stroke="url(#trace)" '
        f'stroke-width="{tube_w:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
        for d in letter_paths
    )
    letter_svg_edges = "\n".join(
        f'<path d="{d}" fill="none" stroke="{TUBE_EDGE}" '
        f'stroke-width="{tube_w + 4:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
        for d in letter_paths
    )

    html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
@font-face {{
  font-family: 'NotoSansTamil';
  src: url(data:font/ttf;base64,{font_b64}) format('truetype');
}}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {W}px; height: {H}px; overflow: hidden; }}
body {{
  font-family: 'NotoSansTamil', sans-serif;
  background: radial-gradient(circle at 62% 42%, {BACKGROUND_GLOW} 0%, {BACKGROUND} 90%);
  position: relative;
}}
.icon {{
  position: absolute; left: 56px; top: 48px;
  width: 108px; height: 108px; border-radius: 50%;
  object-fit: cover;
}}
.title {{
  position: absolute; left: 56px; top: 178px;
  font-size: 39px; font-weight: 700; color: {INK};
  margin: 0; white-space: nowrap;
}}
.subtitle {{
  position: absolute; left: 58px; top: 238px;
  font-size: 28px; color: {TEXT_SECONDARY};
}}
.badge {{
  position: absolute; left: 56px; top: 296px;
  background: {TRACE_END}; color: white;
  font-size: 24px; font-weight: 600;
  padding: 12px 22px; border-radius: 999px;
}}
.sparkle {{
  position: absolute; color: {STAR_FILLED}; font-size: 30px;
}}
</style></head>
<body>
  <img class="icon" src="data:image/png;base64,{icon_b64}">
  <div class="title">அஆஇஈ தமிழ் எழுத்து</div>
  <div class="subtitle">Kids Tamil Alphabet</div>
  <div class="badge">247 எழுத்துகள்</div>
  <div class="sparkle" style="left:494px; top:70px;">&#10022;</div>
  <div class="sparkle" style="left:50px; top:405px; font-size:22px;">&#10022;</div>
  <svg width="{W}" height="{H}" style="position:absolute; left:0; top:0;">
    <defs>
      <linearGradient id="trace" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="{TRACE_START}"/>
        <stop offset="100%" stop-color="{TRACE_END}"/>
      </linearGradient>
    </defs>
    {letter_svg_edges}
    {letter_svg_strokes}
  </svg>
</body></html>
"""
    out_path = os.path.join(HERE, "feature_graphic.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
