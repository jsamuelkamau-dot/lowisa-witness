# Findings

## 27 Oct: day-1 probe (synthetic 44 s clip: 3 answers, one crossed out, one right answer by wrong thinking)

- **SAM 3.1, concept prompts on video**
  - "number" follows digits in the order they were written (first seen at 1.7 s, 2.0 s, 2.5 s…).
  - "paper" matches every frame; "word" gives whole lines.
  - "handwriting", "text", "pen" and "hand" found nothing on this clip.
  - At most 16 objects a frame, so a full page needs windows or regions.
  - 285 frames cost $0.057.
- **Muse Spark 1.3 reading the video** (Responses API, `input_file`)
  - With medium effort and a prompt that asks it to judge the thinking, it:
    - read every step, including the crossed-out 3/8;
    - caught the right answer reached by wrong thinking (16/64 → 1/4 by cancelling the 6s), placed at 35 s, true time about 35.4 s;
    - found the thinking pause (25–30 s; true 25–31 s).
  - About $0.02 and 15 s.
  - With low effort and a plain "is it right" prompt, it called the same answer right. Marking must ask about the method and use medium effort.
- **Erlang TLS** refuses `*.meta.ai` by default (hostname_check_failed); the HTTPS match function is required.

## 27 Oct: the whole sitting through Erlang (`harness/sitting_check.escript`)

- Uploading, then running SAM ("word", forward) and Spark (marking, medium effort) side by side takes 44–53 s and about **$0.08** for the 44 s clip.
- Muse Spark caught the right answer reached by wrong thinking on every run, with the moment at 33–36 s. Q1's crossed-out 3/8 was read on every run.
- **SAM "word" tracked forward finds the written lines in writing order**: 6 of 6 on one run, 5 of 6 on another. Tracked both ways, first sightings came earlier than the ink.
- SAM sees a line once it reads as a word, a few seconds after the ink, so steps are placed by page order and time, with a penalty for leaving one of SAM's lines empty, all questions in one pass.
- **SAM 3.1 and Muse Spark both read a clip from a signed S3 link** (`input_video` with `video_url`), so the phone uploads straight to storage and the server never holds a video. The same marking came back: 6 lines, wrong thinking caught, $0.08.

## 27 Oct: the self-check (`witness_check`, Muse Wonder)

- A weak level, whose every check was a fraction where cancelling digits happens to work (19/95, 26/65, 49/98), was **failed**: "the misconception student passes". Wonder named a fix per lesson, each a fraction where cancelling fails (14/42 → 1/2 against 1/3, 14/24, 18/28).
- A good level (12/24 at the stadium, 13/39 ≠ 1/9) **passed**. Both checks together took 33 s and cost about $0.08.
- At 4,000 output tokens Wonder spent 3,998 on reasoning and returned no verdict (status incomplete). It now runs at medium effort with 16,000 tokens.

## 27 Oct: the emulator, live (test60 on vb1027e)

- The Witness tile shows only for the pilot account. The join code found the exam; "choose a video" sent the desk clip in 6 s; it was marked live.
- The exam's question held "÷", which had failed every paper before the UTF-8 fix; it now marks.
- After the teacher's focus note and release, the phone showed 5 of 6, the crossed-out first try, and "Right answer, thinking to fix" with the diagnosis.

## 28 Oct: video against a photo of the finished page (`harness/photo_cmp.escript`, same day, same model)

12 benchmark papers, 43 questions, 6 languages, plus a new clip where the wrong reason is rubbed out (`erased_en`).
Witness marks the video (SAM 3.1 + Muse Spark); the photo run gives Muse Spark the clip's last frame with the same
marking prompt worded for a photo, and the same scheme.

| | Exact | Sound (mastered or not) | Right answer by wrong thinking caught |
|---|---|---|---|
| Video (Witness) | 43 of 43 | 43 of 43 | 3 of 3 |
| Photo of the finished page | 36 of 43 | 38 of 43 | 2 of 3 |

- The photo missed "19/95 = 1/5" whose reason ("cancel the 9s") was rubbed out: it saw only the answer.
- The photo marked a paper the student corrected in front of the camera (crossed out, then right) part way on all three.
- A wrong method rubbed out and replaced by the right one is a self-correction for both; the video keeps the rubbed-out
  line in the teacher's replay ("16/64: cross out the 6s → 1/4"), the photo cannot.
- Found on the way: one reply in twelve ran out of tokens before its JSON (Spark's thinking used 3,800-4,800 of 6,000 at
  medium effort), which failed the sitting; the budget is 16,000 now and such a reply is read again. And two readings
  that split always ended part way at 40%, so right one-word answers read 1 of 2 once became "part way"; a third
  reading now decides (two of three agree), and the benchmark is back to 46 of 46 exact.

## 30 Oct: the Misconception Fingerprint, live (`harness/fingerprint_check.escript`, `evidence/misconceptions/`)

One question, three photographed papers, all circling $100 for +50% then −50%:

- **A** "+50% - 50% = 0%": named "percentages cancel"; no question. **B** "100 + 50 = 150 / 150 - 50 = 100": named
  "second percentage taken of original amount"; 1 of 3 kept for the right increase. **C** "Half up, half down. Same
  price.": an intuition, so Lo asks "which price is each half taken from?".
- The first rule labelled C "cancelling" from the intuition alone. The rule now names only what the ink shows and asks
  whenever the calculation behind an answer is not on the page; three re-runs gave C a question each time.
- C answered "Both halves are of 100 dollars…": Muse Spark completed the fingerprint as B's idea (the base), from the
  page and the answer together. The page alone could not have told it.
- Muse Wonder's class view grouped Leo and Priya (cancel) and Tomás ("50% always means $50") with a reteach for each.

## 30 Oct: the rehearsal on the real edge found three things, all fixed the same day

- **A released paper vanished from its exam** after the student answered Lo. Rows are read with
  `binary_to_term(.., [safe])`; the host loaded a hand-kept list of Witness modules first, and it missed the day's two
  new modules, so a row holding their atoms (`said`) read as missing on a node that had not loaded them. Reproduced
  offline on the stored row (fails cold, reads once the 24 modules are loaded). The list is now the application's own.
- **Lo's question vanished without a word** once answered: Lo now says the answer was heard, out loud.
- **"The recording is kept for your teacher"** was shown under a spoken answer to Lo, whose recording was not kept. It is
  now, and the desk plays it.

## 30 Oct, evening: the judges' panel, then the fixes, measured

Eight independent reviews of this repository, the film plan and the evidence (two per judging criterion) found, among
others, things this file had not: the marking prompt quoted the three demo answers as examples, so the three-learner
result was fitted, not tested; the recorded reply for Learner C named an idea *and* asked, and the code kept the name;
what Lo's answer settled never reached the self-check, the class patterns or the challenge (the class view put Leo
with "cancel"). Each was checked against the code before anything changed.

- **The demo answers are out of the prompt.** Re-recorded five times each, the honest result at first was worse: C was
  named "cancel" with no question in 5 of 5 runs. The prompt alone does not make the model hold back.
- **The rule moved into code** (`witness_mark:fingerprint/4`): quoted evidence must be in the ink; the final answer is
  no evidence; while Lo asks nothing is named (the guess is kept for the teacher); a numeric answer with no quoted
  calculation, or a rival idea the model names, means Lo asks first. Now A is named 5 of 5, B 5 of 5, and C is asked
  5 of 5, with a question that suggests nothing.
- **Held out** (`harness/heldout/`): 36 papers in 10 topics the prompt never saw. Ambiguous ink asked 9 of 11 (prompt
  only), 8 of 11 (asking the model for rivals: it listed none), **10 of 11** (rule in code); clear ink named right 10 of
  12 with 2 asked first; right work 10 of 10; adversarial ink 3 of 3 held; no wrong name in any run.
- **The settled reading is the diagnosis** everything after it reads (`witness_fingerprint:settled/1`).
- Also from the panel, in the server: preview on by default and a level its self-check did not pass always waits for
  the teacher; "completed" needs each lesson seen; delete routes for a paper and an exam; a ceiling on a
  teacher-paid level's design calls; a paper read again before a slow step writes back.

## 30 Oct, the full live rehearsal

- **Class patterns grouped by the answer, not the reasoning.** Priya (they cancel), Tomás (50% as a fixed $50) and Leo
  (kept the first base) all wrote $100 and came back as one group, the opposite of what the fingerprint shows. Each
  line now carries the fingerprint's named idea, and the prompt keeps different reasoning apart. Live against Muse
  Wonder: three groups in 3 of 3 runs, then on the deployed edge (`evidence/screens/desk-class-patterns.png`).
- **The self-check passed a false claim** (a shop "loses $25" by charging $100 for a $75 price). It now works out every
  number and every gain or loss claim (`true_claims` in `witness_check.erl`). The questions written inside each lesson
  as it opens are still not checked one by one (README, limits).
- **The settled diagnosis carried the model's notes on its evidence.** It is now the named idea alone.

## 31 Oct: twelve judges, then every number re-run on the committed code

A panel of twelve reviewers (three per judging criterion) graded the repository, the film plan and the evidence. Each
gap was checked against the code before anything changed; the fixes and their tests are in the commits of 31 Oct.
Then every evaluation was run again on the committed code.

- **Learner B drifted to "cancel"** in some readings: the name followed the final answer ($100, "back to the start"),
  not the steps. The marking rule now says to name what the student's own steps DO (how each number in them was got).
  Five readings each: A named 5 of 5 (the changes cancel), B 5 of 5 (50% taken as a fixed $50), C asked 5 of 5
  (`evidence/misconceptions/runs-31oct-steps-rule.jsonl`; the readings before the rule are kept beside it).
- **Held-out v2** (53 papers written after the rule froze, three runs): ambiguous asked 40 of 42, a wrong idea named
  2 of 42 (that run; on the code that ships it is 3 of 42, README section 7), clear named right 43 of 48, right work 39 of 39, injection 30 of 30 (`harness/heldout/README.md`).
- **My first "clean" self-check levels leaked worked answers**, so the check passed them for the wrong reason. The
  levels were rewritten (the first version is kept as `levels-first.json`). Now clean passed 30 of 30, faults held
  30 of 30 and named 30 of 30, planted false claims 9 of 9.
- **The reason judge accepted reasons made only of words** ("because percentages work like that"). Its prompt now asks
  for the rule applied to this question's numbers: false accepts 0 of 36, false rejects 0 of 24.
- **A marking bug the photo bench found.** With no mark scheme the prompt said "give 1 mark for a fully correct
  question" beside questions listed as 2 marks; right work came back 1 of 2, which the marking rightly reads as not
  mastered. On the committed code the photo bench fell to 19 of 40 exact. The sentence now gives a fully correct
  question all its worth (`no_scheme_gives_a_right_question_all_its_marks_test`); photo 39 of 43 exact, 42 of 43
  sound; video 45 of 46 exact, 46 of 46 sound. An exam with the teacher's scheme was never affected.
- **Where a line is on the photo** (`harness/bench/line_bench.escript`, 64 lines): `witness_page` 64 of 64 at an
  overlap of 0.5 or more with the ink (mean 0.92), SAM 3.1's word boxes 52 of 64 (0.75), Muse Spark's own boxes 1 of
  64 (0.06). Spark's boxes are loose and drift; the product never cuts a step with them.

## 31 Oct, evening: one continuous run on the production edge, and what it found

From the teacher's PDF to the re-check, on a fresh exam (README §5). Fixed the same day, each with a test:
- **The phone could not photograph.** Since the panel fixes the server refuses the join code for photographing, and the
  phone had nowhere to type the photographing code. The code box now takes either code; an exam opened with the join
  code asks for the photographing code. Two exams with one title also showed each other's papers: now matched by code.
- **"Keep going" told the teacher the next lesson was finished** (6 of 6) before it was played: the lesson player still
  held the last lesson's finished run. A lesson is now told finished only by its own run.
- **A level's practical task lost its typed check** when the model wrote the result as text ("$56.25"), or when its
  number appeared inside another ("6" in "$60"). Both kept now.
- **A lead or a screen title stated the answer a question then asked** ("at $120" over a guess of $120; "Ring the $60
  Ticket" over a typed $60). The prompt rule alone did not hold; code now takes out such a guess or typed question.
- **The last lesson promised "The next lesson answers it"**; **"days later"** was said of a re-check sent the same day;
  **the class patterns called Lo a student** ("Ask Lo first to explain how he got $100"). All reworded at the source.
- **Bulk accept failed in the desktop app** that had run since before the panel fixes: its compiled door list predated
  the route. Rebuilt; a release build compiles it.

## 2 Nov: held-out v2 on the code that ships

- **v2 run again on the shipped code, beside its blind first run** (`harness/heldout/results/v2-on-shipped-code-3-runs.json`,
  `066c9d1`, clean): named right 44 of 48, Lo asks first 39 of 42, a wrong idea named 3 of 42, right work 39 of 39,
  instructions in the ink never obeyed 30 of 30. The blind first run ran on an uncommitted working copy; both are shown
  (`harness/PROVENANCE.md`).

## 3 Nov: a real student's handwriting, and what it found

- **A real Grade 5 student's three papers against his own teacher's marks** (`evidence/real-handwriting/`). As
  photographed: 102 of 109 agree, 4 of his 10 wrong answers caught. With the three sideways pages turned upright by hand:
  105 of 109, 7 of 10.
- **Pages turned upright by the server.** Asked "how many degrees", the first live try turned two of three sideways pages
  the wrong way; asked "which edge is the top", it turned them right. Measured after, 4 papers × 3 runs each way: by edge
  45 of 45 pages, by degrees 44 of 45 (`harness/orient/results/orient-03nov.json`).
- **A long paper took 332 s live.** One reading wrote 11,650 tokens. Marked in parts of about ten questions at once:
  63 and 65 s, against 220 and 232 s for one reading, on the same code (`harness/parts/results/parts-03nov.json`).
- **Half a mark rounded up.** On the parts code, the physics page without a scheme gave three one-mark "part way" answers
  1 of 1. Full marks now belong to a mastered question only (`witness_mark:short_of_full`); the page back to 6 of 30
  (`evidence/unseen-physics/no-scheme-after-half-mark-fix-3-runs.json`).
- **Condition C, the code that ships, three live runs, nothing turned by hand:** 105, 103 and 105 of 109; 7 of 10
  caught every run; the sideways page stored upright in 9 of 9 papers
  (`evidence/real-handwriting/results/condition-c-shipped-code-3-runs.json`).
- **The circled option taken as evidence.** In runs 2 and 3 of condition C the reading included the option he circled
  with its printed text ("A 24 circled"), and an idea was named from it on 4 of the 26 answers not accepted over the three runs. The option chosen is
  the final answer, which is no evidence: `witness_mark:chosen_option/2` (`38dd640`), with a test. Re-applied to the
  four, all four are held and Lo asks first.
- **Sixteen committed images were damaged by git** (CR stripped from every CR LF pair; only `*.png` was marked binary).
  Every one restored or redrawn, every media type marked binary, and `scripts/check_media.py` runs in CI
  (`evidence/MEDIA-REPAIR.md`).
- **The same student's written answers, three live runs, no marking scheme** (42 questions on three more papers,
  creative arts and integrated science): 37, 38 and 38 of 42 agree with his teacher; 3 of 4 wrong answers caught every
  run; all 19 answers not accepted were held for Lo to ask, no idea named
  (`evidence/real-handwriting/results/written-answers-3-runs.json`). Two things found: an answer squeezed onto the
  printed lines was read as crossed out once the ink was removed, and when two readings split, the note to the teacher
  said "Two readings of the video disagreed" on a photographed paper. The wording is now "of the work" (with the tests).
- **Every headline set again on the tagged code `v1.0-code`** (two readings before "Accept all"). The real student's
  multiple choice: 105, 104, 104 of 109; no idea named on any answer not accepted in any run (0 of 24; 4 named on the
  earlier code). His written answers: 39, 37, 38 of 42; 18 of 18 not accepted held. Held-out v2: Lo asks first 40 of
  42, a wrong idea named 2 of 42 (3 before), named right 42 of 48 (44 before), at $3.71 for 159 markings ($2.61 before)
  and a median 22 s (13 s). Physics: 90 of 90 decisions. The answers-only reading caught his misread science Q33 in one
  run of three; in the other two both readings read the same wrong letter.
- **Muse Spark Open on Baseten's Model API** (`harness/open/`, 3 Nov): the same photo path with each reading through
  `witness_open:read_content/3`. Physics: 30 of 30 decisions right in each of 4 completed runs. The real student's
  English 29 of 30, science 46 of 49 (Muse Spark: 29 and 47); no wrong idea named. 3 of 9 runs failed: a reading past
  the 5-minute limit per call (twice) and one reply that was not a marking; the open model writes up to 12,000 tokens a
  reading, half of them reasoning. $0.90 for every completed call.
- **Three runs on `v1.0.1-code`** (then live) (4 Nov, 13-judge panel round 7: "one run is not enough"): multiple
  choice 104/104/104 of 109, 7/6/6 of 10 caught; written 36/37/38 of 42, 2/2/3 of 4 caught; no wrong idea named in any
  run of either set. The written drop from 3 of 4 is one question (science Q35) read as "A. Wheat" instead of "Cow
  peas" in two runs, at 0.65 and 0.75 sure, so it went to the teacher, not to "Accept all": reading variance, not the
  comparison change. Held-out: asked 39 of 42, wrong idea 3 of 42, named right 43 of 48 (0 a different idea).
- **One photographed paper came back unreadable, then marked from the same photos** (written run 3): Muse Spark said
  the photos showed only questions 11 to 30. The product marked nothing, as it should, but told the teacher to have it
  "filmed again"; a photographed paper is now asked to be photographed again (`witness_api:view/2`, live from edge vb1104i, `v1.0.2-code`).
- **Two readings that differ only by "not", or by units, no longer agree** (`witness_mark:same_answer/2`, round-7
  panel): "does not float" and "float", "5 cm" and "5 m". Live from edge vb1104i (`v1.0.2-code`).
