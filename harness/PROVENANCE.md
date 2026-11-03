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
runs, never as the headline (see `harness/heldout/README.md`), with one exception, named here:

| Result file | Recorded | What it means |
|---|---|---|
| `harness/heldout/results/v2-held-out-3-runs.json`, v2's **blind first run** (31 Oct) | `ab0e88a`, dirty | It ran on the working copy before the evidence rule's next change was committed, so its exact code is not in the history. It is shown as the blind result *beside* the clean run on the code that ships (`v2-on-shipped-code-3-runs.json`, `0b7502c`, clean), which is the headline. |
| `evidence/unseen-physics/hard-ask-papers-5-runs-old-rule.json` (31 Oct) | `fatal: not a git repository`, dirty | It ran from a copy of the old rule outside this repository, to compare it with the new rule; the commit could not be read there. It is a development run. |
| `harness/probes/results-31oct/`, `harness/probes/results-03nov/` | `run_at` only | Live probes of Meta's API; no marking code is measured. |

## The tagged code, `v1.0-code` (3 Nov)

Every headline set was run again on one tagged commit, `v1.0-code` (`8d3b44a`; its `witness/` is the same as `d221731`,
live as edge vb1104f): two readings must agree before "Accept all", and the held note says "how it was reached".

| Result | Where it ran | Note |
|---|---|---|
| `evidence/real-handwriting/results/condition-c-on-v1.0-code-3-runs.json` | the live edge vb1104f | three runs |
| `evidence/real-handwriting/results/written-answers-on-v1.0-code-3-runs.json` | the live edge vb1104f | three runs |
| `harness/heldout/results/v2-on-v1.0-code-3-runs.json` | locally, `fingerprint_eval.escript` | its meta says `7475ba1`: a later commit (the film) made while it ran; `git diff 8d3b44a 7475ba1 -- witness` is empty |
| `evidence/unseen-physics/v1.0-code-3-runs.json` | locally, `local_mark.escript` | with a scheme once, without twice (one is the marking the film shows) |

## The code live now, `v1.0.1-code` (3 Nov)

`v1.0.1-code` (`29c0ddc`), live as edge vb1104h: `v1.0-code` plus the two answer-comparison fixes (numbers must be the
same numbers; the same letter with different words is not the same answer), ten minutes a reading for open weights, and
the challenge push without a deprecated catch. One run each on it on 3 Nov (`*-on-v1.0.1-code-1-run.json`), then two more
on 4 Nov; the three together are `evidence/real-handwriting/results/condition-c-on-v1.0.1-code-3-runs.json` and
`written-answers-on-v1.0.1-code-3-runs.json` (the live edge, run 1 identical to the one-run files), and
`harness/heldout/results/v2-on-v1.0.1-code-3-runs.json` (locally; runs 2 and 3 ran at `5b6ba60`, whose `witness/` is
identical to `29c0ddc`, from beams compiled before `witness/src` was next edited, which is why that run's file says
dirty). In written run 3 one paper came back "could not be read" (the product asked for it again, nothing marked);
the same photos were sent again, and the failure is recorded in the file (`not_read_first_time`). The Muse Spark Open runs after 29c0ddc used its ten-minute limit (`harness/open/`).
