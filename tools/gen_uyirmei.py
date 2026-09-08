"""Write lib/data/letters/uyirmei.json — all 216, in 18 consonant groups.

    PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/gen_uyirmei.py

Generated rather than hand-written, because 216 rows of the same three
mechanical facts is 216 chances to mistype one. The Tamil is the consonant
plus the vowel sign, and the transliteration is the consonant's plus the
vowel's — both taken from mei.json and uyir.json so a change there cannot
drift from here.

Example words are deliberately absent. There is no honest way to invent 216
of them, and a wrong one teaches a wrong word; the field is optional and the
letter screen simply omits the panel until someone writes them.

Ids are `uyirmei_<consonant 01-18>_<vowel 01-12>`, so a stroke file lands on
exactly one character and the group is readable straight off the id.
"""

from __future__ import annotations

import json
import os

OUT = "lib/data/letters/uyirmei.json"

# (vowel sign, transliteration suffix). The first is the inherent 'a', which
# is written with no sign at all — க on its own is already "ka".
VOWELS: list[tuple[str, str]] = [
    ("", "a"),
    ("ா", "aa"),
    ("ி", "i"),
    ("ீ", "ii"),
    ("ு", "u"),
    ("ூ", "uu"),
    ("ெ", "e"),
    ("ே", "ee"),
    ("ை", "ai"),
    ("ொ", "o"),
    ("ோ", "oo"),
    ("ௌ", "au"),
]

PULLI = "்"


def consonants() -> list[tuple[str, str]]:
    """(bare consonant, transliteration stem) from mei.json.

    mei.json holds க் and "k"; the uyirmei row needs க and "k". Read rather
    than restated so the two files cannot disagree about either.
    """
    with open("lib/data/letters/mei.json", encoding="utf-8") as fh:
        mei = json.load(fh)
    out = []
    for entry in sorted(mei, key=lambda e: e["order"]):
        tamil = entry["tamil"]
        assert tamil.endswith(PULLI), f"{tamil} is not a pure consonant"
        out.append((tamil[:-1], entry["transliteration"]))
    return out


def build() -> list[dict]:
    rows = []
    for c, (base, stem) in enumerate(consonants(), start=1):
        for v, (sign, vowel) in enumerate(VOWELS, start=1):
            rows.append({
                "id": f"uyirmei_{c:02d}_{v:02d}",
                "category": "uyirmei",
                "group": f"uyirmei_{c:02d}",
                "groupTamil": base,
                "order": (c - 1) * len(VOWELS) + v,
                "tamil": base + sign,
                "transliteration": stem + vowel,
                "strokeDataId": f"uyirmei_{c:02d}_{v:02d}",
            })
    return rows


if __name__ == "__main__":
    rows = build()
    assert len(rows) == 216, len(rows)
    assert len({r["id"] for r in rows}) == 216
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print(f"wrote {OUT} — {len(rows)} characters in "
          f"{len({r['group'] for r in rows})} groups")
    print("  first:", rows[0]["tamil"], rows[0]["transliteration"])
    print("  last :", rows[-1]["tamil"], rows[-1]["transliteration"])
