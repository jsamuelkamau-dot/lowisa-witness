#!/usr/bin/env python3
"""Check that every relative link and image in the repository's Markdown points at a file git tracks, and every #anchor
in the page resolves (a file only on this disk, or ignored, would be missing on GitHub).

    python3 scripts/check_links.py   (exit 1 if any is broken)
"""
import os
import re
import subprocess
import sys


def anchor(title):
    return re.sub(r'[^\w\- ]', '', title.strip().lower()).replace(' ', '-')


def main():
    tracked = set(subprocess.run(['git', 'ls-files'], capture_output=True, text=True, check=True).stdout.splitlines())
    dirs = {os.path.dirname(f) for f in tracked}
    while '' in dirs: dirs.discard('')
    dirs |= {os.path.dirname(d) for d in list(dirs)}
    pages = sorted(f for f in tracked if f.endswith('.md'))
    bad = []
    for md in pages:
        text = open(md, encoding='utf-8').read()
        base = os.path.dirname(md)
        heads = {anchor(h) for h in re.findall(r'^#+ (.*)$', text, re.M)}
        for m in re.finditer(r'\]\(([^)\s]+)\)|<img src="([^"]+)"', text):
            url = m.group(1) or m.group(2)
            if url.startswith(('http://', 'https://', 'mailto:')):
                continue
            if url.startswith('#'):
                if url[1:] not in heads:
                    bad.append((md, url))
                continue
            target = os.path.normpath(os.path.join(base, url.split('#')[0])).replace(os.sep, '/')
            if target not in tracked and target.rstrip('/') not in dirs:
                bad.append((md, url))
    for md, url in bad:
        print(f'BROKEN {md}: {url}')
    print(f'{len(pages)} pages checked, {len(bad)} broken links')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
