# A drafted mark scheme for the teacher to approve (5 Nov 2026, edge vb1105a)

The last review's remaining marking point: without a mark scheme, one click accepted marks judged against the model's
own answer key, which nobody had checked (on the one real learner's papers, 0 to 2 wrong answers a run). The owner's
design: **where no scheme is available, Muse Spark generates one, and the teacher reviews and approves it before
marking.**

How it runs, with no phone or desktop release (desktop 0.9.34 already has every part):

1. On the Exam Desk the teacher creates the exam from a photo or PDF of the paper ("Start from your own paper or mark
   scheme"). `witness_read` reads the questions; when the material has no scheme, Muse Spark also drafts one, worked
   out from the questions, never from handwriting on the page.
2. The draft fills the desk's "Your mark scheme" box under a first line: *DRAFTED BY MUSE SPARK (your paper had no mark
   scheme): check and correct every line.* The teacher corrects it there.
3. Creating the exam takes the line off (`witness_read:undraft/1`), records `scheme_drafted`, and every paper is
   marked against that one scheme; it cannot be changed afterwards. **Since edge vb1105b creating the exam is not the
   approval:** no mark on a draft is accepted in one click until the teacher approves it explicitly, with the time,
   the teacher and the scheme's SHA-256 recorded ([marking policy](../../docs/marking-policy.md)). A draft whose line
   was deleted is still known as a draft.
4. One click needs a scheme (`witness_api:one_click/2`). An exam with none is still marked, and the teacher checks every
   mark; the desk is sent a line no mark reaches, so it shows no one-click row.

## Measured live (Meta's API, 5 Nov)

The unseen physics paper ([`evidence/unseen-physics/`](../../evidence/unseen-physics/README.md)): `paper.jpg` is a
student's written paper (a sample student), 30 questions, 6 of his answers right and 24 wrong; its real mark scheme is
`mark-scheme.jpg` / `scheme-read.txt`.

| Check | Result |
|---|---|
| A scheme drafted from the paper alone, three runs ([results](results/physics-paper-draft-3-runs.json)) | all 30 questions read every run; **every draft gives the right answer to all 30**, matching the real scheme; **none takes any of the student's 24 wrong answers** (Joules, Ampere, nuclear, conduction, 100 kg...); they differ from the real scheme only in how many other answers they accept, which is what the teacher checks. About $0.013 and 20 s a draft |
| The paper marked against each draft as the scheme ([results](results/physics-marked-against-each-draft.json)) | **30 of 30 decisions right in all three runs**; one click accepts 5, 6 and 6 marks, **none wrong**: the same as against the real scheme |

The drafts were not edited before marking, so this measures the draft alone; a teacher's check comes on top. One
paper, one subject: a drafted scheme can be wrong on a harder paper, which is why it is the teacher's to correct and
approve, and why an approved scheme removes a wrong key but not a misread.

Run:
```bash
MODEL_API_KEY=... escript harness/read/draft_scheme.escript out.json 3 evidence/unseen-physics/paper.jpg
MODEL_API_KEY=... escript evidence/unseen-physics/local_mark.escript D1 draft1.txt   # a draft (without its first line) as the scheme
```
The key is read from the environment and never printed. Tests: `a_paper_without_a_scheme_gets_a_draft_for_the_teacher_to_check_test`
(`witness_reaudit_tests`), `an_exam_from_a_checked_draft_scheme_is_marked_against_it_test` (`witness_api_tests`).
