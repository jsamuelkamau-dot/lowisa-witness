# Privacy, safety and retention

Written 31 Oct 2026, after the 12-judge panel found no privacy or minors statement. Each line below says what the code
does today, and where.

## What goes where

| Data | Who sends it | Where it goes | Kept |
|---|---|---|---|
| The teacher's exam file (questions and mark scheme) | the teacher's desk | Muse Spark (the Meta Model API), to read the questions | not kept; the questions read from it are kept with the exam |
| Photographs of a finished paper (name, class, working) | the phone that photographs, with the exam's photographing code | the host's storage (signed links), then Muse Spark reads the pages | with the paper until the teacher deletes it |
| A video of the desk while a student writes (desk filming, the optional way in) | the student's phone, by signed upload | SAM 3.1 and Muse Spark read it through a signed link | **deleted as soon as it is marked**; only short clips and stills at the moments that matter are kept |
| The student's answer to Lo, an explanation, a challenge reason (typed or spoken) | the student's phone | Muse Spark reads the text; a spoken answer goes to Muse Voice Transcribe first | the text, and the recording "for the teacher to hear", with the paper until the teacher deletes it |
| Names | the paper, the class list | **never in a prompt except the page photo itself**: class patterns send students as numbers (`witness_patterns:prompt/2`) | with the exam |

Every student-written text inside a prompt is wrapped as data, and every prompt that carries one says so
(`witness_text`). Nothing a student writes is ever followed as an instruction.

## Who can see what (`witness_api`)

- **The teacher:** everything in their own exams.
- **A student:** their own paper once released.
  - They see their marks, the Mastery Plan, the challenge and the re-check.
  - They never see the model's guess, its rivals, its confidence or its first reading (`student_q/1`).
  - They never see the verdicts on their reasons.
- **The phone that photographs:** it may send pages and start the marking, and nothing else.
  - It cannot read any paper's pictures, recordings or record (`reader_of/3`).
- **Anyone with the class's join code:** it puts a name on the class list. It cannot photograph.
  - A name that joins after a paper was photographed is never linked to that paper on its own. The teacher confirms it.
  - The teacher can take any name off the list and close joining.

## Deleting

The teacher deletes a paper or a whole exam. With it go:
- its rows and every photographed page, recording, still, clip and drawing;
- every pointer to it: its student, students it was linked to before, the phone that photographed it;
- the self-checks of its levels and its cached marking (`forget/4`).

A paper deleted while it is being marked stays deleted (`witness_api:done/8` writes only onto a paper that still exists).

## Limits on use

- **Every route that calls a model has a ceiling a day for one account.** A whole class fits under it; a script does not.
- **Each mastery level's design calls have a ceiling.** Those calls are only for the caller's own released level, and they carry the server's own first instruction to stay on that level's idea.
- **Lo's live turns are read for safety before they reach a student** (`witness_guard`).

## For the owner to decide before a pilot with minors

- Who the controller is (the school), the consent the school collects (a parent's or guardian's, where the law asks for one), and the age at which a student may join on their own.
- A default expiry for pages and recordings (today: kept until the teacher deletes them).
- A deletion request from a student or a parent, made to the school and carried out by its teacher (today: the teacher deletes the paper).
- Who may create an exam (today: any LoWisa account with the feature; a school role could be required).
- The Meta Model API's own terms for data sent to it apply. This repository makes no claim beyond them.
