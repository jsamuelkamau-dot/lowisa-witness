# Built during the hackathon (26 Oct – 4 Nov 2026)

Everything in this repository was written during the event: the build began on 27 Oct at 3:30 AM in our time zone,
which is the 26 Oct 12:00 PM ET kickoff; see the commit history. The table grows as the work lands.

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
| Join codes: a student enters the teacher's code on their phone and records their own paper into the teacher's exam; they see their marks once released | `witness/src/witness_api.erl` | done 27 Oct |
| The phone: join code, record the desk (up to ten minutes) or choose a video, signed upload, marking, "my papers" in words that never say failed | `phone/witness/net.ts`, `phone/witness/WitnessScreen.tsx` | done 27 Oct |
| The Mastery Plan: one level per question not mastered, built by LoWisa's existing level builder in a one-level mastery mode, every design call on Muse Spark, from the student's own working, the diagnosis and the teacher's focus note | `phone/witness/mastery.ts` (the builder's mastery mode is LoWisa's, named in docs/existed-before.md) | done 27 Oct |
| The self-check: Muse Wonder plays each mastery level as the student who still holds the misconception and as one who has it right; a level passes only when the first is caught and the second clears, else it names what to change and the level is written again | `witness/src/witness_check.erl`, `phone/witness/mastery.ts` | done 27 Oct |
| After release: the level's progress, ask-my-teacher threads, verification only when the teacher asks (explain back to Lo, judged by Muse Spark; a fresh paper; explain back to the teacher), and the teacher-issued "Turned around" badge | `witness/src/witness_mastery.erl`, `witness/src/witness_api.erl` | done 27 Oct |
| The Exam Desk (desktop): exams, papers, the review queue, a replay of how each answer was written, the diagnosis at its moment, the teacher's result, marks and focus note, release | `desk/witness-desk.js`, `scripts/sync_desk.sh` | done 27 Oct |

| The examiner: as soon as a paper is marked, Muse Wonder asks the student about at most two steps they wrote themselves; the student answers out loud (Muse Voice Transcribe) or in writing, and Muse Spark judges whether it is their own reasoning and whether they now understand | `witness/src/witness_examiner.erl`, `phone/witness/Examiner.tsx` | done 27 Oct |
| The corrected step: Muse Spark writes the corrected working and Muse Image draws it on lined paper, the changed step underlined | `witness/src/witness_draw.erl` | done 27 Oct |
| The teacher's spoken comment written down as feedback (Voice Transcribe's file door; ffmpeg makes the WAV it takes) | `witness/src/witness_meta.erl`, `witness/src/witness_media.erl` | done 27 Oct |
| The Proof of Thinking record: dated; every answer's steps and times, the marks and confidence beside the teacher's word, the examiner's questions and answers, a still of the desk at each moment that matters; the video itself deleted | `witness/src/witness_proof.erl`, `phone/witness/Proof.tsx` | done 27 Oct |
| The student's own replay, stopping at the moment the thinking went wrong | `phone/witness/Proof.tsx` | done 27 Oct |
| Practical mode: a practical task marked step by step against the teacher's procedure, SAM following the hands and the apparatus | `witness/src/witness_mark.erl`, `witness/src/witness_sitting.erl` | done 27 Oct |
| A fresh question on paper, watched again: the teacher writes it, the student films it, its marking comes back onto the question it checks | `witness/src/witness_api.erl`, `witness/src/witness_mastery.erl` | done 27 Oct |
| The pilot's numbers, measured: agreement with the teacher, wrong-thinking catches the teacher kept, marking seconds, the teacher's seconds per paper | `witness/src/witness_measure.erl` | done 27 Oct |
| Marking on open weights: Muse Spark Open through any OpenAI-compatible endpoint, the same prompt and result | `witness/src/witness_open.erl` | built 27 Oct; live through Meta's endpoint, the hosted open-weight key pending |
| True clip times: SAM's sampled frames scaled onto the clip's own frame table, read in byte ranges from the stored clip | `witness/src/witness_mp4.erl` | done 27 Oct |
| The Exam to Mastery flow: one phone photographs each finished paper page by page; the name read from the paper finds its student on the class list; each written line placed on its own ink on the photographed page (pen told from print by colour), so the student's own step is cut from their paper | `witness/src/witness_photo.erl`, `witness/src/witness_page.erl`, `witness/src/witness_names.erl` | done 29–30 Oct |
| The exam read from the teacher's own file (photo or PDF of the paper and its scheme) by Muse Spark | `witness/src/witness_read.erl` | done 28 Oct |
| Class patterns: Muse Wonder groups the class's misconceptions, what to reteach tomorrow, questions for the next exam | `witness/src/witness_patterns.erl` | done 28 Oct |
| Muse Spark's badge recommendation from all the evidence (the teacher decides) | `witness/src/witness_recommend.erl` | done 28 Oct |
| **The Misconception Fingerprint**: the reasoning that produced each answer, the evidence quoted from the ink, the misconception named only on enough evidence, the intervention; otherwise Lo asks a diagnostic question, out loud, before the level is built | `witness/src/witness_mark.erl`, `witness/src/witness_fingerprint.erl`, `phone/witness/WitnessScreen.tsx`, `desk/witness-desk.js` | done 30 Oct |
| **The teacher's new challenge**: the same idea in a new situation (drafted by Muse Spark, edited by the teacher), answered on the phone with a reason, the reason read by Muse Spark for the teacher | `witness/src/witness_challenge.erl`, `phone/witness/WitnessScreen.tsx`, `desk/witness-desk.js` | done 30 Oct |
| **The rule in code, after the judges' panel**: evidence must be the student's ink, no name while Lo asks (the guess kept for the teacher), a numeric answer needs a worked line, a rival holds the name; the settled reading becomes the diagnosis everything after it reads; the demo answers taken out of the prompt | `witness/src/witness_mark.erl`, `witness/src/witness_fingerprint.erl`, `phone/witness/mastery.ts` | done 30 Oct |
| **The held-out check**: 36 papers in 10 topics the prompt never saw, labelled before the run, three runs | `harness/heldout/`, `harness/fingerprint_eval.escript` | done 30 Oct |
| The teacher's gates: preview on by default, a level its self-check did not pass waits for the teacher, "completed" needs every lesson seen | `witness/src/witness_mastery.erl`, `witness/src/witness_api.erl` | done 30 Oct |
| Deleting a paper or an exam, for good: rows, pages, recordings, pictures, the clip, the student's pointer, the cached marking, the join code | `witness/src/witness_api.erl`, `desk/witness-desk.js` | done 30 Oct |
| The benchmark, its cases, its raw results and the script that recomputes every number | `harness/bench/` | committed 30 Oct (run 27–28 Oct) |
| Tests from a fresh clone, and CI | `scripts/test.sh`, `.github/workflows/test.yml` | done 30 Oct |
