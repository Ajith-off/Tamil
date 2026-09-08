"""Compose writing orders for the uyirmei nobody has to draw.

    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/compose_uyirmei.py

216 uyirmei, but only 65 are new shapes. The rest are a consonant you have
already authored standing next to a vowel sign you have already authored, and
the two do not even touch — separate connected components, so each half's
arcs appear in the composed glyph unchanged apart from where they sit.

That is the whole trick, and it is *not* the failed "match one letterform
against another" of HANDOFF.md. These are the same glyph outlines from the
same font at the same size; a translation-invariant signature matches them
exactly, and this refuses to emit anything when one does not.

Two libraries are read out of the authored orders:

  * **consonants** — each mei letter's order with the puḷḷi's component
    dropped. The bare consonant's skeleton *is* the mei letter's minus its
    dot, arc for arc, so this needs no guessing.
  * **signs** — every component of an authored uyirmei that is not its
    consonant, keyed by shape. Keyed by *shape*, not by vowel column: கி is
    a single fused glyph while வி is a consonant plus a separate ி, so the
    column says nothing about which sign shape a letter contains.

Each sign also records whether the hand drew it before or after the
consonant — ெ goes first, ா follows, and a wrap form like ௌ has one piece
each side. That is a handwriting fact, so it is read off what a person did
rather than decided here.
"""

from __future__ import annotations

import io
import json
import sys

import glyph_skeleton as gs
from export_skeletons import uyirmei_to_author
from trace_batch import arc_components
from trace_letter import AUTHORED_PATH, load_orders

ROSTER = "lib/data/letters/uyirmei.json"
MEI = "lib/data/letters/mei.json"
PULLI = "்"
# Points sampled when fingerprinting an arc: enough to tell a letter's arcs
# apart, few enough to survive a pixel of rounding.
SAMPLES = 8


def signature(chain) -> tuple:
    """An arc's shape, independent of where it sits on the page."""
    r0, c0 = chain[0]
    step = max(1, (len(chain) - 1) // SAMPLES)
    return (
        len(chain),
        tuple((round(r - r0), round(c - c0)) for r, c in chain[::step]),
        (round(chain[-1][0] - r0), round(chain[-1][1] - c0)),
    )


class Glyph:
    """A character's skeleton, split into pieces and fingerprinted."""

    def __init__(self, char: str):
        self.char = char
        self.skeleton = gs.build(char)
        self.chains = gs.ordered_arcs(self.skeleton)
        self.sigs = [signature(c) for c in self.chains]
        self.components = arc_components(self.chains)

    def key(self, group) -> tuple:
        return tuple(sorted(self.sigs[i] for i in group))

    def left_of(self, group) -> float:
        return min(p[1] for i in group for p in self.chains[i])

    def component_of(self, arc: int):
        return next(g for g in self.components if arc in g)


def align(source: Glyph, source_arcs, target: Glyph, target_arcs) -> dict | None:
    """source arc index -> target arc index, by shape. None on any ambiguity.

    A signature that matches two target arcs, or none, means the two are not
    the same shape after all — and nothing here is entitled to pick one.
    """
    mapping, used = {}, set()
    for src in source_arcs:
        hits = [t for t in target_arcs if target.sigs[t] == source.sigs[src] and t not in used]
        if len(hits) != 1:
            return None
        mapping[src] = hits[0]
        used.add(hits[0])
    return mapping if len(used) == len(list(target_arcs)) else None


def consonant_body(mei_char: str, orders: dict, mei_id: str):
    """The mei letter's arcs and strokes with the puḷḷi's component removed."""
    glyph = Glyph(mei_char)
    dots = gs.dot_arc_indices(glyph.skeleton)
    dotted = {i for g in glyph.components if any(d in g for d in dots) for i in g}
    keep = [i for i in range(len(glyph.chains)) if i not in dotted]
    _, specs = orders[mei_id]
    strokes = [s for s in specs if all(i in keep for i, _ in s)]
    return glyph, keep, strokes


def build_sign_library(orders: dict, authored: set, roster: list, mei_ids: dict):
    """shape key -> (source glyph, arcs, strokes, drawn before the consonant?)."""
    library: dict[tuple, tuple] = {}
    for row in roster:
        if row["id"] not in authored:
            continue
        char = row["tamil"]
        glyph = Glyph(char)
        bare = Glyph(row["groupTamil"])
        bare_key = tuple(sorted(bare.sigs))
        cons = next((g for g in glyph.components if glyph.key(g) == bare_key), None)
        if cons is None:
            continue  # fused: no consonant piece to separate, nothing to lend
        _, specs = orders[row["id"]]

        def first_stroke_touching(arcs) -> int:
            for n, stroke in enumerate(specs):
                if any(i in arcs for i, _ in stroke):
                    return n
            return len(specs)

        cons_at = first_stroke_touching(set(cons))
        for group in glyph.components:
            if group is cons:
                continue
            key = glyph.key(group)
            if key in library:
                continue
            arcs = set(group)
            strokes = [s for s in specs if all(i in arcs for i, _ in s)]
            if not strokes:
                continue
            library[key] = (glyph, group, strokes, first_stroke_touching(arcs) < cons_at)
    return library


def main() -> int:
    roster = json.load(io.open(ROSTER, encoding="utf-8"))
    mei_ids = {e["tamil"]: e["id"] for e in json.load(io.open(MEI, encoding="utf-8"))}
    orders = load_orders()
    authored = {i for i, _ in uyirmei_to_author()}

    library = build_sign_library(orders, authored, roster, mei_ids)
    print(f"sign shapes available: {len(library)}")

    composed, skipped = {}, []
    for row in roster:
        letter_id, char = row["id"], row["tamil"]
        if letter_id in authored or letter_id in orders:
            continue
        mei_char = row["groupTamil"] + PULLI
        mei_glyph, keep, body_strokes = consonant_body(mei_char, orders, mei_ids[mei_char])

        target = Glyph(char)
        bare_key = tuple(sorted(signature(c) for c in Glyph(row["groupTamil"]).chains))
        cons = next((g for g in target.components if target.key(g) == bare_key), None)
        if cons is None:
            skipped.append((letter_id, char, "no piece matches the bare consonant"))
            continue

        cons_map = align(mei_glyph, keep, target, cons)
        if cons_map is None:
            skipped.append((letter_id, char, "consonant arcs did not line up"))
            continue
        cons_strokes = [[(cons_map[i], r) for i, r in s] for s in body_strokes]

        before, after, failed = [], [], None
        for group in sorted((g for g in target.components if g is not cons),
                            key=target.left_of):
            entry = library.get(target.key(group))
            if entry is None:
                failed = "no authored letter supplies this sign shape"
                break
            source, src_arcs, src_strokes, is_before = entry
            sign_map = align(source, src_arcs, target, group)
            if sign_map is None:
                failed = "sign arcs did not line up"
                break
            mapped = [[(sign_map[i], r) for i, r in s] for s in src_strokes]
            (before if is_before else after).extend(mapped)
        if failed:
            skipped.append((letter_id, char, failed))
            continue

        strokes = before + cons_strokes + after
        drawn = {i for s in strokes for i, _ in s}
        # Every *piece* must be drawn, not every arc. A composed letter can
        # only inherit the coverage of what it was composed from, and the
        # authored sources legitimately skip junction slivers — கெ's sign
        # leaves a 32px and a 4px arc alone, both well inside the tube.
        # Demanding every arc here rejected 52 letters for a flaw their own
        # sources have. A piece never touched is the thing that matters.
        if any(not (set(g) & drawn) for g in target.components):
            skipped.append((letter_id, char, "a whole piece would go undrawn"))
            continue
        composed[letter_id] = {
            "char": char,
            "strokes": [[[i, bool(r)] for i, r in s] for s in strokes],
        }

    existing = json.load(io.open(AUTHORED_PATH, encoding="utf-8"))
    existing.update(composed)
    io.open(AUTHORED_PATH, "w", encoding="utf-8").write(
        json.dumps(existing, ensure_ascii=False, indent=2))

    print(f"composed : {len(composed)}")
    print(f"skipped  : {len(skipped)}")
    for letter_id, char, why in skipped:
        print(f"    {letter_id} {char} — {why}")
    print(f"orders.json now holds {len(existing)} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
