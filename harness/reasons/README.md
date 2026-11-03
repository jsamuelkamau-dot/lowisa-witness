# The challenge's reason judge, measured

When a learner answers the teacher's challenge, Muse Spark judges whether their *reason* holds
(`witness_challenge:judge/3`). The harmful error is a false accept: a reason that does not hold, judged understood,
which would let "Turned around" through. `reasons.json` holds labelled reasons of five kinds (worked, explained, a rule
of thumb, the old idea, the right words with nothing behind them); `harness/reason_eval.escript` runs each three times.

| File | False accepts | False rejects |
|---|---|---|
| [`results/reasons-3-runs.json`](results/reasons-3-runs.json) (first version) | 12 of 36: every "right words only" reason was accepted | 0 of 24 |
| [`results/reasons-applied-3-runs.json`](results/reasons-applied-3-runs.json) (the rule applied in code, as shipped) | **0 of 36** | **0 of 24** |

```bash
MODEL_API_KEY=... escript harness/reason_eval.escript out.json 3
```
