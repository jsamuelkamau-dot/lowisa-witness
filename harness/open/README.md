# Muse Spark Open, on partner inference

Muse Spark Open (Meta's open-weight release) on **Baseten's Model API** (`meta-models/muse-spark-open`,
`https://inference.baseten.co/v1`), through the product's own photo path: `witness_photo:mark/4` with each reading sent
through `witness_open:read_content/3`, exactly as `witness_api` does when an exam is marked on open weights. Run
locally on 3 Nov 2026 ([`open_run.escript`](open_run.escript)); the live edge's switch for it was not turned on.
Recompute everything: `python3 harness/open/score.py`.

| | Muse Spark Open (Baseten) | Muse Spark 1.3 (Meta's API), the same papers |
|---|---|---|
| The film's physics paper, every marking decision | **30 of 30 in each of 5 runs** (3 without a scheme, 2 with), 6/30 every run | 30 of 30 in 9 of 9 runs |
| The real student's English paper (pages turned upright) | 29 of 30 agree with his teacher; no wrong idea named | 29 of 30 (condition B) |
| The real student's science paper | 46 of 49; no wrong idea named | 47 of 49 (condition B) |
| The real student's maths paper | 27 and 28 of 30 agree; **5 of his teacher's 6 wrong answers caught** in both runs; no wrong idea named (it failed twice first, on the 5-minute limit) | 29 of 30 (condition B) |
| Runs completed | 9 of 12: all 3 since the limit per call was raised to 10 minutes (`v1.0.1-code`); before it, 2 timed out and 1 reply was not a marking | all, on these papers |
| Cost | $0.05–0.17 a paper; $1.29 for every completed call | $0.05–0.11 a physics paper |

**Against the baseline.** Marking every answer right would agree on 28 of 30 (English) and 47 of 49 (science), so on
these two papers the agreement says little; what counts is that open weights caught 1 of his 2 wrong answers on each
and named no wrong idea. It ran locally through the product's code; the edge's switch for open weights stays off.

**What it shows.** Meta's open weights, served by a partner, mark the same paper the same way through the same code,
and the evidence rule holds on them: no wrong idea was named on any answer they did not accept. **Reliability:** the open
model writes longer readings (up to 12,000 tokens, half of them reasoning), so a long paper passed the 5-minute limit
per call twice; with 10 minutes (`witness_open`, `TIMEOUT_MS`, in `v1.0.1-code`) the next 3 runs all completed, the
maths paper in 37–103 s. One earlier reply was not a marking. Three runs since the change is few. The cost above is an upper bound: every input token is priced at $1.25, although Baseten charges
cached input at $0.15.
