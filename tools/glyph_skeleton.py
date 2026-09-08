"""Turn a bundled-font Tamil glyph into a traceable skeleton graph.

The tracing canvas draws each letter as a constant-width tube swept along a
centreline, so every letter needs that centreline in writing order. The shape
must come from the very font the app renders (assets/fonts), or the letter the
child traces will not match the letter they read.

This module does the geometry half:

    glyph -> raster -> medial axis -> pruned skeleton -> graph of edges

It deliberately stops before deciding *order*. A skeleton is an undirected
graph; which edge is drawn first, and in which direction, is a handwriting
fact that no font contains. `emit_strokes` takes that order as an explicit
argument, so it can be supplied per letter from a stroke-order reference.

Run directly to dump a labelled diagram of a glyph's skeleton:

    python tools/glyph_skeleton.py அ
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass, field

import networkx as nx
import numpy as np
import freetype
import uharfbuzz as hb
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from skimage.morphology import skeletonize

FONT_PATH = "assets/fonts/NotoSansTamil-Regular.ttf"
FONT_SIZE = 720
# Blank space kept around the glyph. The distance transform and the rounded
# ends of a stroke both need room; without it the skeleton bends along the
# edge of the image instead of the letter.
RASTER_MARGIN = 120
# Spurs shorter than this fraction of the stroke width are rasterisation
# artefacts at stroke ends, not real branches.
SPUR_FACTOR = 1.0
# How far an arc must turn, over a stroke-width-scaled window, to count as a
# corner rather than a curve. Tamil letters are mostly curves; the corners
# that matter are the near-square ones in ஈ, எ, ஏ and their relatives.
CORNER_DEGREES = 55


@dataclass
class GlyphSkeleton:
    """A glyph's medial axis as a graph, plus the metrics needed to scale it."""

    graph: nx.Graph
    """Nodes are (row, col) pixels; every node is a junction or an endpoint."""

    edges: dict[tuple, list[tuple[float, float]]]
    """Edge key -> the ordered pixel chain joining its two endpoints."""

    stroke_width: float
    """Median stroke width of the glyph, in raster pixels."""

    bounds: tuple[int, int, int, int]
    """(min_row, min_col, max_row, max_col) of the inked glyph."""

    dot_keys: frozenset = frozenset()
    """Keys of the arcs `_dot_arcs` invented for filled dots.

    They are segments only so that a finger has something to follow on the
    authoring screen. What the dot actually is, is a point — see
    `dot_arc_indices`, which is how `trace_letter.py` knows to ship one.
    """

    dot_diameters: dict = field(default_factory=dict)
    """Dot arc key -> the dot's own diameter in pixels.

    A puḷḷi is not drawn at the letter's stroke width: it is 95px across on
    every mei letter where the stroke is 54-62px, so 1.5x to 1.8x wider. Drawn
    at the tube width it comes out visibly too small, which is what a shipped
    dot has to carry its own size for.
    """


def rasterize(char: str, font_path: str = FONT_PATH) -> np.ndarray:
    """Draw the glyph large, shaped exactly as the app renders it.

    **Shaped, not stacked.** Tamil is a complex script and the letters here
    are more than one code point: க் is க + U+0BCD. Pillow without libraqm has
    no shaper, so it laid those out by advance width — draw க, step forward,
    drop a standalone puḷḷi. The font does not work that way. Noto Sans Tamil
    carries a *precomposed* glyph for க் (gid 77, where bare க is gid 18), and
    asking HarfBuzz for it returns that one glyph. The stacked version put
    every mei letter's dot up to a third of the letter's width right of where
    the designer placed it; shaped, it lands dead centre.

    This matters far more for uyirmei than it did for mei: கு is a single
    fused glyph too, and கெ *reorders* — the vowel sign is emitted before the
    consonant. No amount of advance-width stacking produces either.

    Sized to the glyph rather than to a fixed square. ஔ is wider than it is
    tall by nearly two to one, and a square big enough to hold it vertically
    clipped its left edge clean off — arcs ran to column 0 and part of the
    letter simply was not in the skeleton. Everything downstream is scaled by
    the glyph's own bounding box, so the canvas size affects nothing else,
    while the font size — which sets the stroke width every threshold here is
    measured against — stays fixed.
    """
    spans = _shaped_glyphs(char, font_path)
    if not spans:
        raise ValueError(f"{char!r} shaped to nothing")

    left = min(x for _, x, _ in spans)
    top = min(y for _, _, y in spans)
    width = int(round(max(x + bitmap.shape[1] for bitmap, x, _ in spans) - left))
    height = int(round(max(y + bitmap.shape[0] for bitmap, _, y in spans) - top))

    canvas = np.zeros((height + 2 * RASTER_MARGIN, width + 2 * RASTER_MARGIN), np.uint8)
    for bitmap, x, y in spans:
        if bitmap.size == 0:
            continue
        r = int(round(y - top)) + RASTER_MARGIN
        c = int(round(x - left)) + RASTER_MARGIN
        target = canvas[r:r + bitmap.shape[0], c:c + bitmap.shape[1]]
        # Marks and bases can overlap, so take the darker of the two.
        np.maximum(target, bitmap, out=target)
    return canvas > 128


def _shaped_glyphs(char: str, font_path: str = FONT_PATH):
    """(bitmap, x, y) for every glyph HarfBuzz says this string is made of.

    HarfBuzz decides *which* glyphs and where; FreeType draws them. Pillow is
    not used for text here at all — it has no shaper in this environment
    (`PIL.features.check('raqm')` is False), which is the whole problem.
    """
    blob = hb.Blob.from_file_path(font_path)
    hb_font = hb.Font(hb.Face(blob))
    hb_font.scale = (FONT_SIZE * 64, FONT_SIZE * 64)
    buffer = hb.Buffer()
    buffer.add_str(char)
    buffer.guess_segment_properties()
    hb.shape(hb_font, buffer)

    face = freetype.Face(font_path)
    face.set_pixel_sizes(0, FONT_SIZE)

    spans = []
    pen = 0
    for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
        face.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
        bitmap = face.glyph.bitmap
        pixels = (
            np.array(bitmap.buffer, dtype=np.uint8)
            .reshape(bitmap.rows, bitmap.pitch)[:, : bitmap.width]
            if bitmap.rows
            else np.zeros((0, 0), np.uint8)
        )
        spans.append((
            pixels,
            (pen + position.x_offset) / 64.0 + face.glyph.bitmap_left,
            (-position.y_offset) / 64.0 - face.glyph.bitmap_top,
        ))
        pen += position.x_advance
    return spans


def _neighbours(point, points: set):
    r, c = point
    return [
        (r + dr, c + dc)
        for dr in (-1, 0, 1)
        for dc in (-1, 0, 1)
        if (dr or dc) and (r + dr, c + dc) in points
    ]


def _prune_spurs(skeleton: np.ndarray, max_length: float) -> np.ndarray:
    """Repeatedly trim dead-end twigs shorter than `max_length`.

    Rasterising a glyph rounds its stroke ends, and the medial axis of a
    rounded end sprouts a short twig. Left in place these become phantom
    branches that derail any traversal.
    """
    skeleton = skeleton.copy()
    while True:
        points = set(map(tuple, np.argwhere(skeleton)))
        degree = {p: len(_neighbours(p, points)) for p in points}
        removed = False
        for endpoint in [p for p, d in degree.items() if d == 1]:
            twig = [endpoint]
            current, previous = endpoint, None
            while True:
                nxts = [n for n in _neighbours(current, points) if n != previous]
                if len(nxts) != 1:
                    break
                previous, current = current, nxts[0]
                if len(_neighbours(current, points)) > 2:
                    break
                twig.append(current)
                if len(twig) > max_length:
                    break
            if len(twig) <= max_length and len(twig) < len(points):
                for p in twig:
                    skeleton[p] = False
                removed = True
        if not removed:
            return skeleton


def _junction_representatives(pixels: nx.Graph) -> dict[tuple, tuple]:
    """Map every junction/endpoint pixel to one representative per clump.

    Junctions rasterise as a small blob of touching high-degree pixels; each
    blob is one conceptual node, so they all collapse onto a single member.
    """
    special = [n for n in pixels if pixels.degree(n) != 2]
    clumps = nx.Graph()
    clumps.add_nodes_from(special)
    special_set = set(special)
    for p in special:
        for q in _neighbours(p, special_set):
            clumps.add_edge(p, q)
    mapping: dict[tuple, tuple] = {}
    for clump in nx.connected_components(clumps):
        # Prefer the busiest pixel in the clump as its representative.
        rep = max(clump, key=lambda n: (pixels.degree(n), -n[0], -n[1]))
        for member in clump:
            mapping[member] = rep
    return mapping


def build(char: str, font_path: str = FONT_PATH) -> GlyphSkeleton:
    mask = rasterize(char, font_path)
    distance = ndimage.distance_transform_edt(mask)
    raw = skeletonize(mask)
    stroke_width = float(2 * np.median(distance[raw]))

    skeleton = _prune_spurs(raw, stroke_width * SPUR_FACTOR)
    points = set(map(tuple, np.argwhere(skeleton)))

    pixels = nx.Graph()
    for p in points:
        for q in _neighbours(p, points):
            pixels.add_edge(p, q, weight=math.dist(p, q))

    # A single conceptual junction shows up as a little clump of adjacent
    # high-degree pixels. Collapse each clump to one representative, otherwise
    # the contraction below emits a shower of 2px edges between them.
    representative = _junction_representatives(pixels)

    # A component that is one closed loop — a dot, or a ring — has no pixel of
    # degree other than 2, so it offers nothing to seed the walk from and would
    # be dropped in silence. ஃ is three such dots, and only one of them used to
    # survive. Seed every loop component, not just the first.
    for component in nx.connected_components(pixels):
        if not any(p in representative for p in component):
            seed = min(component)
            representative[seed] = seed

    graph = nx.Graph()
    edges: dict[tuple, list[tuple[float, float]]] = {}
    walked = set()
    # Walk out of every clump *member*, not just the representative. A branch
    # usually leaves the clump from some other pixel — at ஆ's T-junction the
    # representative only faces west, and the bar continuing up and down hangs
    # off two of its neighbours. Starting at representatives alone loses any
    # such branch whose far end is also a clump, which broke ஆ's vertical bar.
    for member in sorted(representative):
        rep = representative[member]
        for first in pixels.neighbors(member):
            if (member, first) in walked or first in representative:
                continue
            chain = [member, first]
            walked.add((member, first))
            previous, current = member, first
            # Run along the arc until we arrive at the next junction clump.
            while current not in representative:
                options = [n for n in pixels.neighbors(current) if n != previous]
                if not options:
                    break
                nxt = options[0]
                walked.add((current, nxt))
                walked.add((nxt, current))
                previous, current = current, nxt
                chain.append(current)
            # Arcs must meet at their node, so pull both loose ends onto the
            # representative — the clump is only a few pixels across. Both
            # ends matter: a walk starts at some member of the clump it left
            # and stops at some member of the clump it reached, and neither
            # is necessarily the pixel the graph calls the node. Leaving the
            # far end short put 4-8px holes between arcs that are supposed to
            # touch, and made the arc graph look disconnected.
            a = rep
            b = representative.get(chain[-1], chain[-1])
            if chain[0] != a:
                chain.insert(0, a)
            if chain[-1] != b:
                chain.append(b)
            # A walk that leaves a clump and steps straight back into it is a
            # stub of the clump, not an arc. A genuine loop has to enclose
            # area, so it is far longer than the stroke is wide.
            if a == b and len(chain) < stroke_width:
                continue
            edges[(a, b, len(chain))] = chain

    dots, dot_diameters = _dot_arcs(mask, edges, stroke_width)
    edges.update(dots)

    # Corners become nodes too, so a stroke may begin or end at one.
    # A two-point dot arc is far too short to hold a corner, so it comes
    # through with its key intact and stays findable.
    edges = _split_at_corners(edges, stroke_width)
    graph = nx.Graph()
    for (a, b, length) in edges:
        graph.add_edge(a, b, length=length, key=(a, b, length))

    inked = np.argwhere(mask)
    return GlyphSkeleton(
        graph=graph,
        edges={k: [(float(r), float(c)) for r, c in chain] for k, chain in edges.items()},
        stroke_width=stroke_width,
        bounds=(inked[:, 0].min(), inked[:, 1].min(), inked[:, 0].max(), inked[:, 1].max()),
        dot_keys=frozenset(dots),
        dot_diameters=dot_diameters,
    )


def _dot_arcs(mask: np.ndarray, edges: dict, stroke_width: float) -> dict:
    """An arc for every inked piece the skeleton left with nothing.

    The medial axis of a filled disc is a single point. `skeletonize` renders
    that as a pixel or two, and `_prune_spurs` then clears it away as a stray
    twig — so ஈ's two dots were absent from the graph entirely and the letter
    came out without them.

    A point cannot be traced or authored against, so each dot becomes a short
    segment through its centre instead, shortened by the stroke width. Drawn
    as a tube with round caps that is the dot, and it is long enough for a
    finger to follow. Emitted last and only two points long, so these sort to
    the end of the arc list and no existing arc index moves.
    """
    labels, count = ndimage.label(mask)
    if count < 2:
        return {}, {}
    inked = {labels[int(r), int(c)] for chain in edges.values() for r, c in chain}

    dots: dict[tuple, list] = {}
    diameters: dict[tuple, float] = {}
    for label in range(1, count + 1):
        if label in inked:
            continue
        rows, cols = np.where(labels == label)
        top, bottom, left, right = rows.min(), rows.max(), cols.min(), cols.max()
        centre_row, centre_col = (top + bottom) / 2, (left + right) / 2
        half = max(1.0, (max(bottom - top, right - left) - stroke_width) / 2)
        if (right - left) >= (bottom - top):
            chain = [(centre_row, centre_col - half), (centre_row, centre_col + half)]
        else:
            chain = [(centre_row - half, centre_col), (centre_row + half, centre_col)]
        key = (chain[0], chain[-1], len(chain))
        dots[key] = chain
        diameters[key] = float(max(bottom - top, right - left))
    return dots, diameters


def _corner_split_points(chain, window: int, min_segment: int) -> list[int]:
    """Indices where a chain turns a sharp corner.

    A junction is where strokes *meet*; a corner is where one changes
    direction. Both are places a pen starts or stops — ஈ is written as a
    downstroke and a cross-stroke meeting at its top-left, but the medial
    axis just turns there, so without this they are one L-shaped arc and
    neither of those strokes can be named on its own.

    Measured over a window, so the pixel staircase of a rasterised diagonal
    does not read as a corner, and a drawn curve — which turns steadily and
    gently — does not either.
    """
    if len(chain) < 2 * window + 3:
        return []
    scored = []
    for i in range(window, len(chain) - window):
        ay, ax = chain[i][0] - chain[i - window][0], chain[i][1] - chain[i - window][1]
        by, bx = chain[i + window][0] - chain[i][0], chain[i + window][1] - chain[i][1]
        na, nb = math.hypot(ay, ax), math.hypot(by, bx)
        if na == 0 or nb == 0:
            continue
        cosine = (ay * by + ax * bx) / (na * nb)
        scored.append((i, max(-1.0, min(1.0, cosine))))

    limit = math.cos(math.radians(CORNER_DEGREES))
    corners: list[int] = []
    run: list[tuple[int, float]] = []
    for entry in scored + [(-1, 1.0)]:  # sentinel flushes a trailing run
        if entry[1] < limit:
            run.append(entry)
            continue
        if run:
            # The sharpest point of the bend is the corner itself.
            corner = min(run, key=lambda e: e[1])[0]
            if (corner >= min_segment
                    and len(chain) - corner >= min_segment
                    and all(abs(corner - c) >= min_segment for c in corners)):
                corners.append(corner)
            run = []
    return sorted(corners)


def _split_at_corners(edges: dict, stroke_width: float) -> dict:
    window = max(3, round(stroke_width * 0.35))
    min_segment = max(window * 2, round(stroke_width))
    out: dict[tuple, list] = {}
    for (a, b, _), chain in edges.items():
        cuts = _corner_split_points(chain, window, min_segment)
        if not cuts:
            out[(a, b, len(chain))] = chain
            continue
        bounds = [0, *cuts, len(chain) - 1]
        for start, end in zip(bounds, bounds[1:]):
            # Consecutive pieces share the corner pixel, so the arcs still
            # meet exactly and an order across them makes no pen jump.
            piece = chain[start:end + 1]
            key = (tuple(piece[0]), tuple(piece[-1]), len(piece))
            out[key] = piece
    return out


def ordered_edges(skel: GlyphSkeleton):
    """The skeleton's (key, arc) pairs in index order: longest arc first.

    Every consumer must agree on these indices — the diagram labels them, a
    writing order in `trace_letter.ORDERS` names them, and the in-app
    authoring screen reports them back. `build` walks the pixel graph from a
    set, so insertion order is not something to lean on; the edge key breaks
    ties so the order depends only on the glyph.
    """
    return sorted(skel.edges.items(), key=lambda kv: (-len(kv[1]), kv[0]))


def ordered_arcs(skel: GlyphSkeleton) -> list[list[tuple[float, float]]]:
    """Just the arcs from [ordered_edges], indexed the same way."""
    return [chain for _, chain in ordered_edges(skel)]


def dot_arc_indices(skel: GlyphSkeleton) -> set[int]:
    """Which arc indices stand for a filled dot rather than a line.

    A filled dot's medial axis is a single point, so `_dot_arcs` gives it a
    short segment instead — otherwise there is nothing on the authoring
    canvas for a finger to follow, and nothing to name in an order. That
    segment is scaffolding, not the letter: stroked with round caps it comes
    out about 1.7 times wider than it is tall, which is a little bar and not
    a dot. `trace_letter.py` uses this to collapse it back to the point it
    always was before the stroke data ships.
    """
    return {i for i, (key, _) in enumerate(ordered_edges(skel)) if key in skel.dot_keys}


def dot_arc_diameters(skel: GlyphSkeleton) -> dict[int, float]:
    """Arc index -> that dot's diameter in pixels. See [dot_diameters]."""
    return {
        i: skel.dot_diameters[key]
        for i, (key, _) in enumerate(ordered_edges(skel))
        if key in skel.dot_diameters
    }


def diagram(char: str, skel: GlyphSkeleton, out_path: str) -> None:
    """Save a labelled picture of the skeleton, for choosing a traversal."""
    mask = rasterize(char)
    img = Image.new("RGB", (mask.shape[1], mask.shape[0]), "white")
    px = img.load()
    for r, c in np.argwhere(mask):
        px[c, r] = (232, 232, 232)
    draw = ImageDraw.Draw(img)
    palette = [(200, 0, 0), (0, 140, 0), (0, 80, 220), (200, 120, 0), (160, 0, 160), (0, 150, 150)]
    for i, (key, chain) in enumerate(ordered_edges(skel)):
        colour = palette[i % len(palette)]
        for (r0, c0), (r1, c1) in zip(chain, chain[1:]):
            draw.line([(c0, r0), (c1, r1)], fill=colour, width=5)
        mid = chain[len(chain) // 2]
        draw.ellipse([mid[1] - 20, mid[0] - 20, mid[1] + 20, mid[0] + 20], fill=colour)
        draw.text((mid[1] - 5, mid[0] - 7), str(i), fill="white")
    for node in skel.graph.nodes:
        draw.ellipse([node[1] - 9, node[0] - 9, node[1] + 9, node[0] + 9], outline=(0, 0, 0), width=4)
        draw.text((node[1] + 12, node[0] - 8), f"{node[0]},{node[1]}", fill=(0, 0, 0))
    img.save(out_path)


if __name__ == "__main__":
    char = sys.argv[1] if len(sys.argv) > 1 else "அ"
    out = sys.argv[2] if len(sys.argv) > 2 else "glyph_skeleton.png"
    skel = build(char)
    print(f"char           : {char}")
    print(f"stroke width   : {skel.stroke_width:.1f}px")
    print(f"bounds         : {skel.bounds}")
    print(f"skeleton nodes : {skel.graph.number_of_nodes()}")
    print(f"skeleton edges : {len(skel.edges)}")
    for i, (key, chain) in enumerate(ordered_edges(skel)):
        print(f"  [{i}] {key[0]} -> {key[1]}   {len(chain)}px")
    diagram(char, skel, out)
    print(f"wrote {out}")
