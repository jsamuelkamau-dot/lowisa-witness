# Which commit each result ran on

Every result file records the commit it ran on (`commit`) and whether `witness/src` had uncommitted changes (`dirty`).

On 2 Nov the history of this repository was rewritten once, before it was made public. Three files that copied code
out of LoWisa's private product were removed from every commit (see `host/README.md`). Nothing else changed, but each
commit got a new hash. A few result files still name the hash their run had at the time:

| Hash in the result file | The same commit now | What differs between them | Result files |
|---|---|---|---|
| `83d1c10` | `5712d5b` | only the three removed files under `host/`; `witness/src` and `harness/` are identical | `harness/selfcheck/results/selfcheck-3-runs.json`, `harness/reasons/results/reasons-applied-3-runs.json` |
| `85784ed` | `b529f24` | the same | `harness/heldout/results/v2-held-out-steps-rule-3-runs.json`, `harness/class/results/class-of-40.json`, `harness/bench/results/photo_on_head.json`, `harness/bench/results/line_placement.json` |
| `ce7fcce` | `ba83c3c` | the same | `harness/heldout/results/v2-held-out-explain-rule-3-runs.json`, `evidence/unseen-physics/hard-ask-papers-5-runs-new-rule.json` |

To check one: `git diff --stat 5712d5b b529f24` shows what changed between two runs, and `git show 5712d5b:witness/src/witness_mark.erl`
shows the rule a run used.

A run marked `"dirty": true` ran with uncommitted changes in `witness/src`. Those runs are reported as development
runs, never as the headline (see `harness/heldout/README.md`).
