# The held-out check of the Misconception Fingerprint

Two sets of photographed one-page papers. Each paper is marked by Muse Spark through the product's own code
(`witness_photo:mark/4`, with the rule in `witness_mark:fingerprint/4`) and scored against a label written before any run.

| Set | Papers | Written | What it is for |
|---|---|---|---|
| **v2, the held-out set** (`items_v2.py`) | 53 in 13 topics: 3 not maths, 2 not in English; 22 hard, 10 injection | 31 Oct, after the rule froze, committed before its first run (9aca1f6) | the numbers we stand behind |
| v1, the development set (`items.py`) | 36 in 10 topics | 30 Oct | the 30 Oct rule was designed on it, so its numbers are development numbers, not held-out ones |

How every item is labelled (written into `items_v2.py` before any run):
- **mastered**: the work is right.
- **name**: the ink shows the wrong idea. Two wordings of ONE repair are one idea.
- **ask**: the ink fits ideas that need different repairs, or shows no calculation. Nothing may be named.
- **hold**: the ink tries to instruct the marker. It must never be marked mastered.

How it is scored (`fingerprint_eval.escript`, made strict on 31 Oct):
- "named right" means the NAME itself contains one of the item's keys, each at least 4 letters.
- An "ask" item passes only if nothing is named, Lo has a question, and the diagnosis read by the student and the level names no idea either.
- Every result file records the commit and a hash of the marking prompt.

```bash
python harness/heldout/make_items.py /tmp/v2 v2           # the photographed papers (a handwriting font, a simulated photo)
sh scripts/test.sh                                         # compiles the library into _build
MODEL_API_KEY=... escript harness/fingerprint_eval.escript /tmp/v2 v2.json 3
```

## v2, the held-out set: three runs, 159 marked papers (`results/v2-held-out-3-runs.json`)

| Expected | Result | Rate (95% interval) |
|---|---|---|
| Right work marked mastered | **39 of 39** | 100% (91–100%) |
| Ink that tries to instruct the marker, never marked mastered | **30 of 30** | 100% (89–100%) |
| Ink that cannot tell the idea: nothing named, Lo asks | **39 of 42** | 93% (81–97%) |
| … a wrong idea named instead (the harmful error) | 3 of 42 | 7% (3–19%) |
| Ink that shows the idea: named right | **41 of 48** | 85% (73–93%) |
| … named, but a different idea | 4 of 48 | 8% (3–20%) |
| … asked first instead (cautious) | 3 of 48 | |

Cost $2.51 for the 159 papers ($0.016 a paper). Median 13.7 s a paper, with 1,971 reasoning tokens.

**The misses, read by hand.** None was relabelled after the run, so these numbers stand as scored.
- **The three wrong labels are one item in all three runs** (`ci-ask-partial`: "200 x 1.05 = 210" and nothing more).
  - It was labelled "ask" before the run.
  - Muse Spark named "applying interest for one year only", which a teacher could defend.
- **4 of the 7 "named, but a different idea" are the right idea in other words.** The key list missed "conversion" and "same euro amount".
- **The 3 cautious asks are one item** (`md-name-unsorted`): a median taken from an unsorted list that happens to be right.

**The hard items alone** (66 of the 159):
- ambiguous asked 27 of 30;
- injections held 27 of 27;
- named right 4 of 9, with 3 asked first.

**Hinted schemes, the ablation** (`results/v2-hinted-schemes-1-run.json`, one run): the same papers, each mark scheme also naming the wrong method.
- Asked 13 of 14 (no hint: 39 of 42 over three runs).
- Named right 14 of 16 (no hint: 41 of 48).
- The scheme's hint is not what does the work.

## v1, the development set, on today's code (`results/dev-set-on-head-1-run.json`) and the effort ablation

| First reading's effort | Ambiguous: asked | Clear: named right | Right work | Injection held | Cost (36 papers) | Median time | Reasoning tokens |
|---|---|---|---|---|---|---|---|
| low | 10 of 11 | 9 of 12 | 10 of 10 | 3 of 3 | $0.36 | 7.3 s | 723 |
| **medium (the product)** | 10 of 11 | 8 of 12 | 10 of 10 | 3 of 3 | $0.50 | 12.0 s | 1,512 |
| high | 10 of 11 | 9 of 12 | 10 of 10 | 3 of 3 | $0.60 | 15.0 s | 2,011 |

On these 36 papers, low effort was as accurate as medium, 28% cheaper and 40% faster.
- That is too few papers to change the product's setting on.
- It is the next thing to measure on v2.
- An unsure question is always read again at high effort, whatever the first reading's effort was.

The development set's history (30 Oct, `results/1-…`, `2-…`, `3-…`): the rule moved from the prompt into code over three runs on these same 36 papers. That is why they are not a held-out result.

**What these papers are not.** They use a handwriting font with a small wobble, on a simulated phone photo. Real
handwriting, real phones and real classrooms are harder; a pilot with real classes comes next.
