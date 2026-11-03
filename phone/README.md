# The learner's screens (phone)

The From Exam to Mastery screens built this week for LoWisa's phone app (React Native), synced into it with
`scripts/sync_to_host.sh`; the app around them existed before.

- `witness/WitnessScreen.tsx`: exams on paper, the learner's Mastery Plan, each question's result.
- `witness/Proof.tsx`: Proof of Thinking, what their own working shows and what Lo asks first.
- `witness/SayIt.tsx`, `witness/OwnStep.tsx`: answering Lo out loud (Muse Voice Transcribe) or in writing.
- `witness/Examiner.tsx`, `witness/TurnedAround.tsx`: the teacher's challenge and its "Turned around" card.
- `witness/mastery.ts`, `witness/metaRoute.ts`, `witness/net.ts`: opening a mastery level, the routes to the edge.
- `android/WitnessCameraActivity.kt`: the camera for photographing a paper or filming a desk.
- `__tests__/`: the screens' tests (they run inside LoWisa's phone project, whose test setup is not in this repository).
