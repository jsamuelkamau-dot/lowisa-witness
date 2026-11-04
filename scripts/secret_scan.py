"""Refuse a push when a tracked file looks like it holds a secret, an account id or real learner data.

Run from the repo root:
  python scripts/secret_scan.py             the tracked files (the pre-push hook runs it)
  python scripts/secret_scan.py --history   also every file in every commit, and every picture, video and recording's
                                            metadata (CI runs it on the full history)

4 Nov 2026 (third independent audit: "a passing scan does not cover deleted content in history, provider keys outside
its patterns, or metadata in media"): --history reads every blob any commit ever held, not only today's files, and
checks each picture, video, recording and PDF for metadata a camera or phone leaves (EXIF, GPS, a PNG text chunk,
QuickTime location or device names, XMP beyond the AI-made label Muse Image writes). What it cannot see is still the
reader's to check: text inside an image (every published picture was looked at by hand, evidence/PUBLISHING.md).
"""
import hashlib, pathlib, re, subprocess, sys

PATTERNS = {
    "Meta/LLM key": r"LLM[A-Za-z0-9_\-|]{30,}",
    "OpenAI key": r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_\-]{20,}",   # not inside a word ("desk-fingerprint-...")
    "AWS access key": r"(AKIA|ASIA)[0-9A-Z]{16}",
    "bearer token": r"Bearer [A-Za-z0-9_\-\.|]{24,}",
    "private key": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "ElevenLabs key": r"\bsk_[a-f0-9]{40,}\b",
    "GitHub token": r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{40,}",
    "Google API key": r"\bAIza[0-9A-Za-z_\-]{35}\b",
    "Slack token": r"\bxox[abprs]-[A-Za-z0-9-]{10,}",
    "Stripe live key": r"\b(sk|rk)_live_[A-Za-z0-9]{20,}",
    "signed JWT": r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{20,}",
    "signed URL": r"X-Amz-Signature=[0-9a-f]{20,}",
    "email address": r"[A-Za-z0-9._%+-]+@(?!example\.com|noreply)[A-Za-z0-9.-]+\.[a-z]{2,}",
}
ALLOW = {"LICENSE"}
# our cloud account ids, kept only as hashes so this file never names them
ACCOUNT_HASHES = {"a7f50a81a1e5c5bff8e9c4ecf99a51ec8a3b2a095cf10ad0c25d572351a439e9"}
MEDIA = re.compile(r"\.(jpe?g|png|webp|heic|gif|mp4|mov|m4a|wav|pdf)$", re.I)
# the one XMP block allowed: Muse Image's "made by a trained algorithm" label (IPTC DigitalSourceType)
AI_LABEL = b"digitalsourcetype/trainedAlgorithmicMedia"


def text_findings(name, text):
    out = []
    for kind, rx in PATTERNS.items():
        for m in re.finditer(rx, text):
            out.append(f"{name}:{text.count(chr(10), 0, m.start()) + 1}: looks like {kind}")
    for m in re.finditer(r"\b\d{12}\b", text):
        if hashlib.sha256(m.group().encode()).hexdigest() in ACCOUNT_HASHES:
            out.append(f"{name}:{text.count(chr(10), 0, m.start()) + 1}: looks like our cloud account id")
    return out


def png_chunks(b):
    i, out = 8, []
    while i + 8 <= len(b):
        n = int.from_bytes(b[i:i + 4], "big"); t = b[i + 4:i + 8]; out.append(t); i += 12 + n
        if t == b"IEND": break
    return out


def media_findings(name, b):
    """Metadata a camera, a phone or an editor leaves in a file."""
    out = []
    if b[:2] == b"\xff\xd8" and (b"Exif\x00\x00" in b[:65536]):
        out.append(f"{name}: has EXIF (camera, time or place)")
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        extra = {c for c in png_chunks(b)} & {b"tEXt", b"iTXt", b"zTXt", b"eXIf", b"tIME"}
        if extra:
            out.append(f"{name}: PNG metadata chunk {sorted(c.decode() for c in extra)}")
    if MEDIA.search(name) and re.search(r"\.(mp4|mov|m4a)$", name, re.I):
        for tag in (b"\xa9xyz", b"com.apple.quicktime.location", b"com.apple.quicktime.make", b"com.android.manufacturer",
                    b"com.android.model", b"\xa9mak", b"\xa9mod"):
            if tag in b:
                out.append(f"{name}: video metadata {tag!r}")
    for m in re.finditer(rb"<x:xmpmeta.*?</x:xmpmeta>", b, re.S):
        if AI_LABEL not in m.group(0) or re.search(rb"(Creator|Author|Location|GPS|City|Country|Make|Model)", m.group(0)):
            out.append(f"{name}: XMP metadata beyond the AI-made label")
    if b[:4] == b"%PDF" and re.search(rb"/(Author|Creator|Producer)\s*\(", b):
        out.append(f"{name}: PDF author or creator field")
    return out


def blob(sha):
    return subprocess.run(["git", "cat-file", "blob", sha], capture_output=True, check=True).stdout


bad = []
files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.split()
for f in files:
    if f in ALLOW: continue
    p = pathlib.Path(f)
    if not p.exists(): continue
    raw = p.read_bytes()
    if MEDIA.search(f):
        bad += media_findings(f, raw)
        continue
    try:
        bad += text_findings(f, raw.decode("utf-8"))
    except UnicodeDecodeError:
        continue

scanned = len(files)
if "--history" in sys.argv:
    seen, objects = set(), subprocess.run(["git", "rev-list", "--all", "--objects"], capture_output=True, text=True, check=True).stdout
    for line in objects.splitlines():
        sha, _, path = line.partition(" ")
        if not path or sha in seen or path.split("/")[-1] in ALLOW: continue
        if subprocess.run(["git", "cat-file", "-t", sha], capture_output=True, text=True).stdout.strip() != "blob": continue
        seen.add(sha)
        b = blob(sha)
        where = f"{path} (history {sha[:8]})"
        if MEDIA.search(path):
            bad += media_findings(where, b)
            continue
        try:
            bad += text_findings(where, b.decode("utf-8"))
        except UnicodeDecodeError:
            continue
    scanned += len(seen)

if bad:
    print("secret scan FAILED:\n  " + "\n  ".join(sorted(set(bad))))
    sys.exit(1)
print(f"secret scan ok ({scanned} files{' and history blobs' if '--history' in sys.argv else ''})")
