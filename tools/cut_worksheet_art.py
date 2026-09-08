"""Cut the individual pictures out of the A-to-Z worksheet pages.

    PYTHONIOENCODING=utf-8 python tools/cut_worksheet_art.py

Each page in tools/worksheet_pages/ is one A4 sheet holding a grid or two
columns of clipart, wrapped in rules, answer letters and the publisher's
branding. This finds the clipart, trims it to its own ink, drops the page
background to transparent and de-duplicates the pieces that appear on more
than one sheet — the same elephant is on four of them.

Writes tools/worksheet_art/: one PNG per picture, a manifest, and numbered
contact sheets to review the lot on.

Nothing here ships. The reviewed pictures are what get copied into
assets/images/ under their Tamil word, which is a decision for a person.
"""
import os, glob, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "worksheet_pages")
OUT = os.path.join(HERE, "worksheet_art")
ART = os.path.join(OUT, "art")

HEADER_FRAC = 0.12       # branding band at the top of every sheet
FOOTER_FRAC = 0.955      # "visit atozworksheet.com" band
MIN_SIDE = 90            # a printed letter is smaller than this
MIN_AREA = 3500
MAX_W_FRAC = 0.95        # wider than this is a page rule, not a card
MAX_H_FRAC = 0.32
PAD = 6                  # breathing room kept around the trimmed art
FRAME_INK_MIN = 0.85     # ink all the way round the box means a card border
ROW_ASPECT = 3.5         # wider than this is a row holding art plus its answer
LARGEST_PIECE_MIN = 0.6  # transparency that shatters the art is refused

# Sheets that answer a picture with a letter put every picture in the left
# column and every letter to its right. Nothing about a letter's *shape* tells
# it apart from a drawing — a solid orange is as flat a fill as a solid G — so
# the column is what separates them. Full-page x, on a 1414px-wide sheet.
PICTURE_X_MAX = {
    "show_special_1": 240, "show_special_2": 240,   # picture, then its letter
    "show_special_3": 400, "show_special_4": 400,   # picture left, letter far right
    "show_special_5": 400, "show_special_6": 400,
    "special_4": 400, "special_5": 400,             # Tamil matching sheets
}

# White art on a white card has no seam to cut along. The fragmentation test
# below catches most of it; the unicorn is drawn so lightly that what survives
# is still one piece, so it is named here instead.
KEEP_OPAQUE = {"show_special_5#1"}


def pale_mask(arr):
    """True where the pixel is page background — white card or lavender page."""
    mx = arr.max(axis=2).astype(np.int16)
    mn = arr.min(axis=2).astype(np.int16)
    return (mn > 214) & ((mx - mn) < 32)


def is_framed(ink):
    """A rectangle of ink round the edge of the box — a card, not a picture."""
    ring = np.concatenate([ink[0, :], ink[-1, :], ink[:, 0], ink[:, -1]])
    return ring.mean() > FRAME_INK_MIN


def is_text_line(box):
    """A run of instruction text: long, low, and never as tall as a picture."""
    bw, bh = box[2] - box[0], box[3] - box[1]
    return bh < 80 and bw > bh * 2.5


def _boxes(ink, w, h):
    grown = ndimage.binary_dilation(ink, np.ones((13, 13), bool))
    lab, _ = ndimage.label(grown)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        ys, xs = sl
        bh, bw = ys.stop - ys.start, xs.stop - xs.start
        area = int((ink[sl] & (lab[sl] == i)).sum())
        if max(bh, bw) < MIN_SIDE or area < MIN_AREA:
            continue
        if bw > w * MAX_W_FRAC or bh > h * MAX_H_FRAC:
            continue
        out.append([int(xs.start), int(ys.start), int(xs.stop), int(ys.stop), area])
    return out


def find_blobs(arr, page=""):
    h, w = arr.shape[:2]
    ink = ~pale_mask(arr)
    ink[: int(h * HEADER_FRAC), :] = False
    ink[int(h * FOOTER_FRAC) :, :] = False
    boxes = _boxes(ink, w, h)

    # a box that swallows another one is a container (card border) — drop it
    boxes = [a for a in boxes
             if not any(b is not a and a[0] <= b[0] and a[1] <= b[1]
                        and a[2] >= b[2] and a[3] >= b[3] for b in boxes)]

    x_max = PICTURE_X_MAX.get(page, w)
    keep = []
    for b in boxes:
        x0, y0, x1, y1 = b[:4]
        if x0 >= x_max or is_text_line(b):
            continue
        sub_ink = ink[y0:y1, x0:x1]
        # A pill or card holding a picture and its answer; also any box far
        # wider than a drawing ever is, which is the same thing with a pale
        # outline the ink test does not see.
        if is_framed(sub_ink) or (x1 - x0) > (y1 - y0) * ROW_ASPECT:
            # Look inside it. The card also holds the answer — letters under
            # the picture on a grid card, a dotted word beside it on a row —
            # and the picture always comes first in reading order, so keep only
            # the part of the card the answer cannot be in.
            inner = ink[y0 + 14:y1 - 14, x0 + 14:x1 - 14].copy()
            inner[:, :6] = inner[:, -6:] = inner[:6, :] = inner[-6:, :] = False
            if (x1 - x0) > (y1 - y0) * 1.6:
                inner[:, int(inner.shape[1] * 0.4):] = False    # row: art left
            else:
                inner[int(inner.shape[0] * 0.65):, :] = False   # grid: art top
            for s in _boxes(inner, w, h):
                if not is_text_line(s):
                    keep.append([x0 + 14 + s[0], y0 + 14 + s[1],
                                 x0 + 14 + s[2], y0 + 14 + s[3], s[4]])
            continue
        keep.append(b)

    keep.sort(key=lambda b: (b[1] // 60, b[0]))
    return keep


def cut(page_arr, box, opaque=False):
    """Trim to the ink inside the box and knock the background transparent."""
    x0, y0, x1, y1 = box[:4]
    sub = page_arr[y0:y1, x0:x1]
    ink = ~pale_mask(sub)
    ys, xs = np.where(ink)
    if len(ys) == 0:
        return None, False
    t, b = max(0, ys.min() - PAD), min(sub.shape[0], ys.max() + 1 + PAD)
    l, r = max(0, xs.min() - PAD), min(sub.shape[1], xs.max() + 1 + PAD)
    sub = np.ascontiguousarray(sub[t:b, l:r])

    # background = the pale region reachable from the border, so white *inside*
    # the drawing (a cow's flank, an ice cream) is kept
    pale = pale_mask(sub)
    lab, _ = ndimage.label(pale)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    outside = np.isin(lab, list(border))

    # White art on a white card has no seam to cut along: stripping the
    # background walks in through the gaps and shatters the drawing. When that
    # happens keep the picture opaque rather than ship a hole-punched cat.
    keep_alpha = not opaque
    if keep_alpha:
        opq = ~outside
        olab, on = ndimage.label(opq)
        if on:
            sizes = ndimage.sum(opq, olab, range(1, on + 1))
            keep_alpha = sizes.max() / max(1.0, sizes.sum()) >= LARGEST_PIECE_MIN
    alpha = np.where(outside & keep_alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([sub, alpha]), "RGBA"), keep_alpha


def signature(im, n=16):
    """Shape plus colour. Shape alone merges the seven crayons — same drawing,
    seven different fills — which is exactly what the colour sheet is about."""
    g = np.asarray(im.convert("RGBA"))
    rgb, a = g[..., :3].astype(float), g[..., 3:4] / 255.0
    flat = (rgb * a + 255 * (1 - a)).astype(np.uint8)   # composite on white
    small = np.asarray(Image.fromarray(flat).convert("L")
                       .resize((n, n), Image.LANCZOS), float)
    ink = a[..., 0] > 0.5
    mean = rgb[ink].mean(axis=0) if ink.any() else np.zeros(3)
    return (small > small.mean()).flatten(), mean


def same_picture(a, b):
    shape_a, col_a = a
    shape_b, col_b = b
    return (shape_a != shape_b).sum() <= 14 and np.abs(col_a - col_b).max() < 34


def main():
    os.makedirs(ART, exist_ok=True)
    for f in glob.glob(os.path.join(ART, "*.png")):
        os.remove(f)

    entries, sigs = [], []
    for f in sorted(glob.glob(os.path.join(SRC, "*.webp"))):
        page = os.path.splitext(os.path.basename(f))[0]
        arr = np.asarray(Image.open(f).convert("RGB"))
        for k, box in enumerate(find_blobs(arr, page), start=1):
            slot = f"{page}#{k}"
            im, transparent = cut(arr, box, opaque=slot in KEEP_OPAQUE)
            if im is None:
                continue
            sig = signature(im)
            dupe = next((e for e, s in zip(entries, sigs)
                         if same_picture(s, sig)), None)
            if dupe:
                dupe["also_on"].append(slot)
                continue
            eid = f"{len(entries) + 1:03d}"
            name = f"{eid}_{page}_{k:02d}.png"
            im.save(os.path.join(ART, name))
            entries.append(dict(id=eid, file=name, page=page, slot=k,
                                box=box[:4], size=list(im.size),
                                transparent=bool(transparent), also_on=[]))
            sigs.append(sig)
        print(f"{page}: running total {len(entries)}")

    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=1)
    contact(entries)
    print(f"\n{len(entries)} unique pictures -> {ART}")


def contact(entries, cols=6, cell=210, per_sheet=30):
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for s in range(0, len(entries), per_sheet):
        chunk = entries[s:s + per_sheet]
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + 30)), "white")
        d = ImageDraw.Draw(sheet)
        for i, e in enumerate(chunk):
            im = Image.open(os.path.join(ART, e["file"])).convert("RGBA")
            im.thumbnail((cell - 16, cell - 16))
            x, y = (i % cols) * cell, (i // cols) * (cell + 30)
            bg = Image.new("RGBA", (cell, cell), (255, 255, 255, 255))
            bg.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
            sheet.paste(bg.convert("RGB"), (x, y))
            d.rectangle([x, y, x + cell - 1, y + cell - 1], outline=(210, 210, 210))
            d.text((x + 6, y + cell + 4), e["id"], fill=(0, 0, 0), font=font)
        sheet.save(os.path.join(OUT, f"sheet_{s // per_sheet + 1}.png"))


if __name__ == "__main__":
    main()
