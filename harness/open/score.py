#!/usr/bin/env python3
"""Muse Spark Open on partner inference (Baseten), scored the same way as Muse Spark, from the committed files.

    python3 harness/open/score.py

Physics: the film's paper against the physics key (evidence/unseen-physics/score.py's TRUTH). The real student's three
multiple-choice papers (his sideways pages turned upright, as in condition B): against his teacher's marks (the key in
evidence/real-handwriting/results/condition-c-shipped-code-3-runs.json). Every run is listed, the failed ones too. The
cost is every call's tokens at the endpoint's list price, every input token at the full $1.25 (an upper bound).
"""
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ns = {'__file__': os.path.join(ROOT, 'evidence/unseen-physics/score.py')}
exec(open(ns['__file__'], encoding='utf-8').read().split('def norm')[0], ns)
TRUTH = ns['TRUTH']
C = json.load(open(os.path.join(ROOT, 'evidence/real-handwriting/results/condition-c-shipped-code-3-runs.json'), encoding='utf-8'))
KEY = {s: {r['n']: r['teacher_right'] for r in rows} for s, rows in C['runs'][0]['papers'].items()}


def call_cost(calls):
    return sum(c['usage'].get('prompt_tokens', 0) * 1.25e-6 + c['usage'].get('completion_tokens', 0) * 4.25e-6 for c in calls)


total = 0.0
for f in sorted(glob.glob(os.path.join(HERE, 'results', '*.json'))):
    d = json.load(open(f, encoding='utf-8'))
    cost = call_cost(d.get('calls', [])); total += cost
    name = os.path.basename(f)[:-5]
    head = f'{name:22} {d["marking_seconds"]:6.0f} s  {len(d.get("calls", [])):2} calls  ${cost:.3f}  '
    if d['status'] != 'ok':
        print(head + 'FAILED: ' + d.get('why', '')[:90]); continue
    qs = {q['n']: q for q in d['questions']}
    if name.startswith('physics'):
        right = sum(((qs.get(n, {}).get('marks') or 0) >= 1) == bool(m) for n, (_, m) in TRUTH.items())
        print(head + f'score {sum(q["marks"] for q in qs.values())}/30, marking decisions right {right}/30'
              f' ({"scheme" if d.get("scheme") else "no scheme"})')
    else:
        subj = name.split('-')[1]
        rows = [(n, tr, qs.get(n)) for n, tr in KEY[subj].items() if tr is not None]
        agree = sum((bool(q) and q['marks'] >= q['out_of']) == tr for n, tr, q in rows)
        wrong = [(n, q) for n, tr, q in rows if not tr]
        caught = sum(1 for n, q in wrong if not (q and q['marks'] >= q['out_of']))
        out = [q for n, tr, q in rows if q and q['marks'] < q['out_of']]
        named = sum(1 for q in out if isinstance(q.get('fingerprint'), dict) and q['fingerprint'].get('misconception'))
        print(head + f'{subj}: {agree}/{len(rows)} agree with his teacher; caught {caught}/{len(wrong)}; '
              f'not accepted {len(out)}, a wrong idea named {named}')
print(f'all calls: ${total:.2f}')
