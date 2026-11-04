// The Exam Desk outside the IDE: serves desk/witness-desk.js on a plain page and passes its calls to a Witness host.
//
//   WITNESS_URL=https://your-host WITNESS_TOKEN=... node demo/desk-server.js      then open http://localhost:4747
//   node demo/desk-server.js --replay                                            no key, no account, no network
//
// 31 Oct (the 12-judge panel: nothing could be opened without the private LoWisa host): --replay answers the desk's
// reads from a recorded exam (evidence/replay/: the rehearsal's own answers from the production edge, names kept as
// they are on the sample papers, tokens and signed links removed), so the desk, the fingerprints, the class patterns,
// the challenge and the badge can be looked at locally. Anything that would change the exam is answered read-only.
//
// The page gets the same seam the IDE gives the desk (window.__lowisaWitnessIpc); this server adds the bearer token
// so it never reaches the page, and forwards only /api/witness/ paths.
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 4747);
const HOST = process.env.WITNESS_URL || 'http://localhost:8080';
const TOKEN = process.env.WITNESS_TOKEN || '';
const REPLAY = process.argv.includes('--replay') ? path.join(__dirname, '..', 'evidence', 'replay') : null;
// a recorded answer for a read: the path's own file (/api/witness/pile/<id> -> pile_<id>.json), else 404
function replayed(route) {
  const name = route.replace(/^\/api\/witness\//, '').replace(/\//g, '_') + '.json';
  const file = path.join(REPLAY, name);
  return file.startsWith(REPLAY) && fs.existsSync(file) ? fs.readFileSync(file) : null;
}
const DESK = path.join(__dirname, '..', 'desk', 'witness-desk.js');

const PAGE = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Exam Desk</title><style>
:root{--bg:#ffffff;--bg2:#f7f7f5;--bga:#efeeea;--bgh:#e8e6e0;--bgt:#ffffff;--tx:#1f1e1c;--tx2:#5f5e5a;--bd:#e2e0da;--bd2:#cfcdc5;
--ac:#2f5fd0;--on-ac:#ffffff;--ok:#2e7d32;--warn:#a86400;--err:#c62828;--mono:ui-monospace,Consolas,monospace}
@media (prefers-color-scheme: dark){:root{--bg:#1d1d1b;--bg2:#252523;--bga:#2d2d2a;--bgh:#353532;--bgt:#1d1d1b;--tx:#ecebe6;--tx2:#a9a79f;
--bd:#3a3a36;--bd2:#4a4a45;--ac:#7aa2ff;--on-ac:#10131a;--ok:#81c784;--warn:#ffb74d;--err:#ef9a9a}}
html,body{margin:0;height:100%;background:var(--bg2);color:var(--tx);font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
#bar{height:38px;display:flex;align-items:center;padding:0 14px;background:var(--bga);border-bottom:1px solid var(--bd);font-size:12px;color:var(--tx2)}
#open{margin:60px auto;display:block;padding:10px 18px;font-size:14px;border-radius:8px;border:1px solid var(--ac);background:var(--ac);color:var(--on-ac);cursor:pointer}
</style></head><body><div id="bar">LoWisa · Exam Desk (demo page: the desktop app shows the same desk below its title bar)</div>
<button id="open">Open the Exam Desk</button>
<script>
localStorage.setItem('lowisa-user-id', 'demo');
window.__lowisaWitnessIpc = {
  hello: async () => { const r = await fetch('/api/witness/piles'); return { on: r.status === 200 }; },
  call: async (q) => {
    const r = await fetch(q.path, { method: q.method, headers: q.method === 'POST' ? { 'content-type': 'application/json' } : {}, body: q.method === 'POST' ? JSON.stringify(q.body || {}) : undefined });
    let json = null; try { json = await r.json(); } catch (e) { json = null; }
    return { status: r.status, json };
  },
};
document.getElementById('open').onclick = () => window.__lowisaWitnessDesk && window.__lowisaWitnessDesk.open();
// ?pile=<id>&paper=<id>&n=<question> opens the desk straight there
const q = new URLSearchParams(location.search);
if (q.has('pile') || q.has('paper') || q.has('open')) {
  const go = async () => { const d = window.__lowisaWitnessDesk; if (!d || !(await d.show({pile: q.get('pile'), paper: q.get('paper'), n: q.get('n')}))) setTimeout(go, 300); };
  setTimeout(go, 200);
}
</script><script src="/witness-desk.js"></script></body></html>`;

// 4 Nov (independent audit, finding D): bound to this computer is not enough on its own. A web page open in the same
// browser can point its own name at 127.0.0.1 (DNS rebinding) and call this server, which adds the bearer token. So a
// request is answered only when it is addressed to localhost or 127.0.0.1 on this port, and one that would change
// something must come from this page itself.
const LOCAL = new Set(['localhost:' + PORT, '127.0.0.1:' + PORT]);
function local(req) {
  if (!LOCAL.has(String(req.headers.host || '').toLowerCase())) return false;
  const origin = req.headers.origin;
  return req.method === 'GET' || !origin || LOCAL.has(origin.replace(/^http:\/\//, '').toLowerCase());
}
if (!REPLAY && !/^https:\/\//.test(HOST) && !/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(HOST)) {
  console.error('WITNESS_URL must be https:// (or a host on this computer), so the token never travels in the clear.');
  process.exit(1);
}

http.createServer((req, res) => {
  if (!local(req)) { res.writeHead(403); return res.end(); }
  const route = (req.url || '').split('?')[0];
  if (route === '/' || route === '/index.html') { res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); return res.end(PAGE); }
  if (req.url === '/witness-desk.js') { res.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8' }); return res.end(fs.readFileSync(DESK)); }
  // 4 Nov (security review): a replay file name is a plain name, never . or ..
  if (REPLAY && /^\/replay-asset\/[A-Za-z0-9._-]+$/.test(route) && !/^\.+$/.test(route.slice('/replay-asset/'.length))) {
    const f = path.join(REPLAY, 'assets', route.slice('/replay-asset/'.length));
    if (!fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': /\.png$/.test(f) ? 'image/png' : /\.webp$/.test(f) ? 'image/webp' : /\.m4a$/.test(f) ? 'audio/mp4' : 'image/jpeg' });
    return res.end(fs.readFileSync(f));
  }
  // a paper's pictures (still-1.jpg, drawn-2.webp) and the record pass too; nothing outside /api/witness/
  if (!/^\/api\/witness\/[a-z0-9/._-]+$/.test(req.url || '') || (req.url || '').indexOf('..') >= 0) { res.writeHead(404); return res.end(); }
  if (REPLAY) {
    if (req.method !== 'GET') { res.writeHead(200, { 'content-type': 'application/json' }); return res.end('{"ok":false,"code":"replay","error":"This is a recorded exam: it can be read, not changed."}'); }
    // a picture of a paper: the recorded file itself, served from the replay folder
    // named by its whole path (two papers each have a still-1.jpg)
    const asset = /\/asset\/[A-Za-z0-9._-]+$/.test(route) ? route.replace(/^\/api\/witness\//, '').replace(/\//g, '_') : null;
    if (asset) { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ ok: true, url: '/replay-asset/' + asset })); }
    const body = replayed(route);
    res.writeHead(body ? 200 : 404, { 'content-type': 'application/json' });
    return res.end(body || '{"ok":false,"error":"Not in this recording."}');
  }
  const cap = /\/voice$/.test(route) ? 6 * 1024 * 1024 : 65536;   // a spoken comment is base64 audio
  let body = '';
  req.on('data', (c) => { body += c; if (body.length > cap) req.destroy(); });
  req.on('end', async () => {
    try {
      const r = await fetch(HOST + req.url, { method: req.method, headers: { authorization: 'Bearer ' + TOKEN, ...(req.method === 'POST' ? { 'content-type': 'application/json' } : {}) },
                                              body: req.method === 'POST' ? body || '{}' : undefined });
      res.writeHead(r.status, { 'content-type': 'application/json' });
      res.end(await r.text());
    } catch (e) { res.writeHead(502, { 'content-type': 'application/json' }); res.end('{"ok":false,"error":"The Witness host did not answer."}'); }
  });
}).listen(PORT, '127.0.0.1', () => console.log('Exam Desk demo on http://localhost:' + PORT + ' -> ' + (REPLAY ? 'the recording in evidence/replay/' : HOST)));
