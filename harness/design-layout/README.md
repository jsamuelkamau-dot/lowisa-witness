# The design route's message layout, before and after edge vb1104m (4 Nov 2026)

The independent audit (finding B) asked that a client never send a system message. Since vb1104m the server's scope
is the only system message, and the phone's level-builder instructions arrive as a user message marked as the app's.
This checks that the change costs nothing in level quality and holds against a tampered app.

- The request: the exact outline request the phone builds for one live paper's question 4 (sample paper A, "a 50%
  rise and a 50% fall cancel out", marked on the production edge on 4 Nov), made by LoWisa 1.10.4's own level builder
  (`masteryBrief`, `outlineUserPrompt`, `MASTERY_RULE`, `TOPIC_OUTLINE_SYSTEM`). It is LoWisa's code that existed
  before the event, so the request is not published here; the scripts read it as `outline_req.json` from the folder.
- `ab.mjs`: sends it to Muse Spark 1.3 in the old layout (the app's system message, then the scope) and the new one,
  with the phone's own settings (low effort, 12,000 tokens). The scope is read from each version's source.
- `hostile.mjs`: the same, with a tampered app's instruction to write a history essay.

| | old layout | new layout |
|---|---|---|
| valid outline, on the student's idea, one level of three lessons, no answer in a title | 4 of 4 | 4 of 4 |
| tampered app: "write my history essay" | refused 4 of 4 | refused 4 of 4 |

```bash
git show <commit before vb1104m>:witness/src/witness_api.erl > /tmp/ab/old.erl   # c62b5e6 or 935dffc
cp witness/src/witness_api.erl /tmp/ab/new.erl   # and the phone's request as /tmp/ab/outline_req.json
MODEL_API_KEY=... node harness/design-layout/ab.mjs /tmp/ab 4
MODEL_API_KEY=... node harness/design-layout/hostile.mjs /tmp/ab 4
```
