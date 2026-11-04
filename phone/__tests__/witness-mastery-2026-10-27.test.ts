/**
 * WITNESS (2026-10-27, Meta hackathon): a mastery level is the Master any topic build of ONE level for one question a
 * student did not master. Pinned here: what the build is given (the question, the student's own working in order with
 * the crossed-out step, the diagnosis, the wrong-method note, the teacher's focus), the words a student sees (never
 * "failed"), and the level text the self-check reads.
 */
import {masteryBrief, masteryKey, MASTERY_MODEL} from '../src/witness/mastery';
import {asksLeft, RESULT_WORDS, toMaster, typedCode} from '../src/witness/net';
import {clock, replayGaps, slipIndex} from '../src/witness/Proof';
import {createCustomCourse, MASTERY_RULE, masteryLevelText, MASTERY_CHECK_ROUNDS} from '../src/paths/custom/course';
import type {Paper, Question} from '../src/witness/net';

const q3: Question = {
  n: 3, result: 'right_answer_wrong_thinking', marks: 1, out_of: 2, final_answer: '1/4', confidence: 0.9, moment_s: 35,
  steps: [{t: 33, wrote: '3. 16/64', crossed_out: false}, {t: 34, wrote: '16/64 = 1/4', crossed_out: true}],
  diagnosis: 'Cancelled the digit 6 from top and bottom instead of dividing by a common factor.',
  focus: 'Show her a fraction where cancelling digits gives a wrong answer. She loves football.',
};
const paper: Paper = {id: 'p1', status: 'released', title: 'Fractions check', result: {questions: [
  {...q3, n: 1, result: 'mastered', diagnosis: '', steps: []}, q3, {...q3, n: 4, result: 'mastered', teacher_result: 'not_yet'},
]}};

describe('Witness mastery levels', () => {
  it('gives the build the question, the working in order, the diagnosis and the teacher note', () => {
    const {input, context} = masteryBrief(paper, q3, 'Year 7');
    expect(input).toBe('One mastery level: Cancelled the digit 6 from top and bottom instead of dividing by a common factor');
    expect(context).toContain('question 3 of "Fractions check" (the student answered 1/4)');
    expect(context).toContain('3. 16/64\n(crossed out) 16/64 = 1/4');
    expect(context).toContain('WHERE THE THINKING WENT WRONG: Cancelled the digit 6');
    expect(context).toContain('the method was wrong');
    expect(context).toContain("THE TEACHER'S FOCUS NOTE: Show her a fraction");
    expect(context).toContain("THE STUDENT'S LEVEL: Year 7");
    expect(MASTERY_MODEL).toBe('muse-spark-1-3');
    expect(masteryKey('p1', 3)).toBe('p1#3');
  });

  it('asks for exactly one level that runs the student own step first', () => {
    expect(MASTERY_RULE).toContain('EXACTLY ONE level of exactly 3 lessons');
    expect(MASTERY_RULE).toContain("Lesson 1 runs the student's OWN step");
    expect(MASTERY_RULE).toContain('never medical advice');
    // the industry gap: the level ends in a real task someone does at work with the idea
    expect(MASTERY_RULE).toContain('AS A REAL TASK someone does at');
    expect(MASTERY_RULE).toContain('able to DO it');
    expect(MASTERY_RULE).toContain("Lesson 3's title names that task");
    expect(MASTERY_CHECK_ROUNDS).toBe(3);   // the plan: "up to 3 times" (28 Oct re-audit)
  });

  it('counts the teacher word: a question they marked not yet is to master', () => {
    expect(toMaster(paper).map(q => q.n)).toEqual([3, 4]);
    expect(Object.values(RESULT_WORDS).join(' ').toLowerCase()).not.toContain('fail');
    expect(typedCode(' t3s-tab0 ')).toBe('T3STAB');
  });

  it('reads each lesson for the self-check', () => {
    const t = masteryLevelText({title: 'Common factors', modules: [{title: 'At the stadium', beats: [{name: 'Your step', teach: '16/64 = 1/4 works by luck', analogy: 'a lucky pass'}, {bad: 1}]}]});
    expect(t).toEqual({title: 'Common factors', lessons: [{title: 'At the stadium', beats: ['Your step: 16/64 = 1/4 works by luck: a lucky pass']}]});
  });
});

describe('the self-check reads the level that is kept', () => {
  const titles = ['Your step at the till', 'Digits are not numbers', 'Price the boots sale'];
  const run = async (verdicts: boolean[]) => {
    const asked: string[] = [];
    const fetchFn = async (_url: string, init?: {body?: string}) => {
      const msgs = JSON.parse(String(init && init.body || '{}')).messages || [];
      const system = String((msgs.find((m: {role: string}) => m.role === 'system') || {content: ''}).content);
      const user = String((msgs.find((m: {role: string}) => m.role === 'user') || {content: ''}).content);
      asked.push(user.includes('FAILED ITS SELF-CHECK') ? 'rewrite' : 'other');
      const reply = system.includes('OUTLINE SKELETON') ? {title: 'Common factors', promise: 'Cancel right.', levels: [{title: 'Cancel factors right', modules: titles.map(t => ({title: t}))}]}
        : system.startsWith('You REVIEW') ? {missing: [], repeats: [], crammed: [], padding: [], depth: ''}
        : {modules: titles.map(t => ({title: t, beats: [1, 2, 3].map(i => ({name: t + ' ' + i, teach: 'This sentence teaches part ' + i + ' of ' + t + ' plainly to the student.'}))}))};
      return {ok: true, status: 200, json: async () => ({success: true, text: JSON.stringify(reply)})};
    };
    const store = new Map<string, string>();
    const storage = {getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => { store.set(k, v); }, removeItem: (k: string) => { store.delete(k); }} as never;
    let checks = 0;
    const made = await createCustomCourse({backendUrl: 'https://api.test', token: async () => 'tok', fetchFn: fetchFn as unknown as typeof fetch, now: () => 1, mastery: true,
      masteryCheck: async () => ({passes: verdicts[Math.min(checks++, verdicts.length - 1)], problems: ['lesson 2: lucky cancels only']})}, storage, 'topic', 'One mastery level: cancelling digits', {context: 'question 3', findSyllabus: async () => null});
    return {made, checks, rewrites: asked.filter(a => a === 'rewrite').length};
  };
  it('checks the last rewrite too, and stops at the rounds', async () => {
    const failing = await run([false]);
    expect(failing.made.ok).toBe(true);
    expect(failing.rewrites).toBe(MASTERY_CHECK_ROUNDS);
    expect(failing.checks).toBe(MASTERY_CHECK_ROUNDS + 1);
    const fixed = await run([false, true]);
    expect(fixed.rewrites).toBe(1);
    expect(fixed.checks).toBe(2);
  });
});

describe('the examiner and the replay on the phone', () => {
  it('counts the examiner questions still to answer', () => {
    const p: Paper = {id: 'p', status: 'with_teacher', examiner: {status: 'ready', asks: [{k: 1, n: 3, ask: 'Why?', answered: true}, {k: 2, n: 1, ask: 'How?', answered: false}]}};
    expect(asksLeft(p).map(a => a.k)).toEqual([2]);
    expect(asksLeft({id: 'x', status: 'with_teacher'})).toEqual([]);
  });
  it('stops the replay at the step written when the thinking went wrong, at its own pace', () => {
    const steps = [{t: 33, wrote: '16/64', crossed_out: false}, {t: 34, wrote: '= 1/4', crossed_out: false}, {t: 50, wrote: 'check', crossed_out: false}];
    expect(slipIndex(steps, 35)).toBe(1);
    expect(slipIndex(steps, null)).toBe(-1);
    expect(slipIndex(steps, 2)).toBe(0);
    expect(replayGaps(steps)).toEqual([1600, 400, 1600]);
    expect(clock(95)).toBe('1:35');
  });
});

// 29 Oct (emulator): "1 part syrup in 4" and "a true 1 to 4 mix" for the same jug left a question with no right option
test('the mastery rule keeps a fraction of a whole apart from a ratio', () => {
  const {MASTERY_RULE: rule} = require('../src/paths/custom/course');
  expect(rule).toContain('a fraction of a whole is said as a part of the whole');
  expect(rule).toContain('never as a ratio');
});
