/**
 * WITNESS — one mastery level for one question a student did not master (2026-10-27, Meta hackathon; synced into
 * the LoWisa app as src/witness/mastery.ts).
 *
 * Owner (27 Oct): the level is generated exactly as Master any topic generates a level, to the same standard and with
 * everything a level has, but it is ONE level, for that question and that student. So the build IS the Master any
 * topic build (createCustomCourse, topic), with three things set: the material (the question, the student's own
 * working, where the thinking went wrong, the teacher's focus note), the mastery rule (one level, the student's own step
 * running in a real-world setting first), and Meta's Muse Spark as the model of every design call.
 */
import type {MirrorStorage} from '../state/storage';
import {readCourseStore} from '../course/store';
import {createCustomCourse, CustomCourseResult, CustomEnv, MasteryLevelText} from '../paths/custom/course';
import type {Fingerprint, Paper, Question, WitnessEnv} from './net';
import {CAPABILITIES, capabilitiesOf, resultOf, witness} from './net';

export {MASTERY_MODEL, MASTERY_DESIGN_PATH, MASTERY_KEY, masteryOfPath} from './metaRoute';
import {MASTERY_MODEL, MASTERY_DESIGN_PATH, MASTERY_KEY} from './metaRoute';

export function masteryKey(paperId: string, n: number): string { return paperId + '#' + n; }

/** The level's course for a question, when it was built on this phone. */
export function masteryPath(storage: MirrorStorage, paperId: string, n: number): string | null {
  try { const m = JSON.parse(storage.getItem(MASTERY_KEY) || '{}'); const v = m[masteryKey(paperId, n)]; return typeof v === 'string' ? v : null; }
  catch (e) { return null; }
}

function remember(storage: MirrorStorage, paperId: string, n: number, pathId: string): void {
  let m: Record<string, string> = {};
  try { m = JSON.parse(storage.getItem(MASTERY_KEY) || '{}') || {}; } catch (e) { m = {}; }
  m[masteryKey(paperId, n)] = pathId;
  storage.setItem(MASTERY_KEY, JSON.stringify(m));
}

/** The mastery levels finished on this phone: every lesson's questions and the flashcards (29 Oct, owner). */
export const MASTERY_DONE_KEY = 'lowisa-witness-mastery-done-v1';

/**
 * A mastery level (a one-level course) is done once its lessons and its flashcard deck are finished on the path. 29 Oct,
 * live: the level is played on the path map, which never moved the course record's count, so the teacher never heard.
 */
export function masteryDone(storage: MirrorStorage, pathId: string): boolean {
  try { const d = JSON.parse(storage.getItem(MASTERY_DONE_KEY) || '[]'); if (Array.isArray(d) && d.includes(pathId)) return true; } catch (e) { /* none yet */ }
  try { const p = readCourseStore(storage).courses[pathId]; return !!p && Number(p.completed) >= 1; } catch (e) { return false; }
}

/** The path map's deck closed on a level whose lessons are all done: the level is finished (the badge may open). */
export function markMasteryDone(storage: MirrorStorage, pathId: string): void {
  let d: string[] = [];
  try { const v = JSON.parse(storage.getItem(MASTERY_DONE_KEY) || '[]'); if (Array.isArray(v)) d = v.filter(x => typeof x === 'string'); } catch (e) { d = []; }
  if (!d.includes(pathId)) storage.setItem(MASTERY_DONE_KEY, JSON.stringify(d.concat(pathId).slice(-200)));
}

/** What a level's build found (its self-check, the outline the teacher looks at), kept until the teacher has it: 29 Oct,
 * live, the news of a fresh level was lost to one dropped connection and the open sent it again without them. */
export const BUILT_KEY = 'lowisa-witness-built-v1';
export type BuiltNews = {check: SelfCheck | null; level: MasteryLevelText | null};
export function keepBuilt(storage: MirrorStorage, pathId: string, news: BuiltNews): void {
  let m: Record<string, BuiltNews> = {};
  try { m = JSON.parse(storage.getItem(BUILT_KEY) || '{}') || {}; } catch (e) { m = {}; }
  m[pathId] = news;
  const keys = Object.keys(m);
  for (const k of keys.slice(0, Math.max(0, keys.length - 20))) delete m[k];
  storage.setItem(BUILT_KEY, JSON.stringify(m));
}
export function builtNews(storage: MirrorStorage, pathId: string): BuiltNews | null {
  try { const v = (JSON.parse(storage.getItem(BUILT_KEY) || '{}') || {})[pathId]; return v && typeof v === 'object' ? v as BuiltNews : null; }
  catch (e) { return null; }
}

/** What the build is asked (the composer's line) and its material (pure, for tests). */
export function masteryBrief(paper: Paper, q: Question, level?: string): {input: string; context: string} {
  const working = (q.steps || []).map(s => (s.crossed_out ? '(crossed out) ' : '') + s.wrote).join('\n') || '(nothing written)';
  const idea = q.diagnosis || 'the idea behind this question';
  const input = 'One mastery level: ' + idea.replace(/\.$/, '');
  const context = [
    'THE QUESTION: question ' + q.n + (paper.title ? ' of "' + paper.title + '"' : '') + (q.final_answer ? ' (the student answered ' + q.final_answer + ')' : '') + '.',
    'HOW THE STUDENT WORKED IT, in the order written:\n' + working,
    'WHERE THE THINKING WENT WRONG: ' + idea,
    // 30 Oct (owner): the Misconception Fingerprint. The level repairs THIS idea, by its intervention, not the topic
    ...fingerprintLines(q.fingerprint),
    resultOf(q) === 'right_answer_wrong_thinking' ? 'The final answer was right, but the method was wrong: the level must show why the method fails on a case where it gives the wrong answer.' : '',
    resultOf(q) === 'part_way' ? 'The student started right but did not show (or reach) the whole method: the level must make every step of the thinking visible.' : '',
    q.focus ? 'THE TEACHER\'S FOCUS NOTE: ' + q.focus : '',
    // 29 Oct (owner): every level builds named thinking capabilities, whether the exam was passed or not
    capabilitiesOf(q).length ? 'THE THINKING CAPABILITIES THIS LEVEL BUILDS (practise them by name in the real-world task): '
      + capabilitiesOf(q).map(c => c + ' (' + CAPABILITIES[c] + ')').join('; ') : '',
    level ? 'THE STUDENT\'S LEVEL: ' + level : '',
  ].filter(Boolean).join('\n\n');
  return {input, context};
}

/** The fingerprint for the level's writer: the named idea, the evidence, what the student told Lo, the repair. */
export function fingerprintLines(f?: Fingerprint | null): string[] {
  if (!f) return [];
  const said = (f.said || []).map(x => 'Lo asked "' + x.ask + '"; the student said: "' + x.text + '"').join('\n');
  return [
    f.misconception ? 'THE MISCONCEPTION (from the evidence below; the whole level repairs this one idea): ' + f.misconception : '',
    f.reasoning ? 'THE REASONING THAT PRODUCED THE ANSWER: ' + f.reasoning : '',
    (f.evidence || []).length ? 'THE EVIDENCE, in the student\'s own words:\n' + (f.evidence || []).join('\n') : '',
    said ? 'WHAT THE STUDENT TOLD LO:\n' + said : '',
    f.intervention ? 'THE INTERVENTION (build the lessons around it): ' + f.intervention : '',
  ].filter(Boolean);
}

/** The self-check waits at most this long for Muse Wonder's verdict, then the level is kept as written. */
export const CHECK_WAIT_MS = 120000;

/** Muse Wonder plays the written level as both students (the edge's POST check, then its verdict). */
export function selfCheck(env: WitnessEnv, paper: Paper, q: Question, wait: (ms: number) => Promise<void> = ms => new Promise(r => setTimeout(r, ms))) {
  return async (level: MasteryLevelText): Promise<{passes: boolean; problems: string[]} | null> => {
    const working = (q.steps || []).map(s => (s.crossed_out ? '(crossed out) ' : '') + s.wrote).join('\n');
    const asked = await witness.check(env, {question: 'Question ' + q.n + (paper.title ? ' of ' + paper.title : ''), working, diagnosis: q.diagnosis || '', focus: q.focus || '', level});
    if (!asked.ok) return null;
    for (let waited = 0; waited < CHECK_WAIT_MS; waited += 4000) {
      await wait(4000);
      const r = await witness.checked(env, asked.value.id);
      if (!r.ok || r.value.status === 'failed') return null;
      if (r.value.status === 'done' && r.value.verdict) {
        const v = r.value.verdict;
        return {passes: v.passes === true, problems: (v.problems || []).map(p => (p.lesson ? 'lesson ' + p.lesson + ': ' : '') + p.fix)};
      }
    }
    return null;
  };
}

/** Builds the level with the Master any topic build, checks it as both students, and remembers it for the question. */
export type SelfCheck = {passes: boolean; problems: string[]};

/** Builds the level with the Master any topic build, checks it as both students, and remembers it for the question.
 * `checked` is the kept level's last verdict (the build checks its final rewrite too), null when no check answered. */
export async function buildMastery(env: CustomEnv & WitnessEnv, storage: MirrorStorage, paper: Paper, q: Question, level?: string, wait?: (ms: number) => Promise<void>): Promise<CustomCourseResult & {checked: SelfCheck | null; outline: MasteryLevelText | null}> {
  const {input, context} = masteryBrief(paper, q, level);
  const check = selfCheck(env, paper, q, wait);
  let checked: SelfCheck | null = null;
  // the level as it was last checked is the one kept: its outline goes to the teacher (28 Oct: the teacher's preview)
  let outline: MasteryLevelText | null = null;
  const masteryCheck = async (l: MasteryLevelText) => { outline = l; checked = await check(l); return checked; };
  const made = await createCustomCourse({...env, designModel: MASTERY_MODEL, designPath: MASTERY_DESIGN_PATH, designFor: {sitting: paper.id, n: q.n}, mastery: true, masteryCheck}, storage, 'topic', input, {context});
  if (made.ok && made.pathId) { remember(storage, paper.id, q.n, made.pathId); keepBuilt(storage, made.pathId, {check: checked, level: outline}); }
  return {...made, checked, outline};
}
