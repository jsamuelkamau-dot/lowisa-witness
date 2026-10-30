# The Misconception Fingerprint

> Not simply whether the answer is correct, but **what reasoning produced it**, **what evidence supports the
> diagnosis**, and **which intervention can repair it**.

Three students can circle the same wrong answer for three different reasons, and each reason needs a different repair.
A mark ("0 of 3") hides all three. A generic re-teach ("here is how percentages work") repairs none of them precisely.
The fingerprint is what From Exam to Mastery reads from the student's own handwriting before anything is taught.

## The rule

1. **Classify only on evidence.** A misconception is named only when the student's own ink holds enough evidence to
   tell it apart from the other ways the same answer could be reached. The evidence is quoted exactly as written.
2. **Otherwise, ask.** When the ink is not enough (a bare answer, an intuition with no numbers, working that fits two
   ideas), Lo asks the student **one diagnostic question**, out loud, in their Mastery Plan, before the level is built.
   Their answer, written or spoken, is evidence too, and completes the fingerprint. At most two questions, then the
   level is built from what is known: the student is never held up.
3. **Repair that idea only.** The intervention targets the named idea, never a re-teach of the whole method, and the
   mastery level is built around it.
4. **The teacher sees everything**: the reasoning, the evidence, what the student told Lo, the intervention. The badge
   is still the teacher's.

## One question, three learners

The question (from the demo paper, Year 9 Mathematics):

> A product costs $100. Its price increases by 50%, then decreases by 50%. What is its final price?
> A $100 · B $75 · C $50 · D $150

It looks easy: a child can follow the story, and an adult can still fall into the trap of thinking +50% and −50%
cancel. It is the same arithmetic as a salary rise then a cut, inflation then a sale, an investment's gain then loss.

All three learners below circled **A $100**. The fingerprints are Muse Spark's own output, recorded on 30 Oct 2026 from
photographs of the paper (`evidence/misconceptions/*.json`, reproducible with `harness/fingerprint_check.escript`).
The papers are samples made for the demo; the readings are live.

### Learner A: the cancellation misconception

![Learner A, question 4](../evidence/misconceptions/learner-a-cancellation-q4.jpg)

| | Muse Spark read |
|---|---|
| Evidence (as written) | `+50% - 50% = 0%` · `so it stays at $100.` |
| Reasoning | Reasoned that a 50% increase and a 50% decrease cancel to 0% so the price stays at $100. |
| Misconception | **successive percentages combine additively** |
| Intervention | Calculate 50% of $100 to get $150, then 50% of $150, and compare the size of the increase with the size of the decrease. |
| Lo asks | (nothing: the ink is enough) |
| Marks | 0 of 3 |

### Learner B: the changing-base misconception

![Learner B, question 4](../evidence/misconceptions/learner-b-changing-base-q4.jpg)

| | Muse Spark read |
|---|---|
| Evidence (as written) | `100 + 50 = 150` · `150 - 50 = 100` |
| Reasoning | Calculated the increase to $150 correctly but then subtracted $50, which is 50% of the original $100, instead of 50% of $150. |
| Misconception | **second change taken from original amount** |
| Intervention | Calculate what 50% of $150 actually is and compare it to the $50 subtracted, to see which amount the decrease is of. |
| Lo asks | (nothing: the ink is enough) |
| Marks | **1 of 3**: the increase was worked correctly, and the method mark is kept |

Learner B is not Learner A. B understands percentage change; B only takes the second change from the wrong base. A
re-teach of "what a percentage is" would waste B's time. The intervention names the one thing to fix.

### Learner C: the mental-model misconception

![Learner C, question 4](../evidence/misconceptions/learner-c-mental-model-q4.jpg)

| | Muse Spark read |
|---|---|
| Evidence (as written) | `A $100` · `Half up, half down. Same price.` |
| Reasoning | Reasoned that half up then half down must return to the same price without calculating each change. |
| Misconception | **percentage changes cancel** (an intuition: the steps were never worked as numbers) |
| Intervention | Work each step in dollars: first the price after the 50% increase, then 50% of that new price. |
| **Lo asks first** | **"You wrote 'Half up, half down' – half of what amount each time?"** |
| Marks | 0 of 3 |

"Half up, half down" shows an intuition, not which calculation the student believes. Learner C might halve $100 twice
(B's idea) or believe the halves cancel (A's idea). So before the level is built, Lo asks, out loud, about C's own
words. The answer is read by Muse Spark with the ink (`POST mastery/<sitting>/<n>/diagnose`, `witness_fingerprint.erl`)
and the fingerprint is completed; the level is then built around the intervention that fits.

## Where it lives in the code

| Step | Code |
|---|---|
| The rule in the marking prompt (photo and filmed papers) | `witness/src/witness_mark.erl` `fingerprint_rule/0`, `witness/src/witness_photo.erl` |
| Evidence before a label: a named misconception without quoted evidence becomes a question | `witness_mark:fingerprint/2` |
| Lo's diagnostic question, answered in writing or by voice (Muse Voice Transcribe), read by Muse Spark | `witness/src/witness_fingerprint.erl`, `witness/src/witness_api.erl` `diagnose_step/5` |
| Nothing reaches a model unless Lo is still asking | `witness_fingerprint:pending/1`, tested in `witness_api_tests` |
| The level is built around the intervention | `phone/witness/mastery.ts` `fingerprintLines/1` |
| "Lo asks first", spoken by Lo, on the phone | `phone/witness/WitnessScreen.tsx` `LoAsks` |
| The teacher's view of the whole fingerprint | `desk/witness-desk.js` `fingerprintCard` |
| The badge recommendation reads it | `witness/src/witness_recommend.erl` |
| Tests | `witness/test/witness_fingerprint_tests.erl` (the three learners, evidence before a label, at most two questions) |
