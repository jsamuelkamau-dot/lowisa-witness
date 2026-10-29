/**
 * WITNESS — the Exam Desk's doors (2026-10-27, Meta hackathon; the desk itself is lowisa-witness's desk/witness-desk.js,
 * synced in as src/renderer-parts/27-witness-desk.js).
 *
 * The edge holds the switch (LOWISA_WITNESS_ACCESS): off it every /api/witness/ path answers the unknown route, so the
 * desk asks `witness:hello` (GET /api/witness/piles) once per account and adds nothing to the IDE unless it gets a 200.
 *
 *   witness:hello   {userId} -> {on}
 *   witness:call    {userId, method, path, body} -> {status, json}   one of the doors below, never anything else
 */
import type { IpcMain } from 'electron';
import { fetchEdgeFirst } from './edge-http';

export interface WitnessIpcDeps {
  token(userId: string): Promise<string | null>;
  fetchImpl?: typeof fetch;
  env?: NodeJS.ProcessEnv;
}

const HEX16 = '[0-9a-f]{16}';
const DOORS: Array<[string, RegExp]> = [
  ['GET', /^\/api\/witness\/piles$/],
  ['POST', /^\/api\/witness\/pile$/],
  ['GET', new RegExp(`^/api/witness/pile/${HEX16}$`)],
  ['POST', new RegExp(`^/api/witness/pile/${HEX16}/release$`)],
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}$`)],
  ['POST', new RegExp(`^/api/witness/sitting/${HEX16}/review$`)],
  // Mark again: a paper Meta could not mark is marked from its kept video (28 Oct); a paper already marked is never marked twice
  ['POST', new RegExp(`^/api/witness/sitting/${HEX16}/mark$`)],
  // 2026-10-27: the drawn corrected step, the spoken comment, a paper's pictures, its Proof of Thinking, the exam's numbers
  ['POST', new RegExp(`^/api/witness/sitting/${HEX16}/(draw|voice)$`)],
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}/asset/(still|drawn|step|world)-[0-9]{1,3}\.(jpg|webp)$`)],
  // 28 Oct re-audit: the six-second clips, and the student's spoken answers kept for the teacher (owner)
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}/asset/clip-[0-9]{1,3}\.mp4$`)],
  // 29 Oct (From Exam to Mastery): a photographed paper's pages, and the teacher saying whose paper it is
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}/asset/page-[0-9]{1,2}\.(jpg|png|webp)$`)],
  ['POST', new RegExp(`^/api/witness/sitting/${HEX16}/student$`)],
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}/asset/(answer-[0-9]{1,3}|explain-(lo|teacher)-[0-9]{1,3})\.(m4a|aac|wav|webm|ogg|mp3)$`)],
  ['POST', new RegExp(`^/api/witness/pile/read$`)],
  ['POST', new RegExp(`^/api/witness/pile/${HEX16}/patterns$`)],
  ['GET', new RegExp(`^/api/witness/sitting/${HEX16}/proof$`)],
  ['GET', new RegExp(`^/api/witness/pile/${HEX16}/measure$`)],
  // the teacher's side of a question after release: which checks, an answer in the thread, the badge
  ['POST', new RegExp(`^/api/witness/mastery/${HEX16}/[0-9]{1,3}/(verify|reply|badge|approve|recommend)$`)],
];
const MAX_BODY = 64 * 1024;
// 28 Oct re-audit: a photo or PDF of the teacher's paper or scheme (10 MB on the edge), as base64
const MAX_FILE = 14 * 1024 * 1024;
// a spoken comment travels as base64 audio (a few minutes); every other desk request stays small
const MAX_VOICE = 6 * 1024 * 1024;
const CALL_TIMEOUT_MS = 30000;
// 30 Oct (film take): Muse Spark reading a teacher's whole exam file, or weighing a level, can pass 30 s; those
// calls get the edge's own minute and a half, every other desk call stays at 30 s
const LONG_CALL_MS = 90000;
const LONG_CALLS = [/^\/api\/witness\/pile\/read$/, /^\/api\/witness\/pile\/[0-9a-f]+\/patterns$/, /^\/api\/witness\/mastery\/[0-9a-f]+\/\d+\/recommend$/];

export function witnessDoor(method: unknown, p: unknown): { method: 'GET' | 'POST'; path: string } | null {
  if ((method !== 'GET' && method !== 'POST') || typeof p !== 'string' || p.length > 200) return null;
  return DOORS.some(([m, re]) => m === method && re.test(p)) ? { method, path: p } : null;
}

function backendUrl(env: NodeJS.ProcessEnv): string {
  return env.CREDIT_BACKEND_URL || 'https://api.lowisa.dev';
}

export function registerWitnessIPC(ipcMain: IpcMain, deps: WitnessIpcDeps): void {
  const env = deps.env || process.env;
  const fetchImpl = deps.fetchImpl || fetch;
  const on = new Map<string, boolean>();

  const request = async (userId: string, method: 'GET' | 'POST', p: string, body?: unknown): Promise<{ status: number; json: any }> => {
    const token = userId ? await deps.token(userId) : null;
    if (!token) return { status: 401, json: { ok: false, code: 'signed_out', error: 'Sign in to LoWisa first.' } };
    const init: RequestInit = { method, headers: { authorization: 'Bearer ' + token, ...(method === 'POST' ? { 'content-type': 'application/json' } : {}) } };
    if (method === 'POST') init.body = JSON.stringify(body === undefined ? {} : body);
    try {
      const signal = typeof AbortSignal !== 'undefined' && typeof (AbortSignal as any).timeout === 'function' ? (AbortSignal as any).timeout(LONG_CALLS.some((re) => re.test(p)) ? LONG_CALL_MS : CALL_TIMEOUT_MS) : undefined;
      if (signal) (init as any).signal = signal;
      const res = await fetchEdgeFirst(backendUrl(env), p, init, fetchImpl);
      let json: any = null;
      try { json = await res.json(); } catch { json = null; }
      return { status: res.status, json };
    } catch {
      return { status: 0, json: { ok: false, code: 'offline', error: 'LoWisa could not reach the Exam Desk. Check your connection and try again.' } };
    }
  };

  ipcMain.handle('witness:hello', async (_e, req: { userId?: string } = {}) => {
    const userId = typeof req.userId === 'string' ? req.userId : '';
    if (!userId) return { on: false };
    const r = await request(userId, 'GET', '/api/witness/piles');
    const yes = r.status === 200 && !!r.json && r.json.ok === true;
    on.set(userId, yes);
    return { on: yes };
  });

  ipcMain.handle('witness:call', async (_e, req: { userId?: string; method?: string; path?: string; body?: unknown } = {}) => {
    const userId = typeof req.userId === 'string' ? req.userId : '';
    if (!on.get(userId)) return { status: 0, json: { ok: false, code: 'off', error: 'The Exam Desk is not open for this account.' } };
    const door = witnessDoor(req.method, req.path);
    if (!door) return { status: 0, json: { ok: false, code: 'not_a_door', error: 'That is not an Exam Desk request.' } };
    const limit = /\/voice$/.test(door.path) ? MAX_VOICE : /\/pile\/read$/.test(door.path) ? MAX_FILE : MAX_BODY;
    if (door.method === 'POST' && JSON.stringify(req.body === undefined ? {} : req.body).length > limit) {
      return { status: 0, json: { ok: false, code: 'too_big', error: 'That is too much to send at once.' } };
    }
    return request(userId, door.method, door.path, req.body);
  });
}
