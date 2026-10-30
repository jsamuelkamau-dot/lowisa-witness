"""Refuse a push when a tracked file looks like it holds a secret, an account id or real learner data.

Run from the repo root: python scripts/secret_scan.py  (the pre-push hook runs it).
"""
import hashlib, pathlib, re, subprocess, sys

PATTERNS = {
    "Meta/LLM key": r"LLM[A-Za-z0-9_\-|]{30,}",
    "OpenAI key": r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_\-]{20,}",   # not inside a word ("desk-fingerprint-...")
    "AWS access key": r"AKIA[0-9A-Z]{16}",
    "bearer token": r"Bearer [A-Za-z0-9_\-\.|]{24,}",
    "private key": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "ElevenLabs key": r"\bsk_[a-f0-9]{40,}\b",
    "email address": r"[A-Za-z0-9._%+-]+@(?!example\.com|noreply)[A-Za-z0-9.-]+\.[a-z]{2,}",
}
ALLOW = {"LICENSE"}
# our cloud account ids, kept only as hashes so this file never names them
ACCOUNT_HASHES = {"a7f50a81a1e5c5bff8e9c4ecf99a51ec8a3b2a095cf10ad0c25d572351a439e9"}

files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.split()
bad = []
for f in files:
    if f in ALLOW: continue
    try:
        text = pathlib.Path(f).read_text(encoding="utf-8")
    except (UnicodeDecodeError, FileNotFoundError):
        continue
    for name, rx in PATTERNS.items():
        for m in re.finditer(rx, text):
            line = text.count("\n", 0, m.start()) + 1
            bad.append(f"{f}:{line}: looks like {name}")
    for m in re.finditer(r"\b\d{12}\b", text):
        if hashlib.sha256(m.group().encode()).hexdigest() in ACCOUNT_HASHES:
            bad.append(f"{f}:{text.count(chr(10), 0, m.start()) + 1}: looks like our cloud account id")
if bad:
    print("secret scan FAILED:\n  " + "\n  ".join(bad))
    sys.exit(1)
print(f"secret scan ok ({len(files)} files)")
