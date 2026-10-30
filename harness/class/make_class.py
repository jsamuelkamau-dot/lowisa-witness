"""A class of 40: the film's maths test (six questions, two pages) answered by 40 sample students, each paper
photographed, for class_run.escript (31 Oct 2026, after the 12-judge panel: "show a class of 40: marking time, the
class patterns with real group sizes, cost per class").

  python harness/class/make_class.py OUT_DIR
  ->  OUT_DIR/sNN_p1.jpg, OUT_DIR/sNN_p2.jpg, OUT_DIR/exam.json (the exam the teacher set) and OUT_DIR/truth.json
      (written here, before any run: each student's name and, per question, mastered or the wrong idea drawn)

Each wrong answer is one of a few ideas a teacher sees in this topic. Some ideas cross questions on purpose: "a
percentage taken as that many dollars" is a wrong answer on Q2, Q4 and Q5, so the class view should put those lines
in one group. Q4's "Half up, half down. Same price." states a result and shows no calculation: the right outcome is
that nothing is named and Lo asks. The handwriting and the photo come from the held-out generator (a handwriting
font, a simulated phone photo); these are sample papers, not real students' work."""
import json, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "heldout"))
sys.argv = sys.argv[:2]   # make_items reads its own arguments at import; the class set needs none of them
from make_items import printed, hand, photograph   # noqa: E402
from PIL import Image, ImageDraw   # noqa: E402

W, H = 1240, 1754
TITLE = "Mathematics: Percentages and Money"
QUESTIONS = [
    (1, "Work out 25% of 80.", 1),
    (2, "A jacket costs $60. In a sale it is 20% off. What is the sale price? Show your working.", 2),
    (3, "Write 3/5 as a percentage.", 1),
    (4, "A product costs $100. Its price increases by 50%, then decreases by 50%. What is its final price? "
        "Circle one answer and explain your thinking.", 3),
    (5, "A salary of $2,000 a month rises by 10%. What is the new salary?", 2),
    (6, "Share $45 between Ana and Ben in the ratio 2 : 3.", 2),
]
OPTIONS4 = ["A   $100 — back to the original price", "B   $75 — lower than the original price",
            "C   $50 — half the original price", "D   $150 — higher than the original price"]
SCHEME = ("Q1: 20 (1).\n"
          "Q2: 20% of $60 = $12 (1); $60 - $12 = $48 (1).\n"
          "Q3: 60% (1).\n"
          "Q4: B, $75 (1). Method (2): the 50% increase is on $100, giving $150 (1); the 50% decrease is on the new "
          "price $150, so $75 is taken off, giving $75 (1). The two percentages are of different amounts, so they do not "
          "cancel. Saying +50% and -50% cancel gets no method marks.\n"
          "Q5: 10% of $2,000 = $200 (1); $2,200 (1).\n"
          "Q6: $45 / 5 = $9 a part (1); Ana $18, Ben $27 (1).")

# question -> idea -> (the lines the student writes, the option ringed on Q4 or None)
WRITES = {
    1: {"right": (["20"], None),
        "divides_by_percent": (["80 ÷ 25 = 3.2"], None)},
    2: {"right": (["20% of 60 = 12", "60 - 12 = $48"], None),
        "percent_as_dollars": (["60 - 20 = $40"], None)},
    3: {"right": (["60%"], None),
        "digits_as_percent": (["3/5 = 35%"], None)},
    4: {"right": (["Up: 50% of 100 = 50, so $150", "Down: 50% of 150 = 75, so $75"], 1),
        "cancel": (["+50% - 50% = 0%", "so it stays at $100."], 0),
        "percent_as_dollars": (["100 + 50 = 150", "150 - 50 = 100"], 0),
        "no_calculation": (["Half up, half down. Same price."], 0)},
    5: {"right": (["10% of 2000 = 200", "$2,200"], None),
        "percent_as_dollars": (["2000 + 10 = $2,010"], None)},
    6: {"right": (["45 ÷ 5 = 9", "Ana $18, Ben $27"], None),
        "divides_by_each_part": (["45 ÷ 2 = 22.50", "45 ÷ 3 = 15"], None)},
}
# how many of the 40 draw each wrong idea (the rest are right); fixed, so the truth is known before the run
COUNTS = {1: {"divides_by_percent": 4}, 2: {"percent_as_dollars": 8}, 3: {"digits_as_percent": 5},
          4: {"cancel": 12, "percent_as_dollars": 9, "no_calculation": 5}, 5: {"percent_as_dollars": 6},
          6: {"divides_by_each_part": 7}}
NAMES = ["Amara Okafor", "Lucas Moreau", "Hana Sato", "Mateo Garcia", "Zara Ahmed", "Noah Fischer", "Isla Murphy",
         "Arjun Mehta", "Chloe Dubois", "Yusuf Kaya", "Elena Petrova", "Kofi Mensah", "Mia Johansson", "Ravi Iyer",
         "Sofia Bianchi", "Daniel Cohen", "Aisha Bello", "Leo Tanaka", "Nadia Haddad", "Samuel Osei", "Grace Kim",
         "Tomas Novak", "Layla Hassan", "Ethan Walker", "Priya Raman", "Hugo Silva", "Fatima Diallo", "Oliver Brown",
         "Mei Lin", "Javier Torres", "Ingrid Larsen", "Kenji Mori", "Amina Yusuf", "Lucia Romero", "David Mwangi",
         "Sara Nilsson", "Omar Farouk", "Anya Kowalski", "Ben Carter", "Nia Thompson"]


def draw_truth():
    rnd = random.Random("class-of-40")
    truth = [{"student": NAMES[i], "questions": {}} for i in range(40)]
    order = list(range(40))
    for n in range(1, 7):
        rnd.shuffle(order)
        k = 0
        for idea, c in COUNTS[n].items():
            for s in order[k:k + c]:
                truth[s]["questions"][n] = idea
            k += c
        for s in order[k:]:
            truth[s]["questions"][n] = "right"
    return truth


def page(pno, name, answers, rnd):
    img = Image.new("RGBA", (W, H), (251, 250, 246, 255)); d = ImageDraw.Draw(img)
    if pno == 1:
        printed(d, 90, 64, TITLE, 40, True)
        printed(d, 90, 118, "Year 9 · Class Test · Total 11 marks", 24)
        printed(d, 90, 168, "Name: ______________________________      Class: ________", 28)
        printed(d, 90, 220, "Answer every question in the space below it. Show your working.", 22)
        hand(img, 200, 152, name, 52, rnd)
        hand(img, 820, 156, "9B", 48, rnd)
        qs, y = [1, 2, 3], 300
    else:
        printed(d, 90, 64, TITLE + "  (page 2)", 28, True)
        qs, y = [4, 5, 6], 150
    for n in qs:
        _, text, marks = QUESTIONS[n - 1]
        y = printed(d, 90, y, "%d.  %s   (%d mark%s)" % (n, text, marks, "" if marks == 1 else "s"), 25)
        lines, ring = WRITES[n][answers[n]]
        if n == 4:
            y += 10
            for i, o in enumerate(OPTIONS4):
                printed(d, 150, y, o, 25)
                if i == ring:
                    layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
                    for k in range(2):
                        ld.ellipse((130 + k * 2, y - 12 + k, 238 - k * 2, y + 42 - k), outline=(24, 40, 110, 215), width=3)
                    img.alpha_composite(layer.rotate(rnd.uniform(-3, 3), center=(198, y + 15), resample=Image.BICUBIC))
                y += 48
            y += 14
        y += 18
        for line in lines:
            hand(img, 140 + rnd.randint(-6, 6), y, line, 44, rnd)
            y += 66
        y += 80 if pno == 1 else 110
    printed(d, W // 2 - 50, H - 78, "Page %d of 2" % pno, 20)
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    truth = draw_truth()
    for i, t in enumerate(truth):
        rnd = random.Random("class-of-40-%d" % i)
        for pno in (1, 2):
            photograph(page(pno, t["student"], t["questions"], rnd), rnd).save(
                os.path.join(out, "s%02d_p%d.jpg" % (i + 1, pno)), quality=86)
    json.dump({"title": TITLE, "level": "Year 9", "scheme": SCHEME,
               "questions": [{"n": n, "text": t + (" Options: " + "; ".join(OPTIONS4) if n == 4 else ""), "marks": m}
                             for n, t, m in QUESTIONS]},
              open(os.path.join(out, "exam.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump([{"paper": "s%02d" % (i + 1), **t} for i, t in enumerate(truth)],
              open(os.path.join(out, "truth.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("40 papers in", out)
