# Does it strengthen learning? The study we will run, written down before it runs

The fourth independent audit (4 Nov 2026) put it plainly: no controlled study yet shows that From Exam to Mastery
improves learning, transfer or retention compared with another way of learning. That is true. This page fixes the
design **before** any data exists, so the result cannot be shaped after the fact. Changes to it will be dated here, and
made only before the first paper is marked.

## The question

After a marked exam, do students who work through their Mastery Plan answer **new** questions on the same ideas
correctly, **without AI and weeks later**, more often than students who get the usual feedback?

## Design

- **Where:** classes in schools that join the pilot (README 17.6). The school and the parents consent first, and every
  student may leave at any time. No student is denied normal teaching.
- **Randomised within each class, by question.** Each student's failed questions are split at random into two halves.
  - **Mastery Plan**: the question becomes a level (Lo, the challenge, the teacher's "Turned around").
  - **Usual feedback**: the marked paper and the teacher's correction, as the class does today.

  Every student is their own control, so differences between students and between teachers cancel out. One known risk
  is that learning in one half spills into the other: the ideas are split so that the two halves share as few ideas as
  possible.
- **The outcome, fixed now:** a delayed test **3 weeks** after the levels are finished. It is on paper, with no AI, and
  holds **new** items on the same ideas (different numbers and contexts, written by the teacher, never seen in a level).
  It is marked by the teacher, blind to which half each item came from.
- **Secondary outcomes:** the same test at **8 weeks** (did it last?); the share of failed questions whose level was
  finished; the teacher's time per paper.

## Size and analysis

- **Size:** we aim for at least **300 students** with at least 4 failed questions each, so roughly 1,200 paired items.
  If a third of the students are lost, that is still enough to see a difference of about 8 percentage points in
  delayed correctness.
- **Primary analysis:** delayed correctness, Mastery Plan half against usual-feedback half, in a mixed-effects logistic
  model with student and class as random effects. The effect is reported with its 95% interval.
- **Every result is published**, including no difference or a worse one, with the data needed to recompute it.

## What would count against us

Any of these would show the product is not doing what we claim:

- no difference, or a worse result, at 3 weeks;
- a gain at 3 weeks that is gone at 8;
- a gain only on items that look like the original question;
- teachers spending more time than without it.

## What this page is not

It is not a result. Until the study runs, the repository claims only what it measures (README section 7). The product
is **designed to** strengthen independent capability; that it **does** is what this study will test.
