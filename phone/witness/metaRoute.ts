/**
 * WITNESS — every call a mastery level makes goes to Meta (29 Oct audit; synced into the LoWisa app as
 * src/witness/metaRoute.ts).
 *
 * The plan (1b, owner 27 Oct): the level is generated the way Master any topic generates a level, and "its calls for
 * mastery levels go to Meta's models". The build's design calls already did (course.ts designPath). The audit found
 * the calls made AFTER the build still went to the house model: the lessons written when the student opens them, the
 * flashcards, and Lo's live teaching turns. A path that is a mastery level now sends those to the same door as its
 * design calls: the edge's own metered call on Muse Spark, paid by the exam's teacher.
 */
import type {MirrorStorage} from '../state/storage';
import {classifyGate, type CreditGate} from '../billing/credits';

/** The model of every call of a mastery level (the edge's house-only Meta row, open to Witness accounts). */
export const MASTERY_MODEL = 'muse-spark-1-3';
/** Where a mastery level's calls go: the edge's own metered call on Muse Spark (behind the Witness switch). */
export const MASTERY_DESIGN_PATH = '/api/witness/design';
/** Which course each question's level became: {"<paper>#<n>": pathId}. */
export const MASTERY_KEY = 'lowisa-witness-mastery-v1';

/** The paper and question a mastery level was built for, from its path (the lesson player's "Ask my teacher"). */
export function masteryOfPath(storage: MirrorStorage, pathId: string): {paperId: string; n: number} | null {
  try {
    const m = JSON.parse(storage.getItem(MASTERY_KEY) || '{}') || {};
    for (const k of Object.keys(m)) {
      if (m[k] !== pathId) continue;
      const at = k.lastIndexOf('#'); const n = Number(k.slice(at + 1));
      if (at > 0 && Number.isInteger(n)) return {paperId: k.slice(0, at), n};
    }
  } catch (e) { /* nothing remembered */ }
  return null;
}

/** Who a mastery level's call is for: the paper (sitting) and question it was built from (the teacher pays). */
export interface MetaRoute { sitting: string; n: number }

export function metaRouteFor(storage: MirrorStorage, pathId: string | null | undefined): MetaRoute | null {
  if (!pathId) return null;
  const m = masteryOfPath(storage, pathId);
  return m ? {sitting: m.paperId, n: m.n} : null;
}

export type MetaAnswer = {kind: 'text'; text: string} | {kind: 'gated'; gate: CreditGate} | {kind: 'refused'; text: string} | {kind: 'failed'};

export interface MetaEnv {
  backendUrl: string;
  token(): Promise<string | null> | string | null;
  fetchFn?: typeof fetch;
  clientVersion?: string;
}

/** Room for one lesson section's JSON (a long section ran past 8,000 on the house model). */
const MAX_OUT = 12000;
/** Muse Spark writes a whole lesson section in one reply; the edge gives it 55 s. */
const TIMEOUT_MS = 70000;

/**
 * One call of a mastery level on Muse Spark. `text`: the reply is words (Lo's live turn), not JSON. Never throws.
 * The teacher's wallet running out comes back as `refused` with words for the student, never as the student's own wall.
 */
export async function askMeta(env: MetaEnv, route: MetaRoute, messages: Array<{role: 'system' | 'user'; content: string}>,
  requestId: string, opts?: {text?: boolean; maxOut?: number; timeoutMs?: number}): Promise<MetaAnswer> {
  const token = await Promise.resolve(env.token());
  if (!token) return {kind: 'failed'};
  const abort = typeof AbortController === 'function' ? new AbortController() : null;
  const bell = setTimeout(() => { try { if (abort) abort.abort(); } catch (e) { /* already gone */ } }, (opts && opts.timeoutMs) || TIMEOUT_MS);
  try {
    const res = await (env.fetchFn || fetch)(env.backendUrl + MASTERY_DESIGN_PATH, {
      signal: abort ? abort.signal : undefined,
      method: 'POST',
      headers: {'Content-Type': 'application/json', Authorization: 'Bearer ' + token, 'x-lowisa-client-version': env.clientVersion || 'mobile-dev'},
      body: JSON.stringify({
        requestId, modelKey: MASTERY_MODEL, for: route, messages,
        maxOutputTokens: (opts && opts.maxOut) || MAX_OUT,
        ...(opts && opts.text ? {reply: 'text'} : {}),
      }),
    });
    let body: {success?: boolean; text?: string; code?: string; error?: string} = {};
    try { body = await res.json(); } catch (e) { /* handled below */ }
    if (res.ok && body.success && typeof body.text === 'string' && body.text.trim()) return {kind: 'text', text: body.text};
    if (body.code === 'teacher_credits') return {kind: 'refused', text: String(body.error || '')};
    // the wall itself goes back with it, so the lesson shows the credit wall, not "check your internet" (30 Oct
    // rehearsal: a teacher who sat their own exam ran out of credits mid-level)
    const gate = classifyGate(res.status, body as Record<string, unknown>);
    if (gate) return {kind: 'gated', gate};
    return {kind: 'failed'};
  } catch (e) {
    return {kind: 'failed'};
  } finally {
    clearTimeout(bell);
  }
}
