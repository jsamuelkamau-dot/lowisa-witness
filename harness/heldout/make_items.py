"""Renders a held-out set as photographed one-page papers, for fingerprint_eval.escript.

  python harness/heldout/make_items.py OUT_DIR            the development set (items.py)
  python harness/heldout/make_items.py OUT_DIR v2         the held-out set written after the rule froze (items_v2.py)
  python harness/heldout/make_items.py OUT_DIR planted    the planted-working set (items_planted.py, 4 Nov audit)
  python harness/heldout/make_items.py OUT_DIR v2 hinted  the same, each scheme also naming the wrong method (the ablation)
  python harness/heldout/make_items.py OUT_DIR v1 truth   also OUT_DIR/<id>.truth.json: where each handwritten line really is
                                                          on the photo (the line-placement benchmark, line_bench.escript)
  ->  OUT_DIR/<id>.jpg and OUT_DIR/<id>.json (the exam the teacher set)

The handwriting is a handwriting font (HAND_FONT, default Windows' Ink Free) with a small wobble per letter; the
"photograph" is simulated: the page on a wooden desk, slightly turned, perspective, light falling off. These are not
real students' papers, and real handwriting is harder (stated in the README's limits). A crossed-out line ("~" in
items.py) is struck through in pen."""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
SET = sys.argv[2] if len(sys.argv) > 2 else "v1"
HINTED = len(sys.argv) > 3 and sys.argv[3] == "hinted"
TRUTH = len(sys.argv) > 3 and sys.argv[3] == "truth"
if SET == "v2":
    from items_v2 import ITEMS, TOPICS, SCHEMES_HINTED
elif SET == "planted":
    from items_planted import ITEMS, TOPICS, SCHEMES_HINTED
else:
    from items import ITEMS, TOPICS
    SCHEMES_HINTED = {}

HAND = os.environ.get("HAND_FONT", r"C:\Windows\Fonts\Inkfree.ttf")
PRINT = os.environ.get("PRINT_FONT", r"C:\Windows\Fonts\arial.ttf")
PRINTB = os.environ.get("PRINT_FONT_BOLD", r"C:\Windows\Fonts\arialbd.ttf")
W, H = 1240, 1754


def wrap(d, text, font, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) > width and cur:
            lines.append(cur); cur = w
        else:
            cur = t
    return lines + [cur]


def printed(d, x, y, text, size=26, bold=False, width=1040):
    f = ImageFont.truetype(PRINTB if bold else PRINT, size)
    for line in wrap(d, text, f, width):
        d.text((x, y), line, font=f, fill=(28, 28, 28)); y += int(size * 1.35)
    return y


def hand(img, x, y, text, size, rnd, strike=False, ink=(24, 40, 110, 238)):
    f = ImageFont.truetype(HAND, size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    cx, base = x, rnd.uniform(-1.5, 1.5)
    for ch in text:
        base += rnd.uniform(-0.25, 0.25)
        d.text((cx, y + base + rnd.uniform(-1.8, 1.8)), ch, font=f, fill=ink)
        cx += d.textlength(ch, font=f) + rnd.uniform(-0.5, 0.9)
    if strike:
        d.line([(x - 6, y + size * 0.62), (cx + 6, y + size * 0.55)], fill=ink, width=4)
    img.alpha_composite(layer.rotate(rnd.uniform(-0.4, 0.4), center=(x, y), resample=Image.BICUBIC))


def photograph(img, rnd, mask=False):
    desk = Image.new("RGB", (1500, 2000), (120, 92, 66)); dd = ImageDraw.Draw(desk)
    for i in range(0, 2000, 9):
        c = 112 + int(14 * math.sin(i / 37.0)) + rnd.randint(-4, 4)
        dd.line([(0, i), (1500, i + rnd.randint(-6, 6))], fill=(0, 0, 0) if mask else (c, int(c * 0.76), int(c * 0.55)), width=5)
    p = img.rotate(rnd.uniform(-1.8, 1.8), resample=Image.BICUBIC, expand=True)
    p = p.resize((int(p.width * 1.08), int(p.height * 1.08)))
    desk = desk.convert("RGBA"); desk.alpha_composite(p, ((1500 - p.width) // 2 + rnd.randint(-15, 15), (2000 - p.height) // 2 + rnd.randint(-15, 15)))
    desk = desk.convert("RGB")
    yy, xx = np.mgrid[0:desk.height, 0:desk.width].astype(np.float32)
    fall = 1.0 - 0.16 * ((xx / desk.width) * 0.6 + (yy / desk.height) * 0.4)
    r = np.sqrt(((xx - desk.width / 2) / desk.width) ** 2 + ((yy - desk.height / 2) / desk.height) ** 2)
    a = np.asarray(desk).astype(np.float32) * (fall * (1.0 - 0.18 * np.clip(r - 0.25, 0, 1)))[..., None]
    desk = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    k = rnd.uniform(0.00002, 0.00004)
    desk = desk.transform(desk.size, Image.PERSPECTIVE, (1, 0.02, -15, 0.01, 1, -10, k, 0.00001), Image.BICUBIC)
    return desk.resize((1200, 1600))


NAMES = ["Ana Lima", "Kwame Asante", "Mei Chen", "Omar Haddad", "Sofia Rossi", "Ravi Patel", "Lena Novak", "Diego Ruiz"]


def paper(item, rnd, only=None):
    """only = k: a mask of the k-th handwritten answer line alone (white on black), drawn with the same random draws."""
    iid, topic, lines = item[0], item[1], item[2]
    text, marks, _ = TOPICS[topic]
    mask = only is not None
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255) if mask else (251, 250, 246, 255)); d = ImageDraw.Draw(img)
    hidden = (0, 0, 0, 0)
    pd = ImageDraw.Draw(Image.new("RGBA", (W, H))) if mask else d      # printed words: drawn nowhere on a mask
    printed(pd, 90, 64, "Mathematics Class Check" if SET == "v1" else "Class Check", 40, True)
    printed(pd, 90, 168, "Name: ______________________________      Class: ________", 28)
    hand(img, 200, 152, NAMES[sum(map(ord, iid)) % len(NAMES)], 52, rnd, ink=hidden if mask else (24, 40, 110, 238))
    hand(img, 820, 156, "8A", 48, rnd, ink=hidden if mask else (24, 40, 110, 238))
    y = printed(pd, 90, 280, "1.  %s   (%d mark%s)" % (text, marks, "" if marks == 1 else "s"), 25) + 30
    for k, line in enumerate(lines):
        ink = ((255, 255, 255, 255) if k == only else hidden) if mask else (24, 40, 110, 238)
        hand(img, 140 + rnd.randint(-6, 6), y, line.lstrip("~"), 44, rnd, strike=line.startswith("~"), ink=ink)
        y += 66
    printed(pd, W // 2 - 50, H - 78, "Page 1 of 1", 20)
    return img


def truth(item):
    """Each answer line's box on the final photo, in thousandths of its width and height (left, top, right, bottom)."""
    boxes = []
    for k in range(len(item[2])):
        rnd = random.Random(item[0])
        m = np.asarray(photograph(paper(item, rnd, only=k), rnd, mask=True).convert("L"))
        ys, xs = np.where(m > 140)
        boxes.append(None if len(xs) == 0 else [round(xs.min() / m.shape[1] * 1000), round(ys.min() / m.shape[0] * 1000),
                                                 round(xs.max() / m.shape[1] * 1000), round(ys.max() / m.shape[0] * 1000)])
    return boxes


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for item in ITEMS:
        iid, topic = item[0], item[1]
        rnd = random.Random(iid)
        photograph(paper(item, rnd), rnd).save(os.path.join(out, iid + ".jpg"), quality=86)
        if TRUTH:
            json.dump({"id": iid, "lines": [l.lstrip("~") for l in item[2]], "boxes": truth(item)},
                      open(os.path.join(out, iid + ".truth.json"), "w", encoding="utf-8"), ensure_ascii=False)
        text, marks, scheme = TOPICS[topic]
        if HINTED and topic in SCHEMES_HINTED:
            scheme = scheme + " " + SCHEMES_HINTED[topic]
        json.dump({"id": iid, "topic": topic, "expect": item[3], "keys": item[4], "level": "Year 8",
                   "hard": bool(item[5]) if len(item) > 5 else False, "set": SET, "hinted": HINTED,
                   "scheme": "Q1: " + scheme, "questions": [{"n": 1, "text": text, "marks": marks}]},
                  open(os.path.join(out, iid + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(ITEMS), "papers in", out)
