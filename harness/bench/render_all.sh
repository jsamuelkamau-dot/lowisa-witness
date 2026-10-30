#!/bin/sh
# Renders every benchmark case (cases/cases.json) as a desk video: bench_page.py writes each paper as an animated page
# (the pen writing it, line by line, in a handwriting font), Electron records it frame by frame (render.cjs), ffmpeg
# makes the clip, and two clips get a messy copy (dark, grainy, 480p, 5 fps).
#   OUT=/tmp/bench ELECTRON=electron FFMPEG=ffmpeg sh harness/bench/render_all.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$here/clips}"; ELECTRON="${ELECTRON:-electron}"; FFMPEG="${FFMPEG:-ffmpeg}"
mkdir -p "$OUT"
for spec in "$here"/cases/*_spec.json; do
  id=$(basename "$spec" _spec.json)
  [ -f "$OUT/$id.html" ] || python3 "$here/bench_page.py" "$spec" "$OUT/$id.html"
done
for c in $(python3 -c "import json,sys;print(' '.join(c['id']+':'+str(c['secs']) for c in json.load(open(sys.argv[1],encoding='utf-8'))))" "$here/cases/cases.json"); do
  id=${c%%:*}; secs=${c##*:}
  [ -f "$OUT/$id.mp4" ] && continue
  rm -rf "$OUT/fr_$id"
  "$ELECTRON" "$here/render.cjs" "$OUT/$id.html" "$OUT/fr_$id" "$secs" 10 720 1280
  "$FFMPEG" -hide_banner -loglevel error -y -framerate 10 -i "$OUT/fr_$id/%05d.png" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/$id.mp4"
done
for id in maths_cancel_en fr_maths; do
  "$FFMPEG" -hide_banner -loglevel error -y -i "$OUT/$id.mp4" -vf "fps=5,scale=480:-2,eq=brightness=-0.22:contrast=0.7:saturation=0.5,noise=alls=22:allf=t" \
    -c:v libx264 -b:v 300k -pix_fmt yuv420p "$OUT/${id}_messy.mp4"
done
cp "$here/cases/cases.json" "$OUT/cases.json"
echo "clips in $OUT; then: MODEL_API_KEY=... escript harness/bench/bench.escript $OUT/cases.json"
