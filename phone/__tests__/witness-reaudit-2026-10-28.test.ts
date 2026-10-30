/**
 * WITNESS re-audit (2026-10-28): what the submission, the research and the plan promised the phone and it did not have.
 */
import {spokenFeedback} from '../src/witness/WitnessScreen';
import {toMaster, turnedAround, type Paper, type Question} from '../src/witness/net';
import {KEPT_WORDS} from '../src/witness/SayIt';
import {createCustomCourse, MASTERY_CHECK_ROUNDS} from '../src/paths/custom/course';

const q = (n: number, result: Question['result'], extra: Partial<Question> = {}): Question =>
  ({n, result, marks: 0, out_of: 2, confidence: 0.9, moment_s: 3, diagnosis: 'Cancelled the 6s.', steps: [], ...extra} as Question);

describe('a turned-around question counts as mastered', () => {
  it('leaves the questions to master once the teacher issues the badge', () => {
    const p: Paper = {id: 'p', status: 'released', result: {questions: [q(1, 'mastered', {marks: 2}), q(3, 'right_answer_wrong_thinking', {mastery: {status: 'badge'} as never}), q(4, 'not_yet')]}} as Paper;
    expect(toMaster(p).map(x => x.n)).toEqual([4]);
    expect(turnedAround(p.result!.questions[1])).toBe(true);
  });
});

describe('Hear it: the feedback spoken (the submission)', () => {
  it('says the result, the marks, what went wrong and the teacher', () => {
    expect(spokenFeedback(q(3, 'right_answer_wrong_thinking', {comment: {text: 'Divide by 16.'}} as never)))
      .toBe("Question 3. In your Mastery Plan. You got 0 of 2 marks. What your working shows: Cancelled the 6s. Your teacher says: Divide by 16.");
    expect(spokenFeedback(q(3, 'right_answer_wrong_thinking', {mastery: {status: 'badge'}} as never))).toBe('Question 3. Turned around. You got 0 of 2 marks.');
  });
  it('tells the student their recording is kept for the teacher (owner, 28 Oct)', () => {
    expect(KEPT_WORDS).toContain('the recording is kept with your paper so your teacher can listen to it');
  });
});

describe('a mastery level names the paper it is for, so the teacher pays (the plan)', () => {
  it('sends `for` on every design call, and checks up to three rewrites', async () => {
    expect(MASTERY_CHECK_ROUNDS).toBe(3);
    const bodies: Array<Record<string, unknown>> = [];
    const titles = ['Your step at the till', 'Digits are not numbers', 'Fix the stock order'];
    const fetchFn = async (_url: string, init?: {body?: string}) => {
      const b = JSON.parse(String(init && init.body || '{}')); bodies.push(b);
      const system = String((b.messages || []).find((m: {role: string}) => m.role === 'system')?.content || '');
      const reply = system.includes('OUTLINE SKELETON') ? {title: 'Common factors', promise: 'Cancel right.', levels: [{title: 'Cancel factors right', modules: titles.map(t => ({title: t}))}]}
        : system.startsWith('You REVIEW') ? {missing: [], repeats: [], crammed: [], padding: [], depth: ''}
        : {modules: titles.map(t => ({title: t, beats: [1, 2, 3].map(i => ({name: t + ' ' + i, teach: 'This sentence teaches part ' + i + ' of ' + t + ' plainly to the student.'}))}))};
      return {ok: true, status: 200, json: async () => ({success: true, text: JSON.stringify(reply)})};
    };
    const store = new Map<string, string>();
    const storage = {getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => { store.set(k, v); }, removeItem: (k: string) => { store.delete(k); }} as never;
    const made = await createCustomCourse({backendUrl: 'https://api.test', token: async () => 'tok', fetchFn: fetchFn as unknown as typeof fetch, now: () => 1, mastery: true,
      designFor: {sitting: 'abc123', n: 3}, masteryCheck: async () => ({passes: true, problems: []})}, storage, 'topic', 'One mastery level', {context: 'q3', findSyllabus: async () => null});
    expect(made.ok).toBe(true);
    expect(bodies.length).toBeGreaterThan(0);
    expect(bodies.every(b => JSON.stringify(b.for) === JSON.stringify({sitting: 'abc123', n: 3}))).toBe(true);
  });
});

describe("a teacher out of credits is the teacher's, not the student's wall", () => {
  it('says so in the server words', async () => {
    const fetchFn = async () => ({ok: false, status: 409, json: async () => ({success: false, code: 'teacher_credits', error: "Your teacher's credits for mastery levels have run out. Ask your teacher, then try again."})});
    const store = new Map<string, string>();
    const storage = {getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => { store.set(k, v); }, removeItem: (k: string) => { store.delete(k); }} as never;
    const made = await createCustomCourse({backendUrl: 'https://api.test', token: async () => 'tok', fetchFn: fetchFn as unknown as typeof fetch, now: () => 1, mastery: true,
      designFor: {sitting: 'abc123', n: 3}}, storage, 'topic', 'One mastery level', {context: 'q3', findSyllabus: async () => null});
    expect(made.ok).toBe(false);
    expect(made.reason).toBe('refused');
    expect(made.text).toContain("Your teacher's credits");
    expect(made.gate).toBeUndefined();
  });
});

describe('the Witness camera hands over to the camera app when it cannot record (28 Oct, live)', () => {
  it('opens the camera app and says so', async () => {
    const {record, HAND_OVER_WORDS} = require('../src/witness/WitnessScreen');
    const clip = {name: 'clip.mp4', mime: 'video/mp4', size: 10, uri: 'file:///clip.mp4'};
    let said = '';
    const failing = {witnessCamera: jest.fn(async () => { throw Object.assign(new Error('x'), {code: 'witness_camera_failed'}); }), takeVideo: jest.fn(async () => clip)};
    await expect(record(failing, () => { said = HAND_OVER_WORDS; })).resolves.toBe(clip);
    expect(failing.takeVideo).toHaveBeenCalled();
    expect(said).toContain("phone's own camera opens instead");
    const fine = {witnessCamera: jest.fn(async () => clip), takeVideo: jest.fn()};
    await expect(record(fine)).resolves.toBe(clip);
    expect(fine.takeVideo).not.toHaveBeenCalled();
    const other = {witnessCamera: jest.fn(async () => { throw Object.assign(new Error('x'), {code: 'camera_off'}); }), takeVideo: jest.fn()};
    await expect(record(other)).rejects.toThrow();
  });
});
