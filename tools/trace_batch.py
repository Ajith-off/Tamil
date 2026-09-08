"""Trace every letter of a set that has an order yet, and show the results together.

`trace_letter.py` handles one letter; authoring a category means running it
eighteen times and opening eighteen filmstrips. This does the whole set in one
go, says which letters are still waiting for an order, and stacks the
filmstrips into a single contact sheet — because the check that matters is
whether the *set* is right, and flipping between windows is how a wrong one
gets waved through.

    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py mei
    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py mei_07 mei_08

Writes lib/data/letters/strokes/<id>.json for each, build/filmstrips/<id>.png,
and build/filmstrips/<set>_sheet.png.

Nothing here derives an order. It reads tools/orders.json, which is where the
authoring screen's output goes.
"""

from __future__ import annotations

import json
import os
import sys

import networkx as nx
from PIL import Image, ImageDraw

import glyph_skeleton as gs
import filmstrip
from export_skeletons import LETTERS, uyirmei_to_author
from trace_letter import load_orders, pen_jumps, trace

OUT_DIR = "build/filmstrips"
STROKE_DIR = "lib/data/letters/strokes"
LABEL_PX = 22


def roster() -> list[tuple[str, str]]:
    """Every letter that can be traced.

    The 31 hand-drawn ones plus **all** 216 uyirmei — the 65 that were drawn
    and the rest that `compose_uyirmei.py` builds from them. Composed orders
    have to go through exactly the same pen-jump and coverage checks as
    authored ones; being derived is not a reason to trust them more.
    """
    path = "lib/data/letters/uyirmei.json"
    if not os.path.exists(path):
        return LETTERS + uyirmei_to_author()
    with open(path, encoding="utf-8") as fh:
        uyirmei = [(r["id"], r["tamil"]) for r in json.load(fh)]
    return LETTERS + uyirmei


def resolve(wanted: list[str]) -> list[tuple[str, str]]:
    """Letter ids from an explicit list or a prefix like `mei`."""
    letters = roster()
    if not wanted:
        return letters
    ids = {i for i, _ in letters}
    out: list[tuple[str, str]] = []
    for token in wanted:
        if token in ids:
            out.append(next((i, c) for i, c in letters if i == token))
        else:
            matched = [(i, c) for i, c in letters if i.startswith(token)]
            if not matched:
                sys.exit(f"no letter or prefix matched {token!r}; known: {sorted(ids)}")
            out.extend(matched)
    return out


def arc_components(chains) -> list[list[int]]:
    """Group arc indices into the disconnected pieces of the glyph.

    Same graph `repair_gaps` builds: arcs are edges between their endpoints,
    so a piece of the letter the pen must lift to reach is a component here.
    """
    graph = nx.MultiGraph()
    for index, chain in enumerate(chains):
        graph.add_edge(tuple(chain[0]), tuple(chain[-1]), key=index)
    groups = []
    for nodes in nx.connected_components(graph):
        groups.append(sorted(k for _, _, k in graph.edges(nodes, keys=True)))
    return groups


def undrawn_components(chains, specs) -> list[list[int]]:
    """Whole pieces of the glyph the order never touches at all.

    A piece the pen never visits is a piece of the letter that simply is not
    there: க் without its puḷḷi is க, and கெ without its vowel sign is க.
    Both are different letters, and both are easy to forget because a
    separate piece means a separate pen stroke.

    Judged per *component*, not per arc. An arc left out of a component that
    is otherwise drawn is a sliver at a junction — கெ's sign carries a 32px
    and a 4px one on a 57px stroke — and those sit inside the tube. If one
    ever mattered the pen would have to jump to get past it, and `pen_jumps`
    is what says so.
    """
    drawn = {index for spec in specs for index, _ in spec}
    return [g for g in arc_components(chains) if not any(i in drawn for i in g)]


def contact_sheet(entries: list[tuple[str, str, str]], out_path: str) -> None:
    """Stack the filmstrips, one row per letter, each labelled."""
    strips = [(letter_id, char, Image.open(path)) for letter_id, char, path in entries]
    width = max(s.width for _, _, s in strips)
    height = sum(s.height + LABEL_PX for _, _, s in strips)
    sheet = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(sheet)
    y = 0
    for letter_id, char, strip in strips:
        draw.text((6, y + 5), f"{letter_id}  {char}", fill=(40, 40, 40))
        sheet.paste(strip, (0, y + LABEL_PX))
        y += strip.height + LABEL_PX
    sheet.save(out_path)


if __name__ == "__main__":
    targets = resolve(sys.argv[1:])
    orders = load_orders()
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(STROKE_DIR, exist_ok=True)

    done: list[tuple[str, str, str]] = []
    pending: list[tuple[str, str]] = []
    warnings: list[str] = []

    for letter_id, char in targets:
        if letter_id not in orders:
            pending.append((letter_id, char))
            continue

        char, skel, strokes, data, specs = trace(letter_id)
        stroke_path = f"{STROKE_DIR}/{letter_id}.json"
        with open(stroke_path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)

        chains = gs.ordered_arcs(skel)
        for s, i, index, gap in pen_jumps(chains, specs, tolerance_px=3.0):
            warnings.append(f"{letter_id}: stroke {s} jumps {gap:.0f}px into arc "
                            f"{index} (step {i}) — the order skips a piece")
        for group in undrawn_components(chains, specs):
            warnings.append(f"{letter_id}: a whole piece of '{char}' is never drawn "
                            f"— arcs {', '.join(str(i) for i in group)}")

        strip_path = f"{OUT_DIR}/{letter_id}.png"
        filmstrip.render(letter_id, char, strip_path)
        done.append((letter_id, char, strip_path))
        print(f"{letter_id} {char}  strokes={[len(s) for s in strokes]}  -> {stroke_path}")

    if done:
        prefix = os.path.commonprefix([i for i, _, _ in done]).rstrip("_0123456789") or "letters"
        sheet_path = f"{OUT_DIR}/{prefix}_sheet.png"
        contact_sheet(done, sheet_path)
        print(f"\ncontact sheet: {sheet_path}   (yellow = stroke start, black = pen head)")

    if pending:
        print(f"\nno order yet ({len(pending)}): " + " ".join(f"{i} {c}" for i, c in pending))
    if warnings:
        print("\nWARNINGS")
        for warning in warnings:
            print(f"  {warning}")
    print(f"\n{len(done)} traced, {len(pending)} pending, {len(warnings)} warnings")
