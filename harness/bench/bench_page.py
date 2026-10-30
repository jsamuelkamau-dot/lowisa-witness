# bench_page.py <spec.json> [out.html]: a self-contained page that animates a student writing a paper (synthetic, not real
# student data), for rendering frame by frame (window.__T = seconds) into a Witness benchmark clip.
# Spec: {out, head, qlines: [..], items: [[start, dur, "t", x, y, text, "rtl"?] | [start, dur, "x", ref, nChars] | [start, dur, "e", ref] (rubbed out)],
#        sway?: px}
import base64, json, pathlib, sys
spec = json.load(open(sys.argv[1], encoding='utf-8'))
import os
font = base64.b64encode(pathlib.Path(os.environ.get("HAND_FONT", r"C:\Windows\Fonts\Inkfree.ttf")).read_bytes()).decode()

html = """<!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<style>@font-face{font-family:H;src:url(data:font/ttf;base64,FONT)}html,body{margin:0;background:#6b5a48;overflow:hidden}
canvas{display:block;width:100vw;height:100vh}</style></head><body><canvas id=c></canvas><script>
const items=ITEMS, QL=QLINES, SW=SWAY, c=document.getElementById('c'), g=c.getContext('2d');
let W,H; function size(){W=c.width=innerWidth*devicePixelRatio;H=c.height=innerHeight*devicePixelRatio;}
size(); addEventListener('resize',size);
const INK=INKPX+'px H, "Segoe Print", "Nirmala UI", "Segoe UI", Arial';
function paper(){g.fillStyle='#f4efe2';g.fillRect(20,40,620,980);g.strokeStyle='#b9cfe6';g.lineWidth=1.2;
 for(let y=150+35*QL.length;y<1000;y+=35){g.beginPath();g.moveTo(20,y);g.lineTo(640,y);g.stroke();}
 g.strokeStyle='#e7a1a1';g.beginPath();g.moveTo(90,40);g.lineTo(90,1020);g.stroke();
 g.fillStyle='#222';g.font='22px serif';g.fillText(HEAD,40,90);
 g.font='18px serif';QL.forEach((q,i)=>g.fillText(q,40,122+24*i));}
function draw(t){g.setTransform(1,0,0,1,0,0); g.fillStyle='#6b5a48';g.fillRect(0,0,W,H);
 const s=Math.min(W/660,H/1060), sx=Math.sin(t*1.3)*SW, sy=Math.cos(t*0.9)*SW*0.7;
 g.setTransform(s,0,0,s,(W-660*s)/2+sx,(H-1060*s)/2+sy); g.rotate(-0.012);
 paper(); g.fillStyle='#1b2a6b'; g.strokeStyle='#1b2a6b'; g.font=INK; let tip=null;
 const m=q=>g.measureText(q).width;
 for(const it of items){const [st,du,k]=it; if(t<st)continue; const p=Math.min(1,(t-st)/du);
  if(k==='t'){const [, , ,x,y,txt,dir]=it; const w=m(txt); g.save(); g.beginPath();
   if(dir==='rtl'){g.rect(x+w*(1-p)-5,y-50,w*p+10,70);} else {g.rect(x-5,y-50,w*p+5,70);} g.clip(); g.fillText(txt,x,y); g.restore();
   if(p<1) tip=dir==='rtl'?[x+w*(1-p),y-8]:[x+w*p,y-8];}
  else if(k==='e'){const [, , ,ref]=it, R=items[ref], w=m(R[5]); g.save(); g.fillStyle='#efe9db'; g.fillRect(R[3]-6,R[4]-46,(w+12)*p,62);
   g.fillStyle='rgba(120,110,95,0.10)'; g.fillRect(R[3]-6,R[4]-20,(w+12)*p,8); g.restore(); g.fillStyle='#1b2a6b'; if(p<1) tip=[R[3]+(w+12)*p,R[4]+10];}
  else{const [, , ,ref,n]=it, R=items[ref], tx=R[5]; const x1=R[3]+m(tx)-m(tx.slice(tx.length-n)), x2=R[3]+m(tx), y1=R[4]-13;
   const ex=x1+(x2-x1)*p; g.lineWidth=3.5; g.beginPath(); g.moveTo(x1,y1); g.lineTo(ex,y1); g.stroke(); if(p<1) tip=[ex,y1];}}
 if(!tip){const last=items.filter(i=>i[0]<=t).pop(); if(last){const R=last[2]==='t'?last:items[last[3]]; tip=[R[3]+m(R[5])+20,R[4]+30];} else tip=[500,900];}
 g.save(); g.translate(tip[0],tip[1]); g.rotate(0.6); g.fillStyle='#2b2b2b'; g.fillRect(-4,-2,8,120); g.fillStyle='#c68e6a';
 g.beginPath(); g.ellipse(18,150,55,70,0.3,0,6.3); g.fill(); g.restore();}
window.__draw=draw;
</script></body></html>"""
html = (html.replace("ITEMS", json.dumps(spec["items"], ensure_ascii=False))
            .replace("QLINES", json.dumps(spec["qlines"], ensure_ascii=False))
            .replace("SWAY", str(spec.get("sway", 3)))
            .replace("INKPX", str(spec.get("ink", 40)))
            .replace("HEAD", json.dumps(spec["head"], ensure_ascii=False))
            .replace("FONT", font))
out = sys.argv[2] if len(sys.argv) > 2 else spec["out"]
pathlib.Path(out).write_text(html, encoding="utf-8")
print("ok", out)
