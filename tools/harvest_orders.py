"""Recover kept writing orders from the device log and merge them into
tools/orders.json.

    adb -s <device> logcat -d > log.txt
    PYTHONIOENCODING=utf-8 python tools/harvest_orders.py log.txt          # show
    PYTHONIOENCODING=utf-8 python tools/harvest_orders.py log.txt --write  # merge

The authoring screen holds a sitting in its own state and exports through the
clipboard, the console and a dialog — but writes no file, so leaving the
screen loses everything not yet pasted. It therefore prints each order to the
console the moment it is kept, precisely so the sitting survives a crash.

That backstop was needed once already: `debugPrint` throttles, the first
Export all of 18 mei letters came through cut off mid-way through the
seventeenth, and all 18 had to be recovered from the individual blocks by
hand. This does that by machine.

Reads a saved `adb logcat` dump, or stdin. Merging is opt-in: authoring the
same letter twice is normal — the screen offers **Replace →** — so the last
block in the log wins, and the JSON is only rewritten when asked.
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORDERS = os.path.join(HERE, "orders.json")

# Every logcat line carries a timestamp/pid prefix before the payload.
PREFIX = re.compile(r"^.*?\bflutter\s*:\s?", re.UNICODE)
KEPT = re.compile(r"=== kept: (\S+) (\S+) [—-] (.+)$")


def from_summary(summary):
    """Rebuild the strokes from the one-line summary the header carries.

    `1 → 2 → 6 → 0R → 6R → 5 | 3 → 4` — arc indices in writing order, `R` for
    against the arc's stored direction, `|` between pen strokes. This is the
    same information as the JSON block and it fits on one line, which is why
    it survives when the block does not.
    """
    strokes = []
    for part in summary.split("|"):
        steps = []
        for token in part.replace("→", " ").split():
            token = token.strip()
            if not token:
                continue
            reverse = token.endswith("R")
            index = token[:-1] if reverse else token
            if not index.isdigit():
                return None
            steps.append([int(index), reverse])
        if steps:
            strokes.append(steps)
    return strokes or None


def harvest(lines):
    """Every kept order in the log, later blocks overriding earlier ones."""
    found: dict[str, dict] = {}
    pending = None       # (letterId, char, summary) of the block being read
    buf: list[str] = []
    depth = 0

    def flush():
        """Take the JSON block if it is whole, else fall back to the header.

        `debugPrint` throttles, which is how the first Export all of 18 mei
        letters came through cut off mid-way through the seventeenth. A
        truncated block is therefore expected rather than exceptional — and
        losing an order to it means redrawing the letter, which is the
        expensive part.
        """
        nonlocal pending, buf, depth
        if pending is None:
            return
        letter_id, char, summary = pending
        try:
            found.update(json.loads("\n".join(buf)))
        except json.JSONDecodeError:
            strokes = from_summary(summary)
            if strokes is None:
                print(f"  lost {letter_id} {char}: block truncated and the "
                      f"summary did not parse", file=sys.stderr)
            else:
                found[letter_id] = {"char": char, "strokes": strokes}
                print(f"  {letter_id} {char}: block was truncated, rebuilt from "
                      f"its summary line", file=sys.stderr)
        pending, buf, depth = None, [], 0

    for raw in lines:
        line = PREFIX.sub("", raw.rstrip("\n"))
        match = KEPT.search(line)
        if match:
            flush()                       # the previous block ends here
            pending = match.groups()
            buf, depth = [], 0
            continue
        if pending is None:
            continue
        # The block is one pretty-printed JSON object. Count braces rather than
        # look for a closing line, so a truncated block is caught rather than
        # silently merging half an order.
        buf.append(line)
        depth += line.count("{") - line.count("}")
        if depth == 0 and "{" in "".join(buf):
            flush()
    flush()                               # a block still open at end of log
    return found


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    write = "--write" in argv

    if args:
        with open(args[0], encoding="utf-8", errors="replace") as fh:
            found = harvest(fh)
    else:
        found = harvest(sys.stdin)

    if not found:
        print("no kept orders in the log")
        return 1

    with open(ORDERS, encoding="utf-8") as fh:
        orders = json.load(fh)

    new = [k for k in found if k not in orders]
    changed = [k for k in found if k in orders and orders[k] != found[k]]
    same = [k for k in found if k in orders and orders[k] == found[k]]

    for letter_id, order in sorted(found.items()):
        mark = "new" if letter_id in new else "replaces" if letter_id in changed else "unchanged"
        strokes = " | ".join(
            " ".join(f"{i}{'R' if rev else ''}" for i, rev in stroke)
            for stroke in order["strokes"]
        )
        print(f"{letter_id:<16} {order['char']:<4} {mark:<10} {strokes}")

    print(f"\n{len(found)} kept: {len(new)} new, {len(changed)} replacing, "
          f"{len(same)} unchanged")

    if not write:
        print("\nnothing written — pass --write to merge into tools/orders.json")
        return 0

    # Match the file exactly as the authoring screen's own export writes it —
    # two-space indent, insertion order, so new letters land at the end. Any
    # other choice reformats 11,000 lines and buries the six that changed.
    orders.update(found)
    with open(ORDERS, "w", encoding="utf-8") as fh:
        json.dump(orders, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(f"\nmerged into {ORDERS} — {len(orders)} entries")
    print("now run: PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
