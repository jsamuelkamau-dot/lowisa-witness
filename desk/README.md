# The teacher's Exam Desk

Built this week for LoWisa's desktop app (Electron), synced into it with `scripts/sync_to_host.sh`.

- `witness-desk.js`: the desk. A teacher's exams, each a pile of papers; Muse Spark's marks, with the ones it is least
  sure of first; each answer's fingerprint and the evidence in the learner's own writing; "Accept all" (on an exam with a mark scheme, since 5 Nov; a drafted scheme only once the teacher approved it, which this desk cannot send yet: the next release adds the box, README 17.7) for the marks two
  readings agree on; class patterns; the challenge; "Turned around".
- `witness-ipc.ts`: the desk's only doors to the edge. Nothing is added to the app unless the edge's switch answers.
- `__tests__/`: its tests (they run inside LoWisa's desktop project).

Try it without an account: `node demo/desk-server.js --replay`, then http://localhost:4747.
