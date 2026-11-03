# The shots new in film v11 (3 Nov 2026, the 13-judge panel round 4: more of this week's work on screen, in motion, four
# of Meta's models seen, the teacher's control, the real student's result stated against its baseline). Each draws only
# from a live result or a committed screen: nothing is mocked up.
#   title    the name, and the four Meta models that do the work
#   marks    Daniel's photographed page; Muse Spark's mark on each question lands where Muse Spark found the question
#   voice    Lo asks first (phone); the spoken answer plays, Muse Voice Transcribe's text appears; the desk after
#   wonder   Muse Wonder's two plays of the Q24 level, check by check, from the level's own self-check
#   image    Daniel's answer, then Muse Image's drawn corrected step wiping in
#   teacher  the desk: the confident marks accepted, the paper's Mastery Plan
#   lasting  the re-check days later (phone) and "Turned around" (desk), on another sample learner
import json, os, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

F7 = r'C:\lw-witness-scratch\film7'
SCREENS = r'C:\lw-witness\evidence\screens'
MARKS = json.load(open(r'C:\lw-witness-scratch\film5\test\lmark_film11.json', encoding='utf-8'))['sitting_reply']['result']['questions']
LEVEL24 = next(q for q in json.load(open(r'C:\lw-witness\evidence\unseen-physics\levels-q23-q24-with-self-check.json', encoding='utf-8'))['result']['questions'] if q['n'] == 24)['mastery']
HELD = next(r for r in json.load(open('C:/lw-witness/harness/selfcheck/results/selfcheck-3-runs.json', encoding='utf-8'))['results'] if r['id'] == 'base-false-claim' and r['run'] == 1)['verdict']
TRANSCRIPT = json.load(open(r'C:\lw-witness\harness\probes\results-31oct\transcript-31oct.json', encoding='utf-8'))['transcript']
LEO_WAV = r'C:\lw-witness-scratch\probe31\leo-answer.wav'


def wav_mono(path, sr):
    w = wave.open(path); n = w.getnframes(); ch = w.getnchannels(); r = w.getframerate()
    x = np.frombuffer(w.readframes(n), '<i2').astype(np.float32) / 32768
    if ch > 1: x = x.reshape(-1, ch).mean(1)
    if r != sr: x = np.interp(np.arange(0, len(x), r / sr), np.arange(len(x)), x).astype(np.float32)
    f = int(0.03 * sr); x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    return x * (0.7 / (np.abs(x).max() or 1))


# where each question's answer line ends on Daniel's photographed paper, as the marks shot shows it (screen pixels)
ANSWER_AT = {n: (905, y) for n, y in zip(range(1, 16), (380, 420, 455, 490, 530, 586, 648, 688, 722, 762, 798, 845, 889, 930, 980))}
ANSWER_AT.update({n: (1548, y) for n, y in zip(range(16, 31), (235, 268, 304, 357, 392, 452, 489, 551, 762, 836, 876, 912, 948, 987, 1022))})


def tick(d, x, y, ok, col, r=15):
    if ok: d.line([(x - r, y), (x - r * 0.3, y + r * 0.8), (x + r * 1.1, y - r)], fill=col, width=7)
    else: d.line([(x - r, y - r), (x + r, y + r)], fill=col, width=7); d.line([(x - r, y + r), (x + r, y - r)], fill=col, width=7)


# the film's own palette for cards (owner, 3 Nov: the cards clashed with the film): glass on the gradient, a soft border,
# muted accents
CORAL, MINT, GOLD, SOFT = (240, 138, 126), (118, 214, 170), (242, 193, 78), (226, 232, 242)


def glass_card(base, box, accent=None, a=1.0, r=26):
    """A frosted card: white at a low alpha over the film's gradient, a hairline border, an accent line on the left."""
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, r, fill=(255, 255, 255, int(20 * a)), outline=(255, 255, 255, int(56 * a)), width=2)
    if accent:
        x0, y0, x1, y1 = box
        d.rounded_rectangle((x0 + 14, y0 + 22, x0 + 20, y1 - 22), 3, fill=accent + (int(230 * a),))
    base.alpha_composite(layer)


def install(g):
    """Called from build11 with its globals: E, K, C, load, fade_in, framed, push, put_phone, P, A."""
    E, K, C, load, fade_in, framed, push = g['E'], g['K'], g['C'], g['load'], g['fade_in'], g['framed'], g['push']
    cache = {}

    def text_c(d, y, s, f, fill):
        d.text(((K.W - d.textlength(s, font=f)) / 2, y), s, font=f, fill=fill)

    def title_shot(base, b, lt):
        d = ImageDraw.Draw(base); a = E.ease(lt / 0.5)
        text_c(d, 300, 'From Exam to Mastery', K.font(K.F_BLACK, 110), (255, 255, 255, int(255 * a)))
        text_c(d, 450, 'inside LoWisa  ·  built this week  ·  powered by Meta’s models', K.font(K.F_SEMI, 38), (159, 179, 200, int(255 * a)))
        models = ['Muse Spark', 'Muse Wonder', 'Muse Voice Transcribe', 'Muse Image']
        f = K.font(K.F_BLACK, 34); ws = [d.textlength(m, font=f) + 60 for m in models]; x = (K.W - sum(ws) - 30 * 3) / 2
        for i, (m, w) in enumerate(zip(models, ws)):
            t0 = 1.0 + i * 0.45
            if lt < t0: continue
            k = E.ease((lt - t0) / 0.4); y = 610 + (1 - k) * 30
            d.rounded_rectangle((x, y, x + w, y + 70), 35, fill=(45, 125, 255, int(235 * k)))
            d.text((x + 30, y + 14), m, font=f, fill=(255, 255, 255, int(255 * k))); x += w + 30

    def marks_shot(base, b, lt):
        if 'paper' not in cache:
            im = load(os.path.join(r'C:\lw-witness-scratch\film5\out', 'paper_blank_fixed.jpg'))
            s = min(1640 / im.width, 900 / im.height)
            cache['paper'] = (im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS).convert('RGBA'), s, im.size)
        paper, s, (W0, H0) = cache['paper']; v = paper.copy(); dd = ImageDraw.Draw(v)
        order = sorted(MARKS, key=lambda q: q['n'])
        win, pad = E.shadowed(v, radius=10)
        base.alpha_composite(win, ((K.W - win.width) // 2, 140))
        span = max(1.0, b['dur'] - 2.6); shown = 0; dd = ImageDraw.Draw(base)
        for i, q in enumerate(order):
            t0 = 0.6 + span * i / len(order)
            if lt < t0: continue
            shown += 1; k = E.ease((lt - t0) / 0.25)
            # the end of the question's answer line, read off this photo as the film shows it (Muse Spark's own boxes
            # are rough across the page: harness/bench/results/line_placement.json)
            x, y = ANSWER_AT[q['n']]
            ok = q['result'] == 'mastered'; col = (40, 170, 90, int(255 * k)) if ok else (226, 60, 70, int(255 * k))
            tick(dd, x, y, ok, col)
        d = ImageDraw.Draw(base); f = K.font(K.F_BLACK, 44)
        right = sum(1 for q in order[:shown] if q['result'] == 'mastered')
        s1 = 'Marked %d of 30' % shown if shown < len(order) else '%d of 30 right  ·  %d into his Mastery Plan' % (right, len(order) - right)
        d.text((40, 96), s1, font=f, fill=K.YELLOW)

    def voice_shot(base, b, lt):
        if 'ph' not in cache:
            ph, _, _ = E.phone_frame(load(os.path.join(SCREENS, 'phone-lo-asks-first.png')), 860); cache['ph'] = ph
            # the payoff (round-7 panel): the desk once his spoken answer is in, the idea named and his own words ringed
            after = load(os.path.join(SCREENS, 'desk-fingerprint-c-after-lo-asked.png')).crop((834, 372, 1862, 700))
            sc = 1180 / after.width
            after = after.resize((1180, int(after.height * sc)), Image.LANCZOS).convert('RGBA'); da = ImageDraw.Draw(after)
            for bx in [(853, 402, 1714, 434), (840, 666, 1420, 698)]:
                da.rounded_rectangle(((bx[0] - 834) * sc - 6, (bx[1] - 372) * sc - 6, (bx[2] - 834) * sc + 6, (bx[3] - 372) * sc + 6), 10, outline=GOLD, width=5)
            cache['after'] = E.shadowed(after, radius=14)
            w = wave.open(LEO_WAV); x = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(np.float32)
            if w.getnchannels() > 1: x = x.reshape(-1, w.getnchannels()).mean(1)
            bins = np.array_split(np.abs(x), 120); cache['env'] = np.array([c.max() for c in bins]) / (np.abs(x).max() or 1)
            cache['wav_s'] = w.getnframes() / w.getframerate()
        base.alpha_composite(cache['ph'], (110, 110))
        d = ImageDraw.Draw(base)
        w0 = b.get('w0', 0.0); ws = cache['wav_s']; k = min(1.0, max(0.0, (lt - w0) / ws))
        X0, Y0 = 640, 210
        d.text((X0, 130), 'HIS SPOKEN ANSWER', font=K.font(K.F_BLACK, 30), fill=K.YELLOW)
        env = cache['env']
        for i, e in enumerate(env):
            h = 6 + 70 * e; x = X0 + i * 9; on = i / len(env) <= k
            d.rounded_rectangle((x, Y0 + 50 - h / 2, x + 5, Y0 + 50 + h / 2), 2, fill=(126, 240, 222) if on else (60, 80, 100))
        words = TRANSCRIPT.split(); n = int(len(words) * min(1.0, max(0.0, (lt - w0 - 0.4) / ws)))
        if n:
            f = K.font(K.F_BOLD, 44); line, y = '', Y0 + 140
            for wd in words[:n]:
                if d.textlength(line + ' ' + wd, font=f) > 1150: d.text((X0, y), line.strip(), font=f, fill='white'); y += 60; line = ''
                line += ' ' + wd
            d.text((X0, y), '“' + line.strip() if y == Y0 + 140 and not line.startswith('“') else line.strip(), font=f, fill='white')
        if lt > w0 + ws + 0.2:
            (win, pad), a = cache['after'], E.ease((lt - w0 - ws - 0.2) / 0.5)
            d.text((X0, 520), 'HIS OWN ANSWER SETTLES IT: THE IDEA IS NAMED FROM HIS WORDS', font=K.font(K.F_BLACK, 30), fill=GOLD + (int(255 * a),))
            base.alpha_composite(fade_in(win, a), (X0 - pad, 570 - pad + int((1 - a) * 30)))

    def wonder_shot(base, b, lt):
        d = ImageDraw.Draw(base); plays = LEVEL24['check']['plays']
        lanes = [('PLAYS AS DANIEL · still sure heavy things sink', plays['holds'], CORAL),
                 ('PLAYS AS A STUDENT WHO HAS IT RIGHT', plays['knows'], MINT)]
        d.text((110, 120), 'Muse Wonder plays his level before he sees it: “Ships, Nails and Upthrust”', font=K.font(K.F_BLACK, 40), fill='white')
        steps = len(lanes[0][1]); span = max(1.0, (b['dur'] - 3.0) / steps)
        for li, (head, rows, col) in enumerate(lanes):
            x0 = 110 + li * 870; d.text((x0, 210), head, font=K.font(K.F_BLACK, 28), fill=col)
            for ri, r in enumerate(rows):
                t0 = 0.6 + ri * span + li * 0.35
                if lt < t0: continue
                a = E.ease((lt - t0) / 0.4); y = 270 + ri * 210
                glass_card(base, (x0, y, x0 + 820, y + 185), col, a); d = ImageDraw.Draw(base)
                d.text((x0 + 40, y + 16), 'Lesson %d · %s' % (r['lesson'], r['check']), font=K.font(K.F_BLACK, 28), fill=(242, 193, 78, int(255 * a)))
                fl = K.font(K.F_SEMI, 28)
                for i, ln in enumerate(K.wrap(d, '“' + r['answered'] + '”', fl, 700)[:3]):
                    d.text((x0 + 40, y + 62 + 36 * i), ln, font=fl, fill=SOFT + (int(255 * a),))
                tick(d, x0 + 784, y + 40, r['right'], col + (int(255 * a),))
        if lt > b['dur'] - 2.4:
            a = E.ease((lt - b['dur'] + 2.4) / 0.4)
            text_c(d, 900, 'It catches his idea at every check, and finds no false claim: the level may start.', K.font(K.F_BLACK, 40), GOLD + (int(255 * a),))

    def image_shot(base, b, lt):
        if 'ans' not in cache:
            p = load(os.path.join(r'C:\lw-witness-scratch\film5\out', 'paper_blank_fixed.jpg')).crop((790, 560, 1491, 760))
            p = p.resize((780, int(780 * p.height / p.width)), Image.LANCZOS).convert('RGBA'); cache['ans'] = E.shadowed(p, radius=10)
            dr = Image.open(os.path.join(F7, 'drawn-q24.webp')).convert('RGB').crop((0, 380, 1600, 1220))
            dr = dr.resize((900, int(900 * dr.height / dr.width)), Image.LANCZOS).convert('RGBA'); cache['dr'] = dr
        d = ImageDraw.Draw(base); f = K.font(K.F_BLACK, 30)
        (win, pad) = cache['ans']; base.alpha_composite(win, (90 - pad, 330 - pad))
        d.text((90, 270), 'HIS ANSWER, ON HIS EXAM', font=f, fill=(255, 140, 120))
        d.text((960, 230), 'DRAWN BY MUSE IMAGE, FOR HIM', font=f, fill=(126, 200, 255))
        dr = cache['dr']; k = E.ease(max(0.0, lt - 0.6) / 2.2); h = max(1, int(dr.height * k))
        part = dr.crop((0, 0, dr.width, h)); win2, pad2 = E.shadowed(part, radius=12)
        base.alpha_composite(win2, (960 - pad2, 290 - pad2))

    def teacher_shot(base, b, lt):
        if 'desk' not in cache:
            fr = load(os.path.join(r'C:\lw-witness-scratch\film5', 'dA.png')).copy()
            for box in [(140, 170, 290, 212), (232, 244, 380, 288)]:
                fr.paste(fr.crop(box).filter(ImageFilter.GaussianBlur(10)), box[:2])
            cache['desk'] = fr
        fr = cache['desk']
        v, x0, y0 = push(fr, (0, 440, 1920, 1128), lt)
        bw, bh = 1700, 880; s2 = min(bw / v.width, bh / v.height)
        view = v.resize((int(v.width * s2), int(v.height * s2)), Image.LANCZOS).convert('RGBA'); dd = ImageDraw.Draw(view)
        for (mx0, my0, mx1, my1), t0 in [((1722, 930, 1852, 972), 1.8), ((30, 455, 550, 552), b['dur'] * 0.55)]:
            if lt > t0:
                a = int(255 * E.ease((lt - t0) / 0.5))
                dd.rounded_rectangle(((mx0 - x0) * s2 - 8, (my0 - y0) * s2 - 8, (mx1 - x0) * s2 + 8, (my1 - y0) * s2 + 8), 14, outline=(242, 193, 78, a), width=6)
        win, pad = E.shadowed(view, radius=20)
        base.alpha_composite(win, ((K.W - win.width) // 2, (K.H - win.height) // 2 + 30))

    def lasting_shot(base, b, lt):
        if 'rc' not in cache:
            ph, _, _ = E.phone_frame(load(os.path.join(SCREENS, 'phone-recheck-right.png')), 860); cache['rc'] = ph
            dk = load(os.path.join(SCREENS, 'desk-turned-around.png')).crop((820, 470, 1900, 1020))
            dk = dk.resize((1060, int(1060 * dk.height / dk.width)), Image.LANCZOS).convert('RGBA'); cache['dk'] = E.shadowed(dk, radius=14)
        base.alpha_composite(cache['rc'], (110, 110))
        d = ImageDraw.Draw(base)
        d.text((720, 160), 'DAYS LATER: A FRESH QUESTION, SAME IDEA', font=K.font(K.F_BLACK, 30), fill=K.YELLOW)
        if lt > 2.0:
            (win, pad), a = cache['dk'], E.ease((lt - 2.0) / 0.5)
            d.text((720, 260), 'THEN THE TEACHER: TURNED AROUND', font=K.font(K.F_BLACK, 30), fill=(242, 193, 78, int(255 * a)))
            base.alpha_composite(fade_in(win, a), (720 - pad, 320 - pad))

    RH = r'C:\lw-witness\evidence\real-handwriting'

    def real_shot(base, b, lt):
        if 'sheets' not in cache:
            sh = {}
            for nm in ('sheets/maths-teacher-marked.jpg', 'sent/maths-sheet-ink-removed.jpg'):
                im = load(os.path.join(RH, nm)); sh[nm] = E.shadowed(im.resize((int(640 * im.width / im.height), 640), Image.LANCZOS).convert('RGBA'), radius=12)
            cache['sheets'] = sh
            sent = load(os.path.join(RH, 'sent/maths-sheet-ink-removed.jpg'))
            rows = {}
            for n, box in ((11, (232, 1028, 500, 1108)), (24, (500, 862, 762, 946))):
                r = sent.crop(box); r = r.resize((int(r.width * 2.2), int(r.height * 2.2)), Image.LANCZOS).convert('RGBA')
                rows[n] = E.shadowed(r, radius=10)
            cache['rows'] = rows
        d = ImageDraw.Draw(base); f = K.font(K.F_BOLD, 34); Z = 5.2
        out = 1 - E.ease((lt - Z) / 0.3) if lt > Z else 1.0
        for i, (nm, lab, t0) in enumerate([('sheets/maths-teacher-marked.jpg', 'Marked by his teacher', 0.0), ('sent/maths-sheet-ink-removed.jpg', 'Sent to Muse Spark, red ink removed', 1.2)]):
            if lt < t0 or out <= 0: continue
            (win, pad), k = cache['sheets'][nm], E.ease((lt - t0) / 0.5) * out
            x = 330 + i * 720; y = int(150 + (1 - k) * 30)
            base.alpha_composite(fade_in(win, k), (x - pad, y - pad))
            if lt < Z: d.text((x + (win.width - 2 * pad - d.textlength(lab, font=f)) / 2, y + 650), lab, font=f, fill=(175, 194, 214, int(255 * k)))
        if lt > Z:
            # in every run on both tags: question 11 caught, question 24 marked right where his teacher marked it wrong
            for i, (n, col, head, lines) in enumerate([
                    (11, MINT, 'QUESTION 11 · CAUGHT', ['His teacher: wrong.  Muse Spark: not yet.', 'The page shows “A” but not how he got it,', 'so no idea is named: Lo asks first.']),
                    (24, CORAL, 'QUESTION 24 · AN HONEST MISS', ['His teacher: wrong.  Muse Spark: right.', 'One of the 3 or 4 of his teacher’s 10', 'it did not catch, in every run.'])]):
                t0 = Z + 0.3 + i * 1.4
                if lt < t0: continue
                a = E.ease((lt - t0) / 0.5); x0 = 110 + i * 870
                glass_card(base, (x0, 150, x0 + 830, 780), col, a); d = ImageDraw.Draw(base)
                d.text((x0 + 44, 180), head, font=K.font(K.F_BLACK, 30), fill=col + (int(255 * a),))
                win, pad = cache['rows'][n]; base.alpha_composite(fade_in(win, a), (x0 + (830 - win.width) // 2, 250 - pad))
                fl = K.font(K.F_SEMI, 34)
                for j, ln in enumerate(lines):
                    d.text((x0 + 44, 520 + 52 * j), ln, font=fl, fill=SOFT + (int(255 * a),))
        if lt > 3.2:
            k = E.ease((lt - 3.2) / 0.5); f2 = K.font(K.F_BLACK, 38)
            s1 = '6 or 7 of his teacher’s 10 wrong answers caught in every run  ·  no wrong idea named'
            d.text(((K.W - d.textlength(s1, font=f2)) / 2, 860), s1, font=f2, fill=(242, 193, 78, int(255 * k)))

    def held_shot(base, b, lt):
        r = HELD
        d = ImageDraw.Draw(base)
        d.text((110, 130), 'Muse Wonder checks every claim the level makes', font=K.font(K.F_BLACK, 44), fill='white')
        a = E.ease(lt / 0.4)
        glass_card(base, (110, 220, 1810, 560), CORAL, a); d = ImageDraw.Draw(base)
        d.text((150, 245), 'FALSE CLAIM FOUND IN LESSON %d' % r['problems'][0]['lesson'], font=K.font(K.F_BLACK, 30), fill=CORAL + (int(255 * a),))
        fl = K.font(K.F_SEMI, 34)
        for i, ln in enumerate(K.wrap(d, r['false_claims'][0], fl, 1620)[:4]):
            d.text((150, 300 + 48 * i), ln, font=fl, fill=SOFT + (int(255 * a),))
        if lt > 1.6:
            k = E.ease((lt - 1.6) / 0.4)
            glass_card(base, (110, 600, 1810, 860), GOLD, k); d = ImageDraw.Draw(base)
            d.text((150, 625), 'THE LEVEL IS HELD, AND REWRITTEN WITH THIS FIX', font=K.font(K.F_BLACK, 30), fill=GOLD + (int(255 * k),))
            for i, ln in enumerate(K.wrap(d, r['problems'][0]['fix'], fl, 1620)[:3]):
                d.text((150, 680 + 48 * i), ln, font=fl, fill=SOFT + (int(255 * k),))
        if lt > 2.6:
            k = E.ease((lt - 2.6) / 0.4)
            text_c(d, 890, 'Planted faults held: 30 of 30  ·  false claims found: 9 of 9  (harness/selfcheck)', K.font(K.F_BOLD, 34), (159, 179, 200, int(255 * k)))

    return {'title': title_shot, 'marks': marks_shot, 'voice': voice_shot, 'wonder': wonder_shot, 'image': image_shot,
            'teacher': teacher_shot, 'lasting': lasting_shot, 'held': held_shot, 'real': real_shot}


def end_card(K, C, E, lt):
    """The name; Meta's six models, each checked by another and by code; the replay command; the dates."""
    im = C.lines_card(['From Exam to Mastery'], sub='inside LoWisa  ·  powered by Meta’s models', size=104, top=200).copy()
    d = ImageDraw.Draw(im)
    models = ['Muse Spark', 'Muse Wonder', 'Muse Voice Transcribe', 'Muse Image', 'SAM 3.1', 'Muse Spark Open']
    f = K.font(K.F_BLACK, 28); ws = [d.textlength(m, font=f) + 48 for m in models]; x = (K.W - sum(ws) - 20 * 5) / 2
    for i, (m, w) in enumerate(zip(models, ws)):
        t0 = 0.4 + i * 0.25
        if lt < t0: continue
        k = E.ease((lt - t0) / 0.4); y = 470 + (1 - k) * 20; op = m == 'Muse Spark Open'
        d.rounded_rectangle((x, y, x + w, y + 58), 29, fill=(MINT if op else (45, 125, 255)) + (int(235 * k),))
        d.text((x + 24, y + 12), m, font=f, fill=((10, 30, 24) if op else (255, 255, 255)) + (int(255 * k),)); x += w + 20
    if lt > 2.0:
        k = E.ease((lt - 2.0) / 0.5); f2 = K.font(K.F_SEMI, 30)
        s = 'each one checked by another, and by code  ·  Muse Spark Open: the same marking on open weights'
        d.text(((K.W - d.textlength(s, font=f2)) / 2, 556), s, font=f2, fill=(159, 179, 200, int(255 * k)))
    if lt > 2.6:
        k = E.ease((lt - 2.6) / 0.5)
        glass_card(im, (460, 640, 1460, 740), GOLD, k); d = ImageDraw.Draw(im)
        d.text((540, 668), 'node demo/desk-server.js --replay', font=K.font(K.F_BOLD, 34), fill=(255, 255, 255, int(255 * k)))
        f5 = K.font(K.F_SEMI, 24); s = 'no account, no key'
        d.text((1430 - d.textlength(s, font=f5), 678), s, font=f5, fill=GOLD + (int(255 * k),))
    f4 = K.font(K.F_SEMI, 30)
    for i, s in enumerate(['Built 26 Oct – 4 Nov for the Meta Global AI Developer Hackathon', 'Daniel is a sample student; his paper was made for the demo  ·  lowisa.dev']):
        d.text(((K.W - d.textlength(s, font=f4)) / 2, 820 + 50 * i), s, font=f4, fill='#8EA3BA')
    return im
