"""Emit stroke JSON for a letter: font geometry, animation order.

Neither source is sufficient alone. The app's font has the exact shape the
child will read but no notion of which part is written first; the UPenn
animation knows the writing order but is a low-resolution handwriting form.
This pairs them — every arc of the font's medial axis is stamped with the
moment the animation drew that part of the letter, and the arcs are then
walked in that order.

    python tools/auto_trace.py uyir_01 அ <gif> [verify.png]
"""

from __future__ import annotations

import json
import math
import sys

import numpy as np
from scipy.spatial import cKDTree

import glyph_skeleton as gs
import trace_letter as tl
import upenn_order as uo


def _unit(points, bounds):
    """Scale pixel coordinates into a 0..1 box using the ink's bounds."""
    min_r, min_c, max_r, max_c = bounds
    height = max(max_r - min_r, 1)
    width = max(max_c - min_c, 1)
    return [((r - min_r) / height, (c - min_c) / width) for r, c in points]


def derive_spec(char: str, gif_path: str):
    """Work out, for the font's skeleton, which arc is drawn when."""
    skel = gs.build(char)
    # Keep each arc's graph-node ids alongside its pixels: a chain's last
    # pixel can be a junction-clump member rather than the node the graph
    # actually joined, and comparing pixels would make nothing look adjacent.
    ranked = sorted(skel.edges.items(), key=lambda kv: -len(kv[1]))
    chains = [chain for _, chain in ranked]
    nodes = [(key[0], key[1]) for key, _ in ranked]

    strokes = uo.ordered_strokes(gif_path)
    if not strokes:
        raise ValueError(f"no strokes recovered from {gif_path}")

    every = [p for s in strokes for p in s]
    rows = [p[0] for p in every]
    cols = [p[1] for p in every]
    animation_bounds = (min(rows), min(cols), max(rows), max(cols))

    # One flat timeline of the animation, remembering which stroke each
    # sample belonged to and how far through the writing it happened.
    timeline, stroke_of = [], []
    for stroke_index, stroke in enumerate(strokes):
        for point in _unit(stroke, animation_bounds):
            timeline.append(point)
            stroke_of.append(stroke_index)
    # Let the animation drive the assignment rather than the other way
    # round: walk it in time order and hand each moment to the arc it is
    # nearest. An arc's time is then when the pen was actually on it, which
    # survives the two letterforms not matching perfectly.
    edge_samples, edge_of_sample, position_of_sample = [], [], []
    for edge_index, chain in enumerate(chains):
        for position, point in enumerate(_unit(chain, skel.bounds)):
            edge_samples.append(point)
            edge_of_sample.append(edge_index)
            position_of_sample.append(position / max(len(chain) - 1, 1))
    edge_tree = cKDTree(np.array(edge_samples))

    _, nearest_edge_sample = edge_tree.query(np.array(timeline))
    votes: dict[int, list[tuple[float, float, int]]] = {}
    for time_index, sample_index in enumerate(nearest_edge_sample):
        votes.setdefault(edge_of_sample[sample_index], []).append(
            (float(time_index), position_of_sample[sample_index], stroke_of[time_index])
        )

    specs: dict[int, list[tuple[int, float, bool]]] = {}
    for edge_index in range(len(chains)):
        cast = votes.get(edge_index)
        if not cast:
            continue
        times = np.array([v[0] for v in cast])
        positions = np.array([v[1] for v in cast])
        owning_stroke = int(np.bincount([v[2] for v in cast]).argmax())
        # Does the pen move along the arc as stored, or against it?
        forward = np.corrcoef(positions, times)[0, 1] if len(cast) > 2 else 1.0
        if math.isnan(forward):
            forward = 1.0
        specs.setdefault(owning_stroke, []).append(
            (edge_index, float(np.median(times)), forward < 0)
        )

    times = {edge: t for group in specs.values() for edge, t, _ in group}
    reversed_of = {edge: rev for group in specs.values() for edge, _, rev in group}
    ordered = _connected_walk(chains, nodes, times, reversed_of)
    return skel, chains, ordered


def _connected_walk(chains, nodes, times, reversed_of):
    """Order the arcs into walks a pen could actually make.

    Timing each arc independently is noisy, because the font letterform and
    the animation's handwriting form never line up exactly. Requiring the
    result to be a connected walk pins most of that noise down: from where
    the pen is, only the arcs meeting that point are candidates, and the
    earliest-timed one wins. When the next unwritten arc is elsewhere, the
    pen retraces already-written arcs to reach it — which is what a hand
    does — and only lifts if there is no route at all.
    """
    import networkx as nx

    known = [i for i in range(len(chains)) if i in times]
    if not known:
        return []

    graph = nx.MultiGraph()
    for i in known:
        a, b = nodes[i]
        graph.add_edge(a, b, key=i)

    unvisited = set(known)
    strokes: list[list[tuple[int, bool]]] = []

    while unvisited:
        start = min(unvisited, key=lambda i: times[i])
        a, b = nodes[start]
        # Enter the arc from whichever end the animation reached first.
        stroke = [(start, bool(reversed_of.get(start, False)))]
        unvisited.discard(start)
        node = a if reversed_of.get(start, False) else b
        if a == b:
            node = a  # a closed arc leaves the pen where it started

        while True:
            candidates = [i for i in unvisited if node in nodes[i]]
            if candidates:
                nxt = min(candidates, key=lambda i: times[i])
                a2, b2 = nodes[nxt]
                reverse = (b2 == node and a2 != node)
                stroke.append((nxt, reverse))
                unvisited.discard(nxt)
                node = a2 if reverse else b2
                if a2 == b2:
                    node = a2
                continue

            # Nothing adjacent left: can the pen reach any unwritten arc by
            # going back over what it has already written?
            route = _route_to_unvisited(graph, chains, nodes, node, unvisited)
            if route is None:
                break
            for edge_index, reverse, arrive in route:
                stroke.append((edge_index, reverse))
                node = arrive

        strokes.append(stroke)

    return strokes


def _route_to_unvisited(graph, chains, nodes, node, unvisited):
    """Shortest retrace from `node` to any arc still to be written."""
    import networkx as nx

    targets = {n for i in unvisited for n in nodes[i]}
    if not targets:
        return None
    best = None
    for target in targets:
        try:
            path = nx.shortest_path(graph, node, target)
        except (nx.NetworkXNoPath, nx.NodeNotFound):
            continue
        if best is None or len(path) < len(best):
            best = path
    if best is None or len(best) < 2:
        return None
    route = []
    for a, b in zip(best, best[1:]):
        edge_index = min(graph[a][b], key=lambda k: len(chains[k]))
        node_a, node_b = nodes[edge_index]
        route.append((edge_index, node_b == a and node_a != a, b))
    return route


def build(letter_id: str, char: str, gif_path: str):
    skel, chains, specs = derive_spec(char, gif_path)
    strokes = [
        tl.smooth(tl.resample(tl.build_stroke(chains, spec), skel.stroke_width * 0.18))
        for spec in specs
    ]
    strokes = [s for s in strokes if len(s) >= 2]

    every = [p for s in strokes for p in s]
    min_r = min(p[0] for p in every)
    max_r = max(p[0] for p in every)
    min_c = min(p[1] for p in every)
    max_c = max(p[1] for p in every)
    width, height = max_c - min_c, max_r - min_r
    scale = (1 - 2 * tl.MARGIN) / max(width, height)
    off_x = (1 - width * scale) / 2
    off_y = (1 - height * scale) / 2

    def normalize(points):
        return [
            {"x": round(off_x + (c - min_c) * scale, 4), "y": round(off_y + (r - min_r) * scale, 4)}
            for r, c in points
        ]

    data = {
        "letterId": letter_id,
        "note": (
            f"Centreline of the '{char}' glyph from the app's own bundled font "
            "(assets/fonts/NotoSansTamil-Regular.ttf), so the traced letter matches the "
            "printed letter exactly. The writing order and direction come from the "
            "University of Pennsylvania South Asia Center stroke-order animation "
            "(ccat.sas.upenn.edu/plc/tamilweb, cf. Schiffman 1996): its frames are diffed "
            "to recover when each part of the letter was drawn, and the font's medial-axis "
            "arcs are then walked in that same order. Both axes share one scale, preserving "
            "true proportions."
        ),
        "strokes": [{"index": i, "points": normalize(s)} for i, s in enumerate(strokes)],
        "tubeWidthFactor": round(skel.stroke_width * scale, 4),
    }
    return char, strokes, data


if __name__ == "__main__":
    letter_id, char, gif_path = sys.argv[1], sys.argv[2], sys.argv[3]
    char, strokes, data = build(letter_id, char, gif_path)
    out = f"lib/data/letters/strokes/{letter_id}.json"
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print(f"{letter_id}: strokes={[len(s) for s in strokes]} tube={data['tubeWidthFactor']} -> {out}")
    if len(sys.argv) > 4:
        tl.verify_image(char, strokes, sys.argv[4])
