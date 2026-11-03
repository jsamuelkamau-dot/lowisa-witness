"""murf11.py [keys] -- the film's narration in Murf's Joshua (en-UK-joshua, Falcon 2.1, owner's choice 3 Nov), one mp3 per
line of script11.json into vo_joshua11/. The key is read from MURF_API_KEY and never printed. The final cut is MURF_VOICE=en-US-gordon."""
import json, os, sys, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
VOICE = os.environ.get('MURF_VOICE', 'en-UK-joshua')
OUT = os.path.join(HERE, 'vo_' + VOICE.split('-')[-1] + '11'); os.makedirs(OUT, exist_ok=True)
want = sys.argv[1].split(',') if len(sys.argv) > 1 else None
KEY = os.environ['MURF_API_KEY']  # read, never printed
for k, cap, spoken in json.load(open(os.path.join(HERE, 'script11.json'), encoding='utf-8')):
    if want and k not in want: continue
    text = (spoken or cap).replace('LoWisa', 'Lo-Weesa')
    body = json.dumps({'voiceId': VOICE, 'text': text, 'model': 'falcon-2.1', 'format': 'MP3', 'sampleRate': 44100}).encode()
    req = urllib.request.Request('https://api.murf.ai/v1/speech/stream', body, {'api-key': KEY, 'Content-Type': 'application/json'})
    data = urllib.request.urlopen(req, timeout=120).read()
    open(os.path.join(OUT, k + '.mp3'), 'wb').write(data); print(VOICE, k, len(data), flush=True)
