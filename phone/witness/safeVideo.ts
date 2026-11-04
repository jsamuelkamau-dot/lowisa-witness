/**
 * WITNESS — whether a desk video may leave the phone (4 Nov 2026, second independent audit). No imports, so the rule is
 * tested on its own, in this repository's CI (phone/__tests__/safe-video.node.test.ts), as well as in LoWisa's app.
 *
 * The phone's face look (LoWisaDocuments.smallVideo, native) answers explicitly. A video is sent only when it answered
 * `faces: "checked"`: the look ran to the end, and any face found is covered in the copy it made. `same: true` means the
 * original may go as it is (a copy the phone made already, or a small video with no face in it). Every other answer is
 * blocked: no look on this phone (iPhone today), a look that failed, an empty answer, or anything not said explicitly.
 */
export type SafeVideo<F> = {status: 'verified'; file: F} | {status: 'blocked'; reason: 'no_face_look' | 'face_look_failed' | 'not_verified'};

export async function safeVideo<F extends {uri: string}>(file: F, look: ((uri: string) => Promise<unknown>) | undefined): Promise<SafeVideo<F>> {
  if (typeof look !== 'function') return {status: 'blocked', reason: 'no_face_look'};
  let r: unknown;
  try { r = await look(file.uri); } catch (e) { return {status: 'blocked', reason: 'face_look_failed'}; }
  if (!r || typeof r !== 'object') return {status: 'blocked', reason: 'not_verified'};
  const a = r as {faces?: unknown; same?: unknown; uri?: unknown};
  if (a.faces !== 'checked') return {status: 'blocked', reason: 'not_verified'};
  if (a.same === true) return {status: 'verified', file};
  if (typeof a.uri !== 'string' || !a.uri) return {status: 'blocked', reason: 'not_verified'};
  const {faces, same, ...copy} = a as Record<string, unknown>;
  return {status: 'verified', file: copy as unknown as F};
}
