"""Emit a letter's stroke JSON from the bundled font plus a writing order.

`glyph_skeleton` gives the geometry (an undirected graph of arcs). This adds
the half a font cannot supply: which arc is drawn first and in which
direction. That order is stated per letter as a list of skeleton edge
indices — the same indices `glyph_skeleton.py` prints and colours in its
diagram, so a spec can be checked against the picture by eye.

Orders come from two places, and `tools/orders.json` wins where both have a
letter:

  * ORDERS below, hand-written from a stroke-order reference.
  * tools/orders.json, exported by the in-app authoring screen — someone
    draws the letter over the font's own geometry and the app reports which
    arcs the finger crossed, in what order.

    python tools/trace_letter.py uyir_01

writes lib/data/letters/strokes/<id>.json and a verification image.
"""

from __future__ import annotations

import json
import math
import os
import sys

import networkx as nx

from PIL import Image, ImageDraw

import glyph_skeleton as gs

MARGIN = 0.06
AUTHORED_PATH = "tools/orders.json"
# An arc is a loop when its two ends meet, and "meet" has to be judged
# against the arc's own length rather than any absolute distance: a loop is
# long and comes back to where it began, while a short connector's ends are
# close together simply because it is short. அ's arc 6 is a 22px straight
# line whose ends are 23px apart, and an absolute tolerance called it a loop.
CLOSED_ARC_RATIO = 0.15
# ...and its ends have to actually meet, not merely be nearer to each other
# than the arc is long. ஆ's bottom curl is 997px with its ends 133px apart —
# 13% of its length, so the ratio alone called it a loop, and `rotate_ring`
# then closed it by drawing a 133px segment the font does not contain, joining
# the curl to the vertical bar. Measured across every letter, a real loop's
# ends sit on the *same* node and the gap is exactly 0; the largest genuine
# one is 0.38 stroke widths. Half a stroke width separates them cleanly.
CLOSED_ARC_MAX_GAP_FACTOR = 0.5

# id -> (character, [stroke, ...]) where each stroke is a list of
# (edge_index, reversed) pairs. Edge indices are those printed by
# glyph_skeleton.py, ordered longest arc first.
ORDERS: dict[str, tuple[str, list[list[tuple[int, bool]]]]] = {
    # அ: the body is one continuous stroke — round the top loop, down its
    # right side, round the bowl and back along the centre line, then out to
    # the bar. The bar is a separate stroke, drawn top to bottom.
    #
    # Arc 3 runs top-to-middle as stored, so it is written forwards. It used
    # to say (3, True), which wrote the bar middle-to-top and then doubled
    # back down through the middle to reach arc 4 — the upper half traced
    # twice. Invisible in the verify image, because the return leg lies on
    # top of the bar; the authoring screen's join check is what caught it.
    "uyir_01": (
        "அ",
        [
            [(1, True), (2, False), (6, False), (0, True), (6, True), (5, False)],
            [(3, False), (4, False)],
        ],
    ),
    # உ: one unbroken stroke — spiral out of the inner curl, then sweep down
    # and away along the tail.
    "uyir_05": (
        "உ",
        [
            [(1, True), (0, True)],
        ],
    ),
}


def load_orders(path: str = AUTHORED_PATH) -> dict:
    """ORDERS with anything authored in the app layered on top.

    The app writes `{"uyir_02": {"char": "ஆ", "strokes": [[[3, false], ...]]}}`
    — arc indices and a direction flag, the same thing ORDERS holds, just in
    a form that does not involve editing Python on a phone.
    """
    orders = dict(ORDERS)
    if not os.path.exists(path):
        return orders
    with open(path, encoding="utf-8") as fh:
        authored = json.load(fh)
    for letter_id, entry in authored.items():
        orders[letter_id] = (
            entry["char"],
            [[(int(i), bool(r)) for i, r in stroke] for stroke in entry["strokes"]],
        )
    return orders


def arc_length(chain) -> float:
    return sum(math.dist(a, b) for a, b in zip(chain, chain[1:]))


def is_closed(chain, ratio: float = CLOSED_ARC_RATIO, max_gap: float | None = None) -> bool:
    """Whether an arc loops back on itself.

    Both tests have to pass. The ratio keeps a *short* connector from counting
    (அ's arc 6 is 22px long with its ends 23px apart), and `max_gap` keeps a
    *long* open curve from counting (ஆ's arc 1 is 997px with its ends 133px
    apart). See CLOSED_ARC_RATIO and CLOSED_ARC_MAX_GAP_FACTOR.
    """
    if len(chain) < 3:
        return False
    length = arc_length(chain)
    if length <= 0:
        return False
    gap = math.dist(chain[0], chain[-1])
    if max_gap is not None and gap > max_gap:
        return False
    return gap <= length * ratio


def rotate_ring(chain, pen):
    """Re-start a closed arc at whichever of its points is nearest the pen.

    A loop has no inherent beginning — the pen joins it wherever it arrives
    and comes back round to the same place. Pinning it to the stored first
    point instead leaves a gap of however far that point happens to be, which
    is what put a 23px hole in ஆ. Direction is untouched.
    """
    ring = chain[:-1] if math.dist(chain[0], chain[-1]) < 1e-9 else list(chain)
    if len(ring) < 2:
        return list(chain)
    start = min(range(len(ring)), key=lambda i: math.dist(pen, ring[i]))
    return ring[start:] + ring[:start] + [ring[start]]


def dot_centre(chains, spec: list[tuple[int, bool]]) -> tuple[float, float]:
    """The middle of a stroke that is nothing but a dot.

    A puḷḷi, or either of ஈ's two marks, is a filled disc: its medial axis is
    one point, and the segment the skeleton carries in its place exists only
    so a finger has something to follow while the order is being authored.
    Shipping that segment draws a small bar — a tube as long as the segment
    plus a round cap at each end, about 1.7x wider than tall. A single point
    stroked with the same round cap is the dot itself, and the app completes
    it on a touch rather than asking a child to drag across it.
    """
    points = [p for index, _ in spec for p in chains[index]]
    return (
        sum(p[0] for p in points) / len(points),
        sum(p[1] for p in points) / len(points),
    )


def build_stroke(chains, spec: list[tuple[int, bool]], max_gap: float | None = None) -> list[tuple[float, float]]:
    """Concatenate the chosen arcs into one pen path."""
    path: list[tuple[float, float]] = []
    for index, reverse in spec:
        chain = list(chains[index])
        if reverse:
            chain = chain[::-1]
        # A loop begins and ends in the same place, so "which end is nearer
        # the pen" is decided by a pixel or two of rounding — a coin toss
        # that would silently overrule the direction the arc was written in.
        # ஓ's bottom circle came out backwards on a 2px margin.
        if path and is_closed(chain, max_gap=max_gap):
            chain = rotate_ring(chain, path[-1])
        elif path and math.dist(path[-1], chain[0]) > math.dist(path[-1], chain[-1]):
            # Whichever end is nearer the pen is where this arc really starts.
            chain = chain[::-1]
        if path and math.dist(path[-1], chain[0]) < 1e-6:
            chain = chain[1:]
        path.extend(chain)
    return path


def resample(points: list[tuple[float, float]], spacing: float) -> list[tuple[float, float]]:
    """Even out point density so later arc-length maths behaves."""
    if len(points) < 2:
        return points
    out = [points[0]]
    carry = 0.0
    for a, b in zip(points, points[1:]):
        segment = math.dist(a, b)
        if segment == 0:
            continue
        travelled = spacing - carry
        while travelled <= segment:
            t = travelled / segment
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            travelled += spacing
        carry = (carry + segment) % spacing
    if math.dist(out[-1], points[-1]) > spacing * 0.25:
        out.append(points[-1])
    return out


def smooth(points: list[tuple[float, float]], window: int = 7) -> list[tuple[float, float]]:
    """Take the staircase off the raster-derived centreline."""
    if len(points) < window:
        return points
    out = []
    for i in range(len(points)):
        lo, hi = max(0, i - window // 2), min(len(points), i + window // 2 + 1)
        chunk = points[lo:hi]
        out.append((sum(p[0] for p in chunk) / len(chunk), sum(p[1] for p in chunk) / len(chunk)))
    # Keep the true endpoints; averaging pulls them inward.
    out[0], out[-1] = points[0], points[-1]
    return out


def trace(letter_id: str, repair: bool = True):
    orders = load_orders()
    if letter_id not in orders:
        raise KeyError(
            f"no writing order for {letter_id}. Author one on the app's "
            f"authoring screen and paste it into {AUTHORED_PATH}, or add it "
            "to ORDERS here. Known: " + ", ".join(sorted(orders))
        )
    char, specs = orders[letter_id]
    skel = gs.build(char)
    chains = gs.ordered_arcs(skel)

    if repair:
        specs, notes = repair_gaps(skel, chains, specs, 3.0)
        for note in notes:
            print(f"  repaired: {note}")

    dots = gs.dot_arc_indices(skel)
    diameters = gs.dot_arc_diameters(skel)
    max_gap = skel.stroke_width * CLOSED_ARC_MAX_GAP_FACTOR
    strokes = []
    # Stroke index -> that dot's diameter in pixels, for the strokes that are
    # dots. A puḷḷi is 1.5x-1.8x the letter's stroke width, so drawing it at
    # the tube width leaves it visibly small.
    stroke_widths: dict[int, float] = {}
    for spec in specs:
        if spec and all(index in dots for index, _ in spec):
            stroke_widths[len(strokes)] = max(diameters[index] for index, _ in spec)
            strokes.append([dot_centre(chains, spec)])
        else:
            strokes.append(
                smooth(resample(build_stroke(chains, spec, max_gap), skel.stroke_width * 0.18))
            )

    every = [p for s in strokes for p in s]
    min_r = min(p[0] for p in every)
    max_r = max(p[0] for p in every)
    min_c = min(p[1] for p in every)
    max_c = max(p[1] for p in every)
    width, height = max_c - min_c, max_r - min_r
    scale = (1 - 2 * MARGIN) / max(width, height)
    off_x = (1 - width * scale) / 2
    off_y = (1 - height * scale) / 2

    def normalize(points):
        return [{"x": round(off_x + (c - min_c) * scale, 4),
                 "y": round(off_y + (r - min_r) * scale, 4)} for r, c in points]

    data = {
        "letterId": letter_id,
        "note": (
            f"Centreline of the '{char}' glyph from the app's own bundled font "
            "(assets/fonts/NotoSansTamil-Regular.ttf), so the traced letter matches the "
            "printed letter exactly. Geometry is the pruned medial axis of the rasterised "
            "glyph; the writing order and direction come from tools/trace_letter.py or "
            "tools/orders.json, because a font contains no notion of which part is drawn "
            "first. Both axes share one scale, preserving true proportions."
        ),
        "strokes": [
            {
                "index": i,
                "points": normalize(s),
                # Only a dot carries its own width; everything else is the
                # letter's one tube width.
                **({"width": round(stroke_widths[i] * scale, 4)} if i in stroke_widths else {}),
            }
            for i, s in enumerate(strokes)
        ],
        "tubeWidthFactor": round(skel.stroke_width * scale, 4),
    }
    return char, skel, strokes, data, specs


def repair_gaps(skel, chains, specs, tolerance_px: float):
    max_gap = skel.stroke_width * CLOSED_ARC_MAX_GAP_FACTOR
    """Fill in short connectors the finger swung too wide to touch.

    A gap between consecutive arcs is never legitimate — arcs that meet share
    a pixel. It means the pen was recorded leaving one arc and arriving on
    another it could not have reached without crossing something in between,
    and what it crossed is whatever the skeleton says lies between them.

    This is not inventing an order. The two ends were both drawn; only the
    join between them was missed, and the skeleton has exactly one shortest
    way across. Where it has more than one, nothing is guessed — the gap is
    left in place and reported, so a person decides.

    Returns (repaired_specs, notes).
    """
    graph = nx.MultiGraph()
    for index, chain in enumerate(chains):
        a, b = tuple(chain[0]), tuple(chain[-1])
        graph.add_edge(a, b, key=index, weight=len(chain))

    nodes = list(graph.nodes)

    def nearest_node(point):
        return min(nodes, key=lambda n: math.dist(point, n))

    repaired, notes = [], []
    for s, spec in enumerate(specs):
        out = []
        path: list[tuple[float, float]] = []
        for i, (index, reverse) in enumerate(spec):
            chain = list(chains[index])
            if reverse:
                chain = chain[::-1]
            if path:
                if is_closed(chain, max_gap=max_gap):
                    chain = rotate_ring(chain, path[-1])
                    gap = math.dist(path[-1], chain[0])
                else:
                    gap = min(math.dist(path[-1], chain[0]), math.dist(path[-1], chain[-1]))
                    if math.dist(path[-1], chain[0]) > math.dist(path[-1], chain[-1]):
                        chain = chain[::-1]
                if gap > tolerance_px:
                    bridge = _bridge(graph, nearest_node(path[-1]), nearest_node(chain[0]))
                    if bridge is None:
                        notes.append(f"stroke {s} step {i}: {gap:.0f}px gap into arc "
                                     f"{index} left alone — no single way across")
                    else:
                        for arc_index in bridge:
                            out.append((arc_index, False))
                            path.extend(chains[arc_index])
                        notes.append(f"stroke {s} step {i}: {gap:.0f}px gap into arc "
                                     f"{index} bridged by arc(s) "
                                     f"{', '.join(str(b) for b in bridge)}")
            out.append((index, reverse))
            path.extend(chain)
        repaired.append(out)
    return repaired, notes


def _bridge(graph, start, end):
    """Arc indices forming the one short way from `start` to `end`, or None."""
    if start == end:
        return []
    try:
        route = nx.shortest_path(graph, start, end, weight="weight")
    except (nx.NetworkXNoPath, nx.NodeNotFound):
        return None
    arcs = []
    for a, b in zip(route, route[1:]):
        # Parallel arcs between the same two nodes are genuinely ambiguous.
        options = graph[a][b]
        if len(options) != 1:
            return None
        arcs.append(next(iter(options)))
    return arcs


def pen_jumps(chains, specs, tolerance_px: float, max_gap: float | None = None):
    """Where a spec would make the pen leap from one arc to the next.

    Arcs that meet share their junction pixel, so consecutive arcs of one
    stroke land on each other. A gap means the order skips a piece of the
    letter. Worth shouting about, because `resample` fills the leap with
    evenly spaced points afterwards and the verify image then looks fine —
    that is exactly how அ shipped with its bar traced twice over.
    """
    jumps = []
    for s, spec in enumerate(specs):
        path: list[tuple[float, float]] = []
        for i, (index, reverse) in enumerate(spec):
            chain = list(chains[index])
            if reverse:
                chain = chain[::-1]
            if path:
                if is_closed(chain, max_gap=max_gap):
                    chain = rotate_ring(chain, path[-1])
                    gap = math.dist(path[-1], chain[0])
                else:
                    gap = min(math.dist(path[-1], chain[0]), math.dist(path[-1], chain[-1]))
                    if math.dist(path[-1], chain[0]) > math.dist(path[-1], chain[-1]):
                        chain = chain[::-1]
                if gap > tolerance_px:
                    jumps.append((s, i, index, gap))
            path.extend(chain)
    return jumps


def verify_image(char: str, strokes, out_path: str):
    """Draw the emitted tube over the real glyph; they should coincide."""
    mask = gs.rasterize(char)
    img = Image.new("RGB", (mask.shape[1], mask.shape[0]), "white")
    px = img.load()
    for r, c in zip(*mask.nonzero()):
        px[c, r] = (222, 222, 222)
    draw = ImageDraw.Draw(img)
    for i, stroke in enumerate(strokes):
        colour = (200, 0, 0) if i == 0 else (0, 90, 220)
        for a, b in zip(stroke, stroke[1:]):
            draw.line([(a[1], a[0]), (b[1], b[0])], fill=colour, width=6)
        for j in range(0, len(stroke), max(1, len(stroke) // 26)):
            r, c = stroke[j]
            draw.ellipse([c - 7, r - 7, c + 7, r + 7], fill=colour)
        sr, sc = stroke[0]
        er, ec = stroke[-1]
        draw.ellipse([sc - 20, sr - 20, sc + 20, sr + 20], fill=(255, 210, 0))
        draw.ellipse([ec - 20, er - 20, ec + 20, er + 20], fill=(230, 0, 230))
    img.save(out_path)


if __name__ == "__main__":
    letter_id = sys.argv[1] if len(sys.argv) > 1 else "uyir_01"
    char, skel, strokes, data, specs = trace(letter_id)
    out_json = f"lib/data/letters/strokes/{letter_id}.json"
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print(f"strokes      : {[len(s) for s in strokes]}")
    print(f"tube width   : {data['tubeWidthFactor']}")
    print(f"wrote        : {out_json}")

    # Arcs that meet share a pixel, so anything above rounding is a skip.
    # Checked against the spec as emitted, repairs included.
    jumps = pen_jumps(gs.ordered_arcs(skel), specs, tolerance_px=3.0,
                      max_gap=skel.stroke_width * CLOSED_ARC_MAX_GAP_FACTOR)
    for s, i, index, gap in jumps:
        print(f"  WARNING: stroke {s} jumps {gap:.0f}px into arc {index} "
              f"(step {i}) — the order skips a piece of the letter")

    if len(sys.argv) > 2:
        verify_image(char, strokes, sys.argv[2])
        print(f"wrote        : {sys.argv[2]}")
