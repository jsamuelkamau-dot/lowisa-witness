/**
 * The photographing code on the phone (31 Oct, rehearsal): since the judges' panel the server refuses the students'
 * join code for photographing papers, but the phone still sent it and had nowhere to type the photographing code.
 * The photographing code typed in the code box opens the exam for photographing; an exam opened with the join code
 * asks for the photographing code before a paper goes up. Papers listed are this exam's, by code, not by title.
 */
import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import {PhotoDesk} from '../src/witness/WitnessScreen';
import {witness} from '../src/witness/net';

jest.mock('../src/career/documents', () => ({
  takePhoto: jest.fn(async () => null),
  pickImagesSafely: jest.fn(async () => ({kind: 'ok', docs: [{name: 'p1.jpg', mime: 'image/jpeg', base64: 'AAAA'}]})),
}));

const env = {} as never;
const text = (r: ReactTestRenderer.ReactTestRenderer) => JSON.stringify(r.toJSON());
const byId = (r: ReactTestRenderer.ReactTestRenderer, id: string) =>
  r.root.find(n => n.props.testID === id && (typeof n.props.onPress === 'function' || typeof n.props.onChangeText === 'function'));

describe('photographing the papers', () => {
  beforeEach(() => {
    jest.spyOn(witness, 'taken').mockResolvedValue({ok: true, value: {papers: [
      {id: 'a', status: 'marked', pages: 2, got: [1, 2], title: 'Maths', code: 'DEMOJN', photo_code: 'DEMOPH', created_ms: 1, student: 'Leo Martins', read: {}, name_match: 'read'},
      {id: 'b', status: 'marked', pages: 2, got: [1, 2], title: 'Maths', code: 'TESTJN', photo_code: 'K2K2K2', created_ms: 1, student: 'Priya Nair', read: {}, name_match: 'read'},
    ]}} as never);
  });
  afterEach(() => jest.restoreAllMocks());

  it('opened with the join code, it asks for the photographing code and sends that one', async () => {
    const start = jest.spyOn(witness, 'startPhoto').mockResolvedValue({ok: false, error: 'stop here', code: 'x', status: 400} as never);
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => { r = ReactTestRenderer.create(<PhotoDesk env={env} code="DEMOJN" title="Maths" photo={false} />); });
    expect(text(r)).toContain('It is not the students');
    expect(text(r)).toContain('Leo Martins');
    expect(text(r)).not.toContain('Priya Nair');   // the other exam with the same title
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-pick').props.onPress(); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-send').props.onPress(); });
    expect(start).not.toHaveBeenCalled();
    expect(text(r)).toContain('Type the photographing code');
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-code').props.onChangeText('demoph'); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-send').props.onPress(); });
    expect(start).toHaveBeenCalledWith(env, 'DEMOPH', 1);
  });

  it('opened with the photographing code, it asks for nothing more', async () => {
    const start = jest.spyOn(witness, 'startPhoto').mockResolvedValue({ok: false, error: 'stop here', code: 'x', status: 400} as never);
    let r!: ReactTestRenderer.ReactTestRenderer;
    await ReactTestRenderer.act(async () => { r = ReactTestRenderer.create(<PhotoDesk env={env} code="DEMOPH" title="Maths" photo />); });
    expect(r.root.findAll(n => n.props.testID === 'witness-photo-code')).toHaveLength(0);
    expect(text(r)).toContain('Leo Martins');
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-pick').props.onPress(); });
    await ReactTestRenderer.act(async () => { byId(r, 'witness-photo-send').props.onPress(); });
    expect(start).toHaveBeenCalledWith(env, 'DEMOPH', 1);
  });
});
