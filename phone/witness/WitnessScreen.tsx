/**
 * WITNESS ON THE PHONE — sit a teacher's exam on paper, with the phone watching the desk (2026-10-27, Meta hackathon;
 * synced into the LoWisa app as src/witness/WitnessScreen.tsx).
 *
 *   1. The teacher's join code -> the exam's name.
 *   2. The student's name as the teacher knows it.
 *   3. Record the desk (the phone's camera app, up to ten minutes) or choose a video already made.
 *   4. The video goes straight to storage on a signed link, then Witness marks it. The paper is "with your teacher"
 *      until they release it; then it shows here, question by question, in words that never say "failed".
 *
 * Only shown when the edge's Witness doors answer (LOWISA_WITNESS_ACCESS); the caller checks witness.mine first.
 */
import React, {useCallback, useEffect, useState} from 'react';
import {ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View} from 'react-native';
import {Page} from '../ui/Page';
import {Btn} from '../exam/print/ui';
import {chooseVideo, doorMime, VideoFile} from '../community/video';
import {NativeModules} from 'react-native';
import {marksOf, Paper, Question, RESULT_WORDS, resultOf, toMaster, typedCode, witness, WitnessEnv} from './net';
import type {MirrorStorage} from '../state/storage';
import type {CustomEnv} from '../paths/custom/course';
import {onBuildProgress} from '../paths/custom/course';
import {buildMastery, masteryPath} from './mastery';

/** The camera app is told to stop here: SAM 3.1 follows up to about ten minutes of video in one go. */
export const RECORD_SECONDS = 600;
/** The phone's own recordings play at a steady rate; this is what the marking is told when nothing better is known. */
export const PHONE_FPS = 30;

type Stage =
  | {kind: 'home'}
  | {kind: 'joined'; code: string; title: string; level: string}
  | {kind: 'sending'; title: string; line: string}
  | {kind: 'sent'; title: string}
  | {kind: 'paper'; paper: Paper};

interface Native { uploadFile?(uri: string, url: string, contentType: string): Promise<number>; takeVideo?(maxSeconds: number): Promise<VideoFile | null> }
const docs = () => (NativeModules as Record<string, unknown>).LoWisaDocuments as Native | undefined;

export function WitnessScreen({env, storage, onBack, onOpenPath}: {env: WitnessEnv & CustomEnv; storage: MirrorStorage; onBack(): void; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const [stage, setStage] = useState<Stage>({kind: 'home'});
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [papers, setPapers] = useState<Paper[] | null>(null);
  const [busy, setBusy] = useState(false);

  const loadMine = useCallback(async () => {
    const r = await witness.mine(env);
    if (r.ok) setPapers(r.value.papers || []); else setError(r.error);
  }, [env]);
  useEffect(() => { loadMine(); }, [loadMine]);

  const join = async () => {
    setError('');
    if (code.length !== 6) { setError('The code has six letters and numbers. Check it with your teacher.'); return; }
    setBusy(true);
    const r = await witness.join(env, code);
    setBusy(false);
    if (!r.ok) { setError(r.error); return; }
    setStage({kind: 'joined', code, title: r.value.pile.title, level: r.value.pile.level});
  };

  const sit = async (source: 'camera' | 'gallery') => {
    if (stage.kind !== 'joined') return;
    setError('');
    if (!name.trim()) { setError('Write your name as your teacher knows it.'); return; }
    let file: VideoFile | null = null;
    // the camera app records up to ten minutes here (the composer's own recordings stop at two)
    try { const n = docs(); file = source === 'camera' && n && n.takeVideo ? await n.takeVideo(RECORD_SECONDS) : await chooseVideo(source); }
    catch (e) { setError('The camera could not start. Try choosing a video you already recorded.'); return; }
    if (!file) return;
    const mime = doorMime(file.mime, file.name);
    if (!mime) { setError('Witness reads MP4 and MOV videos. Record it again with the camera here.'); return; }
    const title = stage.title;
    setStage({kind: 'sending', title, line: 'Getting the upload ready…'});
    const started = await witness.start(env, Math.round(file.size), mime, stage.code, name.trim());
    if (!started.ok) { setStage({kind: 'joined', code: stage.code, title, level: stage.level}); setError(started.error); return; }
    setStage({kind: 'sending', title, line: 'Sending your paper…'});
    const up = docs();
    let status = 0;
    try { status = up && up.uploadFile ? await up.uploadFile(file.uri, started.value.put, mime) : 0; } catch (e) { status = 0; }
    if (status < 200 || status >= 300) {
      setStage({kind: 'joined', code: stage.code, title, level: stage.level});
      setError('The video did not go up. Check your connection, on Wi-Fi if you can, and try again.');
      return;
    }
    setStage({kind: 'sending', title, line: 'Witness is reading how you worked…'});
    const marked = await witness.mark(env, started.value.id, PHONE_FPS);
    if (!marked.ok) { setStage({kind: 'joined', code: stage.code, title, level: stage.level}); setError(marked.error); return; }
    setStage({kind: 'sent', title});
    loadMine();
  };

  const back = () => {
    if (stage.kind === 'home') onBack();
    else { setStage({kind: 'home'}); setError(''); loadMine(); }
  };

  return (
    <Page title="Witness" subtitle="Exams on paper" onBack={back}>
      <ScrollView contentContainerStyle={s.page} keyboardShouldPersistTaps="handled" testID="witness-screen">
        {error ? <Text style={s.error} accessibilityRole="alert" testID="witness-error">{error}</Text> : null}

        {stage.kind === 'home' ? (
          <>
            <View style={s.card}>
              <Text style={s.h}>Sit your teacher's exam</Text>
              <Text style={s.sub}>Work on paper as you always do. Your phone watches the desk, so your teacher sees how you worked, not only your answers.</Text>
              <TextInput value={code} onChangeText={t => setCode(typedCode(t))} placeholder="Join code" autoCapitalize="characters" maxLength={6}
                style={[s.input, s.code]} accessibilityLabel="Your teacher's join code" testID="witness-code" />
              <Btn label={busy ? 'Checking…' : 'Find the exam'} onPress={join} primary disabled={busy} testID="witness-join" />
            </View>
            <Mine papers={papers} onOpen={p => setStage({kind: 'paper', paper: p})} />
          </>
        ) : null}

        {stage.kind === 'joined' ? (
          <View style={s.card}>
            <Text style={s.h} testID="witness-exam-title">{stage.title}</Text>
            {stage.level ? <Text style={s.sub}>{stage.level}</Text> : null}
            <TextInput value={name} onChangeText={setName} placeholder="Your name, as your teacher knows it" maxLength={80}
              style={s.input} accessibilityLabel="Your name" testID="witness-name" />
            <Text style={s.how}>Prop your phone above the desk so it sees the whole page and your hand. Keep faces out of view. Then work through the paper and stop the recording when you finish.</Text>
            <Btn label="Record my paper" onPress={() => sit('camera')} primary testID="witness-record" />
            <View style={{height: 8}} />
            <Btn label="Choose a video I recorded" onPress={() => sit('gallery')} testID="witness-pick" />
            <Text style={s.small}>The video is deleted once your paper is marked.</Text>
          </View>
        ) : null}

        {stage.kind === 'sending' ? (
          <View style={[s.card, s.center]} testID="witness-sending">
            <ActivityIndicator />
            <Text style={s.h}>{stage.title}</Text>
            <Text style={s.sub}>{stage.line}</Text>
          </View>
        ) : null}

        {stage.kind === 'sent' ? (
          <View style={s.card} testID="witness-sent">
            <Text style={s.h}>Sent to your teacher</Text>
            <Text style={s.sub}>Your paper for {stage.title} is with your teacher. Your marks show here once they release them, with what to master next.</Text>
            <Btn label="Done" onPress={back} primary testID="witness-done" />
          </View>
        ) : null}

        {stage.kind === 'paper' ? <PaperView paper={stage.paper} env={env} storage={storage} onOpenPath={onOpenPath} /> : null}
      </ScrollView>
    </Page>
  );
}

function Mine({papers, onOpen}: {papers: Paper[] | null; onOpen(p: Paper): void}): React.JSX.Element {
  if (papers === null) return <ActivityIndicator style={{marginTop: 16}} />;
  if (!papers.length) return <Text style={[s.sub, {marginTop: 12}]}>Your papers show here.</Text>;
  return (
    <View style={s.card} testID="witness-mine">
      <Text style={s.h}>Your papers</Text>
      {papers.map(p => {
        const left = toMaster(p).length;
        const line = p.status === 'released' ? (left ? left + ' to master next' : 'All mastered') : p.status === 'failed' ? 'Record it again' : 'With your teacher';
        return (
          <Pressable key={p.id} onPress={() => p.status === 'released' && onOpen(p)} style={s.row} accessibilityRole="button" testID={'witness-paper-' + p.id}>
            <Text style={s.rowTitle}>{p.title || 'Paper'}</Text>
            <Text style={s.rowMeta}>{line}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function PaperView({paper, env, storage, onOpenPath}: {paper: Paper; env: CustomEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const qs = (paper.result && paper.result.questions) || [];
  const got = qs.reduce((a, q) => a + marksOf(q), 0);
  const of = qs.reduce((a, q) => a + (q.out_of || 0), 0);
  return (
    <>
      <View style={s.card} testID="witness-result">
        <Text style={s.h}>{paper.title || 'Your paper'}</Text>
        <Text style={s.sub}>{got} of {of} marks · {toMaster(paper).length} to master next</Text>
      </View>
      {qs.map(q => <QuestionCard key={q.n} q={q} paper={paper} env={env} storage={storage} onOpenPath={onOpenPath} />)}
    </>
  );
}

function QuestionCard({q, paper, env, storage, onOpenPath}: {q: Question; paper: Paper; env: CustomEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const r = resultOf(q);
  const next = r === 'not_yet' || r === 'right_answer_wrong_thinking';
  const [path, setPath] = useState<string | null>(() => masteryPath(storage, paper.id, q.n));
  const [building, setBuilding] = useState('');
  const [said, setSaid] = useState('');
  const start = async () => {
    if (path) { if (onOpenPath) onOpenPath(path); return; }
    setSaid(''); setBuilding('Planning your level…');
    const off = onBuildProgress(st => setBuilding(st.stage === 'write' ? 'Writing your lessons…' : st.stage === 'review' ? 'Checking it teaches this one idea…' : 'Planning your level…'));
    const made = await buildMastery(env, storage, paper, q);
    off(); setBuilding('');
    if (made.ok && made.pathId) { setPath(made.pathId); if (onOpenPath) onOpenPath(made.pathId); }
    else setSaid(made.text);
  };
  return (
    <View style={[s.card, next ? s.next : null]} testID={'witness-q-' + q.n}>
      <View style={s.rowTop}>
        <Text style={s.rowTitle}>Question {q.n}</Text>
        <Text style={[s.chip, next ? s.chipNext : s.chipOk]}>{RESULT_WORDS[r]}</Text>
      </View>
      <Text style={s.sub}>{marksOf(q)} of {q.out_of} marks</Text>
      {(q.steps || []).map((st, i) => (
        <Text key={i} style={[s.step, st.crossed_out ? s.crossed : null]}>{st.wrote}</Text>
      ))}
      {next && q.diagnosis ? <Text style={s.diag}>{q.diagnosis}</Text> : null}
      {next ? (
        <View style={{marginTop: 10}}>
          {building ? <View style={s.buildRow}><ActivityIndicator /><Text style={s.small}> {building}</Text></View>
            : <Btn label={path ? 'Open my mastery level' : 'Start my mastery level'} onPress={start} primary testID={'witness-master-' + q.n} />}
          {said ? <Text style={s.error}>{said}</Text> : null}
        </View>
      ) : null}
    </View>
  );
}

const s = StyleSheet.create({
  page: {padding: 16, paddingBottom: 40},
  card: {borderWidth: 1, borderColor: '#e2e0da', borderRadius: 12, padding: 14, marginBottom: 12, backgroundColor: '#ffffff'},
  next: {borderColor: '#d9a441'},
  center: {alignItems: 'center'},
  h: {fontSize: 17, fontWeight: '600', color: '#1f1e1c', marginBottom: 4},
  sub: {fontSize: 14, color: '#5f5e5a', lineHeight: 20, marginBottom: 10},
  how: {fontSize: 14, color: '#1f1e1c', lineHeight: 20, marginVertical: 10},
  small: {fontSize: 12, color: '#5f5e5a', marginTop: 8},
  input: {borderWidth: 1, borderColor: '#cfcdc5', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10, fontSize: 16, marginBottom: 10, color: '#1f1e1c'},
  code: {fontSize: 22, letterSpacing: 4, textAlign: 'center'},
  error: {color: '#c62828', fontSize: 14, marginBottom: 10},
  row: {paddingVertical: 10, borderTopWidth: 1, borderTopColor: '#efeeea'},
  rowTop: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'},
  rowTitle: {fontSize: 15, fontWeight: '600', color: '#1f1e1c'},
  rowMeta: {fontSize: 13, color: '#5f5e5a', marginTop: 2},
  chip: {fontSize: 12, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, overflow: 'hidden'},
  chipOk: {color: '#2e7d32', backgroundColor: '#eaf3de'},
  chipNext: {color: '#8a5300', backgroundColor: '#faeeda'},
  step: {fontSize: 15, color: '#1f1e1c', fontFamily: 'monospace', marginTop: 4},
  crossed: {textDecorationLine: 'line-through', color: '#8a8984'},
  buildRow: {flexDirection: 'row', alignItems: 'center'},
  diag: {fontSize: 14, color: '#1f1e1c', marginTop: 10, padding: 10, borderRadius: 8, backgroundColor: '#faeeda'},
});
