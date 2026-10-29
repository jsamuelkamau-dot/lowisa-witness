/**
 * WITNESS — "Turned around" on the student's profile (2026-10-28, Meta hackathon; the plan: the badge shows on the
 * student's profile and record, first, before first-time correct answers). Each badge names the question, what was
 * turned around and the days from going wrong to mastered. Nothing shows until the teacher has issued one, or when
 * Witness is not open for the account.
 */
import React, {useEffect, useState} from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {C} from '../ui/theme';
import {Badge, witness, WitnessEnv} from './net';

/** "12 Oct to 28 Oct", or the one date when it turned around the same day; in the phone's own way of writing dates. */
export function journey(wrongAt: number | null, turnedAt: number): string {
  const day = (ms: number) => new Date(ms).toLocaleDateString(undefined, {day: 'numeric', month: 'short'});
  if (!wrongAt || day(wrongAt) === day(turnedAt)) return day(turnedAt);
  return day(wrongAt) + ' to ' + day(turnedAt);
}

export function TurnedAround({env}: {env: WitnessEnv}): React.JSX.Element | null {
  const [badges, setBadges] = useState<Badge[]>([]);
  useEffect(() => {
    let alive = true;
    witness.badges(env).then(r => { if (alive && r.ok) setBadges(r.value.badges || []); }).catch(() => undefined);
    return () => { alive = false; };
  }, [env]);
  if (!badges.length) return null;
  return (
    <View style={s.card} testID="profile-turned-around">
      <Text style={s.h}>Turned around</Text>
      {badges.map((b, i) => (
        <View key={i} style={s.row}>
          <Text style={s.q}>{b.question || b.exam}</Text>
          {b.fixed ? <Text style={s.sub}>{b.fixed}</Text> : null}
          <Text style={s.when}>{(b.exam ? b.exam + ' · ' : '') + journey(b.wrong_at, b.turned_at)}{b.note ? ' · ' + b.note : ''}</Text>
        </View>
      ))}
    </View>
  );
}

const s = StyleSheet.create({
  card: {backgroundColor: C.surface, borderRadius: 16, padding: 16, marginTop: 12, borderWidth: 1, borderColor: C.lineSolid},
  h: {fontSize: 17, fontWeight: '700', color: C.teal, marginBottom: 6},
  row: {paddingVertical: 8, borderTopWidth: 1, borderTopColor: C.lineSolid},
  q: {fontSize: 15, fontWeight: '600', color: C.ink},
  sub: {fontSize: 13, color: C.inkSoft, marginTop: 2},
  when: {fontSize: 12, color: C.teal, marginTop: 4},
});
