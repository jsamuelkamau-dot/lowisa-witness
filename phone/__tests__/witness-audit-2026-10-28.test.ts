/**
 * WITNESS audit (2026-10-28): the Turned around badge on the profile names the days from going wrong to mastered.
 */
import {journey} from '../src/witness/TurnedAround';
import {masteryOfPath, MASTERY_KEY} from '../src/witness/mastery';
import {NativeModules} from 'react-native';
import {canSendParts, sendParts} from '../src/witness/WitnessScreen';

describe('Turned around on the profile', () => {
  it('shows the days from going wrong to mastered, or the one day', () => {
    const wrong = Date.UTC(2026, 9, 12, 12), turned = Date.UTC(2026, 9, 28, 12);
    const day = (ms: number) => new Date(ms).toLocaleDateString(undefined, {day: 'numeric', month: 'short'});
    expect(journey(wrong, turned)).toBe(day(wrong) + ' to ' + day(turned));
    expect(journey(turned, turned)).toBe(day(turned));
    expect(journey(null, turned)).toBe(day(turned));
  });
});

describe('Ask my teacher from inside the level', () => {
  it('finds the paper and question a level was built for, and nothing for any other path', () => {
    const store: Record<string, string> = {[MASTERY_KEY]: JSON.stringify({'abc123#3': 'custom-topic-x', 'abc123#1': 'custom-topic-y'})};
    const storage = {getItem: (k: string) => store[k] ?? null, setItem: (k: string, v: string) => { store[k] = v; }, removeItem: (k: string) => { delete store[k]; }} as any;
    expect(masteryOfPath(storage, 'custom-topic-x')).toEqual({paperId: 'abc123', n: 3});
    expect(masteryOfPath(storage, 'deep-python')).toBeNull();
  });
});

describe('a long video goes up in parts', () => {
  const mods = NativeModules as Record<string, unknown>;
  const noWait = () => Promise.resolve();
  afterEach(() => { delete mods.LoWisaDocuments; });

  it('sends each part from its own offset, the last one short', async () => {
    const uploadPart = jest.fn().mockResolvedValue(200);
    mods.LoWisaDocuments = {uploadPart};
    expect(canSendParts()).toBe(true);
    const done: number[] = [];
    await expect(sendParts('file:///v.mp4', 20, 8, [{n: 1, url: 'u1'}, {n: 2, url: 'u2'}, {n: 3, url: 'u3'}], d => done.push(d), noWait)).resolves.toBe(true);
    expect(uploadPart.mock.calls).toEqual([['file:///v.mp4', 'u1', 0, 8], ['file:///v.mp4', 'u2', 8, 8], ['file:///v.mp4', 'u3', 16, 4]]);
    expect(done).toEqual([1, 2, 3]);
  });

  it('tries a part three times, stops at one that still fails, and never retries a refused link', async () => {
    const uploadPart = jest.fn().mockResolvedValueOnce(200).mockRejectedValueOnce(new Error('reset')).mockResolvedValueOnce(503).mockResolvedValueOnce(0);
    mods.LoWisaDocuments = {uploadPart};
    await expect(sendParts('f', 24, 8, [{n: 1, url: 'a'}, {n: 2, url: 'b'}, {n: 3, url: 'c'}], undefined, noWait)).resolves.toBe(false);
    expect(uploadPart).toHaveBeenCalledTimes(4);              // part 1 once, part 2 three times, part 3 never
    const refused = jest.fn().mockResolvedValue(403);
    mods.LoWisaDocuments = {uploadPart: refused};
    await expect(sendParts('f', 8, 8, [{n: 1, url: 'a'}], undefined, noWait)).resolves.toBe(false);
    expect(refused).toHaveBeenCalledTimes(1);
  });

  it('an older phone without the part upload sends the video whole', () => {
    mods.LoWisaDocuments = {uploadFile: jest.fn()};
    expect(canSendParts()).toBe(false);
  });
});


describe('a mastery rewrite can rename the lesson its self-check named', () => {
  // 28 Oct, live: lesson 3 stayed "Failed Digit Cancellation Example" through every rewrite (its outline title was kept)
  const {pairLevel} = require('../src/paths/custom/course');
  const reply = {modules: [{title: 'Your step at the till', beats: [1]}, {title: 'Digits are not numbers', beats: [2]}, {title: 'Write the £14 sale ticket', beats: [3]}]};
  const slot = {levelTitle: 'Cancel factors right', moduleTitles: ['Your step at the till', 'Digits are not numbers', 'Failed Digit Cancellation Example']};
  it('keeps the outline titles on a first writing, takes the new one on a rewrite', () => {
    expect(pairLevel(slot, reply).modules.map((m: {title: string}) => m.title)[2]).toBe('Failed Digit Cancellation Example');
    const again = pairLevel(slot, reply, true);
    expect(again.modules.map((m: {title: string}) => m.title)).toEqual(['Your step at the till', 'Digits are not numbers', 'Write the £14 sale ticket']);
    expect(again.modules[2].beats).toEqual([3]);
  });
  it('never takes an empty or overlong title', () => {
    const odd = {modules: [{title: '  ', beats: [1]}, {title: 'x'.repeat(81), beats: [2]}, {beats: [3]}]};
    expect(pairLevel(slot, odd, true).modules.map((m: {title: string}) => m.title)).toEqual(slot.moduleTitles);
  });
});
