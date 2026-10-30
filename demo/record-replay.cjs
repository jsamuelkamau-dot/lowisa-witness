// Records one exam from a running LoWisa desktop app for `node demo/desk-server.js --replay` (31 Oct 2026, the
// 12-judge panel: "nothing can be opened without the private LoWisa host").
//
//   (start the desktop app with --remote-debugging-port=9224, signed in as the teacher)
//   node demo/record-replay.cjs <pile id> [port]      ->  evidence/replay/*.json and evidence/replay/assets/*
//
// It asks the desk's own door (window.__lowisaWitnessIpc, the app's allow-listed calls with the app's own sign-in) for
// every read the desk makes on that exam: the exam list, the exam, its measures, each paper, each paper's Proof of
// Thinking, and each picture a paper names. Pictures are downloaded through their signed links, and every signed link
// is removed from what is saved. No token is ever read or written: the app keeps its own.
const fs = require('fs');
const path = require('path');

const PILE = process.argv[2];
const PORT = Number(process.argv[3] || 9224);
const OUT = path.join(__dirname, '..', 'evidence', 'replay');
if (!PILE || !/^[A-Za-z0-9_-]+$/.test(PILE)) { console.error('usage: node demo/record-replay.cjs <pile id> [port]'); process.exit(2); }

async function page() {
  const list = await (await fetch('http://127.0.0.1:' + PORT + '/json/list')).json();
  const p = list.find((t) => t.type === 'page');
  if (!p) throw new Error('no app window on port ' + PORT);
  const ws = new WebSocket(p.webSocketDebuggerUrl);
  await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
  let id = 0; const wait = new Map();
  ws.onmessage = (m) => { const j = JSON.parse(m.data); if (wait.has(j.id)) { wait.get(j.id)(j); wait.delete(j.id); } };
  return {
    get: (route) => new Promise((ok) => {
      const n = ++id;
      wait.set(n, (j) => ok(j.result && j.result.result ? j.result.result.value : null));
      const expr = 'window.__lowisaWitnessIpc.call(' + JSON.stringify({ method: 'GET', path: route }) + ')';
      ws.send(JSON.stringify({ id: n, method: 'Runtime.evaluate', params: { expression: expr, awaitPromise: true, returnByValue: true } }));
    }),
    close: () => ws.close(),
  };
}

// a signed link (or anything carrying a signature) never reaches the saved file
function clean(v) {
  if (typeof v === 'string') return /^https?:\/\//.test(v) && /X-Amz-|Signature=|token=/i.test(v) ? '' : v;
  if (Array.isArray(v)) return v.map(clean);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clean(x)]));
  return v;
}
const ASSET = /^[A-Za-z0-9._-]+\.(jpg|jpeg|png|webp|m4a|mp4|wav)$/i;
function assetsIn(v, acc = new Set()) {
  if (typeof v === 'string' && ASSET.test(v)) acc.add(v);
  else if (Array.isArray(v)) v.forEach((x) => assetsIn(x, acc));
  else if (v && typeof v === 'object') Object.values(v).forEach((x) => assetsIn(x, acc));
  return acc;
}
const fileOf = (route) => route.replace(/^\/api\/witness\//, '').replace(/\//g, '_');

(async () => {
  fs.mkdirSync(path.join(OUT, 'assets'), { recursive: true });
  const app = await page();
  const save = async (route) => {
    const r = await app.get(route);
    if (!r || r.status !== 200 || !r.json) { console.log('skip', route, r && r.status); return null; }
    fs.writeFileSync(path.join(OUT, fileOf(route) + '.json'), JSON.stringify(clean(r.json)));
    console.log('saved', route);
    return r.json;
  };
  const piles = await save('/api/witness/piles');
  if (piles && Array.isArray(piles.piles)) {   // the recording holds this exam alone
    piles.piles = piles.piles.filter((p) => p.id === PILE);
    fs.writeFileSync(path.join(OUT, 'piles.json'), JSON.stringify(clean(piles)));
  }
  const pile = await save('/api/witness/pile/' + PILE);
  await save('/api/witness/pile/' + PILE + '/measure');
  const sittings = ((pile && (pile.pile || pile).sittings) || []).map((s) => (typeof s === 'string' ? s : s.id)).filter(Boolean);
  for (const sid of sittings) {
    const s = await save('/api/witness/sitting/' + sid);
    await save('/api/witness/sitting/' + sid + '/proof');
    for (const a of assetsIn(s)) {
      const route = '/api/witness/sitting/' + sid + '/asset/' + a;
      const r = await app.get(route);
      const url = r && r.json && r.json.url;
      if (!url) { console.log('no picture', a); continue; }
      const bytes = Buffer.from(await (await fetch(url)).arrayBuffer());
      fs.writeFileSync(path.join(OUT, 'assets', fileOf(route)), bytes);
      console.log('picture', a, bytes.length);
    }
  }
  app.close();
  console.log('recorded', sittings.length, 'papers into', OUT);
})().catch((e) => { console.error(e.message); process.exit(1); });
