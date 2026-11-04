# Marking policy: what one click accepts, and what the teacher checks

This is the rule the server enforces (`witness_api:one_click/2`, `risks/2`, `key_of/1`). The Exam Desk only shows it:
whatever list a desk sends, the server applies this rule to every mark. It took effect with edge vb1104p
(4 November 2026).

## What never changes

- **Nothing reaches a student until the teacher releases it.** One click is a teacher's action on the desk, not an
  automatic one.
- **The teacher decides.** A mark one click would accept can still be opened and changed. A mark held back is checked
  one by one.
- **The student is never sent a guess**: not the model's possible idea, not its confidence.

## The two options: with a mark scheme, and without one

The teacher can give the exam's mark scheme, the answers and how marks are given, when creating the exam. What the
marks are judged against depends on that.

| | With the teacher's mark scheme | Without one (it falls to the next) |
|---|---|---|
| **Marks judged against** | the teacher's mark scheme | the model's own answer key |
| **One click accepts** | marks called right, at least 0.95 sure, with no risk below | the same: marks called right, at least 0.95 sure, with no risk below |
| **The desk is told** | `judged_against: mark_scheme` | `judged_against: model_key`, so the teacher knows the key was not theirs |

When there is no mark scheme, nothing is blocked: the rule falls back to the next option, and the desk says so. **We
recommend giving a mark scheme.** On the one real learner's papers (no scheme), every wrong answer one click still
accepted at 0.95 had been judged against the model's own key (below).

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

On these papers the risk checks change nothing, because their risks are not in this kind of paper: multiple choice,
read once, nothing struck out. The wrong answers still accepted were all judged with no mark scheme. That is why the
desk says which key was used, and why we recommend a scheme. One learner's papers are not enough to set the line for
everyone, and it will be measured again on more real papers (README 17.2).

## Changing this policy

Any change to these lines is the owner's decision, recorded here with its date and the measurement behind it.

- **4 Nov 2026:** line 0.95 (owner, from 0.90). Risk checks added (fourth independent audit). Without a mark scheme,
  one click falls back to the same rule and the desk is told the key was the model's (owner: "both options").
