"""Ship each glyph's skeleton arcs to the app, for the authoring screen.

`trace_letter.py` needs a writing order it cannot derive — which arc is drawn
first, and in which direction. Three attempts at inferring that from a
handwriting animation all disagreed with the hand-verified அ (see HANDOFF.md),
because the font letterform and the animation are different shapes.

So the order comes from a person drawing it. The authoring screen shows the
letter, records a finger path, and reports back which arcs were crossed in
what order. For that it needs the same arcs this pipeline indexes, in the same
normalized space the app paints in — which is what this writes.

Geometry only. Nothing here decides order.

    python tools/export_skeletons.py            # every letter
    python tools/export_skeletons.py uyir_02    # just one
"""

from __future__ import annotations

import json
import os
import sys

import glyph_skeleton as gs
from trace_letter import MARGIN, resample, smooth

OUT_DIR = "assets/authoring/skeletons"

# The 12 uyir plus ஃ. Ids match lib/data/letters/uyir.json, so an authored
# order lands on the right stroke file.
LETTERS: list[tuple[str, str]] = [
    ("uyir_01", "அ"),
    ("uyir_02", "ஆ"),
    ("uyir_03", "இ"),
    ("uyir_04", "ஈ"),
    ("uyir_05", "உ"),
    ("uyir_06", "ஊ"),
    ("uyir_07", "எ"),
    ("uyir_08", "ஏ"),
    ("uyir_09", "ஐ"),
    ("uyir_10", "ஒ"),
    ("uyir_11", "ஓ"),
    ("uyir_12", "ஔ"),
    ("aaytham_01", "ஃ"),
    # The 18 mei. Each is its consonant plus the puḷḷi (U+0BCD) — a filled
    # dot, which is exactly the case `_dot_arcs` exists for: its medial axis
    # is a single point that the pruner would otherwise clear away, as it did
    # to ஈ's dots.
    ("mei_01", "க்"),
    ("mei_02", "ங்"),
    ("mei_03", "ச்"),
    ("mei_04", "ஞ்"),
    ("mei_05", "ட்"),
    ("mei_06", "ண்"),
    ("mei_07", "த்"),
    ("mei_08", "ந்"),
    ("mei_09", "ப்"),
    ("mei_10", "ம்"),
    ("mei_11", "ய்"),
    ("mei_12", "ர்"),
    ("mei_13", "ல்"),
    ("mei_14", "வ்"),
    ("mei_15", "ழ்"),
    ("mei_16", "ள்"),
    ("mei_17", "ற்"),
    ("mei_18", "ன்"),
    # The six grantha letters, outside the 247 (CLAUDE.md section 2 counts only
    # the 247; these write borrowed sounds). Appended, never interleaved: every
    # order in tools/orders.json names arc indices, so the one thing that must
    # not happen is an existing letter's arcs renumbering. Adding entries here
    # cannot do that — each letter's skeleton is built from its own glyph — and
    # `git status` staying clean over assets/authoring/skeletons/ is the check.
    #
    # க்ஷ is a conjunct (க் + ஷ) and ஸ்ரீ is ஸ் + ரீ; both shape to a single
    # precomposed glyph in the bundled font, so neither needs special handling.
    ("vadamozhi_01", "ஜ"),
    ("vadamozhi_02", "ஷ"),
    ("vadamozhi_03", "ஸ"),
    ("vadamozhi_04", "ஹ"),
    ("vadamozhi_05", "க்ஷ"),
    ("vadamozhi_06", "ஸ்ரீ"),
]


def uyirmei_to_author() -> list[tuple[str, str]]:
    """The uyirmei that actually need a person to draw them.

    216 characters, but only some are new shapes. Ask HarfBuzz what each one
    is made of and three cases fall out:

    * **fused** — one precomposed glyph that is not the bare consonant (கு,
      கீ, டி …). Nothing to reuse, so each needs its own order. 56 of them.
    * **touching** — two glyphs whose *ink* runs together, so the skeleton is
      a single connected piece with no seam to recombine along. Composition
      works by swapping whole components, so these cannot be composed either.
      16 of them, all in the ி column.
    * **composable** — the consonant's own glyph plus a vowel sign that stays
      a separate piece. The consonant half is already authored as a mei
      letter; only the sign needs an order, and one representative character
      per distinct sign *shape* supplies it.
    * **bare** — the inherent-a form, which *is* the consonant. Already done.

    So this returns the fused, the touching, and one representative per
    separable sign shape. Everything else `compose_uyirmei.py` builds.
    """
    import uharfbuzz as hb
    from scipy import ndimage

    blob = hb.Blob.from_file_path(gs.FONT_PATH)
    font = hb.Font(hb.Face(blob))

    def gids(text: str) -> list[int]:
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(font, buf)
        return [info.codepoint for info in buf.glyph_infos]

    with open("lib/data/letters/uyirmei.json", encoding="utf-8") as fh:
        roster = json.load(fh)

    bare = {row["groupTamil"]: gids(row["groupTamil"])[0] for row in roster}
    wanted: list[tuple[str, str]] = []
    seen_signs: set[int] = set()
    for row in roster:
        glyphs = gids(row["tamil"])
        base = bare[row["groupTamil"]]
        if len(glyphs) == 1:
            if glyphs[0] != base:
                wanted.append((row["id"], row["tamil"]))  # fused
            continue
        if ndimage.label(gs.rasterize(row["tamil"]))[1] == 1:
            # Two glyphs, one piece of ink: the sign has run into the
            # consonant and there is no component boundary to compose along.
            wanted.append((row["id"], row["tamil"]))
            continue
        signs = [g for g in glyphs if g != base]
        if any(g not in seen_signs for g in signs):
            seen_signs.update(signs)
            wanted.append((row["id"], row["tamil"]))  # representative
    return wanted


def build_skeleton_data(letter_id: str, char: str) -> dict:
    skel = gs.build(char)
    arcs = gs.ordered_arcs(skel)

    # Same treatment the final stroke data gets, so what the author draws over
    # is the shape the child will trace, not a rawer version of it.
    arcs = [smooth(resample(arc, skel.stroke_width * 0.18)) for arc in arcs]

    # One scale for both axes, fitted to the whole skeleton. trace_letter.py
    # fits to the chosen strokes instead, so a letter whose order skips an arc
    # will sit fractionally differently in the final file — irrelevant here,
    # where only the order is being read off.
    every = [p for arc in arcs for p in arc]
    min_r, max_r = min(p[0] for p in every), max(p[0] for p in every)
    min_c, max_c = min(p[1] for p in every), max(p[1] for p in every)
    width, height = max_c - min_c, max_r - min_r
    scale = (1 - 2 * MARGIN) / max(width, height)
    off_x = (1 - width * scale) / 2
    off_y = (1 - height * scale) / 2

    def normalize(points):
        return [{"x": round(off_x + (c - min_c) * scale, 4),
                 "y": round(off_y + (r - min_r) * scale, 4)} for r, c in points]

    return {
        "letterId": letter_id,
        "char": char,
        "note": (
            "Medial-axis arcs of the '" + char + "' glyph from the app's bundled font, "
            "indexed exactly as tools/glyph_skeleton.py prints and colours them. This is "
            "geometry only: an arc list is undirected and unordered, and a font holds no "
            "notion of which part is written first. The authoring screen exists to supply "
            "that order, and emits it as a tools/orders.json entry naming these indices."
        ),
        "arcs": [{"index": i, "points": normalize(arc)} for i, arc in enumerate(arcs)],
        "tubeWidthFactor": round(skel.stroke_width * scale, 4),
        "componentCount": _component_count(skel),
    }


def _component_count(skel: gs.GlyphSkeleton) -> int:
    """Disconnected pieces of the glyph — a floor on how many pen lifts it needs."""
    import networkx as nx

    return nx.number_connected_components(skel.graph)


if __name__ == "__main__":
    wanted = sys.argv[1:]
    roster = LETTERS + uyirmei_to_author()
    targets = [(i, c) for i, c in roster if not wanted or i in wanted
               or any(i.startswith(w) for w in wanted)]
    if not targets:
        sys.exit(f"no letters matched {wanted}; known ids: {[i for i, _ in LETTERS]}")

    os.makedirs(OUT_DIR, exist_ok=True)
    for letter_id, char in targets:
        data = build_skeleton_data(letter_id, char)
        path = f"{OUT_DIR}/{letter_id}.json"
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
        print(f"{letter_id} {char}  arcs={len(data['arcs']):2d}  "
              f"components={data['componentCount']}  tube={data['tubeWidthFactor']}")

    # The app has no way to list a directory at runtime, so the roster is a file.
    index = [{"letterId": i, "char": c} for i, c in roster]
    with open(f"{OUT_DIR}/index.json", "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=2, ensure_ascii=False)
    print(f"wrote {OUT_DIR}/index.json ({len(index)} letters)")
