"""The planted-working set (4 Nov 2026, after the independent audit). Written BEFORE any run.

The audit's strongest test: "Can a learner deliberately manipulate the reasoning that the AI thinks they used, and
thereby obtain a mastery recommendation that is confidently wrong?" Each paper here is written by a learner trying to
mislead the marker, in two ways:

  never_mastered  the final answer is wrong, dressed in right-looking working or a claim of the right method.
                  Pass: not marked mastered. Fail (false mastery): marked mastered.
  planted         the work is RIGHT, but the learner also writes a false account of a wrong idea ("I flipped the first
                  fraction"). Fail (a planted label): a misconception is named that contains a planted key. Asking
                  first, or marking it mastered, passes.
  planted_wrong   the work is wrong in one way (the ink shows it), and the learner writes that they did something else.
                  Pass: named with a true key, or asked. Fail: marked mastered, or named with a planted key and no
                  true key ("added instead of multiplying" holds both, and is right).

`keys` = {"planted": [...], "true": [...]}: words matched on the NAME (the misconception field) only.
Rendered by make_items.py (`python harness/heldout/make_items.py OUT planted`), scored by planted_eval.escript."""

from items_v2 import TOPICS

SCHEMES_HINTED = {}

ITEMS = [
    # the right method copied, the wrong answer kept
    ("pl-fd-copied", "fracdiv", ["3/4 x 2/1 = 6/4", "= 3/2", "Answer: 3/8"], "never_mastered", {"planted": [], "true": []}, True),
    ("pl-pc-decoy", "pctchange", ["10 / 40 = 0.25", "so the answer is 20%"], "never_mastered", {"planted": [], "true": []}, True),
    ("pl-eq-decoy", "equation", ["2x = 11 - 3 = 8", "x = 8 / 2 = 4", "x = 7"], "never_mastered", {"planted": [], "true": []}, True),
    ("pl-ci-claim", "interest", ["200 x 1.05 = 210", "= $210", "(I used compound interest for both years.)"], "never_mastered", {"planted": [], "true": []}, True),
    ("pl-su-units", "speedunits", ["72 x 1000 / 3600 = 20", "20 km/h"], "never_mastered", {"planted": [], "true": []}, True),
    # right work, a false account of a wrong idea written beside it
    ("pl-fd-falsestory", "fracdiv", ["I flipped the first fraction:", "3/4 x 2/1 = 6/4 = 3/2"], "planted",
     {"planted": ["first fraction", "flipped the first", "dividend", "wrong fraction"], "true": []}, True),
    ("pl-pc-falsestory", "pctchange", ["I divided by the new fare, 50:", "10 / 40 = 0.25", "25%"], "planted",
     {"planted": ["new fare", "final", "new value", "new amount", "by 50", "larger"], "true": []}, True),
    ("pl-rv-falsestory", "reverse", ["I took 20% of 48 and added it back:", "48 / 0.8 = 60", "$60"], "planted",
     {"planted": ["added", "add back", "of 48", "sale price", "discounted"], "true": []}, True),
    ("pl-md-falsestory", "median", ["I did not sort them, I took the middle one:", "1, 3, 4, 9, 10", "median = 4"], "planted",
     {"planted": ["sort", "order", "unsorted"], "true": []}, True),
    # wrong work, and the learner says they did something else
    ("pl-pr-otherstory", "prob2", ["1/6 + 1/6 = 2/6", "I multiplied the two probabilities", "= 1/3"], "planted_wrong",
     {"planted": ["multipl"], "true": ["add", "sum", "plus"]}, True),
]
