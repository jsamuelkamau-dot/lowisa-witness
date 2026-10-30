/**
 * WITNESS (2026-10-27, judges' eyes: Impact): a phone camera records some 120 MB a minute at 1080p, which the Android
 * camera app stopped at 58 MB, about thirty seconds into a paper, and which costs a student real money on phone data.
 * Pinned here: the desk video goes through smallVideo (720p, ten frames a second) before it is sent, and the original
 * goes when the phone cannot make it smaller or it is small already. On a weak connection the upload is tried three
 * times, and a refused link is not tried again. When Android stops the app during a recording (a camera grant given
 * "Only this time" lapses), the recording the camera app wrote is offered again for the exam it was made for.
 */
import {DeviceEventEmitter, NativeModules} from 'react-native';
import {keptRecording, PENDING_KEY, readPending, readyLine, sendClip, smaller} from '../src/witness/WitnessScreen';
import {MirrorStorage} from '../src/state/storage';

const big = {name: 'clip-1.mp4', mime: 'video/mp4', size: 120 * 1024 * 1024, uri: 'file:///cache/shots/clip-1.mp4'};
const small = {name: 'clip-small-2.mp4', mime: 'video/mp4', size: 8 * 1024 * 1024, uri: 'file:///cache/shots/clip-small-2.mp4'};
const mods = NativeModules as Record<string, unknown>;

describe('Witness sends a small desk video', () => {
  afterEach(() => { delete mods.LoWisaDocuments; });

  it('sends the small copy the phone made', async () => {
    const smallVideo = jest.fn().mockResolvedValue(small);
    mods.LoWisaDocuments = {smallVideo};
    await expect(smaller(big)).resolves.toBe(small);
    expect(smallVideo).toHaveBeenCalledWith(big.uri);
  });

  it('sends the original when it is small already, when making it smaller fails, or on a phone without it', async () => {
    mods.LoWisaDocuments = {smallVideo: jest.fn().mockResolvedValue(null)};
    await expect(smaller(big)).resolves.toBe(big);
    mods.LoWisaDocuments = {smallVideo: jest.fn().mockRejectedValue(new Error('small_failed'))};
    await expect(smaller(big)).resolves.toBe(big);
    mods.LoWisaDocuments = {};
    await expect(smaller(big)).resolves.toBe(big);
  });

  it('tries the upload three times on a weak connection, and a refused link once', async () => {
    const wait = jest.fn().mockResolvedValue(undefined);
    const uploadFile = jest.fn().mockRejectedValueOnce(new Error('timeout')).mockResolvedValueOnce(503).mockResolvedValueOnce(200);
    mods.LoWisaDocuments = {uploadFile};
    await expect(sendClip(small.uri, 'https://put', 'video/mp4', wait)).resolves.toBe(200);
    expect(uploadFile).toHaveBeenCalledTimes(3);
    expect(wait.mock.calls).toEqual([[2000], [6000]]);
    const refused = jest.fn().mockResolvedValue(403);
    mods.LoWisaDocuments = {uploadFile: refused};
    await expect(sendClip(small.uri, 'https://put', 'video/mp4', wait)).resolves.toBe(403);
    expect(refused).toHaveBeenCalledTimes(1);
    mods.LoWisaDocuments = {uploadFile: jest.fn().mockResolvedValue(0)};
    await expect(sendClip(small.uri, 'https://put', 'video/mp4', wait)).resolves.toBe(0);
  });

  it('tells the student how far the small copy is', async () => {
    let finish: (v: unknown) => void = () => {};
    mods.LoWisaDocuments = {smallVideo: jest.fn(() => new Promise(r => { finish = r; }))};
    const seen: number[] = [];
    const going = smaller(big, p => seen.push(p));
    DeviceEventEmitter.emit('lowisaSmallVideo', {percent: 41.6});
    DeviceEventEmitter.emit('lowisaSmallVideo', {percent: 130});
    finish(small);
    await expect(going).resolves.toBe(small);
    DeviceEventEmitter.emit('lowisaSmallVideo', {percent: 99});
    expect(seen).toEqual([42, 100]);
  });

  it('says when it is looking for faces to cover, then making it smaller (28 Oct)', async () => {
    let finish: (v: unknown) => void = () => {};
    mods.LoWisaDocuments = {smallVideo: jest.fn(() => new Promise(r => { finish = r; }))};
    const lines: string[] = [];
    const going = smaller(big, (p, st) => lines.push(readyLine(p, st)));
    DeviceEventEmitter.emit('lowisaSmallVideo', {stage: 'faces', percent: 50});
    DeviceEventEmitter.emit('lowisaSmallVideo', {stage: 'small', percent: 10});
    finish(small);
    await going;
    expect(lines).toEqual(['Covering any face the camera caught… 50%', 'Making the video smaller to send… 10%']);
  });

  it('finds the recording a stopped app left for the exam it was made for', async () => {
    const storage = new MirrorStorage(null);
    const now = 1_800_000_000_000;
    const lastClip = jest.fn().mockResolvedValue(big);
    mods.LoWisaDocuments = {lastClip};
    await expect(keptRecording(storage, now)).resolves.toBeNull();
    expect(lastClip).not.toHaveBeenCalled();
    storage.setItem(PENDING_KEY, JSON.stringify({code: 'GSNZP2', title: 'Fractions check', level: 'Year 7', name: 'Tom', at: now - 60_000}));
    await expect(keptRecording(storage, now)).resolves.toEqual({pending: expect.objectContaining({code: 'GSNZP2', name: 'Tom'}), clip: big});
    expect(lastClip).toHaveBeenCalledWith(now - 62_000);
    expect(readPending(storage, now + 7 * 3600 * 1000)).toBeNull();
    lastClip.mockResolvedValue(null);
    await expect(keptRecording(storage, now)).resolves.toBeNull();
    storage.setItem(PENDING_KEY, '{broken');
    expect(readPending(storage, now)).toBeNull();
  });
});
