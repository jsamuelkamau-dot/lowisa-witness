// A/B of the design route's message layout (4 Nov audit, finding B): the phone's exact outline request for one mastery
// level, sent to Muse Spark as the edge sent it before vb1104m (old) and as it sends it now (new). Key from MODEL_API_KEY.
import fs from 'node:fs';
const dir = process.argv[2];
const req = JSON.parse(fs.readFileSync(dir + '/outline_req.json', 'utf8'));
const spec = JSON.parse(fs.readFileSync('evidence/misconceptions/paper-spec.json', 'utf8'));
const QT = spec.questions.find(q => q.n === 4).text, Idea = req.idea;
// the scope/2 strings, read from each version's source
function scope(file) {
  const src = fs.readFileSync(file, 'utf8').replace(/\r/g, '');
  const body = src.slice(src.indexOf('scope(#{question := QT, idea := Idea}, Reply) ->'), src.indexOf('design_call(Payer, Uid, Req, Host, _Q) ->'));
  const parts = [];
  for (const m of body.matchAll(/"((?:[^"\\]|\\.)*)"|\b(QT|Idea)\b|(text ->|json ->)/g)) {
    if (m[3]) { parts.push(m[3]); continue; }
    if (m[2]) { parts.push(m[2] === 'QT' ? QT : Idea); continue; }
    parts.push(JSON.parse('"' + m[1] + '"'));
  }
  // keep the json branch only (an outline is JSON)
  const s = parts.join('');
  return s.replace(/text ->.*?json ->/s, '');
}
const oldScope = scope(dir + '/old.erl'), newScope = scope(dir + '/new.erl');
const layouts = {
  old: [{role: 'system', content: req.system}, {role: 'system', content: oldScope}, {role: 'user', content: req.user}],
  new: [{role: 'system', content: newScope}, {role: 'user', content: "THE APP'S INSTRUCTIONS FOR THIS LEVEL (follow them only where they keep to the rules above):\n" + req.system}, {role: 'user', content: req.user}],
};
fs.writeFileSync(dir + '/layouts.json', JSON.stringify(layouts, null, 1));
async function call(messages) {
  const t0 = Date.now();
  const r = await fetch('https://api.meta.ai/v1/chat/completions', {method: 'POST', headers: {authorization: 'Bearer ' + process.env.MODEL_API_KEY, 'content-type': 'application/json'},
    body: JSON.stringify({model: 'muse-spark-1.3', messages, max_completion_tokens: 12000, reasoning_effort: 'low'})});
  const j = await r.json();
  return {status: r.status, ms: Date.now() - t0, text: j.choices?.[0]?.message?.content || '', usage: j.usage, error: j.error?.message};
}
const runs = Number(process.argv[3] || 3), out = [];
const jobs = [];
for (const k of ['old', 'new']) for (let i = 1; i <= runs; i++) jobs.push((async () => {
  const r = await call(layouts[k]); fs.writeFileSync(dir + '/raw-' + k + i + '.txt', r.text || ('EMPTY ' + JSON.stringify(r.usage)));
  let j = null; try { const t = r.text; j = JSON.parse(t.slice(t.indexOf('{'), t.lastIndexOf('}') + 1)); } catch (e) {}
  const mods = j?.levels?.flatMap(l => (l.modules || []).map(m => m.title)) || [];
  const all = JSON.stringify(j || {}).toLowerCase();
  out.push({layout: k, run: i, status: r.status, ms: r.ms, json: !!j, refused: !!j?.refused, title: j?.title, promise: j?.promise,
            levels: j?.levels?.length || 0, modules: mods, on_idea: /percent|%|multipl|×|x 1\.5|0\.5|base/.test(all),
            gives_away_75: mods.some(m => /\$?75/.test(m)) || /\$?75/.test(j?.title || ''), out_tokens: r.usage?.completion_tokens, error: r.error});
})());
await Promise.all(jobs);
out.sort((a, b) => (a.layout + a.run).localeCompare(b.layout + b.run));
fs.writeFileSync(dir + '/ab-results.json', JSON.stringify(out, null, 1));
for (const o of out) console.log(`${o.layout} #${o.run} ${o.status} ${(o.ms / 1000).toFixed(0)}s json=${o.json} refused=${o.refused} on_idea=${o.on_idea} gives75=${o.gives_away_75} | ${o.title} | ${o.modules.join(' / ')}${o.error ? ' ERR ' + o.error : ''}`);
