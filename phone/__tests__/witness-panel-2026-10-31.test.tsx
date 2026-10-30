/**
 * 31 Oct 2026 (the hackathon's 12-judge panel): the phone's part of the fixes.
 *  - the self-check names the paper and question it is for, and its id goes with the built level (the server holds the
 *    teacher to its own verdict, never the phone's word);
 *  - "Turned around" is followed by a re-check a few days later, answered with the student's own number and working.
 */
import React from 'react';
import TestRenderer, {act} from 'react-test-renderer';
import {selfCheck} from '../src/witness/mastery';
import {witness} from '../src/witness/net';
import type {Paper, Question} from '../src/witness/net';
import {RecheckCard, recheckWords} from '../src/witness/WitnessScreen';

jest.mock('../src/tutor/voice', () => ({tutorSay: jest.fn()}));

const q = {n: 4, result: 'not_yet', marks: 0, out_of: 3, final_answer: '$100', diagnosis: 'takes the second change of the original amount',
  steps: [{t: null, wrote: 'Half up, half down. Same price.', crossed_out: false}], moment_s: null, confidence: 0.9} as unknown as Question;
const paper = {id: 'abcdef0123456789', status: 'released', title: 'Year 9 Maths'} as Paper;

describe('the self-check is the server\'s', () => {
  it('names the question it is for and hands back its id', async () => {
    const check = jest.spyOn(witness, 'check').mockResolvedValue({ok: true, value: {id: 'chk1'}} as never);
    jest.spyOn(witness, 'checked').mockResolvedValue({ok: true, value: {status: 'done', verdict: {passes: true, problems: []}}} as never);
    const run = selfCheck({} as never, paper, q, async () => undefined);
    const v = await run({title: 'L', lessons: [{title: 'One', beats: ['b']}]} as never);
    expect(check.mock.calls[0][1]).toMatchObject({for: {sitting: 'abcdef0123456789', n: 4}});
    expect(v).toEqual({passes: true, problems: [], id: 'chk1'});
  });
});

describe('the re-check after Turned around', () => {
  it('says when it is due, and what came back', () => {
    expect(recheckWords(undefined)).toMatch(/solve a new one/);
    expect(recheckWords({status: 'scheduled', due_ms: Date.UTC(2026, 10, 7)})).toMatch(/Re-check on/);
    expect(recheckWords({status: 'passed'})).toMatch(/still right on the re-check/);
    expect(recheckWords({status: 'not_yet'})).toMatch(/one more look/);
  });
  it('takes the student\'s own number and working, never options', async () => {
    const act$ = jest.fn().mockResolvedValue({});
    let tree!: TestRenderer.ReactTestRenderer;
    await act(async () => { tree = TestRenderer.create(<RecheckCard r={{status: 'open', q: 'After a 20% rise a jacket costs $60. What did it cost before?', unit: '$'}} act={act$} />); });
    const value = tree.root.findByProps({testID: 'witness-recheck-value'});
    const working = tree.root.findByProps({testID: 'witness-recheck-working'});
    await act(async () => { value.props.onChangeText('50'); working.props.onChangeText('60 / 1.2 = 50'); });
    await act(async () => { tree.root.findByProps({testID: 'witness-recheck-send'}).props.onPress(); });
    expect(act$).toHaveBeenCalledWith('recheck_answer', {value: '50', working: '60 / 1.2 = 50'});
    expect(tree.root.findAll(n => typeof n.props.testID === 'string' && n.props.testID.indexOf('option') >= 0)).toHaveLength(0);
  });
  it('shows the right value only with the student\'s answer', async () => {
    let tree!: TestRenderer.ReactTestRenderer;
    await act(async () => { tree = TestRenderer.create(<RecheckCard r={{status: 'not_yet', q: 'x', unit: '$', reply: {value: 72, right: false, answer: 50}}} act={jest.fn()} />); });
    const said = tree.root.findByProps({testID: 'witness-recheck-result'});
    expect(JSON.stringify(said.props.children)).toMatch(/50/);
  });
});
