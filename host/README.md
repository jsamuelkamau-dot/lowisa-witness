# Host-side code built during the hackathon

From Exam to Mastery runs inside LoWisa (see `docs/existed-before.md`). Most of what was built during the event is in
`witness/`, `phone/` and `desk/`. A few parts had to live inside LoWisa's own code. They are copied here, so a judge
can read every line written during the event, and so can tell those lines from LoWisa's older code.

| File | What it is | Built |
|---|---|---|
| `lowisa_edge_witness.erl` | LoWisa's edge as the Witness host (`witness_host`): the account switch (`LOWISA_WITNESS_ACCESS`), signed storage, the Meta Model API key, design calls charged in credits, and the conditional write (`update/3`) | new 27 Oct; `update/3` 31 Oct |
| `course-mastery-mode.ts` | Extracts from LoWisa's level builder: the mastery options, the mastery rule, and the loop that has Muse Wonder check a level and rewrites it with what Muse Wonder found | added 27-31 Oct to an older file |
| `scene-checked-task.txt` | Extracts from LoWisa's scene module and player: a mastery scene's practical task ends in a number the learner types, checked by the player | added 31 Oct to older files |

The phone's Witness screens and the desk are whole files in `phone/witness/` and `desk/`.
