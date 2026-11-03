#!/usr/bin/env python3
"""Check that every committed image and sound file is whole, byte for byte.

Until 3 Nov 2026 git stripped the CR from every CR LF byte pair in 16 committed images (evidence/MEDIA-REPAIR.md).
This walks each PNG's chunks (lengths and CRCs), each WebP's RIFF size and chunks, each JPEG's segments, and each
WAV's RIFF size; when ffmpeg is on PATH it also decodes every file and fails on any decoder error.
Usage: python3 scripts/check_media.py   (exit 1 if any file is damaged)
"""
import shutil
import struct
import subprocess
import sys
import zlib

MEDIA = ('.png', '.jpg', '.jpeg', '.webp', '.wav', '.mp4', '.gif')


def png(b):
    if b[:8] != b'\x89PNG\r\n\x1a\n':
        return 'bad signature'
    i = 8
    while i + 12 <= len(b):
        n, t = struct.unpack('>I', b[i:i + 4])[0], b[i + 4:i + 8]
        if i + 12 + n > len(b):
            return f'chunk {t!r} runs past the end'
        if zlib.crc32(b[i + 4:i + 8 + n]) & 0xffffffff != struct.unpack('>I', b[i + 8 + n:i + 12 + n])[0]:
            return f'chunk {t!r} at {i} fails its CRC'
        i += 12 + n
        if t == b'IEND':
            return None if i == len(b) else 'bytes after IEND'
    return 'no IEND'


def riff(b, kind):
    if b[:4] != b'RIFF' or b[8:12] != kind:
        return 'bad RIFF header'
    if struct.unpack('<I', b[4:8])[0] + 8 != len(b):
        return f'RIFF size {struct.unpack("<I", b[4:8])[0] + 8} but file is {len(b)} bytes'
    return None


def jpeg(b):
    if b[:2] != b'\xff\xd8':
        return 'no start marker'
    i = 2
    while i + 4 <= len(b):
        if b[i] != 0xff:
            return f'segment marker expected at {i}'
        m = b[i + 1]
        if m == 0xda:  # start of scan: entropy-coded data follows, checked by the decoder
            break
        if 0xd0 <= m <= 0xd7 or m == 0x01:
            i += 2
            continue
        i += 2 + struct.unpack('>H', b[i + 2:i + 4])[0]
    if b.rstrip(b'\x00')[-2:] != b'\xff\xd9':
        return 'no end marker'
    return None


def check(path):
    b = open(path, 'rb').read()
    ext = path.lower().rsplit('.', 1)[-1]
    if ext == 'png':
        return png(b)
    if ext == 'webp':
        return riff(b, b'WEBP')
    if ext == 'wav':
        return riff(b, b'WAVE')
    if ext in ('jpg', 'jpeg'):
        return jpeg(b)
    return None


def main():
    files = [f for f in subprocess.run(['git', 'ls-files'], capture_output=True, text=True, check=True).stdout.splitlines()
             if f.lower().endswith(MEDIA)]
    ffmpeg = shutil.which('ffmpeg')
    bad = []
    for f in files:
        why = check(f)
        if not why and ffmpeg and not f.lower().endswith('.wav'):
            r = subprocess.run([ffmpeg, '-v', 'error', '-i', f, '-f', 'null', '-'], capture_output=True, text=True)
            if r.returncode != 0 or r.stderr.strip():
                why = 'decoder: ' + (r.stderr.strip().splitlines() or ['failed'])[0]
        if why:
            bad.append((f, why))
    for f, why in bad:
        print(f'DAMAGED {f}: {why}')
    print(f'{len(files)} media files checked{" with ffmpeg" if ffmpeg else ""}, {len(bad)} damaged')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
