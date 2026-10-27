# Reads a SAM 3.1 video response and the clip's MP4 frame times, then prints when each tracked
# object first appeared, where, and for how long: a first look at the "ink timeline".
import json, re, struct, sys

def frame_times(path):
    data = open(path, "rb").read()
    def boxes(buf, start, end):
        i = start
        while i + 8 <= end:
            size, kind = struct.unpack(">I4s", buf[i:i + 8])
            head = 8
            if size == 1: size, head = struct.unpack(">Q", buf[i + 8:i + 16])[0], 16
            elif size == 0: size = end - i
            if size < head: break
            yield kind.decode("latin1"), i + head, i + size
            i += size
    def find(buf, start, end, path_):
        for kind, s, e in boxes(buf, start, end):
            if kind == path_[0]:
                if len(path_) == 1: return s, e
                r = find(buf, s, e, path_[1:])
                if r: return r
        return None
    moov = find(data, 0, len(data), ["moov"])
    for kind, s, e in boxes(data, *moov):
        if kind != "trak": continue
        hdlr = find(data, s, e, ["mdia", "hdlr"])
        if data[hdlr[0] + 8:hdlr[0] + 12] != b"vide": continue
        mdhd = find(data, s, e, ["mdia", "mdhd"])
        ver = data[mdhd[0]]
        scale = struct.unpack(">I", data[mdhd[0] + (20 if ver else 12):mdhd[0] + (24 if ver else 16)])[0]
        stts = find(data, s, e, ["mdia", "minf", "stbl", "stts"])
        n = struct.unpack(">I", data[stts[0] + 4:stts[0] + 8])[0]
        t, out = 0, []
        for k in range(n):
            cnt, dl = struct.unpack(">II", data[stts[0] + 8 + 8 * k:stts[0] + 16 + 8 * k])
            for _ in range(cnt):
                out.append(t / scale); t += dl
        return out

def records(text):
    for line in text.split("\n"):
        m = re.match(r"<(\d+)f>(.*)", line)
        if not m: continue
        f = int(m.group(1))
        for oid, box in re.findall(r"(?:^|,)(\d+)<\|box;([^|]+)\|>", m.group(2)):
            kv = dict(p.split("=") for p in box.split(";"))
            yield f, int(oid), {k: float(v) for k, v in kv.items()}

resp, clip = sys.argv[1], sys.argv[2]
times = frame_times(clip)
text = json.load(open(resp))["output"][0]["content"][0]["text"]
seen = {}
for f, oid, b in records(text):
    s = seen.setdefault(oid, {"first": f, "last": f, "n": 0, "box": b})
    s["last"] = max(s["last"], f); s["first"] = min(s["first"], f); s["n"] += 1
    if f == s["first"]: s["box"] = b
print(f"frames {len(times)}, clip {times[-1]:.1f}s, objects {len(seen)}")
for oid, s in sorted(seen.items(), key=lambda kv: kv[1]["first"]):
    b = s["box"]
    print(f"id {oid:3} first {times[s['first']]:5.1f}s last {times[s['last']]:5.1f}s seen {s['n']:3} "
          f"box x {b['x1']:.0f}-{b['x2']:.0f} y {b['y1']:.0f}-{b['y2']:.0f} c {b.get('c', 0):.2f}")
