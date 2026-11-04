// The server's scope message for one level, both reply modes, read from witness_api:scope/2 in the source as it is
// (so a test always sends the live wording): node harness/design-layout/scope.mjs > scope.json
import fs from 'node:fs';

const src = fs.readFileSync('witness/src/witness_api.erl', 'utf8').replace(/\r/g, '');
const body = src.slice(src.indexOf('scope(#{question := QT, idea := Idea}, Reply) ->'), src.indexOf('design_call(Payer, Uid, Req, Host, _Q) ->'));
const spec = JSON.parse(fs.readFileSync('evidence/misconceptions/paper-spec.json', 'utf8'));
const QT = spec.questions.find(q => q.n === 4).text;
const Idea = 'Thinks a 50% increase followed by a 50% decrease cancels to 0% because percentages can be added directly.';

function build(mode) {
  const parts = [];
  let skip = false;
  for (const m of body.matchAll(/"((?:[^"\\]|\\.)*)"|\b(QT|Idea)\b|(text ->|json ->|end\]\)|end,)/g)) {
    if (m[3]) { skip = m[3].startsWith('end') ? false : !m[3].startsWith(mode); continue; }
    if (skip) continue;
    parts.push(m[2] ? (m[2] === 'QT' ? QT : Idea) : JSON.parse('"' + m[1] + '"'));
  }
  return parts.join('');
}
process.stdout.write(JSON.stringify({json: build('json'), text: build('text')}));
