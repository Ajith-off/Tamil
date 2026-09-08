"""Render a letter's stroke data as a filmstrip, to check writing direction.

A still picture of a finished letter cannot show which way the pen went, and
direction is exactly what keeps going wrong — அ's bar was traced twice over
and its opening loop ran backwards, neither visible in a single frame. This
draws the path at a series of moments so the motion is readable.

    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/filmstrip.py uyir_01 out.png

Reads the emitted stroke JSON, so it checks what actually shipped rather than
re-deriving anything.
"""

from __future__ import annotations

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

import glyph_skeleton as gs
from trace_letter import MARGIN

PANELS = 8
PANEL_PX = 260
PAD = 8
ARROW_EVERY_PX = 34
# One colour per stroke, so a letter written in three or four of them can be
# told apart at a glance. ஔ needs all of these.
STROKE_COLOURS = [
    (215, 60, 40), (30, 90, 210), (0, 140, 70), (200, 120, 0),
    (150, 0, 160), (0, 150, 150),
]


def _arrowheads(draw, points, colour):
    """Chevrons along the path, pointing the way the pen is travelling.

    Panels alone cannot settle the direction of a loop: half a loop in either
    direction ends up in much the same place, so both readings look alike.
    An arrow does not have that problem. அ's opening loop ran backwards for a
    while precisely because nothing was drawing these.
    """
    travelled = 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        step = math.dist((x0, y0), (x1, y1))
        travelled += step
        if travelled < ARROW_EVERY_PX or step == 0:
            continue
        travelled = 0.0
        ux, uy = (x1 - x0) / step, (y1 - y0) / step
        px, py = -uy, ux
        tip = (x1 + ux * 6, y1 + uy * 6)
        draw.polygon(
            [tip, (x1 - ux * 3 + px * 5, y1 - uy * 3 + py * 5),
             (x1 - ux * 3 - px * 5, y1 - uy * 3 - py * 5)],
            fill=colour,
        )


def load(letter_id: str):
    path = f"lib/data/letters/strokes/{letter_id}.json"
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    return [[(p["x"], p["y"]) for p in s["points"]] for s in data["strokes"]], data


def render(letter_id: str, char: str | None, out_path: str, panels: int = PANELS):
    strokes, data = load(letter_id)
    total = sum(len(s) for s in strokes)

    # The glyph behind the path, so it is obvious when a stroke wanders off it.
    # Fitted exactly the way trace_letter normalises the strokes — same
    # margin, one scale for both axes, centred. The raster is cut to each
    # glyph now, so squeezing it into a square panel would stretch a wide
    # letter like ஔ and the ghost would no longer sit under its own path.
    ghost = None
    if char:
        mask = gs.rasterize(char)
        ink = np.argwhere(mask)
        min_r, min_c = ink.min(axis=0)
        max_r, max_c = ink.max(axis=0)
        height, width = max_r - min_r + 1, max_c - min_c + 1
        scale = (1 - 2 * MARGIN) * PANEL_PX / max(width, height)
        size = (max(1, round(width * scale)), max(1, round(height * scale)))
        crop = Image.fromarray(
            (mask[min_r:max_r + 1, min_c:max_c + 1] * 255).astype("uint8")
        ).resize(size, Image.LANCZOS)
        ghost = Image.new("L", (PANEL_PX, PANEL_PX), 0)
        ghost.paste(crop, ((PANEL_PX - size[0]) // 2, (PANEL_PX - size[1]) // 2))

    strip = Image.new(
        "RGB", (panels * PANEL_PX + (panels + 1) * PAD, PANEL_PX + 2 * PAD), "white"
    )
    draw_strip = ImageDraw.Draw(strip)

    for panel in range(panels):
        shown = round(total * (panel + 1) / panels)
        tile = Image.new("RGB", (PANEL_PX, PANEL_PX), "white")
        if ghost is not None:
            tile.paste(Image.new("RGB", (PANEL_PX, PANEL_PX), (234, 234, 234)), (0, 0), ghost)
        draw = ImageDraw.Draw(tile)

        drawn = 0
        for i, stroke in enumerate(strokes):
            take = max(0, min(len(stroke), shown - drawn))
            drawn += len(stroke)
            # A dot is one point, so it has no line to draw — but it is a
            # whole stroke of the letter and has to be visible here, or the
            # filmstrip silently stops showing the puḷḷi.
            if len(stroke) == 1:
                if take >= 1:
                    x, y = stroke[0]
                    r = data["tubeWidthFactor"] * PANEL_PX / 2
                    draw.ellipse(
                        [x * PANEL_PX - r, y * PANEL_PX - r,
                         x * PANEL_PX + r, y * PANEL_PX + r],
                        fill=STROKE_COLOURS[i % len(STROKE_COLOURS)],
                    )
                continue
            if take < 2:
                continue
            pts = [(x * PANEL_PX, y * PANEL_PX) for x, y in stroke[:take]]
            colour = STROKE_COLOURS[i % len(STROKE_COLOURS)]
            draw.line(pts, fill=colour, width=7, joint="curve")
            _arrowheads(draw, pts, (255, 255, 255))
            # The head of the pen, so its direction of travel is unmistakable.
            draw.ellipse([pts[-1][0] - 9, pts[-1][1] - 9, pts[-1][0] + 9, pts[-1][1] + 9],
                         fill=(0, 0, 0))
            draw.ellipse([pts[0][0] - 7, pts[0][1] - 7, pts[0][0] + 7, pts[0][1] + 7],
                         fill=(255, 200, 0))

        x = PAD + panel * (PANEL_PX + PAD)
        strip.paste(tile, (x, PAD))
        draw_strip.rectangle([x, PAD, x + PANEL_PX, PAD + PANEL_PX], outline=(200, 200, 200))
        draw_strip.text((x + 6, PAD + 4), f"{panel + 1}/{panels}", fill=(120, 120, 120))

    strip.save(out_path)
    return data


if __name__ == "__main__":
    letter_id = sys.argv[1] if len(sys.argv) > 1 else "uyir_01"
    out = sys.argv[2] if len(sys.argv) > 2 else "filmstrip.png"
    # The character is only needed for the ghost, and trace_letter knows it.
    try:
        from trace_letter import load_orders
        char = load_orders().get(letter_id, (None, None))[0]
    except Exception:
        char = None
    render(letter_id, char, out)
    print(f"wrote {out}   (yellow = stroke start, black = pen head)")
