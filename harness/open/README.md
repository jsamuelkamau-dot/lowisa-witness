# Muse Spark Open, on partner inference

Muse Spark Open (Meta's open-weight release) on **Baseten's Model API** (`meta-models/muse-spark-open`,
`https://inference.baseten.co/v1`), through the product's own photo path: `witness_photo:mark/4` with each reading sent
through `witness_open:read_content/3`, exactly as `witness_api` does when an exam is marked on open weights. Run
locally on 3 Nov 2026 ([`open_run.escript`](open_run.escript)); the live edge's switch for it was not turned on.
Recompute everything: `python3 harness/open/score.py`.

| | Muse Spark Open (Baseten) | Muse Spark 1.3 (Meta's API), the same papers |
|---|---|---|
| The film's physics paper, every marking decision | **30 of 30 in each of 4 runs** (3 without a scheme, 1 with), 6/30 every run | 30 of 30 in 9 of 9 runs |
| The real student's English paper (pages turned upright) | 29 of 30 agree with his teacher; no wrong idea named | 29 of 30 (condition B) |
| The real student's science paper | 46 of 49; no wrong idea named | 47 of 49 (condition B) |
| The real student's maths paper | **failed twice**: one reading ran past the 5-minute limit per call, then a reply that was not a marking | 29 of 30 (condition B) |
| Failed runs | 3 of 9 (one physics run with a scheme timed out too) | none on these papers |
| Cost | $0.05–0.17 a paper; $0.90 for every completed call | $0.05–0.11 a physics paper |

**What it shows.** Meta's open weights, served by a partner, mark the same paper the same way through the same code,
and the evidence rule holds on them: no wrong idea was named on any answer they did not accept. **What it does not
show yet:** reliability. The open model writes longer readings (up to 12,000 tokens, half of them reasoning), so a
long paper can pass the 5-minute limit per call (`witness_open`, `TIMEOUT_MS`), and one of nine runs got a reply that
was not a marking. The cost above is an upper bound: every input token is priced at $1.25, although Baseten charges
cached input at $0.15.
