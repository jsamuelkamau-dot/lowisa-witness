# The film's labelled transcript, from build11's own timeline: every narrator line and every line Lo speaks, with its
# time, and the label on screen when it is said (built this week / LoWisa / sample paper). Writes transcript.md and
# exam-to-mastery.srt into the repository's evidence/film/.
import sys, os
sys.argv = ['build11.py']
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build11 as B

OUT = r'C:\lw-witness\evidence\film'


def ts(t, srt=False):
    m, s = divmod(t, 60)
    return '%02d:%02d:%02d,%03d' % (0, int(m), int(s), int((s % 1) * 1000)) if srt else '%d:%04.1f' % (int(m), s)


lines = []
for b in B.beats:
    tag = b.get('tag') or ''
    kind = ('this week' if tag.startswith(B.TAG_BUILT) else 'LoWisa, playing a level written this week' if tag.startswith('LoWisa')
            else 'sample paper' if tag == B.TAG_SAMPLE else 'the film\'s own card')
    if b.get('line'):
        lines.append((b['v0'], b['v0'] + b['vo'], 'Narrator', B.SCRIPT[b['line']], tag or 'no label (card)', kind))
    if b['kind'] == 'clip' and b.get('say'):
        c0 = b['l0'] + (b.get('say_from', b['a']) - b['a']) / b.get('speed', 1.0)
        lines.append((c0, c0 + (b['b'] - b.get('say_from', b['a'])), 'Lo (LoWisa\'s voice; words by Muse Spark)', b['say'], tag, kind))
    if b.get('wav'):
        w0 = b['t0'] + b['w0']
        lines.append((w0, w0 + b['wlen'], 'Sample learner (a synthetic voice)', B.S11.TRANSCRIPT, tag, kind))
lines.sort()

md = ['# From Exam to Mastery: the film, word for word',
      '',
      'Every line spoken in [`exam-to-mastery.mp4`](exam-to-mastery.mp4) (%s), when it is said, and the label on the screen '
      'at that moment. The narrator is a synthetic voice (Murf, voice Gordon), not a Meta model and not a person. Lo speaks in LoWisa\'s own voice; the words Lo says in a mastery level are written by Muse Spark. Daniel is a '
      'sample student and his paper was made for the demo; the learner who answers out loud is another sample learner, his '
      'answer read by a synthetic voice (Amazon Polly) and written down by Muse Voice Transcribe. Subtitles: '
      '[`exam-to-mastery.srt`](exam-to-mastery.srt).' % ('%d:%02d' % divmod(round(B.END), 60)),
      '', '| Time | Who | What is said | On screen |', '|---|---|---|---|']
srt = []
for i, (a, z, who, text, tag, kind) in enumerate(lines, 1):
    md.append('| %s | %s | %s | %s |' % (ts(a), who, text.replace('|', '/'), tag.replace('|', '/')))
    srt += [str(i), '%s --> %s' % (ts(a, True), ts(z, True)), text, '']
open(os.path.join(OUT, 'transcript.md'), 'w', encoding='utf-8', newline='\n').write('\n'.join(md) + '\n')
open(os.path.join(OUT, 'exam-to-mastery.srt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(srt))
print(len(lines), 'lines;', ts(B.END))
