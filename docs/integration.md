# How From Exam to Mastery plugs into a host

The server side is a set of Erlang modules (`witness/src`; the `witness_` prefix is from the desk-filming mode built
first) that run inside a host's OTP application. In production the host is
LoWisa's edge server. `scripts/sync_to_host.sh path/to/app` copies the modules and their tests into a host.

## What the host provides

| Point | What the host does | In LoWisa |
|---|---|---|
| Meta API key | Hands `witness_meta` the key on each call; nothing in the library reads configuration | A SecureString parameter in the host's own secret store |
| Streaming chat | Calls `witness_meta:chat_request(ModelId, Messages, Opts)` for the URL and body, then streams it with its existing OpenAI-style reader, TLS options from `witness_meta:ssl_opts()` | The provider module gains one `meta` clause; its connection pool, breaker and cancellation apply as for every provider |
| Metering | Charges each call: tokens through the host's price table, SAM frames, images and audio seconds through `witness_meta:cost/2` | Two house-only model rows (Muse Spark 1.3, Muse Wonder 1.0) at Meta's Standard prices; learners can't choose them for anything else |
| Who may use it | A switch limited to pilot accounts | The host's existing switch mechanism |
| The level builder | Receives the mastery-level input (question, diagnosis, the student's working, the teacher's focus note) and builds the level the same way it builds every level | LoWisa's Master any topic builder (existed before) |
| A mastery level's calls | Every model call the level makes goes to `POST design` with the paper it is for (`for`), so it runs on Muse Spark and the exam's teacher pays: the build, the lessons written when opened, the flashcards and Lo's live turns (`reply: "text"`). `phone/witness/metaRoute.ts` decides which paths are mastery levels | The lesson writer, flashcard maker and live teacher ask `askMeta` for a mastery level's path; the Insight episode is asked with `witness: true` and written on Muse Spark |

## Model calls it makes

| Call | Endpoint | Function |
|---|---|---|
| Upload a clip | `POST /v1/files` (purpose `user_data`) | `witness_meta:upload/4` |
| Track the page and the ink | `POST /v1/responses`, model `sam-3.1`, `input_video` | `witness_meta:sam_video/3`, read with `witness_sam` |
| Read and mark the clip | `POST /v1/responses`, model `muse-spark-1.3`, `input_file` | `witness_meta:read_video/5` |
| Agent turns | `POST /v1/chat/completions` (streamed) | the host's stream with `witness_meta:chat_request/3` |
