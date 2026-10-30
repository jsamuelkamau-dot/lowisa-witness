"""Every number the README quotes about marking, recomputed from the raw results committed beside this file.

  python harness/bench/summary.py

A question counts as exact when the marking's result is the result the case was written to have (cases/*.json,
written before the run), by bench.escript's own rule: an answer written with no working ("no_working") is exact when it
is not given full marks as mastered (since 29 Oct the marking calls it part way), and "sound" when mastered or not
mastered agrees, which is what decides whether a student gets a mastery level. Video runs mark the desk clip (SAM 3.1 + Muse Spark); the photo run marks a photo of the
finished page (Muse Spark), on the same papers."""
import json, os

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
RUNS = [
    ("run3", "27 Oct, video, 13 clips (11 papers in 6 languages + 2 messy copies)"),
    ("run4", "27 Oct, video, the same 13 clips again"),
    ("1028", "28 Oct, video, after the out-of-marks fix"),
    ("1028b", "28 Oct, video, a second run the same day (one split reading: the fix that followed is the third reading)"),
    ("cmp_video2", "28 Oct, video, the comparison set (14 clips, with the rubbed-out reason)"),
    ("photo", "28 Oct, photo of the finished page, the same papers"),
    ("load39", "28 Oct, load test: 39 papers marked at once"),
]


def count(path):
    papers = json.load(open(path, encoding="utf-8"))
    qs = [q for p in papers for q in p.get("questions", []) if "truth" in q]
    def exact(q):
        if q["truth"] == "no_working":
            return not (q["result"] == "mastered" and q.get("marks") == q.get("out_of"))
        return q["result"] == q["truth"]
    def sound(q):
        if q["truth"] == "no_working":
            return exact(q)
        return (q["result"] == "mastered") == (q["truth"] == "mastered")
    return len(papers), len(qs), sum(map(exact, qs)), sum(map(sound, qs))


if __name__ == "__main__":
    print("| Run | Papers | Questions | Exact | Sound |")
    print("|---|---|---|---|---|")
    for rid, what in RUNS:
        n, q, e, ok = count(os.path.join(HERE, rid + ".json"))
        print("| %s | %d | %d | %d of %d | %d of %d |" % (what, n, q, e, q, ok, q))
