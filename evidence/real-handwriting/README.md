# Real handwriting: one student, his papers, his teacher's marks

The first real handwriting in this repository: answers written by a real Grade 5 student in his own
pencil, and marked by his class teacher, who is not on our team. Everything else in `harness/` is sample papers.

**Consent and privacy.** His parent consented to these papers being used and published, his name included; **the
written consent is available if required.** We chose to blur his name anyway, with his school's name, his class and his
student number, on every photo. The photos carried no
location or other metadata. To ask about them or have them taken down: [lowisa.dev](https://lowisa.dev).

**What was marked.** Three multiple-choice papers from the end of his school term: maths (30 questions),
English (30) and integrated science (50), 110 questions in all, 109 scored (the teacher's mark on science Q20 is
unclear). The printed question papers are a commercial practice series, so this folder shows his answer sheets and two
questions from one page, not the full papers. Two more
answer sheets (social studies/RE and creative arts) were left out because the question paper photographed with them is a
different paper: the answers he circled on it do not match either sheet. **His written answers** (42 questions on three
more papers) are a second test, below.

## How it was run

1. **The answer key is the teacher's.** We read his red-pen marks on each sheet (a tick is right; a curl is wrong):
   maths Q11, 12, 14, 24, 26 and 29 wrong (his total, 24/30, agrees); English Q23 and 27 wrong (28/30 agrees);
   science Q33 and 42 wrong, and Q20 unclear (a "wrong" curl with another mark over it), so Q20 is left out of
   the counts. [`results/three-papers-two-conditions.json`](results/three-papers-two-conditions.json) records it all.
2. **The teacher's ink was removed before marking**, by colour (his letters are grey pencil, the teacher's marks are
   red pen), so the model could not copy the ticks. What was sent is in [`sent/`](sent/); the sheets as the teacher
   marked them are in [`sheets/`](sheets/).
3. **The live product marked it**: the photo path a teacher uses (one exam, one paper per subject, the question pages
   then the answer sheet), on the production edge, Muse Spark 1.3, all on 3 Nov 2026.
4. **Three conditions.**
   - **A, as photographed** (edge vb1103a, `witness/src` `0b7502c`, once). Three of the nine question pages were
     photographed sideways.
   - **B, the three sideways pages turned upright by us, by hand**, nothing else changed (same code, once). This was the
     experiment: it showed what turning pages would gain, before the product could do it.
   - **C, the code that ships, as photographed, three runs** (edges vb1104a–c, `witness/src` `a1be423`). Nothing was
     turned by hand: the server asks Muse Spark which edge of each photo is the page's top, turns it, and marks the paper
     in parts at once. [`results/condition-c-shipped-code-3-runs.json`](results/condition-c-shipped-code-3-runs.json)
     records every answer, each run's time, and each page's shape as sent and as stored.

## Results

Recompute every number here with `python3 evidence/real-handwriting/score.py`.

| | A: as photographed | B: turned upright by hand | C: the code that ships, 3 runs |
|---|---|---|---|
| Questions where Witness and the teacher agree | 102 of 109 | 105 of 109 | **105, 103, 105 of 109** |
| The teacher's wrong answers Witness also marked wrong | 4 of 10 | 7 of 10 | **7 of 10** in every run |
| Marked wrong by Witness, right by the teacher | 1 | 1 | 1, 3, 1 |
| Cohen's kappa against the teacher | 0.50 | 0.76 | 0.76, 0.67, 0.76 |
| The sideways page stored upright | no | (by hand) | **9 of 9** papers |
| Time per paper | 36–101 s | 53–70 s | 69–299 s (median about 100 s) |

**What the numbers mean.** Marking every answer right would agree with the teacher on 99 of 109, so agreement alone
flatters any marker; the useful number is the wrong answers caught, 7 of 10 in each run (95% interval 40–89%, ten is
few), with one right answer marked wrong. By question, 6 of the 10 were caught in every run (`score.py` prints both). Kappa, which discounts agreement by chance, is 0.67–0.76 on the code that ships.

**Every disagreement in C**, over the three runs:

| Question | Teacher | Witness | Runs | What happened |
|---|---|---|---|---|
| Maths Q24 | wrong (he chose B, 10:55 pm) | right | 3 of 3 | A clock-face question; from the photo we cannot settle which is right. |
| English Q23 | wrong (he wrote D) | right | 3 of 3 | Every run read his D, and judged D the right answer; the teacher (and B, once) marked it wrong. The disagreement is over the answer, not the reading. |
| English Q13 | right (A, "Our teachers") | wrong | 3 of 3 | A comprehension question whose passage supports more than one answer. |
| Science Q33 | wrong (he wrote D) | right, read "C" | 2 of 3 | He wrote D on the sheet and the question paper; Witness read the correct letter instead: **a reading error.** |
| Science Q42 | wrong (sheet: B) | right, read "D" | 1 of 3 | His sheet says B; on the question paper he circled D. |
| Science Q26, Q28 | right | wrong | 1 of 3 each | Misread once each, in the slow second run. |

**What C found that the code got wrong, and the fix.** For multiple choice the page shows only the letter, so no idea
should be named and Lo should ask first. In run 1 it did, every time. In runs 2 and 3 the reading of a question page
included the option he circled with its printed text ("A 24 circled"), the code took that as his own ink, and an idea
was named from the choice alone on 4 of the 26 answers it did not accept, over the three runs (for example "LCM is the product of the numbers"). Commit
`6611ef2` treats the option chosen, with its printed words, as the final answer, which is no evidence
(`witness_mark:chosen_option/2`, with a test); re-applied to those four, all four are held and Lo asks first.

**What turning pages upright gained.** In A, Witness read his letter correctly on maths Q11 but took the option's value
from the wrong place on a sideways page, and read an unclear letter on Q12 as the right one. B, turned by hand, caught
both; C, with the server turning the pages itself, catches both in every run.

## His written answers: 42 questions, no marking scheme

The papers above are multiple choice. These are his own words: short written answers, a sequence, a list, a music
rhythm written in note symbols, written on the printed question pages themselves, with no separate answer sheet and
**no marking scheme given to Witness**. Three papers from the same term: creative arts (SBA006, pages 3 and 4, Q15–30),
integrated science (SBA006, page 4, Q35–50) and creative arts (SBA003, page 4, Q21–30). 42 questions, of which 30 are
written answers or drawings and 12 circled options.

- **The key is his teacher's**, read by us from the red pen (a long tick is right, a short curl or hook is wrong):
  creative arts Q28 wrong ("Digo community" for the Olwika); science Q35 (cow peas as a cereal), Q41 (the order of
  laundry steps) and Q46 ("iron" for rickets) wrong; every other answer right. Each page total that is visible agrees
  (10 and 5 on the two creative-arts pages).
- **Run the same way as condition C:** the ink removed by colour, the photos as taken, the live product (edge vb1104d,
  `witness/src` `6611ef2`), three runs on 3 Nov 2026. A page from another student was sent by mistake in the same
  runs; it was deleted from the product, and it is in no file here.
- [`results/written-answers-3-runs.json`](results/written-answers-3-runs.json) records every answer as read, every
  mark, and every note to the teacher; `score.py` recomputes the numbers. Two excerpts, as marked and as sent:
  [`sheets/written-creative-arts-q28-30.jpg`](sheets/written-creative-arts-q28-30.jpg),
  [`sent/written-creative-arts-q28-30.jpg`](sent/written-creative-arts-q28-30.jpg),
  [`sheets/written-science-q41.jpg`](sheets/written-science-q41.jpg),
  [`sent/written-science-q41.jpg`](sent/written-science-q41.jpg).

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Questions where Witness and the teacher agree | 37 of 42 | 38 of 42 | 38 of 42 |
| The teacher's wrong answers Witness also marked not yet mastered | 3 of 4 | 3 of 4 | 3 of 4 |
| Marked not yet by Witness, right by the teacher | 4 | 3 | 3 |
| A wrong idea named to the student | **0** | **0** | **0** |
| Time per paper | 119–155 s | 127–163 s | 90–145 s |

**What the numbers mean.** Marking every answer right would agree on 38 of 42 too, so agreement here says little, and
kappa is 0.48–0.55. Four wrong answers is far too few to measure how many are caught (3 of 4; 95% interval 30–95%).
What this does show: Witness read a Grade 5 student's written words from phone photos, in subjects it was never tuned on
(it was built on mathematics), without a marking scheme, and judged most of them as his teacher did, including two
things he drew: a rhythm in note symbols and a quaver rest (both Q30, right in every run). **And every answer it did not accept, right or wrong, was held for Lo to ask, with no idea
named and no label shown to him**: the design choice, *when unsure, ask*, held on all 19 of them.

**Every disagreement:**

| Question | Teacher | Witness | Runs | What happened |
|---|---|---|---|---|
| Science Q41, laundry steps | wrong | right | 3 of 3 | He wrote *sorting, mending, soaking, washing, rinsing, drying, ironing*. That is the order textbooks usually give; from the page we cannot see why the teacher marked it wrong. Over the answer, not the reading. |
| Creative arts Q18, first step of a mosaic | right (B, collect materials) | not yet, Lo asks | 3 of 3 | Witness judged making a sketch to come first. The answer key, not the reading. |
| Creative arts Q20, the fabric picture | right (B, applique) | not yet, Lo asks | 3 of 3 | Witness took the printed picture for batik. A reading of the printed picture, not of his ink. |
| Science Q44, an organic waste pit | right | not yet, Lo asks | 3 of 3 | His answer is squeezed onto the question's own printed lines, and the teacher's tick ran through it; with the ink removed, Witness read it as crossed out (and once misread it). **A reading error**, made worse by the ink removal. |
| Creative arts (SBA003) Q21, "Abu" | right | not yet, Lo asks | 1 of 3 | Run 1 took the name of the horn for a cut-off word; runs 2 and 3 marked it right. |

## Limits

- **One student, one teacher.** The multiple-choice papers test reading a child's handwritten letters; the written
  answers test reading his words, without a scheme. Neither tests long written working (a calculation over several
  lines), which is where the fingerprint does its work: none of these answers shows a method, so Witness rightly named
  no idea and had Lo ask. Written working from many students is the pilot's first step (main README, section 17).
- **The teacher's marks were read by us**, from the photos. Where his marks were unclear (science Q20) the question is
  left out rather than guessed.
- **Removing the ink by colour** left faint pink specks, and where a tick crossed a letter a little of the stroke may
  be lost. The letters Witness misread in B (Q33, Q42) were checked against the originals and are still clear.
- **A and B ran once each, C and the written answers three times.** No run was repeated or chosen; run 2 of C was slow (244 and 299 s for two
  papers) and is reported as it came.
