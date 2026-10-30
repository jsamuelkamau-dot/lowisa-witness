/**
 * The teacher's lesson record (31 Oct, rehearsal): "Keep going" opened lesson 2 while the session still held lesson 1's
 * finished run, and lesson 2 reached the teacher as finished, 6 of 6, before the student had answered anything in it.
 * A lesson is told as finished only by the run of that very lesson.
 */
import React from 'react';
import {act} from 'react';
import TestRenderer from 'react-test-renderer';
import {LessonPlayer} from '../src/game/LessonPlayer';
import {MobileLessonSession} from '../src/game/session';
import {MirrorStorage} from '../src/state/storage';
import {compileDeepCourse, deepCourseFor} from '../src/paths/deep';

const compiled = compileDeepCourse(deepCourseFor('web-foundations')!);
const lessons = compiled.path.sections.flatMap(s => s.skills.flatMap(k => k.chapters.flatMap(c => c.lessons)));
const [first, second] = lessons as unknown as Array<{id: string; title: string}>;

function session(): MobileLessonSession {
  return new MobileLessonSession({storage: new MirrorStorage(null), deviceId: 'd', sessionId: 's', learnerId: 'l', projectId: 'p',
                                  now: () => 1700000000000, speak: () => {}});
}

test("the next lesson is not told as finished by the last lesson's run", () => {
  const s = session();
  s.start(first as never, 'seed', 60);
  s.run = {...s.run!, phase: 'lesson_done'} as never;   // lesson 1 just finished; "Keep going" opens lesson 2
  const told: Array<{title: string}> = [];
  act(() => { TestRenderer.create(<LessonPlayer session={s} lesson={second as never} seed="seed" pipAccuracy={60}
                                                onDone={() => {}} onHandOff={() => {}} masteryActivity={l => told.push(l)} />); });
  expect(told.map(t => t.title)).not.toContain(second.title);
});

test('a lesson whose own run finished is told once', () => {
  const s = session();
  s.start(first as never, 'seed', 60);
  s.run = {...s.run!, phase: 'lesson_done'} as never;
  const told: Array<{title: string}> = [];
  let r!: TestRenderer.ReactTestRenderer;
  act(() => { r = TestRenderer.create(<LessonPlayer session={s} lesson={first as never} seed="seed" pipAccuracy={60} resume={null}
                                                    onDone={() => {}} onHandOff={() => {}} masteryActivity={l => told.push(l)} />); });
  act(() => { r.update(<LessonPlayer session={s} lesson={first as never} seed="seed" pipAccuracy={60} resume={null}
                                     onDone={() => {}} onHandOff={() => {}} masteryActivity={l => told.push(l)} />); });
  expect(told.filter(t => t.title === first.title).length).toBeLessThanOrEqual(1);
});

// 31 Oct, rehearsal: the last lesson promised "The next lesson answers it" with no next lesson
import {AskOurselves} from '../src/game/AskOurselves';
import {RecheckCard} from '../src/witness/WitnessScreen';

test('the last lesson of a level does not promise a next lesson', () => {
  let r!: TestRenderer.ReactTestRenderer;
  act(() => { r = TestRenderer.create(<AskOurselves q="What do you pay?" last final onGo={() => {}} />); });
  const t = JSON.stringify(r.toJSON());
  expect(t).not.toContain('The next lesson answers it');
  expect(t).toContain('Answer it yourself');
  act(() => { r.update(<AskOurselves q="What do you pay?" last onGo={() => {}} />); });
  expect(JSON.stringify(r.toJSON())).toContain('The next lesson answers it');
});

test('"days later" only when the re-check came days later', () => {
  const card = (days: number | null) => {
    let r!: TestRenderer.ReactTestRenderer;
    act(() => { r = TestRenderer.create(<RecheckCard r={{status: 'passed', q: 'q', unit: 'L', reply: {value: 125, right: true, answer: 125}, days}} act={async () => ({})} />); });
    return JSON.stringify(r.toJSON());
  };
  expect(card(0)).toContain('Right. Still yours.');
  expect(card(0)).not.toContain('later');
  expect(card(7)).toContain('Still yours, 7 days later.');
  expect(card(null)).not.toContain('later');
});
