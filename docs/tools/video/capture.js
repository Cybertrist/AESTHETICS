// Photographie la vidéo de présentation image par image, et la monte.
//
// Chrome est lancé sans affichage et piloté par son protocole de débogage :
// pour chaque image, rendre(t) pose la page à l'instant t, puis une capture
// part vers ffmpeg, qui encode la vidéo et y pose la musique. La page est
// servie par un petit serveur local, parce qu'elle lit ses animations par
// fetch().
//
//   node docs/tools/video/capture.js             la vidéo entière
//   node docs/tools/video/capture.js --apercu    des images fixes de toute la vidéo, pour relire
//   node docs/tools/video/capture.js --apercu --scene seance    six images d'une seule scène
//   node docs/tools/video/capture.js --bande seance    une image par demi-temps de la scène, en planche
//   node docs/tools/video/capture.js --bande tout      une image par temps de toute la vidéo
const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');
const { spawn } = require('child_process');

const DOCS = path.join(__dirname, '..', '..');
const SORTIE = path.join(__dirname, '..', 'html', 'video');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const APERCU = process.argv.includes('--apercu');
const BANDE = process.argv.includes('--bande') ? process.argv[process.argv.indexOf('--bande') + 1] : null;
const SCENE = process.argv.includes('--scene') ? process.argv[process.argv.indexOf('--scene') + 1] : null;
// Un port par lancement : plusieurs captures peuvent tourner en même temps.
const PORT = 9300 + Math.floor(Math.random() * 600);
const IPS = 30, DUREE = 25.6, L = 1280, H = 720, DENSITE = 1.5; // 1920 × 1080
fs.mkdirSync(SORTIE, { recursive: true });

const TYPES = { html: 'text/html; charset=utf-8', png: 'image/png', webp: 'image/webp', jpg: 'image/jpeg', js: 'text/javascript' };
const serveur = http.createServer((q, r) => {
  const f = path.join(DOCS, decodeURIComponent(q.url.split('?')[0]));
  if (!f.startsWith(DOCS) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; }
  r.writeHead(200, { 'Content-Type': TYPES[f.split('.').pop()] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(r);
});
const attendre = (ms) => new Promise((ok) => setTimeout(ok, ms));

(async () => {
  await new Promise((ok) => serveur.listen(0, '127.0.0.1', ok));
  const port = serveur.address().port;
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'video-'));
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profil}`, `--window-size=${L},${H}`, 'about:blank'], { stdio: 'ignore' });
  let cible;
  for (let k = 0; k < 60 && !cible; k++) {
    await attendre(250);
    try { cible = (await (await fetch(`http://127.0.0.1:${PORT}/json`)).json()).find((c) => c.type === 'page'); } catch (e) { /* pas encore prêt */ }
  }
  if (!cible) throw new Error('Chrome ne répond pas');
  const ws = new WebSocket(cible.webSocketDebuggerUrl);
  await new Promise((ok) => { ws.onopen = ok; });
  let suivant = 1; const attentes = new Map();
  ws.onmessage = (m) => { const r = JSON.parse(m.data); if (attentes.has(r.id)) { attentes.get(r.id)(r); attentes.delete(r.id); } };
  const cdp = (method, params = {}) => new Promise((ok, ko) => {
    const id = suivant++; attentes.set(id, (r) => (r.error ? ko(new Error(`${method} : ${r.error.message}`)) : ok(r.result)));
    ws.send(JSON.stringify({ id, method, params }));
  });
  const js = async (expression) => (await cdp('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result.value;

  await cdp('Emulation.setDeviceMetricsOverride', { width: L, height: H, deviceScaleFactor: DENSITE, mobile: false });
  await cdp('Page.navigate', { url: `http://127.0.0.1:${port}/tools/video/video.html` });
  for (let k = 0; k < 240 && !(await js('window.pret === true')); k++) await attendre(250);
  if (!(await js('window.pret === true'))) throw new Error('La page ne se charge pas');
  const image = async (t) => {
    await js(`rendre(${t}); new Promise((ok) => requestAnimationFrame(() => requestAnimationFrame(ok)))`);
    return Buffer.from((await cdp('Page.captureScreenshot', { format: 'jpeg', quality: 93 })).data, 'base64');
  };

  if (BANDE) {
    // La bande : la scène image par image, une par demi-temps, pour juger le rythme.
    // Quatre images par ligne : une ligne fait deux temps. Pour toute la vidéo, une image
    // par temps et huit par ligne : une ligne fait deux mesures.
    const { execFileSync } = require('child_process');
    let de = 0, a = 64, pas = 1, colonnes = 8;
    if (BANDE !== 'tout') {
      const bornes = await js(`(() => { const s = SCENES.find((x) => x.id === ${JSON.stringify(BANDE)}); return s ? [s.de, s.a] : null; })()`);
      if (!bornes) throw new Error(`Scène inconnue : ${BANDE}`);
      [de, a] = bornes; pas = 0.5; colonnes = 4;
    }
    const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'bande-'));
    let n = 0;
    // Un dixième de temps après le temps : on voit ce que le pied vient de déclencher.
    for (let b = de; b < a - 1e-9; b += pas) fs.writeFileSync(path.join(dossier, `${String(++n).padStart(3, '0')}.jpg`), await image((b + 0.1) * 0.4));
    const sortie = path.join(SORTIE, `bande-${BANDE}.jpg`);
    execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', path.join(dossier, '%03d.jpg'), '-vf',
      `scale=480:270,tile=${colonnes}x${Math.ceil(n / colonnes)}:margin=6:padding=6:color=0x333333`, '-frames:v', '1', '-q:v', '3', sortie]);
    fs.rmSync(dossier, { recursive: true, force: true });
    console.log(`  bande-${BANDE}.jpg  ${n} images, de ${de} à ${a}, une tous les ${pas} temps, ${colonnes} par ligne`);
  } else if (APERCU) {
    let instants = [0.5, 2.6, 4.6, 5.8, 7.4, 9.6, 11.2, 13.0, 15.6, 16.8, 18.6, 20.8, 21.8, 24.6], prefixe = 'apercu';
    if (SCENE) {
      const bornes = await js(`(() => { const s = SCENES.find((x) => x.id === ${JSON.stringify(SCENE)}); return s ? [s.de, s.a] : null; })()`);
      if (!bornes) throw new Error(`Scène inconnue : ${SCENE}`);
      // Six instants dans la scène, du tout début à la toute fin.
      instants = [0.04, 0.2, 0.4, 0.6, 0.8, 0.96].map((k) => +((bornes[0] + (bornes[1] - bornes[0]) * k) * 0.4).toFixed(2));
      prefixe = `apercu-${SCENE}`;
    }
    for (const [k, t] of instants.entries()) {
      const nom = `${prefixe}-${String(k + 1).padStart(2, '0')}.jpg`;
      fs.writeFileSync(path.join(SORTIE, nom), await image(t));
      console.log(`  ${nom}  à ${t} s`);
    }
  } else {
    const musique = path.join(SORTIE, 'musique.wav');
    const video = path.join(SORTIE, 'aesthetics.mp4');
    const ffmpeg = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(IPS), '-c:v', 'mjpeg', '-i', '-',
      '-i', musique, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'slow', '-c:a', 'aac', '-b:a', '192k',
      '-shortest', '-movflags', '+faststart', video], { stdio: ['pipe', 'inherit', 'inherit'] });
    const total = Math.round(DUREE * IPS);
    for (let k = 0; k < total; k++) {
      const tampon = await image(k / IPS);
      if (!ffmpeg.stdin.write(tampon)) await new Promise((ok) => ffmpeg.stdin.once('drain', ok));
      if (k % 90 === 0) console.log(`  image ${k} / ${total}`);
    }
    ffmpeg.stdin.end();
    await new Promise((ok) => ffmpeg.on('close', ok));
    console.log(`  aesthetics.mp4  ${(fs.statSync(video).size / 1048576).toFixed(1)} Mo`);
  }
  ws.close(); chrome.kill(); serveur.close();
  await attendre(400);
  fs.rmSync(profil, { recursive: true, force: true });
})().catch((e) => { console.error(e.message); process.exit(1); });
