/**
 * WITNESS audit (2026-10-29): the plan (1b) says every call of a mastery level goes to Meta's models. The build's design
 * calls did; the calls after it (lessons opened later, flashcards, Lo's live turns, the Insight episode) went to the
 * house model. A mastery level's path now sends them to the Witness door on Muse Spark, with the paper it is for.
 */
import {askMeta, MASTERY_KEY, metaRouteFor} from '../src/witness/metaRoute';
import {LessonWriter} from '../src/paths/gen/generate';
import {liveTeach} from '../src/teaching/live';
import {makeDeck} from '../src/flashcards/make';

const store = (m: Record<string, string> = {}) => {
  const d: Record<string, string> = {...m};
  return {getItem: (k: string) => (k in d ? d[k] : null), setItem: (k: string, v: string) => { d[k] = v; }, removeItem: (k: string) => { delete d[k]; }} as never;
};
const mastery = () => store({[MASTERY_KEY]: JSON.stringify({'paper1#3': 'custom-topic-abc'})});
const reply = (status: number, body: unknown) => ({ok: status >= 200 && status < 300, status, json: async () => body}) as unknown as Response;

describe('which paths are a mastery level', () => {
  it('finds the paper and question a level was built for', () => {
    expect(metaRouteFor(mastery(), 'custom-topic-abc')).toEqual({sitting: 'paper1', n: 3});
    expect(metaRouteFor(mastery(), 'python-basics')).toBeNull();
    expect(metaRouteFor(store(), 'custom-topic-abc')).toBeNull();
    expect(metaRouteFor(mastery(), null)).toBeNull();
  });
});

describe('askMeta', () => {
  it('asks Muse Spark through the Witness door with the paper it is for', async () => {
    const calls: Array<{url: string; body: Record<string, unknown>}> = [];
    const fetchFn = (async (url: string, init?: {body?: string}) => { calls.push({url, body: JSON.parse(String(init && init.body))}); return reply(200, {success: true, text: '{"a":1}'}); }) as never;
    const r = await askMeta({backendUrl: 'https://x', token: () => 't', fetchFn}, {sitting: 'paper1', n: 3}, [{role: 'user', content: 'hi'}], 'rid');
    expect(r).toEqual({kind: 'text', text: '{"a":1}'});
    expect(calls[0].url).toBe('https://x/api/witness/design');
    expect(calls[0].body).toMatchObject({requestId: 'rid', modelKey: 'muse-spark-1-3', for: {sitting: 'paper1', n: 3}});
    expect(calls[0].body.reply).toBeUndefined();
    await askMeta({backendUrl: 'https://x', token: () => 't', fetchFn}, {sitting: 'paper1', n: 3}, [{role: 'user', content: 'hi'}], 'rid', {text: true});
    expect(calls[1].body.reply).toBe('text');
  });
  it("says the teacher's wallet ran out as the teacher's, never as the student's wall", async () => {
    const fetchFn = (async () => reply(409, {success: false, code: 'teacher_credits', error: "Your teacher's credits for mastery levels have run out."})) as never;
    expect(await askMeta({backendUrl: 'x', token: () => 't', fetchFn}, {sitting: 'p', n: 1}, [], 'r')).toEqual({kind: 'refused', text: "Your teacher's credits for mastery levels have run out."});
  });
});

describe('the calls after the build', () => {
  // 30 Oct rehearsal: a teacher who sat their own exam pays for their own level; when that wallet was empty the lesson
  // screen said "check your internet" because the wall never reached the lesson writer
  it("a level paid from the learner's own wallet shows the credit wall when it runs out", async () => {
    const fetchFn = (async () => reply(402, {success: false, code: 'credits_exhausted', error: 'No managed credits remaining.', credits: 0})) as never;
    const w = new LessonWriter({backendUrl: 'https://x', token: () => 't', storage: mastery(), fetchFn});
    expect(await w.ask([{role: 'user', content: 'hi'}], 'r1', {pathId: 'custom-topic-abc'})).toEqual({kind: 'gated'});
    expect(w.gate()).not.toBeNull();
  });
  it('a mastery level asks the lesson writer on Meta; any other path keeps the house model', async () => {
    const urls: string[] = [];
    const fetchFn = (async (url: string) => { urls.push(url); return reply(200, {success: true, text: 'ok'}); }) as never;
    const w = new LessonWriter({backendUrl: 'https://x', token: () => 't', storage: mastery(), fetchFn, streamUrl: 'https://s/stream'});
    expect(await w.ask([{role: 'user', content: 'hi'}], 'r1', {pathId: 'custom-topic-abc'})).toEqual({kind: 'text', text: 'ok'});
    expect(urls).toEqual(['https://x/api/witness/design']);
    await w.ask([{role: 'user', content: 'hi'}], 'r2', {pathId: 'python-basics'});
    expect(urls.slice(1).some(u => u.includes('/api/witness/design'))).toBe(false);
  });
  // 29 Oct audit: the refusal came back as a plain failure, and the lesson screen told the student to check their internet
  it("a lesson the teacher's wallet can't pay for says so, in the edge's words; the next answer clears it", async () => {
    let n = 0;
    const fetchFn = (async () => (n++ === 0 ? reply(409, {success: false, code: 'teacher_credits', error: "Your teacher's credits for mastery levels have run out."}) : reply(200, {success: true, text: 'ok'}))) as never;
    const w = new LessonWriter({backendUrl: 'https://x', token: () => 't', storage: mastery(), fetchFn});
    expect(await w.ask([{role: 'user', content: 'hi'}], 'r1', {pathId: 'custom-topic-abc'})).toEqual({kind: 'failed'});
    expect(w.refused()).toBe("Your teacher's credits for mastery levels have run out.");
    expect(await w.ask([{role: 'user', content: 'hi'}], 'r2', {pathId: 'custom-topic-abc'})).toEqual({kind: 'text', text: 'ok'});
    expect(w.refused()).toBeNull();
  });
  it("a mastery level's flashcards are written on Meta", async () => {
    const bodies: Array<Record<string, unknown>> = [];
    const fetchFn = (async (_u: string, init?: {body?: string}) => { bodies.push(JSON.parse(String(init && init.body))); return reply(200, {success: true, text: '{"cards":[]}'}); }) as never;
    const w = new LessonWriter({backendUrl: 'https://x', token: () => 't', storage: mastery(), fetchFn});
    await makeDeck(w, {course: {pathId: 'custom-topic-abc', title: 'C', levels: []}, level: {id: 'l', title: 'L', modules: []}, count: 5} as never);
    expect(bodies[0]).toMatchObject({modelKey: 'muse-spark-1-3', for: {sitting: 'paper1', n: 3}});
  });
  it("Lo's live turn in a mastery level is Muse Spark's words", async () => {
    const bodies: Array<Record<string, unknown>> = [];
    const fetchFn = (async (_u: string, init?: {body?: string}) => { bodies.push(JSON.parse(String(init && init.body))); return reply(200, {success: true, text: ' Divide both by 16. '}); }) as never;
    const r = await liveTeach({backendUrl: 'https://x', token: async () => 't', fetchFn, route: {sitting: 'paper1', n: 3}},
      {pathTitle: 'P', lessonTitle: 'L', concept: 'c', actionCall: 'a', lastOutcome: 'first'} as never);
    expect(r).toEqual({ok: true, text: 'Divide both by 16.'});
    expect(bodies[0]).toMatchObject({reply: 'text', modelKey: 'muse-spark-1-3'});
  });
});

describe("the phone's copies of a paper's video go once it is marked (the screen's promise)", () => {
  it('deletes each copy once, and does nothing without the native door', () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const {forgetClips} = require('../src/witness/WitnessScreen');
    const gone: string[] = [];
    forgetClips(['file:///cache/shots/clip-1.mp4', 'file:///cache/shots/clip-small-1.mp4', 'file:///cache/shots/clip-1.mp4', ''], {removeFile: (u: string) => gone.push(u)});
    expect(gone).toEqual(['file:///cache/shots/clip-1.mp4', 'file:///cache/shots/clip-small-1.mp4']);
    expect(() => forgetClips(['x'], {})).not.toThrow();
  });
});

describe("a mastery level's animations are its calls too", () => {
  it('the first look, its lesson\'s other scenes and the main run name the paper; any other course does not', async () => {
    /* eslint-disable @typescript-eslint/no-var-requires */
    const {lessonMotion} = require('../src/game/LiveStep');
    const {MirrorStorage} = require('../src/state/storage');
    const {deepCourseFor} = require('../src/paths/deep');
    const {saveCustomCourse} = require('../src/paths/custom/course');
    /* eslint-enable @typescript-eslint/no-var-requires */
    const storage = new MirrorStorage(null);
    const base = deepCourseFor('web-foundations');
    for (const id of ['custom-topic-abc', 'custom-topic-other']) {
      saveCustomCourse(storage, {id, wayId: 'topic', sourceInput: 'x', createdAt: 1, course: {...base, pathId: id, title: 'Cancel factors'}});
    }
    storage.setItem(MASTERY_KEY, JSON.stringify({'paper1#3': 'custom-topic-abc'}));
    const lesson = 'deep-' + base.levels[0].modules[0].id;
    const fetch = jest.fn().mockResolvedValue({ok: true, scene: {title: 't', beats: [{type: 'process', title: 'L', nodes: [{id: 'a', label: 'A'}]}]}, fresh: true});
    await lessonMotion({env: {} as never, storage, pathId: 'custom-topic-abc', fetch}, lesson, 'opener').load();
    const opener = fetch.mock.calls[0][1];
    expect(opener.witness).toEqual({sitting: 'paper1', n: 3});
    expect((opener.ahead || []).every((a: {witness?: unknown}) => !!a.witness)).toBe(true);
    await lessonMotion({env: {} as never, storage, pathId: 'custom-topic-abc', fetch}, lesson, 'main').load();
    expect(fetch.mock.calls[1][1].witness).toEqual({sitting: 'paper1', n: 3});
    await lessonMotion({env: {} as never, storage, pathId: 'custom-topic-other', fetch}, lesson, 'main').load();
    expect(fetch.mock.calls[2][1].witness).toBeUndefined();
  });
});

describe("a mastery level's checkpoint opens its flashcards (29 Oct, live: it did nothing when tapped)", () => {
  it('a one-level course gets a flashcards stop, never a drill that cannot be made; it is done once the lessons are', () => {
    /* eslint-disable @typescript-eslint/no-var-requires */
    const {MirrorStorage} = require('../src/state/storage');
    const {deepCourseFor} = require('../src/paths/deep');
    const {saveCustomCourse} = require('../src/paths/custom/course');
    const {packForPath} = require('../src/paths/catalog');
    const {buildTrail, PRACTICE_MIN_TEMPLATES} = require('../src/map/nodes');
    /* eslint-enable @typescript-eslint/no-var-requires */
    const storage = new MirrorStorage(null);
    const base = deepCourseFor('web-foundations');
    const one = {...base, pathId: 'custom-topic-one', title: 'Cancel factors', levels: [base.levels[0]]};
    saveCustomCourse(storage, {id: 'custom-topic-one', wayId: 'topic', sourceInput: 'x', createdAt: 1, course: one});
    const pack = packForPath('custom-topic-one', 1, storage);
    expect(pack.practicePool.length).toBeLessThan(PRACTICE_MIN_TEMPLATES);
    const lessons = (pack.path.sections[0].skills || []).flatMap((k: {chapters: Array<{lessons: Array<{id: string}>}>}) => k.chapters.flatMap(c => c.lessons));
    const facts = {doneLessonIds: new Set<string>(lessons.map((l: {id: string}) => l.id)), checkpointsDone: new Set<string>(), projectDone: false, flashcards: true};
    const cps = buildTrail(pack, facts).units.flatMap((u: {nodes: Array<{kind: string; flashOnly?: boolean; state: string}>}) => u.nodes).filter((n: {kind: string}) => n.kind === 'checkpoint');
    expect(cps.length).toBe(1);
    expect(cps[0].flashOnly).toBe(true);
    expect(cps[0].state).toBe('done');
  });
});
