/**
 * WITNESS ON THE PHONE — the doors (2026-10-27, Meta hackathon; synced into the LoWisa app as src/witness/net.ts).
 *
 *   POST join                 {code}                 the teacher's exam, by its join code
 *   POST sitting/start        {mime, size, code?, student?}  a signed upload for the desk video
 *   PUT  <signed url>                                the video, straight to storage (LoWisaDocuments.uploadFile)
 *   POST sitting/<id>/mark    {fps}                  SAM 3.1 and Muse Spark read it; the clip is deleted after
 *   GET  sitting/<id>         a paper of my own (homework, no code), its result once marked
 *   GET  mine                 my papers in teachers' exams: "with your teacher" until released, then the result
 *
 * Off LOWISA_WITNESS_ACCESS the edge answers its unknown route, read here as `closed`: the app shows nothing of Witness.
 */
import {callViaEdge, EdgeMiss} from '../live/edge';
import type {CommunityEnv} from '../community/net';
import {UNREACHABLE} from '../community/net';

export type WitnessEnv = CommunityEnv;
export type Door<T> = {ok: true; value: T} | {ok: false; error: string; code?: string; status?: number};

export const BASE = '/api/witness/';
const READ_MS = 15000;
const WRITE_MS = 20000;

export type Result = 'mastered' | 'right_answer_wrong_thinking' | 'part_way' | 'not_yet';
export interface Step { t: number | null; wrote: string; crossed_out: boolean; line?: number }
export interface Question {
  n: number; result: Result; teacher_result?: Result; marks: number; teacher_marks?: number; out_of: number;
  final_answer: string; steps: Step[]; diagnosis: string; moment_s: number | null; confidence: number; focus?: string;
}
export interface Paper { id: string; status: string; title?: string; student?: string; result?: {questions: Question[]} }

/** The words a student sees: a failed question is never "failed", it is the next thing they master. */
export const RESULT_WORDS: Record<Result, string> = {
  mastered: 'Mastered',
  right_answer_wrong_thinking: 'Right answer, thinking to fix',
  part_way: 'Part way there',
  not_yet: 'Next to master',
};

export function resultOf(q: Question): Result { return q.teacher_result || q.result; }
export function marksOf(q: Question): number { return typeof q.teacher_marks === 'number' ? q.teacher_marks : q.marks; }
export function toMaster(p: Paper): Question[] {
  return ((p.result && p.result.questions) || []).filter(q => { const r = resultOf(q); return r === 'not_yet' || r === 'right_answer_wrong_thinking'; });
}

/** The join code as typed or pasted: upper case, only the code's letters, at most 6. */
export const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export function typedCode(input: string): string {
  return String(input || '').toUpperCase().split('').filter(ch => CODE_ALPHABET.indexOf(ch) >= 0).join('').slice(0, 6);
}

export async function door<T>(env: WitnessEnv, method: 'GET' | 'POST', path: string, body?: Record<string, unknown>): Promise<Door<T>> {
  let token: string | null = null;
  try { token = await env.token(); } catch (e) { token = null; }
  if (!token) return {ok: false, error: 'Sign in first.', code: 'unauthorized', status: 401};
  let miss: EdgeMiss | null = null;
  const onMiss = (m: EdgeMiss) => { miss = m; };
  const timeoutMs = method === 'GET' ? READ_MS : WRITE_MS;
  let r: {status: number; json: Record<string, unknown>} | null = null;
  try {
    r = await callViaEdge(env, method, BASE + path, body,
      method === 'GET' ? {token, timeoutMs, answer5xx: true, edgeOnly: true, declines: true, onMiss}
                       : {token, timeoutMs, live: null, answer5xx: true, edgeOnly: true, declines: true, onMiss});
  } catch (e) { r = null; }
  if (!r) {
    const m = miss as EdgeMiss | null;
    if (m && m.kind === 'timeout') return {ok: false, error: 'It took too long. The connection may be slow: try again.', code: 'timeout'};
    return {ok: false, error: UNREACHABLE, code: 'unreachable'};
  }
  const j = r.json || {};
  if (r.status >= 200 && r.status < 300 && j.ok !== false) return {ok: true, value: j as unknown as T};
  const code = typeof j.code === 'string' ? j.code : undefined;
  // the edge's unknown route (or the API behind it): Witness is not open on this account
  if (r.status === 404 && (code === 'not_found' || j.error === 'not_found' || (!code && typeof j.error !== 'string'))) {
    return {ok: false, error: 'Witness is not open on this account.', code: 'closed', status: 404};
  }
  return {ok: false, error: typeof j.error === 'string' ? j.error : 'Something went wrong. Try again.', code, status: r.status};
}

export const witness = {
  mine: (env: WitnessEnv) => door<{papers: Paper[]}>(env, 'GET', 'mine'),
  join: (env: WitnessEnv, code: string) => door<{pile: {title: string; level: string}}>(env, 'POST', 'join', {code}),
  start: (env: WitnessEnv, size: number, mime: string, code?: string, student?: string) =>
    door<{id: string; put: string; headers: Record<string, string>}>(env, 'POST', 'sitting/start', {size, mime, ...(code ? {code} : {}), ...(student ? {student} : {})}),
  mark: (env: WitnessEnv, id: string, fps: number) => door<{status: string}>(env, 'POST', 'sitting/' + id + '/mark', {fps}),
  paper: (env: WitnessEnv, id: string) => door<Paper>(env, 'GET', 'sitting/' + id),
};
