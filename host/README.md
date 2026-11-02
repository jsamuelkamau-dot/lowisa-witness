# Work done inside LoWisa's own code during the hackathon

From Exam to Mastery runs inside LoWisa, which existed before the event (see `docs/existed-before.md`). Most of what
was built during the event is in `witness/`, `phone/` and `desk/`, and every line of it is in this repository.

A few parts had to be written inside files that LoWisa already had before 26 Oct. **Those files are LoWisa's
private product code, so they are not published here.** This page says exactly what was added to each one and when,
so a judge can see it existed and where it sits. The interface they implement is public: `witness/src/witness_host.erl`.

| Inside LoWisa's existing… | What was added during the event | When | How you can see it working |
|---|---|---|---|
| Edge server (Erlang/OTP) | The host for this library: the account switch, signed storage for pages and clips, the Meta Model API key from the secret store, design calls charged in the teacher's credits, and the conditional write that lets forty joins land at once. Also a `meta` provider, so the edge can call Meta's models at all | 27 Oct; conditional write 31 Oct | Every live run in `evidence/` and `harness/` went through it |
| Level builder (Master any topic) | A mastery mode: exactly one level of three lessons for one question; lesson 1 runs the student's own step in a real setting, lesson 3 is a real work task; Muse Wonder's self-check after writing, and up to three rewrites with what it found | 27–31 Oct | `harness/selfcheck/`, the film, `evidence/unseen-physics/levels-q23-q24-with-self-check.json` |
| Scene writer and lesson player | A mastery level's practical task ends in a number the student types and the player checks; titles and leads may not give the answer away | 31 Oct | `evidence/screens/phone-practical-task.png` |
| Phone app and desktop app | The From Exam to Mastery tile and the Exam Desk door are wired in; the screens themselves are whole files in `phone/` and `desk/` | 27 Oct | The film, `evidence/screens/` |
