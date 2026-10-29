/**
 * WITNESS — say it out loud (2026-10-28 re-audit; the plan's teach-back is "by voice or in writing"). Records a short
 * spoken answer with the app's recorder and hands it on as base64; Voice Transcribe writes it down on the edge, and
 * the recording is kept with the paper for the teacher to hear (owner, 28 Oct). Writing stays beside it.
 */
import React, {useEffect, useRef, useState} from 'react';
import {ActivityIndicator, PermissionsAndroid, Platform, Pressable, StyleSheet, Text, View} from 'react-native';
import {C} from '../ui/theme';
import {cancelRecording, readRecording, recorderAvailable, removeRecording, RECORDING_MIME, startRecording, stopRecording} from '../voice/recorder';

/** An explanation is a few sentences; the recording stops on its own after this. */
export const SAY_SECONDS = 90;
/** What the student is told before the microphone opens: the teacher can listen to it. */
export const KEPT_WORDS = 'What you say is written down, and the recording is kept with your paper so your teacher can listen to it.';

export function SayIt({onAudio, label, testID}: {onAudio(audio: string, mime: string): Promise<unknown>; label: string; testID?: string}): React.JSX.Element | null {
  const [mode, setMode] = useState<'idle' | 'recording' | 'sending'>('idle');
  const [said, setSaid] = useState('');
  const alive = useRef(true);
  useEffect(() => () => { alive.current = false; if (mode === 'recording') cancelRecording(); }, []); // eslint-disable-line react-hooks/exhaustive-deps
  if (!recorderAvailable()) return null;
  const start = async () => {
    setSaid('');
    if (Platform.OS === 'android') {
      try {
        const g = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO, {title: label, message: KEPT_WORDS, buttonPositive: 'Allow', buttonNegative: 'Not now'});
        if (g !== PermissionsAndroid.RESULTS.GRANTED) { setSaid('LoWisa needs the microphone to hear you. You can write it instead.'); return; }
      } catch (e) { return; }
    }
    const st = await startRecording(SAY_SECONDS, 'phrase');
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
    await onAudio(audio, RECORDING_MIME);
    if (alive.current) setMode('idle');
  };
  return (
    <View style={s.wrap}>
      {mode === 'sending' ? <View style={s.row}><ActivityIndicator /><Text style={s.small}> Listening…</Text></View>
        : mode === 'recording' ? (
          <View>
            <Text style={s.live}>Recording. Say it in your own words.</Text>
            <Pressable style={[s.btn, s.main]} onPress={stop} accessibilityRole="button" testID={testID ? testID + '-stop' : undefined}><Text style={s.mainText}>Stop and send</Text></Pressable>
          </View>
        ) : (
          <View>
            <Pressable style={s.btn} onPress={start} accessibilityRole="button" testID={testID}><Text style={s.btnText}>{label}</Text></Pressable>
            <Text style={s.small}>{KEPT_WORDS}</Text>
          </View>
        )}
      {said ? <Text style={s.err}>{said}</Text> : null}
    </View>
  );
}

const s = StyleSheet.create({
  wrap: {marginTop: 6},
  row: {flexDirection: 'row', alignItems: 'center'},
  btn: {borderWidth: 1, borderColor: C.brand, borderRadius: 10, paddingVertical: 9, paddingHorizontal: 12, alignSelf: 'flex-start', marginTop: 4},
  btnText: {color: C.brand, fontWeight: '700', fontSize: 14},
  main: {backgroundColor: C.brandFill},
  mainText: {color: C.onFill, fontWeight: '700', fontSize: 14},
  live: {color: C.pink, fontWeight: '700', marginTop: 4},
  small: {color: C.inkSoft, fontSize: 12, marginTop: 4},
  err: {color: C.pink, fontSize: 13, marginTop: 4},
});
