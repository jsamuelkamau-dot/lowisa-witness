# Marking policy: what one click accepts, and what the teacher checks

This is the rule the server enforces (`witness_api:one_click/2`, `risks/2`, `key_of/1`). The Exam Desk only shows it:
whatever list a desk sends, the server applies this rule to every mark. It took effect with edge vb1104p
(4 November 2026); since edge vb1105a (5 November) one click needs a mark scheme the teacher approved (below).

## What never changes

- **Nothing reaches a student until the teacher releases it.** One click is a teacher's action on the desk, not an
  automatic one.
- **The teacher decides.** A mark one click would accept can still be opened and changed. A mark held back is checked
  one by one.
- **The student is never sent a guess**: not the model's possible idea, not its confidence.

## The mark scheme: the teacher's own, or Muse Spark's draft the teacher approved

**Since 5 Nov (owner: "where no scheme is available, AI generates the scheme, reviewed and approved by the teacher"),
the model never marks a class against a key nobody checked.**

1. The teacher creates the exam from a photo or PDF of the paper ("Start from your own paper or mark scheme" on the
   Exam Desk). Muse Spark reads the questions and, **when the material has no mark scheme, drafts one**: the right
   answer to each question, the steps that earn each mark, and other right answers to accept. It is worked out from the
   questions, never from handwriting on the page (`witness_read`).
2. The draft fills the desk's **"Your mark scheme"** box under a first line saying it was drafted by Muse Spark and must
   be checked. The teacher corrects it there.
3. **Creating the exam is the teacher's approval.** The server takes the line off, records `scheme_drafted`, and the
   exam is marked against that scheme. A scheme cannot be changed after the exam is made, so every paper is marked
   against the one approved version (the marking cache is keyed by it too).

| | With a mark scheme (the teacher's own, or the draft they approved) | Without any scheme |
|---|---|---|
| **Marks judged against** | that scheme | the model's own answer key |
| **One click accepts** | marks called right, at least 0.95 sure, with no risk below | **nothing**: every mark is checked one by one |
| **The desk is told** | `judged_against: mark_scheme`, `accept_at: 0.95` | `judged_against: model_key`, and a line no mark reaches (`accept_at: 1.01`), so the desk shows no one-click row |

An exam without a scheme still works (a teacher who typed the questions in, or an exam made before 5 Nov): it is
marked, and the teacher checks each mark. Desktop 0.9.34 needs no update for any of this: the box, the reader and the
one-click row are already there; the server decides what fills them.

**Measured live (5 Nov, `harness/read/`):** Muse Spark drafted a scheme from the unseen physics paper alone (a student's
written paper, 30 questions) three times: **every draft gave the right answer to all 30**, matching the paper's real
mark scheme, and **none copied any of the student's 24 wrong answers** on the page. The drafts differ from the real
scheme only in how many other answers they accept (for example any contact force for Q4), which is what the teacher
checks. Marked against each draft as the scheme, the paper got **30 of 30 decisions right in all three runs**, and one
click accepted 5, 6 and 6 marks, **none wrong**, the same as against the real scheme ([`harness/read/`](../harness/read/README.md)).

## What holds a mark back, however sure the model is

A mark with any of these goes to the teacher, one by one, even at 0.99:

| Risk | When |
|---|---|
| `readings_disagreed` | the readings of the work disagreed (a third reading settled it), or the answers-only check read the final answer differently |
| `crossed_out` | the student struck something out and wrote it again |
| `unclear_writing` | no final answer could be read, or the reading marks it unclear or illegible |

Every mark that is not called right ("mastered"), or is under 0.95 sure, is also checked one by one. When one click
holds a mark back, the server says which risks did it, so the desk can show the teacher why.

## Why these lines: what was measured

On one real Grade 5 learner's multiple-choice papers (109 questions, his own teacher's marks, no mark scheme, three
runs; `python3 evidence/real-handwriting/score.py`):

| One-click line | Accepted in one click | Of those, his wrong answers called right |
|---|---|---|
| 0.90 (until 4 Nov) | 95 to 98 of 109 | 2 to 4 |
| 0.95 | 58 to 82 of 109 | 0 to 2 |
| 0.95 with the risk checks (no scheme) | 58 to 82 of 109 | 0 to 2 |
| **Since 5 Nov: no scheme, no one click** | **0 of 109** | **0** (the teacher checks every mark) |

On these papers the risk checks change nothing, because their risks are not in this kind of paper: multiple choice,
read once, nothing struck out. The wrong answers still accepted were all judged with no mark scheme, against the
model's own key. **That is why, since 5 Nov, one click needs a scheme the teacher approved.** With one, the remaining
risk is the model misreading the handwriting or misapplying the scheme, which the risk checks and the teacher's
release are for; marking is still not perfect. One learner's papers are not enough to set the line for
everyone, and it will be measured again on more real papers (README 17.2).

## Changing this policy

Any change to these lines is the owner's decision, recorded here with its date and the measurement behind it.

- **5 Nov 2026:** one click only with a mark scheme; where the paper has none, Muse Spark drafts one and the teacher
  approves it by creating the exam (owner, after the last review). Edge vb1105a.
- **4 Nov 2026:** line 0.95 (owner, from 0.90). Risk checks added (fourth independent audit). Without a mark scheme,
  one click falls back to the same rule and the desk is told the key was the model's (owner: "both options").
