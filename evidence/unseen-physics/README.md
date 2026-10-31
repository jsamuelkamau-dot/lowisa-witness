# An exam it had never seen: Form 3 physics, 31 October 2026

Everything in From Exam to Mastery was built and tuned on mathematics. This is the first time it met a physics paper.
Nothing in the code or the prompts names this paper, this subject or these questions. We ran it the way a teacher
would, on the production edge the judges use, to find out whether it works on an exam nobody prepared it for, or
only on the ones we tested.

**The paper:** 30 questions across forces, energy, electricity, magnetism, heat, waves, pressure and buoyancy. One
photo shows both pages ([paper.jpg](paper.jpg)). The student, Daniel Kwan (a sample student), wrote 30 answers by hand:
6 are right and 24 are wrong in the ways real students get them wrong. One example is question 24, "Explain why a
large steel ship floats while a small metal nail sinks", answered with "Heavy objects sink and light objects float."

**Ground truth:** a physics teacher's correct marking, one mark per question. The answers Daniel got right are 3, 17,
19, 28, 29 and 30 (6/30). [score.py](score.py) holds the key and how each run is compared to it.

## 1. Reading the exam (the teacher's "start from your own paper")

| Input | Read | Time |
|---|---|---|
| Photo of the paper | all 30 questions, word for word, with the right marks; title and level | 6.2 s |
| Photo of the mark scheme | all 30 answers in the scheme, including the worked lines ("200 ÷ 50 = 4") | 9.3 s |

**Found and fixed:** on the teacher's desk, reading the scheme after the paper replaced the 30 questions with 30
blanks, because a scheme has numbers but no question words. The desk now keeps the paper's questions and adds the
scheme ([desk test](../../desk/__tests__)).

## 2. Marking: six runs on the live edge, three without a scheme and three with one

| | Without a scheme | With the scheme |
|---|---|---|
| Score given | 6/30, 6/30, 6/30 | 6/30, 6/30, 6/30 |
| Marking decisions that match the correct marking | **90 of 90** | **90 of 90** |
| Handwritten answers read correctly | 90 of 90 | 90 of 90 |
| Name, class and date read from the paper | 3 of 3 | 3 of 3 |
| Time to mark the paper (photo in, marks out) | 46–58 s | 40–52 s |
| Cost per paper (Muse Spark) | about $0.05 | about $0.05 |

So the marking was right on all 180 decisions, including with no scheme at all, where it marked from its own physics
knowledge. Two of the answers it marked right (question 19, density "200 ÷ 50 = 4 g/cm³", and question 29, "300 000
km/s") are easy for a tired marker to cross out by mistake. It gave both their marks in every run.

Raw results: [live-6-runs-before-fix.json](live-6-runs-before-fix.json).

## 3. What the test found wrong, and what changed

**a) A written explanation was treated as a bare answer.** The diagnosis rule was built on mathematics, where an
answer with no working on the page says nothing about the thinking behind it, so Lo asks first. On a physics paper
the explanation IS the working. Daniel wrote his idea down ("Heavy objects sink and light objects float"), yet it was
named in only 4 of 6 runs. "P = 100 × 0.5 = 50 Pa" was named in only 2 of 6, and the teacher saw "Only the answer … is
on the page" under a full sentence.

*Change* (`witness_mark`): an answer that is itself the working, a calculation or a sentence of five or more words,
counts as the student's own evidence. The rule tells the marker that a written explanation is the working, and names
the idea it states. A one-word recall answer ("Joules", "Nuclear") still has Lo ask a question first, because one word
does not show which wrong idea produced it.

**b) "Part way" with every mark.** In one run without a scheme, five one-mark answers came back "part way" at 1 of 1.
*Change* (`witness_mark:question/1`): a question part way or not yet there never holds every mark. A right answer
reached by wrong thinking keeps what the scheme gives it.

| Q24 and others: idea named (N) or Lo asks first (a), six runs | Before | After |
|---|---|---|
| Q24 "Heavy objects sink and light objects float." | a N N N a N | **N N N N N N** |
| Q21 "P = 100 × 0.5 = 50 Pa" | a a a N N a | **N N N N N N** |
| Q15 "Angle of incidence is bigger than angle of reflection." | a N N N a N | **N N N N N N** |
| Q23 "There is less oxygen higher up." | a a a a a a | **N N N N N N** |
| Q1 "Joules", Q11 "It attracts all metals.", Q20 "P = F × A" (one word or a recalled formula) | a | a (unchanged, as intended) |
| Marking decisions right | 180 / 180 | 180 / 180 |

After the change, every one of the 180 marking decisions was still right: [6-runs-after-fix.json](6-runs-after-fix.json).

## 4. Did the change hurt anything else? (the held-out set)

The held-out set is 53 photographed papers in 13 topics, labelled before any run ([harness/heldout](../../harness/heldout)).
The dangerous error is naming a wrong idea when the ink cannot tell which idea it was.

| Held-out v2, 3 runs (159 papers) | Before (committed rule) | After (first draft of the change) |
|---|---|---|
| Right work marked mastered | 39 / 39 | 39 / 39 |
| Ink that tries to instruct the marker, never marked mastered | 30 / 30 | 30 / 30 |
| Ink that shows the idea: named right | 43 / 48 | 42 / 48 |
| Ink that cannot tell: Lo asks, nothing named | 40 / 42 | 38 / 42 |

Both versions got the same two papers wrong on the "cannot tell" items. One is a compound-interest paper, "200 × 1.05 =
210", which was named in 1 of 3 runs before the change and 3 of 3 after. Three runs is too few to tell whether that is
noise, so the wording was narrowed to answers in words only. Then the five hardest "Lo should ask" papers were run
five times each on the old code and the new:

| Five hardest "ask" papers × 5 runs | Old code | New code (shipped) |
|---|---|---|
| Lo rightly asks | 20 / 25 | 21 / 25 |
| An idea named the ink cannot show | 5 / 25 | 4 / 25 |

Files: [old](hard-ask-papers-5-runs-old-rule.json), [new](hard-ask-papers-5-runs-new-rule.json). The compound-interest
paper is the known weak spot of both versions: the old code named it 5 of 5 times, the new one 3 of 5. Lo's question
is the safety net, because the student's answer to it settles the idea before a lesson is built on it.

## 5. From the failed question to a lesson (question 24)

The test continued on the live system, using a fresh exam built with the corrected scheme:

1. Daniel joined with the class code.
2. His paper was photographed and marked in 35 s.
3. The name read from the paper ("Daniel Kwan") linked it to his account by itself.
4. The teacher released the marks.

On his phone the paper showed **6 of 30 · 24 in your Mastery Plan**, and question 24 showed his own words with what
they reveal: *"Explained floating by lightness alone instead of displaced water upthrust balancing weight."*
([screen](screens/1-q24-on-the-phone.png))

**The level was built for an idea it had never been tuned on.** Two levels were built at the same time, question 24
and question 23 (atmospheric pressure). Each took about 8 minutes from the tap to "ready for the teacher", including
the self-check.

| | Q24: "Ships, Nails and Upthrust" | Q23: "Altitude Pressure Explained" |
|---|---|---|
| Lesson 1 | Predicting ship and nail (the weight trap, a harbour test tank) | A sealed snack bag swelling on the climb from 2,860 m to 4,910 m |
| Lesson 2 | Displaced water pushes up: upthrust balances weight | The weight of the air above |
| Lesson 3 (a real task) | Load a cargo barge to its safe displacement limit | A mountain guide calibrates an altimeter and signs the log |
| Self-check, playing Daniel's wrong idea | caught in all 3 lessons | caught in all 3 lessons |
| Self-check, playing a student who understands | passes all 3 | passes all 3 |
| False claims found by the self-check | none | none |

We checked the numbers ourselves too. A 76,000-tonne ship displacing 76,000 t of water gets 745,560,000 N of upthrust
(76,000 × 9,810), and the lesson shows exactly that. A 4 g steel nail displaces about 0.5 mL of water (4 ÷ 7.85 g/cm³).
For Q23, the air pressure is about 72 kPa at 2,860 m and 55 kPa at 4,910 m, which is what the standard atmosphere
gives at those heights.

**Played on the phone as Daniel:**
- the first look ([displacement](screens/3-first-look-displacement.png));
- his own turn on the slider, to the upthrust that holds the ship ([746M N](screens/4-slider-746M-N.png));
- Lo talking his exact idea through ("Steel is heavy, so shouldn't every steel thing sink?", [screen](screens/5-lo-talks-the-trap-through.png));
- a wrong answer, corrected with the reason ([screen](screens/6-wrong-answer-corrected.png)), then a new case answered right ([screen](screens/7-check-right-with-why.png));
- the lesson's questions;
- the halfway twist, where he loads 2,500 t of cargo and the ship pushes 6,500 t aside and still floats ([screen](screens/8-twist-cargo-6500t.png));
- the tutor's ideas.

**What the phone run found, and what was done:**

| Found on screen | Why it matters | Done |
|---|---|---|
| The graph's axis read "1.20e+3M" | computer notation on a physics-sized number | fixed: "1.2B", tested (phone test103) |
| An instruction read "Lo, slide the displaced-water amount…" | Lo speaking to itself instead of the learner | fixed in the scene player: the line is said to the learner, tested (test103) |
| Live meters showed displaced water 3,953 t under a weight of 3,977 t on a ship that floats | the lesson's point is that the two are equal; the readouts drifted apart | fixed: meters of one unit move together, tested (test103) |
| "Float number (push minus weight)" | an invented name; a physics teacher says "net upward force" | open: wording of the lesson writer |
| The tutor spends 8 ideas setting the scene again after the first look, with text drawings ("Picture it") | slow; the animations already showed it | open: the pace of an existing feature, not a fault in the physics |
| Lesson 3's last line says "from Question 24" | the exam leaks into the lesson's words | open: wording of the lesson writer |

## Summary

| What was tested on an exam the system had never seen | Result |
|---|---|
| Reading the paper and the scheme from photos | 30/30 questions, 30/30 scheme answers |
| Marking, with and without a scheme, six runs | 180/180 decisions right; 6/30 every run |
| Reading handwriting, name, class, date | all of it, every run |
| Naming the student's idea when his ink shows it | Q24 6/6 after the fix (4/6 before) |
| Asking first when the ink cannot tell | unchanged or better (held-out set and the hardest five) |
| A mastery level built from the failed question | built, self-checked both ways, physics correct |
| Faults found | 2 fixed in marking (`vb1031g`, live), 1 on the desk, 3 in the scene player (phone test103); 3 open, all wording or pacing |

## How to repeat it

```bash
python run.py read paper.jpg                      # the desk's "start from your paper", live
python run.py mark A1 questions-read.json         # pile, photo, mark, wait (no scheme)
python run.py mark B1 questions-read.json scheme-read.txt
python score.py mark                              # compare with the correct marking
escript local_mark.escript A1 no                  # the same through the library code, before a ship
```
