# What was checked in LoWisa's own app build, 4 Nov 2026

The third independent audit asked for evidence from the actual app build, since the phone screens' full tests need
LoWisa's app around them and cannot run in this repository's CI. This is that evidence. The app's own source is
LoWisa's (it existed before the event) and is not published; this records what ran against it and what passed.

## The build checked

- **Phone app:** LoWisa's React Native project as it was next released, 1.10.5 (the Witness screens in this repository
  synced into it, plus the native face look in its Android module). The stores then carried 1.10.4 (Google Play 1.10.4,
  version code 11005; the App Store 1.10.4), which did **not** yet have the changes below (on 4 Nov; 1.10.5 has them, see "Since then" at the end).
- **Desktop app:** the Exam Desk as a part of LoWisa's desktop app source, after desktop 0.9.33 (released as desktop 0.9.34).

## What passed

| Check | Result |
|---|---|
| The phone's Witness tests (12 suites), in LoWisa's project | **80 of 80** passed |
| TypeScript, the whole phone project (`tsc --noEmit`) | **0 errors** |
| The Android native code (`gradlew :app:compileReleaseKotlin`) | **compiles** (the face look's changes included) |
| The face rule on its own, and that every upload goes through it (`phone/__tests__/safe-video.node.test.ts`, in this repository's CI) | **7 of 7** |
| The Exam Desk's JavaScript, in this repository and in the desktop app's source | parses (`node --check`) |

## Every way a video leaves the phone

The Witness screens send a video in exactly two places: the exam's desk video, and the fresh question filmed during a
Mastery Plan. Both take the file from `smaller()`, which applies `safeVideo` (a video goes only on the face look's
explicit `faces: "checked"`), and both stop when it gives nothing. A resumed upload goes through the same check. Nothing
else in the phone app calls the two upload functions. A test in this repository's CI reads the screen's source and fails
if an upload ever appears without the check before it.

## What "checked" means, exactly (the native face look on Android)

- The phone looks at a frame every 2 seconds, at most 300 frames (a 60-minute exam: one every 12 seconds), with ML
  Kit's face detector and its person mask, offline, on the phone.
- Each face or person found beside the page is covered in the frames around it. **Fixed 4 Nov:** the time a face stays
  covered now grows with the gap between looks, so a face that stays in view is covered all the way through, on a video
  of any length. Before, on a video over 25 minutes, it was uncovered between two looks.
- `faces: "checked"` is said only when the look ran to the end: any detector error, or fewer than half the frames
  readable, and the phone sends nothing.
- **The limit that remains:** a face that comes into view and leaves again between two looks (under 2 seconds on a
  short video) can be missed. The main way in, photographing the finished paper, films no one.
- **iPhone** has no face look yet, so it does not offer desk filming at all.

## Until then: the server takes no video from the store apps (fourth audit, finding A)

The apps in the stores (1.10.4) predate the fail-closed rule above. Since edge vb1104p the server takes a desk video, or
a filmed fresh question, only from an app that says its face look ran to the end (`faces: "checked"`). This build says
it in both requests, and only for a file `smaller()` returned; a test in this repository's CI fails if either request
stops saying it. The store apps never say it, so they are refused ("Filming needs the newest LoWisa app...") and the
paper is photographed. The server cannot see faces: this stops the old apps; it is not proof about a video. After this
change, in LoWisa's project: the phone's Witness tests 80 of 80, `tsc --noEmit` 0 errors.

## Still to do before these reach users (as written on 4 Nov; done since, see below)

- The next phone release, with this build run on a device (Android) by its release checklist, and the stores' review.
- The next desktop release, for the desk's one-click line and its wording.

## Since then (status on 5 Nov)

- **Phone 1.10.5 on Google Play** (published 4 Nov). Its store build was run on a device (an Android emulator) against
  the live server before it was sent: a desk video with a face was covered on the phone and marked; the same video sent
  raw by a script was refused by the server's own face look ([live checks 7](../live-checks/README.md)). Android phones
  on 1.10.4 are offered the update.
- **Phone 1.10.5 on the App Store** (submitted 4 Nov, released by Apple 4 Nov, 21:37 UTC). The iPhone build was
  checked on Xcode 27.1's simulator first: the exam page offers "Photograph the papers" and no desk filming.
- **Desktop 0.9.34 released** (4 Nov, Windows, macOS and Linux), with the desk's one-click line, its wording, the
  face chip and the line saying what the marks were judged against.
- **The server no longer relies on `faces: "checked"` alone:** since edge vb1104r it looks for faces in every desk
  video itself ([`harness/face/`](../../harness/face/README.md)).
