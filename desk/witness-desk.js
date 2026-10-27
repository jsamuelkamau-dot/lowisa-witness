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

  var S = { on: false, view: 'home', piles: [], pid: '', pile: null, sid: '', paper: null, n: null, msg: null, busy: false, draft: {}, timer: null, play: null,
            opened: 0, assets: {}, proof: null, measure: null, rec: null, drawTimer: null };
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
    if (S.view === 'proof') { S.view = 'paper'; render(); }
    else if (S.view === 'paper') { stopPlay(); stopRec(); S.view = 'pile'; render(); }
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
    var m = await api('GET', '/api/witness/pile/' + id + '/measure');
    S.measure = m.ok ? m : null;
    // an open exam keeps itself current: a student's paper arrives, is marked, its examiner answers come in
    // (live in the desktop app, 27 Oct: the first paper of a new exam never showed until the exam was reopened)
    poll();
    return true;
  }
  async function loadPaper(sid) {
    var j = await api('GET', '/api/witness/sitting/' + sid);
    if (!j.ok) { say(errText(j), 'err'); return false; }
    if (S.sid !== sid) S.opened = Date.now();
    S.sid = sid; S.paper = j;
    var drawing = ((j.result && j.result.questions) || []).some(function (q) { return q.drawn && q.drawn.status === 'drawing'; });
    if (drawing && !S.drawTimer) S.drawTimer = setTimeout(function () { S.drawTimer = null; if (S.view === 'paper' && S.sid === sid) loadPaper(sid).then(render); }, 4000);
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
    var body = S.view === 'new' ? viewNew() : S.view === 'pile' ? viewPile() : S.view === 'paper' ? viewPaper() : S.view === 'proof' ? viewProof() : viewHome();
    p.innerHTML = head + '<div class="wd-body">' + msg + body + '</div>';
    S.msg = null;
    fillAssets(p);
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
      '<label for="wdKind">What students do</label><select id="wdKind" data-f="kind">' +
      '<option value="paper"' + (d.kind !== 'practical' ? ' selected' : '') + '>An exam on paper (Witness follows the ink)</option>' +
      '<option value="practical"' + (d.kind === 'practical' ? ' selected' : '') + '>A practical task (Witness follows the hands and the apparatus)</option></select>' +
      '<label for="wdEngine">Marked by</label><select id="wdEngine" data-f="engine">' +
      '<option value="meta"' + (d.engine !== 'open' ? ' selected' : '') + '>Muse Spark, with SAM 3.1 following the ink</option>' +
      '<option value="open"' + (d.engine === 'open' ? ' selected' : '') + '>Muse Spark Open, on open weights</option></select>' +
      '<label for="wdQs">' + (d.kind === 'practical' ? 'The procedure\'s steps, one a line, with the marks in brackets' : 'Questions, one a line, with the marks in brackets') + '</label>' +
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
        s.status === 'failed' ? '<span class="wd-chip err">' + (s.unreadable ? 'Paper not in view: film again' : s.kept ? 'Not marked yet: mark again' : 'Record again') + '</span>' : '<span class="wd-chip">' + (s.status === 'uploading' ? 'Uploading' : 'Marking') + '</span>';
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
    return code + nums + measured() + '<div class="wd-cols"><div class="wd-card"><h3>Papers</h3>' + papers + '</div>' +
      '<div class="wd-card"><h3>To review: what needs you first</h3>' + queue + '</div></div>' +
      '<div style="margin-top:6px">' + (released ? '<span class="wd-chip ok">Released to students</span>' :
        '<button class="wd-btn wd-main" data-act="release">Release marks</button> <span class="wd-sub">Students see their marks; every question they didn\'t master becomes their next mastery level.</span>') + '</div>';
  }

  function viewPaper() {
    var j = S.paper || {}; var qs = (j.result && j.result.questions) || [];
    if (j.status === 'failed') return '<div class="wd-card">' + esc(j.error || 'This paper could not be marked.') +
      (j.unreadable ? '<div class="wd-sub">What the camera showed: ' + esc(j.unreadable) + '</div>' : '') +
      // Meta could not mark it: the video is kept, so it is marked again from here, not filmed again
      (j.kept ? '<div style="margin-top:10px"><button class="wd-btn wd-main" data-act="remark">Mark again</button></div>' : '') + '</div>';
    if (!qs.length) return '<div class="wd-card wd-sub">This paper is still being marked.</div>';
    var list = qs.map(function (q) {
      var res = q.teacher_result || q.result;
      return '<div class="wd-row' + (q.n === S.n ? ' on' : '') + '" data-q="' + esc(q.n) + '"><span class="wd-grow">' + unit() + ' ' + esc(q.n) + '</span>' + chip(res) +
        (q.reviewed ? '<span class="wd-chip ok">Reviewed</span>' : '') + '</div>';
    }).join('');
    var q = qs.filter(function (x) { return x.n === S.n; })[0] || qs[0];
    S.n = q.n;
    return '<div class="wd-cols"><div><div class="wd-card"><h3>' + (practical() ? 'The procedure' : 'Questions') + '</h3>' + list +
      '<div style="margin-top:10px"><button class="wd-btn" data-act="proof">Proof of Thinking</button></div></div>' + examinerCard(j) + '</div><div>' + questionCard(q) + '</div></div>';
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
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">' + unit() + ' ' + esc(q.n) +
      (q.final_answer ? (practical() ? ' · result ' : ' · answer ') + esc(q.final_answer) : '') + '</h3></span>' + chip(q.result) +
      '<span class="wd-sub">' + Math.round((q.confidence || 0) * 100) + '% sure</span></div>' +
      '<div style="margin:10px 0 4px;display:flex;gap:8px;align-items:center"><b style="font-size:12px">' + (practical() ? 'What was done' : 'How it was written') + '</b>' +
      '<button class="wd-btn" data-act="replay">Replay</button></div><div class="wd-steps" id="wdSteps">' + steps + '</div>' +
      (q.diagnosis ? '<div class="wd-diag"><b>Where the thinking went wrong' + (q.moment_s != null ? ' (' + fmtT(q.moment_s) + ')' : '') + '</b><div>' + esc(q.diagnosis) + '</div></div>' : '') +
      stillOf(q) + '</div>' + drawnCard(q) + '<div class="wd-card"><h3>Your word</h3>' +
      '<label for="wdRes">Result</label><select id="wdRes" data-f="res">' + opts + '</select>' +
      '<label for="wdMarks">Marks out of ' + esc(q.out_of) + '</label><input id="wdMarks" data-f="marks" type="number" min="0" max="' + esc(q.out_of) + '" value="' + esc(marks) + '">' +
      '<label for="wdFocus">What should this student\'s mastery level focus on?</label>' +
      '<textarea id="wdFocus" data-f="focus" rows="3" placeholder="What to make them see, and something they care about (a sport, a job they want).">' + esc(q.focus || '') + '</textarea>' +
      '<div class="wd-sub">Witness builds one level for each question a student didn\'t master, from their own working and your note.</div>' +
      '<label for="wdComment">Your comment for the student</label>' +
      '<textarea id="wdComment" data-f="comment" rows="3" placeholder="Say it or write it: what they did well, and the one thing to change.">' + esc(S.draft.comment != null ? S.draft.comment : ((q.comment && q.comment.text) || '')) + '</textarea>' +
      '<div style="margin-top:6px;display:flex;gap:8px;align-items:center"><button class="wd-btn" data-act="speak">' + (S.rec ? 'Stop and write it down' : 'Speak it') + '</button>' +
      '<span class="wd-sub">' + (S.rec ? 'Listening… speak your comment.' : 'Muse Voice Transcribe writes down what you say; you can edit it before saving.') + '</span></div>' +
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
    // the fresh question on paper, watched again: how it was worked, beside the result
    var fr = m.fresh || null, fq = fr && fr.question;
    var fresh = !fr ? '' : '<div class="wd-card"><b>The fresh question on paper</b>' +
      (fr.status === 'marked' && fq ? ' ' + chip(fq.result) + '<div class="wd-sub">' + esc(asks.fresh || '') + '</div>' +
        (fq.steps || []).map(function (st) { return '<div class="wd-step' + (st.crossed_out ? ' slip' : '') + '" style="opacity:1">' + esc(st.wrote) + '</div>'; }).join('') +
        (fq.diagnosis ? '<div class="wd-sub">' + esc(fq.diagnosis) + '</div>' : '')
      : '<div class="wd-sub">' + (fr.status === 'failed' ? 'The video could not be read. The student can film it again.' : fr.status === 'uploading' ? 'Not sent yet.' : 'Witness is reading it.') + '</div>') + '</div>';
    var box = function (k, label) { return '<label style="display:flex;gap:6px;align-items:center;color:var(--tx)"><input type="checkbox" data-ask="' + k + '"' + (asks[k] ? ' checked' : '') + ' style="width:auto"> ' + label + '</label>'; };
    var done = m.status === 'badge';
    // the level's own self-check (Muse Wonder played it as both students); a level that still fails is the teacher's to know
    var chk = m.check ? (m.check.passes ? '<div class="wd-sub" style="margin-top:6px">Self-check: passed. Wonder played the level as both students.</div>' :
      '<div class="wd-card" style="margin-top:8px;border-color:var(--warn,#b26a00)"><b>Self-check: still not right</b><div class="wd-sub">After its rewrites the level still had these. Look before you rely on it, or answer them in the thread.</div>' +
      (m.check.problems || []).map(function (p) { return '<div class="wd-sub" style="margin:3px 0">· ' + esc(p) + '</div>'; }).join('') + '</div>') : '';
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Mastery</h3></span>' +
      '<span class="wd-chip ' + (done ? 'ok' : '') + '">' + esc(STATUS[m.status] || m.status) + '</span></div>' + chk +
      (thread ? '<div style="margin-top:8px"><b style="font-size:12px">Questions to you</b>' + thread + '</div>' : '') +
      '<label for="wdReply">Answer in the thread</label><input id="wdReply" data-f="reply" placeholder="Your answer to their question">' +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="reply">Send</button></div>' +
      '<div style="margin-top:12px"><b style="font-size:12px">Ask for a check (only if you want one)</b>' +
      box('lo', 'Explain it back to Lo') + box('paper', 'A fresh question on paper, watched again') +
      '<input id="wdFresh" data-f="fresh" value="' + esc(S.draft.fresh != null ? S.draft.fresh : (asks.fresh || '')) + '" placeholder="The fresh question, for the same idea" aria-label="The fresh question">' +
      box('teacher', 'Explain it back to me') +
      '<button class="wd-btn" data-act="verify" style="margin-top:6px">Save checks</button></div>' + lo + toMe + fresh +
      '<label for="wdBadgeNote">A note with your decision</label><input id="wdBadgeNote" data-f="badgeNote" placeholder="Well done: you found the reason, not only the answer.">' +
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
    if (f === 'kind' && e.type === 'change') render();   // a practical's lines are the procedure's steps
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
    if (act === 'remark') return remark();
    if (act === 'save') return save();
    if (act === 'replay') return runPlay();
    if (act === 'draw') return draw();
    if (act === 'speak') return speak();
    if (act === 'proof') return openProof();
    if (act === 'print') { try { window.print(); } catch (e) { /* no printer */ } return; }
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
    var f = document.getElementById('wdFresh');
    if (out.paper && f && f.value.trim()) out.fresh = f.value.trim();
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

  // ---------------------------------------------------------------- the examiner, the drawn step, the spoken comment, the record
  // a practical task's lines are the procedure's steps, not questions
  function practical() { return !!(S.pile && S.pile.pile && S.pile.pile.kind === 'practical'); }
  function unit() { return practical() ? 'Step' : 'Question'; }

  function examinerCard(j) {
    var ex = j.examiner; if (!ex) return '';
    if (ex.status === 'failed' || !(ex.asks || []).length) return '';
    var rows = ex.asks.map(function (a) {
      var ans = a.answer, v = ans && ans.verdict;
      return '<div style="margin-top:10px"><b>' + (practical() ? 'Step ' : 'Q') + esc(a.n) + ':</b> ' + esc(a.ask) + (a.wrote ? '<div class="wd-ink" style="margin:4px 0">' + esc(a.wrote) + '</div>' : '') +
        (ans ? '<div>' + (ans.spoken ? 'Said: ' : 'Wrote: ') + '<i>' + esc(ans.text) + '</i></div>' +
          (v ? '<div class="wd-sub">' + (v.own_work ? '<span class="wd-chip ok">Their own reasoning</span> ' : '<span class="wd-chip err">Not clearly their own</span> ') +
            (v.understood ? '<span class="wd-chip ok">Understands it now</span> ' : '<span class="wd-chip">Not yet understood</span> ') + esc(v.why || '') + '</div>' : '')
          : '<div class="wd-sub">Not answered yet.</div>') + '</div>';
    }).join('');
    return '<div class="wd-card"><h3>The examiner\'s questions</h3><div class="wd-sub">Muse Wonder asked about steps the student wrote; they answered out loud or in writing.</div>' + rows + '</div>';
  }
  function stillOf(q) {
    var st = ((S.paper && S.paper.result && S.paper.result.stills) || []).filter(function (x) { return x.n === q.n; })[0];
    if (!st) return '';
    return '<div style="margin-top:10px"><b style="font-size:12px">The desk at ' + fmtT(st.t) + '</b><img data-asset="' + esc(st.asset) + '" alt="The desk at ' + fmtT(st.t) + ', question ' + esc(q.n) + '" style="display:block;width:100%;max-width:420px;border-radius:8px;margin-top:4px;background:#f4efe2;min-height:60px"></div>';
  }
  function drawnCard(q) {
    var res = q.teacher_result || q.result;
    if (res === 'mastered' && !q.drawn) return '';
    var d = q.drawn || {};
    var inner = d.status === 'done' ? '<img data-asset="' + esc(d.asset) + '" alt="The corrected working: ' + esc((d.lines || []).join(', ')) + '" style="display:block;width:100%;max-width:420px;border-radius:8px;background:#f4efe2;min-height:60px">' +
        '<div class="wd-sub" style="margin-top:6px">' + (d.lines || []).map(esc).join(' · ') + '</div><div style="margin-top:6px"><button class="wd-btn" data-act="draw">Draw it again</button></div>'
      : d.status === 'drawing' ? '<div class="wd-sub">Muse Spark is writing the corrected working and Muse Image is drawing it…</div>'
      : '<div class="wd-sub">' + (d.status === 'failed' ? 'That drawing did not come back. ' : '') + 'The student sees it with their marks: their own working, with the step that changes underlined.</div>' +
        '<div style="margin-top:6px"><button class="wd-btn" data-act="draw">Draw the corrected step</button></div>';
    return '<div class="wd-card"><h3>The step, corrected</h3>' + inner + '</div>';
  }
  // pictures come through the desk's door as short-lived links, fetched once per paper
  // the links last 30 minutes: one is kept for 20, and a picture that fails to load asks for a fresh one once
  // (live in the desktop app, 27 Oct: a still opened again after half an hour showed as broken)
  function fillAssets(p) {
    Array.prototype.forEach.call(p.querySelectorAll('img[data-asset]'), function (img) {
      var key = S.sid + '/' + img.getAttribute('data-asset');
      var fetchUrl = function () {
        api('GET', '/api/witness/sitting/' + S.sid + '/asset/' + img.getAttribute('data-asset')).then(function (j) {
          if (j.ok && j.url) { S.assets[key] = { url: j.url, at: Date.now() }; img.src = j.url; } else img.remove();
        });
      };
      img.onerror = function () { img.onerror = null; delete S.assets[key]; fetchUrl(); };
      var c = S.assets[key];
      if (c && Date.now() - c.at < 20 * 60 * 1000) { img.src = c.url; return; }
      fetchUrl();
    });
  }
  async function draw() {
    if (S.n == null) return;
    var j = await api('POST', '/api/witness/sitting/' + S.sid + '/draw', { n: S.n });
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    delete S.assets[S.sid + '/drawn-' + S.n + '.webp'];
    await loadPaper(S.sid);
    say('Drawing the corrected step. It takes about half a minute.');
    render();
  }
  // the teacher's spoken comment: recorded here, written down on the server by Muse Voice Transcribe
  function stopRec() { if (S.rec) { try { S.rec.r.stop(); } catch (e) { /* stopped */ } S.rec = null; } }
  async function speak() {
    if (S.rec) { var r = S.rec; S.rec = null; r.r.stop(); return; }
    if (!navigator.mediaDevices || typeof MediaRecorder === 'undefined') { say('This computer has no microphone the desk can use. Write the comment instead.', 'err'); return render(); }
    var stream;
    try { stream = await navigator.mediaDevices.getUserMedia({ audio: true }); } catch (e) { say('The microphone is not allowed for the desk. Write the comment instead.', 'err'); return render(); }
    var chunks = [], n = S.n, sid = S.sid;
    var rec = new MediaRecorder(stream);
    rec.ondataavailable = function (e) { if (e.data && e.data.size) chunks.push(e.data); };
    rec.onstop = async function () {
      stream.getTracks().forEach(function (t) { t.stop(); });
      var blob = new Blob(chunks, { type: rec.mimeType || 'audio/webm' });
      var b64 = await new Promise(function (ok) { var fr = new FileReader(); fr.onload = function () { ok(String(fr.result).split(',')[1] || ''); }; fr.readAsDataURL(blob); });
      say('Writing down your comment…'); render();
      var j = await api('POST', '/api/witness/sitting/' + sid + '/voice', { n: n, audio: b64, mime: blob.type });
      if (!j.ok) { say(errText(j), 'err'); return render(); }
      S.draft.comment = (S.draft.comment ? S.draft.comment + ' ' : '') + j.text;
      say('Written down. Edit it if you like, then Save.');
      render();
    };
    S.rec = { r: rec };
    rec.start();
    render();
  }
  async function openProof() {
    var j = await api('GET', '/api/witness/sitting/' + S.sid + '/proof');
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    S.proof = j; S.view = 'proof'; render();
  }
  function viewProof() {
    var p = S.proof || {};
    var day = function (ms) { return ms ? new Date(ms).toLocaleString() : ''; };
    var qs = (p.questions || []).map(function (q) {
      return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Question ' + esc(q.n) + (q.question ? ' · ' + esc(q.question) : '') + '</h3></span>' +
        chip(q.teacher_result || q.result) + '<span class="wd-sub">' + num(q.teacher_marks != null ? q.teacher_marks : q.marks) + ' / ' + num(q.out_of) + ' · ' + Math.round((q.confidence || 0) * 100) + '% sure</span></div>' +
        (q.steps || []).map(function (s) { return '<div class="wd-step' + (s.crossed_out ? ' crossed' : '') + '" style="opacity:1"><span class="wd-sub">' + (s.t == null ? '' : fmtT(s.t)) + '</span><div class="wd-ink">' + esc(s.wrote) + '</div></div>'; }).join('') +
        (q.diagnosis ? '<div class="wd-diag"><b>' + (q.moment_s != null ? 'At ' + fmtT(q.moment_s) : 'Where it went wrong') + '</b><div>' + esc(q.diagnosis) + '</div></div>' : '') +
        (q.still ? '<img data-asset="' + esc(q.still) + '" alt="The desk, question ' + esc(q.n) + '" style="display:block;width:100%;max-width:360px;border-radius:8px;margin-top:8px">' : '') +
        (q.comment ? '<div style="margin-top:6px"><b>Teacher:</b> ' + esc(q.comment) + '</div>' : '') + '</div>';
    }).join('');
    var asks = (p.examiner || []).map(function (a) {
      var v = a.answer && a.answer.verdict;
      return '<div style="margin-top:8px"><b>Q' + esc(a.n) + ':</b> ' + esc(a.ask) + '<div>' + (a.answer ? esc(a.answer.text) : '<span class="wd-sub">Not answered.</span>') + '</div>' +
        (v ? '<div class="wd-sub">' + (v.own_work ? 'Their own reasoning. ' : 'Not clearly their own. ') + (v.understood ? 'Understands it now. ' : '') + esc(v.why || '') + '</div>' : '') + '</div>';
    }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Proof of Thinking</h3>' +
      '<div class="wd-sub">' + esc(p.exam || '') + (p.level ? ' · ' + esc(p.level) : '') + ' · ' + esc(p.student || '') + ' · sat ' + esc(day(p.sat_ms)) + ' · ' + num(p.marks) + ' of ' + num(p.out_of) + ' marks</div></span>' +
      '<button class="wd-btn" data-act="print">Print</button></div></div>' + qs +
      (asks ? '<div class="wd-card"><h3>The examiner\'s questions</h3>' + asks + '</div>' : '') +
      '<div class="wd-sub" style="margin:8px 2px">Marked by ' + esc(p.engine || '') + '. Read by ' + esc((p.read_by || []).join(', ')) + '. The video was ' + esc(p.video || '') + '.</div>';
  }
  function measured() {
    var m = S.measure; if (!m || !m.marked) return '';
    var pct = m.agreement == null ? '—' : Math.round(m.agreement * 100) + '%';
    var secs = function (x) { return x && x.n ? Math.round(x.median) + ' s' : '—'; };
    return '<div class="wd-card"><h3>Measured on this exam</h3><div class="wd-nums">' +
      '<div><b>' + pct + '</b>you agreed with Witness (' + m.teacher_agreed + ' of ' + m.reviewed + ' reviewed)</div>' +
      '<div><b>' + m.wrong_thinking_caught + '</b>right answers by wrong thinking caught</div>' +
      '<div><b>' + secs(m.marking_seconds) + '</b>to mark a paper (median)</div>' +
      '<div><b>' + secs(m.teacher_seconds_per_paper) + '</b>of your time per paper (median)</div>' +
      '<div><b>' + m.examiner_answered + ' / ' + m.examiner_asks + '</b>examiner questions answered</div></div>' +
      ((m.changed_by_teacher || []).length ? '<div class="wd-sub">You changed: ' + m.changed_by_teacher.map(function (c) { return 'Q' + c.n + ' ' + (RESULT[c.witness] || c.witness) + ' → ' + (RESULT[c.teacher] || c.teacher); }).join('; ') + '</div>' : '') + '</div>';
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
    var j = await api('POST', '/api/witness/pile', { title: d.title, level: d.level || '', questions: questionsOf(d.qs), scheme: d.scheme || '', kind: d.kind === 'practical' ? 'practical' : 'paper', engine: d.engine === 'open' ? 'open' : 'meta' });
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
    if (d.comment != null) body.comment = d.comment;
    body.desk_s = Math.max(0, Math.round((Date.now() - (S.opened || Date.now())) / 1000));
    S.opened = Date.now();
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
  async function remark() {
    S.busy = true;
    var j = await api('POST', '/api/witness/sitting/' + S.sid + '/mark', {});
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    S.paper = { ok: true, id: S.sid, status: j.status };
    say('Marking it again. It shows here when it is done.');
    render();
    var sid = S.sid, tries = 0;
    (function look() {
      setTimeout(function () {
        if (S.view !== 'paper' || S.sid !== sid) return;
        loadPaper(sid).then(function () {
          if (S.paper && S.paper.status === 'marking' && tries++ < 60) return look();
          render();
        });
      }, 5000);
    })();
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
