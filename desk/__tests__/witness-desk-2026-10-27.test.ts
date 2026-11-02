// @vitest-environment jsdom
/**
 * WITNESS (2026-10-27, Meta hackathon): the Exam Desk (26-witness-desk.js, synced from lowisa-witness) and its doors
 * (witness-ipc.ts; the edge is lowisa_edge_witness, tested in lowisa_edge_witness_tests).
 *  1. witness-ipc.ts: only the desk's doors pass main's allowlist; a call before hello said "on" is refused, no fetch.
 *  2. Off (hello is not on): no command, nothing drawn.
 *  3. On: the desk opens below the 38 px title bar, lists the exams, a new exam is sent with its questions parsed,
 *     an exam shows its papers and the review queue in the edge's order, a paper shows the steps and the diagnosis,
 *     the teacher's result, marks and focus note are saved, release says how many papers went out; Esc goes one step
 *     up and closes from the list.
 * No network: the seam is a stub.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { registerWitnessIPC, witnessDoor } from '../main/witness-ipc';

const DESK = fs.readFileSync(path.resolve(__dirname, '..', 'renderer-parts', '26-witness-desk.js'), 'utf8');
const flush = async (n = 15) => { for (let i = 0; i < n; i++) await new Promise((r) => setTimeout(r, 0)); };
const P = '0123456789abcdef';
const S1 = 'aaaaaaaaaaaaaaaa';

describe('witness-ipc doors', () => {
  it('lets only the desk doors through', () => {
    expect(witnessDoor('GET', '/api/witness/piles')).toEqual({ method: 'GET', path: '/api/witness/piles' });
    expect(witnessDoor('POST', '/api/witness/pile')).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/pile/${P}`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/release`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/sitting/${S1}/review`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/badge`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/12/verify`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/explain`)).toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/d/reply`)).toBeNull();
    // the phone's doors and anything else stay shut on the desktop
    expect(witnessDoor('POST', '/api/witness/sitting/start')).toBeNull();
    expect(witnessDoor('POST', `/api/witness/sitting/${S1}/mark`)).not.toBeNull();   // Mark again (28 Oct)
    expect(witnessDoor('GET', '/api/classroom/hello')).toBeNull();
    expect(witnessDoor('GET', `/api/witness/pile/${P}/../../credits`)).toBeNull();
    expect(witnessDoor('DELETE', `/api/witness/pile/${P}`)).toBeNull();
    // 31 Oct (judges' panel): the class list, joining, one action on many questions, the re-check; never the phone's
    // model door or a student's own steps
    expect(witnessDoor('POST', `/api/witness/pile/${P}/bulk`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/joining`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/roster/remove`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/recheck_now`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/recheck_answer`)).toBeNull();
    expect(witnessDoor('POST', '/api/witness/design')).toBeNull();
    expect(witnessDoor('POST', '/api/witness/check')).toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/roster/remove/x`)).toBeNull();
  });

  it('refuses a call before hello said on, and asks the edge with the account token after', async () => {
    const handlers: Record<string, (e: unknown, r: any) => Promise<any>> = {};
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify({ ok: true, piles: [] }), { status: 200 }));
    registerWitnessIPC({ handle: (ch: string, fn: any) => { handlers[ch] = fn; } } as any,
                       { token: async (u: string) => (u === 'u1' ? 'tok-1' : null), fetchImpl: fetchImpl as any, env: { CREDIT_BACKEND_URL: 'https://edge.example.com' } as any });
    const before = await handlers['witness:call'](null, { userId: 'u1', method: 'GET', path: '/api/witness/piles' });
    expect(before.json.code).toBe('off');
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(await handlers['witness:hello'](null, { userId: 'u1' })).toEqual({ on: true });
    const auth = (fetchImpl.mock.calls[0] as any)[1].headers.authorization;
    expect(auth).toBe('Bearer tok-1');
    const no = await handlers['witness:call'](null, { userId: 'u1', method: 'POST', path: '/api/witness/sitting/start', body: {} });
    expect(no.json.code).toBe('not_a_door');
    expect(await handlers['witness:hello'](null, { userId: 'nobody' })).toEqual({ on: false });
  });
});

type Answer = { status?: number; json: Record<string, unknown> };

describe('the Exam Desk', () => {
  let calls: Array<{ method: string; path: string; body?: any }>;
  let answers: Record<string, Answer>;
  let on: boolean;
  let commands: Array<{ id: string; run: () => void }>;

  const boot = async () => {
    (window as any).__lowisaWitnessIpc = {
      hello: vi.fn(async () => ({ on })),
      call: vi.fn(async (r: any) => { calls.push({ method: r.method, path: r.path, body: r.body }); const a = answers[r.method + ' ' + r.path] || { json: { ok: false, error: 'no answer' } }; return { status: a.status || 200, json: a.json }; }),
    };
    (window as any).__lowisaRegisterCommand = (c: any) => commands.push(c);
    localStorage.setItem('lowisa-user-id', 'u1');
    new Function(DESK)();
    await flush();
  };
  const desk = () => document.getElementById('lowisaWitnessDesk');
  const click = async (sel: string) => { (desk()!.querySelector(sel) as HTMLElement).click(); await flush(); };

  beforeEach(() => {
    calls = []; commands = []; on = true;
    document.body.innerHTML = '';
    answers = {
      'GET /api/witness/piles': { json: { ok: true, piles: [{ id: P, title: 'Fractions quiz', papers: 2, released: false }] } },
      [`GET /api/witness/pile/${P}`]: { json: { ok: true, pile: { id: P, title: 'Fractions quiz' },
        sittings: [{ id: S1, student: 'Amara', status: 'marked', marks: 2, out_of: 3, to_master: 1, to_review: 3 }],
        queue: [{ sitting: S1, student: 'Amara', n: 3, result: 'right_answer_wrong_thinking', confidence: 0.9, diagnosis: 'Cancelled the 6s.' },
                { sitting: S1, student: 'Amara', n: 1, result: 'mastered', confidence: 0.95, diagnosis: '' }] } },
      [`GET /api/witness/sitting/${S1}`]: { json: { ok: true, id: S1, status: 'marked', student: 'Amara', result: { questions: [
        { n: 1, result: 'mastered', marks: 1, out_of: 1, confidence: 0.95, steps: [{ t: 7, wrote: '3/4 ÷ 1/2 = 3/8', crossed_out: true }, { t: 15, wrote: '= 3/2', crossed_out: false }], diagnosis: '', moment_s: null },
        { n: 3, result: 'right_answer_wrong_thinking', marks: 0, out_of: 1, confidence: 0.9, final_answer: '1/4',
          steps: [{ t: 33, wrote: '16/64', crossed_out: false }, { t: 38, wrote: '= 1/4', crossed_out: false }], diagnosis: 'Cancelled the 6s.', moment_s: 35 }],
        returns: [{ to_q: 1, from_q: 3, at_s: 63 }] } } },
      [`POST /api/witness/sitting/${S1}/review`]: { json: { ok: true, question: {} } },
      [`POST /api/witness/pile/${P}/release`]: { json: { ok: true, released: 1 } },
      'POST /api/witness/pile': { json: { ok: true, id: P } },
    };
  });
  afterEach(() => { (window as any).__lowisaWitnessDesk?.close?.(); });

  it('adds nothing when the edge says off', async () => {
    on = false;
    await boot();
    expect(commands).toEqual([]);
    expect(desk()).toBeNull();
    expect(calls).toEqual([]);
  });

  it('opens below the title bar, reviews a paper, saves the teacher word and releases', async () => {
    await boot();
    expect(commands.map((c) => c.id)).toEqual(['witness.open']);
    await (window as any).__lowisaWitnessDesk.open();
    await flush();
    expect(document.getElementById('lowisaWitnessCss')!.textContent).toContain('#lowisaWitnessDesk{position:fixed;top:38px');
    expect(desk()!.textContent).toContain('Fractions quiz');
    // the exam: papers and the queue in the edge's order
    await click(`[data-pile="${P}"]`);
    const queue = Array.from(desk()!.querySelectorAll('[data-n]')).map((e) => e.getAttribute('data-n'));
    expect(queue).toEqual(['3', '1']);
    expect(desk()!.textContent).toContain('Mastery Plan: right answer, wrong thinking');
    // a question from the queue: its steps, the crossed-out step, the diagnosis at its moment
    await click('[data-n="3"]');
    expect(desk()!.textContent).toContain('16/64');
    expect(desk()!.textContent).toContain('Where the thinking went wrong (0:35)');
    expect(desk()!.textContent).toContain('At 1:03 went back to question 1 from question 3.');   // 28 Oct
    expect(desk()!.querySelectorAll('.wd-step.slip').length).toBe(1);
    // the teacher's word
    const sel = desk()!.querySelector('#wdRes') as HTMLSelectElement; sel.value = 'not_yet'; sel.dispatchEvent(new Event('change', { bubbles: true }));
    const marks = desk()!.querySelector('#wdMarks') as HTMLInputElement; marks.value = '0'; marks.dispatchEvent(new Event('input', { bubbles: true }));
    const focus = desk()!.querySelector('#wdFocus') as HTMLTextAreaElement; focus.value = 'Common factors, not digits'; focus.dispatchEvent(new Event('input', { bubbles: true }));
    await click('[data-act="save"]');
    const saved = calls.find((c) => c.path === `/api/witness/sitting/${S1}/review`)!;
    expect(saved.body).toMatchObject({ n: 3, result: 'not_yet', marks: 0, focus: 'Common factors, not digits' });
    expect(typeof saved.body.desk_s).toBe('number');          // the seconds this paper was open: the pilot's time per paper
    expect(saved.body.comment).toBeUndefined();
    // Esc goes up to the exam, which is read again: a paper sent meanwhile shows (28 Oct, live), then release
    answers[`GET /api/witness/pile/${P}`].json.sittings = [...(answers[`GET /api/witness/pile/${P}`].json.sittings as any[]),
      { id: 'bbbbbbbbbbbbbbbb', student: 'Baraka', status: 'marked', marks: 2, out_of: 6, to_master: 2, to_review: 3 }];
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await flush();
    expect(desk()!.textContent).toContain('Baraka');
    await click('[data-act="release"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/pile/${P}/release`)).toBe(true);
    expect(desk()!.textContent).toContain('1 paper released to students.');
    // Esc twice more: to the list, then closed
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); await flush();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); await flush();
    expect(desk()).toBeNull();
  });

  // 30 Oct (film take): a paper photographed after the exam was released stayed "marked", and the button was gone
  it('releases a paper that arrives after the exam was released', async () => {
    const pile = answers[`GET /api/witness/pile/${P}`].json as any;
    pile.pile.released_ms = 5;
    pile.sittings = [{ id: S1, student: 'Amara', status: 'released', marks: 2, out_of: 3, to_master: 1 },
                     { id: 'bbbbbbbbbbbbbbbb', student: 'Baraka', status: 'marked', marks: 1, out_of: 3, to_master: 2 }];
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush(40);
    expect(desk()!.textContent).toContain('Release 1 new paper');
    expect(desk()!.textContent).toContain('The rest are released');
    await click('[data-act="release"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/pile/${P}/release`)).toBe(true);
    // all released: only the chip
    pile.sittings[1].status = 'released';
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush(40);
    expect(desk()!.querySelector('[data-act="release"]')).toBeNull();
    expect(desk()!.textContent).toContain('Released to students');
  });

  it('shows a released question mastery (a self-check that still fails, the thread, Lo verdict); the teacher answers, asks for a check and issues the badge', async () => {
    const q3 = (answers[`GET /api/witness/sitting/${S1}`].json.result as any).questions[1];
    answers[`GET /api/witness/sitting/${S1}`].json.status = 'released';
    q3.teacher_result = 'not_yet';
    q3.mastery = { status: 'completed', path: 'custom-topic-x',
      check: { passes: false, problems: ['lesson 2: the checks are all lucky cancels'] },
      thread: [{ from: 'student', text: 'Why does 12/24 not work?', at: 1 }],
      explain: { lo: { text: 'Digits are not factors.', at: 2, verdict: { understood: false, why: 'Says the rule, not the reason.' } } },
      asks: { lo: true, paper: true, teacher: false, fresh: 'Simplify 12/48' },
      fresh: { sitting: 'f1', status: 'marked', question: { n: 1, result: 'mastered', steps: [{ t: 3, wrote: '12/48 = 1/4 (both by 12)', crossed_out: false }], diagnosis: '' } } };
    const M = (a: string) => `POST /api/witness/mastery/${S1}/3/${a}`;
    for (const a of ['reply', 'verify', 'badge']) answers[M(a)] = { json: { ok: true, mastery: q3.mastery } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    const text = desk()!.textContent!;
    expect(text).toContain('Self-check: still not right');
    expect(text).toContain('lesson 2: the checks are all lucky cancels');
    expect(text).toContain('Amara: Why does 12/24 not work?');
    expect(text).toContain('Lo: still working on it. Says the rule, not the reason.');
    const reply = desk()!.querySelector('#wdReply') as HTMLInputElement; reply.value = 'Try dividing both by 12.'; reply.dispatchEvent(new Event('input', { bubbles: true }));
    await click('[data-act="reply"]');
    expect(calls.find((c) => c.path.endsWith('/3/reply'))!.body).toEqual({ text: 'Try dividing both by 12.' });
    expect(desk()!.textContent).toContain('The fresh question on paper');
    expect(desk()!.textContent).toContain('12/48 = 1/4 (both by 12)');
    (desk()!.querySelector('[data-ask="lo"]') as HTMLInputElement).checked = false;
    (desk()!.querySelector('#wdFresh') as HTMLInputElement).value = 'Simplify 15/45';
    await click('[data-act="verify"]');
    expect(calls.find((c) => c.path.endsWith('/3/verify'))!.body).toEqual({ lo: false, paper: true, teacher: false, fresh: 'Simplify 15/45' });
    await click('[data-act="badge"]');
    expect(calls.find((c) => c.path.endsWith('/3/badge'))!.body).toEqual({ issue: true, note: '' });
    expect(desk()!.textContent).toContain('Badge issued: Turned around.');
  });

  // 29 Oct, live: a finished lesson and the finished level showed only after the paper was reopened
  it("keeps an open paper's mastery current, never under the teacher's typing", async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
    try {
      const sit = answers[`GET /api/witness/sitting/${S1}`].json as any;
      sit.status = 'released';
      const q3 = sit.result.questions[1];
      q3.mastery = { status: 'ready', path: 'custom-topic-x', activity: [] };
      await boot();
      await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
      expect(desk()!.textContent).toContain('No lesson finished yet.');
      expect((desk()!.querySelector('[data-act="badge"]') as HTMLButtonElement | null)).toBeNull();
      const next = JSON.parse(JSON.stringify(sit));
      next.result.questions[1].mastery = { status: 'completed', path: 'custom-topic-x', completed_ms: 5, activity: [{ title: 'Fix the cancel', asked: 6, right: 6 }] };
      answers[`GET /api/witness/sitting/${S1}`] = { json: next };
      // the teacher is typing a note: the card waits
      const note = desk()!.querySelector('#wdBadgeNote') as HTMLInputElement; note.focus();
      vi.advanceTimersByTime(6000); await flush();
      expect(desk()!.textContent).toContain('No lesson finished yet.');
      note.blur();
      vi.advanceTimersByTime(6000); await flush();
      expect(desk()!.textContent).toContain('Fix the cancel: 6 of 6 right first time');
      expect((desk()!.querySelector('[data-act="badge"]') as HTMLButtonElement)).not.toBeNull();
      // the question list and the rest of the paper are not redrawn
      expect(desk()!.querySelector('[data-q="3"]')!.className).toContain('on');
      // back on the exam, the paper stops asking
      await click('[data-act="back"]');
      const before = calls.filter((c) => c.path === `/api/witness/sitting/${S1}`).length;
      vi.advanceTimersByTime(18000); await flush();
      expect(calls.filter((c) => c.path === `/api/witness/sitting/${S1}`).length).toBe(before);
    } finally { vi.useRealTimers(); }
  });

  // 28 Oct audit: the plan's step 4, the teacher looks at each level first when the exam says so
  it('shows a held level to the teacher and lets the student start', async () => {
    const q3 = (answers[`GET /api/witness/sitting/${S1}`].json.result as any).questions[1];
    answers[`GET /api/witness/sitting/${S1}`].json.status = 'released';
    q3.teacher_result = 'not_yet';
    q3.mastery = { status: 'held', path: 'p1', level: { title: 'Cancel Factors Right', lessons: [{ title: 'Price the boots sale', beats: ['Half price: 32/64'] }] } };
    answers[`POST /api/witness/mastery/${S1}/3/approve`] = { json: { ok: true, mastery: { ...q3.mastery, status: 'ready' } } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    expect(desk()!.textContent).toContain('Level made: waiting for you to look');
    expect(desk()!.textContent).toContain('Lesson 1: Price the boots sale');
    q3.mastery = { ...q3.mastery, status: 'ready' };
    await click('[data-act="approve"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/mastery/${S1}/3/approve`)).toBe(true);
    expect(desk()!.querySelector('[data-act="approve"]')).toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/approve`)).not.toBeNull();
  });

  // 3 Nov (judges' panel, the teacher of forty): the exam lists its held levels; those whose self-check passed start together
  it('lets every held level whose self-check passed start at once, and lists the others to open one by one', async () => {
    const pile = answers[`GET /api/witness/pile/${P}`].json as any;
    pile.held = [{ sitting: S1, student: 'Amara', n: 3, idea: 'Cancelled the 6s.', passed: true },
                 { sitting: S1, student: 'Amara', n: 4, idea: 'Added the bottoms.', passed: true },
                 { sitting: S1, student: 'Kofi', n: 2, idea: 'Divided by the percent.', passed: false }];
    answers[`POST /api/witness/pile/${P}/bulk`] = { json: { ok: true, done: 2, results: [{ result: 'ok' }, { result: 'ok' }] } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush();
    expect(desk()!.textContent).toContain('Levels waiting for you: 3');
    expect(desk()!.textContent).toContain('Let all 2 start');
    expect(desk()!.textContent).toContain('Self-check still not right, open each on its own');
    await click('[data-act="startall"]');
    const bulk = calls.find((c) => c.method === 'POST' && c.path === `/api/witness/pile/${P}/bulk`)!;
    expect(bulk.body).toEqual({ action: 'approve', items: [{ sitting: S1, n: 3 }, { sitting: S1, n: 4 }] });
    expect(desk()!.textContent).toContain('2 levels reach their students now.');
    // an exam whose server sends no list (before that server's release) shows no card
    delete pile.held; await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush();
    expect(desk()!.querySelector('[data-act="startall"]')).toBeNull();
  });

  // 28 Oct, live: a level whose news reached the edge late came without its outline, and the button lived in the outline
  it('lets the student start a held level that came without its outline', async () => {
    const q3 = (answers[`GET /api/witness/sitting/${S1}`].json.result as any).questions[1];
    answers[`GET /api/witness/sitting/${S1}`].json.status = 'released';
    q3.teacher_result = 'not_yet';
    q3.mastery = { status: 'held', path: 'p1' };
    answers[`POST /api/witness/mastery/${S1}/3/approve`] = { json: { ok: true, mastery: { ...q3.mastery, status: 'ready' } } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    expect(desk()!.textContent).toContain('Its outline did not come with it.');
    q3.mastery = { ...q3.mastery, status: 'ready' };
    await click('[data-act="approve"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/mastery/${S1}/3/approve`)).toBe(true);
  });

  it('shows the examiner, draws the corrected step, keeps the comment, opens the record and the measured numbers', async () => {
    const sit = answers[`GET /api/witness/sitting/${S1}`].json as any;
    sit.examiner = { status: 'ready', asks: [{ k: 1, n: 3, ask: 'You wrote 16/64 = 1/4. Why did you cross out the 6s?', wrote: '16/64',
      answer: { text: 'Because both have a 6.', spoken: true, verdict: { own_work: true, understood: false, why: 'Says the digit rule, not a factor.' } } }] };
    sit.result.stills = [{ n: 3, t: 35, asset: 'still-3.jpg' }];
    sit.result.questions[1].drawn = { status: 'done', asset: 'drawn-3.webp', lines: ['16/64', '= 1/4 (divide by 16)'], changed: 2 };
    answers[`GET /api/witness/sitting/${S1}/asset/still-3.jpg`] = { json: { ok: true, url: 'https://s3.example/still' } };
    answers[`GET /api/witness/sitting/${S1}/asset/drawn-3.webp`] = { json: { ok: true, url: 'https://s3.example/drawn' } };
    answers[`POST /api/witness/sitting/${S1}/draw`] = { json: { ok: true, n: 3, drawn: { status: 'drawing' } } };
    answers[`GET /api/witness/pile/${P}/measure`] = { json: { ok: true, marked: 1, reviewed: 2, teacher_agreed: 1, agreement: 0.5, wrong_thinking_caught: 1,
      marking_seconds: { n: 1, median: 31 }, teacher_seconds_per_paper: { n: 1, median: 60 }, examiner_asks: 2, examiner_answered: 1,
      changed_by_teacher: [{ n: 1, witness: 'mastered', teacher: 'part_way' }] } };
    answers[`GET /api/witness/sitting/${S1}/proof`] = { json: { ok: true, record: 'proof_of_thinking', exam: 'Fractions quiz', student: 'Amara', sat_ms: 1, marks: 1, out_of: 3,
      questions: [{ n: 3, question: 'Simplify 16/64', result: 'right_answer_wrong_thinking', marks: 0, out_of: 1, confidence: 0.9, moment_s: 35, diagnosis: 'Cancelled the 6s.',
        steps: [{ t: 33, wrote: '16/64', crossed_out: false }], still: 'still-3.jpg', comment: 'Divide by 16.' }],
      examiner: [{ k: 1, n: 3, ask: 'Why did you cross out the 6s?', answered: true, answer: { text: 'Because both have a 6.', verdict: { own_work: true, understood: false, why: 'w' } } }],
      read_by: ['SAM 3.1'], video: 'deleted once the paper was marked' } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush();
    expect(desk()!.textContent).toContain('Measured on this exam');
    expect(desk()!.textContent).toContain('50%you agreed with Muse Spark (1 of 2 reviewed)');
    expect(desk()!.textContent).toContain('You changed: Q1 Mastered → Mastery Plan: part way');
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush(); await flush();
    const t = desk()!.textContent!;
    expect(t).toContain("The examiner's questions");
    expect(t).toContain('Said: Because both have a 6.');
    expect(t).toContain('Their own reasoning');
    expect(t).toContain('Still working on it');
    expect(t).toContain('The desk at 0:35');
    expect(t).toContain('16/64 · = 1/4 (divide by 16)');
    expect((desk()!.querySelector('img[data-asset="drawn-3.webp"]') as HTMLImageElement).src).toBe('https://s3.example/drawn');
    expect((desk()!.querySelector('img[data-asset="still-3.jpg"]') as HTMLImageElement).src).toBe('https://s3.example/still');
    await click('[data-act="draw"]');
    expect(calls.find((c) => c.path.endsWith('/draw'))!.body).toEqual({ n: 3 });
    const cm = desk()!.querySelector('#wdComment') as HTMLTextAreaElement; cm.value = 'Divide by 16, not the 6s.'; cm.dispatchEvent(new Event('input', { bubbles: true }));
    await click('[data-act="save"]');
    expect(calls.filter((c) => c.path.endsWith('/review')).pop()!.body).toMatchObject({ n: 3, comment: 'Divide by 16, not the 6s.' });
    await click('[data-act="proof"]');
    expect(desk()!.textContent).toContain('Proof of Thinking');
    expect(desk()!.textContent).toContain('Filmed at the desk; the video was deleted once the paper was marked.');
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); await flush();
    expect(desk()!.textContent).toContain('How it was written');
  });

  // 28 Oct: Meta busy every time is not the student's fault: the video is kept and the teacher marks it again here
  it('marks a paper again from its kept video when Meta could not mark it', async () => {
    answers[`GET /api/witness/pile/${P}`] = { json: { ok: true, pile: { id: P, title: 'Fractions quiz' },
      sittings: [{ id: S1, student: 'Amara', status: 'failed', kept: true, marks: 0, out_of: 0, to_master: 0, to_review: 0 }], queue: [] } };
    answers[`GET /api/witness/sitting/${S1}`] = { json: { ok: true, id: S1, status: 'failed', kept: true,
      error: "The marking service couldn't be reached, so this paper isn't marked yet. The video is kept: mark it again, no need to film it again." } };
    answers[`POST /api/witness/sitting/${S1}/mark`] = { status: 202, json: { ok: true, id: S1, status: 'marking' } };
    await boot();
    await (window as any).__lowisaWitnessDesk.open(); await flush();
    await click(`[data-pile="${P}"]`);
    expect(desk()!.textContent).toContain('Not marked yet: mark again');
    await click(`[data-paper="${S1}"]`);
    expect(desk()!.textContent).toContain('The video is kept');
    await click('[data-act="remark"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/sitting/${S1}/mark`)).toBe(true);
    expect(desk()!.textContent).toContain('Marking it again.');
    expect(desk()!.querySelector('[data-act="remark"]')).toBeNull();
  });

  it('makes a practical task, its lines the procedure steps', async () => {
    await boot();
    await (window as any).__lowisaWitnessDesk.open(); await flush();
    await click('[data-act="new"]');
    const kind = desk()!.querySelector('#wdKind') as HTMLSelectElement; kind.value = 'practical'; kind.dispatchEvent(new Event('change', { bubbles: true })); await flush();
    expect(desk()!.textContent).toContain("The procedure's steps, one a line");
    const set = (id: string, v: string) => { const el = desk()!.querySelector(id) as HTMLInputElement; el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); };
    set('#wdTitle', 'Heating water'); set('#wdQs', '1. Measure 100 ml of water (2)\n2. Read the thermometer at eye level (1)');
    await click('[data-act="create"]');
    expect(calls.find((c) => c.method === 'POST' && c.path === '/api/witness/pile')!.body).toMatchObject({ title: 'Heating water', kind: 'practical',
      questions: [{ n: 1, text: 'Measure 100 ml of water', marks: 2 }, { n: 2, text: 'Read the thermometer at eye level', marks: 1 }] });
  });

  it('sends a new exam with its questions read from the lines', async () => {
    await boot();
    await (window as any).__lowisaWitnessDesk.open(); await flush();
    await click('[data-act="new"]');
    const set = (id: string, v: string) => { const el = desk()!.querySelector(id) as HTMLInputElement; el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); };
    set('#wdTitle', 'Algebra check'); set('#wdLevel', 'Year 9'); set('#wdQs', '1. Solve 2x + 6 = 14 (2)\n2) Factorise x² - 9\nExpand (x+1)(x+2) (3 marks)');
    await click('[data-act="create"]');
    const sent = calls.find((c) => c.method === 'POST' && c.path === '/api/witness/pile')!;
    expect(sent.body).toEqual({ title: 'Algebra check', level: 'Year 9', scheme: '', kind: 'paper', engine: 'meta', preview: true,
      questions: [{ n: 1, text: 'Solve 2x + 6 = 14', marks: 2 }, { n: 2, text: 'Factorise x² - 9', marks: 1 }, { n: 3, text: 'Expand (x+1)(x+2)', marks: 3 }] });
  });
});

// 28 Oct re-audit: what the submission, the research and the plan promised the desk and it did not have
describe('the Exam Desk after the re-audit', () => {
  let calls: Array<{ method: string; path: string; body?: any }>;
  let answers: Record<string, { status?: number; json: any }>;
  const desk = () => document.getElementById('lowisaWitnessDesk');
  const click = async (sel: string) => { (desk()!.querySelector(sel) as HTMLElement).click(); await flush(); };
  const boot = async () => {
    (window as any).__lowisaWitnessIpc = {
      hello: vi.fn(async () => ({ on: true })),
      call: vi.fn(async (r: any) => { calls.push({ method: r.method, path: r.path, body: r.body }); const a = answers[r.method + ' ' + r.path] || { json: { ok: false, error: 'no answer' } }; return { status: a.status || 200, json: a.json }; }),
    };
    (window as any).__lowisaRegisterCommand = () => undefined;
    localStorage.setItem('lowisa-user-id', 'u1');
    new Function(DESK)();
    await flush();
  };
  const q3 = (mastery: any) => ({ n: 3, result: 'right_answer_wrong_thinking', marks: 0, out_of: 2, confidence: 0.9, diagnosis: 'Cancelled the 6s.', moment_s: 35, steps: [], mastery });
  beforeEach(() => {
    calls = []; document.body.innerHTML = '';
    answers = {
      'GET /api/witness/piles': { json: { ok: true, piles: [] } },
      [`GET /api/witness/pile/${P}/measure`]: { json: { ok: false } },
      [`GET /api/witness/pile/${P}`]: { json: { ok: true, pile: { id: P, title: 'Fractions quiz', level: 'Year 7' },
        sittings: [{ id: S1, student: 'Amara', status: 'released', marks: 2, out_of: 4, to_master: 1, turned_around: 1, to_review: 0 }], queue: [] } },
      [`GET /api/witness/sitting/${S1}`]: { json: { ok: true, id: S1, status: 'released', student: 'Amara', result: {
        questions: [q3({ status: 'completed', asks: { lo: true, teacher: true }, activity: [{ title: 'Fix the stock order', right: 5, asked: 6 }],
                         explain: { lo: { text: 'Divide both by 16.', spoken: true, audio: 'explain-lo-3.m4a', verdict: { understood: true, why: 'names the factor' } } } })],
        stills: [{ n: 3, t: 35, asset: 'still-3.jpg', clip: 'clip-3.mp4' }] },
        examiner: { status: 'ready', asks: [{ k: 1, n: 3, ask: 'Why the 6s?', answer: { text: 'They match.', spoken: true, audio: 'answer-1.m4a' } }] } } },
    };
  });
  afterEach(() => { (window as any).__lowisaWitnessDesk?.close?.(); });

  it('opens the new doors only', () => {
    expect(witnessDoor('POST', '/api/witness/pile/read')).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/patterns`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/recommend`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/clip-3.mp4`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/answer-1.m4a`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/explain-lo-3.webm`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/explain-x-3.m4a`)).toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/clip-3.exe`)).toBeNull();
  });

  it('finds the class patterns and starts the next exam from them', async () => {
    answers[`POST /api/witness/pile/${P}/patterns`] = { json: { ok: true, patterns: { status: 'making' } } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush();
    expect(desk()!.textContent).toContain('1 turned around');
    await click('[data-act="patterns"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/pile/${P}/patterns`)).toBe(true);
    (answers[`GET /api/witness/pile/${P}`].json as any).pile.patterns = { status: 'ready', patterns: [
      { idea: 'Cancels matching digits', students: ['Amara', 'Ben'], questions: [3], turned_around: 1, reteach: 'Divide by a common factor: 16/64 by 16.' }],
      tomorrow: 'Start with 16/64.', next_exam: [{ text: 'Simplify 18/48', marks: 2 }, { text: 'Simplify 15/25', marks: 1 }] };
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush();
    const t = desk()!.textContent!;
    expect(t).toContain('2 students: Cancels matching digits');
    expect(t).toContain('Amara, Ben');
    expect(t).toContain('Reteach: Divide by a common factor');
    expect(t).toContain('Start with 16/64.');
    await click('[data-act="nextexam"]');
    expect((desk()!.querySelector('#wdTitle') as HTMLInputElement).value).toBe('Fractions quiz (next)');
    expect((desk()!.querySelector('#wdQs') as HTMLTextAreaElement).value).toBe('1. Simplify 18/48 (2)\n2. Simplify 15/25 (1)');
  });

  it("reads a new exam from the teacher's own file", async () => {
    // 29 Oct (film take): the paper's printed "(2 marks)" came through beside the mark, and the scheme as one line
    answers['POST /api/witness/pile/read'] = { json: { ok: true, title: 'Algebra quiz', level: 'Year 8',
      questions: [{ n: 1, text: 'Expand 3(x + 4)', marks: 2 }, { n: 2, text: 'Factorise 6x + 9. (2 marks)', marks: 2 }, { n: 3, text: 'Solve (2 marks) for x', marks: 1 }],
      scheme: 'Q1: 1 mark each term Q2: 3(2x + 3) (2) Q3: x = 4 (1)' } };
    await boot();
    await (window as any).__lowisaWitnessDesk.open(); await flush();
    await click('[data-act="new"]');
    const input = desk()!.querySelector('#wdRead') as HTMLInputElement;
    const file = new File(['%PDF-1.4'], 'scheme.pdf', { type: 'application/pdf' });
    Object.defineProperty(input, 'files', { value: [file], configurable: true });
    input.dispatchEvent(new Event('change', { bubbles: true }));
    await flush(40);
    const sent = calls.find((c) => c.path === '/api/witness/pile/read')!;
    expect(sent.body.mime).toBe('application/pdf');
    expect(atob(sent.body.file)).toBe('%PDF-1.4');
    expect((desk()!.querySelector('#wdTitle') as HTMLInputElement).value).toBe('Algebra quiz');
    expect((desk()!.querySelector('#wdQs') as HTMLTextAreaElement).value).toBe('1. Expand 3(x + 4) (2)\n2. Factorise 6x + 9. (2)\n3. Solve (2 marks) for x (1)');
    expect((desk()!.querySelector('#wdScheme') as HTMLTextAreaElement).value).toBe('Q1: 1 mark each term\nQ2: 3(2x + 3) (2)\nQ3: x = 4 (1)');
    // 31 Oct (physics test): a mark scheme read after the paper has the numbers but no question words; the paper's
    // questions stay and the scheme fills in
    answers['POST /api/witness/pile/read'] = { json: { ok: true, title: 'Algebra scheme', level: '',
      questions: [{ n: 1, text: '', marks: 1 }, { n: 2, text: '', marks: 1 }, { n: 3, text: '', marks: 1 }], scheme: 'Q1: 3x + 12 Q2: 3(2x + 3) Q3: x = 4' } };
    const again = desk()!.querySelector('#wdRead') as HTMLInputElement;
    Object.defineProperty(again, 'files', { value: [new File(['%PDF-1.4'], 'answers.pdf', { type: 'application/pdf' })] });
    again.dispatchEvent(new Event('change', { bubbles: true }));
    await flush(40);
    expect((desk()!.querySelector('#wdQs') as HTMLTextAreaElement).value).toBe('1. Expand 3(x + 4) (2)\n2. Factorise 6x + 9. (2)\n3. Solve (2 marks) for x (1)');
    expect((desk()!.querySelector('#wdScheme') as HTMLTextAreaElement).value).toBe('Q1: 3x + 12\nQ2: 3(2x + 3)\nQ3: x = 4');
  });

  it('shows the clip, the recordings, the level activity and asks for a recommendation', async () => {
    answers[`POST /api/witness/mastery/${S1}/3/recommend`] = { json: { ok: true, mastery: {} } };
    for (const f of ['still-3.jpg', 'clip-3.mp4', 'explain-lo-3.m4a', 'answer-1.m4a']) answers[`GET /api/witness/sitting/${S1}/asset/${f}`] = { json: { ok: true, url: 'https://store.example.com/' + f } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    const d = desk()!;
    expect((d.querySelector('video[data-asset="clip-3.mp4"]') as HTMLVideoElement).src).toBe('https://store.example.com/clip-3.mp4');
    expect(d.querySelector('audio[data-asset="explain-lo-3.m4a"]')).not.toBeNull();
    expect(d.querySelector('audio[data-asset="answer-1.m4a"]')).not.toBeNull();
    expect(d.textContent).toContain('Explained to Lo, out loud');
    expect(d.textContent).toContain('Fix the stock order: 5 of 6 right first time');
    expect(calls.some((c) => c.path === `/api/witness/sitting/${S1}/asset/clip-3.mp4`)).toBe(true);
    (answers[`GET /api/witness/sitting/${S1}`].json as any).result.questions[0].mastery.recommendation = { recommend: 'issue', why: 'The fresh question was right.', missing: '' };
    await click('[data-act="recommend"]');
    expect(calls.some((c) => c.method === 'POST' && c.path === `/api/witness/mastery/${S1}/3/recommend`)).toBe(true);
    expect(desk()!.textContent).toContain('The fresh question was right.');
  });

  // 30 Oct (owner): the Misconception Fingerprint on the teacher's question view: the reasoning, the evidence, the named
  // misconception (or that the paper was not enough), what the student told Lo, and the intervention
  it('shows the misconception fingerprint', async () => {
    const q = (answers[`GET /api/witness/sitting/${S1}`].json as any).result.questions[0];
    q.fingerprint = { reasoning: 'An intuition with no numbers.', evidence: ['Half up, half down. Same price.'], misconception: '',
      intervention: 'Write each step as numbers.', ask: 'Half of which amount, each time?', said: [] };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    let t = desk()!.textContent!;
    expect(t).toContain('Misconception fingerprint');
    expect(t).toContain('Not named yet: the paper is not enough evidence');
    expect(t).toContain('Half up, half down. Same price.');
    expect(t).toContain('Lo asks them first');
    expect(t).toContain('Half of which amount, each time?');
    q.fingerprint = { ...q.fingerprint, misconception: 'takes the second percentage of the original amount', ask: '',
      said: [{ ask: 'Half of which amount, each time?', text: 'Half of 100, both times.', at: 1 }] };
    (window as any).__lowisaWitnessDesk.close();
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    t = desk()!.textContent!;
    expect(t).toContain('takes the second percentage of the original amount');
    expect(t).toContain('They said: “Half of 100, both times.”');
    expect(t).toContain('The intervention their level is built on');
    expect(t).not.toContain('Lo asks them first');
  });

  // 30 Oct (owner): the teacher sends a new challenge (the same idea, a new situation), drafted by Muse Spark or their
  // own; the student's answer, their reason and Spark's reading of it come back on the card
  it('sends a new challenge and shows the answer and the reason that come back', async () => {
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/challenge`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/challenge_suggest`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/mastery/${S1}/3/challenge_answer`)).toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/diagnose-4-1.m4a`)).not.toBeNull();
    answers[`POST /api/witness/mastery/${S1}/3/challenge_suggest`] = { json: { ok: true, mastery: {}, suggestion: {
      q: 'A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?',
      options: ['910 litres', '1,000 litres', '1,090 litres'], answer: 0, checks: 'A right answer shows the rise is on the smaller amount.' } } };
    answers[`POST /api/witness/mastery/${S1}/3/challenge`] = { json: { ok: true, mastery: {} } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 3 }); await flush();
    expect(desk()!.textContent).toContain('A new challenge');
    // nothing half-written goes
    await click('[data-act="challenge"]');
    expect(calls.some((c) => c.path === `/api/witness/mastery/${S1}/3/challenge`)).toBe(false);
    expect(desk()!.textContent).toContain('mark the right one');
    // Muse Spark drafts it; the teacher changes an option and sends it
    await click('[data-act="chsuggest"]');
    const d = desk()!;
    expect((d.querySelector('#wdChQ') as HTMLTextAreaElement).value).toContain('1,000 litres of stored water');
    expect((d.querySelector('[data-f="chO2"]') as HTMLInputElement).value).toBe('1,090 litres');
    expect(d.textContent).toContain('the rise is on the smaller amount');
    const o1 = d.querySelector('[data-f="chO1"]') as HTMLInputElement;
    o1.value = 'Back to 1,000 litres'; o1.dispatchEvent(new Event('input', { bubbles: true }));
    const sheet = (answers[`GET /api/witness/sitting/${S1}`].json as any).result.questions[0].mastery;
    sheet.challenge = { q: 'A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?',
      options: ['910 litres', 'Back to 1,000 litres', '1,090 litres'], answer: 0, at: 1,
      reply: { pick: 0, right: true, why: '30% of 700 is only 210, so 910.', at: 2, verdict: { understood: true, why: 'The rise is taken on the new amount.' } } };
    await click('[data-act="challenge"]');
    const sent = calls.filter((c) => c.path === `/api/witness/mastery/${S1}/3/challenge`).pop()!;
    expect(sent.body).toEqual({ q: 'A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?',
      options: ['910 litres', 'Back to 1,000 litres', '1,090 litres'], answer: 0 });
    const t = desk()!.textContent!;
    expect(t).toContain('Answered right');
    expect(t).toContain('30% of 700 is only 210, so 910.');
    expect(t).toContain('Muse Spark: the reason holds. The rise is taken on the new amount.');
    expect(t).toContain('Set another challenge');
    expect(desk()!.querySelector('#wdChQ')).toBeNull();
  });
});

// 29 Oct (owner): From Exam to Mastery. A paper photographed after the exam by one phone: the name read from it, the
// teacher saying whose it is from the class list, the answer and the student's own step cut from the page, the seven
// capabilities, no verdict, and the badge held until the level is finished.
describe('From Exam to Mastery on the desk', () => {
  let calls: Array<{ method: string; path: string; body?: any }>;
  let answers: Record<string, { status?: number; json: any }>;
  const desk = () => document.getElementById('lowisaWitnessDesk');
  // a loaded machine (an app build beside it) needs more turns for the desk's calls to settle
  const click = async (sel: string) => { (desk()!.querySelector(sel) as HTMLElement).click(); await flush(60); };
  const boot = async () => {
    (window as any).__lowisaWitnessIpc = {
      hello: vi.fn(async () => ({ on: true })),
      call: vi.fn(async (r: any) => { calls.push({ method: r.method, path: r.path, body: r.body }); const a = answers[r.method + ' ' + r.path] || { json: { ok: false, error: 'no answer' } }; return { status: a.status || 200, json: a.json }; }),
    };
    (window as any).__lowisaRegisterCommand = () => undefined;
    localStorage.setItem('lowisa-user-id', 'u1');
    new Function(DESK)();
    await flush();
  };
  const q1 = (mastery: any) => ({ n: 1, result: 'not_yet', marks: 0, out_of: 2, confidence: 0.95, diagnosis: 'Multiplied straight across.', moment_s: null, slip: 1,
    capabilities: ['Pattern Recognition'], steps: [{ t: null, wrote: '3/4 ÷ 1/2 = 3/8', crossed_out: false, page: 1 }], mastery });
  const q2 = { n: 2, result: 'mastered', marks: 2, out_of: 2, confidence: 0.99, diagnosis: '', moment_s: null, capabilities: [], steps: [{ t: null, wrote: 'x = 4', crossed_out: false, page: 1 }] };
  const paper = (extra: any, mastery: any = { status: 'ready' }) => ({ ok: true, id: S1, status: 'released', kind: 'photo', student: 'Amani Wanjku', linked: false,
    name_match: 'unsure', read: { name: 'Amani Wanjku', class: '8B' }, pages: ['page-1.jpg', 'page-2.jpg'],
    result: { questions: [q1(mastery), q2], stills: [{ n: 1, t: null, page: 1, asset: 'still-1.jpg', step: 'step-1.jpg' }] }, ...extra });
  beforeEach(() => {
    calls = []; document.body.innerHTML = '';
    answers = {
      'GET /api/witness/piles': { json: { ok: true, piles: [] } },
      [`GET /api/witness/pile/${P}/measure`]: { json: { ok: false } },
      [`GET /api/witness/pile/${P}`]: { json: { ok: true, pile: { id: P, title: 'Maths Term Test', code: 'ABC234',
        roster: [{ uid: 'u-amani', name: 'Amani Wanjiru' }, { uid: 'u-amina', name: 'Amina Wanjiku' }, { uid: 'u-liam', name: 'Liam Chen' }] },
        sittings: [{ id: S1, kind: 'photo', student: 'Amani Wanjku', status: 'released', name_match: 'unsure', linked: false, candidates: ['u-amina', 'u-amani'],
                     marks: 2, out_of: 4, to_master: 1, to_review: 0 }], queue: [] } },
      [`GET /api/witness/sitting/${S1}`]: { json: paper({}) },
      [`POST /api/witness/sitting/${S1}/student`]: { json: { ok: true, paper: { id: S1, student: 'Amani Wanjiru', linked: true } } },
      [`POST /api/witness/mastery/${S1}/1/badge`]: { json: { ok: true, mastery: {} } },
    };
    for (const f of ['still-1.jpg', 'step-1.jpg', 'page-1.jpg', 'page-2.jpg']) answers[`GET /api/witness/sitting/${S1}/asset/${f}`] = { json: { ok: true, url: 'https://store.example.com/' + f } };
  });
  afterEach(() => { (window as any).__lowisaWitnessDesk?.close?.(); });

  it('opens the doors a photographed paper needs, and only those', () => {
    expect(witnessDoor('POST', `/api/witness/sitting/${S1}/student`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/page-2.jpg`)).not.toBeNull();
    expect(witnessDoor('GET', `/api/witness/sitting/${S1}/asset/page-2.exe`)).toBeNull();
    expect(witnessDoor('POST', `/api/witness/sitting/${S1}/page`)).toBeNull();          // the phone sends the pages
    expect(witnessDoor('POST', '/api/witness/join')).toBeNull();
  });

  it('shows whose paper it is, and the teacher says', async () => {
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush(60);
    let t = desk()!.textContent!;
    expect(t).toContain('From Exam to Mastery');
    expect(t).toContain('Class list: 3 joined');
    expect(t).toContain('Whose? Confirm');
    expect(t).toContain('1 in Mastery Plan');
    expect(t).not.toMatch(/Not yet|To master/);
    await click(`[data-paper="${S1}"]`);
    for (let i = 0; i < 20 && !desk()!.querySelector('[data-f="whose"] option'); i++) await flush();
    t = desk()!.textContent!;
    expect(t).toContain('Name written on the paper: Amani Wanjku');
    expect(t).toContain('class 8B');
    // the likely students first, marked so
    const opts = Array.from(desk()!.querySelectorAll('[data-f="whose"] option')).map((o) => o.textContent);
    expect(opts).toEqual(['Amani Wanjiru (likely)', 'Amina Wanjiku (likely)', 'Liam Chen']);
    expect(desk()!.querySelectorAll('img[data-asset^="page-"]').length).toBe(2);
    answers[`GET /api/witness/sitting/${S1}`] = { json: paper({ student: 'Amani Wanjiru', linked: true, name_match: 'teacher' }) };
    await click('[data-act="whose"]');
    expect(calls.find((c) => c.path === `/api/witness/sitting/${S1}/student`)!.body).toEqual({ uid: 'u-amani' });
    expect(desk()!.textContent).toContain('This paper is with Amani Wanjiru now');
    // a student with no phone: a name, printed for them
    answers[`POST /api/witness/sitting/${S1}/student`] = { json: { ok: true, paper: { id: S1, student: 'Baraka Otieno', linked: false } } };
    const nm = desk()!.querySelector('[data-f="whoseName"]') as HTMLInputElement; nm.value = 'Baraka Otieno'; nm.dispatchEvent(new Event('input', { bubbles: true }));
    await click('[data-act="whosename"]');
    expect(calls.filter((c) => c.path === `/api/witness/sitting/${S1}/student`)[1].body).toEqual({ name: 'Baraka Otieno' });
    expect(desk()!.textContent).toContain('Saved as Baraka Otieno');
  });

  // 30 Oct (judges' panel): a paper is deleted for good, asked twice; while Lo asks, the guess is the teacher's alone
  it('deletes a paper only when asked twice, and shows the possible idea while Lo asks', async () => {
    expect(witnessDoor('POST', `/api/witness/sitting/${S1}/delete`)).not.toBeNull();
    expect(witnessDoor('POST', `/api/witness/pile/${P}/delete`)).not.toBeNull();
    const asking = paper({}); asking.result.questions[0].fingerprint = { reasoning: 'Could be either idea.', evidence: [], misconception: '', intervention: '', ask: 'Write the price after each change.', possible: 'cancelling' };
    answers[`GET /api/witness/sitting/${S1}`] = { json: asking };
    answers[`POST /api/witness/sitting/${S1}/delete`] = { json: { ok: true, deleted: 1 } };
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P }); await flush(60);
    await click(`[data-paper="${S1}"]`);
    for (let i = 0; i < 20 && !desk()!.querySelector('[data-act="delask"]'); i++) await flush();
    expect(desk()!.textContent).toContain('Possible, until they answer Lo (not shown to the student)cancelling');
    await click('[data-act="delask"]');
    expect(calls.some((c) => c.path.endsWith('/delete'))).toBe(false);
    expect(desk()!.textContent).toContain('Delete for good?');
    await click('[data-act="delete"]');
    expect(calls.find((c) => c.path === `/api/witness/sitting/${S1}/delete`)).toBeTruthy();
    expect(desk()!.textContent).toContain('The paper is deleted.');
  });

  it("shows the answer and the student's own step from the page, the capabilities, and no verdict", async () => {
    await boot();
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 1 }); await flush(60);
    const d = desk()!;
    const t = d.textContent!;
    expect(t).toContain('Mastery Plan');
    expect(t).not.toMatch(/Not yet|To master|Replay/);           // no verdict; a photographed paper has no times to replay
    expect(t).toContain('The answer on the paper, page 1');
    expect(t).toContain('Thinking capabilities its level builds');
    expect(t).toContain('Pattern Recognition: Identify patterns');
    expect((d.querySelector('img[data-asset="step-1.jpg"]') as HTMLImageElement).src).toBe('https://store.example.com/step-1.jpg');
    expect(d.querySelectorAll('.wd-step.slip').length).toBe(1);
    // the badge waits for the finished level: every lesson's questions and the flashcards
    const issue = Array.from(d.querySelectorAll('button')).find((b) => b.textContent === 'Issue Turned around') as HTMLButtonElement;
    expect(issue.disabled).toBe(true);
    expect(t).toContain('The badge opens once they finish the level');
    expect(t).toContain('Keep going');
    answers[`GET /api/witness/sitting/${S1}`] = { json: paper({}, { status: 'completed', completed_ms: 1 }) };
    await (window as any).__lowisaWitnessDesk.show({ pile: P, paper: S1, n: 1 }); await flush(60);
    await click('[data-act="badge"]');
    expect(calls.find((c) => c.path === `/api/witness/mastery/${S1}/1/badge`)!.body).toMatchObject({ issue: true });
  });
});
