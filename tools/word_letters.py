"""Curate the cut worksheet pictures into game data, and say why each drop.

    PYTHONIOENCODING=utf-8 python tools/word_letters.py

Two jobs, both of which need the same thing — a word split into the characters
a child actually writes. யானை is four code points and two written characters.

  * Picture Puzzle needs the *first* character of the word (CLAUDE.md §8).
  * Word Builder needs every character, and every one of them has to be a
    character some category teaches. A word containing ஜ or ஸ is unbuildable
    until the grantha category exists, and even then only if that category
    covers the uyirmei forms — ஜாடி needs ஜா, not ஜ.

Writes worksheet_art/keepers.png, a contact sheet of what survived.
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART_DIR = os.path.join(HERE, "worksheet_art")
WORDS = os.path.join(ART_DIR, "words.json")
MANIFEST = os.path.join(ART_DIR, "manifest.json")

UYIR = "அஆஇஈஉஊஎஏஐஒஓஔ"
AAYTHAM = "ஃ"
CONSONANTS = "கஙசஞடணதநபமயரலவழளறன"
GRANTHA = "ஜஷஸஹ"
PULLI = "்"
SIGNS = "".join(chr(c) for c in range(0x0BBE, 0x0BCD)) + "ௗ"

BUILDER_MAX_CHARS = 4      # CLAUDE.md §8 starts Word Builder at three


def split_characters(word):
    """One entry per written character: a base plus whatever hangs off it."""
    out = []
    for ch in word:
        if ch in SIGNS or ch == PULLI:
            if out:
                out[-1] += ch
            continue
        if ch.isspace():
            continue
        out.append(ch)
    return out


def classify(char):
    base, marks = char[0], char[1:]
    if base in UYIR and not marks:
        return "uyir"
    if base == AAYTHAM:
        return "aaytham"
    if base in CONSONANTS:
        return "mei" if marks == PULLI else "uyirmei"
    if base in GRANTHA:
        return "grantha" if not marks else "grantha_uyirmei"
    return "other"


def main():
    words = json.load(open(WORDS, encoding="utf-8"))
    manifest = {e["id"]: e for e in json.load(open(MANIFEST, encoding="utf-8"))}

    keepers, dropped = [], {}
    for eid, e in sorted(words.items()):
        if eid.startswith("_"):
            continue
        if e["class"] != "native":
            dropped.setdefault(e["class"], []).append(eid)
            continue
        chars = split_characters(e["ta"])
        kinds = [classify(c) for c in chars]
        keepers.append(dict(id=eid, en=e["en"], ta=e["ta"], chars=chars,
                            kinds=kinds, flag=e.get("flag"),
                            colour=e.get("colour")))

    print(f"KEEP {len(keepers)} of {len(words) - 2}\n")
    header = f"{'id':<5}{'word':<20}{'first':<8}{'characters':<38}{'Word Builder'}"
    print(header)
    print("-" * len(header))
    builder_ready = 0
    for k in keepers:
        needs = sorted({x for x in k["kinds"] if x.startswith("grantha") or x == "other"})
        if needs:
            note = "needs " + ", ".join(needs)
        elif len(k["chars"]) > BUILDER_MAX_CHARS:
            note = f"too long ({len(k['chars'])})"
        else:
            note = "ready"
            builder_ready += 1
        print(f"{k['id']:<5}{k['ta']:<20}{k['chars'][0]:<8}"
              f"{' + '.join(k['chars']):<38}{note}")

    print(f"\n{builder_ready} are Word Builder ready; "
          f"{len(keepers)} are Picture Puzzle ready.")

    print("\nDROPPED")
    for cls in ("duplicate", "loanword", "rare", "wrong", "damaged"):
        ids = dropped.get(cls, [])
        if ids:
            print(f"  {cls:<10} {len(ids):>2}   {', '.join(ids)}")

    print("\nFLAGS")
    for k in keepers:
        if k["flag"]:
            print(f"  {k['id']} {k['ta']}: {k['flag']}")

    contact(keepers, manifest)


def contact(keepers, manifest, cols=8, cell=170):
    try:
        font = ImageFont.truetype("arial.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    rows = (len(keepers) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 26)), "white")
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(keepers):
        im = Image.open(os.path.join(ART_DIR, "art", manifest[k["id"]]["file"])).convert("RGBA")
        im.thumbnail((cell - 14, cell - 14))
        x, y = (i % cols) * cell, (i // cols) * (cell + 26)
        bg = Image.new("RGBA", (cell, cell), (255, 255, 255, 255))
        bg.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
        sheet.paste(bg.convert("RGB"), (x, y))
        d.rectangle([x, y, x + cell - 1, y + cell - 1], outline=(215, 215, 215))
        d.text((x + 5, y + cell + 3), f"{k['id']} {k['en']}", fill=(0, 0, 0), font=font)
    out = os.path.join(ART_DIR, "keepers.png")
    sheet.save(out)
    print(f"\ncontact sheet: {out}")


if __name__ == "__main__":
    main()
