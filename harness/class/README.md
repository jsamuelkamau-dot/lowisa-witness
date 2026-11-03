# A class of 40

`make_class.py` writes 40 sample students' two-page maths papers (six questions each) with the truth for every answer
written before the run; `class_run.escript` marks all 40 the way the product does (`witness_photo:mark/4`), then groups
every question not mastered into class patterns with Muse Wonder (`witness_patterns:run/3`).

[`results/class-of-40.json`](results/class-of-40.json): all 40 marked in 32 s and the class patterns ready a minute
after the last photo, for $1.01 in all; 40 of 40 names read right; an idea named on 48 of the 51 wrong answers (each
question's row says which idea was drawn into it and which was named), and all 5 answers with no working asked about,
with nothing named. These are sample papers, not real students.

```bash
python harness/class/make_class.py OUT_DIR
MODEL_API_KEY=... escript harness/class/class_run.escript OUT_DIR out.json
```
