# Real handwriting: one student, three papers, his teacher's marks

The first real handwriting in this repository: answers written by a real Grade 5 student in his own
pencil, and marked by his class teacher, who is not on our team. Everything else in `harness/` is sample papers.

**Consent and privacy.** His parent gave consent. His name, his school's name, his class and his student number are
blurred on every photo. The photos carried no location or other metadata.

**What was marked.** Three multiple-choice papers from the end of his school term: maths (30 questions),
English (30) and integrated science (50), 110 questions in all. The printed question papers are a commercial practice
series, so this folder shows his answer sheets and one small excerpt of a question page, not the full papers. Two more
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
   then the answer sheet), on the production edge vb1103a, `witness/src` at commit `0b7502c`, Muse Spark 1.3.
   Once, on 3 Nov 2026, with no change to the code before or between runs.
4. **Two conditions.** A: the pages as photographed. Three of the nine question pages were photographed sideways.
   B: the same pages with those three turned upright, nothing else changed.

## Results

| | A: as photographed | B: sideways pages turned upright |
|---|---|---|
| Questions where Witness and the teacher agree | **102 of 109** (93.6%) | **105 of 109** (96.3%) |
| Answers the teacher marked wrong that Witness also marked wrong | 4 of 10 | **7 of 10** |
| Marked wrong by Witness, right by the teacher | 1 | 1 |
| A wrong answer given an invented reason | 0 | **0 of 9**: every one says only the letter is on the page, and Lo asks him first |
| Time per paper | 36–101 s | 53–70 s |

**Every disagreement in B**, and what we can tell from the photos:

| Question | Teacher | Witness | What happened |
|---|---|---|---|
| Science Q33 | wrong (he wrote D) | right, read "C" | He wrote D on both the sheet and the question paper. Witness read the correct answer instead of his: **a reading error.** |
| Science Q42 | wrong (sheet: B) | right, read "D" | His sheet says B; on the question paper he circled D. Witness went with the paper. |
| Maths Q24 | wrong (he chose B, 10:55 pm) | right | A clock-face question; from the photo we cannot settle which is right. |
| English Q13 | right (A, "Our teachers") | wrong | A reading-comprehension question whose passage supports more than one answer. |

**What the sideways pages cost.** In A, Witness read his letter correctly on maths Q11 but took the option's value from
the wrong place on a sideways page, and read an unclear letter on Q12 as the right one. Turning the pages upright
caught both, and English Q23 and the left-out science Q20 also moved to the teacher's mark. A teacher's phone will
photograph some pages sideways, so the product should turn every page upright before marking; that is the fix this run
points to.

## Limits

- **One student, one teacher, multiple choice only.** This tests reading a child's handwritten letters from phone
  photos and marking them against a real teacher. It does not test written working, which is where the fingerprint
  does its work; for multiple choice, Witness rightly names no wrong idea and has Lo ask. Written answers from many
  students are the pilot's first step (main README, section 16).
- **The teacher's marks were read by us**, from the photos. Where his marks were unclear (science Q20) the question is
  left out rather than guessed.
- **Removing the ink by colour** left faint pink specks, and where a tick crossed a letter a little of the stroke may
  be lost. The letters Witness misread in B (Q33, Q42) were checked against the originals and are still clear.
- **Two runs, one each.** No run was repeated or chosen.
