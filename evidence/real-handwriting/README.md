# Real handwriting: one student, three papers, his teacher's marks

The first real handwriting in this repository: answers written by a real Grade 5 student in his own
pencil, and marked by his class teacher, who is not on our team. Everything else in `harness/` is sample papers.

**Consent and privacy.** His parent consented to these papers being used and published, his name included. We chose to
blur his name anyway, with his school's name, his class and his student number, on every photo. The photos carried no
location or other metadata. To ask about them or have them taken down: [lowisa.dev](https://lowisa.dev).

**What was marked.** Three multiple-choice papers from the end of his school term: maths (30 questions),
English (30) and integrated science (50), 110 questions in all, 109 scored (the teacher's mark on science Q20 is
unclear). The printed question papers are a commercial practice series, so this folder shows his answer sheets and two
questions from one page, not the full papers. Two more
answer sheets (social studies/RE and creative arts) were left out because the question paper photographed with them is a
different paper: the answers he circled on it do not match either sheet.

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
flatters any marker; the useful number is the wrong answers caught, 7 of 10 (95% interval 40–89%, ten is few), with
one right answer marked wrong. Kappa, which discounts agreement by chance, is 0.67–0.76 on the code that ships.

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
was named from the choice alone on 4 of 27 wrong answers (for example "LCM is the product of the numbers"). Commit
`6611ef2` treats the option chosen, with its printed words, as the final answer, which is no evidence
(`witness_mark:chosen_option/2`, with a test); re-applied to those four, all four are held and Lo asks first.

**What turning pages upright gained.** In A, Witness read his letter correctly on maths Q11 but took the option's value
from the wrong place on a sideways page, and read an unclear letter on Q12 as the right one. B, turned by hand, caught
both; C, with the server turning the pages itself, catches both in every run.

## Limits

- **One student, one teacher, multiple choice only.** This tests reading a child's handwritten letters from phone
  photos and marking them against a real teacher. It does not test written working, which is where the fingerprint
  does its work; for multiple choice, Witness rightly names no wrong idea and has Lo ask. Written answers from many
  students are the pilot's first step (main README, section 16).
- **The teacher's marks were read by us**, from the photos. Where his marks were unclear (science Q20) the question is
  left out rather than guessed.
- **Removing the ink by colour** left faint pink specks, and where a tick crossed a letter a little of the stroke may
  be lost. The letters Witness misread in B (Q33, Q42) were checked against the originals and are still clear.
- **A and B ran once each, C three times.** No run was repeated or chosen; run 2 of C was slow (244 and 299 s for two
  papers) and is reported as it came.
