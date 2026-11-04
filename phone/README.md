# The learner's screens (phone)

The From Exam to Mastery screens built this week for LoWisa's phone app (React Native), synced into it with
`scripts/sync_to_host.sh`; the app around them existed before.

- `witness/WitnessScreen.tsx`: exams on paper, the learner's Mastery Plan, each question's result.
- `witness/Proof.tsx`: Proof of Thinking, what their own working shows and what Lo asks first.
- `witness/SayIt.tsx`, `witness/OwnStep.tsx`: answering Lo out loud (Muse Voice Transcribe) or in writing.
- `witness/Examiner.tsx`, `witness/TurnedAround.tsx`: the teacher's challenge and its "Turned around" card.
- `witness/mastery.ts`, `witness/metaRoute.ts`, `witness/net.ts`: opening a mastery level, the routes to the edge.
- `android/WitnessCameraActivity.kt`: the camera for photographing a paper or filming a desk.
- `witness/safeVideo.ts`: whether a desk video may leave the phone (only on the face look's explicit `faces: "checked"`).
- `__tests__/`: the screens' tests (they run inside LoWisa's phone project, whose test setup is not in this repository),
  except `safe-video.node.test.ts`, which tests `safeVideo.ts` on its own and runs in this repository's CI
  (`node --test phone/__tests__/safe-video.node.test.ts`, Node 23.6 or later).

**LoWisa code these screens import (existed before, not in this repository):** `ui/theme`, `ui/Page`, `ui/SoftInput`
(styling and page frames), `state/storage` (local storage), `live/edge` and `community/net` (the connection to LoWisa's
server), `community/video`, `voice/recorder` and `tutor/voice` (camera upload, recording and Lo's voice),
`billing/credits` (LoWisa credits), `course/store`, `paths/custom/course` and `exam/print/ui` (opening a level, printed
exams), and `career/documents`. The screens' tests also load parts of LoWisa's lesson player (`paths/`, `map/`, `game/`,
`teaching/`) to open a mastery level.
