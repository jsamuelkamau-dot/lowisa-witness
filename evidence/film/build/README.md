# How the film is built

The final cut, [`../exam-to-mastery.mp4`](../exam-to-mastery.mp4), is drawn frame by frame in Python from the
product's own results and screens, drawn from committed files. Four things in it are not the product's output, and
each is labelled on screen: Daniel's paper marked by hand (a prop, labelled sample paper), the before-and-after card
(a summary we wrote), the film's title and end cards, and the spoken answer (another sample learner, a synthetic
voice; Muse Voice Transcribe's writing-down of it is real).

- `script11.json`: every narrator line (what is shown on screen, and what is spoken).
- `murf11.py`: the narration, one mp3 a line, in Murf's Gordon (`MURF_VOICE=en-US-gordon`, key in `MURF_API_KEY`).
- `edit11.py.txt`: the cut, beat by beat: which shot, which line, its label (built this week / LoWisa / sample paper)
  and the model named on screen.
- `shots11.py`: the shots new in this cut. Each draws from a committed result or screen: Muse Spark's marks
  (`MARKS`), Muse Wonder's two plays (`evidence/unseen-physics/levels-q23-q24-with-self-check.json`), the held level
  (`harness/selfcheck/`), the spoken answer (`harness/probes/results-31oct/`), the real student's sheets
  (`evidence/real-handwriting/`).
- `make_build11.py`: writes `build11.py` from the previous cut's builder with these changes; `transcript11.py` writes
  `../transcript.md` and `../exam-to-mastery.srt` from the same timeline.

They run on the build machine: the earlier cuts' drawing engine, the phone recordings of LoWisa's player and the
fonts are not in this repository, so the paths in them are that machine's.

```bash
VOICE=gordon VO_TEMPO=1.04 python build11.py
```
