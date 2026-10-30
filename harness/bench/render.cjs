// electron render.cjs <page.html> <outDir> <seconds> <fps> <width> <height>
// Draws the benchmark page at each frame's own time (window.__draw(t)) and saves the frames as PNGs.
const {app, BrowserWindow} = require('electron');
const fs = require('fs'), path = require('path');
const [html, out, secs, fps, w, h] = process.argv.slice(2);
app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const win = new BrowserWindow({width: +w, height: +h, show: false, useContentSize: true, webPreferences: {offscreen: true}});
  console.log('load', html); await win.loadFile(html); console.log('loaded');
  await win.webContents.executeJavaScript('document.fonts.ready.then(() => true)');
  console.log('fonts'); fs.mkdirSync(out, {recursive: true});
  const n = Math.round(+secs * +fps);
  for (let i = 0; i < n; i++) {
    await win.webContents.executeJavaScript(`window.__draw(${(i / +fps).toFixed(4)}); true`);
    const img = await win.webContents.capturePage({x: 0, y: 0, width: +w, height: +h});
    fs.writeFileSync(path.join(out, String(i).padStart(5, '0') + '.png'), img.toPNG());
  }
  app.quit();
}).catch((e) => { console.error('render failed', e); app.exit(1); });
