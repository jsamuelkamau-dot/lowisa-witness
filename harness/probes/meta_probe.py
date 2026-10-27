"""Day-1 probe: does SAM 3.1 follow fresh ink in a phone video, and can Muse Spark mark the thinking from it?

  MODEL_API_KEY=... python harness/probes/meta_probe.py clip.mp4 [out_dir]

Uploads the clip once (Files API), asks SAM 3.1 to track a few concept prompts, then asks
Muse Spark 1.3 to read the video and mark each answer's path. Writes the raw responses to
out_dir (default probe-out/, git-ignored) and prints a short summary with the cost.
"""
import json, os, pathlib, re, sys, urllib.request, uuid

API = "https://api.meta.ai/v1"
KEY = os.environ["MODEL_API_KEY"]
SAM_PER_FRAME = 0.0002                 # $ per video frame (dev.meta.ai pricing, 2026-10-27)
SPARK_IN, SPARK_OUT = 1.25e-6, 4.25e-6  # $ per token, Standard mode

MARK_PROMPT = """This video shows a student's paper while they answer a short quiz. The printed questions are at the top.
Watch the whole video. Return JSON only:
{"questions":[{"q":1,"final_answer":"...","steps":[{"t":seconds,"wrote":"...","crossed_out":true|false}],
"result":"mastered|right_answer_wrong_thinking|part_way|not_yet","diagnosis":"one sentence naming the exact misconception, or empty","moment_s":seconds or null,"confidence":0-1}],
"pauses":[{"from_s":..,"to_s":..}]}
Judge the thinking, not only the final answer."""


def post(path, body, headers):
    req = urllib.request.Request(API + path, data=body, headers={"Authorization": "Bearer " + KEY, **headers})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)


def upload(clip):
    b = "----w" + uuid.uuid4().hex
    data = (f"--{b}\r\nContent-Disposition: form-data; name=\"purpose\"\r\n\r\nuser_data\r\n"
            f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{clip.name}\"\r\n"
            f"Content-Type: video/mp4\r\n\r\n").encode() + clip.read_bytes() + f"\r\n--{b}--\r\n".encode()
    return post("/files", data, {"Content-Type": "multipart/form-data; boundary=" + b})["id"]


def respond(body):
    return post("/responses", json.dumps(body).encode(), {"Content-Type": "application/json"})


def text_of(resp):
    return "".join(c.get("text", "") for o in resp.get("output", []) for c in (o.get("content") or [])
                   if c.get("type") == "output_text")


def main():
    clip = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "probe-out"); out.mkdir(exist_ok=True)
    fid = upload(clip)
    cost = 0.0
    for prompt in ("paper", "number", "word"):
        r = respond({"model": "sam-3.1", "metadata": {"include_confidence": "true"},
                     "input": [{"type": "message", "role": "user", "content": [
                         {"type": "input_text", "text": prompt}, {"type": "input_video", "file_id": fid}]}]})
        (out / f"sam_{prompt}.json").write_text(json.dumps(r))
        t = text_of(r)
        frames = r.get("usage", {}).get("video_frames_processed", 0)
        cost += max(frames, 50) * SAM_PER_FRAME
        ids = set(re.findall(r"(?:^|,)(\d+)<\|box", t, re.M))
        print(f"SAM '{prompt}': {sum(1 for l in t.splitlines() if l.strip())} of {frames} frames matched, {len(ids)} objects")
    r = respond({"model": "muse-spark-1.3", "reasoning": {"effort": "medium"}, "max_output_tokens": 6000,
                 "input": [{"type": "message", "role": "user", "content": [
                     {"type": "input_text", "text": MARK_PROMPT}, {"type": "input_file", "file_id": fid}]}]})
    (out / "spark_mark.json").write_text(json.dumps(r))
    u = r.get("usage", {})
    cost += u.get("input_tokens", 0) * SPARK_IN + u.get("output_tokens", 0) * SPARK_OUT
    print("Spark marking:", text_of(r))
    print(f"cost about ${cost:.3f}")


if __name__ == "__main__":
    main()
