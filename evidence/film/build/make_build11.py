s = open('C:/lw-witness-scratch/film6/edit/build10.py', encoding='utf-8').read()


def rep(a, b, c=1):
    global s
    assert s.count(a) == c, (s.count(a), a[:60])
    s = s.replace(a, b)


rep("F6 = os.path.join(HERE, '..')", "F6 = 'C:/lw-witness-scratch/film6'")
rep("VO_DIR = os.path.join(F6, 'vo_' + VOICE + '10')", "F7 = r'C:\\lw-witness-scratch\\film7'\nVO_DIR = os.path.join(F7, 'vo_' + VOICE + '11')")
rep("OUT = os.path.join(HERE, 'exam-to-mastery-v10-%s%s.mp4' % (VOICE, '-preview' if PREVIEW else ''))",
    "OUT = os.path.join(F7, 'exam-to-mastery-v11-%s%s.mp4' % (VOICE, '-preview' if PREVIEW else ''))")
rep("MIX = os.path.join(HERE, 'mix10-%s.wav' % VOICE)", "MIX = os.path.join(F7, 'mix11-%s.wav' % VOICE)")
rep("SCRIPT = {k: cap for k, cap, _ in json.load(open(os.path.join(F6, 'script10.json'), encoding='utf-8'))}",
    "SCRIPT = {k: cap for k, cap, _ in json.load(open(os.path.join(F7, 'script11.json'), encoding='utf-8'))}")

a = s.index("EDIT = [")
z = s.index("]\n\n\ndef end_card():") + 2
EDIT = open('C:/lw-witness-scratch/film7/edit11.py.txt', encoding='utf-8').read()
s = s[:a] + EDIT + s[z:]

rep("BLANK, MARKED = 'paper_blank_fixed.jpg', 'marked_hand_fixed.png'",
    "BLANK, MARKED = 'paper_blank_fixed.jpg', r'C:\\lw-witness-scratch\\film7\\marked_no_total.png'  # v11: the prop's red total (8/30) taken off; Muse Spark's 6/30 is the mark")
rep("import cards as K, cards2 as C, engine as E, audio as A",
    "import cards as K, cards2 as C, engine as E, audio as A\nsys.path.insert(0, r'C:\\lw-witness-scratch\\film7')\nimport shots11 as S11")
rep("""    else:
        speech = vo + lo + (0.3 if vo and lo else 0) + lead""", """    elif b.get('wav'):
        wl = len(S11.wav_mono(b['wav'], A.SR)) / A.SR
        b = {**b, 'w0': 0.08 + vo + 0.3, 'wlen': wl}
        speech = vo + 0.3 + wl + b.get('after', 2.0)
    else:
        speech = vo + lo + (0.3 if vo and lo else 0) + lead""")
rep("""    if b.get('lo'):
        a = lo_audio(*b['lo'][:2]); s = int(l0 * A.SR)""", """    if b.get('wav'):
        a = S11.wav_mono(b['wav'], A.SR); s = int((b['t0'] + b['w0']) * A.SR); lo_tr[s:s + len(a)] += a[:max(0, n - s)]
        d0, d1 = max(0, s - int(0.3 * A.SR)), min(n, s + len(a) + int(0.3 * A.SR)); duck[d0:d1] = 0.2
    if b.get('lo'):
        a = lo_audio(*b['lo'][:2]); s = int(l0 * A.SR)""")
rep("""        s1 = '105 of 109 answers agree with his teacher  ·  7 of his 10 wrong answers caught'""",
    """        s1 = '6 or 7 of his teacher’s 10 wrong answers caught in every run  ·  no wrong idea named'""")
rep("""         'trio': trio_shot, 'both': both_shot, 'think': think_shot, 'clip': clip_shot, 'intro': intro_shot, 'real': real_shot}""",
    """         'trio': trio_shot, 'both': both_shot, 'think': think_shot, 'clip': clip_shot, 'intro': intro_shot, 'real': real_shot}
SHOTS.update(S11.install(globals()))""")
rep("""def dstill_shot(base, b, lt):
    v, x0, y0 = push(load(P(b['png'])), b.get('crop'), lt)""", """def dstill_shot(base, b, lt):
    v, x0, y0 = push(load(b['png'] if os.path.isabs(b['png']) else P(b['png'])), b.get('crop'), lt)""")
rep("""    for i, s in enumerate(['Built 26 Oct – 4 Nov for the Meta Global AI Developer Hackathon', 'LoWisa on Google Play, the App Store and the desktop  ·  lowisa.dev']):""",
    """    for i, s in enumerate(['Built 26 Oct – 4 Nov for the Meta Global AI Developer Hackathon', 'Daniel is a sample student; his paper was made for the demo  ·  lowisa.dev']):""")
rep("""def paper_shot(base, b, lt):
    im = load(os.path.join(PAPERS, b['img']))""", """def paper_shot(base, b, lt):
    im = load(b['img'] if os.path.isabs(b['img']) else os.path.join(PAPERS, b['img']))""")
rep("k = E.ease((lt - 3.2) / 0.5); f2 = K.font(K.F_BLACK, 46)", "k = E.ease((lt - 3.2) / 0.5); f2 = K.font(K.F_BLACK, 38)")
rep("""    for x0, col, kick, quote, foot in [
            (140, K.RED, 'BEFORE · ON HIS EXAM',""", """    for x0, col, kick, quote, foot in [
            (140, S11.CORAL, 'BEFORE · ON HIS EXAM',""")
rep("""            (1000, K.GREEN, 'AFTER · WITH LO',""", """            (1000, S11.MINT, 'AFTER · WITH LO',""")
rep("""        d.rounded_rectangle((x0, 220, x0 + 780, 860), 36, fill=(16, 26, 42, 255), outline=col, width=5)
        d.text((x0 + 50, 270), kick, font=fk, fill=col)""", """        # v11e (owner: cards in the film's own colours): a glass card on the gradient, the accent on its edge
        S11.glass_card(im, (x0, 220, x0 + 780, 860), col, 1.0, r=36); d = ImageDraw.Draw(im)
        d.text((x0 + 50, 270), kick, font=fk, fill=col)""")
# round-7 panel (4 Nov): the first look's scene panel holds its first drawn frame instead of a blank white panel
rep("""    z = _vid[key + (('z2',) if late else ('z',))].at(lt * sp).convert('RGBA')""",
    """    z = _vid[key + (('z2',) if late else ('z',))].at(max(lt * sp, b.get('zoom_hold', b['a']) - b['a'])).convert('RGBA')""")
open('C:/lw-witness-scratch/film7/build11.py', 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
