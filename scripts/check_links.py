#!/usr/bin/env python3
"""Check that every relative link and image in the repository's Markdown resolves, and every #anchor in README.md.

    python3 scripts/check_links.py   (exit 1 if any is broken)
"""
import glob
import os
import re
import sys


def anchor(title):
    return re.sub(r'[^\w\- ]', '', title.strip().lower()).replace(' ', '-')


def main():
    pages = sorted(set(glob.glob('*.md') + glob.glob('**/*.md', recursive=True)))
    pages = [p for p in pages if not p.startswith(('_build', 'node_modules'))]
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
            if not os.path.exists(os.path.normpath(os.path.join(base, url.split('#')[0]))):
                bad.append((md, url))
    for md, url in bad:
        print(f'BROKEN {md}: {url}')
    print(f'{len(pages)} pages checked, {len(bad)} broken links')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
