# From Exam to Mastery: one page for judges

**What it is.** A teacher photographs a finished exam. Meta's models mark every answer and read how the learner reached
it, from their own handwriting. Every question not mastered becomes a level in their Mastery Plan. In that level the
learner does the thinking, it ends in a real task, and the teacher decides when it is turned around. It is not a
chatbot: the learner is never handed an answer.

**Watch:** the 2:59 demo, [youtu.be/s4DtrRzyQsI](https://youtu.be/s4DtrRzyQsI).
**Try it in a minute, no account and no key:** `node demo/desk-server.js --replay`, then http://localhost:4747.
**Run the tests:** `sh scripts/test.sh` (Erlang/OTP 27); every push runs them in GitHub Actions.

## The three strongest proofs

| Proof | Result | Recompute it |
|---|---|---|
| **One real Grade 5 learner against his own teacher**: real handwriting; the teacher is not on our team | Multiple choice, 109 questions × 3 runs: 6 or 7 of the teacher's 10 wrong answers caught; no wrong idea named on any answer it did not accept | `python3 evidence/real-handwriting/score.py` |
| **It asks instead of guessing**: 53 held-out papers × 3 runs (simulated handwriting) | Where the ink cannot show the idea, Lo asks first 39 of 42. A learner planting misleading working never had the planted idea named, 30 of 30 | [`harness/heldout/`](harness/heldout/) |
| **Mark your own exam live**, with your own Meta key and no LoWisa account | A 30-question paper marked in 92 s for about $0.07 | `MODEL_API_KEY=... escript harness/mark_my_paper.escript <exam> <page.jpg>` |

## Checked live on the production server (4 Nov)

- **Lo never hands over the exam answer**: 18 of 18 live turns, including a tampered app told to give it.
- **An online-safety lesson is taught**, not blocked. A false stop the run found ("they might say 'don't tell your
  parents'") was fixed the same day.
- **An unreadable photo is never marked**: both came back "photograph it again", with nothing marked.
- **One click accepts only marks at least 0.95 sure**, the server's money holds settle, and expired rows read as gone.
  What one click takes, with and without a mark scheme: [`docs/marking-policy.md`](docs/marking-policy.md).

Details are in [`evidence/live-checks/`](evidence/live-checks/README.md).

## Exact versions

| What | Version |
|---|---|
| Code the measurements ran on | tag `v1.0.1-code` (three runs of every real set); earlier runs in [`harness/PROVENANCE.md`](harness/PROVENANCE.md) |
| Production server (Witness library) | `v1.0.2-code` plus the audit fixes in README section 13, edge vb1104p (live 4 Nov 09:12 UTC; each edge release is listed there) |
| Phone apps in the stores | LoWisa 1.10.4 (Google Play and the App Store); the phone fixes in README 17.1 arrive with the next release |
| Desktop app | LoWisa desktop 0.9.33; the desk's wording fixes arrive with the next desktop release |

## What is proven, and what is not yet

- **Proven here**: the marking, the diagnosis, asking before naming an idea, resistance to misleading work, levels
  built and checked, and the safety rules above.
- **Measured, with limits**: on real handwriting, one learner so far. On his written answers, agreement is no better
  than marking everything right (36–38 of 42 against 38). The held-out set is simulated handwriting that we wrote and
  have re-run.
- **Not yet shown**: that the product strengthens learning lastingly, across many learners. That needs a controlled
  study, whose design is written down before it runs: [`docs/STUDY-PLAN.md`](docs/STUDY-PLAN.md). One completed level
  or one re-check is evidence of a step, not of lasting mastery.
- **A risk that stays until the next phone release**: the store apps cannot apply the fail-closed face rule. Instead,
  the server refuses their desk videos, so those students' papers are photographed.

Every limit is in README section 16. **Licence:** [PolyForm Strict 1.0.0](LICENSE), with
[an added permission for judges](JUDGING-PERMISSION.md) to do whatever verification needs.
