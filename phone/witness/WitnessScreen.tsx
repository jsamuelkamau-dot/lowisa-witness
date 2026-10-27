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
import {DeviceEventEmitter, NativeModules} from 'react-native';
import {marksOf, Paper, Question, RESULT_WORDS, resultOf, toMaster, typedCode, witness, WitnessEnv} from './net';
import type {MirrorStorage} from '../state/storage';
import type {CustomEnv} from '../paths/custom/course';
import {onBuildProgress} from '../paths/custom/course';
import {buildMastery, masteryDone, masteryPath} from './mastery';
import type {Mastery} from './net';
import {asksLeft} from './net';
import {AsksView} from './Examiner';
import {clock, Picture, ProofView, Replay} from './Proof';

/** The camera app is told to stop here: SAM 3.1 follows up to about ten minutes of video in one go. */
export const RECORD_SECONDS = 600;
/** The phone's own recordings play at a steady rate; this is what the marking is told when nothing better is known. */
export const PHONE_FPS = 30;

type Stage =
  | {kind: 'home'}
  | {kind: 'joined'; code: string; title: string; level: string}
  | {kind: 'sending'; title: string; line: string}
  | {kind: 'sent'; title: string; id: string}
  | {kind: 'asks'; paper: Paper}
  | {kind: 'proof'; paper: Paper}
  | {kind: 'paper'; paper: Paper};

interface Native { uploadFile?(uri: string, url: string, contentType: string): Promise<number>; takeVideo?(maxSeconds: number): Promise<VideoFile | null>; smallVideo?(uri: string): Promise<VideoFile | null>; lastClip?(sinceMs: number): Promise<VideoFile | null> }
const docs = () => (NativeModules as Record<string, unknown>).LoWisaDocuments as Native | undefined;

/**
 * A desk video made small enough to send on a phone's data: 720p, ten frames a second, about 8 MB a minute where the
 * camera made some 120 (27 Oct). The original goes when it is small already, or when this phone cannot make it smaller.
 */
export async function smaller(file: VideoFile, onPercent?: (percent: number) => void): Promise<VideoFile> {
  const n = docs();
  if (!n || !n.smallVideo) return file;
  const sub = onPercent ? DeviceEventEmitter.addListener('lowisaSmallVideo', (e: {percent?: number}) => {
    if (typeof e?.percent === 'number') onPercent(Math.max(0, Math.min(100, Math.round(e.percent))));
  }) : null;
  try { return (await n.smallVideo(file.uri)) || file; } catch (e) { return file; } finally { sub?.remove(); }
}

/**
 * The upload, tried three times: on a weak connection one try often drops and the next goes through (27 Oct). The
 * status of the last try; 0 when nothing answered. A refused link (4xx) is not tried again.
 */
export async function sendClip(uri: string, put: string, mime: string, wait = (ms: number) => new Promise<void>(r => setTimeout(r, ms))): Promise<number> {
  const up = docs();
  if (!up || !up.uploadFile) return 0;
  let status = 0;
  for (let i = 0; i < 3; i++) {
    try { status = await up.uploadFile(uri, put, mime); } catch (e) { status = 0; }
    if ((status >= 200 && status < 300) || (status >= 400 && status < 500)) return status;
    if (i < 2) await wait(i === 0 ? 2000 : 6000);
  }
  return status;
}

/**
 * The exam a camera recording is being made for, kept until the paper is sent. Android stops the app when a camera
 * grant given "Only this time" lapses while the camera app records (about a minute in, 27 Oct, emulator), and the
 * recording the camera app still wrote is found again from this when Witness opens.
 */
export const PENDING_KEY = 'lowisa-witness-pending-v1';
export interface PendingSit { code: string; title: string; level: string; name: string; at: number }
/** A kept recording is offered for six hours (the cache drops an unsent clip after a day). */
const PENDING_MS = 6 * 3600 * 1000;

export function readPending(storage: MirrorStorage, now = Date.now()): PendingSit | null {
  try {
    const p = JSON.parse(storage.getItem(PENDING_KEY) || 'null') as PendingSit | null;
    return p && typeof p.code === 'string' && typeof p.at === 'number' && now - p.at < PENDING_MS ? p : null;
  } catch (e) { return null; }
}

/** The recording a stopped app left behind for the pending exam, or null. */
export async function keptRecording(storage: MirrorStorage, now = Date.now()): Promise<{pending: PendingSit; clip: VideoFile} | null> {
  const p = readPending(storage, now);
  const n = docs();
  if (!p || !n || !n.lastClip) return null;
  try { const clip = await n.lastClip(p.at - 2000); return clip ? {pending: p, clip} : null; } catch (e) { return null; }
}

export function WitnessScreen({env, storage, onBack, onOpenPath}: {env: WitnessEnv & CustomEnv; storage: MirrorStorage; onBack(): void; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const [stage, setStage] = useState<Stage>({kind: 'home'});
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [papers, setPapers] = useState<Paper[] | null>(null);
  const [busy, setBusy] = useState(false);
  // a recording that did not go up stays here: a weak connection costs a second try, not the paper sat again
  const [unsent, setUnsent] = useState<VideoFile | null>(null);
  const [notice, setNotice] = useState('');

  // a recording the camera app made while Android stopped this app (PENDING_KEY): offered as soon as Witness opens
  useEffect(() => {
    let live = true;
    keptRecording(storage).then(k => {
      if (!live || !k) return;
      setName(k.pending.name);
      setUnsent(k.clip);
      setStage({kind: 'joined', code: k.pending.code, title: k.pending.title, level: k.pending.level});
      setNotice('Your recording was kept. Send it to your teacher.');
    });
    return () => { live = false; };
  }, [storage]);

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
    const n = docs();
    const camera = source === 'camera' && !!n && !!n.takeVideo;
    if (camera) storage.setItem(PENDING_KEY, JSON.stringify({code: stage.code, title: stage.title, level: stage.level, name: name.trim(), at: Date.now()}));
    // the camera app records up to ten minutes here (the composer's own recordings stop at two)
    try { file = camera ? await n!.takeVideo!(RECORD_SECONDS) : await chooseVideo(source); }
    catch (e) { if (camera) storage.removeItem(PENDING_KEY); setError('The camera could not start. Try choosing a video you already recorded.'); return; }
    if (!file) { if (camera) storage.removeItem(PENDING_KEY); return; }
    if (!doorMime(file.mime, file.name)) { setError('Witness reads MP4 and MOV videos. Record it again with the camera here.'); return; }
    await send(file);
  };

  const send = async (picked: VideoFile) => {
    if (stage.kind !== 'joined') return;
    setError('');
    if (!name.trim()) { setError('Write your name as your teacher knows it.'); return; }
    setNotice('');
    const {title} = stage;
    const again = (why: string, file: VideoFile) => { setStage({kind: 'joined', code: stage.code, title, level: stage.level}); setUnsent(file); setError(why); };
    setStage({kind: 'sending', title, line: 'Making the video smaller to send…'});
    const file = await smaller(picked, p => setStage({kind: 'sending', title, line: `Making the video smaller to send… ${p}%`}));
    const mime = doorMime(file.mime, file.name)!;
    setStage({kind: 'sending', title, line: 'Getting the upload ready…'});
    const started = await witness.start(env, Math.round(file.size), mime, stage.code, name.trim());
    if (!started.ok) { again(started.error, file); return; }
    setStage({kind: 'sending', title, line: 'Sending your paper…'});
    const status = await sendClip(file.uri, started.value.put, mime);
    if (status < 200 || status >= 300) {
      again('The video did not go up. It is kept on this phone: send it again when the connection is better, on Wi-Fi if you can.', file);
      return;
    }
    setUnsent(null);
    storage.removeItem(PENDING_KEY);
    setStage({kind: 'sending', title, line: 'Witness is reading how you worked…'});
    const marked = await witness.mark(env, started.value.id, PHONE_FPS);
    if (!marked.ok) { setStage({kind: 'joined', code: stage.code, title, level: stage.level}); setError(marked.error); return; }
    setStage({kind: 'sent', title, id: started.value.id});
    loadMine();
  };

  // the examiner's questions arrive a little after the marking (Muse Wonder writes them): look for them while the
  // student is still on the "sent" page, for up to two minutes
  const [waitingAsks, setWaitingAsks] = useState<Paper | null>(null);
  useEffect(() => {
    if (stage.kind !== 'sent') { setWaitingAsks(null); return; }
    let live = true; let tries = 0;
    const look = async () => {
      if (!live || tries++ > 24) return;
      const r = await witness.mine(env);
      if (!live) return;
      const mine = r.ok ? (r.value.papers || []).find(p => p.id === stage.id) : undefined;
      if (mine && mine.examiner && asksLeft(mine).length) { setWaitingAsks(mine); if (r.ok) setPapers(r.value.papers || []); return; }
      if (mine && mine.examiner && mine.examiner.status === 'failed') return;
      setTimeout(look, 5000);
    };
    setTimeout(look, 4000);
    return () => { live = false; };
  }, [stage, env]);

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
            <Mine papers={papers} onOpen={p => setStage(p.status === 'released' ? {kind: 'paper', paper: p} : {kind: 'asks', paper: p})} />
          </>
        ) : null}

        {stage.kind === 'joined' ? (
          <View style={s.card}>
            <Text style={s.h} testID="witness-exam-title">{stage.title}</Text>
            {stage.level ? <Text style={s.sub}>{stage.level}</Text> : null}
            <TextInput value={name} onChangeText={setName} placeholder="Your name, as your teacher knows it" maxLength={80}
              style={s.input} accessibilityLabel="Your name" testID="witness-name" />
            <Text style={s.how}>Prop your phone above the desk so it sees the whole page and your hand. Keep faces out of view. Then work through the paper and stop the recording when you finish.</Text>
            {notice ? <Text style={s.notice} accessibilityRole="alert" testID="witness-kept">{notice}</Text> : null}
            {unsent ? (
              <>
                <Btn label={notice ? 'Send my recording' : 'Send my recording again'} onPress={() => send(unsent)} primary testID="witness-resend" />
                <View style={{height: 8}} />
              </>
            ) : null}
            <Btn label="Record my paper" onPress={() => sit('camera')} primary={!unsent} testID="witness-record" />
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
            {waitingAsks ? (
              <View style={{marginBottom: 10}}>
                <Text style={s.sub}>Witness has {asksLeft(waitingAsks).length === 1 ? 'a question' : 'two questions'} about steps you wrote.</Text>
                <Btn label="Answer about my work" onPress={() => setStage({kind: 'asks', paper: waitingAsks})} primary testID="witness-open-asks" />
              </View>
            ) : <Text style={s.small}>Witness may ask you about a step you wrote. Stay here a moment.</Text>}
            <Btn label="Done" onPress={back} testID="witness-done" />
          </View>
        ) : null}

        {stage.kind === 'asks' && stage.paper.examiner ? (
          <AsksView env={env} paperId={stage.paper.id} title={stage.paper.title || ''} examiner={stage.paper.examiner} onDone={back} />
        ) : null}
        {stage.kind === 'proof' ? <ProofView env={env} paperId={stage.paper.id} /> : null}
        {stage.kind === 'paper' ? <PaperView paper={stage.paper} env={env} storage={storage} onOpenPath={onOpenPath} onProof={() => setStage({kind: 'proof', paper: stage.paper})} /> : null}
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
        const asks = asksLeft(p).length;
        const line = p.status === 'released' ? (left ? left + ' to master next' : 'All mastered') : p.status === 'failed' ? (p.unseen ? 'Paper not in view: record it again' : 'Record it again')
          : asks ? (asks === 1 ? 'A question about your work' : asks + ' questions about your work') : 'With your teacher';
        return (
          <Pressable key={p.id} onPress={() => (p.status === 'released' || asks) && onOpen(p)} style={s.row} accessibilityRole="button" testID={'witness-paper-' + p.id}>
            <Text style={s.rowTitle}>{p.title || 'Paper'}</Text>
            <Text style={s.rowMeta}>{line}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** What a failed build says here: the builder's own lines name its own button ("Build my path"); the wall's words stay. */
export function failedWords(reason: string | undefined, text: string): string {
  if (reason === 'no-credits' || reason === 'full') return text;
  if (reason === 'no-network' || reason === 'no-auth') return 'No connection right now. Try again when you are back online.';
  if (reason === 'timeout') return 'That took too long. Tap Start my mastery level to try again.';
  return 'Your level could not be made just now. Tap Start my mastery level to try again in a moment.';
}

function PaperView({paper, env, storage, onOpenPath, onProof}: {paper: Paper; env: CustomEnv & WitnessEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void; onProof(): void}): React.JSX.Element {
  const qs = (paper.result && paper.result.questions) || [];
  const got = qs.reduce((a, q) => a + marksOf(q), 0);
  const of = qs.reduce((a, q) => a + (q.out_of || 0), 0);
  return (
    <>
      <View style={s.card} testID="witness-result">
        <Text style={s.h}>{paper.title || 'Your paper'}</Text>
        <Text style={s.sub}>{got} of {of} marks · {toMaster(paper).length} to master next</Text>
        <Btn label="My Proof of Thinking" onPress={onProof} small testID="witness-proof-open" />
      </View>
      {qs.map(q => <QuestionCard key={q.n} q={q} paper={paper} env={env} storage={storage} onOpenPath={onOpenPath} />)}
    </>
  );
}

function QuestionCard({q, paper, env, storage, onOpenPath}: {q: Question; paper: Paper; env: CustomEnv & WitnessEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const r = resultOf(q);
  const next = r === 'not_yet' || r === 'right_answer_wrong_thinking';
  const [path, setPath] = useState<string | null>(() => masteryPath(storage, paper.id, q.n) || (q.mastery && q.mastery.path) || null);
  const [m, setM] = useState<Mastery | undefined>(q.mastery);
  const act = async (action: 'event' | 'explain' | 'ask', body: Record<string, unknown>) => {
    const r = await witness.mastery(env, paper.id, q.n, action, body);
    if (r.ok) setM(r.value.mastery); else setSaid(r.error);
    return r.ok ? r.value.mastery : null;
  };
  // the exam's teacher looks at each level first: it opens once they let the student start (28 Oct)
  const held = !!m && m.status === 'held';
  // a level played to the end on this phone tells the teacher once
  useEffect(() => {
    if (path && masteryDone(storage, path) && (!m || (m.status !== 'completed' && m.status !== 'badge' && m.status !== 'not_yet'))) { void act('event', {event: 'completed'}); }
  }, [path]); // eslint-disable-line react-hooks/exhaustive-deps
  const [building, setBuilding] = useState('');
  const [said, setSaid] = useState('');
  // the fresh question the teacher set, worked on paper and filmed like the exam
  const [filming, setFilming] = useState('');
  const film = async (source: 'camera' | 'gallery') => {
    setSaid('');
    let file: VideoFile | null = null;
    try { const n = docs(); file = source === 'camera' && n && n.takeVideo ? await n.takeVideo(RECORD_SECONDS) : await chooseVideo(source); }
    catch (e) { setSaid('The camera could not start. Try choosing a video you already recorded.'); return; }
    if (!file) return;
    if (!doorMime(file.mime, file.name)) { setSaid('Witness reads MP4 and MOV videos. Record it again with the camera here.'); return; }
    setFilming('Making the video smaller to send…');
    file = await smaller(file, p => setFilming(`Making the video smaller to send… ${p}%`));
    const mime = doorMime(file.mime, file.name)!;
    setFilming('Getting the upload ready…');
    const r = await witness.mastery(env, paper.id, q.n, 'fresh', {mime, size: Math.round(file.size)});
    if (!r.ok || !r.value.fresh) { setFilming(''); setSaid(r.ok ? 'Try again in a moment.' : r.error); return; }
    setM(r.value.mastery);
    setFilming('Sending your answer…');
    const status = await sendClip(file.uri, r.value.fresh.put, mime);
    if (status < 200 || status >= 300) { setFilming(''); setSaid('The video did not go up. Check your connection, on Wi-Fi if you can, and try again.'); return; }
    setFilming('Witness is reading how you worked…');
    const marked = await witness.mark(env, r.value.fresh.id, PHONE_FPS);
    setFilming('');
    if (!marked.ok) { setSaid(marked.error); return; }
    setM(prev => (prev ? {...prev, fresh: {status: 'marking'}} : prev));
  };
  const start = async () => {
    if (path && held) { const r = await witness.mine(env); const p = r.ok ? (r.value.papers || []).find(x => x.id === paper.id) : undefined;
      const now = p && p.result ? p.result.questions.find(x => x.n === q.n) : undefined; if (now && now.mastery) setM(now.mastery);
      if (!now || !now.mastery || now.mastery.status === 'held') return; }
    if (path) { if (onOpenPath) onOpenPath(path); return; }
    setSaid(''); setBuilding('Planning your level…');
    const off = onBuildProgress(st => setBuilding(st.stage === 'write' ? 'Writing your lessons…' : st.stage === 'check' ? 'Playing it through as you, to be sure it teaches this…' : st.stage === 'review' ? 'Checking the plan…' : st.stage === 'redesign' ? 'Making it sharper…' : 'Planning your level…'));
    const made = await buildMastery(env, storage, paper, q);
    off(); setBuilding('');
    if (made.ok && made.pathId) {
      setPath(made.pathId);
      const after = await act('event', {event: 'built', path: made.pathId, check: made.checked, level: made.outline});
      if (after && after.status !== 'held' && onOpenPath) onOpenPath(made.pathId);
    }
    else setSaid(failedWords(made.reason, made.text));
  };
  return (
    <View style={[s.card, next ? s.next : null]} testID={'witness-q-' + q.n}>
      <View style={s.rowTop}>
        <Text style={s.rowTitle}>Question {q.n}</Text>
        {/* once the teacher issues the badge, the question reads as turned around, not as still to fix */}
        <Text style={[s.chip, next && !(m && m.status === 'badge') ? s.chipNext : s.chipOk]}>{m && m.status === 'badge' ? 'Turned around' : RESULT_WORDS[r]}</Text>
      </View>
      <Text style={s.sub}>{marksOf(q)} of {q.out_of} marks</Text>
      <Replay q={q} />
      {next && q.diagnosis && q.moment_s == null ? <Text style={s.diag}>{q.diagnosis}</Text> : null}
      {q.comment && q.comment.text ? <Text style={s.comment} testID={'witness-comment-' + q.n}>Your teacher: {q.comment.text}</Text> : null}
      {next && (paper.result?.stills || []).some(x => x.n === q.n) ? (
        <Picture env={env} paperId={paper.id} file={(paper.result?.stills || []).find(x => x.n === q.n)!.asset}
          label={'Your desk at ' + clock(q.moment_s) + ', question ' + q.n} testID={'witness-still-' + q.n} />
      ) : null}
      {q.drawn && q.drawn.status === 'done' && q.drawn.asset ? (
        <View>
          <Text style={s.rowTitle}>The step, corrected</Text>
          <Picture env={env} paperId={paper.id} file={q.drawn.asset} label={'The corrected working: ' + (q.drawn.lines || []).join(', ')} testID={'witness-drawn-' + q.n} />
        </View>
      ) : null}
      {next ? (
        <View style={{marginTop: 10}}>
          {building ? <View style={s.buildRow}><ActivityIndicator /><Text style={s.small}> {building}</Text></View>
            : held ? <View><Text style={s.small} testID={'witness-held-' + q.n}>Your level is made. Your teacher is looking at it first; it opens here once they let you start.</Text>
                <Btn label="Has my teacher let me start?" onPress={start} small testID={'witness-held-look-' + q.n} /></View>
            : <Btn label={path ? 'Open my mastery level' : 'Start my mastery level'} onPress={start} primary testID={'witness-master-' + q.n} />}
          {said ? <Text style={s.error}>{said}</Text> : null}
          <AfterLevel m={m} act={act} film={film} filming={filming} />
        </View>
      ) : null}
    </View>
  );
}

/** After the level: the badge or the teacher's word, only the checks the teacher asked for, and ask my teacher. */
const FRESH_WORDS: Record<string, string> = {
  marking: 'Witness is reading it. Your teacher will see how you worked.',
  marked: 'Sent. Your teacher has your answer.',
  failed: 'Witness could not read that video. Film it again.',
};

function AfterLevel({m, act, film, filming}: {m?: Mastery; act(action: 'explain' | 'ask', body: Record<string, unknown>): Promise<unknown>; film(source: 'camera' | 'gallery'): void; filming: string}): React.JSX.Element | null {
  const [toLo, setToLo] = useState('');
  const [toTeacher, setToTeacher] = useState('');
  const [question, setQuestion] = useState('');
  const asks = (m && m.asks) || {};
  const told = (m && m.explained) || [];
  return (
    <View style={{marginTop: 12}}>
      {m && m.status === 'badge' ? <Text style={s.badge} testID="witness-badge">Turned around{m.badge && m.badge.note ? ' · ' + m.badge.note : ''}</Text> : null}
      {m && m.status === 'not_yet' ? <Text style={s.diag}>Your teacher says not yet{m.badge && m.badge.note ? ': ' + m.badge.note : '.'}</Text> : null}
      {m && m.status === 'completed' ? <Text style={s.small}>Level done. Your teacher will look at your work.</Text> : null}
      {asks.lo && (told.indexOf('lo') < 0 || m?.lo_next) ? (
        <View style={{marginTop: 10}}>
          <Text style={s.rowTitle}>Explain it back to Lo</Text>
          {m && m.lo_next ? <Text style={s.sub}>Lo: {m.lo_next}</Text> : <Text style={s.sub}>In your own words: what went wrong, and what is right?</Text>}
          <TextInput value={toLo} onChangeText={setToLo} multiline style={s.input} accessibilityLabel="Your explanation for Lo" testID="witness-explain-lo" />
          <Btn label="Tell Lo" onPress={async () => { if (await act('explain', {to: 'lo', text: toLo})) setToLo(''); }} small />
        </View>
      ) : null}
      {asks.teacher && told.indexOf('teacher') < 0 ? (
        <View style={{marginTop: 10}}>
          <Text style={s.rowTitle}>Explain it back to your teacher</Text>
          <TextInput value={toTeacher} onChangeText={setToTeacher} multiline style={s.input} accessibilityLabel="Your explanation for your teacher" testID="witness-explain-teacher" />
          <Btn label="Send to my teacher" onPress={async () => { if (await act('explain', {to: 'teacher', text: toTeacher})) setToTeacher(''); }} small />
        </View>
      ) : null}
      {asks.paper && asks.fresh ? (
        <View style={{marginTop: 10}} testID="witness-fresh">
          <Text style={s.rowTitle}>A fresh question from your teacher</Text>
          <Text style={s.step}>{asks.fresh}</Text>
          {m && m.fresh && FRESH_WORDS[m.fresh.status] ? <Text style={s.sub}>{FRESH_WORDS[m.fresh.status]}</Text> : null}
          {filming ? <View style={s.buildRow}><ActivityIndicator /><Text style={s.small}> {filming}</Text></View>
            : !m || !m.fresh || m.fresh.status === 'uploading' || m.fresh.status === 'failed' ? (
              <View>
                <Text style={s.sub}>Work it on paper and film your hand as you write, like the exam.</Text>
                <Btn label="Film my answer" onPress={() => film('camera')} small testID="witness-fresh-film" />
                <Btn label="Choose a video" onPress={() => film('gallery')} small testID="witness-fresh-pick" />
              </View>
            ) : null}
        </View>
      ) : asks.paper ? <Text style={s.small}>Your teacher would like a fresh question on paper. They'll give it to you.</Text> : null}
      <View style={{marginTop: 10}}>
        {(m && m.thread || []).map((t, i) => <Text key={i} style={s.sub}>{t.from === 'teacher' ? 'Your teacher: ' : 'You: '}{t.text}</Text>)}
        <TextInput value={question} onChangeText={setQuestion} placeholder="Stuck? Ask your teacher" style={s.input} accessibilityLabel="Ask your teacher" testID="witness-ask" />
        <Btn label="Ask my teacher" onPress={async () => { if (question.trim() && await act('ask', {text: question})) setQuestion(''); }} small />
      </View>
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
  notice: {color: '#1b5e20', fontSize: 14, fontWeight: '600', marginBottom: 10},
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
  comment: {fontSize: 14, color: '#141a2e', marginTop: 8, fontStyle: 'italic', lineHeight: 20},
  badge: {fontSize: 15, fontWeight: '700', color: '#2e7d32', padding: 10, borderRadius: 8, backgroundColor: '#eaf3de', overflow: 'hidden'},
  diag: {fontSize: 14, color: '#1f1e1c', marginTop: 10, padding: 10, borderRadius: 8, backgroundColor: '#faeeda'},
});
