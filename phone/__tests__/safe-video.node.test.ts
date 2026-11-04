// 4 Nov 2026 (second independent audit: "CI does not run the phone's tests"): the rule that decides whether a desk video
// may leave the phone, tested on its own with Node's own test runner, so this repository's CI runs it on every push.
//   node --test phone/__tests__/safe-video.node.test.ts        (Node 23.6 or later reads TypeScript directly)
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {safeVideo} from '../witness/safeVideo.ts';

const big = {name: 'clip-1.mp4', mime: 'video/mp4', size: 120e6, uri: 'file:///cache/shots/clip-1.mp4'};
const small = {name: 'clip-small-2.mp4', mime: 'video/mp4', size: 8e6, uri: 'file:///cache/shots/clip-small-2.mp4'};
const answers = (a: unknown) => async () => a;

test('a copy the look made, faces checked, is sent', async () => {
  assert.deepEqual(await safeVideo(big, answers({...small, faces: 'checked'})), {status: 'verified', file: small});
});

test('the original goes only when the look says checked and the same file', async () => {
  assert.deepEqual(await safeVideo(big, answers({faces: 'checked', same: true})), {status: 'verified', file: big});
});

test('no look on this phone (iPhone today) is blocked', async () => {
  assert.equal((await safeVideo(big, undefined)).status, 'blocked');
});

test('a look that failed is blocked', async () => {
  const r = await safeVideo(big, async () => { throw new Error('faces_failed'); });
  assert.deepEqual(r, {status: 'blocked', reason: 'face_look_failed'});
});

test('an empty or unclear answer is never taken as "send the original"', async () => {
  for (const a of [null, undefined, 0, '', 'checked', {}, {same: true}, {faces: 'skipped', same: true}, {faces: true, same: true},
                   {faces: 'checked'}, {faces: 'checked', uri: ''}, small]) {
    const r = await safeVideo(big, answers(a));
    assert.equal(r.status, 'blocked', 'answer ' + JSON.stringify(a));
  }
});

test('the look is asked about the file itself', async () => {
  let asked = '';
  await safeVideo(big, async (uri: string) => { asked = uri; return {faces: 'checked', same: true}; });
  assert.equal(asked, big.uri);
});
