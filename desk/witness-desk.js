// === WITNESS: THE EXAM DESK (2026-10-27, Meta hackathon) ===
// A teacher's exams, each a pile of papers marked by Witness: SAM 3.1 follows the ink in a desk video and Muse Spark
// marks the path as well as the answer. The desk shows every paper, a review queue that puts the marks the model is
// least sure of first (and, among equals, a right answer reached by wrong thinking), a replay of how each answer was
// written, and the teacher's own word: their mark, their result and a focus note for the question's mastery level.
//
// Runs inside the LoWisa IDE (synced in as src/renderer-parts/27-witness-desk.js). It talks only through
// window.__lowisaWitnessIpc (main's doors, src/main/witness-ipc.ts) and adds nothing unless the edge's switch answers.
// Full screen below the 38 px title bar, Close and Esc always leave (the IDE's rule for every expanded page).
(function () {
  'use strict';

  var S = { on: false, view: 'home', piles: [], pid: '', pile: null, sid: '', paper: null, n: null, msg: null, busy: false, draft: {}, timer: null, play: null };
  var ipc = function () { return window.__lowisaWitnessIpc; };
  var uid = function () { try { return localStorage.getItem('lowisa-user-id') || localStorage.getItem('lowisa-userId') || ''; } catch (e) { return ''; } };
  var esc = function (s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); };

  var RESULT = {
    mastered: 'Mastered',
    right_answer_wrong_thinking: 'Right answer, wrong thinking',
    part_way: 'Part way',
    not_yet: 'To master',
  };
  var TONE = { mastered: 'ok', right_answer_wrong_thinking: 'warn', part_way: 'warn', not_yet: 'err' };

  async function api(method, path, body) {
    var r = null;
    try { r = await ipc().call({ userId: uid(), method: method, path: path, body: body }); } catch (e) { r = null; }
    var j = (r && r.json && typeof r.json === 'object') ? r.json : { ok: false };
    j.__status = r ? r.status : 0;
    return j;
  }
  function errText(j) { return (j && typeof j.error === 'string' && j.error) || 'Something went wrong. Try again.'; }
  function say(text, kind) { S.msg = text ? { text: text, kind: kind || 'ok' } : null; }

  // ---------------------------------------------------------------- turning on
  function ask(tries) {
    var id = uid();
    if (!ipc() || !id) { if ((tries || 0) < 40) setTimeout(function () { ask((tries || 0) + 1); }, 15000); return; }
    Promise.resolve(ipc().hello({ userId: id })).then(function (h) { if (h && h.on === true) turnOn(); }).catch(function () { /* stays off */ });
  }
  function turnOn() {
    if (S.on) return;
    S.on = true;
    if (typeof window.__lowisaRegisterCommand === 'function') {
      window.__lowisaRegisterCommand({ id: 'witness.open', title: 'Exam Desk: Open', category: 'Exam Desk', run: function () { open(); } });
    }
    window.__lowisaWitnessDesk = { open: open, close: close, show: show };
  }

  // ---------------------------------------------------------------- the panel
  var CSS =
    '#lowisaWitnessDesk{position:fixed;top:38px;left:0;right:0;bottom:0;z-index:9000;background:var(--bg2);color:var(--tx);display:flex;flex-direction:column;font-size:12.5px;border-top:1px solid var(--bd)}' +
    '#lowisaWitnessDesk .wd-head{display:flex;align-items:center;gap:10px;padding:10px 16px;background:var(--bga);border-bottom:1px solid var(--bd)}' +
    '#lowisaWitnessDesk .wd-head b{font-size:14px}#lowisaWitnessDesk .wd-head .wd-crumb{color:var(--tx2)}#lowisaWitnessDesk .wd-head .wd-grow{flex:1}' +
    '#lowisaWitnessDesk .wd-body{flex:1;overflow:auto;padding:16px 20px}' +
    '#lowisaWitnessDesk .wd-cols{display:grid;grid-template-columns:minmax(260px,1fr) minmax(320px,1.4fr);gap:16px;align-items:start}' +
    '#lowisaWitnessDesk .wd-card{border:1px solid var(--bd);border-radius:10px;padding:10px 12px;margin:0 0 10px;background:var(--bg)}' +
    '#lowisaWitnessDesk .wd-row{display:flex;align-items:center;gap:8px;padding:7px 8px;border-radius:8px;cursor:pointer}' +
    '#lowisaWitnessDesk .wd-row:hover,#lowisaWitnessDesk .wd-row.on{background:var(--bgh)}' +
    '#lowisaWitnessDesk .wd-row .wd-grow{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '#lowisaWitnessDesk .wd-sub{color:var(--tx2);font-size:11.5px;line-height:1.45}' +
    '#lowisaWitnessDesk h3{font-size:12.5px;margin:0 0 8px}' +
    '#lowisaWitnessDesk .wd-chip{font-size:11px;padding:2px 8px;border-radius:10px;border:1px solid var(--bd2);white-space:nowrap}' +
    '#lowisaWitnessDesk .wd-chip.ok{color:var(--ok);border-color:var(--ok)}#lowisaWitnessDesk .wd-chip.warn{color:var(--warn,#b7791f);border-color:var(--warn,#b7791f)}' +
    '#lowisaWitnessDesk .wd-chip.err{color:var(--err);border-color:var(--err)}' +
    '#lowisaWitnessDesk .wd-btn{background:var(--bgh);color:var(--tx);border:1px solid var(--bd2);border-radius:6px;padding:5px 10px;cursor:pointer;font-size:12px}' +
    '#lowisaWitnessDesk .wd-btn.wd-main{background:var(--ac);color:var(--on-ac);border-color:var(--ac);font-weight:600}' +
    '#lowisaWitnessDesk input,#lowisaWitnessDesk textarea,#lowisaWitnessDesk select{background:var(--bgt);color:var(--tx);border:1px solid var(--bd2);border-radius:6px;padding:5px 7px;font-size:12px;font-family:inherit;width:100%;box-sizing:border-box}' +
    '#lowisaWitnessDesk label{display:block;margin:8px 0 3px;color:var(--tx2);font-size:11.5px}' +
    '#lowisaWitnessDesk .wd-msg{margin:0 0 10px;padding:7px 10px;border-radius:8px;background:var(--bga)}#lowisaWitnessDesk .wd-msg.err{color:var(--err)}' +
    '#lowisaWitnessDesk .wd-steps{border-left:2px solid var(--bd2);margin:6px 0 6px 6px;padding-left:12px}' +
    '#lowisaWitnessDesk .wd-step{position:relative;margin:0 0 7px;transition:opacity .3s}#lowisaWitnessDesk .wd-step.later{opacity:.18}' +
    '#lowisaWitnessDesk .wd-step:before{content:"";position:absolute;left:-17px;top:5px;width:8px;height:8px;border-radius:50%;background:var(--bd2)}' +
    '#lowisaWitnessDesk .wd-step.slip:before{background:var(--err)}#lowisaWitnessDesk .wd-step .wd-ink{font-family:var(--mono,monospace);font-size:13px}' +
    '#lowisaWitnessDesk .wd-step.crossed .wd-ink{text-decoration:line-through;color:var(--tx2)}' +
    '#lowisaWitnessDesk .wd-diag{border:1px solid var(--err);border-radius:8px;padding:8px 10px;margin:8px 0}' +
    '#lowisaWitnessDesk .wd-nums{display:flex;gap:10px;flex-wrap:wrap;margin:0 0 12px}#lowisaWitnessDesk .wd-nums div{background:var(--bga);border-radius:8px;padding:8px 12px}' +
    '#lowisaWitnessDesk .wd-nums b{display:block;font-size:18px}';

  function panelEl() {
    var p = document.getElementById('lowisaWitnessDesk');
    if (p) return p;
    if (!document.getElementById('lowisaWitnessCss')) {
      var st = document.createElement('style');
      st.id = 'lowisaWitnessCss';
      st.textContent = CSS;
      document.head.appendChild(st);
    }
    p = document.createElement('div');
    p.id = 'lowisaWitnessDesk';
    p.setAttribute('role', 'dialog');
    p.setAttribute('aria-label', 'Exam Desk');
    p.addEventListener('click', onClick);
    p.addEventListener('input', onInput);
    p.addEventListener('change', onInput);
    document.body.appendChild(p);
    return p;
  }
  function onKey(e) { if (e.key === 'Escape' && document.getElementById('lowisaWitnessDesk')) { e.stopPropagation(); back(); } }

  async function open() {
    if (!S.on) return false;
    panelEl();
    document.addEventListener('keydown', onKey, true);
    await loadPiles();
    render();
    return true;
  }
  // show({pile, paper, n}): open straight on an exam or one paper's question (the demo page's links)
  async function show(where) {
    if (!(await open())) return false;
    where = where || {};
    if (where.pile && await loadPile(where.pile)) S.view = 'pile';
    if (where.paper && await loadPaper(where.paper)) { S.view = 'paper'; S.n = where.n != null ? Number(where.n) : null; stopPoll(); }
    render();
    return true;
  }
  function close() {
    stopPlay(); stopPoll();
    var p = document.getElementById('lowisaWitnessDesk');
    if (p) p.remove();
    document.removeEventListener('keydown', onKey, true);
  }
  // Esc and Back go one step up; from the exams list they close the desk
  function back() {
    if (S.view === 'paper') { stopPlay(); S.view = 'pile'; render(); }
    else if (S.view === 'pile' || S.view === 'new') { stopPoll(); S.view = 'home'; loadPiles().then(render); }
    else close();
  }

  // ---------------------------------------------------------------- loading
  async function loadPiles() {
    var j = await api('GET', '/api/witness/piles');
    if (j.ok) S.piles = j.piles || []; else say(errText(j), 'err');
  }
  async function loadPile(id) {
    var j = await api('GET', '/api/witness/pile/' + id);
    if (!j.ok) { say(errText(j), 'err'); return false; }
    S.pid = id; S.pile = j;
    var marking = (j.sittings || []).some(function (s) { return s.status === 'marking' || s.status === 'uploading'; });
    if (marking) poll(); else stopPoll();
    return true;
  }
  async function loadPaper(sid) {
    var j = await api('GET', '/api/witness/sitting/' + sid);
    if (!j.ok) { say(errText(j), 'err'); return false; }
    S.sid = sid; S.paper = j;
    return true;
  }
  function poll() {
    if (S.timer) return;
    S.timer = setInterval(function () {
      if (S.view !== 'pile' || !document.getElementById('lowisaWitnessDesk')) { stopPoll(); return; }
      loadPile(S.pid).then(render);
    }, 5000);
  }
  function stopPoll() { if (S.timer) { clearInterval(S.timer); S.timer = null; } }

  // ---------------------------------------------------------------- drawing
  function render() {
    var p = panelEl();
    var crumb = S.view === 'home' ? '' : S.view === 'new' ? 'New exam' : esc(S.pile && S.pile.pile ? S.pile.pile.title : '');
    var head = '<div class="wd-head"><b>Exam Desk</b>' + (crumb ? '<span class="wd-crumb">/ ' + crumb + '</span>' : '') +
      (S.view === 'paper' && S.paper ? '<span class="wd-crumb">/ ' + esc(S.paper.student || 'Paper') + '</span>' : '') +
      '<span class="wd-grow"></span>' +
      (S.view !== 'home' ? '<button class="wd-btn" data-act="back">Back</button>' : '') +
      '<button class="wd-btn" data-act="close" aria-label="Close the Exam Desk">Close</button></div>';
    var msg = S.msg ? '<div class="wd-msg ' + (S.msg.kind === 'err' ? 'err' : '') + '" role="status">' + esc(S.msg.text) + '</div>' : '';
    var body = S.view === 'new' ? viewNew() : S.view === 'pile' ? viewPile() : S.view === 'paper' ? viewPaper() : viewHome();
    p.innerHTML = head + '<div class="wd-body">' + msg + body + '</div>';
    S.msg = null;
    if (S.view === 'paper' && S.play && S.play.pending) { S.play.pending = false; runPlay(); }
  }

  function viewHome() {
    var rows = S.piles.map(function (x) {
      return '<div class="wd-row" data-pile="' + esc(x.id) + '"><span class="wd-grow"><b>' + esc(x.title) + '</b></span>' +
        (x.code ? '<span class="wd-sub">Code ' + esc(x.code) + '</span>' : '') +
        '<span class="wd-sub">' + x.papers + ' paper' + (x.papers === 1 ? '' : 's') + '</span>' +
        (x.released ? '<span class="wd-chip ok">Released</span>' : '<span class="wd-chip">Open</span>') + '</div>';
    }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default"><span class="wd-grow"><h3 style="margin:0">Your exams</h3>' +
      '<div class="wd-sub">Each exam holds its papers. Students sit on paper; a phone over the desk records how each answer was written.</div></span>' +
      '<button class="wd-btn wd-main" data-act="new">New exam</button></div></div>' +
      (rows ? '<div class="wd-card">' + rows + '</div>' : '<div class="wd-card wd-sub">No exams yet. Start one, then record each student\'s paper from the LoWisa phone app.</div>');
  }

  function viewNew() {
    var d = S.draft;
    return '<div class="wd-card" style="max-width:720px">' +
      '<label for="wdTitle">Exam name</label><input id="wdTitle" data-f="title" value="' + esc(d.title || '') + '" placeholder="Fractions quiz, Year 7">' +
      '<label for="wdLevel">Level</label><input id="wdLevel" data-f="level" value="' + esc(d.level || '') + '" placeholder="Year 7, university first year, CPA part 1">' +
      '<label for="wdQs">Questions, one a line, with the marks in brackets</label>' +
      '<textarea id="wdQs" data-f="qs" rows="6" placeholder="1. 3/4 ÷ 1/2 (2)&#10;2. Solve 2x + 6 = 14 (2)&#10;3. Simplify 16/64 (2)">' + esc(d.qs || '') + '</textarea>' +
      '<div class="wd-sub">Leave it empty to let Witness read the questions printed on the paper.</div>' +
      '<label for="wdScheme">Your mark scheme</label><textarea id="wdScheme" data-f="scheme" rows="6" placeholder="Q1: 1 mark for multiplying by the reciprocal, 1 for 3/2.">' + esc(d.scheme || '') + '</textarea>' +
      '<div class="wd-sub">Witness follows it exactly, method marks included. Without one, each question is worth its marks when both the method and the answer are right.</div>' +
      '<div style="margin-top:12px;display:flex;gap:8px"><button class="wd-btn wd-main" data-act="create">Create exam</button><button class="wd-btn" data-act="back">Cancel</button></div></div>';
  }

  function viewPile() {
    var j = S.pile || {}; var ss = j.sittings || []; var q = j.queue || [];
    var marked = ss.filter(function (s) { return s.status === 'marked' || s.status === 'released'; });
    var toMaster = marked.reduce(function (a, s) { return a + (s.to_master || 0); }, 0);
    var nums = '<div class="wd-nums"><div><b>' + ss.length + '</b>papers</div><div><b>' + marked.length + '</b>marked</div>' +
      '<div><b>' + q.length + '</b>to review</div><div><b>' + toMaster + '</b>questions to master</div></div>';
    var papers = ss.map(function (s) {
      var st = s.status === 'marked' ? '<span class="wd-sub">' + num(s.marks) + ' / ' + num(s.out_of) + '</span>' :
        s.status === 'released' ? '<span class="wd-chip ok">Released</span>' :
        s.status === 'failed' ? '<span class="wd-chip err">Record again</span>' : '<span class="wd-chip">' + (s.status === 'uploading' ? 'Uploading' : 'Marking') + '</span>';
      return '<div class="wd-row" data-paper="' + esc(s.id) + '"><span class="wd-grow">' + esc(s.student || 'Paper') + '</span>' + st +
        (s.to_master ? '<span class="wd-chip err">' + s.to_master + ' to master</span>' : '') + '</div>';
    }).join('') || '<div class="wd-sub">No papers yet. Record them from the LoWisa phone app under this exam.</div>';
    var queue = q.map(function (it) {
      return '<div class="wd-row" data-paper="' + esc(it.sitting) + '" data-n="' + esc(it.n) + '"><span class="wd-grow">' + esc(it.student || 'Paper') + ' · Q' + esc(it.n) +
        (it.diagnosis ? '<div class="wd-sub" style="white-space:normal">' + esc(it.diagnosis) + '</div>' : '') + '</span>' +
        chip(it.result) + '<span class="wd-sub">' + Math.round((it.confidence || 0) * 100) + '% sure</span></div>';
    }).join('') || '<div class="wd-sub">Nothing left to review.</div>';
    var released = j.pile && j.pile.released_ms;
    var code = j.pile && j.pile.code ? '<div class="wd-card"><b>Join code: <span style="font-size:18px;letter-spacing:3px">' + esc(j.pile.code) + '</span></b>' +
      '<div class="wd-sub">Students enter it in the LoWisa phone app, then record their own paper. Or record each paper yourself.</div></div>' : '';
    return code + nums + '<div class="wd-cols"><div class="wd-card"><h3>Papers</h3>' + papers + '</div>' +
      '<div class="wd-card"><h3>To review: what needs you first</h3>' + queue + '</div></div>' +
      '<div style="margin-top:6px">' + (released ? '<span class="wd-chip ok">Released to students</span>' :
        '<button class="wd-btn wd-main" data-act="release">Release marks</button> <span class="wd-sub">Students see their marks; every question they didn\'t master becomes their next mastery level.</span>') + '</div>';
  }

  function viewPaper() {
    var j = S.paper || {}; var qs = (j.result && j.result.questions) || [];
    if (j.status === 'failed') return '<div class="wd-card">' + esc(j.error || 'This paper could not be marked.') + '</div>';
    if (!qs.length) return '<div class="wd-card wd-sub">This paper is still being marked.</div>';
    var list = qs.map(function (q) {
      var res = q.teacher_result || q.result;
      return '<div class="wd-row' + (q.n === S.n ? ' on' : '') + '" data-q="' + esc(q.n) + '"><span class="wd-grow">Question ' + esc(q.n) + '</span>' + chip(res) +
        (q.reviewed ? '<span class="wd-chip ok">Reviewed</span>' : '') + '</div>';
    }).join('');
    var q = qs.filter(function (x) { return x.n === S.n; })[0] || qs[0];
    S.n = q.n;
    return '<div class="wd-cols"><div class="wd-card"><h3>Questions</h3>' + list + '</div><div>' + questionCard(q) + '</div></div>';
  }

  function questionCard(q) {
    var steps = (q.steps || []).map(function (s, i) {
      var slip = q.moment_s != null && s.t != null && nearMoment(q, i);
      return '<div class="wd-step' + (s.crossed_out ? ' crossed' : '') + (slip ? ' slip' : '') + '" data-i="' + i + '">' +
        '<span class="wd-sub">' + (s.t == null ? '' : fmtT(s.t)) + (s.crossed_out ? ' · crossed out' : '') + '</span><div class="wd-ink">' + esc(s.wrote) + '</div></div>';
    }).join('') || '<div class="wd-sub">No steps were read for this question.</div>';
    var res = q.teacher_result || q.result;
    var marks = q.teacher_marks != null ? q.teacher_marks : q.marks;
    var opts = Object.keys(RESULT).map(function (k) { return '<option value="' + k + '"' + (k === res ? ' selected' : '') + '>' + RESULT[k] + '</option>'; }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Question ' + esc(q.n) +
      (q.final_answer ? ' · answer ' + esc(q.final_answer) : '') + '</h3></span>' + chip(q.result) +
      '<span class="wd-sub">' + Math.round((q.confidence || 0) * 100) + '% sure</span></div>' +
      '<div style="margin:10px 0 4px;display:flex;gap:8px;align-items:center"><b style="font-size:12px">How it was written</b>' +
      '<button class="wd-btn" data-act="replay">Replay</button></div><div class="wd-steps" id="wdSteps">' + steps + '</div>' +
      (q.diagnosis ? '<div class="wd-diag"><b>Where the thinking went wrong' + (q.moment_s != null ? ' (' + fmtT(q.moment_s) + ')' : '') + '</b><div>' + esc(q.diagnosis) + '</div></div>' : '') +
      '</div><div class="wd-card"><h3>Your word</h3>' +
      '<label for="wdRes">Result</label><select id="wdRes" data-f="res">' + opts + '</select>' +
      '<label for="wdMarks">Marks out of ' + esc(q.out_of) + '</label><input id="wdMarks" data-f="marks" type="number" min="0" max="' + esc(q.out_of) + '" value="' + esc(marks) + '">' +
      '<label for="wdFocus">What should this student\'s mastery level focus on?</label>' +
      '<textarea id="wdFocus" data-f="focus" rows="3" placeholder="Make them see why only the divisor flips. They like cooking.">' + esc(q.focus || '') + '</textarea>' +
      '<div class="wd-sub">Witness builds one level for each question a student didn\'t master, from their own working and your note.</div>' +
      '<div style="margin-top:10px"><button class="wd-btn wd-main" data-act="save">Save</button></div></div>' +
      masteryCard(q);
  }

  // After release: the student's level, their questions to the teacher, the checks the teacher chooses (none needed),
  // what they explained, and the badge. Only for a question that was to master.
  var STATUS = { not_started: 'Level not started yet', building: 'Level being made', ready: 'Level ready on their phone',
                 completed: 'Level played to the end', badge: 'Turned around', not_yet: 'Not yet' };
  function masteryCard(q) {
    var released = S.paper && S.paper.status === 'released';
    var res = q.teacher_result || q.result;
    if (!released || !(res === 'not_yet' || res === 'right_answer_wrong_thinking')) return '';
    var m = q.mastery || { status: 'not_started' };
    var asks = m.asks || {};
    var thread = (m.thread || []).map(function (t) {
      return '<div class="wd-sub" style="margin:4px 0"><b>' + (t.from === 'teacher' ? 'You' : esc(S.paper.student || 'Student')) + ':</b> ' + esc(t.text) + '</div>';
    }).join('');
    var ex = m.explain || {};
    var lo = ex.lo ? '<div class="wd-card"><b>Explained to Lo</b><div>' + esc(ex.lo.text) + '</div>' +
      (ex.lo.verdict ? '<div class="wd-sub">' + (ex.lo.verdict.understood ? 'Lo: understood. ' : 'Lo: not yet understood. ') + esc(ex.lo.verdict.why || '') + '</div>' : '') + '</div>' : '';
    var toMe = ex.teacher ? '<div class="wd-card"><b>Explained to you</b><div>' + esc(ex.teacher.text) + '</div></div>' : '';
    var box = function (k, label) { return '<label style="display:flex;gap:6px;align-items:center;color:var(--tx)"><input type="checkbox" data-ask="' + k + '"' + (asks[k] ? ' checked' : '') + ' style="width:auto"> ' + label + '</label>'; };
    var done = m.status === 'badge';
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Mastery</h3></span>' +
      '<span class="wd-chip ' + (done ? 'ok' : '') + '">' + esc(STATUS[m.status] || m.status) + '</span></div>' +
      (thread ? '<div style="margin-top:8px"><b style="font-size:12px">Questions to you</b>' + thread + '</div>' : '') +
      '<label for="wdReply">Answer in the thread</label><input id="wdReply" data-f="reply" placeholder="Try dividing both by 12.">' +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="reply">Send</button></div>' +
      '<div style="margin-top:12px"><b style="font-size:12px">Ask for a check (only if you want one)</b>' +
      box('lo', 'Explain it back to Lo') + box('paper', 'A fresh question on paper, watched again') + box('teacher', 'Explain it back to me') +
      '<button class="wd-btn" data-act="verify" style="margin-top:6px">Save checks</button></div>' + lo + toMe +
      '<label for="wdBadgeNote">A note with your decision</label><input id="wdBadgeNote" data-f="badgeNote" placeholder="Well done, you found why digits are not numbers.">' +
      '<div style="margin-top:8px;display:flex;gap:8px">' + (done ? '<span class="wd-chip ok">Badge issued</span>' :
        '<button class="wd-btn wd-main" data-act="badge">Issue Turned around</button><button class="wd-btn" data-act="notyet">Not yet</button>') + '</div></div>';
  }

  // the step written when the thinking went wrong: the last step finished at or before that second
  function nearMoment(q, i) {
    var at = -1;
    (q.steps || []).forEach(function (s, k) { if (s.t != null && s.t <= q.moment_s + 1) at = k; });
    if (at < 0) at = 0;
    return i === at;
  }
  function chip(r) { return '<span class="wd-chip ' + (TONE[r] || '') + '">' + esc(RESULT[r] || r || '') + '</span>'; }
  function fmtT(t) { t = Math.max(0, Math.round(Number(t) || 0)); return Math.floor(t / 60) + ':' + ('0' + (t % 60)).slice(-2); }
  function num(n) { var x = Math.round((Number(n) || 0) * 10) / 10; return String(x); }

  // ---------------------------------------------------------------- the replay: the steps appear at their own pace
  function runPlay() {
    stopPlay();
    var box = document.getElementById('wdSteps'); if (!box) return;
    var els = Array.prototype.slice.call(box.querySelectorAll('.wd-step'));
    var q = ((S.paper && S.paper.result && S.paper.result.questions) || []).filter(function (x) { return x.n === S.n; })[0];
    if (!q || !els.length) return;
    var t0 = (q.steps[0] && q.steps[0].t) || 0;
    els.forEach(function (e) { e.classList.add('later'); });
    S.play = { timers: els.map(function (e, i) {
      var t = q.steps[i] && q.steps[i].t != null ? q.steps[i].t : t0 + i;
      return setTimeout(function () { e.classList.remove('later'); }, Math.min(12000, Math.max(0, (t - t0) * 250)) + 150);
    }) };
  }
  function stopPlay() { if (S.play && S.play.timers) S.play.timers.forEach(clearTimeout); S.play = null; }

  // ---------------------------------------------------------------- doing
  function onInput(e) {
    var f = e.target && e.target.getAttribute('data-f');
    if (f) S.draft[f] = e.target.value;
  }
  async function onClick(e) {
    var t = e.target.closest('[data-act],[data-pile],[data-paper],[data-q]');
    if (!t || S.busy) return;
    var act = t.getAttribute('data-act');
    if (act === 'close') return close();
    if (act === 'back') return back();
    if (act === 'new') { S.draft = {}; S.view = 'new'; return render(); }
    if (act === 'create') return create();
    if (act === 'release') return release();
    if (act === 'save') return save();
    if (act === 'replay') return runPlay();
    if (act === 'verify') return masteryDo('verify', checks());
    if (act === 'reply') return masteryDo('reply', { text: S.draft.reply || '' });
    if (act === 'badge') return masteryDo('badge', { issue: true, note: S.draft.badgeNote || '' });
    if (act === 'notyet') return masteryDo('badge', { issue: false, note: S.draft.badgeNote || '' });
    if (t.hasAttribute('data-pile')) { if (await loadPile(t.getAttribute('data-pile'))) { S.view = 'pile'; } return render(); }
    if (t.hasAttribute('data-paper')) {
      var n = t.getAttribute('data-n');
      if (await loadPaper(t.getAttribute('data-paper'))) { S.view = 'paper'; S.n = n != null ? Number(n) : null; S.draft = {}; S.play = { pending: true }; stopPoll(); }
      return render();
    }
    if (t.hasAttribute('data-q')) { S.n = Number(t.getAttribute('data-q')); S.draft = {}; S.play = { pending: true }; return render(); }
  }

  function checks() {
    var out = { lo: false, paper: false, teacher: false };
    var p = document.getElementById('lowisaWitnessDesk');
    if (p) p.querySelectorAll('[data-ask]').forEach(function (el) { out[el.getAttribute('data-ask')] = !!el.checked; });
    return out;
  }
  async function masteryDo(action, body) {
    if (S.n == null) return;
    S.busy = true;
    var j = await api('POST', '/api/witness/mastery/' + S.sid + '/' + S.n + '/' + action, body);
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    await loadPaper(S.sid);
    S.draft = {};
    say(action === 'badge' ? (body.issue ? 'Badge issued: Turned around.' : 'Marked not yet, with your note.') : action === 'verify' ? 'Checks saved. The student sees only these.' : 'Sent.');
    render();
  }

  // "1. 3/4 ÷ 1/2 (2)" -> {n: 1, text: "3/4 ÷ 1/2", marks: 2}
  function questionsOf(text) {
    return String(text || '').split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean).map(function (l, i) {
      var m = /^(\d+)[.)]?\s*(.*)$/.exec(l); var n = m ? Number(m[1]) : i + 1; var rest = m ? m[2] : l;
      var mk = /\((\d+)\s*(marks?)?\)\s*$/.exec(rest); var marks = mk ? Number(mk[1]) : 1;
      return { n: n, text: mk ? rest.slice(0, mk.index).trim() : rest, marks: marks };
    });
  }
  async function create() {
    var d = S.draft;
    if (!String(d.title || '').trim()) { say('Give the exam a name.', 'err'); return render(); }
    S.busy = true;
    var j = await api('POST', '/api/witness/pile', { title: d.title, level: d.level || '', questions: questionsOf(d.qs), scheme: d.scheme || '' });
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    S.draft = {};
    if (await loadPile(j.id)) S.view = 'pile';
    say('Exam created. Give your students the join code ' + (j.code || '') + ', or record each paper yourself from the LoWisa phone app.');
    render();
  }
  async function save() {
    var q = ((S.paper && S.paper.result && S.paper.result.questions) || []).filter(function (x) { return x.n === S.n; })[0];
    if (!q) return;
    var d = S.draft; var body = { n: q.n };
    body.result = d.res || q.teacher_result || q.result;
    var m = d.marks != null && d.marks !== '' ? Number(d.marks) : (q.teacher_marks != null ? q.teacher_marks : q.marks);
    if (isFinite(m)) body.marks = m;
    body.focus = d.focus != null ? d.focus : (q.focus || '');
    S.busy = true;
    var j = await api('POST', '/api/witness/sitting/' + S.sid + '/review', body);
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    await loadPaper(S.sid);
    S.draft = {};
    var next = ((S.paper.result && S.paper.result.questions) || []).filter(function (x) { return !x.reviewed; })[0];
    say(next ? 'Saved. Question ' + next.n + ' is next on this paper.' : 'Saved. This paper is reviewed.');
    if (next) { S.n = next.n; S.play = { pending: true }; }
    render();
  }
  async function release() {
    S.busy = true;
    var j = await api('POST', '/api/witness/pile/' + S.pid + '/release', {});
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    await loadPile(S.pid);
    say(j.released + ' paper' + (j.released === 1 ? '' : 's') + ' released to students.');
    render();
  }

  // exposed for the tests (pure helpers only)
  window.__lowisaWitnessDeskTest = { questionsOf: questionsOf, fmtT: fmtT, nearMoment: nearMoment };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { ask(0); }); else ask(0);
})();
