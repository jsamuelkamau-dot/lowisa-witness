# Witness

**From a failed question to real-world mastery.**

For a long time, failing a question has been read as "you can't do this". Witness turns each failed question into
the next thing a student masters:

1. A phone looks down at the desk while the student works on paper.
2. Meta's models mark how each answer was made, not only what was written.
3. The teacher writes what to focus on.
4. Each failed question becomes one mastery level, made for that student.
5. The teacher signs off the mastery.

It works for any subject and any level, anywhere.

Built for the Meta Global AI Developer Hackathon (27 Oct – 4 Nov 2026) by the LoWisa team, as a new part of
[LoWisa](https://lowisa.dev).

## The loop

```
Sit      the student works on paper; a phone watches the desk (paper and hands only)
Mark     SAM 3.1 follows the ink → the order each answer was written in
         Muse Spark marks the answer and the path:
           mastered · right answer, wrong thinking · part way · not yet
         plus a one-sentence diagnosis and the second it happened
Check    a Muse Wonder examiner asks about the student's own step; Voice Transcribe hears the reply
Desk     the teacher reviews (least certain first) and writes a focus note on each failed question
Plan     one mastery level per failed question, checked by an agent before it reaches the student
Master   the student plays the level; "ask my teacher" sits on every step
Verify   only if the teacher asks for it: explain back to Lo, a fresh question watched again,
         or explain back to the teacher
Badge    the teacher issues "Turned around"
```

## Built during the hackathon

Everything in this repository was written between 27 Oct and 4 Nov 2026; see the commit history. The table grows
as the work lands.

| Part | Where | Status |
|---|---|---|
| Day-1 probe: SAM 3.1 ink tracking and Muse Spark path marking on video | `harness/probes/` | done 27 Oct |
| Secret scan before every push | `scripts/secret_scan.py` | done 27 Oct |
| Meta Model API client: chat (OpenAI-shaped), Files, SAM 3.1 video, Muse Spark video reading, cost per call | `witness/src/witness_meta.erl` | done 27 Oct |
| SAM 3.1 answer parser: records, tracks, order of appearance | `witness/src/witness_sam.erl` | done 27 Oct |
| Live check through the Erlang client | `harness/live_check.escript` | done 27 Oct |
| Sync into a host app, and the integration points | `scripts/sync_to_host.sh`, `docs/integration.md` | done 27 Oct |
| Frame times from the clip itself (variable-rate phone video) | `witness/src/witness_mp4.erl` | done 27 Oct |
| Ink timeline: SAM's written lines (tracked forward) meet Spark's steps, in page order | `witness/src/witness_timeline.erl` | done 27 Oct |
| Marking the path: four results, diagnosis, the moment, confidence | `witness/src/witness_mark.erl` | done 27 Oct |
| One sitting end to end (SAM and Spark at the same time, cost) | `witness/src/witness_sitting.erl`, `harness/sitting_check.escript` | done 27 Oct |
| Sitting endpoints: signed upload from the phone, marking off the request, the clip dropped after | `witness/src/witness_api.erl` | done 27 Oct |
| The host interface (accounts, storage, money and keys stay the host's) | `witness/src/witness_host.erl` | done 27 Oct |
| Piles for teachers: one exam's papers, the review queue (least certain first), the teacher's word beside the model's, focus notes, release | `witness/src/witness_api.erl` | done 27 Oct |

## What existed before (not in this repository)

LoWisa existed before the event. These parts are used by Witness but were built earlier. They are named here so
judges can tell old from new; their code is not part of this repository.

- The LoWisa phone app, desktop IDE, accounts, credits and metering.
- The Master any topic level builder and the level format: lessons, beats, first look, halfway twist and main run
  animations, Lo asks, Insight episodes, flashcards and A4 notes.
- Lo's voice, the scene player and the lesson player.
- The school dashboard, team roles and the school wallet.
- Earlier exam photo capture and marking (on other providers).

See `docs/existed-before.md` and `docs/integration.md` for how Witness plugs into them.

## Meta models and their jobs

| Job | Model |
|---|---|
| Follow the page and the ink through the video | SAM 3.1 |
| Read the video, mark the path, diagnose | Muse Spark 1.3 |
| Examiner, mastery-level agent, self-check | Muse Wonder |
| Hear spoken replies (25 languages, mixed languages) | Muse Voice Transcribe |
| Art for the level's real-world setting | Muse Image |
| The same reading on open weights | Muse Spark Open |

## Running the probe

```bash
MODEL_API_KEY=... python harness/probes/meta_probe.py your-clip.mp4
```

No keys, learner data or recordings are ever committed. `scripts/secret_scan.py` runs before every push.

## Licence

MIT
