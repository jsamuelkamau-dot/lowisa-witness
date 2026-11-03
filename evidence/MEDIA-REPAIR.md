# Sixteen damaged images, and how each was put right (3 November 2026)

**What happened.** `.gitattributes` said `* text=auto eol=lf` and listed only `*.png` as binary. Git stripped the CR
from every CR LF byte pair in 16 committed images, so they lost 1 to 7 bytes each. Some no longer opened at all.
Others opened with damaged pixels. The round-3 review panel found it, and `scripts/check_media.py` now checks every
committed media file in CI (PNG chunk CRCs, WebP and WAV RIFF sizes, JPEG segments, and a full ffmpeg decode).
Every media type is now marked binary.

**How each was restored.** No file was redrawn by hand or edited.

| Files | How | Exact original? |
|---|---|---|
| `evidence/screens/desk-accept-confident-marks.png`, `phone-level-lessons-done.png`, `phone-recheck.png`, `phone-recheck-right.png` | Each PNG chunk carries its length and a CRC-32. For every chunk, the lost CRs were put back at the one placement of LF bytes that makes the CRC match. | Yes: every chunk's CRC matches |
| `evidence/replay/assets/`: the page photos of the three replay sittings, two stills and `world-4.webp` (9 files) | Downloaded again from the product's asset store, where the recorder (`demo/record-replay.cjs`) first read them | Yes: the stored originals |
| `harness/probes/results-31oct/drawn-learner-{a,b,c}.webp` | WebP carries no checksum, so they cannot be rebuilt. Muse Image drew them again with the same learners, question and code: `harness/probes/redraw_3nov.escript`, results in `harness/probes/results-03nov/` | No: new drawings, $0.053 in all |

The real-handwriting images (`evidence/real-handwriting/`) were checked against the files they were made from, and are
identical.
