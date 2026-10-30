/**
 * FROM EXAM TO MASTERY (2026-10-29, owner): the paper photographed after the exam by one phone, no question ending in a
 * verdict, every question not mastered in the Mastery Plan, and the seven thinking capabilities named in each level.
 */
import {takenLine, takenFor, MAX_PAGES} from '../src/witness/WitnessScreen';
import {CAPABILITIES, capabilitiesOf, PLAN_WHY, RESULT_WORDS, toMaster, witness, type Paper, type Question, type Taken} from '../src/witness/net';
import {builtNews, keepBuilt, markMasteryDone, masteryBrief, masteryDone, MASTERY_DONE_KEY} from '../src/witness/mastery';
import {compileDeepCourse} from '../src/paths/deep/compile';

const q = (n: number, result: Question['result'], extra: Partial<Question> = {}): Question =>
  ({n, result, marks: 0, out_of: 2, confidence: 0.9, moment_s: null, diagnosis: 'Cancelled the 6s.', steps: [], ...extra} as Question);

describe('no question ends in a verdict', () => {
  it('says mastered, or in your Mastery Plan, and never "not yet" or "failed"', () => {
    expect(RESULT_WORDS.mastered).toBe('Mastered');
    for (const r of ['not_yet', 'right_answer_wrong_thinking', 'part_way'] as const) {
      expect(RESULT_WORDS[r]).toBe('In your Mastery Plan');
      expect(PLAN_WHY[r]).toMatch(/Mastery Plan/);
    }
    const words = Object.values(RESULT_WORDS).concat(Object.values(PLAN_WHY)).join(' ').toLowerCase();
    expect(words).not.toMatch(/not yet|fail|wrong/);
  });
  it('puts every question not mastered in the Mastery Plan, part way included', () => {
    const p = {id: 'p', status: 'released', result: {questions: [q(1, 'mastered'), q(2, 'part_way'), q(3, 'right_answer_wrong_thinking'), q(4, 'not_yet')]}} as Paper;
    expect(toMaster(p).map(x => x.n)).toEqual([2, 3, 4]);
  });
});

describe('the seven thinking capabilities', () => {
  it('are the owner\'s seven, by name', () => {
    expect(Object.keys(CAPABILITIES)).toEqual(['Pattern Recognition', 'Probability & Uncertainty', 'Optimization', 'Systems Thinking',
      'Trade-offs', 'Decision-Making', 'Root Cause Analysis']);
  });
  it('shows at most two a question, only known ones', () => {
    expect(capabilitiesOf(q(1, 'not_yet', {capabilities: ['Root Cause Analysis', 'Telepathy', 'Decision-Making', 'Optimization']}))).toEqual(['Root Cause Analysis', 'Decision-Making']);
    expect(capabilitiesOf(q(1, 'mastered'))).toEqual([]);
  });
  it('asks the level builder to practise them, never naming them in the lessons', () => {
    const {context} = masteryBrief({id: 'p', status: 'released', title: 'Maths Term Test'} as Paper,
      q(3, 'right_answer_wrong_thinking', {capabilities: ['Root Cause Analysis'], final_answer: '1/4', steps: [{t: null, wrote: '16/64 with both 6s struck =', crossed_out: false}]}));
    // 31 Oct (judges' panel): the level practises the thinking and never writes the capability's name in its text
    expect(context).toMatch(/THE THINKING THIS LEVEL PRACTISES .*never write these names.*Root Cause Analysis \(Investigate problems systematically/);
    expect(context).toMatch(/THE CHECKS: no title, beat name, banner or question gives its own answer away/);
    expect(context).toMatch(/16\/64 with both 6s struck/);
  });
  it('tells the builder a part-way answer needs its whole thinking shown', () => {
    expect(masteryBrief({id: 'p', status: 'released'} as Paper, q(5, 'part_way')).context).toMatch(/make every step of the thinking visible/);
  });
});

describe('the papers one phone photographed', () => {
  const t = (extra: Partial<Taken>): Taken => ({id: 'x', status: 'marked', pages: 2, got: [1, 2], title: 'Maths', created_ms: 1, student: 'Amani Wanjiru',
    read: {name: 'Amani Wanjiru'}, name_match: 'read', ...extra});
  it('lists only the papers sent for this exam, by its code, when two exams share a title', () => {
    const mine = t({id: 'a', title: 'Maths', code: 'DEMOJN'}), other = t({id: 'b', title: 'Maths', code: 'VVRAWN'});
    expect(takenFor([mine, other], 'demojn', 'Maths').map(p => p.id)).toEqual(['a']);
    expect(takenFor([t({id: 'old', title: 'Maths'})], 'DEMOJN', 'Maths').map(p => p.id)).toEqual(['old']);   // an older server
  });
  it('says whose each paper is once the name comes back', () => {
    expect(takenLine(t({}))).toBe('Amani Wanjiru · on the class list');
    expect(takenLine(t({name_match: 'unsure', read: {name: 'Amani Wanjku'}}))).toBe('Name read: Amani Wanjku · the teacher confirms whose it is');
    expect(takenLine(t({name_match: 'none', student: 'Baraka Otieno', read: {name: 'Baraka Otieno'}}))).toBe('Name read: Baraka Otieno · not on the class list yet');
    expect(takenLine(t({name_match: 'unread', read: {}}))).toBe('No name could be read · the teacher says whose it is');
    expect(takenLine(t({status: 'marking'}))).toBe('Marking: the name comes back here');
    expect(takenLine(t({name_match: null}))).toBe('Marked: finding whose it is');
    expect(takenLine(t({status: 'failed'}))).toMatch(/Photograph it again/);
    expect(MAX_PAGES).toBe(20);
  });
  it('sends the paper as the server reads it', async () => {
    const calls: Array<{path: string; body: unknown}> = [];
    jest.resetModules();
    jest.doMock('../src/live/edge', () => ({callViaEdge: async (_e: unknown, _m: string, path: string, body: unknown) => { calls.push({path, body}); return {status: 200, json: {ok: true, id: 's1', pages: 2, got: [1]}}; }}));
    const net = require('../src/witness/net') as typeof import('../src/witness/net');
    const env = {token: async () => 'tok'} as never;
    await net.witness.join(env, 'ABC234', 'Amani Wanjiru');
    await net.witness.startPhoto(env, 'ABC234', 2);
    await net.witness.page(env, 's1', 1, 'image/jpeg', 'AAAA');
    expect(calls.map(c => c.path)).toEqual(['/api/witness/join', '/api/witness/sitting/start', '/api/witness/sitting/s1/page']);
    expect(calls[0].body).toEqual({code: 'ABC234', name: 'Amani Wanjiru'});
    expect(calls[1].body).toEqual({kind: 'photo', pages: 2, code: 'ABC234'});
    expect(calls[2].body).toEqual({n: 1, mime: 'image/jpeg', file: 'AAAA'});
    jest.dontMock('../src/live/edge');
    expect(typeof witness.taken).toBe('function');
  });
});

describe('the level is finished when its lessons and flashcards are', () => {
  const store = () => { const m = new Map<string, string>(); return {getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => { m.set(k, v); }, removeItem: (k: string) => { m.delete(k); }} as never; };
  it('counts a level the path map finished, which the course record never did (29 Oct, live)', () => {
    const s = store();
    expect(masteryDone(s, 'custom-topic-1')).toBe(false);
    markMasteryDone(s, 'custom-topic-1');
    markMasteryDone(s, 'custom-topic-1');
    expect(masteryDone(s, 'custom-topic-1')).toBe(true);
    expect(masteryDone(s, 'custom-topic-2')).toBe(false);
    expect(JSON.parse((s as {getItem(k: string): string}).getItem(MASTERY_DONE_KEY))).toEqual(['custom-topic-1']);
  });
  it('survives a broken record', () => {
    const s = store(); (s as {setItem(k: string, v: string): void}).setItem(MASTERY_DONE_KEY, '{oops');
    expect(masteryDone(s, 'p')).toBe(false);
    markMasteryDone(s, 'p');
    expect(masteryDone(s, 'p')).toBe(true);
  });
});

describe('a mastery level is named by its title, not "Level 0"', () => {
  const level = (n: number, title: string) => ({id: 'l' + n, n, title, modules: [{id: 'm' + n, title: 'A lesson', beats: []}]});
  const course = (levels: any[]) => ({pathId: 'custom-topic-t', title: 'T', promise: '', careerProjects: [], outcomes: [], levels} as any);
  test('one level: its own title (Quick Fire and the path read "Fractions: Fix Digit Cancelling")', () => {
    expect(compileDeepCourse(course([level(0, 'Fractions: Fix Digit Cancelling')])).path.sections[0].title).toBe('Fractions: Fix Digit Cancelling');
  });
  test('a course of several levels keeps its numbers', () => {
    const p = compileDeepCourse(course([level(0, 'Start'), level(1, 'Next')])).path;
    expect(p.sections.map(x => x.title)).toEqual(['Level 0 — Start', 'Level 1 — Next']);
  });
});

describe("a fresh level's news is kept until the teacher has it", () => {
  const mem = () => { const m: Record<string, string> = {}; return {getItem: (k: string) => (k in m ? m[k] : null), setItem: (k: string, v: string) => { m[k] = v; }, removeItem: (k: string) => { delete m[k]; }} as any; };
  test('the self-check and the outline come back for the path, nothing for another', () => {
    const st = mem();
    const level = {title: 'Fractions: Fix Digit Cancelling', lessons: [{title: 'The juice mix', beats: ['Find the concentrate']}]} as any;
    keepBuilt(st, 'custom-topic-a', {check: {passes: true, problems: []}, level});
    expect(builtNews(st, 'custom-topic-a')).toEqual({check: {passes: true, problems: []}, level});
    expect(builtNews(st, 'custom-topic-b')).toBeNull();
  });
  test('it keeps the newest twenty', () => {
    const st = mem();
    for (let i = 0; i < 25; i++) keepBuilt(st, 'p' + i, {check: null, level: null});
    expect(builtNews(st, 'p0')).toBeNull();
    expect(builtNews(st, 'p24')).toEqual({check: null, level: null});
  });
});

describe('a mastery level never ends on a build', () => {
  const {normalizeBuild} = require('../src/paths/gen/contract');
  test('a placeholder build ("x") is not a program', () => {
    expect(normalizeBuild({title: 'x', lang: 'python', code: 'x', tweak: 'x', say: 'x'})).toBeNull();
    expect(normalizeBuild({title: 'Hi', lang: 'python', code: 'print("Hi")', tweak: 'Say your name.', say: 'Run it.'})).not.toBeNull();
  });
  test('the writer drops a build on a subject course, keeps it on a code path', () => {
    const src = require('fs').readFileSync(require('path').join(__dirname, '..', 'src', 'paths', 'gen', 'generate.ts'), 'utf8');
    expect((src.match(/this\.assemble\(pathId, authored, sections/g) || []).length).toBe(3);
    expect(src).not.toMatch(/return assembleRichLesson\(authored, sections\);/);
    expect(src).toMatch(/pathId\.indexOf\('custom-topic-'\) === 0 && rich\.build \? \{\.\.\.rich, build: null\} : rich/);
  });
});
