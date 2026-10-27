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
import type {Paper, Question, WitnessEnv} from './net';
import {resultOf, witness} from './net';

/** The model of every design call of a mastery level (the edge's house-only Meta row, open to Witness accounts). */
export const MASTERY_MODEL = 'muse-spark-1-3';
/** Where a mastery level's design calls go: the edge's own metered call on Muse Spark (behind the Witness switch). */
export const MASTERY_DESIGN_PATH = '/api/witness/design';
/** Which course each question's level became: {"<paper>#<n>": pathId}. */
export const MASTERY_KEY = 'lowisa-witness-mastery-v1';

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

/** A mastery level (a one-level course) is done once the course record counts its level complete. */
export function masteryDone(storage: MirrorStorage, pathId: string): boolean {
  try { const p = readCourseStore(storage).courses[pathId]; return !!p && Number(p.completed) >= 1; } catch (e) { return false; }
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
    resultOf(q) === 'right_answer_wrong_thinking' ? 'The final answer was right, but the method was wrong: the level must show why the method fails on a case where it gives the wrong answer.' : '',
    q.focus ? 'THE TEACHER\'S FOCUS NOTE: ' + q.focus : '',
    level ? 'THE STUDENT\'S LEVEL: ' + level : '',
  ].filter(Boolean).join('\n\n');
  return {input, context};
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
export async function buildMastery(env: CustomEnv & WitnessEnv, storage: MirrorStorage, paper: Paper, q: Question, level?: string, wait?: (ms: number) => Promise<void>): Promise<CustomCourseResult & {checked: SelfCheck | null}> {
  const {input, context} = masteryBrief(paper, q, level);
  const check = selfCheck(env, paper, q, wait);
  let checked: SelfCheck | null = null;
  const masteryCheck = async (l: MasteryLevelText) => { checked = await check(l); return checked; };
  const made = await createCustomCourse({...env, designModel: MASTERY_MODEL, designPath: MASTERY_DESIGN_PATH, mastery: true, masteryCheck}, storage, 'topic', input, {context});
  if (made.ok && made.pathId) remember(storage, paper.id, q.n, made.pathId);
  return {...made, checked};
}
