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
