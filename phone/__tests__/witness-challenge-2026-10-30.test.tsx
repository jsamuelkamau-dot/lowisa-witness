/**
 * The teacher's new challenge on the phone (owner, 30 Oct): "After LoWisa helps the learner understand the initial
 * problem, the teacher can present new challenges that measure whether the learner has genuinely understood the
 * principle rather than memorised the answer", and the learner receives it. The student picks an answer and says why,
 * once; Lo reads it out on request; which option is right shows only with their own answer.
 */
import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import {ChallengeCard} from '../src/witness/WitnessScreen';
import {onTutorSay} from '../src/tutor/voice';

const WATER = {
  q: 'A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?',
  options: ['910 litres', '1,000 litres', '1,090 litres'], at: 1,
};
const text = (r: ReactTestRenderer.ReactTestRenderer) => JSON.stringify(r.toJSON());
const byId = (r: ReactTestRenderer.ReactTestRenderer, id: string) => r.root.find(n => n.props.testID === id && typeof n.props.onPress === 'function' || n.props.testID === id && typeof n.props.onChangeText === 'function');

describe('the new challenge on the phone', () => {
  it('sends one answer with its reason, only once both are given', async () => {
    const act = jest.fn(async () => ({}));
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => { r = ReactTestRenderer.create(<ChallengeCard c={WATER} act={act} />); });
    expect(text(r)).toContain('A new challenge from your teacher');
    expect(text(r)).toContain('1,000 litres of stored water');
    // nothing goes until an answer is picked and a reason written
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-send').props.onPress(); });
    expect(act).not.toHaveBeenCalled();
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-option-0').props.onPress(); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-send').props.onPress(); });
    expect(act).not.toHaveBeenCalled();
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-why').props.onChangeText('30% of 700 is only 210, so 910.'); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-send').props.onPress(); });
    expect(act).toHaveBeenCalledWith('challenge_answer', {pick: 0, why: '30% of 700 is only 210, so 910.'});
  });

  it('lets Lo read the challenge out, with its options', async () => {
    const heard: string[] = [];
    const off = onTutorSay(line => heard.push(line));
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => { r = ReactTestRenderer.create(<ChallengeCard c={WATER} act={jest.fn()} />); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-challenge-hear').props.onPress(); await new Promise(res => setTimeout(res, 5)); });
    off();
    expect(heard.pop()).toBe(WATER.q + ' 1: 910 litres. 2: 1,000 litres. 3: 1,090 litres.');
  });

  it('shows the right answer only with their own, and takes no second answer', async () => {
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => {
      r = ReactTestRenderer.create(<ChallengeCard c={{...WATER, reply: {pick: 1, right: false, answer: 0}}} act={jest.fn()} />);
    });
    expect(text(r)).toContain('Not this time: the right answer is 910 litres.');
    expect(r.root.findAll(n => n.props.testID === 'witness-challenge-send')).toHaveLength(0);
    await ReactTestRenderer.act(async () => {
      r.update(<ChallengeCard c={{...WATER, reply: {pick: 0, right: true, answer: 0}}} act={jest.fn()} />);
    });
    expect(text(r)).toContain('Right. Your teacher has your answer and your reason.');
  });
});
