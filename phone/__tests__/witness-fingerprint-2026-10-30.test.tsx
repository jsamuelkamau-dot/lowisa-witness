/**
 * The Misconception Fingerprint on the phone (owner, 30 Oct): "not simply whether the answer is correct, but what
 * reasoning produced it, what evidence supports the diagnosis, and which intervention can repair it". A misconception is
 * named only when the written work holds enough evidence; otherwise Lo asks a diagnostic question, out loud, first.
 */
import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import {LoAsks, spokenFeedback, whatShows} from '../src/witness/WitnessScreen';
import {fingerprintLines, masteryBrief} from '../src/witness/mastery';
import {onTutorSay} from '../src/tutor/voice';
import type {Fingerprint, Paper, Question} from '../src/witness/net';

const C: Fingerprint = {reasoning: 'An intuition with no numbers.', evidence: ['Half up, half down. Same price.'], misconception: 'intuition that the changes cancel',
  intervention: 'Write each step as numbers.', ask: "You wrote 'half up, half down' - half of which amount each time?"};
const byId = (r: ReactTestRenderer.ReactTestRenderer, id: string) => r.root.find(n => n.props.testID === id && (typeof n.props.onPress === 'function' || typeof n.props.onChangeText === 'function'));

describe('Lo asks first', () => {
  it('says the question out loud, and sends the written answer', async () => {
    const heard: string[] = [];
    const off = onTutorSay(l => heard.push(l));
    const send = jest.fn(async () => true);
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => { r = ReactTestRenderer.create(<LoAsks fp={C} send={send} />); });
    await new Promise(res => setTimeout(res, 10));
    off();
    expect(heard).toContain(C.ask);
    expect(JSON.stringify(r.toJSON())).toContain('Lo asks first');
    await ReactTestRenderer.act(async () => { byId(r, 'witness-lo-asks-send').props.onPress(); });
    expect(send).not.toHaveBeenCalled();
    await ReactTestRenderer.act(async () => { byId(r, 'witness-lo-asks-text').props.onChangeText('Half of 100, both times.'); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-lo-asks-send').props.onPress(); });
    expect(send).toHaveBeenCalledWith({text: 'Half of 100, both times.'});
  });
});

describe('the level is built around the fingerprint', () => {
  it('names the idea, the evidence, what they told Lo and the intervention', () => {
    const lines = fingerprintLines({...C, said: [{ask: C.ask, text: 'Half of 100, both times.', at: 1}]}).join('\n');
    expect(lines).toContain('THE MISCONCEPTION (from the evidence below; the whole level repairs this one idea): intuition that the changes cancel');
    expect(lines).toContain('Half up, half down. Same price.');
    expect(lines).toContain('the student said: "Half of 100, both times."');
    expect(lines).toContain('THE INTERVENTION (build the lessons around it): Write each step as numbers.');
    const paper = {id: 'p', title: 'Mathematics: Percentages and Money'} as unknown as Paper;
    const q = {n: 4, result: 'not_yet', steps: [{wrote: 'Half up, half down. Same price.', crossed_out: false, t: null}], diagnosis: 'd', final_answer: '$100', fingerprint: C} as unknown as Question;
    expect(masteryBrief(paper, q).context).toContain('THE INTERVENTION (build the lessons around it)');
    expect(fingerprintLines(null)).toEqual([]);
  });
});

describe('what the student is shown went wrong', () => {
  it('is the completed fingerprint once Lo asked, and nothing before that (judges panel, 30 Oct)', () => {
    const q = {n: 4, result: 'not_yet', marks: 0, out_of: 3, diagnosis: 'Believes the changes cancel.', fingerprint: C} as unknown as Question;
    expect(whatShows(q)).toBeNull();
    expect(whatShows({...q, fingerprint: {...C, ask: ''}} as Question)).toEqual({label: 'What your working shows', text: 'Believes the changes cancel.'});
    const asked = {...C, ask: '', misconception: 'second percentage taken of the original amount', said: [{ask: C.ask, text: 'Half of 100 both times.', at: 1}]};
    expect(whatShows(q, asked)).toEqual({label: 'What your working and your answer to Lo show', text: 'second percentage taken of the original amount'});
    expect(spokenFeedback(q, asked)).toContain('What your working and your answer to Lo show: second percentage taken of the original amount');
  });
});

// 30 Oct (judges' panel): while Lo asks, the student is shown no idea; once answered, the level and its self-check work
// from what the answer settled, not from the marking's first reading
describe('nothing is named while Lo asks', () => {
  const q = {n: 4, result: 'not_yet', marks: 0, out_of: 3, diagnosis: 'Could be cancelling, or both halves of $100.', steps: []} as unknown as Question;
  it('shows no label until Lo has an answer', () => {
    expect(whatShows(q, {...C, misconception: '', possible: 'cancel'})).toBeNull();
    expect(spokenFeedback(q, {...C, misconception: ''})).not.toContain('What your working shows');
  });
  it('builds from the settled idea', () => {
    const settled: Fingerprint = {...C, ask: '', misconception: 'second change taken of the original amount', reasoning: 'Takes both halves of $100.',
      said: [{ask: C.ask, text: 'Both halves of 100.', at: 1}]};
    const brief = masteryBrief({id: 'p', title: 'Maths'} as unknown as Paper, {...q, fingerprint: settled});
    expect(brief.input).toBe('One mastery level: second change taken of the original amount: Takes both halves of $100');
    expect(whatShows(q, settled)).toEqual({label: 'What your working and your answer to Lo show', text: 'second change taken of the original amount'});
  });
});
