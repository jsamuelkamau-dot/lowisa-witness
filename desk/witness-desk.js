// === FROM EXAM TO MASTERY: THE TEACHER'S DESK (2026-10-27, Meta hackathon; 29 Oct, owner: From Exam to Mastery) ===
// A teacher's exams, each a pile of papers. After the exam a single phone (a teacher's or one the school owns)
// photographs each paper; Muse Spark reads the name on it and marks the path as well as the answer. Witness (the
// optional way in, one student at a time) films the desk while they write and SAM 3.1 follows the ink. No question
// ends in a verdict: it is mastered, or it goes into the student's Mastery Plan. The desk shows every paper, a review queue that puts the marks the model is
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

  // 29 Oct (owner): no verdict. Every question not mastered goes into the student's Mastery Plan; the teacher sees why.
  var RESULT = {
    mastered: 'Mastered',
    right_answer_wrong_thinking: 'Mastery Plan: right answer, wrong thinking',
    part_way: 'Mastery Plan: part way',
    not_yet: 'Mastery Plan',
  };
  var TONE = { mastered: 'ok', right_answer_wrong_thinking: 'warn', part_way: 'warn', not_yet: 'warn' };
  // the seven thinking capabilities LoWisa's teaching builds (owner, 29 Oct)
  var CAPS = {
    'Pattern Recognition': 'Identify patterns, relationships, trends and recurring structures in problems and real-world situations.',
    'Probability & Uncertainty': "Understand likelihood, risk and uncertainty when outcomes aren't guaranteed.",
    'Optimization': 'Find the most effective solution while considering resources, constraints, time and cost.',
    'Systems Thinking': 'Understand how different components interact and how changes affect an entire system.',
    'Trade-offs': 'Evaluate competing priorities and understand what is gained or sacrificed when choosing between alternatives.',
    'Decision-Making': 'Apply evidence, logic and mathematical reasoning to select appropriate actions.',
    'Root Cause Analysis': 'Investigate problems systematically to identify underlying causes rather than symptoms.'
  };
  function inPlan(r) { return !!r && r !== 'mastered'; }

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
      window.__lowisaRegisterCommand({ id: 'witness.open', title: 'From Exam to Mastery: Open', category: 'From Exam to Mastery', run: function () { open(); } });
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
    '#lowisaWitnessDesk .wd-chip.ok{color:var(--ok);border-color:var(--ok)}#lowisaWitnessDesk .wd-chip.warn{color:var(--warn);border-color:var(--warn)}' +
    '#lowisaWitnessDesk .wd-chip.err{color:var(--err);border-color:var(--err)}' +
    '#lowisaWitnessDesk .wd-btn{background:var(--bgh);color:var(--tx);border:1px solid var(--bd2);border-radius:6px;padding:5px 10px;cursor:pointer;font-size:12px}' +
    '#lowisaWitnessDesk .wd-btn.wd-main{background:var(--ac);color:var(--on-ac);border-color:var(--ac);font-weight:600}' +
    '#lowisaWitnessDesk input,#lowisaWitnessDesk textarea,#lowisaWitnessDesk select{background:var(--bgt);color:var(--tx);border:1px solid var(--bd2);border-radius:6px;padding:5px 7px;font-size:12px;font-family:inherit;width:100%;box-sizing:border-box}' +
    '#lowisaWitnessDesk label{display:block;margin:8px 0 3px;color:var(--tx2);font-size:11.5px}' +
    '#lowisaWitnessDesk .wd-msg{margin:0 0 10px;padding:7px 10px;border-radius:8px;background:var(--bga)}#lowisaWitnessDesk .wd-msg.err{color:var(--err)}' +
    '#lowisaWitnessDesk .wd-steps{border-left:2px solid var(--bd2);margin:6px 0 6px 6px;padding-left:12px}' +
    '#lowisaWitnessDesk .wd-step{position:relative;margin:0 0 7px;transition:opacity .3s}#lowisaWitnessDesk .wd-step.later{opacity:.18}' +
    '#lowisaWitnessDesk .wd-step:before{content:"";position:absolute;left:-17px;top:5px;width:8px;height:8px;border-radius:50%;background:var(--bd2)}' +
    '#lowisaWitnessDesk .wd-step.slip:before{background:var(--err)}#lowisaWitnessDesk .wd-step .wd-ink{font-family:var(--fm);font-size:13px}' +
    '#lowisaWitnessDesk .wd-step.crossed .wd-ink{text-decoration:line-through;color:var(--tx2)}' +
    '#lowisaWitnessDesk .wd-diag{border:1px solid var(--err);border-radius:8px;padding:8px 10px;margin:8px 0}' +
    '#lowisaWitnessDesk .wd-nums{display:flex;gap:10px;flex-wrap:wrap;margin:0 0 12px}#lowisaWitnessDesk .wd-nums div{background:var(--bga);border-radius:8px;padding:8px 12px}' +
    '#lowisaWitnessDesk .wd-nums b{display:block;font-size:18px}' +
    // the Proof of Thinking record prints alone, on white (29 Oct audit: Print printed the whole window)
    '@media print{html,body{height:auto!important;overflow:visible!important;background:white!important}' +
    'body>*:not(#lowisaWitnessDesk){display:none!important}' +
    '#lowisaWitnessDesk{position:static!important;display:block!important;border:0!important;background:white!important;color:black!important;' +
    '--tx:black;--tx2:dimgray;--bg2:white;--bga:whitesmoke;--bgt:white;--bd:lightgray;--bd2:silver}' +
    '#lowisaWitnessDesk .wd-head,#lowisaWitnessDesk .wd-btn,#lowisaWitnessDesk video,#lowisaWitnessDesk audio{display:none!important}' +
    '#lowisaWitnessDesk .wd-body{overflow:visible!important;padding:0!important}#lowisaWitnessDesk .wd-card{break-inside:avoid}}';

  // the desk draws only into its own panel; `take` (opening it) makes a panel already there its own. A desk left behind
  // by a reload never draws over the one in front (29 Oct: a late answer redrew the page with the old desk's state)
  function panelEl(take) {
    var p = document.getElementById('lowisaWitnessDesk');
    if (p && (take || p === S.el)) { S.el = p; return p; }
    if (p) return null;
    if (!document.getElementById('lowisaWitnessCss')) {
      var st = document.createElement('style');
      st.id = 'lowisaWitnessCss';
      st.textContent = CSS;
      document.head.appendChild(st);
    }
    p = document.createElement('div');
    p.id = 'lowisaWitnessDesk';
    p.setAttribute('role', 'dialog');
    p.setAttribute('aria-label', 'From Exam to Mastery');
    p.addEventListener('click', onClick);
    p.addEventListener('input', onInput);
    p.addEventListener('change', onInput);
    document.body.appendChild(p);
    S.el = p;   // this desk's own panel: its timers stop once another panel stands in its place
    return p;
  }
  function onKey(e) { if (e.key === 'Escape' && document.getElementById('lowisaWitnessDesk')) { e.stopPropagation(); back(); } }

  async function open() {
    if (!S.on) return false;
    panelEl(true);
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
    if (where.paper && await loadPaper(where.paper)) { S.view = 'paper'; S.n = where.n != null ? Number(where.n) : null; stopPoll(); watchPaper(); }
    render();
    return true;
  }
  function close() {
    stopPlay(); stopPoll(); stopWatch();
    var p = document.getElementById('lowisaWitnessDesk');
    if (p) p.remove();
    document.removeEventListener('keydown', onKey, true);
  }
  // Esc and Back go one step up; from the exams list they close the desk
  function back() {
    if (S.view === 'proof') { S.view = 'paper'; render(); watchPaper(); }
    // back on the exam it is read again and keeps itself current (28 Oct, live: a paper sent while the teacher
    // reviewed another never showed, because the exam's refresh stopped when the paper opened)
    else if (S.view === 'paper') { stopPlay(); stopRec(); stopWatch(); S.view = 'pile'; render(); loadPile(S.pid).then(render); }
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
      if (S.view !== 'pile' || document.getElementById('lowisaWitnessDesk') !== S.el) { stopPoll(); return; }
      loadPile(S.pid).then(render);
    }, 5000);
  }
  function stopPoll() { if (S.timer) { clearInterval(S.timer); S.timer = null; } }
  // an open paper keeps its question's mastery current: a finished lesson, a question to the teacher, an explanation,
  // the finished level (29 Oct, live: the teacher only saw them after reopening the paper). Only the mastery card is
  // redrawn, only when it changed, and never under the teacher's typing or a playing recording.
  function watchPaper() {
    if (S.ptimer) return;
    S.ptimer = setInterval(async function () {
      if (S.view !== 'paper' || document.getElementById('lowisaWitnessDesk') !== S.el) { stopWatch(); return; }
      var sid = S.sid, n = S.n;
      var j = await api('GET', '/api/witness/sitting/' + sid);
      if (!j.ok || S.view !== 'paper' || S.sid !== sid || S.n !== n) return;
      var of = function (p) { return (((p && p.result && p.result.questions) || []).filter(function (x) { return x.n === n; })[0]) || null; };
      var was = of(S.paper), now = of(j);
      if (!now || JSON.stringify((was && was.mastery) || null) === JSON.stringify(now.mastery || null)) return;
      var box = document.getElementById('wdMastery');
      if (!box || box.contains(document.activeElement) || [].some.call(box.querySelectorAll('audio'), function (a) { return !a.paused; })) return;
      S.paper = j;
      box.innerHTML = masteryCard(now);
      fillAssets(box);
    }, 6000);
  }
  function stopWatch() { if (S.ptimer) { clearInterval(S.ptimer); S.ptimer = null; } }

  // ---------------------------------------------------------------- drawing
  function render() {
    var p = panelEl();
    if (!p) return;
    var crumb = S.view === 'home' ? '' : S.view === 'new' ? 'New exam' : esc(S.pile && S.pile.pile ? S.pile.pile.title : '');
    var head = '<div class="wd-head"><b>From Exam to Mastery</b>' + (crumb ? '<span class="wd-crumb">/ ' + crumb + '</span>' : '') +
      (S.view === 'paper' && S.paper ? '<span class="wd-crumb">/ ' + esc(S.paper.student || 'Paper') + '</span>' : '') +
      '<span class="wd-grow"></span>' +
      (S.view !== 'home' ? '<button class="wd-btn" data-act="back">Back</button>' : '') +
      '<button class="wd-btn" data-act="close" aria-label="Close From Exam to Mastery">Close</button></div>';
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
      '<div class="wd-sub">Students sit the exam on paper. Afterwards a single phone photographs each paper, a teacher\'s or one the school owns. ' +
      'Every question a student didn\'t master goes into their Mastery Plan. Desk filming, the optional way in, films one student\'s desk while they write.</div></span>' +
      '<button class="wd-btn wd-main" data-act="new">New exam</button></div></div>' +
      (rows ? '<div class="wd-card">' + rows + '</div>' : '<div class="wd-card wd-sub">No exams yet. Start one; after the exam, photograph each student\'s paper from the LoWisa phone app.</div>');
  }

  function viewNew() {
    var d = S.draft;
    return '<div class="wd-card" style="max-width:720px">' +
      // 28 Oct re-audit (the submission: "a mark scheme built from the teacher's own material"): Muse Spark reads a
      // photo or PDF of the paper or its scheme into this form, for the teacher to check
      '<label for="wdRead">Start from your own paper or mark scheme (a photo or a PDF)</label>' +
      '<input id="wdRead" type="file" accept="image/jpeg,image/png,image/webp,application/pdf">' +
      '<div class="wd-sub">' + (S.reading ? 'Muse Spark is reading it…' : 'Muse Spark reads the questions, their marks and your scheme into the form below. Check them before you create the exam.') + '</div>' +
      '<label for="wdTitle">Exam name</label><input id="wdTitle" data-f="title" value="' + esc(d.title || '') + '" placeholder="Fractions quiz, Year 7">' +
      '<label for="wdLevel">Level</label><input id="wdLevel" data-f="level" value="' + esc(d.level || '') + '" placeholder="Year 7, university first year, CPA part 1">' +
      '<label for="wdKind">What students do</label><select id="wdKind" data-f="kind">' +
      '<option value="paper"' + (d.kind !== 'practical' ? ' selected' : '') + '>An exam on paper (photographed after the exam, or filmed at the desk)</option>' +
      '<option value="practical"' + (d.kind === 'practical' ? ' selected' : '') + '>A practical task (filmed being done: the hands and the apparatus)</option></select>' +
      '<label for="wdEngine">Marked by</label><select id="wdEngine" data-f="engine">' +
      '<option value="meta"' + (d.engine !== 'open' ? ' selected' : '') + '>Muse Spark (with SAM 3.1 following the ink when a paper is filmed)</option>' +
      '<option value="open"' + (d.engine === 'open' ? ' selected' : '') + '>Muse Spark Open, on open weights</option></select>' +
      '<label for="wdPreview">Mastery levels</label><select id="wdPreview" data-f="preview">' +
      '<option value="yes"' + (d.preview !== 'no' ? ' selected' : '') + '>I look at each level first</option>' +
      '<option value="no"' + (d.preview === 'no' ? ' selected' : '') + '>Reach each student as soon as it is made (a level its self-check did not pass still waits for me)</option></select>' +
      '<label for="wdQs">' + (d.kind === 'practical' ? 'The procedure\'s steps, one a line, with the marks in brackets' : 'Questions, one a line, with the marks in brackets') + '</label>' +
      '<textarea id="wdQs" data-f="qs" rows="6" placeholder="1. 3/4 ÷ 1/2 (2)&#10;2. Solve 2x + 6 = 14 (2)&#10;3. Simplify 16/64 (2)">' + esc(d.qs || '') + '</textarea>' +
      '<div class="wd-sub">Leave it empty to let Muse Spark read the questions printed on the paper.</div>' +
      '<label for="wdScheme">Your mark scheme</label><textarea id="wdScheme" data-f="scheme" rows="6" placeholder="Q1: 1 mark for multiplying by the reciprocal, 1 for 3/2.">' + esc(d.scheme || '') + '</textarea>' +
      '<div class="wd-sub">Muse Spark follows it exactly, method marks included. Without one, each question is worth its marks when both the method and the answer are right.</div>' +
      '<div style="margin-top:12px;display:flex;gap:8px"><button class="wd-btn wd-main" data-act="create">Create exam</button><button class="wd-btn" data-act="back">Cancel</button></div></div>';
  }

  function viewPile() {
    var j = S.pile || {}; var ss = j.sittings || []; var q = j.queue || [];
    var marked = ss.filter(function (s) { return s.status === 'marked' || s.status === 'released'; });
    var toMaster = marked.reduce(function (a, s) { return a + (s.to_master || 0); }, 0);
    var turned = marked.reduce(function (a, s) { return a + (s.turned_around || 0); }, 0);
    var nums = '<div class="wd-nums"><div><b>' + ss.length + '</b>papers</div><div><b>' + marked.length + '</b>marked</div>' +
      '<div><b>' + q.length + '</b>to review</div><div><b>' + toMaster + '</b>in Mastery Plans</div>' +
      (turned ? '<div><b>' + turned + '</b>turned around</div>' : '') + '</div>';
    var papers = ss.map(function (s) {
      var st = s.status === 'marked' ? '<span class="wd-sub">' + num(s.marks) + ' / ' + num(s.out_of) + '</span>' :
        s.status === 'released' ? '<span class="wd-chip ok">Released</span>' :
        s.status === 'failed' ? '<span class="wd-chip err">' + (s.unreadable ? 'Paper not in view: film again' : s.kept ? 'Not marked yet: mark again' : s.kind === 'photo' ? 'Photograph again' : 'Record again') + '</span>' : '<span class="wd-chip">' + (s.status === 'uploading' ? 'Uploading' : 'Marking') + '</span>';
      return '<div class="wd-row" data-paper="' + esc(s.id) + '"><span class="wd-grow">' + esc(s.student || 'Paper') + '</span>' + whoseChip(s) + st +
        (s.to_master ? '<span class="wd-chip warn">' + s.to_master + ' in Mastery Plan</span>' : '') +
        (s.turned_around ? '<span class="wd-chip ok">' + s.turned_around + ' turned around</span>' : '') + '</div>';
    }).join('') || '<div class="wd-sub">No papers yet. After the exam, photograph them from the LoWisa phone app with this exam\'s photographing code.</div>';
    var queue = q.map(function (it) {
      return '<div class="wd-row" data-paper="' + esc(it.sitting) + '" data-n="' + esc(it.n) + '"><span class="wd-grow">' + esc(it.student || 'Paper') + ' · Q' + esc(it.n) +
        (it.diagnosis ? '<div class="wd-sub" style="white-space:normal">' + esc(it.diagnosis) + '</div>' : '') + '</span>' +
        chip(it.result) + '<span class="wd-sub">' + Math.round((it.confidence || 0) * 100) + '% sure</span></div>';
    }).join('') || '<div class="wd-sub">Nothing left to review.</div>';
    // 31 Oct (judges' panel, the school leader: forty papers, one question at a time)
    var sure = q.filter(function (it) { return it.result === 'mastered' && (it.confidence || 0) >= 0.9; });
    if (sure.length) queue = '<div class="wd-row" style="cursor:default"><span class="wd-grow wd-sub">' + sure.length + ' marked mastered, Muse Spark 90% sure or more</span>' +
      '<button class="wd-btn" data-act="acceptsure">Accept all ' + sure.length + '</button></div>' + queue;
    var ready = (j.ready || []);
    var readyCard = ready.length ? '<div class="wd-card"><h3>Ready for Turned around: ' + ready.length + '</h3>' +
      '<div class="wd-sub">The level finished and your challenge answered right. Read each reason, untick any you are not sure of, then issue them together.</div>' +
      ready.map(function (r, i) {
        return '<label style="display:flex;gap:8px;align-items:flex-start;margin-top:6px;color:var(--tx)"><input type="checkbox" data-ready="' + i + '" checked style="width:auto;margin-top:3px">' +
          '<span><b>' + esc(r.student || 'Paper') + ' · Q' + esc(r.n) + '</b> <span class="wd-sub">' + esc(r.idea || '') + '</span><div>“' + esc(r.why || '') + '”</div>' +
          (r.verdict ? '<div class="wd-sub">Muse Spark: ' + (r.verdict.understood ? 'the reason holds. ' : 'the reason does not hold. ') + esc(r.verdict.why || '') + '</div>' : '') + '</span></label>';
      }).join('') + '<div style="margin-top:8px"><button class="wd-btn wd-main" data-act="readybadge">Issue Turned around for the ticked ones</button></div></div>' : '';
    var released = j.pile && j.pile.released_ms;
    var waiting = (j.sittings || []).filter(function (x) { return x.status === 'marked'; }).length;
    var roster = (j.pile && j.pile.roster) || [];
    // 31 Oct (judges' panel): the phone that photographs uses its own code, which students never see; joining closes
    // once the class has joined; a name that should not be on the list comes off it
    var closed = j.pile && j.pile.joining === 'closed';
    var code = j.pile && j.pile.code ? '<div class="wd-card"><b>Join code: <span style="font-size:18px;letter-spacing:3px">' + esc(j.pile.code) + '</span></b>' +
      (closed ? ' <span class="wd-chip warn">Joining closed</span>' : '') +
      '<div class="wd-sub">Students enter it in the LoWisa phone app to put their name on the class list.</div>' +
      (j.pile.photo_code ? '<div style="margin-top:6px"><b>Photographing code: <span style="font-size:18px;letter-spacing:3px">' + esc(j.pile.photo_code) + '</span></b>' +
        '<div class="wd-sub">Only for the one phone that photographs the papers after the exam (yours, or one the school owns). Never give it to students.</div></div>' : '') +
      '<div class="wd-sub" style="margin-top:6px"><b>Class list: ' + roster.length + ' joined</b></div>' +
      (roster.length ? '<div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:4px">' + roster.map(function (r) {
        return '<span class="wd-chip">' + esc(r.name) + ' <button class="wd-btn" data-act="unroster" data-uid="' + esc(r.uid) + '" aria-label="Take ' + esc(r.name) + ' off the class list" style="padding:0 6px;margin-left:4px">×</button></span>'; }).join('') + '</div>' : '') +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="joining" data-open="' + (closed ? '1' : '0') + '">' + (closed ? 'Open joining again' : 'Close joining') + '</button>' +
      ' <span class="wd-sub">Desk filming (optional): a student working alone films their desk while they write.</span></div></div>' : '';
    return code + nums + measured() + readyCard + patternsCard(j.pile || {}, toMaster + turned) + '<div class="wd-cols"><div class="wd-card"><h3>Papers</h3>' + papers + '</div>' +
      '<div class="wd-card"><h3>To review: what needs you first</h3>' + queue + '</div></div>' +
      // a paper photographed after the release (a student who sat it late) waits for its own release (30 Oct, film take:
      // the second paper stayed "marked" and the button was gone)
      '<div style="margin-top:6px">' + (released && waiting ? '<button class="wd-btn wd-main" data-act="release">Release ' + waiting + ' new paper' + (waiting === 1 ? '' : 's') + '</button> ' +
        '<span class="wd-chip ok">The rest are released</span>' : released ? '<span class="wd-chip ok">Released to students</span>' :
        '<button class="wd-btn wd-main" data-act="release">Release marks</button> <span class="wd-sub">Students see their marks, and every question they didn\'t master goes into their Mastery Plan.</span>') + '</div>' +
      deleteCard('exam');
  }

  // 28 Oct re-audit (the submission's class report; the plan's class patterns and "the next exam can bring back the
  // question types the class turned around"): Muse Wonder groups the class's questions to master by misconception
  function patternsCard(pile, any) {
    var pt = pile.patterns;
    if (!any && !pt) return '';
    var head = '<div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Class patterns</h3>' +
      '<div class="wd-sub">The same misconception across your students, what to reteach tomorrow, and questions for the next exam.</div></span>' +
      (pt && pt.status === 'making' ? '<span class="wd-chip">Muse Wonder is reading the class…</span>' :
        '<button class="wd-btn" data-act="patterns">' + (pt && pt.status === 'ready' ? 'Find them again' : 'Find the class\'s patterns') + '</button>') + '</div>';
    if (!pt || pt.status !== 'ready') return '<div class="wd-card">' + head + (pt && pt.status === 'failed' ? '<div class="wd-sub" style="margin-top:6px">That did not come back. Try again in a moment.</div>' : '') + '</div>';
    var groups = (pt.patterns || []).map(function (g, gi) {
      var n = (g.students || []).length;
      return '<div style="margin-top:10px"><b>' + n + ' student' + (n === 1 ? '' : 's') + ': ' + esc(g.idea) + '</b>' +
        (g.turned_around ? ' <span class="wd-chip ok">' + g.turned_around + ' turned around</span>' : '') +
        '<div class="wd-sub">' + esc((g.students || []).join(', ')) + ' · ' + unit().toLowerCase() + ((g.questions || []).length === 1 ? ' ' : 's ') + esc((g.questions || []).join(', ')) + '</div>' +
        (g.reteach ? '<div style="margin-top:2px">Reteach: ' + esc(g.reteach) + '</div>' : '') +
        // 31 Oct (judges' panel): one challenge to the whole group, the same idea in a new situation
        ((g.items || []).length > 1 && pile.released_ms ? groupChallenge(g, gi) : '') + '</div>';
    }).join('');
    var next = (pt.next_exam || []);
    return '<div class="wd-card">' + head + groups +
      (pt.tomorrow ? '<div style="margin-top:10px"><b style="font-size:12px">Tomorrow</b><div>' + esc(pt.tomorrow) + '</div></div>' : '') +
      (next.length ? '<div style="margin-top:10px"><b style="font-size:12px">For the next exam</b>' + next.map(function (x, i) { return '<div class="wd-sub">' + (i + 1) + '. ' + esc(x.text) + ' (' + esc(x.marks) + ')</div>'; }).join('') +
        '<div style="margin-top:6px"><button class="wd-btn wd-main" data-act="nextexam">Start the next exam with these</button></div></div>' : '') + '</div>';
  }

  function groupChallenge(g, gi) {
    var d = S.draft, open = d.groupOpen === gi;
    if (!open) return '<div style="margin-top:6px"><button class="wd-btn" data-act="groupopen" data-g="' + gi + '">One challenge for all ' + g.items.length + '</button></div>';
    var opts = [0, 1, 2, 3].map(function (i) {
      return '<div style="display:flex;gap:6px;align-items:center;margin-top:4px"><input type="radio" name="wdGroupAns" data-f="gAns" value="' + i + '"' + (String(d.gAns) === String(i) ? ' checked' : '') + ' style="width:auto" aria-label="Option ' + (i + 1) + ' is right">' +
        '<input data-f="gOpt' + i + '" value="' + esc(d['gOpt' + i] || '') + '" placeholder="Option ' + (i + 1) + '" aria-label="Option ' + (i + 1) + '"></div>';
    }).join('');
    return '<div class="wd-card" style="margin-top:6px"><b>One challenge for ' + g.items.length + ' students</b>' +
      '<textarea data-f="gQ" rows="3" placeholder="The same idea in a new situation" aria-label="The challenge">' + esc(d.gQ || '') + '</textarea>' + opts +
      '<div class="wd-sub">Tick the right option. Each student answers on their phone and says why; you read every reason.</div>' +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="groupdraft" data-g="' + gi + '">Draft one with Muse Spark</button> ' +
      '<button class="wd-btn wd-main" data-act="groupsend" data-g="' + gi + '">Send to all ' + g.items.length + '</button></div></div>';
  }

  // one call on the open exam (31 Oct): the class list, joining, and the actions on many questions at once
  async function pileDo(path, body, done) {
    var id = S.pile && S.pile.pile && S.pile.pile.id; if (!id) return;
    var j = await api('POST', '/api/witness/pile/' + id + '/' + path, body);
    if (j.ok) { say(done + (j.results ? countNot(j.results) : '')); } else { say(j.error || 'That did not go through. Try again.', 'err'); }
    await loadPile(id); return render();
  }
  function countNot(rs) {
    var not = rs.filter(function (r) { return r.result !== 'ok'; }).length;
    return not ? ' ' + not + ' could not yet (the level not finished, or already done).' : '';
  }
  function groupOf(gi) { return ((((S.pile || {}).pile || {}).patterns || {}).patterns || [])[gi] || null; }
  async function groupDraft(gi) {
    var g = groupOf(gi); if (!g || !(g.items || []).length) return;
    var first = g.items[0];
    say('Muse Spark is drafting one challenge for the group…'); render();
    var j = await api('POST', '/api/witness/mastery/' + first.sitting + '/' + first.n + '/challenge_suggest', { note: 'for the whole group: ' + (g.idea || '') });
    if (j.ok && j.suggestion) {
      var sg = j.suggestion; S.draft.gQ = sg.q; S.draft.gAns = sg.answer;
      (sg.options || []).forEach(function (o, i) { S.draft['gOpt' + i] = o; });
      say('Here is a draft. Change anything, then send it.');
    } else say(j.error || 'No draft came back. Write your own.', 'err');
    return render();
  }
  async function groupSend(gi) {
    var g = groupOf(gi), d = S.draft; if (!g) return;
    var options = [0, 1, 2, 3].map(function (i) { return (d['gOpt' + i] || '').trim(); }).filter(Boolean);
    var answer = Number(d.gAns);
    if (!(d.gQ || '').trim() || options.length < 2 || !(answer >= 0 && answer < options.length)) { say('A challenge needs a question, at least two options and the right one ticked.', 'err'); return render(); }
    S.draft.groupOpen = null;
    return pileDo('bulk', { action: 'challenge', challenge: { q: d.gQ.trim(), options: options, answer: answer }, items: g.items }, 'Sent to ' + g.items.length + ' students.');
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
    return whoseCard(j) + '<div class="wd-cols"><div><div class="wd-card"><h3>' + (practical() ? 'The procedure' : 'Questions') + '</h3>' + list +
      returnsLine((j.result && j.result.returns) || []) +
      '<div style="margin-top:10px"><button class="wd-btn" data-act="proof">Proof of Thinking</button></div></div>' + examinerCard(j) + '</div><div>' + questionCard(q) + '</div></div>' +
      deleteCard('paper');
  }

  // 30 Oct (judges' panel: nothing could be deleted): the teacher deletes a paper or a whole exam, for good
  function deleteCard(what) {
    var words = what === 'paper' ? 'This paper: its photographs, the recordings of spoken answers, its pictures and its level\'s record, and the student\'s link to it.'
      : 'This exam and every paper in it: the photographs, the recordings, the pictures, the class list and the join code.';
    if (S.draft.delAsk !== what) return '<div style="margin-top:14px"><button class="wd-btn" data-act="delask" data-what="' + what + '">Delete this ' + (what === 'paper' ? 'paper' : 'exam') + '</button></div>';
    return '<div class="wd-card" style="margin-top:14px"><b>Delete for good?</b><div class="wd-sub">' + words + ' Nothing of it is kept.</div>' +
      '<div style="margin-top:8px;display:flex;gap:8px"><button class="wd-btn wd-main" data-act="delete" data-what="' + what + '">Delete for good</button>' +
      '<button class="wd-btn" data-act="delkeep">Keep it</button></div></div>';
  }
  async function deleteIt(what) {
    S.busy = true;
    var j = await api('POST', what === 'paper' ? '/api/witness/sitting/' + S.sid + '/delete' : '/api/witness/pile/' + S.pid + '/delete', {});
    S.busy = false; S.draft.delAsk = '';
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    // back to where the teacher came from, read again, with the word that it is gone
    if (what === 'paper') { stopPlay(); stopRec(); stopWatch(); S.view = 'pile'; await loadPile(S.pid); }
    else { stopPoll(); S.view = 'home'; await loadPiles(); }
    say(what === 'paper' ? 'The paper is deleted.' : 'The exam is deleted.');
    render();
  }

  // From Exam to Mastery (29 Oct): who a photographed paper is, read from the paper and matched to the class list; the
  // teacher confirms it, picks another student, or types the name of a student with no phone (printed for them)
  // 31 Oct (judges' panel): a name that joined the list after the paper was photographed waits for the teacher
  var MATCH = { read: ['ok', 'Name read'], teacher: ['ok', 'Set by you'], unsure: ['warn', 'Whose? Confirm'], confirm: ['warn', 'Joined after the photo: confirm'],
                none: ['warn', 'Not on the class list'], unread: ['warn', 'No name read'] };
  function whoseChip(s) {
    if (s.kind !== 'photo' || !(s.status === 'marked' || s.status === 'released')) return '';
    var m = MATCH[s.name_match] || null;
    return m ? '<span class="wd-chip ' + m[0] + '">' + m[1] + '</span>' : '';
  }
  function whoseCard(j) {
    if (j.kind !== 'photo') return '';
    var read = j.read || {};
    var roster = (S.pile && S.pile.pile && S.pile.pile.roster) || [];
    var cands = (((S.pile && S.pile.sittings) || []).filter(function (x) { return x.id === S.sid; })[0] || {}).candidates || [];
    var ordered = roster.filter(function (r) { return cands.indexOf(r.uid) >= 0; }).concat(roster.filter(function (r) { return cands.indexOf(r.uid) < 0; }));
    var m = MATCH[j.name_match] || ['', ''];
    var detail = [read['class'] ? 'class ' + esc(read['class']) : '', read.number ? 'number ' + esc(read.number) : '', read.date ? esc(read.date) : ''].filter(Boolean).join(' · ');
    var pages = (j.pages || []).map(function (f, i) {
      return '<img data-asset="' + esc(f) + '" alt="Page ' + (i + 1) + ' of the paper" style="width:120px;border-radius:6px;background:var(--nb-paper);min-height:60px;margin:6px 6px 0 0;vertical-align:top">';
    }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Whose paper</h3></span>' +
      (m[1] ? '<span class="wd-chip ' + m[0] + '">' + m[1] + '</span>' : '') + '</div>' +
      '<div style="margin-top:6px">Name written on the paper: <b>' + esc(read.name || 'none could be read') + '</b>' + (detail ? ' <span class="wd-sub">· ' + detail + '</span>' : '') + '</div>' +
      (read.note ? '<div class="wd-sub">' + esc(read.note) + '</div>' : '') +
      '<div class="wd-sub">' + (j.linked ? 'This paper is with ' + esc(j.student) + ': their marks and Mastery Plan reach their phone.' :
        'Not with a student on the class list yet. Choose who it is, or type the name of a student with no phone and print their Mastery Plan.') + '</div>' +
      '<div style="display:flex;gap:8px;margin-top:8px;align-items:center;flex-wrap:wrap">' +
      (ordered.length ? '<select data-f="whose" aria-label="The student on the class list" style="width:auto;min-width:200px">' + ordered.map(function (r) {
        return '<option value="' + esc(r.uid) + '">' + esc(r.name) + (cands.indexOf(r.uid) >= 0 ? ' (likely)' : '') + '</option>'; }).join('') + '</select>' +
        '<button class="wd-btn" data-act="whose">This is theirs</button>' : '<span class="wd-sub">No one has joined the class list yet.</span>') +
      '<input data-f="whoseName" placeholder="Or a name (no phone)" aria-label="A student with no phone" style="width:auto;min-width:180px"><button class="wd-btn" data-act="whosename">Use this name</button></div>' +
      (pages ? '<div style="margin-top:8px"><b style="font-size:12px">The pages</b><div>' + pages + '</div></div>' : '') + '</div>';
  }

  function questionCard(q) {
    var timed = (q.steps || []).some(function (s) { return s.t != null; });
    var steps = (q.steps || []).map(function (s, i) {
      // a photographed paper has no times: the slip is the step Muse Spark named
      var slip = timed ? (q.moment_s != null && s.t != null && nearMoment(q, i)) : (q.slip != null && q.slip - 1 === i);
      return '<div class="wd-step' + (s.crossed_out ? ' crossed' : '') + (slip ? ' slip' : '') + '" data-i="' + i + '">' +
        '<span class="wd-sub">' + (s.t == null ? '' : fmtT(s.t)) + (s.crossed_out ? (s.t == null ? 'crossed out' : ' · crossed out') : '') + '</span><div class="wd-ink">' + esc(s.wrote) + '</div></div>';
    }).join('') || '<div class="wd-sub">No steps were read for this question.</div>';
    var caps = (q.capabilities || []).filter(function (c) { return CAPS[c]; });
    var res = q.teacher_result || q.result;
    var marks = q.teacher_marks != null ? q.teacher_marks : q.marks;
    var opts = Object.keys(RESULT).map(function (k) { return '<option value="' + k + '"' + (k === res ? ' selected' : '') + '>' + RESULT[k] + '</option>'; }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">' + unit() + ' ' + esc(q.n) +
      (q.final_answer ? (practical() ? ' · result ' : ' · answer ') + esc(q.final_answer) : '') + '</h3></span>' + chip(q.result) +
      // 31 Oct (judges' panel: "95% sure" beside "Not named yet"): how sure the marking is, only once an idea is named
      (q.fingerprint && !q.fingerprint.misconception ? '' : '<span class="wd-sub">' + Math.round((q.confidence || 0) * 100) + '% sure</span>') + '</div>' +
      '<div style="margin:10px 0 4px;display:flex;gap:8px;align-items:center"><b style="font-size:12px">' + (practical() ? 'What was done' : 'How it was written') + '</b>' +
      (timed ? '<button class="wd-btn" data-act="replay">Replay</button>' : '') + '</div><div class="wd-steps" id="wdSteps">' + steps + '</div>' +
      (q.diagnosis ? '<div class="wd-diag"><b>Where the thinking went wrong' + (q.moment_s != null ? ' (' + fmtT(q.moment_s) + ')' : '') + '</b><div>' + esc(q.diagnosis) + '</div></div>' : '') +
      fingerprintCard(q.fingerprint) +
      (q.diagnosis_first ? '<div class="wd-sub" style="margin:4px 0">The marking first read: ' + esc(q.diagnosis_first) + '</div>' : '') +
      (caps.length && inPlan(q.teacher_result || q.result) ? '<div class="wd-card" style="margin:8px 0"><b style="font-size:12px">Thinking capabilities its level builds</b>' +
        caps.map(function (c) { return '<div class="wd-sub" style="margin-top:3px"><b style="color:var(--tx)">' + esc(c) + '</b>' + (q.skill ? ', here: ' + esc(q.skill) : ': ' + esc(CAPS[c])) + '</div>'; }).join('') + '</div>' : '') +
      stillOf(q) + '</div>' + drawnCard(q) + '<div class="wd-card"><h3>Your word</h3>' +
      '<label for="wdRes">Result</label><select id="wdRes" data-f="res">' + opts + '</select>' +
      '<label for="wdMarks">Marks out of ' + esc(q.out_of) + '</label><input id="wdMarks" data-f="marks" type="number" min="0" max="' + esc(q.out_of) + '" value="' + esc(marks) + '">' +
      '<label for="wdFocus">What should this student\'s mastery level focus on?</label>' +
      '<textarea id="wdFocus" data-f="focus" rows="3" placeholder="What to make them see, and something they care about (a sport, a job they want).">' + esc(q.focus || '') + '</textarea>' +
      '<div class="wd-sub">Each question a student didn\'t master gets one mastery level in their Mastery Plan, built from their own working and your note.</div>' +
      '<label for="wdComment">Your comment for the student</label>' +
      '<textarea id="wdComment" data-f="comment" rows="3" placeholder="Say it or write it: what they did well, and the one thing to change.">' + esc(S.draft.comment != null ? S.draft.comment : ((q.comment && q.comment.text) || '')) + '</textarea>' +
      '<div style="margin-top:6px;display:flex;gap:8px;align-items:center"><button class="wd-btn" data-act="speak">' + (S.rec ? 'Stop and write it down' : 'Speak it') + '</button>' +
      '<span class="wd-sub">' + (S.rec ? 'Listening… speak your comment.' : 'Muse Voice Transcribe writes down what you say; you can edit it before saving.') + '</span></div>' +
      '<div style="margin-top:10px"><button class="wd-btn wd-main" data-act="save">Save</button></div></div>' +
      '<div id="wdMastery">' + masteryCard(q) + '</div>';
  }

  // After release: the student's level, their questions to the teacher, the checks the teacher chooses (none needed),
  // what they explained, and the badge. Only for a question that was to master.
  var STATUS = { not_started: 'Level not started yet', building: 'Level being made', ready: 'Level ready on their phone', held: 'Level made: waiting for you to look',
                 completed: 'Level finished', badge: 'Turned around', not_yet: 'Keep going' };
  // the level as it was built, for the teacher to read; one the exam holds for a look waits for "Let them start" (28 Oct)
  function levelOutline(m) {
    var l = m.level;
    // 28 Oct, live: a level whose news reached the edge late came without its outline, and the button to let the
    // student start lived only inside the outline; a held level always has it
    if (!l) return m.status === 'held' ? '<div class="wd-card" style="margin-top:8px"><b>The level</b><div class="wd-sub">Its outline did not come with it.</div>' +
      '<div style="margin-top:8px"><button class="wd-btn wd-main" data-act="approve">Let them start</button> <span class="wd-sub">It reaches the student once you do.</span></div></div>' : '';
    return '<div class="wd-card" style="margin-top:8px"><b>' + esc(l.title || 'The level') + '</b>' +
      (m.world ? '<img data-asset="' + esc(m.world) + '" alt="The real-world place the level happens in, drawn by Muse Image" style="display:block;width:100%;max-width:420px;border-radius:8px;margin-top:6px;background:var(--nb-paper);min-height:60px">' : '') +
      (l.lessons || []).map(function (ls, i) {
      return '<div style="margin-top:6px"><b style="font-size:12px">Lesson ' + (i + 1) + ': ' + esc(ls.title) + '</b>' +
        (ls.beats || []).map(function (b) { return '<div class="wd-sub" style="margin:2px 0">· ' + esc(b) + '</div>'; }).join('') + '</div>';
    }).join('') + (m.status === 'held' ? '<div style="margin-top:8px"><button class="wd-btn wd-main" data-act="approve">Let them start</button>' +
      ' <span class="wd-sub">It reaches the student once you do.</span></div>' : '') + '</div>';
  }
  // 30 Oct (owner): a new challenge once the level has helped them: the same idea in a new situation, so the teacher
  // sees whether the principle is understood rather than the answer memorised. The teacher writes it, or Muse Spark
  // drafts one to edit; the student answers on the phone and says why; Spark reads the reason for the teacher.
  function challengeCard(m) {
    var c = m.challenge, d = S.draft, who = esc(S.paper.student || 'the student');
    var shown = '';
    if (c) {
      var r = c.reply;
      shown = '<div class="wd-card" style="margin-top:8px"><b>Your challenge</b> ' + (r ? '<span class="wd-chip ' + (r.right ? 'ok' : '') + '">' + (r.right ? 'Answered right' : 'Answered wrong') + '</span>' :
          '<span class="wd-chip">Sent: waiting for ' + who + '</span>') +
        '<div style="margin-top:4px">' + esc(c.q) + '</div>' +
        (c.options || []).map(function (o, i) {
          return '<div class="wd-sub" style="margin:2px 0">' + (i === c.answer ? '✓ ' : '· ') + esc(o) + (r && r.pick === i ? ' <b>(their answer)</b>' : '') + '</div>';
        }).join('') +
        (r ? '<div style="margin-top:6px"><b style="font-size:12px">Why, in their words</b><div>' + esc(r.why) + '</div>' +
          (r.verdict ? '<div class="wd-sub" style="margin-top:4px">Muse Spark: ' + (r.verdict.understood ? 'the reason holds. ' : 'the reason does not hold yet. ') + esc(r.verdict.why || '') + '</div>' : '') + '</div>' : '') + '</div>';
    }
    if (c && !d.chOpen) return shown + '<div style="margin-top:6px"><button class="wd-btn" data-act="chopen">Set another challenge</button></div>';
    var n = Math.max(3, Math.min(5, d.chN || 3));
    var opts = '';
    for (var i = 0; i < n; i++) {
      opts += '<input data-f="chO' + i + '" value="' + esc(d['chO' + i] || '') + '" placeholder="Option ' + (i + 1) + '" aria-label="Option ' + (i + 1) + '" style="margin-top:4px">';
    }
    var right = '<select data-f="chA" aria-label="The right option" style="width:auto;margin-top:6px">';
    for (var k = 0; k < n; k++) right += '<option value="' + k + '"' + (String(d.chA || '0') === String(k) ? ' selected' : '') + '>Option ' + (k + 1) + ' is right</option>';
    right += '</select>';
    return shown + '<div class="wd-card" style="margin-top:8px"><b>A new challenge</b><div class="wd-sub">The same idea in a new situation: it shows whether they understood the principle or remembered the answer.</div>' +
      '<label for="wdChQ">The question</label><textarea id="wdChQ" data-f="chQ" rows="3" placeholder="A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?">' + esc(d.chQ || '') + '</textarea>' +
      opts + (n < 5 ? '<div><button class="wd-btn" data-act="chmore" style="margin-top:4px">Add an option</button></div>' : '') + right +
      (d.chChecks ? '<div class="wd-sub" style="margin-top:4px">Muse Spark: ' + esc(d.chChecks) + '</div>' : '') +
      '<label for="wdChNote">Or ask Muse Spark to draft one</label><input id="wdChNote" data-f="chNote" value="' + esc(d.chNote || '') + '" placeholder="Optional: what you want it about, e.g. stored water">' +
      '<div style="margin-top:6px;display:flex;gap:8px;flex-wrap:wrap"><button class="wd-btn" data-act="chsuggest">Draft one with Muse Spark</button>' +
      '<button class="wd-btn wd-main" data-act="challenge">Send to ' + who + '</button></div></div>';
  }
  function challengeBody() {
    var d = S.draft, n = Math.max(3, Math.min(5, d.chN || 3)), options = [], answer = Number(d.chA || 0), at = -1;
    for (var i = 0; i < n; i++) {
      var o = String(d['chO' + i] || '').trim();
      if (o) { if (i === answer) at = options.length; options.push(o); }
    }
    return { q: String(d.chQ || '').trim(), options: options, answer: at };
  }
  async function suggestChallenge() {
    if (S.n == null) return;
    S.busy = true; say('Muse Spark is drafting a challenge…'); render();
    var j = await api('POST', '/api/witness/mastery/' + S.sid + '/' + S.n + '/challenge_suggest', { note: S.draft.chNote || '' });
    S.busy = false;
    if (!j.ok || !j.suggestion) { say(errText(j), 'err'); return render(); }
    var g = j.suggestion, d = S.draft;
    d.chOpen = true; d.chQ = g.q; d.chN = Math.max(3, (g.options || []).length); d.chA = String(g.answer); d.chChecks = g.checks || '';
    for (var i = 0; i < 5; i++) d['chO' + i] = (g.options || [])[i] || '';
    say('Drafted. Read it, change anything, then send it.');
    render();
  }

  // 30 Oct (owner): the Misconception Fingerprint. Not only whether the answer is right: the reasoning that produced it,
  // the evidence on the paper, the misconception (named only when that evidence is enough) and the intervention that
  // repairs it; when the paper was not enough, the question Lo asks the student, and what they answered.
  function fingerprintCard(f) {
    if (!f) return '';
    var row = function (label, html) { return html ? '<div style="margin-top:6px"><b style="font-size:12px">' + label + '</b><div>' + html + '</div></div>' : ''; };
    // while Lo still asks, the marking's reading is a guess, and says so
    var guessing = !f.misconception && !!f.ask && !(f.said || []).length;
    var said = (f.said || []).map(function (x) { return '<div class="wd-sub">Lo asked: ' + esc(x.ask) + '</div><div>They said: “' + esc(x.text) + '”</div>' + listen(x.audio, 'Their answer to Lo, out loud'); }).join('');
    return '<div class="wd-card" style="margin:8px 0"><b>Misconception fingerprint</b> ' +
      (f.misconception ? '<span class="wd-chip warn">' + esc(f.misconception) + '</span>' : '<span class="wd-chip">Not named yet: the paper is not enough evidence</span>') +
      // 30 Oct (judges' panel): nothing is named while Lo asks; the model's guess waits here, for the teacher only
      (!f.misconception && f.possible ? row('Possible, until they answer Lo (not shown to the student)', esc(f.possible)) : '') +
      row(guessing ? 'What the marking read (a guess until they answer Lo)' : 'The reasoning that produced it', esc(f.reasoning || '')) +
      row('The evidence, in their own writing', (f.evidence || []).map(function (e) { return '<div class="wd-step" style="opacity:1">' + esc(e) + '</div>'; }).join('')) +
      row('What they told Lo', said) +
      (f.ask ? row('Lo asks them first', esc(f.ask)) : '') +
      row('The intervention their level is built on', esc(f.intervention || '')) + '</div>';
  }

  // what Muse Wonder answered as each student, and where the misconception was caught (31 Oct, judges' panel)
  function playsOf(c) {
    var pl = c.plays || {}, holds = pl.holds || [], knows = pl.knows || [];
    if (!holds.length && !knows.length) return '';
    var rows = function (list) { return list.map(function (x) {
      return '<div class="wd-sub" style="margin:2px 0">' + (x.right ? '✓' : '✗') + ' Lesson ' + esc(x.lesson == null ? '?' : x.lesson) + ': ' + esc(x.check) + ' · answered ' + esc(x.answered) + '</div>'; }).join(''); };
    return '<div class="wd-cols" style="margin-top:6px"><div><b style="font-size:12px">Played as the student who still holds the idea</b>' + rows(holds) + '</div>' +
      '<div><b style="font-size:12px">Played as a student who has it right</b>' + rows(knows) + '</div></div>';
  }

  function masteryCard(q) {
    var released = S.paper && S.paper.status === 'released';
    var res = q.teacher_result || q.result;
    if (!released || !inPlan(res)) return '';
    var m = q.mastery || { status: 'not_started' };
    var asks = m.asks || {};
    var thread = (m.thread || []).map(function (t) {
      return '<div class="wd-sub" style="margin:4px 0"><b>' + (t.from === 'teacher' ? 'You' : esc(S.paper.student || 'Student')) + ':</b> ' + esc(t.text) +
        (t.where ? '<div class="wd-sub" style="margin-left:12px">Asked from ' + esc(t.where) + '</div>' : '') + '</div>';
    }).join('');
    var ex = m.explain || {};
    var lo = ex.lo ? '<div class="wd-card"><b>Explained to Lo' + (ex.lo.spoken ? ', out loud' : '') + '</b><div>' + esc(ex.lo.text) + '</div>' + listen(ex.lo.audio, 'Their explanation to Lo') +
      (ex.lo.verdict ? '<div class="wd-sub">' + (ex.lo.verdict.understood ? 'Lo: understood. ' : 'Lo: still working on it. ') + esc(ex.lo.verdict.why || '') + '</div>' : '') + '</div>' : '';
    var toMe = ex.teacher ? '<div class="wd-card"><b>Explained to you' + (ex.teacher.spoken ? ', out loud' : '') + '</b><div>' + esc(ex.teacher.text) + '</div>' + listen(ex.teacher.audio, 'Their explanation to you') + '</div>' : '';
    // 28 Oct re-audit (the plan's badge review: "the level activity and answers", "the AI's recommendation")
    var acts = (m.activity || []).map(function (a) {
      return '<div class="wd-sub" style="margin:2px 0">· ' + esc(a.title) + (a.asked != null && a.right != null ? ': ' + esc(a.right) + ' of ' + esc(a.asked) + ' right first time' : ': finished') + '</div>';
    }).join('');
    var activity = '<div style="margin-top:8px"><b style="font-size:12px">In the level</b>' + (acts || '<div class="wd-sub">No lesson finished yet.</div>') + '</div>';
    var rc = m.recommendation;
    var recommend = '<div class="wd-card" style="margin-top:8px"><b>Muse Spark recommends</b>' +
      (rc ? ' <span class="wd-chip ' + (rc.recommend === 'issue' ? 'ok' : '') + '">' + (rc.recommend === 'issue' ? 'Issue Turned around' : 'Keep going') + '</span><div>' + esc(rc.why || '') + '</div>' +
        (rc.missing ? '<div class="wd-sub">Would settle it: ' + esc(rc.missing) + '</div>' : '') : '<div class="wd-sub">Muse Spark weighs the level, the explanations and the fresh question. The decision is yours.</div>') +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="recommend">' + (rc ? 'Ask again' : 'What does Muse Spark recommend?') + '</button></div></div>';
    // the fresh question on paper, watched again: how it was worked, beside the result
    var fr = m.fresh || null, fq = fr && fr.question;
    var fresh = !fr ? '' : '<div class="wd-card"><b>The fresh question on paper</b>' +
      (fr.status === 'marked' && fq ? ' ' + chip(fq.result) + '<div class="wd-sub">' + esc(asks.fresh || '') + '</div>' +
        (fq.steps || []).map(function (st) { return '<div class="wd-step' + (st.crossed_out ? ' slip' : '') + '" style="opacity:1">' + esc(st.wrote) + '</div>'; }).join('') +
        (fq.diagnosis ? '<div class="wd-sub">' + esc(fq.diagnosis) + '</div>' : '')
      : '<div class="wd-sub">' + (fr.status === 'failed' ? 'The video could not be read. The student can film it again.' : fr.status === 'uploading' ? 'Not sent yet.' : 'Reading it now.') + '</div>') + '</div>';
    var box = function (k, label) { return '<label style="display:flex;gap:6px;align-items:center;color:var(--tx)"><input type="checkbox" data-ask="' + k + '"' + (asks[k] ? ' checked' : '') + ' style="width:auto"> ' + label + '</label>'; };
    var done = m.status === 'badge';
    // 29 Oct (owner): the badge replaces the level's certificate, so it opens once the level is finished (every lesson's
    // questions and the flashcards; the game is optional)
    var finished = !!m.completed_ms || m.status === 'completed';
    // the level's own self-check (Muse Wonder played it as both students); a level that still fails is the teacher's to know
    var chk = m.check ? (m.check.passes ? '<div class="wd-sub" style="margin-top:6px">Self-check: passed. Muse Wonder played the level as both students.</div>' + playsOf(m.check) :
      '<div class="wd-card" style="margin-top:8px;border-color:var(--warn)"><b>Self-check: still not right</b><div class="wd-sub">After its rewrites the level still had these. Look before you rely on it, or answer them in the thread.</div>' +
      (m.check.problems || []).map(function (p) { return '<div class="wd-sub" style="margin:3px 0">· ' + esc(p) + '</div>'; }).join('') +
      (m.check.false_claims || []).map(function (f) { return '<div class="wd-sub" style="margin:3px 0;color:var(--err)">Not true: ' + esc(f) + '</div>'; }).join('') + playsOf(m.check) + '</div>') : '';
    // 31 Oct (judges' panel): the re-check a few days after Turned around
    var rk = m.recheck;
    var recheck = !rk ? '' : '<div class="wd-card" style="margin-top:8px"><b>The re-check</b> ' +
      (rk.status === 'scheduled' ? '<span class="wd-chip">Due ' + esc(new Date(rk.due_ms || 0).toLocaleDateString()) + '</span> <button class="wd-btn" data-act="recheck">Send it now</button>' :
        rk.status === 'open' ? '<span class="wd-chip">With the student</span><div>' + esc(rk.q || '') + '</div>' :
        '<span class="wd-chip ' + (rk.status === 'passed' ? 'ok' : 'warn') + '">' + (rk.status === 'passed' ? 'Still right' : 'Needs one more look') + '</span><div>' + esc(rk.q || '') + '</div>' +
          (rk.reply ? '<div class="wd-sub">They answered ' + esc(rk.reply.value) + (rk.unit ? ' ' + esc(rk.unit) : '') + ' (right: ' + esc(rk.answer) + '): “' + esc(rk.reply.working || '') + '”</div>' +
            (rk.reply.verdict ? '<div class="wd-sub">Muse Spark: ' + (rk.reply.verdict.understood ? 'the working holds. ' : 'the working does not hold. ') + esc(rk.reply.verdict.why || '') + '</div>' : '') : '') +
          (rk.status === 'not_yet' ? '<div style="margin-top:6px"><button class="wd-btn" data-act="recheck">Send another re-check</button></div>' : '')) + '</div>';
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Mastery</h3></span>' +
      '<span class="wd-chip ' + (done ? 'ok' : '') + '">' + esc(STATUS[m.status] || m.status) + '</span></div>' + chk + recheck + levelOutline(m) +
      (thread ? '<div style="margin-top:8px"><b style="font-size:12px">Questions to you</b>' + thread + '</div>' : '') +
      '<label for="wdReply">Answer in the thread</label><input id="wdReply" data-f="reply" placeholder="Your answer to their question">' +
      '<div style="margin-top:6px"><button class="wd-btn" data-act="reply">Send</button></div>' +
      '<div style="margin-top:12px"><b style="font-size:12px">Ask for a check (only if you want one)</b>' +
      box('lo', 'Explain it back to Lo') + box('paper', 'A fresh question on paper, watched again') +
      '<input id="wdFresh" data-f="fresh" value="' + esc(S.draft.fresh != null ? S.draft.fresh : (asks.fresh || '')) + '" placeholder="The fresh question, for the same idea" aria-label="The fresh question">' +
      box('teacher', 'Explain it back to me') +
      '<button class="wd-btn" data-act="verify" style="margin-top:6px">Save checks</button></div>' + activity + lo + toMe + fresh + challengeCard(m) + (done ? '' : recommend) +
      '<label for="wdBadgeNote">A note with your decision</label><input id="wdBadgeNote" data-f="badgeNote" placeholder="You found the step that went wrong and explained why the right one works.">' +
      '<div style="margin-top:8px;display:flex;gap:8px;align-items:center">' + (done ? '<span class="wd-chip ok">Badge issued</span>' :
        (finished ? '<button class="wd-btn wd-main" data-act="badge">Issue Turned around</button>' :
          '<button class="wd-btn wd-main" disabled aria-disabled="true" style="opacity:.5;cursor:default">Issue Turned around</button>') +
        '<button class="wd-btn" data-act="notyet">Keep going</button>') + '</div>' +
      (done || finished ? '' : '<div class="wd-sub" style="margin-top:4px">The badge opens once they finish the level: every lesson\'s questions and the flashcards.</div>') + '</div>';
  }

  // the step written when the thinking went wrong: the last step finished at or before that second
  function nearMoment(q, i) {
    var at = -1;
    (q.steps || []).forEach(function (s, k) { if (s.t != null && s.t <= q.moment_s + 1) at = k; });
    if (at < 0) at = 0;
    return i === at;
  }
  function chip(r) { return '<span class="wd-chip ' + (TONE[r] || '') + '">' + esc(RESULT[r] || r || '') + '</span>'; }
  // going back to an earlier question after starting a later one, in the order it happened (28 Oct)
  function returnsLine(rs) {
    if (!rs.length) return '';
    return '<div class="wd-sub" style="margin-top:8px">' + rs.map(function (r) {
      return 'At ' + fmtT(r.at_s) + ' went back to ' + unit().toLowerCase() + ' ' + esc(r.to_q) + ' from ' + unit().toLowerCase() + ' ' + esc(r.from_q) + '.';
    }).join(' ') + '</div>';
  }
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
    if (e.target && e.target.id === 'wdRead' && e.type === 'change') return readFile(e.target.files && e.target.files[0]);
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
    if (act === 'delask') { S.draft.delAsk = t.getAttribute('data-what'); return render(); }
    if (act === 'delkeep') { S.draft.delAsk = ''; return render(); }
    if (act === 'delete') return deleteIt(t.getAttribute('data-what'));
    if (act === 'remark') return remark();
    if (act === 'save') return save();
    if (act === 'replay') return runPlay();
    if (act === 'draw') return draw();
    if (act === 'speak') return speak();
    if (act === 'proof') return openProof();
    if (act === 'print') { try { window.print(); } catch (e) { /* no printer */ } return; }
    if (act === 'verify') return masteryDo('verify', checks());
    if (act === 'reply') return masteryDo('reply', { text: S.draft.reply || '' });
    if (act === 'approve') return masteryDo('approve', {});
    if (act === 'recommend') { say('Muse Spark is weighing the evidence…'); render(); return masteryDo('recommend', {}); }
    if (act === 'chopen') { S.draft.chOpen = true; return render(); }
    if (act === 'chmore') { S.draft.chN = Math.min(5, (S.draft.chN || 3) + 1); return render(); }
    if (act === 'chsuggest') return suggestChallenge();
    if (act === 'challenge') {
      var cb = challengeBody();
      if (!cb.q || cb.options.length < 2 || cb.answer < 0) { say('Write the question, at least two options, and mark the right one.', 'err'); return render(); }
      return masteryDo('challenge', cb);
    }
    if (act === 'patterns') return patterns();
    if (act === 'nextexam') return nextExam();
    if (act === 'badge') return masteryDo('badge', { issue: true, note: S.draft.badgeNote || '' });
    if (act === 'notyet') return masteryDo('badge', { issue: false, note: S.draft.badgeNote || '' });
    if (act === 'whose') return whose({ uid: S.draft.whose || ((document.querySelector('#lowisaWitnessDesk [data-f="whose"]') || {}).value) || '' });
    if (act === 'whosename') return whose({ name: S.draft.whoseName || '' });
    // 31 Oct (judges' panel)
    if (act === 'unroster') return pileDo('roster/remove', { uid: t.getAttribute('data-uid') }, 'Taken off the class list.');
    if (act === 'joining') return pileDo('joining', { open: t.getAttribute('data-open') === '1' }, t.getAttribute('data-open') === '1' ? 'Joining is open again.' : 'Joining is closed.');
    if (act === 'acceptsure') {
      var sure = ((S.pile && S.pile.queue) || []).filter(function (it) { return it.result === 'mastered' && (it.confidence || 0) >= 0.9; });
      return pileDo('bulk', { action: 'accept', items: sure.map(function (it) { return { sitting: it.sitting, n: it.n }; }) }, 'Accepted ' + sure.length + ' as marked.');
    }
    if (act === 'readybadge') {
      var ready = (S.pile && S.pile.ready) || [];
      var ticked = ready.filter(function (r, i) { var b = document.querySelector('#lowisaWitnessDesk [data-ready="' + i + '"]'); return !b || b.checked; });
      return pileDo('bulk', { action: 'badge', note: 'Turned around', items: ticked.map(function (r) { return { sitting: r.sitting, n: r.n }; }) }, 'Turned around issued for ' + ticked.length + '.');
    }
    if (act === 'groupopen') { S.draft.groupOpen = Number(t.getAttribute('data-g')); return render(); }
    if (act === 'groupdraft') return groupDraft(Number(t.getAttribute('data-g')));
    if (act === 'groupsend') return groupSend(Number(t.getAttribute('data-g')));
    if (act === 'recheck') return masteryDo('recheck_now', {});
    if (t.hasAttribute('data-pile')) { if (await loadPile(t.getAttribute('data-pile'))) { S.view = 'pile'; } return render(); }
    if (t.hasAttribute('data-paper')) {
      var n = t.getAttribute('data-n');
      if (await loadPaper(t.getAttribute('data-paper'))) { S.view = 'paper'; S.n = n != null ? Number(n) : null; S.draft = {}; S.play = { pending: true }; stopPoll(); watchPaper(); }
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
    say(action === 'badge' ? (body.issue ? 'Badge issued: Turned around.' : 'Sent: keep going, with your note.') : action === 'verify' ? 'Checks saved. The student sees only these.' :
        action === 'recommend' ? 'Muse Spark recommends; the decision is yours.' : action === 'approve' ? 'The level reaches the student now.' :
        action === 'challenge' ? 'Challenge sent. It is on their phone now.' : 'Sent.');
    render();
  }

  // whose a photographed paper is: a student on the class list, or a name (29 Oct)
  async function whose(body) {
    if (!S.sid || (!body.uid && !String(body.name || '').trim())) { say('Choose a student or type a name.', 'err'); return render(); }
    S.busy = true;
    var j = await api('POST', '/api/witness/sitting/' + S.sid + '/student', body);
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    if (S.pid) await loadPile(S.pid);
    await loadPaper(S.sid);
    S.draft = {};
    say(j.paper && j.paper.linked ? 'This paper is with ' + (j.paper.student || 'the student') + ' now: their marks and Mastery Plan reach their phone.' :
        'Saved as ' + ((j.paper && j.paper.student) || 'that name') + '. Print their Proof of Thinking record for them: it holds their Mastery Plan questions.');
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
        (ans ? '<div>' + (ans.spoken ? 'Said: ' : 'Wrote: ') + '<i>' + esc(ans.text) + '</i></div>' + listen(ans.audio, 'Their answer, as they said it') +
          (v ? '<div class="wd-sub">' + (v.own_work ? '<span class="wd-chip ok">Their own reasoning</span> ' : '<span class="wd-chip err">Not clearly their own</span> ') +
            (v.understood ? '<span class="wd-chip ok">Understands it now</span> ' : '<span class="wd-chip">Still working on it</span> ') + esc(v.why || '') + '</div>' : '')
          : '<div class="wd-sub">Not answered yet.</div>') + '</div>';
    }).join('');
    return '<div class="wd-card"><h3>The examiner\'s questions</h3><div class="wd-sub">Muse Wonder asked about steps the student wrote; they answered out loud or in writing.</div>' + rows + '</div>';
  }
  function stillOf(q) {
    var st = ((S.paper && S.paper.result && S.paper.result.stills) || []).filter(function (x) { return x.n === q.n; })[0];
    if (!st) return '';
    // a photographed paper: the answer as written on the page, and the student's own step cut from it
    if (st.t == null) return '<div style="margin-top:10px">' +
      (st.asset ? '<b style="font-size:12px">The answer on the paper' + (st.page ? ', page ' + esc(st.page) : '') + '</b><img data-asset="' + esc(st.asset) + '" alt="Question ' + esc(q.n) + ' as written on the paper" style="display:block;width:100%;max-width:520px;border-radius:8px;margin-top:4px;background:var(--nb-paper);min-height:60px">' : '') +
      (st.step && inPlan(q.teacher_result || q.result) ? '<div class="wd-sub" style="margin-top:8px">The student\'s own step, as their Mastery Plan opens on it</div><img data-asset="' + esc(st.step) + '" alt="The student\'s own step for question ' + esc(q.n) + '" style="display:block;max-width:420px;border-radius:8px;margin-top:4px;background:var(--nb-paper);min-height:40px">' : '') + '</div>';
    return '<div style="margin-top:10px"><b style="font-size:12px">The desk at ' + fmtT(st.t) + '</b><img data-asset="' + esc(st.asset) + '" alt="The desk at ' + fmtT(st.t) + ', question ' + esc(q.n) + '" style="display:block;width:100%;max-width:420px;border-radius:8px;margin-top:4px;background:var(--nb-paper);min-height:60px">' +
      // six seconds of the desk around the moment, kept once the video is deleted (28 Oct re-audit)
      (st.clip ? '<div class="wd-sub" style="margin-top:6px">The moment itself, six seconds</div><video data-asset="' + esc(st.clip) + '" controls muted playsinline preload="metadata" aria-label="Six seconds of the desk around ' + fmtT(st.t) + '" style="display:block;width:100%;max-width:420px;border-radius:8px;margin-top:4px;background:var(--term-black)"></video>' : '') + '</div>';
  }
  function drawnCard(q) {
    var res = q.teacher_result || q.result;
    if (res === 'mastered' && !q.drawn) return '';
    var d = q.drawn || {};
    var inner = d.status === 'done' ? '<img data-asset="' + esc(d.asset) + '" alt="The corrected working: ' + esc((d.lines || []).join(', ')) + '" style="display:block;width:100%;max-width:420px;border-radius:8px;background:var(--nb-paper);min-height:60px">' +
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
    Array.prototype.forEach.call(p.querySelectorAll('img[data-asset],video[data-asset],audio[data-asset]'), function (img) {
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
        (q.diagnosis ? '<div class="wd-diag"><b>' + (q.moment_s != null ? 'At ' + fmtT(q.moment_s) : 'What the working shows') + '</b><div>' + esc(q.diagnosis) + '</div></div>' : '') +
        ((q.capabilities || []).length && inPlan(q.teacher_result || q.result) ? '<div class="wd-sub" style="margin-top:6px"><b>Thinking it builds:</b> ' + q.capabilities.map(function (c) { return esc(c) + (CAPS[c] ? ' (' + esc(CAPS[c]) + ')' : ''); }).join('; ') + '</div>' : '') +
        (q.still ? '<img data-asset="' + esc(q.still) + '" alt="' + (p.source === 'photo' ? 'The answer on the paper' : 'The desk') + ', question ' + esc(q.n) + '" style="display:block;width:100%;max-width:360px;border-radius:8px;margin-top:8px">' : '') +
        (q.clip ? '<video data-asset="' + esc(q.clip) + '" controls muted playsinline preload="metadata" aria-label="Six seconds of the desk, question ' + esc(q.n) + '" style="display:block;width:100%;max-width:360px;border-radius:8px;margin-top:6px;background:var(--term-black)"></video>' : '') +
        (q.turned_around ? '<div style="margin-top:6px"><span class="wd-chip ok">Turned around</span> <span class="wd-sub">' + esc(day(q.turned_around.from_ms)) + ' to ' + esc(day(q.turned_around.at)) +
          (q.turned_around.note ? ' · ' + esc(q.turned_around.note) : '') + '. Counted as mastered.</span></div>' : '') +
        (q.comment ? '<div style="margin-top:6px"><b>Teacher:</b> ' + esc(q.comment) + '</div>' : '') + '</div>';
    }).join('');
    var asks = (p.examiner || []).map(function (a) {
      var v = a.answer && a.answer.verdict;
      return '<div style="margin-top:8px"><b>Q' + esc(a.n) + ':</b> ' + esc(a.ask) + '<div>' + (a.answer ? esc(a.answer.text) : '<span class="wd-sub">Not answered.</span>') + '</div>' + listen(a.answer && a.answer.audio, 'Their answer, as they said it') +
        (v ? '<div class="wd-sub">' + (v.own_work ? 'Their own reasoning. ' : 'Not clearly their own. ') + (v.understood ? 'Understands it now. ' : '') + esc(v.why || '') + '</div>' : '') + '</div>';
    }).join('');
    return '<div class="wd-card"><div class="wd-row" style="cursor:default;padding:0"><span class="wd-grow"><h3 style="margin:0">Proof of Thinking</h3>' +
      '<div class="wd-sub">' + esc(p.exam || '') + (p.level ? ' · ' + esc(p.level) : '') + ' · ' + esc(p.student || '') + ' · sat ' + esc(day(p.sat_ms)) + ' · ' + num(p.marks) + ' of ' + num(p.out_of) + ' marks' +
        (p.mastered != null ? ' · ' + esc(p.mastered) + ' of ' + esc((p.questions || []).length) + ' mastered' + (p.turned_around ? ' (' + esc(p.turned_around) + ' turned around)' : '') : '') + '</div></span>' +
      '<button class="wd-btn" data-act="print">Print</button></div></div>' + qs +
      (asks ? '<div class="wd-card"><h3>The examiner\'s questions</h3>' + asks + '</div>' : '') +
      returnsLine(p.returns || []) +
      '<div class="wd-sub" style="margin:8px 2px">Marked by ' + esc(p.engine || '') + '. Read by ' + esc((p.read_by || []).join(', ')) + '. ' +
      (p.source === 'photo' ? 'Photographed after the exam: ' + esc(p.pages) + ' page' + (p.pages === 1 ? '' : 's') + ', kept with the paper.' : 'Filmed at the desk; the video was ' + esc(p.video || '') + '.') + '</div>';
  }
  function measured() {
    var m = S.measure; if (!m || !m.marked) return '';
    var pct = m.agreement == null ? '—' : Math.round(m.agreement * 100) + '%';
    var secs = function (x) { return x && x.n ? Math.round(x.median) + ' s' : '—'; };
    // 31 Oct (judges' panel: dashes and zeros read as broken): a tile only for what was measured
    var rk = m.rechecks || {};
    var tiles = [m.reviewed ? '<div><b>' + pct + '</b>you agreed with Muse Spark (' + m.teacher_agreed + ' of ' + m.reviewed + ' reviewed)</div>' : '',
      m.wrong_thinking_caught ? '<div><b>' + m.wrong_thinking_caught + '</b>right answers by wrong thinking caught</div>' : '',
      m.marking_seconds && m.marking_seconds.n ? '<div><b>' + secs(m.marking_seconds) + '</b>to mark a paper (median)</div>' : '',
      m.teacher_seconds_per_paper && m.teacher_seconds_per_paper.n ? '<div><b>' + secs(m.teacher_seconds_per_paper) + '</b>of your time per paper (median)</div>' : '',
      m.examiner_asks ? '<div><b>' + m.examiner_answered + ' / ' + m.examiner_asks + '</b>examiner questions answered</div>' : '',
      m.turned_around ? '<div><b>' + m.turned_around + '</b>turned around</div>' : '',
      (rk.passed || rk.not_yet) ? '<div><b>' + (rk.passed || 0) + ' / ' + ((rk.passed || 0) + (rk.not_yet || 0)) + '</b>still right on the re-check</div>' : ''].join('');
    if (!tiles) return '';
    return '<div class="wd-card"><h3>Measured on this exam</h3><div class="wd-nums">' + tiles + '</div>' +
      ((m.changed_by_teacher || []).length ? '<div class="wd-sub">You changed: ' + m.changed_by_teacher.map(function (c) { return 'Q' + c.n + ' ' + (RESULT[c.witness] || c.witness) + ' → ' + (RESULT[c.teacher] || c.teacher); }).join('; ') + '</div>' : '') + '</div>';
  }

  // a recording the student made, kept with the paper for the teacher (owner, 28 Oct)
  function listen(file, label) {
    return file ? '<audio data-asset="' + esc(file) + '" controls preload="none" aria-label="' + esc(label) + '" style="display:block;width:100%;max-width:360px;margin-top:4px"></audio>' : '';
  }
  async function readFile(file) {
    if (!file) return;
    if (file.size > 10 * 1024 * 1024) { say('That file is over 10 MB. Try a smaller photo or fewer pages.', 'err'); return render(); }
    S.reading = true; render();
    var b64 = await new Promise(function (ok) { var fr = new FileReader(); fr.onload = function () { ok(String(fr.result).split(',')[1] || ''); }; fr.onerror = function () { ok(''); }; fr.readAsDataURL(file); });
    var j = await api('POST', '/api/witness/pile/read', { file: b64, mime: file.type });
    S.reading = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    var d = S.draft;
    if (j.title && !String(d.title || '').trim()) d.title = j.title;
    if (j.level && !String(d.level || '').trim()) d.level = j.level;
    // the paper's own "(2 marks)" is the mark already: kept once (29 Oct, film take: "(2 marks) (2)")
    if ((j.questions || []).length) d.qs = j.questions.map(function (q) {
      var text = String(q.text || '').replace(/\s*\(\s*(\d+)\s*marks?\s*\)\s*$/i, function (all, n) { return Number(n) === Number(q.marks) ? '' : all; });
      return q.n + '. ' + text + ' (' + q.marks + ')';
    }).join('\n');
    // each question's rule on its own line, as a scheme is written
    if (j.scheme) d.scheme = String(j.scheme).replace(/\s+(Q\d+\s*[:.)])/g, '\n$1').trim();
    say('Read ' + (j.questions || []).length + ' question' + ((j.questions || []).length === 1 ? '' : 's') + (j.scheme ? ' and your scheme' : '') + '. Check them, then create the exam.');
    render();
  }
  async function patterns() {
    S.busy = true;
    var j = await api('POST', '/api/witness/pile/' + S.pid + '/patterns', {});
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    await loadPile(S.pid);
    say('Muse Wonder is reading the whole class. It takes about half a minute.');
    render();
  }
  function nextExam() {
    var pl = (S.pile && S.pile.pile) || {}, pt = pl.patterns || {};
    S.draft = { title: (pl.title || 'Exam') + ' (next)', level: pl.level || '', kind: pl.kind || 'paper',
                qs: (pt.next_exam || []).map(function (x, i) { return (i + 1) + '. ' + x.text + ' (' + x.marks + ')'; }).join('\n') };
    stopPoll(); S.view = 'new'; render();
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
    var j = await api('POST', '/api/witness/pile', { title: d.title, level: d.level || '', questions: questionsOf(d.qs), scheme: d.scheme || '', kind: d.kind === 'practical' ? 'practical' : 'paper', engine: d.engine === 'open' ? 'open' : 'meta', preview: d.preview !== 'no' });
    S.busy = false;
    if (!j.ok) { say(errText(j), 'err'); return render(); }
    S.draft = {};
    if (await loadPile(j.id)) S.view = 'pile';
    say('Exam created. Students join with the code ' + (j.code || '') + ' to put their name on the class list; after the exam, photograph each paper from the LoWisa phone app with the photographing code ' + (j.photo_code || '') + '.');
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
