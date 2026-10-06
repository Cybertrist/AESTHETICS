// Petit serveur statique et pilote Chrome headless (puppeteer-core).
const http = require('http');
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.glb': 'model/gltf-binary', '.obj': 'text/plain', '.png': 'image/png', '.jpg': 'image/jpeg', '.bin': 'application/octet-stream' };

function serveur(racine) {
  return new Promise((ok) => {
    const s = http.createServer((req, res) => {
      const p = path.join(racine, decodeURIComponent(req.url.split('?')[0]));
      fs.readFile(p, (err, data) => {
        if (err) { res.writeHead(404); res.end(); return; }
        res.writeHead(200, { 'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream' });
        res.end(data);
      });
    });
    s.listen(0, '127.0.0.1', () => ok(s));
  });
}

async function ouvrir(page, largeur = 1200, hauteur = 1200) {
  const s = await serveur(path.join(__dirname, '..', '..'));
  const nav = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--use-angle=d3d11', '--enable-gpu', '--ignore-gpu-blocklist', '--enable-webgl'],
    protocolTimeout: 600000,
  });
  const p = await nav.newPage();
  await p.setViewport({ width: largeur, height: hauteur });
  p.on('console', (m) => console.log('[page]', m.text()));
  p.on('pageerror', (e) => console.log('[erreur]', e.message));
  await p.goto(`http://127.0.0.1:${s.address().port}/tools/corps3d/${page}`);
  return { page: p, fermer: async () => { await nav.close(); s.close(); } };
}

function ecrireDataUrl(url, fichier) {
  fs.mkdirSync(path.dirname(fichier), { recursive: true });
  fs.writeFileSync(fichier, Buffer.from(url.split(',')[1], 'base64'));
}

module.exports = { ouvrir, ecrireDataUrl };
