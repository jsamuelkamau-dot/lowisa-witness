# Muse Wonder's self-check, measured

Before a learner sees a mastery level, Muse Wonder plays it twice through the product's own code
(`witness_check:run/2`): once as the learner still holding the wrong idea, once as a learner who has it right, and it
checks every claim the level makes. A level that would teach something false, or never catch the wrong idea, is held
and rewritten.

`levels.json` holds twenty levels: clean ones, and ones with one planted fault each (a false claim, no catch of the
wrong idea, a last task that is not a real work task, a level about another idea). `selfcheck_eval.escript` runs each
three times.

| File | Result |
|---|---|
| [`results/selfcheck-3-runs.json`](results/selfcheck-3-runs.json) (the code that ships) | planted faults held **30 of 30**, the planted fault named 30 of 30 (false claims 9 of 9); clean levels passed **30 of 30**; $3.04 |
| [`results/selfcheck-first-levels-3-runs.json`](results/selfcheck-first-levels-3-runs.json) (the first version) | faults held 30 of 30, but clean levels passed only 14 of 30: the check was too strict, and was fixed before the run above |

```bash
MODEL_API_KEY=... escript harness/selfcheck_eval.escript out.json 3
```
