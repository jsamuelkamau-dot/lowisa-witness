# Built during the hackathon (26 Oct – 4 Nov 2026)

Everything in this repository was written during the event. The kickoff, 26 Oct at 12:00 PM ET, was 27 Oct at 2:30 AM in
our time zone (Adelaide, UTC+10:30); the first commit is 27 Oct at 10:36 AM there, eight hours after it. See the commit
history. The table grows as the work lands. Code built this week inside LoWisa's own files is named in `host/README.md`; it is not copied here, so LoWisa's older code stays private.

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
| **The development set**: 36 papers in 10 topics the prompt never saw, labelled before the run; the rule in code was designed on it | `harness/heldout/`, `harness/fingerprint_eval.escript` | done 30 Oct |
| The teacher's gates: preview on by default, a level its self-check did not pass waits for the teacher, "completed" needs every lesson seen | `witness/src/witness_mastery.erl`, `witness/src/witness_api.erl` | done 30 Oct |
| Deleting a paper or an exam, for good: rows, pages, recordings, pictures, the clip, the student's pointer, the cached marking, the join code | `witness/src/witness_api.erl`, `desk/witness-desk.js` | done 30 Oct |
| The benchmark, its cases, its raw results and the script that recomputes every number | `harness/bench/` | committed 30 Oct (run 27–28 Oct) |
| Tests from a fresh clone, and CI | `scripts/test.sh`, `.github/workflows/test.yml` | done 30 Oct |
| **After the 12-judge panel (31 Oct)**: the evidence rule tightened in code: a quote must be in a line read from the page (small reading slips only), a calculation is an operation, an "=" or a comparison, and after Lo asks the evidence must be the ink or the student's own words | `witness/src/witness_mark.erl`, `witness/src/witness_fingerprint.erl` | done 31 Oct |
| The self-check is the server's: its verdict and the outline Muse Wonder played are bound to the level by `check_id`; lessons count only from that outline; Muse Wonder's two playthroughs and any false claim are kept for the teacher | `witness/src/witness_check.erl`, `witness/src/witness_mastery.erl`, `witness/src/witness_api.erl`, `desk/witness-desk.js` | done 31 Oct |
| Access closed: a photographing code separate from the join code; a name that joins after the photo waits for the teacher; the photographing phone reads nothing; the class list can be edited and joining closed; a daily ceiling on every route that calls a model; the design route only for the caller's own released level, with the server's scope and a per-question ceiling | `witness/src/witness_api.erl`, `desk/` | done 31 Oct |
| Lo's live turns read for safety before they reach a student; every student-written text marked as data in every prompt; students sent to class patterns as numbers | `witness/src/witness_guard.erl`, `witness/src/witness_text.erl`, `witness/src/witness_patterns.erl` | done 31 Oct |
| Conditional writes: concurrent joins all land, a paper deleted while marking stays deleted | `witness/src/witness_host.erl` (`update/3`), `witness/src/witness_api.erl`, LoWisa's edge host (named in `host/README.md`) | done 31 Oct |
| **The re-check**: a few days after "Turned around", a new problem on the same idea in a different structure, answered with the student's own number and working | `witness/src/witness_recheck.erl`, `phone/witness/WitnessScreen.tsx`, `desk/witness-desk.js` | done 31 Oct |
| One teacher action on many questions: accept the confident marks, send one challenge to a pattern group, issue "Turned around" after one review | `witness/src/witness_api.erl`, `desk/witness-desk.js` | done 31 Oct |
| A mastery level's practical task ends in a number the learner types, checked by the player | LoWisa's scene writer and player (named in `host/README.md`) | done 31 Oct |
| Structured output on every small JSON reply; prompt caching across the readings of one paper; explicit prices; Muse Spark Open on the photographed paper too | `witness/src/witness_meta.erl`, `witness/src/witness_photo.erl`, `witness/src/witness_open.erl` | done 31 Oct |
| Held-out v2 (53 papers, written before any run), the self-check and reason-judge evaluations, the effort ablation, the live API probe | `harness/heldout/items_v2.py`, `harness/selfcheck/`, `harness/reasons/`, `harness/probes/results-31oct/` | done 31 Oct |
| A local replay of the desk with no key; the privacy document | `demo/desk-server.js --replay`, `docs/privacy.md` | done 31 Oct |
| Lo's live turns fail closed: a turn the safety check could not read never reaches the student (after the 3 Nov judges' panel) | `witness/src/witness_api.erl` | done 3 Nov |
| Held-out v2 run again on the shipped code, beside its blind first run; which commit each result ran on | `harness/heldout/results/v2-on-shipped-code-3-runs.json`, `harness/PROVENANCE.md` | done 3 Nov |
| A real student's handwriting: three papers marked on the live product against his own teacher's marks, as photographed and with sideways pages upright (parent's consent; name and school blurred) | `evidence/real-handwriting/` | done 3 Nov |
