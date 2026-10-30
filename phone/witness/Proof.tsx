/**
 * WITNESS — what the student keeps (2026-10-27, Meta hackathon).
 *
 *   Replay       the steps they wrote appear again at their own pace, and stop at the moment the thinking went wrong
 *   Picture      a still of their desk at that moment, or the corrected step Muse Image drew (once released)
 *   ProofView    the Proof of Thinking record: dated, every answer's steps and times, the marks, the examiner's
 *                questions with their own answers; the video itself was deleted when the paper was marked
 */
import React, {useEffect, useRef, useState} from 'react';
import {ActivityIndicator, Image, StyleSheet, Text, View} from 'react-native';
import {C} from '../ui/theme';
import {WebView} from 'react-native-webview';
import {Btn} from '../exam/print/ui';
import {Proof, Question, RESULT_WORDS, Step, witness, WitnessEnv} from './net';

export function clock(t: number | null | undefined): string {
  const x = Math.max(0, Math.round(Number(t) || 0));
  return Math.floor(x / 60) + ':' + ('0' + (x % 60)).slice(-2);
}

/** The step written when the thinking went wrong: the last one finished by that second (pure, for tests). */
export function slipIndex(steps: Step[], moment: number | null): number {
  if (moment == null) return -1;
  let at = -1;
  steps.forEach((st, i) => { if (st.t != null && st.t <= moment + 1) at = i; });
  return at < 0 && steps.length ? 0 : at;
}

/** How long the replay waits before a step: the real gap, four times faster, between 0.4 s and 1.6 s (pure). */
export function replayGaps(steps: Step[]): number[] {
  return steps.map((st, i) => {
    const prev = i ? steps[i - 1].t : 0;
    const gap = st.t != null && prev != null ? (st.t - prev) * 250 : 800;
    return Math.max(400, Math.min(1600, gap));
  });
}

/** shows: what to say went wrong (WitnessScreen's whatShows: the completed fingerprint once Lo asked); the diagnosis by default. */
export function Replay({q, shows}: {q: Question; shows?: {label: string; text: string} | null}): React.JSX.Element {
  const steps = q.steps || [];
  const [shown, setShown] = useState(steps.length);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);
  // a photographed paper (29 Oct) has no times: its steps show as written, the slip is the step Spark named
  const timed = steps.some(st => typeof st.t === 'number');
  const slip = timed ? slipIndex(steps, q.moment_s) : (typeof q.slip === 'number' && q.slip >= 1 ? q.slip - 1 : -1);
  const play = () => {
    if (timer.current) clearTimeout(timer.current);
    const gaps = replayGaps(steps);
    setShown(0);
    const next = (i: number) => { timer.current = setTimeout(() => { setShown(i + 1); if (i + 1 < steps.length) next(i + 1); }, gaps[i]); };
    next(0);
  };
  return (
    <View testID={'witness-replay-' + q.n}>
      {steps.slice(0, shown).map((st, i) => (
        <View key={i} style={[s.stepRow, i === slip ? s.slipRow : null]}>
          {timed ? <Text style={s.time}>{clock(st.t)}</Text> : null}
          <Text style={[s.step, st.crossed_out ? s.crossed : null]}>{st.wrote}</Text>
        </View>
      ))}
      {slip >= 0 && shown > slip && (shows || q.diagnosis) ? <Text style={s.diag}>{timed ? 'At ' + clock(q.moment_s) + ': ' : (shows ? shows.label + ': ' : 'What your working shows: ')}{shows ? shows.text : q.diagnosis}</Text> : null}
      {timed && steps.length > 1 ? <Btn label="Replay how I worked" onPress={play} small testID={'witness-replay-play-' + q.n} /> : null}
    </View>
  );
}

export function Picture({env, paperId, file, label, testID}: {env: WitnessEnv; paperId: string; file: string; label: string; testID?: string}): React.JSX.Element | null {
  const [url, setUrl] = useState<string | null>(null);
  const [gone, setGone] = useState(false);
  // the picture takes its own shape (29 Oct, live: a wide answer cut from a photographed page sat in a square of paper)
  const [ratio, setRatio] = useState(1);
  useEffect(() => {
    let live = true;
    witness.asset(env, paperId, file).then(r => { if (!live) return; if (r.ok) setUrl(r.value.url); else setGone(true); });
    return () => { live = false; };
  }, [env, paperId, file]);
  useEffect(() => {
    if (!url) return undefined;
    let live = true;
    Image.getSize(url, (w, h) => { if (live && w > 0 && h > 0) setRatio(Math.max(0.5, Math.min(6, w / h))); }, () => undefined);
    return () => { live = false; };
  }, [url]);
  if (gone) return null;
  if (!url) return <ActivityIndicator style={{marginVertical: 10}} />;
  return <Image source={{uri: url}} style={[s.picture, {aspectRatio: ratio}]} resizeMode="contain" accessibilityLabel={label} testID={testID} />;
}

/** Six seconds of the desk around a moment that matters (28 Oct re-audit: the research's record keeps "short clips at the
 *  moments that matter" once the video is deleted), played in a web view from its short-lived link. */
export function Clip({env, paperId, file, label}: {env: WitnessEnv; paperId: string; file: string; label: string}): React.JSX.Element | null {
  // 28 Oct, live: three clips each in its own web view, loading at once, stopped the app answering on the emulator; a
  // clip opens only when the student asks for it
  const [open, setOpen] = useState(false);
  const [url, setUrl] = useState<string | null>(null);
  const [gone, setGone] = useState(false);
  useEffect(() => {
    if (!open) return;
    let live = true;
    witness.asset(env, paperId, file).then(r => { if (!live) return; if (r.ok) setUrl(r.value.url); else setGone(true); });
    return () => { live = false; };
  }, [env, paperId, file, open]);
  if (gone) return null;
  if (!open) return <Btn label="Watch the moment (6 seconds)" onPress={() => setOpen(true)} small testID={'witness-clip-open-' + file} />;
  if (!url) return <ActivityIndicator style={{marginVertical: 10}} />;
  const html = '<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:#000">' +
    '<video src="' + url.replace(/"/g, '&quot;') + '" controls muted playsinline autoplay style="width:100%;height:100%;object-fit:contain"></video></body></html>';
  return (
    <View style={s.clip} accessibilityLabel={label} testID={'witness-clip-' + file}>
      <WebView source={{html}} originWhitelist={['*']} allowsInlineMediaPlayback mediaPlaybackRequiresUserAction={false} javaScriptEnabled={false} style={{backgroundColor: '#000'}} />
    </View>
  );
}

export function ProofView({env, paperId}: {env: WitnessEnv; paperId: string}): React.JSX.Element {
  const [p, setP] = useState<Proof | null>(null);
  const [err, setErr] = useState('');
  useEffect(() => { witness.proof(env, paperId).then(r => { if (r.ok) setP(r.value); else setErr(r.error); }); }, [env, paperId]);
  if (err) return <Text style={s.error}>{err}</Text>;
  if (!p) return <ActivityIndicator style={{marginTop: 16}} />;
  const day = (ms: number | null) => (ms ? new Date(ms).toLocaleString() : '');
  return (
    <View style={s.card} testID="witness-proof">
      <Text style={s.h}>Proof of Thinking</Text>
      <Text style={s.sub}>{p.exam}{p.level ? ' · ' + p.level : ''}</Text>
      <Text style={s.meta}>{p.student ? p.student + ' · ' : ''}sat {day(p.sat_ms)} · {p.marks} of {p.out_of} marks
        {p.mastered != null ? ' · ' + p.mastered + ' of ' + p.questions.length + ' mastered' + (p.turned_around ? ' (' + p.turned_around + ' turned around)' : '') : ''}</Text>
      {p.questions.map(q => (
        <View key={q.n} style={s.block}>
          <Text style={s.qh}>Question {q.n} · {RESULT_WORDS[q.teacher_result || q.result]}</Text>
          {q.question ? <Text style={s.sub}>{q.question}</Text> : null}
          {q.steps.map((st, i) => (
            <View key={i} style={s.stepRow}><Text style={s.time}>{clock(st.t)}</Text><Text style={[s.step, st.crossed_out ? s.crossed : null]}>{st.wrote}</Text></View>
          ))}
          {q.diagnosis ? <Text style={s.diag}>{q.moment_s != null ? 'At ' + clock(q.moment_s) + ': ' : ''}{q.diagnosis}</Text> : null}
          {q.comment ? <Text style={s.comment}>Your teacher: {q.comment}</Text> : null}
          {q.still ? <Picture env={env} paperId={paperId} file={q.still} label={'Your desk, question ' + q.n} testID={'witness-proof-still-' + q.n} /> : null}
          {q.clip ? <Clip env={env} paperId={paperId} file={q.clip} label={'Six seconds of your desk, question ' + q.n} /> : null}
          {q.turned_around ? (
            <Text style={s.turned} testID={'witness-proof-turned-' + q.n}>Turned around · {day(q.turned_around.from_ms)} to {day(q.turned_around.at)}{q.turned_around.note ? ' · ' + q.turned_around.note : ''}. Counted as mastered.</Text>
          ) : null}
        </View>
      ))}
      {p.examiner.length ? (
        <View style={s.block}>
          <Text style={s.qh}>The examiner's questions</Text>
          {p.examiner.map(a => (
            <View key={a.k} style={{marginTop: 6}}>
              <Text style={s.q}>{a.ask}</Text>
              <Text style={s.sub}>{a.answer ? (a.answer.spoken ? 'You said: ' : 'You wrote: ') + a.answer.text : 'Not answered.'}</Text>
            </View>
          ))}
        </View>
      ) : null}
      <Text style={s.foot}>Read by {p.read_by.join(', ')}. {p.source === 'photo' ? 'Photographed after the exam: ' + p.pages + (p.pages === 1 ? ' page' : ' pages') + ', kept with the paper.' : 'Filmed with Witness; the video was ' + p.video + '.'}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  card: {backgroundColor: C.surface, borderRadius: 12, padding: 14, marginTop: 12, borderWidth: 1, borderColor: C.lineSolid},
  h: {fontSize: 17, fontWeight: '700', color: C.ink},
  sub: {fontSize: 14, color: C.inkSoft, marginTop: 4, lineHeight: 20},
  meta: {fontSize: 13, color: C.inkSoft, marginTop: 4},
  block: {marginTop: 14, paddingTop: 10, borderTopWidth: 1, borderTopColor: C.lineSolid},
  qh: {fontSize: 15, fontWeight: '700', color: C.ink},
  q: {fontSize: 14, fontWeight: '600', color: C.ink},
  stepRow: {flexDirection: 'row', alignItems: 'baseline', marginTop: 4, paddingLeft: 6, borderLeftWidth: 3, borderLeftColor: 'transparent'},
  slipRow: {borderLeftColor: C.amber, backgroundColor: C.amberWash},
  time: {width: 44, fontSize: 12, color: C.inkSoft, fontVariant: ['tabular-nums']},
  step: {flex: 1, fontFamily: 'monospace', fontSize: 14, color: C.ink},
  crossed: {textDecorationLine: 'line-through', color: C.inkFaint},
  diag: {fontSize: 14, color: C.ink, marginTop: 6, lineHeight: 20},
  comment: {fontSize: 14, color: C.ink, marginTop: 6, fontStyle: 'italic'},
  picture: {width: '100%', aspectRatio: 1, marginTop: 10, borderRadius: 8, backgroundColor: '#f4efe2'},
  clip: {width: '100%', height: 320, marginTop: 8, borderRadius: 8, overflow: 'hidden', backgroundColor: '#000'},
  turned: {fontSize: 14, color: C.teal, marginTop: 8, fontWeight: '600'},
  foot: {fontSize: 12, color: C.inkSoft, marginTop: 14, lineHeight: 18},
  error: {fontSize: 14, color: C.pink, marginTop: 12},
});
