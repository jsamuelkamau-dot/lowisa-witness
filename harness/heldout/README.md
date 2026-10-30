# The held-out check of the Misconception Fingerprint

36 one-page papers in 10 topics, none of them in the marking prompt, each labelled **before** any run
(`items.py`): right work (must be marked mastered), ink that shows the wrong idea (must be named, and the name must
fit), ink that cannot tell which idea (must not be named: Lo asks), and adversarial ink (must not be marked mastered).

```bash
python harness/heldout/make_items.py /tmp/heldout          # the photographed papers (a handwriting font, simulated photo)
sh scripts/test.sh                                         # compiles the library into _build
MODEL_API_KEY=... escript harness/fingerprint_eval.escript /tmp/heldout /tmp/heldout.json
```

Three runs on 30 Oct 2026, one after each change (full output in `results/`):

| Expected | 1. Rule in the prompt only | 2. + the model asked for rivals | 3. **Rule enforced in code** |
|---|---|---|---|
| Right work, marked mastered | 10 of 10 | 10 of 10 | **10 of 10** |
| Adversarial ink, not mastered | 3 of 3 | 3 of 3 | **3 of 3** |
| Ambiguous ink: Lo asks | 9 of 11 | 8 of 11 | **10 of 11** |
| Clear ink: named right | 12 of 12 | 12 of 12 | **10 of 12** (2 asked first) |
| A wrong idea named | 0 | 0 | **0** |
| Cost / median time a paper | $0.45 / 8.8 s | $0.49 / 9.7 s | $0.49 / 9.9 s |

Asking the model for rivals did not help on its own (run 2): it listed none. What helped is a rule the code applies
whatever the model says (run 3): when the answer is a number and no quoted line shows a calculation, nothing is named
until the student has answered Lo.

**What these papers are not.** They use a handwriting font with a small wobble and a simulated phone photo; real
handwriting, real phones and real classrooms are harder. One run per paper here; the three demo learners were run five
times each (`evidence/misconceptions/runs.json`). "Named right" is decided by keywords written with each item, so a
right name worded unusually could be scored as wrong (none was); every reply is in `results/` to check by eye.
