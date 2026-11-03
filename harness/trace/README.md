# One real paper, every Meta call

The real Grade 5 student's English paper (30 multiple-choice questions, four phone photos, one of them sideways; the
name blurred, his teacher's ink removed) through the product's own code at commit `6dc039b`, on 3 Nov 2026. Every
call to Meta is written down: [`results/trace-english-03nov.json`](results/trace-english-03nov.json).

```
python3 -c "import json; [print(c['step'], c['effort'], round(c['ms']/1000,1), 's', c['output_tokens'], 'out', round(c['cost_usd'],4)) for c in json.load(open('harness/trace/results/trace-english-03nov.json'))['calls']]"
```

| Step | Model, effort | What the code did with it |
|---|---|---|
| Which edge is the top, every page | Muse Spark, low | page 2 was sideways: turned 270° clockwise before marking |
| The paper in three parts, at once | Muse Spark, medium | each part fitted to its questions |
| Two parts: their answers alone, read again | Muse Spark, low, from the prompt cache | every short answer read the same both times: nothing more needed |
| One part with an unsure question: read in full again, then a third time | Muse Spark, high | the third reading decided the split |

**The whole paper:** 8 calls, $0.23 at Meta's published prices, nearly all of every reading's input
served from Meta's prompt cache (11,363 of 11,483 tokens). 26 of 30 answers joined "Accept all" (mastered, 90% sure, two readings
alike); two were held for Lo to ask, with no idea named.

**Time:** 235 s, most of it one first reading that took 189 s on its own. The same parts took 63–65 s on 3 Nov
(`harness/parts/`); the time is Meta's on the day, and a trace shows it rather than hides it.

Run it again (Meta key in `MODEL_API_KEY`, never printed; ffmpeg on the path):

```
sh scripts/test.sh
escript harness/trace/trace_paper.escript harness/trace/results/<out>.json page1.jpg page2.jpg ...
```
