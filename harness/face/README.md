# The server's own face look on a desk video (4 Nov 2026; five frames a second and refusing an incomplete look since 5 Nov)

The final audit's one remaining trust-boundary point: the server took a desk video because the app said its face look
ran (`faces: "checked"`), and a modified app could say that without looking. Since edge vb1104r the server looks
itself, before anything reads the video (`witness/src/witness_face.erl`, called first in `witness_api:attempt/7`):

1. ffmpeg cuts the video to five frames a second (two until 5 Nov), 480 pixels wide, from its signed link, and stops
   at the first decoding error;
2. that copy goes to Meta's file store and SAM 3.1 is asked for `"face"`; the copy is deleted from the store after;
3. **any** face SAM reports, at any confidence, refuses the video: it is deleted unmarked, no still or clip is cut from
   it, and the teacher and the student are told why ("A face could be seen in this video...");
4. a look that cannot run marks nothing (it is tried again only while Meta is busy, as a marking is);
5. a marking cached from before the look existed, or from a look at fewer frames a second, is not reused;
6. **since 5 Nov, a look that cannot cover the whole video refuses it** ("face_unsure": deleted unmarked, nothing kept,
   the teacher told to have the paper photographed): ffmpeg could not read the video to its end, the copy could not be
   made or its frames counted, or SAM looked at fewer frames than the copy holds. SAM no longer reads the original link
   itself when the copy fails, because that look could not be counted.

## Five frames a second, and refusing an incomplete look (5 Nov, edge vb1105a)

The last review: "a face shown briefly can fall between sampled frames; refuse uncertain results". Live on Meta's API,
the server's own code (`face_look_e2e.escript`,
[`results/server-face-look-5fps-19.json`](results/server-face-look-5fps-19.json)), the 16 clips above and three new ones:

| Clip | Should be | Server's look |
|---|---|---|
| the 8 face clips above | face | **face, 8 of 8** |
| **a face in view for a quarter of a second** (new) | face | **face** |
| **a face in view for a tenth of a second** (new; one frame of a 10 fps clip) | face | **face** |
| the 8 face-free clips above | clear | **clear, 8 of 8**, every one with SAM looking at every sampled frame |
| **a desk video cut off part way** (new: the first 60% of a valid video) | refused | **unsure: refused** |

**10 of 10 faces refused, 8 of 8 face-free clips cleared, the cut-off video refused.** About $0.01 to $0.08 a video
(two and a half times the frames of before), 14 to 32 seconds. The cut-off video matters: without `-xerror`, ffmpeg
read the part it could and exited as if it had finished, so the look would have covered only the start of the video.

## Measured live (Meta's API, 4 Nov)

`face_look_e2e.escript` runs the server's own code (`witness_face:look/2`) end to end. Results:
[`results/server-face-look-16.json`](results/server-face-look-16.json).

| Clip | Should be | Server's look |
|---|---|---|
| a whole face (a generated photo of a student at a desk, 8 s) | face | face |
| the 28 Oct face-cover test video (lower face in view, 20 s) | face | face |
| a face crossing the desk for 3 s of 29 | face | face |
| a face at the frame's edge | face | face |
| a small face in a corner (about 90 px) | face | face |
| the lower half of a face at the top edge | face | face |
| a face in view for one second of 29 | face | face |
| the phone's output from 28 Oct that left a face uncovered (the bug fixed then) | face | face |
| the phone's output after that fix (face covered) | clear | clear |
| a writing hand, pen and paper, no face | clear | clear |
| six rendered desk clips (maths, Arabic, chemistry, a dark desk, a long paper, a 1080p phone clip) | clear | clear |

**8 of 8 faces refused, 8 of 8 face-free clips cleared**, about $0.01 and 10 to 30 seconds a video. Meta deleted the
uploaded copy when asked (`forget: true`).

Before the server code, SAM alone (`face_look.escript`, [`results/sam-face-probe.json`](results/sam-face-probe.json)):
every face clip above found also at two frames a second (the rate the server used until 5 Nov), and **no face on any of 21 rendered
desk clips, the writing hand, the covered phone output, or their two-frames-a-second copies.** One clip, a crop that
by eye shows hair and a sliver of cheek but no face (`p4_edge`), was not called a face.

## Limits

- The look decides what is **marked and kept**, not what is **uploaded**: a video from a modified app still reaches the
  private store and SAM before it is refused. It is then deleted at once.
- A face in view for less than a fifth of a second can still fall between two sampled frames (a tenth of a second
  was caught here, on the one frame it was shown).
- A very long video at five frames a second is many frames for SAM; if SAM looks at fewer than were sent, the video is
  refused and the paper photographed, never marked on a partial look.
- SAM is a model: these are 19 and 41 clips, with one generated face (no real student's face is used or kept here), not
  a proof. The phone's own cover stays the first step; this is the second.
- The test clips themselves are not in this repository (one shows a face); the scripts and results are.

Run: `MODEL_API_KEY=... escript harness/face/face_look_e2e.escript out.json clip1.mp4 clip2.mp4 ...` (ffmpeg on the PATH).
