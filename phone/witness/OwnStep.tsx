/**
 * WITNESS — "Your step, as you wrote it" (2026-10-28, Meta hackathon; the plan: the first look opens on the student's own
 * crop from their paper, in their own handwriting, before it runs in the world). The picture is the step cut from the
 * desk video by SAM's box for its line (step-N.jpg). When there is none (a paper marked before it was made, or a step
 * SAM did not place), the first look plays as it always does.
 */
import React, {useEffect, useState} from 'react';
import {ActivityIndicator, Image, Pressable, StyleSheet, Text, View} from 'react-native';
import {witness, WitnessEnv} from './net';

export function OwnStep({env, paperId, n, onGo}: {env: WitnessEnv; paperId: string; n: number; onGo(): void}): React.JSX.Element {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let live = true;
    witness.asset(env, paperId, 'step-' + n + '.jpg').then(r => { if (!live) return; if (r.ok) setUrl(r.value.url); else onGo(); }).catch(() => { if (live) onGo(); });
    return () => { live = false; };
  }, [env, paperId, n]); // eslint-disable-line react-hooks/exhaustive-deps
  if (!url) return <View style={s.wrap}><ActivityIndicator /></View>;
  return (
    <View style={s.wrap} testID="witness-own-step">
      <Text style={s.eyebrow}>YOUR STEP, AS YOU WROTE IT</Text>
      <Image source={{uri: url}} style={s.picture} resizeMode="contain" accessibilityLabel="Your own written step, from your paper" />
      <Text style={s.sub}>Now watch it run in the real world.</Text>
      <Pressable style={s.go} onPress={onGo} accessibilityRole="button" testID="witness-own-step-go"><Text style={s.goText}>Watch it run</Text></Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: {flex: 1, padding: 20, justifyContent: 'center', backgroundColor: '#eef2fb'},
  eyebrow: {fontSize: 13, fontWeight: '800', letterSpacing: 1, color: '#1d4ed8', marginBottom: 12},
  picture: {width: '100%', height: 220, borderRadius: 12, backgroundColor: '#ffffff'},
  sub: {fontSize: 16, color: '#0f172a', marginTop: 14},
  go: {marginTop: 18, backgroundColor: '#1d4ed8', borderRadius: 14, paddingVertical: 14, alignItems: 'center'},
  goText: {color: '#ffffff', fontSize: 17, fontWeight: '700'},
});
