#!/usr/bin/env python3
"""The Meta models the film does not show, each in one picture made only from committed files (nothing new is called).

    python3 evidence/models/make.py

muse-image.png       the student's own step (from the sample paper) beside the corrected step Muse Image drew for it
voice-transcribe.png Lo asks first on the phone; the spoken answer as Muse Voice Transcribe wrote it; the desk before
                     and after, where the idea is named only once the answer shows it
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
W, BG, INK, SUB, ACC = 2000, (14, 22, 36), (240, 244, 250), (150, 168, 190), (120, 200, 255)


def font(size, bold=False):
    for f in (('arialbd.ttf' if bold else 'arial.ttf'), ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf')):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def fit(im, w, h):
    im = im.convert('RGB')
    r = min(w / im.width, h / im.height)
    return im.resize((int(im.width * r), int(im.height * r)), Image.LANCZOS)


def card(title, sub, h):
    im = Image.new('RGB', (W, h), BG)
    d = ImageDraw.Draw(im)
    d.text((60, 40), title, font=font(54, True), fill=INK)
    d.text((60, 112), sub, font=font(30), fill=SUB)
    return im, d


def label(d, xy, text, colour=ACC):
    d.text(xy, text, font=font(30, True), fill=colour)


def muse_image():
    rec = json.load(open(os.path.join(ROOT, 'harness/probes/results-03nov/redraw-03nov.json'), encoding='utf-8'))
    a = next(x for x in rec['muse_image'] if x['learner'] == 'a')
    im, d = card('Muse Image draws the corrected step',
                 f'Sample paper, learner A (section 6). Muse Spark writes the lines; Muse Image draws them, the changed line '
                 f'marked. ${a["cost_usd"]:.3f}, 3 Nov.', 1240)
    mine = fit(Image.open(os.path.join(ROOT, 'evidence/misconceptions/learner-a-cancellation-q4.jpg')), 900, 420)
    drawn = fit(Image.open(os.path.join(ROOT, 'harness/probes/results-03nov/drawn-learner-a.webp')), 900, 900)
    label(d, (60, 190), 'HIS STEP, AS WRITTEN', (255, 140, 120))
    im.paste(mine, (60, 240))
    label(d, (1040, 190), 'DRAWN BY MUSE IMAGE')
    im.paste(drawn, (1040, 240))
    d.text((60, 700), 'The lines Muse Image was given:', font=font(30, True), fill=INK)
    for i, ln in enumerate(a['lines']):
        d.text((60, 750 + 52 * i), ('-> ' if i + 1 == a['changed'] else '   ') + ln, font=font(30), fill=ACC if i + 1 == a['changed'] else SUB)
    d.text((60, 1180), 'Source: harness/probes/results-03nov/ (redraw-03nov.json, drawn-learner-a.webp); code: witness/src/witness_draw.erl',
           font=font(24), fill=SUB)
    im.save(os.path.join(HERE, 'muse-image.png'), optimize=True)


def voice():
    t = json.load(open(os.path.join(ROOT, 'harness/probes/results-31oct/transcript-31oct.json'), encoding='utf-8'))
    im, d = card('Lo asks first; Muse Voice Transcribe writes the answer down',
                 f'Sample learner C (section 6). {t["audio_seconds"]} s spoken (a synthetic voice, Amazon Polly), '
                 f'transcribed for ${t["cost_usd"]:.4f}, 31 Oct.', 1260)
    ask = fit(Image.open(os.path.join(ROOT, 'evidence/screens/phone-lo-asks-first.png')), 420, 930)
    label(d, (60, 190), '1  LO ASKS, NOTHING NAMED')
    im.paste(ask, (60, 240))
    label(d, (540, 190), '2  HIS SPOKEN ANSWER, AS WRITTEN DOWN')
    y = 250
    words, line = t['transcript'].split(), ''
    for w in words:
        if d.textlength(line + ' ' + w, font=font(40)) > 1380:
            d.text((540, y), line.strip(), font=font(40), fill=INK); y += 56; line = ''
        line += ' ' + w
    d.text((540, y), line.strip(), font=font(40), fill=INK)
    before = fit(Image.open(os.path.join(ROOT, 'evidence/screens/desk-fingerprint-c.png')), 690, 410)
    after = fit(Image.open(os.path.join(ROOT, 'evidence/screens/desk-fingerprint-c-after-lo-asked.png')), 690, 410)
    label(d, (540, 520), '3  THE DESK BEFORE')
    im.paste(before, (540, 570))
    label(d, (1270, 520), '... AND AFTER HIS ANSWER')
    im.paste(after, (1270, 570))
    d.text((540, 1010), 'The idea is named only once his own answer shows it, and not the one the model had guessed (section 6).',
           font=font(28), fill=SUB)
    d.text((60, 1200), 'Source: harness/probes/results-31oct/transcript-31oct.json; evidence/screens/; code: witness_meta:transcribe/2',
           font=font(24), fill=SUB)
    im.save(os.path.join(HERE, 'voice-transcribe.png'), optimize=True)


if __name__ == '__main__':
    muse_image()
    voice()
    print('ok')
