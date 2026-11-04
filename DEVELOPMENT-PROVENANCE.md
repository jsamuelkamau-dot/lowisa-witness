# Development provenance

**Why this repository is new.** On 4 Nov 2026, just before submission, From Exam to Mastery was republished here as
a fresh GitHub repository at the same address. The earlier history had been rewritten twice: on 2 Nov, to take out
three files that copied older LoWisa code, and on 4 Nov, to take out a child's first name, two old exam codes and
LoWisa's earlier level-builder lines ([`harness/PROVENANCE.md`](harness/PROVENANCE.md)). GitHub keeps commits it has
seen reachable through a repository's activity record, even after history is rewritten. A fresh repository holds
only the clean commits.

**What is the same.** Every commit from the original repository is here, in the same order. Each one has:
- the same files, with an identical git tree hash (listed below, so anyone can check);
- the same author and date;
- the same message, except that a trailing co-author line was removed.

The tags `v1.0-code`, `v1.0.1-code` and `v1.0.2-code` point at the same trees as before. Every measurement that
names one of them ran on exactly that code.

**What is different.**
- **New hashes.** Every commit has a new hash, because its message changed. The hashes named in the README, the docs
  and the result files are the original repository's. The table below gives each one's hash here.
- **A new GitHub date.** GitHub's own dates for this repository start on 4 Nov. The original repository is kept
  private as an archive, and two dates there are not written by our machine: GitHub created it on **27 Oct 2026 at
  00:06 UTC** (26 Oct, 8:06 PM ET, eight hours after kickoff), and its GitHub Actions history runs from **3 Nov**
  (41 runs to 4 Nov). On request, a judge can be given read access to the archive to check both.
- **Commit dates are not proof.** Commit dates, here and in the archive, are written by our own machine, so on
  their own they prove nothing. What a fresh repository cannot carry over, we state here rather than claim.

## Every commit: original hash → hash here

To check any row, `git rev-parse <hash here>^{tree}` prints the tree hash, which is the same as the original's.

| Original | Here | Tree | Author date | Commit |
|---|---|---|---|---|
| `a41d17b` | `fee9312` | `1b105c2` | 2026-10-27 10:36 +1030 | Day 1: repo, secret scan, Meta video probe (SAM 3.1 ink tracking, Muse Spark path marking) |
| `59e4594` | `d162cd9` | `21b4789` | 2026-10-27 10:36 +1030 | Keep line endings LF |
| `17fdf58` | `be0dece` | `2d9e05d` | 2026-10-27 10:42 +1030 | Meta client and SAM parser in Erlang, with tests and a live check; day-1 findings |
| `227f667` | `060205d` | `0e08a8e` | 2026-10-27 10:55 +1030 | Sync script and integration points |
| `f2a2dc0` | `795651e` | `ae10a76` | 2026-10-27 11:06 +1030 | Ink timeline, path marking and the whole sitting: SAM lines meet Spark steps in page order; four results, d... |
| `afe2bee` | `7123bc8` | `c63925c` | 2026-10-27 11:13 +1030 | Sitting endpoints and the host interface; Meta reads the clip from a signed link |
| `430d950` | `e0e387a` | `92451e1` | 2026-10-27 11:40 +1030 | Piles: a teacher's exam with its papers, the review queue, the teacher's word and focus notes, release |
| `86d0fa5` | `e9fb223` | `72d02ac` | 2026-10-27 11:55 +1030 | The Exam Desk for the desktop: exams, papers, review queue, replay of the writing, the teacher's word, release |
| `1127e5b` | `801ade9` | `7c29379` | 2026-10-27 12:04 +1030 | SAM box fields map to fixed atoms (a model's field name never becomes an atom) |
| `044b653` | `a638ca7` | `f2bcc1f` | 2026-10-27 12:08 +1030 | Join codes: students record their own paper into a teacher's exam; the desk shows the code; the desk demo page |
| `5919d8d` | `368536a` | `6350cca` | 2026-10-27 12:40 +1030 | Prompts are UTF-8 in any script (a question with ÷ failed every sitting of its exam, live); the phone's Wi... |
| `9a64a89` | `c83ab5b` | `8be53c5` | 2026-10-27 12:49 +1030 | Review queue: what needs the teacher first; steps copy the ink; desk deep links for the demo; Open instead ... |
| `5831897` | `1ad7124` | `d51785d` | 2026-10-27 13:02 +1030 | The Mastery Plan on the phone: one level per question not mastered, built by the existing level builder in ... |
| `cbddc02` | `81b2ffd` | `5bc096b` | 2026-10-27 13:42 +1030 | The self-check: Muse Wonder plays a mastery level as both students; live findings |
| `18be248` | `4367ff6` | `afb1cff` | 2026-10-27 15:39 +1030 | The design door: a mastery level's design calls on Muse Spark, paid through the host (the managed-AI path's... |
| `c880382` | `3a6efd5` | `6004b15` | 2026-10-27 15:48 +1030 | Phone: a failed mastery build says what to tap here, not the builder's own button |
| `0045345` | `267507b` | `1ea7fc3` | 2026-10-27 15:51 +1030 | After release: mastery progress, ask my teacher, teacher-chosen verification (explain back to Lo judged by ... |
| `bf2f993` | `c0baa95` | `8f2e1a5` | 2026-10-27 15:52 +1030 | The desk's mastery panel: the level's state, the thread and a reply, the teacher's optional checks, the exp... |
| `54d3a1f` | `56d4c88` | `aa79bba` | 2026-10-27 15:57 +1030 | Phone after the level: built and completed reported, only the checks the teacher asked for, Lo's next quest... |
| `0ad8d19` | `5f7083b` | `79f1f56` | 2026-10-27 16:02 +1030 | Mastery levels end in a real task done at work with the idea; the self-check asks for it (owner: tie master... |
| `0108a06` | `c7838e6` | `7a5dcc5` | 2026-10-27 16:26 +1030 | Phone: the self-check has its own progress line |
| `5f73988` | `9b3c8c7` | `3cc4b9f` | 2026-10-27 17:13 +1030 | The self-check reads the level that is kept: the last rewrite is checked too, and a level that still fails ... |
| `f6ca404` | `c7a6e40` | `a675251` | 2026-10-27 17:35 +1030 | A fresh question on paper, watched again: the teacher writes it, the student films it, its marking comes ba... |
| `8a8bd1c` | `d6db15a` | `13b4c61` | 2026-10-27 17:56 +1030 | Frame times of an uploaded clip from its own table, read in byte ranges (live: a guessed 30 fps put every l... |
| `b18e7e6` | `e357128` | `2f6f255` | 2026-10-27 18:04 +1030 | SAM's frames are the ones it sampled: scale them onto the clip's table (live, against the recording: 13.7 s... |
| `8f6e0e3` | `905d9ae` | `318ab4a` | 2026-10-27 18:45 +1030 | Everything in the plan: Muse Image draws the corrected step; Voice Transcribe writes down the teacher's spo... |
| `2702aa7` | `2631669` | `d2bea53` | 2026-10-27 18:58 +1030 | Muse Spark Open: an exam can be marked on open weights through any OpenAI-compatible endpoint (frames a sec... |
| `8323d00` | `6e8d229` | `1c776d0` | 2026-10-27 19:19 +1030 | Desk: a practical's lines are steps ('What was done', 'The procedure'); subject-neutral focus hint; demo pr... |
| `1e7d665` | `c1bd8f5` | `8c59726` | 2026-10-27 19:38 +1030 | Live in the desktop app: a drawing came back with no lines (Spark's reasoning used the budget) - room, low ... |
| `a55696b` | `89b03b6` | `3eaa987` | 2026-10-27 19:58 +1030 | Phone: a question with the badge reads Turned around |
| `5a5a2d9` | `ceedb27` | `c3541c5` | 2026-10-27 20:14 +1030 | Live in the desktop app: the drawn step showed '1. 2. F = ...' and a repeated line (numbered lines, Spark's... |
| `bb6de78` | `ee1b30c` | `82487c6` | 2026-10-27 20:15 +1030 | README: the parts built on 27 Oct (examiner, drawn step, spoken comment, Proof of Thinking, replay, practic... |
| `7ab0a91` | `2993816` | `1c54ac8` | 2026-10-27 22:04 +1030 | Phone: the desk video is made 720p, 10 fps before it is sent |
| `56e0041` | `97c2076` | `ab8611e` | 2026-10-27 22:15 +1030 | Phone: upload retries and a kept recording to send again |
| `c225e7d` | `904acb5` | `35b914b` | 2026-10-27 22:26 +1030 | Marking: an answer with no working is part way, never mastered |
| `ec66cef` | `b1a51b8` | `69d13c8` | 2026-10-27 22:44 +1030 | Phone: shrink progress on the sending page |
| `1aae25f` | `cd74c9e` | `dad3e21` | 2026-10-27 23:06 +1030 | Phone: keep a recording made while Android stopped the app |
| `162c27d` | `13d587e` | `b1e7932` | 2026-10-27 23:18 +1030 | An upload whose link ran out leaves the exam |
| `5a10ac4` | `0784c70` | `c1ce9d9` | 2026-10-27 23:26 +1030 | Marking: no working means only the final value was written |
| `02d62ea` | `d77cc3b` | `6c5fd6f` | 2026-10-27 23:46 +1030 | Phone: Send my recording for a kept recording |
| `7ba4f90` | `11ad228` | `27cde92` | 2026-10-27 23:54 +1030 | A video that doesn't show the paper is not marked |
| `c89df2c` | `0ce2e72` | `4aa14bf` | 2026-10-28 03:33 +1030 | Meta busy or down: retry, keep the clip to mark again; SAM can't sink a marking |
| `46f070a` | `223d2aa` | `8a7a9fe` | 2026-10-28 05:08 +1030 | Each question is scored out of what the teacher said it is worth |
| `9ae1e04` | `8e8ab12` | `33214fc` | 2026-10-28 05:14 +1030 | Proof of Thinking names only the models that read this paper |
| `5ccc29d` | `3a29563` | `9e8767a` | 2026-10-28 05:36 +1030 | Desk: back from a paper, the exam is read again and keeps itself current |
| `c947340` | `406350b` | `fe2a439` | 2026-10-28 08:14 +1030 | Audit fixes: lesson 3 work task checked, a second reading when unsure, going back to a question |
| `1555222` | `af471e4` | `e014063` | 2026-10-28 08:29 +1030 | Audit fixes: Lo asks the examiner's questions, Turned around on the profile, the teacher's level preview |
| `b420459` | `c66c793` | `200b157` | 2026-10-28 08:37 +1030 | Audit fix: Ask my teacher from any step of the level, with where it was asked |
| `984372a` | `41bc89e` | `3a39566` | 2026-10-28 08:45 +1030 | Audit fix: the level opens on the student's own handwriting |
| `08f9a8d` | `ae5f18a` | `cb4e496` | 2026-10-28 08:49 +1030 | Audit fix: Muse Image draws the real-world place each level happens in |
| `7454912` | `d345762` | `c4e38ac` | 2026-10-28 08:58 +1030 | Audit fix: a long video goes up in parts and resumes |
| `5ff34d6` | `e17316e` | `2b02990` | 2026-10-28 09:02 +1030 | Phone: a long video goes up in parts and resumes on the same sitting |
| `81106ff` | `323d52e` | `2d6b4ba` | 2026-10-28 09:04 +1030 | Phone copy: faces are covered before the video leaves the phone |
| `bdd4d36` | `bf7f2d5` | `f96f3bc` | 2026-10-28 10:05 +1030 | The student's own step: the right line, cut once it is written |
| `d59b23b` | `c7554b5` | `a6ba091` | 2026-10-28 11:10 +1030 | Witness: a teacher sitting their own exam plays both sides |
| `b778529` | `8c573bb` | `94a8014` | 2026-10-28 12:34 +1030 | Witness desk: a held level without its outline can still be let through |
| `971cf28` | `f68bd8b` | `065d5fa` | 2026-10-28 13:31 +1030 | Witness phone copy: a resumed send sends the copy already made |
| `ecd8d85` | `c53cc3b` | `b570002` | 2026-10-28 15:48 +1030 | Witness re-audit: class patterns, the badge recommendation, the exam read from the teacher's file, voice te... |
| `0c43f52` | `b3c60f8` | `a3441e6` | 2026-10-28 16:07 +1030 | Witness phone copy: the re-audit's phone work and the Witness camera |
| `21695ec` | `13ccbc7` | `8d5fb8b` | 2026-10-28 16:36 +1030 | Witness: a third reading decides a split; room for Spark to answer; a reply without its marking is read aga... |
| `82b6947` | `e183f2f` | `d4ddf8d` | 2026-10-28 16:47 +1030 | Witness: a teacher out of credits is said as the teacher's, never the student's wall |
| `9594051` | `6ec532f` | `bb025ac` | 2026-10-28 19:23 +1030 | Witness: desk re-audit view (read from file, patterns, turned around, clips, audio); phone camera hand-over... |
| `8d4ae20` | `7a9f045` | `5ea91ec` | 2026-10-28 19:34 +1030 | Witness: every call of a mastery level on Muse Spark (lessons, flashcards, live turns in text, Insight) |
| `719b246` | `0f097ee` | `d9f56fa` | 2026-10-28 19:41 +1030 | Witness phone copy: video copies deleted once marked |
| `1847651` | `0ede0dd` | `38c8b44` | 2026-10-28 20:59 +1030 | Witness: export the payer rule for a host's other doors |
| `fff22c5` | `f415faa` | `c4cd08c` | 2026-10-29 04:45 +1030 | Witness: printed lines on the paper never take a student's step |
| `b3c59c0` | `e607a13` | `ee980dc` | 2026-10-29 12:15 +1030 | From Exam to Mastery: a finished paper photographed after the exam, page by page |
| `7703383` | `a81a48d` | `f51bd39` | 2026-10-29 12:19 +1030 | Mastery Plan: the teacher's badge waits for the finished level |
| `8e4a6fb` | `ee10e79` | `988cda3` | 2026-10-29 12:58 +1030 | From Exam to Mastery on the desk and the phone |
| `6787ca8` | `50d2d3d` | `06312ea` | 2026-10-29 13:07 +1030 | From Exam to Mastery: a ruled page's lines and specks never widen a step; the refusal names Turned around |
| `10c959d` | `118880b` | `817b524` | 2026-10-29 13:13 +1030 | Desk: the new-exam and whose-paper lines say photograph, not record |
| `dae10bf` | `5626d2b` | `0a9df80` | 2026-10-29 13:14 +1030 | README: From Exam to Mastery, the four areas, Witness as the other way in |
| `f1e5c93` | `3d802b8` | `bcc15ed` | 2026-10-29 13:38 +1030 | From Exam to Mastery: newest paper first; the phone waits for the name and shows a crop in its own shape, w... |
| `adda0b0` | `926a596` | `54884e7` | 2026-10-29 17:12 +1030 | From Exam to Mastery: the level reaches the teacher when its lessons and flashcards are done; neutral wording |
| `dcc22eb` | `14a5af8` | `ec31007` | 2026-10-29 18:21 +1030 | Desk: the open paper stays current; the Proof of Thinking record prints alone (sync a6e4126) |
| `b62aa3a` | `67322d7` | `1bfa588` | 2026-10-29 20:21 +1030 | Phone: a fresh level's news is kept until the teacher has it (sync e70dba8) |
| `cfb9085` | `85d2c13` | `556760a` | 2026-10-29 22:44 +1030 | Desk: a teacher's file reads cleanly; a desk draws only into its own panel (sync) |
| `75d0b3c` | `3a4d2bd` | `3956558` | 2026-10-29 22:58 +1030 | Server: every handwritten line on its own ink (sync d9be152) |
| `c2af5bf` | `5e494a6` | `05daa13` | 2026-10-30 00:06 +1030 | Server: a student's lines told from print by their ink (sync vb1029k) |
| `b5ef59c` | `2c4a8bd` | `ed05f67` | 2026-10-30 00:34 +1030 | Desk: the exam file read waits 90 s (sync) |
| `8b60918` | `5a6b79b` | `c61460f` | 2026-10-30 00:39 +1030 | Server: a pen's line never on a printed row while one of its own is free (sync vb1029l) |
| `f820ca1` | `ec27dd0` | `c882b0e` | 2026-10-30 01:07 +1030 | Server: the student's own step holds only their writing (sync vb1029m) |
| `c408317` | `7ea55a8` | `9a76d6b` | 2026-10-30 04:45 +1030 | Desk: late papers can be released (sync) |
| `540296d` | `df71443` | `622e158` | 2026-10-30 09:08 +1030 | Teacher's new challenge, the Misconception Fingerprint, and every gap from filming closed (sync vb1030b) |
| `d5382fc` | `881cc65` | `5706949` | 2026-10-30 12:51 +1030 | The evidence: the three learners' fingerprints recorded live, the end-to-end rehearsal (screens, clips with... |
| `b6e8212` | `45a6f7d` | `e845958` | 2026-10-30 13:29 +1030 | Evidence: slider step buttons on the phone; the student's final card with what Lo's question found and Turn... |
| `d7d7a60` | `65e4df3` | `0d6bb36` | 2026-10-30 15:07 +1030 | The fingerprint rule in code, measured on a held-out set; the teacher's gates and deleting; the benchmark c... |
| `971f3f4` | `573beb8` | `c3a5e72` | 2026-10-30 15:11 +1030 | Phone: Lo speaks when Turned around arrives; the card says what the marks were on the exam and what changed... |
| `77a1ae3` | `33243b5` | `e5fdb61` | 2026-10-30 15:38 +1030 | While Lo asks, the diagnosis says only what the page shows; the examiner asks about what was not mastered |
| `11bfdbb` | `7169a4f` | `1cd5b60` | 2026-10-30 18:58 +1030 | Deleting a paper takes the student's pointer even when the teacher sat it |
| `b5792f1` | `a651602` | `e266949` | 2026-10-30 20:42 +1030 | Self-check: a level that teaches a false claim does not pass |
| `f6a114f` | `8413d6a` | `8b9e477` | 2026-10-30 22:35 +1030 | Class patterns group by reasoning, never by the answer |
| `2f4371c` | `4843976` | `c0c43dd` | 2026-10-30 22:37 +1030 | Settled diagnosis is the named idea alone |
| `febc3e0` | `01d7a54` | `e6c71f4` | 2026-10-30 22:48 +1030 | Evidence from the 30 Oct live rehearsal; README: 118 tests, the self-check's limit |
| `3104545` | `72543af` | `aff3e77` | 2026-10-30 23:01 +1030 | Class patterns evidence on the deployed edge: three reasons, three groups |
| `5bc7b07` | `3d290fc` | `bab531a` | 2026-10-30 23:01 +1030 | Phone copy: the mastery route returns the credit wall; the last "Film my desk with Witness" label |
| `9aca1f6` | `16608d1` | `c389647` | 2026-10-31 03:07 +1030 | The 12-judge panel's fixes, and held-out set v2 written before any run |
| `ab0e88a` | `4f16c96` | `67cdfe2` | 2026-10-31 03:13 +1030 | Self-check and reason-judge evaluation sets, written before any run |
| `48cb03c` | `52bc2fc` | `2d0bacb` | 2026-10-31 03:31 +1030 | Structured output, prompt caching, private class patterns, a local replay desk; first results |
| `5712d5b` | `7d877ef` | `259af92` | 2026-10-31 03:40 +1030 | First self-check and reason runs; the rule names what the steps do; judges ask for the rule applied |
| `b529f24` | `a99600e` | `082e2a8` | 2026-10-31 03:55 +1030 | Re-runs on the committed code: self-check (corrected levels), reasons, three learners on the steps rule; do... |
| `57686ef` | `ce7f07b` | `179eb2d` | 2026-10-31 04:11 +1030 | No-scheme marking fix; held-out v2, photo, video, line and class-of-40 runs on the committed code |
| `f6d02d1` | `9044710` | `4964a16` | 2026-10-31 04:53 +1030 | The photographing code reaches the phone; sent papers listed by exam code, not title |
| `1ae2b74` | `3d10aa5` | `0a2accf` | 2026-10-31 07:09 +1030 | The continuous run on the production edge: fresh evidence, the replay recording, and the faults it found |
| `b69d182` | `308b90a` | `2c5167f` | 2026-10-31 07:22 +1030 | The photographing code typed in the phone's code box, on the live server (test99) |
| `4dfc992` | `a5d7b95` | `4fc5850` | 2026-10-31 23:04 +1030 | An exam it had never seen: Form 3 physics marked six times live (180/180), the explanation rule, part way n... |
| `3db5f9f` | `1487cc0` | `0f5b91a` | 2026-11-02 23:40 +1030 | README: the problem story with sources, the demo frame by frame, what the film had no time for; LoWisa's ol... |
| `1ac9398` | `eebda6d` | `c75906e` | 2026-11-02 23:53 +1030 | README: exam-failure research, research mapped to what the product does, Meta's models after the story |
| `066c9d1` | `10359d5` | `59fd078` | 2026-11-03 00:17 +1030 | Lo's live turns fail closed; the worded-answer example no longer mirrors a held-out item |
| `2a64bf9` | `5087022` | `e940d5f` | 2026-11-03 00:36 +1030 | README after the 12-judge panel: blind and shipped-code held-out results, provenance, the film's v9 frames,... |
| `02d7e84` | `f920ce5` | `7d1de5f` | 2026-11-03 01:11 +1030 | README: marking time as a pain of its own (TALIS 2024), and where the saved time goes |
| `5321aa6` | `85e4491` | `6f628f0` | 2026-11-03 01:39 +1030 | Let all held levels start at once (built, not released); face covering stated as it is |
| `372e104` | `6e4f748` | `ae5747d` | 2026-11-03 01:40 +1030 | README: Meta beyond a basic integration, Meta across LoWisa (own key, released; LoWisa credits, this projec... |
| `bd36fe2` | `76cf755` | `1e27ef6` | 2026-11-03 08:34 +1030 | Real handwriting: one student's three papers (110 questions) marked on the live product against his teacher... |
| `56c0fbd` | `1b53e4a` | `5853642` | 2026-11-03 08:54 +1030 | Photographed pages turned upright before marking; README: the school pays, a Grade 5 student |
| `15fd3c9` | `731d90b` | `e226962` | 2026-11-03 09:30 +1030 | README: section 15, the problems we hit and how we solved them (sideways pages first); Limits and Sources r... |
| `9598ec5` | `1cdf5de` | `b63d79c` | 2026-11-03 09:30 +1030 | README: the criteria table points technical depth at section 15; 145 library tests |
| `3959470` | `3f3c9f5` | `2e5d2b1` | 2026-11-03 09:30 +1030 | README: fourteen problems, as counted |
| `4b335bf` | `190474a` | `5db522a` | 2026-11-03 10:31 +1030 | README: try it from the demo school (no school details, no password), and what the demo school is and is not |
| `e9fb96f` | `a67eb04` | `707869a` | 2026-11-03 10:59 +1030 | Marking a long multi-page paper in parts at once; full marks only for a mastered question |
| `c3b9f87` | `8e86112` | `700270d` | 2026-11-03 11:50 +1030 | README: the slow long paper and the half mark, in the problems we hit; live marking times |
| `65b6c99` | `eac9f25` | `5438fb6` | 2026-11-03 13:14 +1030 | Sixteen damaged images put right, every media type stored as binary, and a media check in CI |
| `38dd640` | `4e4f7c9` | `d579fa0` | 2026-11-03 13:36 +1030 | The circled option is the final answer, not evidence; dates and counts made consistent; provenance of the t... |
| `2d89191` | `0bc4031` | `6997b68` | 2026-11-03 13:50 +1030 | Condition C on the code that ships, orientation and parts measured, the README's first screen, try-it and f... |
| `9d40746` | `07cb930` | `17f8f13` | 2026-11-03 13:57 +1030 | The film, cut 10, in the repository: the problem first (cognitive ability), a real student's result, every ... |
| `6efd44c` | `15ede0b` | `f94d2f4` | 2026-11-03 13:59 +1030 | The film itself committed (it was ignored as *.mp4); the link check now requires a tracked file |
| `41788da` | `b3543b3` | `5c3c502` | 2026-11-03 14:18 +1030 | README opens with the problem, cognitive ability, before From Exam to Mastery |
| `f74de75` | `b87f0d0` | `52a71f4` | 2026-11-03 14:23 +1030 | README: the rest of the original film opening in writing (what if the AI we fear became a tool to strengthe... |
| `7dffba0` | `79ece7a` | `89e1b8e` | 2026-11-03 16:10 +1030 | Witness: when readings split, the note says "of the work", not "of the video" (a photographed paper said vi... |
| `478f62f` | `ee5e64a` | `ead629c` | 2026-11-03 16:10 +1030 | README: Future plans (a Mastery Plan wherever a learner fails, electronic exams, interactive experiments be... |
| `eec2917` | `2621eba` | `55ce712` | 2026-11-03 16:43 +1030 | Real handwriting: no first name in the written-answers file; the other student's papers deleted from the pr... |
| `6dc039b` | `8016cef` | `54b15bb` | 2026-11-03 17:14 +1030 | Witness: two readings must agree before a question joins "Accept all"; Lo's held note says "how it was reac... |
| `2f240b6` | `74ac205` | `f375bc5` | 2026-11-03 17:39 +1030 | README: the agent pipeline and what each code check changed, measured; one real paper traced call by call; ... |
| `8578da2` | `dc79c46` | `0450f22` | 2026-11-03 17:59 +1030 | host/mastery-mode: the level builder's mastery mode published line by line, each line dated by git blame (9... |
| `f8d866b` | `49adf89` | `b0bcf4f` | 2026-11-03 18:08 +1030 | Film cut 11: Muse Spark's marks landing on the page, the real student against his teacher's baseline, Lo as... |
| `9a01bd2` | `9e175a4` | `3eeffb2` | 2026-11-03 18:16 +1030 | Every headline set again on the tagged code v1.0-code: the real student's multiple choice (no idea named on... |
| `13757f4` | `749b9d0` | `59bd9b7` | 2026-11-03 18:43 +1030 | Witness: two readings agree on a number only when the numbers are the same (never 2.4 and 24, -5 and 5, 150... |
| `02592a0` | `2f440e0` | `6230587` | 2026-11-03 18:50 +1030 | Film cut 11, final (2:59): the paper marked by hand is back before Muse Spark's marking; the real student's... |
| `952098b` | `240ed5d` | `ff4ffc3` | 2026-11-03 20:07 +1030 | README: the last stale figures (151 tests, held-out on v1.0-code, physics marking times with the second rea... |
| `567cd28` | `c2adb88` | `40159f6` | 2026-11-03 20:11 +1030 | Muse Spark Open run on Baseten's Model API through the product's own photo path: physics 30/30 decisions in... |
| `2752f13` | `7ccff6f` | `1eb096f` | 2026-11-03 20:36 +1030 | Witness: the same letter with different words after it is not the same answer ("A dog", "A cat"), nor a wor... |
| `bb686d8` | `6b74e87` | `c97cfe4` | 2026-11-03 20:38 +1030 | Docs pass from the round-6 panel: built-during table repaired and its one exception stated; the open-weight... |
| `8135aea` | `7967c9b` | `35423da` | 2026-11-03 20:45 +1030 | Muse Spark Open with ten minutes a reading: the three failed runs re-run and all completed (physics with a ... |
| `8219a3f` | `bc1c46d` | `6e7bd44` | 2026-11-03 21:14 +1030 | The real sets and held-out v2 once more on the code live now, v1.0.1-code (edge vb1104h): multiple choice 1... |
| `1015e75` | `ea8c292` | `ef0a73f` | 2026-11-03 23:24 +1030 | README: the owner's introduction and four-areas table open the repo (protecting and strengthening human cog... |
| `854a35f` | `59d3b87` | `caef012` | 2026-11-03 23:37 +1030 | Film, final cut (2:57): narrated by Murf's Gordon; Daniel's story first and unbroken, then the real student... |
| `f4b0518` | `4e4f7ba` | `5432951` | 2026-11-04 00:35 +1030 | Round-7 panel pass: a short box for judges above the owner's introduction; the live code run three times (m... |
| `60d667c` | `0b64a90` | `e8ed823` | 2026-11-04 04:21 +1030 | Live now: v1.0.2-code (edge vb1104i), v1.0.1-code plus two fixes (readings no longer agree across "not" or ... |
| `6fc1601` | `43fdd62` | `e7e586c` | 2026-11-04 05:05 +1030 | Round-8 panel pass: one set of results on the latest code with earlier code in its own table; the teacher's... |
| `de52a99` | `fa54055` | `bd576a4` | 2026-11-04 07:29 +1030 | Film (2:59): Lo's "Let's ask ourselves" question, the cargo ship, straight after the first look (owner); th... |
| `5bacb22` | `f89bb07` | `a7bd2ec` | 2026-11-04 07:46 +1030 | Round-8 remaining items: the box says not a chatbot, links to its sections and words Muse Spark Open as tes... |
| `a3ea91f` | `e237cb2` | `fd69534` | 2026-11-04 08:14 +1030 | Nothing of LoWisa's earlier code published: the level builder's excerpt keeps only the 95 lines written dur... |
| `c62b5e6` | `ba46d5e` | `f36be5c` | 2026-11-04 08:24 +1030 | Security review before going public: a join code tried through the video upload counts against the join lim... |
| `5f73739` | `31451d4` | `c10a6ca` | 2026-11-04 08:39 +1030 | Live: edge vb1104j, a photographed paper is never told about a video |
| `935dffc` | `62a01a2` | `fcb1294` | 2026-11-04 11:49 +1030 | Live: edge vb1104k, the security review's fixes, one daily ceiling across all logins and one per student, a... |
| `e78f078` | `8968e60` | `624453d` | 2026-11-04 14:26 +1030 | Independent audit, all fixed: PolyForm Strict 1.0.0 + a judging permission; live on edge vb1104m: the serve... |
| `6102e40` | `9cc076b` | `0e4af29` | 2026-11-04 14:34 +1030 | Future plans: what is fixed in the code and arrives with the next app release (the phone's desk video fails... |
| `c17695d` | `e128aa5` | `c49daca` | 2026-11-04 14:37 +1030 | Future plans 17.1: what already protects students until the phone release (photographing films no one, Andr... |
| `2adbbfd` | `29e8fdf` | `7bc41a4` | 2026-11-04 15:02 +1030 | Second audit: a desk video leaves the phone only on the face look's explicit "checked" (safeVideo.ts, now r... |
| `3fea245` | `7e02275` | `96b135f` | 2026-11-04 15:10 +1030 | Second audit: the judges' route followed from a fresh clone (164 tests, the face rule, the recorded desk, a... |
| `53fa703` | `d59a7a5` | `ee267b5` | 2026-11-04 15:43 +1030 | The $25 a day is reserved before each call and never passed: live from edge vb1104n (checked live: one exam... |
| `5c981b2` | `2e5f712` | `ab4f221` | 2026-11-04 16:57 +1030 | Third audit: the day's holds expire after 30 minutes, at most 500 at once, admitted to $22.50 with every ov... |
| `ffa26dc` | `e4ecc17` | `8d4b37e` | 2026-11-04 17:51 +1030 | Third audit live on edge vb1104o (4 Nov 07:19 UTC): one click only at 0.95 and called right, the day's hold... |
| `b3f13a7` | `259ca9e` | `a76a0b5` | 2026-11-04 17:53 +1030 | The 2:59 demo on YouTube (youtu.be/s4DtrRzyQsI), first in the judges' box and beside the film file |
| `4edd468` | `b362258` | `0612bbb` | 2026-11-04 18:49 +1030 | Fourth audit and live checks: video only after the face look, holds by id, no exam answer in a level, one c... |
| `04fc38c` | `3f1ae34` | `bac4bab` | 2026-11-04 19:13 +1030 | One click with and without a mark scheme: the same rule, the desk told which key was used; docs/marking-pol... |
| `498c3cb` | `e7c877e` | `1b038cd` | 2026-11-04 19:46 +1030 | Live on edge vb1104p: the checks after the release, and the second cause of a parallel charge failing |
| `b3b8275` | `3b66b0e` | `8e271db` | 2026-11-04 20:28 +1030 | Live on edge vb1104q: a class's turns on one wallet, 20 of 20 paid |
| `36668b3` | `1dfc89a` | `075a638` | 2026-11-04 20:46 +1030 | Final audit wording: the video statement is a safeguard, not proof; marking still imperfect; a server-side ... |
| `feb795a` | `9ad24a0` | `250460c` | 2026-11-04 20:49 +1030 | Test: a join after the photo is after it by the clock too (CI ran both in the same millisecond) |
