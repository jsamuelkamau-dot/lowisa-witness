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
