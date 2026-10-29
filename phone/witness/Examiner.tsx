/**
 * WITNESS — two questions back, about the student's own work (2026-10-27, Meta hackathon).
 *
 * As soon as a paper is marked, Muse Wonder asks the student about steps they wrote themselves ("You wrote
 * 120 × 1.5. Why did you multiply here?"). The student answers out loud, in the language they think in (Muse Voice
 * Transcribe hears it on the server), or in writing; Muse Spark judges the answer for the teacher. The student never
 * sees a verdict here: their marks come when the teacher releases the paper.
 */
import React, {useEffect, useRef, useState} from 'react';
import {ActivityIndicator, PermissionsAndroid, Platform, StyleSheet, Text, TextInput, View} from 'react-native';
import {Btn} from '../exam/print/ui';
import {cancelRecording, readRecording, recorderAvailable, removeRecording, RECORDING_MIME, startRecording, stopRecording} from '../voice/recorder';
import {Ask, Examiner, witness, WitnessEnv} from './net';
import {tutorSay} from '../tutor/voice';
import {KEPT_WORDS} from './SayIt';

/** An answer is a sentence or two; the recording stops on its own after this. */
export const ANSWER_SECONDS = 90;

export function AsksView({env, paperId, title, examiner, onDone}: {env: WitnessEnv; paperId: string; title: string; examiner: Examiner; onDone(): void}): React.JSX.Element {
  const [asks, setAsks] = useState<Ask[]>(examiner.asks);
  const left = asks.filter(a => !a.answered);
  // Lo asks the next question out loud (28 Oct audit: the plan has Lo's voice ask them; they were text only), once each
  const next = left.length ? left[0] : null;
  useEffect(() => { if (next) tutorSay(next.ask); }, [next && next.k]); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <View style={s.card} testID="witness-asks">
      <Text style={s.h}>{asks.length === 1 ? 'A question about your work' : 'Two questions about your work'}</Text>
      <Text style={s.sub}>Before your teacher looks at {title || 'your paper'}, you're asked about steps you wrote. Answer in your own words, out loud or in writing, in the language you think in.</Text>
      {asks.map(a => <AskCard key={a.k} a={a} env={env} paperId={paperId} onAnswered={ex => setAsks(ex.asks)} />)}
      {left.length === 0 ? (
        <View style={{marginTop: 12}}>
          <Text style={s.done}>Thank you. Your answers are with your teacher.</Text>
          <Btn label="Done" onPress={onDone} primary testID="witness-asks-done" />
        </View>
      ) : null}
    </View>
  );
}

function AskCard({a, env, paperId, onAnswered}: {a: Ask; env: WitnessEnv; paperId: string; onAnswered(ex: Examiner): void}): React.JSX.Element {
  const [mode, setMode] = useState<'idle' | 'recording' | 'sending'>('idle');
  const [text, setText] = useState('');
  const [said, setSaid] = useState('');
  const alive = useRef(true);
  useEffect(() => () => { alive.current = false; if (mode === 'recording') cancelRecording(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  if (a.answered) {
    return (
      <View style={s.ask} testID={'witness-ask-' + a.k}>
        <Text style={s.q}>{a.ask}</Text>
        <Text style={s.small}>Answered.</Text>
      </View>
    );
  }
  const send = async (body: {audio?: string; mime?: string; text?: string}) => {
    setMode('sending'); setSaid('');
    const r = await witness.answer(env, paperId, {k: a.k, ...body});
    if (!alive.current) return;
    setMode('idle');
    if (r.ok) onAnswered(r.value.examiner); else setSaid(r.error);
  };
  const record = async () => {
    setSaid('');
    if (Platform.OS === 'android') {
      // 28 Oct (owner): the recording is kept with the paper for the teacher to hear; the student is told so first
      try {
        const g = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO, {
          title: 'Answer out loud', message: KEPT_WORDS,
          buttonPositive: 'Allow', buttonNegative: 'Not now'});
        if (g !== PermissionsAndroid.RESULTS.GRANTED) { setSaid('LoWisa needs the microphone to hear you. You can write your answer instead.'); return; }
      } catch (e) { return; }
    }
    const st = await startRecording(ANSWER_SECONDS, 'phrase');
    if (!st.ok) { setSaid(st.text); return; }
    setMode('recording');
  };
  const stop = async () => {
    setMode('sending');
    const rec = await stopRecording();
    if (rec.kind !== 'ok') { setSaid(rec.text); setMode('idle'); return; }
    const audio = await readRecording(rec.path);
    removeRecording(rec.path);
    if (!audio) { setSaid('Nothing was recorded. Try again, or write it.'); setMode('idle'); return; }
    await send({audio, mime: RECORDING_MIME});
  };
  return (
    <View style={s.ask} testID={'witness-ask-' + a.k}>
      <Text style={s.q}>{a.ask}</Text>
      {a.wrote ? <Text style={s.wrote}>{a.wrote}</Text> : null}
      <Btn label="Hear the question" onPress={() => tutorSay(a.ask)} small testID={'witness-ask-hear-' + a.k} />
      {mode === 'sending' ? (
        <View style={s.row}><ActivityIndicator /><Text style={s.small}> Listening to your answer…</Text></View>
      ) : mode === 'recording' ? (
        <View>
          <Text style={s.live}>Recording. Say it in your own words.</Text>
          <Btn label="Stop and send" onPress={stop} primary testID={'witness-ask-stop-' + a.k} />
        </View>
      ) : (
        <View>
          {recorderAvailable() ? <Btn label="Answer out loud" onPress={record} primary testID={'witness-ask-say-' + a.k} /> : null}
          <TextInput value={text} onChangeText={setText} placeholder="Or write your answer" multiline maxLength={2000}
            style={s.input} accessibilityLabel={'Your answer to: ' + a.ask} testID={'witness-ask-text-' + a.k} />
          <Btn label="Send my answer" onPress={() => { if (text.trim()) send({text: text.trim()}); else setSaid('Say or write your answer first.'); }} small testID={'witness-ask-send-' + a.k} />
        </View>
      )}
      {said ? <Text style={s.error} accessibilityRole="alert">{said}</Text> : null}
    </View>
  );
}

const s = StyleSheet.create({
  card: {backgroundColor: '#fff', borderRadius: 12, padding: 14, marginTop: 12, borderWidth: 1, borderColor: '#e6e8ef'},
  h: {fontSize: 17, fontWeight: '700', color: '#141a2e'},
  sub: {fontSize: 14, color: '#4a5266', marginTop: 4, lineHeight: 20},
  small: {fontSize: 13, color: '#4a5266', marginTop: 6},
  ask: {marginTop: 14, paddingTop: 12, borderTopWidth: 1, borderTopColor: '#eef0f5'},
  q: {fontSize: 16, fontWeight: '600', color: '#141a2e', lineHeight: 22},
  wrote: {fontFamily: 'monospace', fontSize: 14, color: '#1b2a6b', backgroundColor: '#f4efe2', padding: 8, borderRadius: 6, marginTop: 8, marginBottom: 8, overflow: 'hidden'},
  input: {borderWidth: 1, borderColor: '#d6d9e3', borderRadius: 8, padding: 10, marginTop: 10, marginBottom: 6, minHeight: 60, fontSize: 15, color: '#141a2e', textAlignVertical: 'top'},
  row: {flexDirection: 'row', alignItems: 'center', marginTop: 8},
  live: {fontSize: 14, color: '#b3261e', fontWeight: '600', marginBottom: 8},
  done: {fontSize: 15, color: '#2e7d32', fontWeight: '600', marginBottom: 8},
  error: {fontSize: 14, color: '#b3261e', marginTop: 8},
});
