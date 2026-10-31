"""film5 test: the live From Exam to Mastery marking a physics paper it has never seen, the way the teacher's desk does it.
TOK (a teacher token) comes from the environment and is never printed.
  python -X utf8 run.py read <file>                     -> read_<name>.json   (POST pile/read, the desk's "start from your paper")
  python -X utf8 run.py mark <tag> <questions.json> [scheme.txt]   -> mark_<tag>.json (pile, photo sitting, page, mark, wait)
"""
import base64, json, os, sys, time, urllib.request, urllib.error

H = 'https://core.lowisa.dev/api/witness'
TOK = os.environ['TOK']
HERE = os.path.dirname(os.path.abspath(__file__))
PAPER = os.path.join(HERE, '..', 'out', 'paper_blank_fixed.jpg')


def call(method, path, body=None, timeout=300):
    req = urllib.request.Request(H + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={'authorization': 'Bearer ' + TOK, 'content-type': 'application/json'})
    t = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read() or b'{}'), time.time() - t
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}'), time.time() - t


def b64(p):
    return base64.b64encode(open(p, 'rb').read()).decode()


def mime(p):
    return 'image/png' if p.endswith('.png') else 'application/pdf' if p.endswith('.pdf') else 'image/jpeg'


cmd = sys.argv[1] if __name__ == '__main__' else ''
if cmd == 'read':
    f = sys.argv[2]
    st, j, dt = call('POST', '/pile/read', {'file': b64(f), 'mime': mime(f)})
    out = os.path.join(HERE, 'read_' + os.path.splitext(os.path.basename(f))[0] + '.json')
    json.dump({'status': st, 'seconds': round(dt, 1), 'reply': j}, open(out, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print(st, round(dt, 1), 's', len(j.get('questions') or []), 'questions; scheme', len(j.get('scheme') or ''), 'chars ->', out)
elif cmd == 'mark':
    tag, qf = sys.argv[2], sys.argv[3]
    scheme = open(sys.argv[4], encoding='utf-8').read() if len(sys.argv) > 4 else ''
    qs = json.load(open(qf, encoding='utf-8'))
    log = {'tag': tag, 'scheme_chars': len(scheme), 'steps': {}}
    t0 = time.time()
    st, j, dt = call('POST', '/pile', {'title': 'Physics Examination Paper, Form 3 (' + tag + ')', 'level': 'Form 3 (about 15 years old)',
                                       'questions': qs, 'scheme': scheme, 'kind': 'paper', 'engine': 'meta', 'preview': True})
    log['steps']['pile'] = [st, round(dt, 1)]; pid = j['id']; log['pile'] = pid
    st, j, dt = call('POST', '/sitting/start', {'kind': 'photo', 'pages': 1, 'pile': pid})
    log['steps']['start'] = [st, round(dt, 1)]; sid = j['id']; log['sitting'] = sid
    st, j, dt = call('POST', '/sitting/%s/page' % sid, {'n': 1, 'mime': 'image/jpeg', 'file': b64(PAPER)})
    log['steps']['page'] = [st, round(dt, 1), j]
    st, j, dt = call('POST', '/sitting/%s/mark' % sid, {})
    log['steps']['mark'] = [st, round(dt, 1), j]
    t1 = time.time()
    while True:
        time.sleep(5)
        st, j, _ = call('GET', '/sitting/' + sid)
        if j.get('status') not in ('marking', 'uploading', 'queued'):
            break
        if time.time() - t1 > 900:
            break
    log['marking_seconds'] = round(time.time() - t1, 1)
    log['total_seconds'] = round(time.time() - t0, 1)
    log['sitting_reply'] = j
    st, p, _ = call('GET', '/pile/' + pid)
    log['pile_reply'] = p
    out = os.path.join(HERE, 'mark_' + tag + '.json')
    json.dump(log, open(out, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print(tag, 'status', j.get('status'), 'marked in', log['marking_seconds'], 's ->', out)
