# What is published about real people, and how it was checked

Written 4 Nov 2026 after the third independent audit ("inspect examination images, screenshots, recordings, metadata
and Git history for unauthorised personal information and confirm the right to publish"). Re-run the machine checks
with `python scripts/secret_scan.py --history` (CI runs it on every push).

## The one real learner

`evidence/real-handwriting/` holds the answer sheets and three written answers of one real Grade 5 student, marked by
his own class teacher (who is not on our team).

- **Consent.** His parent consented in writing to the papers being used and published, his name included; the
  written consent is held by LoWisa and available if required.
- **Blurred anyway.** His name, school, class and student number are blurred on every photo. Looked at by hand on
  4 Nov: all six sheet photos and all five photos as sent to the model, and the one older version of a sheet that
  remains in the history (`maths-question-page-excerpt.jpg`, printed questions only). None shows his name, school,
  class or number.
- **What stays visible:** his pencil answers, his teacher's red marks and totals, and printed questions (one names a
  community in Kenya, the country of the paper). The printed question papers are a commercial practice series, so only
  two questions from one page are shown.
- **History.** His first name, which appeared in an early commit, was removed from every commit on 4 Nov (the
  history was rewritten, `harness/PROVENANCE.md`).

## Everyone else

- **Sample students** (Priya Nair, Leo Martins, Tomás Silva, Daniel Kwan, the held-out and class sets) are fictional.
  Their handwriting is a font on a simulated photograph.
- **Screenshots** (current and every older version in the history): the LoWisa app, the Exam Desk and the sample
  students only. No account name, email or real learner. A Clock it card in one phone screenshot shows a pseudonymous
  community name ("Daring Badger 90"), not a person's name.
- **Voices.** The film's narrator is a synthetic voice; the spoken answers in the probes are synthetic (Amazon Polly).
  No real student's voice is published.
- **Drawings** made by Muse Image carry one piece of metadata, the standard IPTC label "made by a trained algorithm".

## Metadata

Every picture, video, recording and PDF in every commit was checked (228 media files ever committed): no EXIF, no GPS,
no PNG text chunk, no QuickTime location or device name, no PDF author field, and no XMP beyond the AI-made label.
Five early screenshots in the history were damaged by a line-ending conversion before they were replaced; they cannot be
decoded by anyone (no row of their image data survives), so they show nothing.

## Exam codes seen in pictures and tests

Some screenshots and test files show exam codes. On 4 Nov every code in the repository and its history was checked
against the live server:
- the codes in the current screenshots (an earlier demo exam's) no longer exist;
- four test exams' join codes, visible in older screenshots or used as sample values in phone tests, still existed:
  joining was **closed** on all four (the teacher's own "Close joining"), checked live ("Your teacher has closed joining
  for this exam"), and the test files now use made-up codes.

## What a scan cannot see

Text inside a picture is not read by the scanner; every published picture was looked at by hand on 4 Nov, as above.
