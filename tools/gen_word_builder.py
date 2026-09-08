"""Write lib/data/games/word_builder.json and copy the pictures it needs.

    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/gen_word_builder.py

Generated rather than hand-written for the same reason `gen_uyirmei.py` is:
every slot's tiles are a mechanical consequence of the word, and typing 51 of
them out by hand is 51 chances to give a child the wrong letter to drag.

The rules, from CLAUDE.md section 8:

* at most 4 characters, at most 2 uyirmei, every character inside the 247
* the tile pool is the 31 base characters — 12 uyir, 18 mei, ஃ — so **every**
  consonant-vowel character is two tiles, ம் + ஆ → மா and ம் + அ → ம alike.
  No exceptions, because a rule with an exception in it is the one a child
  gets wrong.

Ordered easiest first: fewest slots, then fewest tiles.
"""
from __future__ import annotations

import json
import os
import shutil
import sys

from word_letters import split_characters, classify

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "worksheet_art")
OUT_JSON = "lib/data/games/word_builder.json"
OUT_IMAGES = "assets/images/words"

PULLI = "்"

# Vowel sign -> the uyir letter a child drags for it. The empty sign is the
# inherent 'a': க is க் + அ, written with no sign at all.
SIGN_TO_UYIR = {
    "": "அ", "ா": "ஆ", "ி": "இ", "ீ": "ஈ",
    "ு": "உ", "ூ": "ஊ", "ெ": "எ", "ே": "ஏ",
    "ை": "ஐ", "ொ": "ஒ", "ோ": "ஓ", "ௌ": "ஔ",
}

MAX_SLOTS = 4
MAX_UYIRMEI = 2


def tiles_for(char: str) -> list[str]:
    """The tiles that build one written character, in the order they go down."""
    kind = classify(char)
    if kind == "uyirmei":
        base, sign = char[0], char[1:]
        if sign not in SIGN_TO_UYIR:
            raise ValueError(f"no uyir for the sign in {char!r}")
        return [base + PULLI, SIGN_TO_UYIR[sign]]
    return [char]


def build():
    words = json.load(open(os.path.join(ART, "words.json"), encoding="utf-8"))
    manifest = {e["id"]: e for e in
                json.load(open(os.path.join(ART, "manifest.json"), encoding="utf-8"))}

    rows = []
    for eid, entry in sorted(words.items()):
        if eid.startswith("_") or entry["class"] != "native":
            continue
        chars = split_characters(entry["ta"])
        kinds = [classify(c) for c in chars]
        if any(k.startswith("grantha") or k == "other" for k in kinds):
            continue
        if len(chars) > MAX_SLOTS:
            continue
        if sum(1 for k in kinds if k == "uyirmei") > MAX_UYIRMEI:
            continue
        slots = [{"char": c, "tiles": tiles_for(c)} for c in chars]
        rows.append({
            "sourceId": eid,
            "tamil": entry["ta"],
            "english": entry["en"],
            "slots": slots,
            "_tiles": sum(len(s["tiles"]) for s in slots),
        })

    rows.sort(key=lambda r: (len(r["slots"]), r["_tiles"], r["tamil"]))
    for i, row in enumerate(rows, start=1):
        row["id"] = f"word_{i:02d}"
        row["order"] = i
        row["image"] = f"{OUT_IMAGES}/{row['id']}.png"
        del row["_tiles"]

    return rows, manifest


def main():
    rows, manifest = build()

    os.makedirs(OUT_IMAGES, exist_ok=True)
    for stale in os.listdir(OUT_IMAGES):
        os.remove(os.path.join(OUT_IMAGES, stale))
    for row in rows:
        src = os.path.join(ART, "art", manifest[row["sourceId"]]["file"])
        shutil.copyfile(src, os.path.join(OUT_IMAGES, f"{row['id']}.png"))

    ordered = [{
        "id": r["id"], "order": r["order"], "tamil": r["tamil"],
        "english": r["english"], "image": r["image"], "slots": r["slots"],
    } for r in rows]

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(ordered, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    tiles = [sum(len(s["tiles"]) for s in r["slots"]) for r in rows]
    print(f"wrote {OUT_JSON} — {len(rows)} words")
    print(f"  slots {min(len(r['slots']) for r in rows)}-{max(len(r['slots']) for r in rows)}, "
          f"tiles {min(tiles)}-{max(tiles)}")
    print(f"  copied {len(rows)} pictures to {OUT_IMAGES}/")
    for r in rows[:5]:
        shown = "  ".join(f"{s['char']}=[{'+'.join(s['tiles'])}]" for s in r["slots"])
        print(f"  {r['id']} {r['tamil']:<8} {shown}")

    # Every tile has to be something the pool can actually offer.
    pool = set(SIGN_TO_UYIR.values()) | {c + PULLI for c in "கஙசஞடணதநபமயரலவழளறன"} | {"ஃ"}
    assert len(pool) == 31, len(pool)
    stray = {t for r in rows for s in r["slots"] for t in s["tiles"]} - pool
    assert not stray, f"tiles outside the 31: {stray}"
    print(f"  every tile is one of the 31 base characters")


if __name__ == "__main__":
    sys.exit(main())
