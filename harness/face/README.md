# The server's own face look on a desk video (4 Nov 2026)

The final audit's one remaining trust-boundary point: the server took a desk video because the app said its face look
ran (`faces: "checked"`), and a modified app could say that without looking. Since edge vb1104r the server looks
itself, before anything reads the video (`witness/src/witness_face.erl`, called first in `witness_api:attempt/7`):

1. ffmpeg cuts the video to two frames a second, 480 pixels wide, from its signed link;
2. that copy goes to Meta's file store and SAM 3.1 is asked for `"face"`; the copy is deleted from the store after;
3. **any** face SAM reports, at any confidence, refuses the video: it is deleted unmarked, no still or clip is cut from
   it, and the teacher and the student are told why ("A face could be seen in this video...");
4. a look that cannot run marks nothing (it is tried again only while Meta is busy, as a marking is);
5. a marking cached from before the look existed is not reused for the same video.

Without ffmpeg, or when the copy cannot be made, SAM reads the signed link itself (every frame, dearer, the same look).

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
every face clip above found also at two frames a second (the rate the server uses), and **no face on any of 21 rendered
desk clips, the writing hand, the covered phone output, or their two-frames-a-second copies.** One clip, a crop that
by eye shows hair and a sliver of cheek but no face (`p4_edge`), was not called a face.

## Limits

- The look decides what is **marked and kept**, not what is **uploaded**: a video from a modified app still reaches the
  private store and SAM before it is refused. It is then deleted at once.
- A face in view for less than half a second can fall between two sampled frames.
- SAM is a model: these are 16 and 41 clips, with one generated face (no real student's face is used or kept here), not
  a proof. The phone's own cover stays the first step; this is the second.
- The test clips themselves are not in this repository (one shows a face); the scripts and results are.

Run: `MODEL_API_KEY=... escript harness/face/face_look_e2e.escript out.json clip1.mp4 clip2.mp4 ...` (ffmpeg on the PATH).
