/**
 * WITNESS ON THE PHONE — the doors (2026-10-27, Meta hackathon; synced into the LoWisa app as src/witness/net.ts).
 *
 *   POST join                 {code, name?}          the teacher's exam, by its join code; with a name the student is on
 *                             the exam's class list, so the paper photographed after the exam reaches them by name
 *   POST sitting/start        {kind: 'photo', pages, code}   From Exam to Mastery (29 Oct): one phone (a teacher's or one
 *                             the school owns) photographs each finished paper; POST sitting/<id>/page sends each page
 *   GET  taken                the papers this phone photographed, with the name read from each
 *   POST sitting/start        {mime, size, code?, student?}  a signed upload for the desk video
 *   PUT  <signed url>                                the video, straight to storage (LoWisaDocuments.uploadFile)
 *   POST sitting/<id>/mark    {fps}                  SAM 3.1 and Muse Spark read it; the clip is deleted after
 *   GET  sitting/<id>         a paper of my own (homework, no code), its result once marked
 *   GET  mine                 my papers in teachers' exams: "with your teacher" until released, then the result;
 *                             the examiner's questions about my own steps as soon as the paper is marked
 *   POST sitting/<id>/answer  {k, audio?, mime?, text?}   my answer to one of them, out loud or written
 *   GET  sitting/<id>/asset/<file>   a still of my desk or my teacher's drawn step, once released
 *   GET  sitting/<id>/proof   my Proof of Thinking record, once released
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
export interface Step { t: number | null; wrote: string; crossed_out: boolean; line?: number; page?: number }
export interface Mastery {
  status: 'not_started' | 'building' | 'ready' | 'held' | 'completed' | 'badge' | 'not_yet';
  path?: string; asks?: {lo?: boolean; paper?: boolean; teacher?: boolean; fresh?: string}; explained?: string[]; lo_next?: string;
  fresh?: {status: 'uploading' | 'marking' | 'marked' | 'failed'};
  thread?: Array<{from: 'student' | 'teacher'; text: string; at: number}>; badge?: {issued: boolean; note: string; at: number};
  /** the teacher's new challenge (30 Oct): which option is right comes only with the student's own answer */
  challenge?: Challenge;
}
/** The Misconception Fingerprint (owner, 30 Oct): what reasoning produced the answer, the evidence, the repair; `ask`
 *  is Lo's diagnostic question when the paper alone was not enough, `said` the student's answers to it. */
export interface Fingerprint {
  reasoning: string; evidence: string[]; misconception: string; intervention: string; ask: string;
  /** the model's guess while Lo is still asking: for the teacher only, never shown to the student */
  possible?: string;
  said?: Array<{ask: string; text: string; at: number}>;
}
export interface Challenge { q: string; options: string[]; at: number; reply?: {pick: number; right: boolean; answer: number} }
export interface Ask { k: number; n: number; ask: string; wrote?: string; answered: boolean }
export interface Examiner { status: string; asks: Ask[] }
export interface Still { n: number; t: number | null; asset?: string; step?: string; page?: number }
export interface Question {
  mastery?: Mastery;
  comment?: {text: string; spoken?: boolean};
  drawn?: {status: 'drawing' | 'done' | 'failed'; asset?: string; lines?: string[]; changed?: number};
  n: number; result: Result; teacher_result?: Result; marks: number; teacher_marks?: number; out_of: number;
  final_answer: string; steps: Step[]; diagnosis: string; moment_s: number | null; confidence: number; focus?: string;
  fingerprint?: Fingerprint | null;
  /** the one or two of the seven thinking capabilities its mastery level builds (29 Oct) */
  capabilities?: string[];
  /** a photographed paper: the step (1 for the first) where the thinking went wrong */
  slip?: number | null;
}
/** A long video goes up in parts (2026-10-28): each part on its own link, so a dropped connection costs one part. */
export interface PartUrl { n: number; url: string }
export interface Parts { size: number; count: number; urls: PartUrl[] }
/** A "Turned around" badge: the question, what was turned around, and the days from going wrong to mastered. */
export interface Badge { question: string; fixed: string; exam: string; wrong_at: number | null; turned_at: number; note: string }
export interface Paper { id: string; status: string; unseen?: boolean; title?: string; student?: string; kind?: 'photo' | 'video'; result?: {questions: Question[]; stills?: Still[]}; examiner?: Examiner }
/** A paper this phone photographed for the class: the name read from it, and whether it found its student. */
export interface Taken { id: string; status: string; pages: number; got: number[]; title: string; created_ms: number; student: string;
  read: {name?: string; class?: string; number?: string; note?: string}; name_match: 'read' | 'teacher' | 'unsure' | 'none' | 'unread' | null }
export interface Proof {
  record: 'proof_of_thinking'; id: string; exam: string; level: string; kind: string; student: string;
  sat_ms: number | null; marked_ms: number | null; released_ms: number | null; marks: number; out_of: number; read_by: string[];
  /** 29 Oct: a photographed paper keeps its pages; a filmed one (Witness) keeps no video */
  source?: 'photo' | 'video'; pages?: number; video?: string;
  /** 28 Oct re-audit: mastered on the paper or turned around since, and how many were turned around */
  mastered?: number; turned_around?: number;
  questions: Array<{n: number; question: string; result: Result; teacher_result?: Result; marks: number; teacher_marks?: number; out_of: number;
    confidence: number; moment_s: number | null; diagnosis: string; steps: Step[]; still?: string; clip?: string; comment?: string; drawn?: {asset: string; lines: string[]};
    turned_around?: {from_ms: number | null; at: number; note: string}}>;
  examiner: Array<{k: number; n: number; ask: string; wrote?: string; answered: boolean; answer?: {text: string; spoken: boolean}}>;
}

/** The examiner's questions still to answer on a paper. */
export function asksLeft(p: Paper): Ask[] { return ((p.examiner && p.examiner.asks) || []).filter(a => !a.answered); }

/** The words a student sees (29 Oct, owner: From Exam to Mastery): no question ends in a verdict. A question is
 *  mastered, or it is in the student's Mastery Plan. */
export const RESULT_WORDS: Record<Result, string> = {
  mastered: 'Mastered',
  right_answer_wrong_thinking: 'In your Mastery Plan',
  part_way: 'In your Mastery Plan',
  not_yet: 'In your Mastery Plan',
};
/** Why a question is in the Mastery Plan, in one line (the diagnosis says what exactly). */
export const PLAN_WHY: Record<Result, string> = {
  mastered: '',
  right_answer_wrong_thinking: 'Your answer was right. The way you reached it goes in your Mastery Plan.',
  part_way: 'A good start. The rest of the thinking goes in your Mastery Plan.',
  not_yet: 'This goes in your Mastery Plan.',
};

/** 29 Oct (owner): LoWisa's teaching builds seven thinking capabilities, whether the exam was passed or not. */
export const CAPABILITIES: Record<string, string> = {
  'Pattern Recognition': 'Identify patterns, relationships, trends and recurring structures in problems and real-world situations.',
  'Probability & Uncertainty': "Understand likelihood, risk and uncertainty when outcomes aren't guaranteed.",
  'Optimization': 'Find the most effective solution while considering resources, constraints, time and cost.',
  'Systems Thinking': 'Understand how different components interact and how changes affect an entire system.',
  'Trade-offs': 'Evaluate competing priorities and understand what is gained or sacrificed when choosing between alternatives.',
  'Decision-Making': 'Apply evidence, logic and mathematical reasoning to select appropriate actions.',
  'Root Cause Analysis': 'Investigate problems systematically to identify underlying causes rather than symptoms.',
};
export function capabilitiesOf(q: Question): string[] { return (q.capabilities || []).filter(c => !!CAPABILITIES[c]).slice(0, 2); }

export function resultOf(q: Question): Result { return q.teacher_result || q.result; }
export function marksOf(q: Question): number { return typeof q.teacher_marks === 'number' ? q.teacher_marks : q.marks; }
export function toMaster(p: Paper): Question[] {
  // 28 Oct re-audit (the plan: a question turned around counts the same as one right the first time)
  // 29 Oct (owner): every question not mastered is in the Mastery Plan, part way included
  return ((p.result && p.result.questions) || []).filter(q => resultOf(q) !== 'mastered' && !turnedAround(q));
}

/** The teacher saw this question turned around (the badge). */
export function turnedAround(q: Question): boolean { return !!q.mastery && q.mastery.status === 'badge'; }

/** The join code as typed or pasted: upper case, only the code's letters, at most 6. */
export const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export function typedCode(input: string): string {
  return String(input || '').toUpperCase().split('').filter(ch => CODE_ALPHABET.indexOf(ch) >= 0).join('').slice(0, 6);
}

export async function door<T>(env: WitnessEnv, method: 'GET' | 'POST', path: string, body?: Record<string, unknown>, longMs?: number): Promise<Door<T>> {
  let token: string | null = null;
  try { token = await env.token(); } catch (e) { token = null; }
  if (!token) return {ok: false, error: 'Sign in first.', code: 'unauthorized', status: 401};
  let miss: EdgeMiss | null = null;
  const onMiss = (m: EdgeMiss) => { miss = m; };
  const timeoutMs = longMs || (method === 'GET' ? READ_MS : WRITE_MS);
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
    return {ok: false, error: 'From Exam to Mastery is not open on this account.', code: 'closed', status: 404};
  }
  return {ok: false, error: typeof j.error === 'string' ? j.error : 'Something went wrong. Try again.', code, status: r.status};
}

export const witness = {
  mine: (env: WitnessEnv) => door<{papers: Paper[]}>(env, 'GET', 'mine'),
  badges: (env: WitnessEnv) => door<{badges: Badge[]}>(env, 'GET', 'badges'),
  join: (env: WitnessEnv, code: string, name?: string) => door<{pile: {title: string; level: string; kind?: string}}>(env, 'POST', 'join', {code, ...(name ? {name} : {})}),
  /** a finished paper photographed page by page: started, each page sent (a photo is a few hundred KB: give it time) */
  startPhoto: (env: WitnessEnv, code: string, pages: number) => door<{id: string; pages: number}>(env, 'POST', 'sitting/start', {kind: 'photo', pages, code}),
  page: (env: WitnessEnv, id: string, n: number, mime: string, base64: string) =>
    door<{got: number[]; pages: number}>(env, 'POST', 'sitting/' + id + '/page', {n, mime, file: base64}, 90000),
  taken: (env: WitnessEnv) => door<{papers: Taken[]}>(env, 'GET', 'taken'),
  start: (env: WitnessEnv, size: number, mime: string, code?: string, student?: string, parts?: boolean) =>
    door<{id: string; put?: string; headers?: Record<string, string>; parts?: Parts}>(env, 'POST', 'sitting/start', {size, mime, ...(code ? {code} : {}), ...(student ? {student} : {}), ...(parts ? {parts: true} : {})}),
  /** a video in parts: which arrived, and fresh links for the rest */
  parts: (env: WitnessEnv, id: string) => door<{status?: string; size: number; count: number; done: number[]; urls: PartUrl[]}>(env, 'GET', 'sitting/' + id + '/parts'),
  mark: (env: WitnessEnv, id: string, fps: number) => door<{status: string}>(env, 'POST', 'sitting/' + id + '/mark', {fps}),
  paper: (env: WitnessEnv, id: string) => door<Paper>(env, 'GET', 'sitting/' + id),
  // a challenge's answer is read by Muse Spark before the reply: give it longer
  mastery: (env: WitnessEnv, paperId: string, n: number, action: 'event' | 'explain' | 'ask' | 'fresh' | 'challenge_answer' | 'diagnose', body: Record<string, unknown>) =>
    door<{mastery: Mastery; fresh?: {id: string; put: string}; fingerprint?: Fingerprint; diagnosis?: string}>(env, 'POST', 'mastery/' + paperId + '/' + n + '/' + action, body,
      action === 'challenge_answer' || action === 'diagnose' ? 45000 : undefined),
  check: (env: WitnessEnv, body: Record<string, unknown>) => door<{id: string}>(env, 'POST', 'check', body),
  // a spoken answer is heard (Voice Transcribe) and judged (Muse Spark) before the reply: give it longer
  answer: (env: WitnessEnv, id: string, body: {k: number; audio?: string; mime?: string; text?: string}) =>
    door<{examiner: Examiner}>(env, 'POST', 'sitting/' + id + '/answer', body, 45000),
  asset: (env: WitnessEnv, id: string, file: string) => door<{url: string}>(env, 'GET', 'sitting/' + id + '/asset/' + file),
  proof: (env: WitnessEnv, id: string) => door<Proof>(env, 'GET', 'sitting/' + id + '/proof'),
  checked: (env: WitnessEnv, id: string) => door<{status: string; verdict?: {passes: boolean; problems: Array<{lesson: number | null; fix: string}>}}>(env, 'GET', 'check/' + id),
};
