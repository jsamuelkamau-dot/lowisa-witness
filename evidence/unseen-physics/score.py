"""Score the six live markings of Daniel Kwan's physics paper against a physics teacher's correct marking.

    python -X utf8 score.py           -> the committed results, re-checked against the key below (writes nothing)
    python -X utf8 score.py mark      -> fresh run files mark_*.json (from run.py) -> mark_score.json + the table
"""
import json, os, re, glob, sys

HERE = os.path.dirname(os.path.abspath(__file__))
# what Daniel wrote (read by eye from the photo), and whether it earns the mark
TRUTH = {
    1: ('Joules', 0), 2: ('Magnetic force', 0), 3: ('60 ÷ 4 = 15 m/s', 1), 4: ('Gravity', 0),
    5: ('Moving in a straight line', 0), 6: ('a = 20 ÷ 5 = 2', 0), 7: ('Energy cannot be created.', 0),
    8: ('Nuclear', 0), 9: ('Ampere', 0), 10: ('It gets smaller.', 0), 11: ('It attracts all metals.', 0),
    12: ('Heat it up.', 0), 13: ('Conduction', 0), 14: ('Melting', 0),
    15: ('Angle of incidence is bigger than angle of reflection.', 0), 16: ('Transverse wave', 0),
    17: ('20 Hz – 20 000 Hz', 1), 18: ('It can travel in a vacuum.', 0), 19: ('ρ = 200 ÷ 50 = 4 g/cm³', 1),
    20: ('P = F × A', 0), 21: ('P = 100 × 0.5 = 50 Pa', 0), 22: ('N/m', 0), 23: ('There is less oxygen higher up.', 0),
    24: ('The ship floats because it is very light and the nail sinks because it is heavier. Heavy objects sink and light objects float.', 0),
    25: ('kg', 0), 26: ('W = 10 × 10 = 100 kg', 0), 27: ('The fastest speed at the start.', 0), 28: ('To cook food.', 1),
    29: ('300 000 km/s', 1), 30: ('Telescope', 1),
}


def norm(s):
    s = s.lower().replace('×', 'x').replace('÷', '/').replace('–', '-').replace('ρ', 'p')
    return re.sub(r'[^a-z0-9/x=.\-]', '', s)


def committed():
    """The committed live runs, each answer's marks re-checked against TRUTH (the files' own mark_ok is not trusted)."""
    for name in ('live-6-runs-before-fix.json', '6-runs-after-fix.json'):
        runs = json.load(open(os.path.join(HERE, name), encoding='utf-8'))
        right = 0
        for t, r in sorted(runs.items()):
            ok = sum(((r['q'][str(n)]['marks'] or 0) >= 1) == bool(m) for n, (_, m) in TRUTH.items())
            right += ok
            print(f"{name:30} {t}  {r['total']}/{r['out_of']}  marking decisions right {ok}/30")
        print(f"{name:30} all six runs: {right}/{30 * len(runs)} marking decisions right\n")
    ns = json.load(open(os.path.join(HERE, 'no-scheme-after-half-mark-fix-3-runs.json'), encoding='utf-8'))
    for r in ns['runs']:
        print(f"no scheme, run {r['run']}: score {r['score']}, decisions right {r['decisions_right']}")


if len(sys.argv) < 2:
    committed()
    sys.exit(0)

runs = {}
for f in sorted(glob.glob(os.path.join(HERE, sys.argv[1] + '_*.json'))):
    if f.endswith('_score.json'):
        continue
    j = json.load(open(f, encoding='utf-8'))
    tag = j['tag']
    res = j['sitting_reply'].get('result') or {}
    qs = {q['n']: q for q in res.get('questions', [])}
    row = {'seconds': j['marking_seconds'], 'name': (j['sitting_reply'].get('read') or {}), 'q': {}}
    for n, (wrote, right) in TRUTH.items():
        q = qs.get(n, {})
        got = q.get('marks', None)
        ok_mark = (got or 0) >= 1 if right else (got or 0) == 0
        read_ok = norm(wrote) in norm(q.get('final_answer', '') + ' '.join(s.get('wrote', '') for s in q.get('steps', []))) or \
            norm(q.get('final_answer', '')) in norm(wrote) and len(norm(q.get('final_answer', ''))) > 2
        fp = q.get('fingerprint') or {}
        row['q'][n] = {'result': q.get('result'), 'marks': got, 'out_of': q.get('out_of'), 'mark_ok': ok_mark, 'read_ok': read_ok,
                       'final_answer': q.get('final_answer'), 'confidence': q.get('confidence'),
                       'named': fp.get('misconception') or '', 'ask': fp.get('ask') or '', 'diagnosis': q.get('diagnosis', ''),
                       'skill': q.get('skill', '')}
    row['total'] = sum((v['marks'] or 0) for v in row['q'].values())
    row['out_of'] = sum((v['out_of'] or 0) for v in row['q'].values())
    row['mark_agree'] = sum(v['mark_ok'] for v in row['q'].values())
    row['read_agree'] = sum(v['read_ok'] for v in row['q'].values())
    runs[tag] = row

json.dump(runs, open(os.path.join(HERE, sys.argv[1] + '_score.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('run  secs  score   marks-agree  reads-agree')
for t, r in runs.items():
    print(f"{t}   {r['seconds']:5.1f}  {r['total']}/{r['out_of']}   {r['mark_agree']}/30        {r['read_agree']}/30")
print('\nper question (marks given in runs A1 A2 A3 | B1 B2 B3; truth):')
for n, (wrote, right) in TRUTH.items():
    ms = ' '.join(str(runs[t]['q'][n]['marks']) for t in sorted(runs))
    bad = [t for t in sorted(runs) if not runs[t]['q'][n]['mark_ok']]
    unread = [t for t in sorted(runs) if not runs[t]['q'][n]['read_ok']]
    print(f"Q{n:<2} truth {right}  got {ms}  {'WRONG in ' + ','.join(bad) if bad else ''}  {'read? ' + ','.join(unread) + ' -> ' + str(runs[unread[0]]['q'][n]['final_answer']) if unread else ''}")
