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
- **One click accepts only marks at least 0.95 sure, and only on an exam with a mark scheme the teacher approved**
  (since edge vb1105a: where the paper has none, Muse Spark drafts one for the teacher to check; since vb1105b a
  draft counts only once the teacher approves it explicitly, with the time, the teacher and the scheme's SHA-256
  recorded; the desk's approval box comes with the next desktop release), the server's money holds settle, and expired rows read as gone. What one click takes: [`docs/marking-policy.md`](docs/marking-policy.md).
- **20 of 20 of Lo's turns fired together on one teacher's wallet were paid** (after two fixes the live checks found).

Details are in [`evidence/live-checks/`](evidence/live-checks/README.md).

## Exact versions

| What | Version |
|---|---|
| Code the measurements ran on | tag `v1.0.1-code` (three runs of every real set); earlier runs in [`harness/PROVENANCE.md`](harness/PROVENANCE.md) |
| Production server (Witness library) | `v1.0.2-code` plus the audit fixes in README section 13, edge vb1105b (live 5 Nov, 00:42 UTC: a drafted scheme's explicit approval; vb1105a, 21:30 UTC on 4 Nov: the drafted mark scheme and the stricter face look; each edge release is listed there) |
| Phone apps in the stores | **Google Play: LoWisa 1.10.5** (published 4 Nov), with the phone fixes in README 17.1; Android phones on 1.10.4 are offered the update. **App Store: LoWisa 1.10.5** (released 4 Nov, 21:37 UTC) |
| Desktop app | **LoWisa desktop 0.9.34** (released 4 Nov, Windows, macOS and Linux), with the desk's fixes in README 17.1 |
| This repository's history | Republished fresh on 4 Nov 2026 with every commit kept (same files and dates); the hashes in these files are the original repository's, mapped in [`DEVELOPMENT-PROVENANCE.md`](DEVELOPMENT-PROVENANCE.md) |

## What is proven, and what is not yet

- **Proven here**: the marking, the diagnosis, asking before naming an idea, resistance to misleading work, levels
  built and checked, and the safety rules above.
- **Marking is not perfect, so the teacher decides.** On the real learner's multiple-choice papers, 0 to 2 of the
  marks one click accepted at 0.95 still called a wrong answer right (no mark scheme was given). **Since 5 Nov one
  click needs a scheme the teacher approved**, so on those papers the teacher checks every mark; on the unseen physics
  paper, marked against Muse Spark's drafted scheme, 30 of 30 decisions were right and nothing wrong was accepted in one
  click. An approved scheme removes a wrong key, not a misread. Nothing reaches a student until the teacher releases it.
- **Measured, with limits**: on real handwriting, one learner so far. On his written answers, agreement is no better
  than marking everything right (36–38 of 42 against 38). The held-out set is simulated handwriting that we wrote and
  have re-run.
- **Not yet shown**: that the product strengthens learning lastingly, across many learners. That needs a controlled
  study, whose design is written down before it runs: [`docs/STUDY-PLAN.md`](docs/STUDY-PLAN.md). One completed level
  or one re-check is evidence of a step, not of lasting mastery.
- **Desk video is checked twice, not made impossible.** Apps before 1.10.5 cannot apply the fail-closed face rule, so
  the server refuses their desk videos and those papers are photographed. 1.10.5 (Google Play and the App Store) covers faces on Android and says so; on iPhone it offers no desk filming. Since edge vb1104r the server no longer relies on that statement: it looks for faces in every desk
  video itself (SAM 3.1) and deletes a video with one unmarked, keeping nothing from it (8 of 8 face clips refused,
  8 of 8 face-free clips cleared, [`harness/face/`](harness/face/README.md)). A modified app's video still reaches the
  private store before the look deletes it, and a face shown for under a fifth of a second can still be missed (the look takes five frames a second since edge
  vb1105a, and a look that cannot cover the whole video refuses it). The main way in,
  photographing the finished paper, films no one.

Every limit is in README section 16. **Licence:** [PolyForm Strict 1.0.0](LICENSE), with
[an added permission for judges](JUDGING-PERMISSION.md) to do whatever verification needs.
