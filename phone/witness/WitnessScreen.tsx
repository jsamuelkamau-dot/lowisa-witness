/**
 * FROM EXAM TO MASTERY ON THE PHONE (2026-10-27, Meta hackathon; 29 Oct, owner: the product is From Exam to Mastery;
 * synced into the LoWisa app as src/witness/WitnessScreen.tsx).
 *
 *   1. The teacher's join code -> the exam's name.
 *   2. A student puts their name on the exam's class list.
 *   3. After the exam ONE phone (a teacher's, or one the school owns) photographs each student's finished paper, page by
 *      page. The name is read from the paper and finds the student on the class list.
 *   4. Witness (optional, one student at a time, at home or homeschooled): the phone films the desk while the student
 *      writes, so the thinking is seen as it happens.
 *   5. The paper is "with your teacher" until they release it; then it shows here, question by question. No question
 *      ends in a verdict: it is mastered, or it is in the student's Mastery Plan.
 *
 * Only shown when the edge's Witness doors answer (LOWISA_WITNESS_ACCESS); the caller checks witness.mine first.
 */
import React, {useCallback, useEffect, useState} from 'react';
import {ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, View} from 'react-native';
import {C} from '../ui/theme';
import {SoftInput} from '../ui/SoftInput';
import {Page} from '../ui/Page';
import {Btn} from '../exam/print/ui';
import {chooseVideo, doorMime, VideoFile} from '../community/video';
import {DeviceEventEmitter, NativeModules} from 'react-native';
import {capabilitiesOf, CAPABILITIES, marksOf, Paper, PLAN_WHY, Question, RESULT_WORDS, resultOf, Taken, toMaster, typedCode, witness, WitnessEnv} from './net';
import {pickImagesSafely, takePhoto, PickedDocument} from '../career/documents';
import type {MirrorStorage} from '../state/storage';
import type {CustomEnv} from '../paths/custom/course';
import {onBuildProgress} from '../paths/custom/course';
import {buildMastery, builtNews, masteryDone, masteryPath} from './mastery';
import type {Fingerprint, Mastery} from './net';
import {asksLeft} from './net';
import {AsksView} from './Examiner';
import {SayIt} from './SayIt';
import {tutorSay} from '../tutor/voice';
import {turnedAround} from './net';
import {clock, Picture, ProofView, Replay} from './Proof';

/** The camera app is told to stop here: SAM 3.1 follows up to about ten minutes of video in one go. */
export const RECORD_SECONDS = 600;
/** The phone's own recordings play at a steady rate; this is what the marking is told when nothing better is known. */
export const PHONE_FPS = 30;

type Stage =
  | {kind: 'home'}
  | {kind: 'joined'; code: string; title: string; level: string; practical?: boolean}
  | {kind: 'listed'; title: string; name: string}
  | {kind: 'photos'; code: string; title: string}
  | {kind: 'witness'; code: string; title: string; level: string}
  | {kind: 'sending'; title: string; line: string}
  | {kind: 'sent'; title: string; id: string}
  | {kind: 'asks'; paper: Paper}
  | {kind: 'proof'; paper: Paper}
  | {kind: 'paper'; paper: Paper};

interface Native { uploadPart?(uri: string, url: string, offset: number, length: number): Promise<number>; uploadFile?(uri: string, url: string, contentType: string): Promise<number>; takeVideo?(maxSeconds: number): Promise<VideoFile | null>; witnessCamera?(maxSeconds: number): Promise<VideoFile | null>; smallVideo?(uri: string): Promise<VideoFile | null>; lastClip?(sinceMs: number): Promise<VideoFile | null>; removeFile?(uri: string): void }
const docs = () => (NativeModules as Record<string, unknown>).LoWisaDocuments as Native | undefined;

/** A paper recorded with the Witness camera (a guide frame on the page, the screen dimmed; 28 Oct re-audit), or the
 *  phone's own camera app on a build without it. */
export async function record(n: Native, onHandOver?: () => void): Promise<VideoFile | null> {
  if (!n.witnessCamera) return n.takeVideo!(RECORD_SECONDS);
  try { return await n.witnessCamera(RECORD_SECONDS); }
  catch (e) {
    // 28 Oct, live: a camera the Witness camera cannot record on hands over to the phone's own camera app at once
    if ((e as {code?: string}).code !== 'witness_camera_failed' || !n.takeVideo) throw e;
    if (onHandOver) onHandOver();
    return n.takeVideo(RECORD_SECONDS);
  }
}

/** Said when the Witness camera hands over to the phone's camera app. */
export const HAND_OVER_WORDS = "The Witness camera couldn't record on this phone, so your phone's own camera opens instead. Record your paper there.";

/** What the student is shown went wrong (pure): once Lo's question has completed the fingerprint, what their working AND
 *  their answer showed; until then the marking's own reading (30 Oct, rehearsal: the card still said "cancel" after
 *  Leo's answer showed the base was the idea to fix). */
export function whatShows(q: Question, fp?: Fingerprint | null): {label: string; text: string} | null {
  const f = fp === undefined ? q.fingerprint : fp;
  if (f && f.misconception && (f.said || []).length) return {label: 'What your working and your answer to Lo show', text: f.misconception};
  return q.diagnosis ? {label: 'What your working shows', text: q.diagnosis} : null;
}

/** What Lo says for "Hear it" on a question: the result, the marks, what went wrong and the teacher's words (pure). */
export function spokenFeedback(q: Question, fp?: Fingerprint | null): string {
  const parts = ['Question ' + q.n + '. ' + (turnedAround(q) ? 'Turned around.' : RESULT_WORDS[resultOf(q)] + '.'),
    'You got ' + marksOf(q) + ' of ' + q.out_of + ' marks.'];
  const shows = whatShows(q, fp);
  if (shows && !turnedAround(q)) parts.push(shows.label + ': ' + shows.text);
  if (q.comment && q.comment.text) parts.push('Your teacher says: ' + q.comment.text);
  return parts.join(' ');
}

/**
 * A desk video made small enough to send on a phone's data: 720p, ten frames a second, about 8 MB a minute where the
 * camera made some 120 (27 Oct). The original goes when it is small already, or when this phone cannot make it smaller.
 */
export async function smaller(file: VideoFile, onPercent?: (percent: number, stage: 'faces' | 'small') => void): Promise<VideoFile> {
  const n = docs();
  if (!n || !n.smallVideo) return file;
  const sub = onPercent ? DeviceEventEmitter.addListener('lowisaSmallVideo', (e: {percent?: number; stage?: string}) => {
    if (typeof e?.percent === 'number') onPercent(Math.max(0, Math.min(100, Math.round(e.percent))), e.stage === 'faces' ? 'faces' : 'small');
  }) : null;
  try { return (await n.smallVideo(file.uri)) || file; } catch (e) { return file; } finally { sub?.remove(); }
}

/** What the phone says while the video is got ready: first the look for faces to cover, then making it smaller (28 Oct). */
export function readyLine(percent: number, stage: 'faces' | 'small'): string {
  return (stage === 'faces' ? 'Covering any face the camera caught… ' : 'Making the video smaller to send… ') + percent + '%';
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
 * A long video in parts (2026-10-28, the plan: "in chunks, resumable, so a bad connection loses nothing"): each part
 * from its own offset on its own link, three tries each like sendClip. True when every part given went up; a part that
 * still fails stops it, and the parts already up stay up for the next try.
 */
export async function sendParts(uri: string, total: number, partSize: number, urls: Array<{n: number; url: string}>, onPart?: (done: number) => void,
                                wait = (ms: number) => new Promise<void>(r => setTimeout(r, ms))): Promise<boolean> {
  const up = docs();
  if (!up || !up.uploadPart) return false;
  let done = 0;
  for (const {n, url} of urls) {
    const offset = (n - 1) * partSize;
    const length = Math.min(partSize, total - offset);
    let status = 0;
    for (let i = 0; i < 3; i++) {
      try { status = await up.uploadPart(uri, url, offset, length); } catch (e) { status = 0; }
      if ((status >= 200 && status < 300) || (status >= 400 && status < 500)) break;
      if (i < 2) await wait(i === 0 ? 2000 : 6000);
    }
    if (status < 200 || status >= 300) return false;
    done++;
    if (onPart) onPart(done);
  }
  return true;
}

/** Whether this phone can send a video in parts (a phone without the native part upload sends it whole). */
export function canSendParts(): boolean { const up = docs(); return !!(up && up.uploadPart); }

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

/** Deletes the phone's own copies of a paper's video once it is sent (only files in the app's cache; never the gallery's). */
export function forgetClips(uris: string[], n: Native | null | undefined = docs()): void {
  if (!n || !n.removeFile) return;
  for (const u of Array.from(new Set(uris.filter(Boolean)))) { try { n.removeFile(u); } catch (e) { /* the cache drops it later */ } }
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
  // a video in parts that did not finish: its sitting, so "send again" sends only the parts that did not arrive
  const [resumeOf, setResumeOf] = useState<{id: string; uri: string} | null>(null);
  const [notice, setNotice] = useState('');

  // a recording the camera app made while Android stopped this app (PENDING_KEY): offered as soon as Witness opens
  useEffect(() => {
    let live = true;
    keptRecording(storage).then(k => {
      if (!live || !k) return;
      setName(k.pending.name);
      setUnsent(k.clip);
      setStage({kind: 'witness', code: k.pending.code, title: k.pending.title, level: k.pending.level});
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
    setStage({kind: 'joined', code, title: r.value.pile.title, level: r.value.pile.level, practical: r.value.pile.kind === 'practical'});
  };

  // a student puts their name on the exam's class list: the paper photographed after the exam finds them by it
  const listMe = async () => {
    if (stage.kind !== 'joined') return;
    setError('');
    if (!name.trim()) { setError('Write your name as you write it on your paper.'); return; }
    setBusy(true);
    const r = await witness.join(env, stage.code, name.trim());
    setBusy(false);
    if (!r.ok) { setError(r.error); return; }
    setStage({kind: 'listed', title: stage.title, name: name.trim()});
  };

  const sit = async (source: 'camera' | 'gallery') => {
    if (stage.kind !== 'witness') return;
    setError('');
    if (!name.trim()) { setError('Write your name as your teacher knows it.'); return; }
    let file: VideoFile | null = null;
    const n = docs();
    const camera = source === 'camera' && !!n && !!(n.witnessCamera || n.takeVideo);
    if (camera) storage.setItem(PENDING_KEY, JSON.stringify({code: stage.code, title: stage.title, level: stage.level, name: name.trim(), at: Date.now()}));
    // the camera app records up to ten minutes here (the composer's own recordings stop at two)
    try { file = camera ? await record(n!, () => setNotice(HAND_OVER_WORDS)) : await chooseVideo(source); }
    catch (e) { if (camera) storage.removeItem(PENDING_KEY); setError('The camera could not start. Try choosing a video you already recorded.'); return; }
    if (!file) { if (camera) storage.removeItem(PENDING_KEY); return; }
    if (!doorMime(file.mime, file.name)) { setError('Witness reads MP4 and MOV videos. Record it again with the camera here.'); return; }
    await send(file);
  };

  const send = async (picked: VideoFile) => {
    if (stage.kind !== 'witness') return;
    setError('');
    if (!name.trim()) { setError('Write your name as your teacher knows it.'); return; }
    setNotice('');
    const {title} = stage;
    const again = (why: string, file: VideoFile) => { setStage({kind: 'witness', code: stage.code, title, level: stage.level}); setUnsent(file); setError(why); };
    // 28 Oct, live: a resumed send made the kept copy again (a person off the page is always covered), so it was a new
    // file and the upload started over; the copy already made is sent as it is
    const resuming = !!resumeOf && resumeOf.uri === picked.uri;
    if (!resuming) setStage({kind: 'sending', title, line: 'Covering any face the camera caught…'});
    const file = resuming ? picked : await smaller(picked, (p, st) => setStage({kind: 'sending', title, line: readyLine(p, st)}));
    const mime = doorMime(file.mime, file.name)!;
    const kept = 'The video did not go up. It is kept on this phone: send it again when the connection is better, on Wi-Fi if you can.';
    const total = Math.round(file.size);
    // the parts that did not arrive last time are all that is sent again, on the same sitting
    let id = resumeOf && resumeOf.uri === file.uri ? resumeOf.id : '';
    let urls: Array<{n: number; url: string}> = []; let partSize = 0;
    if (id) {
      const left = await witness.parts(env, id);
      if (left.ok && left.value.urls.length) { urls = left.value.urls; partSize = left.value.size; }
      else if (!left.ok || left.value.status) id = '';
    }
    if (!id) {
      setStage({kind: 'sending', title, line: 'Getting the upload ready…'});
      const started = await witness.start(env, total, mime, stage.code, name.trim(), canSendParts());
      if (!started.ok) { again(started.error, file); return; }
      id = started.value.id;
      if (started.value.parts) { urls = started.value.parts.urls; partSize = started.value.parts.size; }
      else {
        setStage({kind: 'sending', title, line: 'Sending your paper…'});
        const status = await sendClip(file.uri, started.value.put || '', mime);
        if (status < 200 || status >= 300) { again(kept, file); return; }
      }
    }
    if (urls.length) {
      const count = Math.ceil(total / partSize);
      const base = count - urls.length;
      setStage({kind: 'sending', title, line: 'Sending your paper… ' + Math.round(base / count * 100) + '%'});
      const ok = await sendParts(file.uri, total, partSize, urls, d => setStage({kind: 'sending', title, line: 'Sending your paper… ' + Math.round((base + d) / count * 100) + '%'}));
      if (!ok) { setResumeOf({id, uri: file.uri}); again(kept, file); return; }
    }
    setResumeOf(null);
    setUnsent(null);
    storage.removeItem(PENDING_KEY);
    setStage({kind: 'sending', title, line: 'Reading how you worked…'});
    let marked = await witness.mark(env, id, PHONE_FPS);
    if (!marked.ok && marked.code === 'parts_missing') {
      // a part the store does not have yet (it answered, then lost it): sent once more before giving up
      const left = await witness.parts(env, id);
      if (left.ok && left.value.urls.length && await sendParts(file.uri, total, left.value.size, left.value.urls)) marked = await witness.mark(env, id, PHONE_FPS);
    }
    if (!marked.ok) { setStage({kind: 'witness', code: stage.code, title, level: stage.level}); setError(marked.error); return; }
    // 29 Oct audit ("the video is deleted once your paper is marked"): the server has it now, so the phone's own copies
    // go (the recording and the smaller copy it made; a video picked from the gallery is the student's and is left)
    forgetClips([picked.uri, file.uri]);
    setStage({kind: 'sent', title, id});
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
    <Page title="From Exam to Mastery" subtitle="Exams on paper" onBack={back}>
      <ScrollView contentContainerStyle={s.page} keyboardShouldPersistTaps="handled" testID="witness-screen">
        {error ? <Text style={s.error} accessibilityRole="alert" testID="witness-error">{error}</Text> : null}

        {stage.kind === 'home' ? (
          <>
            <View style={s.card}>
              <Text style={s.h}>Your exam on paper</Text>
              <Text style={s.sub}>Sit the exam on paper as you always do. Afterwards it is marked for how you thought, not only your answers, and every question you didn't master becomes your Mastery Plan.</Text>
              <SoftInput value={code} onChangeText={t => setCode(typedCode(t))} placeholder="Join code" autoCapitalize="characters" maxLength={6}
                style={[s.input, s.code]} accessibilityLabel="Your teacher's join code" testID="witness-code" />
              <Btn label={busy ? 'Checking…' : 'Find the exam'} onPress={join} primary disabled={busy} testID="witness-join" />
            </View>
            <Mine papers={papers} onOpen={p => setStage(p.status === 'released' ? {kind: 'paper', paper: p} : {kind: 'asks', paper: p})} />
          </>
        ) : null}

        {stage.kind === 'joined' ? (
          <>
            <View style={s.card}>
              <Text style={s.h} testID="witness-exam-title">{stage.title}</Text>
              {stage.level ? <Text style={s.sub}>{stage.level}</Text> : null}
              <Text style={s.rowTitle}>I'm sitting this exam</Text>
              <Text style={s.sub}>Put your name on the class list, as you write it on your paper. Your marked paper and your Mastery Plan come back here.</Text>
              <SoftInput value={name} onChangeText={setName} placeholder="Your name" maxLength={80}
                style={s.input} accessibilityLabel="Your name" testID="witness-list-name" />
              <Btn label={busy ? 'Adding you…' : 'Put me on the class list'} onPress={listMe} primary disabled={busy} testID="witness-list-me" />
            </View>
            {!stage.practical ? (
              <View style={s.card}>
                <Text style={s.rowTitle}>Photograph the papers</Text>
                <Text style={s.sub}>After the exam, a single phone photographs every student's paper: a teacher's phone, or one the school owns. Each paper's name is read from the paper itself.</Text>
                <Btn label="Photograph the papers" onPress={() => { setError(''); setStage({kind: 'photos', code: stage.code, title: stage.title}); }} testID="witness-photos" />
              </View>
            ) : null}
            <View style={s.card}>
              <Text style={s.rowTitle}>Witness (optional)</Text>
              <Text style={s.sub}>For one student working alone, at home or homeschooled: the phone films the desk while you write, so your thinking is seen as it happens{stage.practical ? '. A practical task is always filmed.' : ', not only the finished page.'}</Text>
              <Btn label="Film my desk with Witness" onPress={() => { setError(''); setStage({kind: 'witness', code: stage.code, title: stage.title, level: stage.level}); }} testID="witness-film" />
            </View>
          </>
        ) : null}

        {stage.kind === 'listed' ? (
          <View style={s.card} testID="witness-listed">
            <Text style={s.h}>You're on the class list</Text>
            <Text style={s.sub}>{stage.name}, for {stage.title}. After the exam your paper is photographed and marked. Every question you didn't master comes back here as your Mastery Plan.</Text>
            <Btn label="Done" onPress={back} primary testID="witness-listed-done" />
          </View>
        ) : null}

        {stage.kind === 'photos' ? <PhotoDesk env={env} code={stage.code} title={stage.title} /> : null}

        {stage.kind === 'witness' ? (
          <View style={s.card}>
            <Text style={s.h} testID="witness-exam-title">{stage.title}</Text>
            {stage.level ? <Text style={s.sub}>{stage.level}</Text> : null}
            <Text style={s.sub}>Witness films your desk while you write, so your teacher sees how you thought, step by step.</Text>
            <SoftInput value={name} onChangeText={setName} placeholder="Your name, as your teacher knows it" maxLength={80}
              style={s.input} accessibilityLabel="Your name" testID="witness-name" />
            <Text style={s.how}>Prop your phone above the desk so it sees the whole page and your hand. Keep faces out of view: any face the camera catches is covered before the video leaves your phone. Then work through the paper and stop the recording when you finish.</Text>
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
            <Text style={s.sub}>Your paper for {stage.title} is with your teacher. Your marks show here once they release them, with your Mastery Plan.</Text>
            {waitingAsks ? (
              <View style={{marginBottom: 10}}>
                <Text style={s.sub}>There {asksLeft(waitingAsks).length === 1 ? 'is a question' : 'are two questions'} about steps you wrote.</Text>
                <Btn label="Answer about my work" onPress={() => setStage({kind: 'asks', paper: waitingAsks})} primary testID="witness-open-asks" />
              </View>
            ) : <Text style={s.small}>You may be asked about a step you wrote. Stay here a moment.</Text>}
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
        const line = p.status === 'released' ? (left ? left + ' in your Mastery Plan' : 'All mastered') : p.status === 'failed' ? (p.unseen ? 'Paper not in view: record it again' : 'Record it again')
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
  if (reason === 'no-credits' || reason === 'full' || reason === 'refused') return text;
  if (reason === 'no-network' || reason === 'no-auth') return 'No connection right now. Try again when you are back online.';
  if (reason === 'timeout') return 'That took too long. Tap Start my mastery level to try again.';
  return 'Your level could not be made just now. Tap Start my mastery level to try again in a moment.';
}

function PaperView({paper, env, storage, onOpenPath, onProof}: {paper: Paper; env: CustomEnv & WitnessEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void; onProof(): void}): React.JSX.Element {
  const qs = (paper.result && paper.result.questions) || [];
  const got = qs.reduce((a, q) => a + marksOf(q), 0);
  const of = qs.reduce((a, q) => a + (q.out_of || 0), 0);
  // the Mastery Plan first: every question not mastered, then the ones mastered on the paper
  const plan = qs.filter(q => resultOf(q) !== 'mastered');
  const done = qs.filter(q => resultOf(q) === 'mastered');
  return (
    <>
      <View style={s.card} testID="witness-result">
        <Text style={s.h}>{paper.title || 'Your paper'}</Text>
        <Text style={s.sub}>{got} of {of} marks · {toMaster(paper).length ? toMaster(paper).length + ' in your Mastery Plan' : 'all mastered'}</Text>
        <Btn label="My Proof of Thinking" onPress={onProof} small testID="witness-proof-open" />
      </View>
      {plan.length ? <Text style={s.section} testID="witness-plan-title">Your Mastery Plan</Text> : null}
      {plan.map(q => <QuestionCard key={q.n} q={q} paper={paper} env={env} storage={storage} onOpenPath={onOpenPath} />)}
      {done.length ? <Text style={s.section}>Mastered</Text> : null}
      {done.map(q => <QuestionCard key={q.n} q={q} paper={paper} env={env} storage={storage} onOpenPath={onOpenPath} />)}
    </>
  );
}

function QuestionCard({q, paper, env, storage, onOpenPath}: {q: Question; paper: Paper; env: CustomEnv & WitnessEnv; storage: MirrorStorage; onOpenPath?(pathId: string): void}): React.JSX.Element {
  const r = resultOf(q);
  // 29 Oct (owner): every question not mastered is in the Mastery Plan
  const next = r !== 'mastered';
  const [path, setPath] = useState<string | null>(() => masteryPath(storage, paper.id, q.n) || (q.mastery && q.mastery.path) || null);
  const [m, setM] = useState<Mastery | undefined>(q.mastery);
  // 30 Oct (owner): the Misconception Fingerprint; while Lo still has a diagnostic question, it comes before the level
  const [fp, setFp] = useState<Fingerprint | null | undefined>(q.fingerprint);
  const asking = !path && !!fp && !!fp.ask && (fp.said || []).length < 2;
  // Lo answers the answer: the learner hears that it landed (30 Oct, rehearsal: the card just vanished)
  const [loThanks, setLoThanks] = useState('');
  const act = async (action: 'event' | 'explain' | 'ask' | 'challenge_answer', body: Record<string, unknown>) => {
    const r = await witness.mastery(env, paper.id, q.n, action, body);
    if (r.ok) { setM(r.value.mastery); setSaid(''); } else setSaid(r.error);
    return r.ok ? r.value.mastery : null;
  };
  // 30 Oct (owner): what the teacher sends after the level (a new challenge, a reply, Turned around) reaches an open screen
  // too: looked for every 20 seconds while the question is still to turn around
  useEffect(() => {
    if (!next || (m && m.status === 'badge')) return undefined;
    let live = true;
    const timer = setInterval(async () => {
      const r = await witness.mine(env);
      const p = r.ok ? (r.value.papers || []).find(x => x.id === paper.id) : undefined;
      const now = p && p.result ? p.result.questions.find(x => x.n === q.n) : undefined;
      if (live && now && now.mastery) setM(prev => (JSON.stringify(prev) === JSON.stringify(now.mastery) ? prev : now.mastery));
    }, 20000);
    return () => { live = false; clearInterval(timer); };
  }, [next, m && m.status, env, paper.id, q.n]); // eslint-disable-line react-hooks/exhaustive-deps
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
    try { const n = docs(); file = source === 'camera' && n && (n.witnessCamera || n.takeVideo) ? await record(n, () => setSaid(HAND_OVER_WORDS)) : await chooseVideo(source); }
    catch (e) { setSaid('The camera could not start. Try choosing a video you already recorded.'); return; }
    if (!file) return;
    if (!doorMime(file.mime, file.name)) { setSaid('Witness reads MP4 and MOV videos. Record it again with the camera here.'); return; }
    setFilming('Covering any face the camera caught…');
    file = await smaller(file, (p, st) => setFilming(readyLine(p, st)));
    const mime = doorMime(file.mime, file.name)!;
    setFilming('Getting the upload ready…');
    const r = await witness.mastery(env, paper.id, q.n, 'fresh', {mime, size: Math.round(file.size)});
    if (!r.ok || !r.value.fresh) { setFilming(''); setSaid(r.ok ? 'Try again in a moment.' : r.error); return; }
    setM(r.value.mastery);
    setFilming('Sending your answer…');
    const status = await sendClip(file.uri, r.value.fresh.put, mime);
    if (status < 200 || status >= 300) { setFilming(''); setSaid('The video did not go up. Check your connection, on Wi-Fi if you can, and try again.'); return; }
    setFilming('Reading how you worked…');
    const marked = await witness.mark(env, r.value.fresh.id, PHONE_FPS);
    setFilming('');
    if (!marked.ok) { setSaid(marked.error); return; }
    setM(prev => (prev ? {...prev, fresh: {status: 'marking'}} : prev));
  };
  const start = async () => {
    if (path && held) { const r = await witness.mine(env); const p = r.ok ? (r.value.papers || []).find(x => x.id === paper.id) : undefined;
      const now = p && p.result ? p.result.questions.find(x => x.n === q.n) : undefined; if (now && now.mastery) setM(now.mastery);
      if (!now || !now.mastery || now.mastery.status === 'held') return; }
    // 28 Oct, live: a level built here whose news the edge refused (one account as teacher and student, before vb1028g)
    // never reached the teacher; it is told again before the level opens, and waits when the teacher looks first
    if (path && (!m || !m.status)) { const after = await act('event', {event: 'built', path, ...(builtNews(storage, path) || {})}); if (!after || after.status === 'held') return; }
    if (path) { if (onOpenPath) onOpenPath(path); return; }
    setSaid(''); setBuilding('Planning your level…');
    const off = onBuildProgress(st => setBuilding(st.stage === 'write' ? 'Writing your lessons…' : st.stage === 'check' ? 'Playing it through as you, to be sure it teaches this…' : st.stage === 'review' ? 'Checking the plan…' : st.stage === 'redesign' ? 'Making it sharper…' : 'Planning your level…'));
    const made = await buildMastery(env, storage, paper, {...q, fingerprint: fp});
    off(); setBuilding('');
    if (made.ok && made.pathId) {
      setPath(made.pathId);
      const news = {event: 'built', path: made.pathId, check: made.checked, level: made.outline};
      // one dropped connection must not lose the teacher's news: asked once more before the student is told to try again
      const after = (await act('event', news)) || (await new Promise(res => setTimeout(res, 3000)).then(() => act('event', news)));
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
      {next && !(m && m.status === 'badge') && PLAN_WHY[r] ? <Text style={s.sub}>{PLAN_WHY[r]}</Text> : null}
      <Replay q={q} />
      {/* 28 Oct re-audit (the submission: each student's feedback comes "with a short spoken explanation") */}
      <Btn label="Hear it" onPress={() => tutorSay(spokenFeedback(q, fp))} small testID={'witness-hear-' + q.n} />
      {next && whatShows(q, fp) && q.moment_s == null && !(typeof q.slip === 'number' && q.slip >= 1) ? <Text style={s.diag}>{whatShows(q, fp)!.label}: {whatShows(q, fp)!.text}</Text> : null}
      {next && capabilitiesOf(q).length ? (
        <View style={s.caps} testID={'witness-caps-' + q.n}>
          <Text style={s.capsHead}>Thinking it builds</Text>
          {capabilitiesOf(q).map(c => <Text key={c} style={s.cap}><Text style={s.capName}>{c}</Text>: {CAPABILITIES[c]}</Text>)}
        </View>
      ) : null}
      {q.comment && q.comment.text ? <Text style={s.comment} testID={'witness-comment-' + q.n}>Your teacher: {q.comment.text}</Text> : null}
      {next && (paper.result?.stills || []).some(x => x.n === q.n && !!x.asset) ? (
        <Picture env={env} paperId={paper.id} file={(paper.result?.stills || []).find(x => x.n === q.n)!.asset || ''}
          label={(paper.result?.stills || []).find(x => x.n === q.n)!.t == null ? 'Your answer on your paper, question ' + q.n : 'Your desk at ' + clock(q.moment_s) + ', question ' + q.n}
          testID={'witness-still-' + q.n} />
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
            : asking && fp ? <LoAsks fp={fp} send={async body => {
                const r = await witness.mastery(env, paper.id, q.n, 'diagnose', body);
                if (!r.ok) { setSaid(r.error); return false; }
                setSaid('');
                if (r.value.fingerprint) setFp(r.value.fingerprint);
                if (r.value.fingerprint && !r.value.fingerprint.ask) {
                  const line = 'Thank you. That tells me exactly which idea to work on. Your level starts from there.';
                  setLoThanks(line); tutorSay(line);
                }
                return true;
              }} />
            : <Btn label={path ? 'Open my mastery level' : 'Start my mastery level'} onPress={start} primary testID={'witness-master-' + q.n} />}
          {loThanks && !asking && !path ? <Text style={s.comment} testID={'witness-lo-thanks-' + q.n}>Lo: {loThanks}</Text> : null}
          {said ? <Text style={s.error}>{said}</Text> : null}
          <AfterLevel m={m} act={act} film={film} filming={filming} />
        </View>
      ) : null}
    </View>
  );
}

/** After the level: the badge or the teacher's word, only the checks the teacher asked for, and ask my teacher. */
const FRESH_WORDS: Record<string, string> = {
  marking: 'Reading it now. Your teacher will see how you worked.',
  marked: 'Sent. Your teacher has your answer.',
  failed: 'That video could not be read. Film it again.',
};

/**
 * Lo asks first (owner, 30 Oct: the Misconception Fingerprint). When the paper alone was not enough evidence of which
 * idea produced the answer, Lo asks one diagnostic question, out loud, before the level is built; the answer, written
 * or spoken, completes the fingerprint the level is built around. At most two questions, then the level starts.
 */
export function LoAsks({fp, send}: {fp: Fingerprint; send(body: Record<string, unknown>): Promise<boolean>}): React.JSX.Element {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => { if (fp.ask) tutorSay(fp.ask); }, [fp.ask]);
  const go = async (body: Record<string, unknown>) => {
    if (busy) return;
    setBusy(true);
    const ok = await send(body);
    setBusy(false);
    if (ok) setText('');
  };
  return (
    <View style={s.challenge} testID="witness-lo-asks">
      <Text style={s.challengeHead}>Lo asks first</Text>
      <Text style={s.challengeQ}>{fp.ask}</Text>
      <Text style={s.sub}>Your answer tells Lo which idea to work on, so your level fixes exactly that.</Text>
      <Btn label="Hear it again" onPress={() => tutorSay(fp.ask)} small testID="witness-lo-asks-hear" />
      <SoftInput value={text} onChangeText={setText} multiline style={s.input} accessibilityLabel="Your answer for Lo" testID="witness-lo-asks-text" />
      <Btn label={busy ? 'Lo is reading it…' : 'Tell Lo'} onPress={() => { if (text.trim()) void go({text: text.trim()}); }} primary small testID="witness-lo-asks-send" />
      <SayIt label="Say it to Lo" onAudio={(audio, mime) => go({audio, mime})} testID="witness-lo-asks-say" />
    </View>
  );
}

/**
 * The teacher's new challenge (owner, 30 Oct): the same idea in a new situation, to show the principle is understood and
 * not the answer remembered. Lo reads it out on request; the student picks an answer and says why, once. Which option is
 * right shows only with their own answer; what Muse Spark makes of the reason is the teacher's to read.
 */
export function ChallengeCard({c, act}: {c: NonNullable<Mastery['challenge']>; act(action: 'challenge_answer', body: Record<string, unknown>): Promise<unknown>}): React.JSX.Element {
  const [pick, setPick] = useState<number | null>(null);
  const [why, setWhy] = useState('');
  const [sending, setSending] = useState(false);
  const r = c.reply;
  const send = async () => {
    if (pick == null || !why.trim() || sending) return;
    setSending(true);
    await act('challenge_answer', {pick, why: why.trim()});
    setSending(false);
  };
  return (
    <View style={s.challenge} testID="witness-challenge">
      <Text style={s.challengeHead}>A new challenge from your teacher</Text>
      <Text style={s.challengeQ}>{c.q}</Text>
      {!r ? <Btn label="Hear it" onPress={() => tutorSay(c.q + ' ' + c.options.map((o, i) => (i + 1) + ': ' + o + '.').join(' '))} small testID="witness-challenge-hear" /> : null}
      {c.options.map((o, i) => {
        const chosen = r ? r.pick === i : pick === i;
        const right = !!r && r.answer === i;
        return (
          <Pressable key={i} onPress={() => { if (!r) setPick(i); }} disabled={!!r} accessibilityRole="button" accessibilityState={{selected: chosen}}
            style={[s.option, chosen ? s.optionOn : null, right ? s.optionRight : null, r && chosen && !r.right ? s.optionWrong : null]} testID={'witness-challenge-option-' + i}>
            <Text style={s.optionText}>{o}{r && right ? '  ✓' : ''}</Text>
          </Pressable>
        );
      })}
      {r ? (
        <Text style={r.right ? s.challengeRight : s.diag} testID="witness-challenge-result">
          {r.right ? 'Right. Your teacher has your answer and your reason.' : 'Not this time: the right answer is ' + c.options[r.answer] + '. Your teacher has your reason and will help.'}
        </Text>
      ) : (
        <View>
          <Text style={s.sub}>Why? In your own words, how you got it.</Text>
          <SoftInput value={why} onChangeText={setWhy} multiline style={s.input} accessibilityLabel="Why, in your own words" testID="witness-challenge-why" />
          <Btn label={sending ? 'Sending…' : 'Send my answer'} onPress={send} primary small testID="witness-challenge-send" />
          {pick == null || !why.trim() ? <Text style={s.small}>Pick an answer and say why, then send it.</Text> : null}
        </View>
      )}
    </View>
  );
}

function AfterLevel({m, act, film, filming}: {m?: Mastery; act(action: 'explain' | 'ask' | 'challenge_answer', body: Record<string, unknown>): Promise<unknown>; film(source: 'camera' | 'gallery'): void; filming: string}): React.JSX.Element | null {
  const [toLo, setToLo] = useState('');
  const [toTeacher, setToTeacher] = useState('');
  const [question, setQuestion] = useState('');
  const asks = (m && m.asks) || {};
  const told = (m && m.explained) || [];
  return (
    <View style={{marginTop: 12}}>
      {m && m.status === 'badge' ? <Text style={s.badge} testID="witness-badge">Turned around{m.badge && m.badge.note ? ' · ' + m.badge.note : ''}</Text> : null}
      {m && m.status === 'not_yet' ? <Text style={s.diag}>Keep going: your teacher would like a little more{m.badge && m.badge.note ? ': ' + m.badge.note : '.'}</Text> : null}
      {m && m.status === 'completed' ? <Text style={s.small}>Level done. Your teacher will look at your work.</Text> : null}
      {asks.lo && (told.indexOf('lo') < 0 || m?.lo_next) ? (
        <View style={{marginTop: 10}}>
          <Text style={s.rowTitle}>Explain it back to Lo</Text>
          {m && m.lo_next ? <Text style={s.sub}>Lo: {m.lo_next}</Text> : <Text style={s.sub}>In your own words: what went wrong, and what is right?</Text>}
          <SoftInput value={toLo} onChangeText={setToLo} multiline style={s.input} accessibilityLabel="Your explanation for Lo" testID="witness-explain-lo" />
          <Btn label="Tell Lo" onPress={async () => { if (await act('explain', {to: 'lo', text: toLo})) setToLo(''); }} small />
          <SayIt label="Say it to Lo" onAudio={(audio, mime) => act('explain', {to: 'lo', audio, mime})} testID="witness-say-lo" />
        </View>
      ) : null}
      {asks.teacher && told.indexOf('teacher') < 0 ? (
        <View style={{marginTop: 10}}>
          <Text style={s.rowTitle}>Explain it back to your teacher</Text>
          <SoftInput value={toTeacher} onChangeText={setToTeacher} multiline style={s.input} accessibilityLabel="Your explanation for your teacher" testID="witness-explain-teacher" />
          <Btn label="Send to my teacher" onPress={async () => { if (await act('explain', {to: 'teacher', text: toTeacher})) setToTeacher(''); }} small />
          <SayIt label="Say it to my teacher" onAudio={(audio, mime) => act('explain', {to: 'teacher', audio, mime})} testID="witness-say-teacher" />
        </View>
      ) : null}
      {m && m.challenge ? <ChallengeCard key={m.challenge.at} c={m.challenge} act={act} /> : null}
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
        <SoftInput value={question} onChangeText={setQuestion} placeholder="Stuck? Ask your teacher" style={s.input} accessibilityLabel="Ask your teacher" testID="witness-ask" />
        <Btn label="Ask my teacher" onPress={async () => { if (question.trim() && await act('ask', {text: question})) setQuestion(''); }} small />
      </View>
    </View>
  );
}

/** What a photographed paper's row says once it comes back: the name read from it, and whether it found its student. */
export function takenLine(t: Taken): string {
  if (t.status === 'uploading') return 'Pages still to send';
  if (t.status === 'marking') return 'Marking: the name comes back here';
  if (t.status === 'failed') return "Couldn't be marked. Photograph it again.";
  const read = (t.read && t.read.name) || '';
  switch (t.name_match) {
    case 'read': return t.student + ' · on the class list';
    case 'teacher': return t.student + ' · set by the teacher';
    case 'unsure': return 'Name read: ' + read + ' · the teacher confirms whose it is';
    case 'none': return 'Name read: ' + read + ' · not on the class list yet';
    case 'unread': return 'No name could be read · the teacher says whose it is';
    default: return 'Marked: finding whose it is';
  }
}

/** The largest paper one phone sends at a time, in pages (the server takes up to 20). */
export const MAX_PAGES = 20;

/**
 * Photograph the papers (29 Oct, owner: From Exam to Mastery). After the exam a single phone, a teacher's or one the
 * school owns, photographs each student's finished paper page by page and sends it; the name is read from the paper.
 * Each page is a JPEG of at most 1600 pixels made on the phone (takePhoto / pickImages), sent one at a time, three tries
 * each, so a weak classroom connection costs a page, not the paper.
 */
function PhotoDesk({env, code, title}: {env: WitnessEnv; code: string; title: string}): React.JSX.Element {
  const [pages, setPages] = useState<PickedDocument[]>([]);
  const [line, setLine] = useState('');
  const [said, setSaid] = useState('');
  const [taken, setTaken] = useState<Taken[] | null>(null);
  const load = useCallback(async () => { const r = await witness.taken(env); if (r.ok) setTaken((r.value.papers || []).filter(p => p.title === title)); }, [env, title]);
  useEffect(() => { load(); }, [load]);
  // while a paper is still being marked, its name is looked for every five seconds (for up to three minutes)
  // the name is matched a moment after the marking: a marked paper with no name result yet is still waited for (29 Oct, live)
  const waiting = (taken || []).some(t => t.status === 'marking' || t.status === 'uploading' || ((t.status === 'marked' || t.status === 'released') && !t.name_match));
  useEffect(() => {
    if (!waiting) return undefined;
    let tries = 0; let live = true;
    const tick = () => { if (!live || tries++ > 36) return; load().then(() => { if (live) timer = setTimeout(tick, 5000); }); };
    let timer = setTimeout(tick, 5000);
    return () => { live = false; clearTimeout(timer); };
  }, [waiting, load]);

  const add = async (source: 'camera' | 'gallery') => {
    setSaid('');
    if (pages.length >= MAX_PAGES) { setSaid('A paper holds up to ' + MAX_PAGES + ' pages. Send this one first.'); return; }
    if (source === 'camera') {
      const shot = await takePhoto();
      if (shot && shot.base64) setPages(ps => [...ps, shot]);
      return;
    }
    const got = await pickImagesSafely(MAX_PAGES - pages.length);
    if (got.kind === 'ok') setPages(ps => [...ps, ...got.docs].slice(0, MAX_PAGES));
    else if (got.kind === 'problem') setSaid(got.text);
  };

  const sendPaper = async () => {
    if (!pages.length) return;
    setSaid('');
    setLine('Getting the paper ready…');
    const started = await witness.startPhoto(env, code, pages.length);
    if (!started.ok) { setLine(''); setSaid(started.error); return; }
    const id = started.value.id;
    for (let i = 0; i < pages.length; i++) {
      setLine('Sending page ' + (i + 1) + ' of ' + pages.length + '…');
      let ok = false; let why = '';
      for (let t = 0; t < 3 && !ok; t++) {
        const r = await witness.page(env, id, i + 1, pages[i].mime || 'image/jpeg', pages[i].base64);
        ok = r.ok; if (!r.ok) { why = r.error; if (r.status && r.status >= 400 && r.status < 500) break; await new Promise(res => setTimeout(res, t === 0 ? 2000 : 6000)); }
      }
      if (!ok) { setLine(''); setSaid('Page ' + (i + 1) + ' did not go up: ' + why + ' The pages are kept here: send the paper again.'); return; }
    }
    setLine('Marking…');
    const marked = await witness.mark(env, id, PHONE_FPS);
    setLine('');
    if (!marked.ok) { setSaid(marked.error); return; }
    setPages([]);
    setSaid('Sent. The name read from the paper comes back below. Next paper.');
    load();
  };

  return (
    <>
      <View style={s.card} testID="witness-photo-desk">
        <Text style={s.h}>{title}</Text>
        <Text style={s.sub}>Photograph one student's paper at a time: every page, the page with the name first. Lay each page flat in good light, the whole page in the photo.</Text>
        {pages.length ? (
          <ScrollView horizontal style={s.thumbs} testID="witness-photo-pages">
            {pages.map((pg, i) => (
              <Pressable key={i} onPress={() => setPages(ps => ps.filter((_, j) => j !== i))} style={s.thumbWrap} accessibilityLabel={'Page ' + (i + 1) + '. Tap to take it out'} testID={'witness-photo-page-' + (i + 1)}>
                <Image source={{uri: 'data:' + (pg.mime || 'image/jpeg') + ';base64,' + pg.base64}} style={s.thumb} resizeMode="cover" />
                <Text style={s.thumbNo}>{i + 1}</Text>
              </Pressable>
            ))}
          </ScrollView>
        ) : null}
        {line ? <View style={s.buildRow}><ActivityIndicator /><Text style={s.small}> {line}</Text></View> : (
          <>
            <Btn label={pages.length ? 'Photograph the next page' : 'Photograph page 1'} onPress={() => add('camera')} primary={!pages.length} testID="witness-photo-take" />
            <View style={{height: 8}} />
            <Btn label="Add pages from the gallery" onPress={() => add('gallery')} testID="witness-photo-pick" />
            {pages.length ? (<><View style={{height: 8}} /><Btn label={'Send this paper (' + pages.length + (pages.length === 1 ? ' page)' : ' pages)')} onPress={sendPaper} primary testID="witness-photo-send" /></>) : null}
          </>
        )}
        {pages.length ? <Text style={s.small}>Tap a page to take it out.</Text> : null}
        {said ? <Text style={s.notice} accessibilityRole="alert" testID="witness-photo-said">{said}</Text> : null}
      </View>
      <View style={s.card} testID="witness-photo-taken">
        <Text style={s.h}>Papers sent</Text>
        {taken === null ? <ActivityIndicator /> : !taken.length ? <Text style={s.sub}>None yet.</Text> : taken.map(t => (
          <View key={t.id} style={s.row} testID={'witness-taken-' + t.id}>
            <Text style={s.rowTitle}>{t.pages} {t.pages === 1 ? 'page' : 'pages'}</Text>
            <Text style={s.rowMeta}>{takenLine(t)}</Text>
          </View>
        ))}
      </View>
    </>
  );
}

const s = StyleSheet.create({
  page: {padding: 16, paddingBottom: 40},
  card: {borderWidth: 1, borderColor: C.lineSolid, borderRadius: 12, padding: 14, marginBottom: 12, backgroundColor: C.surface},
  next: {borderColor: C.amber},
  center: {alignItems: 'center'},
  h: {fontSize: 17, fontWeight: '600', color: C.ink, marginBottom: 4},
  sub: {fontSize: 14, color: C.inkSoft, lineHeight: 20, marginBottom: 10},
  how: {fontSize: 14, color: C.ink, lineHeight: 20, marginVertical: 10},
  small: {fontSize: 12, color: C.inkSoft, marginTop: 8},
  input: {borderWidth: 1, borderColor: C.lineSolid, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 10, fontSize: 16, marginBottom: 10, color: C.ink},
  code: {fontSize: 22, letterSpacing: 4, textAlign: 'center'},
  error: {color: C.pink, fontSize: 14, marginBottom: 10},
  notice: {color: C.teal, fontSize: 14, fontWeight: '600', marginBottom: 10},
  row: {paddingVertical: 10, borderTopWidth: 1, borderTopColor: C.lineSolid},
  rowTop: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'},
  rowTitle: {fontSize: 15, fontWeight: '600', color: C.ink},
  rowMeta: {fontSize: 13, color: C.inkSoft, marginTop: 2},
  chip: {fontSize: 12, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 10, overflow: 'hidden'},
  chipOk: {color: C.teal, backgroundColor: C.tealWash},
  chipNext: {color: C.amber, backgroundColor: C.amberWash},
  step: {fontSize: 15, color: C.ink, fontFamily: 'monospace', marginTop: 4},
  crossed: {textDecorationLine: 'line-through', color: C.inkFaint},
  buildRow: {flexDirection: 'row', alignItems: 'center'},
  comment: {fontSize: 14, color: C.ink, marginTop: 8, fontStyle: 'italic', lineHeight: 20},
  badge: {fontSize: 15, fontWeight: '700', color: C.teal, padding: 10, borderRadius: 8, backgroundColor: C.tealWash, overflow: 'hidden'},
  diag: {fontSize: 14, color: C.ink, marginTop: 10, padding: 10, borderRadius: 8, backgroundColor: C.amberWash},
  challenge: {marginTop: 12, padding: 12, borderRadius: 10, backgroundColor: C.brandWash, borderWidth: 1, borderColor: C.lineSolid},
  challengeHead: {fontSize: 13, fontWeight: '800', color: C.brand, textTransform: 'uppercase', letterSpacing: 0.5},
  challengeQ: {fontSize: 17, fontWeight: '700', color: C.ink, marginTop: 6, marginBottom: 8, lineHeight: 24},
  option: {borderWidth: 1, borderColor: C.lineSolid, borderRadius: 10, paddingVertical: 12, paddingHorizontal: 14, marginBottom: 8, backgroundColor: C.surface},
  optionOn: {borderColor: C.brand, borderWidth: 2},
  optionRight: {borderColor: C.teal, borderWidth: 2, backgroundColor: C.tealWash},
  optionWrong: {borderColor: C.pink, backgroundColor: C.pinkWash},
  optionText: {fontSize: 16, color: C.ink, fontWeight: '600'},
  challengeRight: {fontSize: 15, fontWeight: '700', color: C.teal, marginTop: 6, padding: 10, borderRadius: 8, backgroundColor: C.tealWash, overflow: 'hidden'},
  section: {fontSize: 13, fontWeight: '800', letterSpacing: 0.6, color: C.brand, marginTop: 6, marginBottom: 8},
  caps: {marginTop: 10, padding: 10, borderRadius: 8, backgroundColor: C.brandWash},
  capsHead: {fontSize: 12, fontWeight: '800', color: C.brand, marginBottom: 4},
  cap: {fontSize: 13, color: C.ink, lineHeight: 19},
  capName: {fontWeight: '700'},
  thumbs: {marginVertical: 10},
  thumbWrap: {marginRight: 8},
  thumb: {width: 84, height: 112, borderRadius: 6, backgroundColor: C.surfaceAlt},
  thumbNo: {position: 'absolute', left: 6, top: 4, color: '#ffffff', fontWeight: '800', textShadowColor: '#000000', textShadowRadius: 3},
});
