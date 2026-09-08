"""Recover a letter's writing order from the UPenn stroke-order animation.

The animation at ccat.sas.upenn.edu/plc/tamilweb draws each letter a piece at
a time, so diffing consecutive frames recovers what a static glyph cannot:
which part of the letter is drawn first, in which direction, and where the
pen lifts.

The geometry here is only 114x85 pixels and in a handwriting style, so it is
not used for the letter's shape — `glyph_skeleton` takes that from the app's
own font. This module supplies order alone.
"""

from __future__ import annotations

import math

import networkx as nx
import numpy as np
from PIL import Image
from skimage.morphology import dilation, disk, skeletonize

# A new piece starting further than this many stroke widths from where the
# pen stopped means the pen was lifted and a new stroke begun.
PEN_LIFT_FACTOR = 4.0


def _frame_masks(gif_path: str) -> list[np.ndarray]:
    """Ink is whatever is not the white background.

    Each letter's animation is drawn in a different colour — red, blue,
    magenta, navy, maroon, green — so keying on any single hue misses most
    of the alphabet.
    """
    gif = Image.open(gif_path)
    masks = []
    for i in range(gif.n_frames):
        gif.seek(i)
        arr = np.array(gif.convert("RGB")).astype(int)
        masks.append(arr.min(axis=2) < 200)
    return masks


def _longest_path(mask: np.ndarray) -> list[tuple[int, int]]:
    """Order a thin blob's pixels into a path between its two far ends."""
    skeleton = skeletonize(mask)
    points = list(zip(*np.where(skeleton)))
    if len(points) < 2:
        return [(int(r), int(c)) for r, c in points]
    point_set = set(points)
    graph = nx.Graph()
    for p in points:
        r, c = p
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if (dr or dc) and (r + dr, c + dc) in point_set:
                    graph.add_edge(p, (r + dr, c + dc), weight=math.hypot(dr, dc))
    component = max(nx.connected_components(graph), key=len)
    graph = graph.subgraph(component)
    ends = [n for n in graph.nodes if graph.degree(n) == 1] or list(graph.nodes)
    best: list | None = None
    for i in range(len(ends)):
        for j in range(i + 1, len(ends)):
            try:
                candidate = nx.shortest_path(graph, ends[i], ends[j], weight="weight")
            except nx.NetworkXNoPath:
                continue
            if best is None or len(candidate) > len(best):
                best = candidate
    return [(int(r), int(c)) for r, c in (best or list(graph.nodes))]


def _pieces_added_by(frame: np.ndarray, previous: np.ndarray) -> list[list[tuple[int, int]]]:
    """Each separate blob of ink this frame added, as an ordered path."""
    added = frame & ~dilation(previous, disk(1))
    if added.sum() < 3:
        return []
    from scipy import ndimage

    labels, n = ndimage.label(added, structure=np.ones((3, 3)))
    pieces = []
    for label in range(1, n + 1):
        blob = labels == label
        if blob.sum() < 3:
            continue
        path = _longest_path(blob)
        if len(path) >= 2:
            pieces.append(path)
    return pieces


def ordered_strokes(gif_path: str) -> list[list[tuple[int, int]]]:
    """The letter's pen strokes, in writing order, each ordered start to end."""
    masks = _frame_masks(gif_path)
    if not masks:
        return []

    from scipy import ndimage

    distance = ndimage.distance_transform_edt(masks[-1])
    stroke_width = float(2 * np.median(distance[skeletonize(masks[-1])]))
    lift_distance = stroke_width * PEN_LIFT_FACTOR

    strokes: list[list[tuple[int, int]]] = []
    pen: tuple[int, int] | None = None
    previous = np.zeros_like(masks[0])

    for frame in masks:
        for piece in _pieces_added_by(frame, previous):
            if pen is not None:
                # Whichever end of this piece the pen is nearer to is where
                # it was actually entered.
                if math.dist(piece[-1], pen) < math.dist(piece[0], pen):
                    piece = piece[::-1]
                # Dilating the previous frame to kill sliver artefacts also
                # eats the overlap where a stroke continues, so a genuine
                # continuation can look like a gap. Only a clearly distant
                # restart counts as the pen lifting.
                if math.dist(piece[0], pen) > lift_distance:
                    strokes.append(piece)
                else:
                    strokes[-1].extend(piece)
            else:
                strokes.append(piece)
            pen = strokes[-1][-1]
        previous = frame

    return [s for s in strokes if len(s) >= 2]
