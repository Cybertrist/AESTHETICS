// Planche côte à côte : node comparer.js sortie.png hauteur img1 img2 ... (chemins relatifs à mobile/)
const { ouvrir } = require('./serveur');
const fs = require('fs');
const path = require('path');
(async () => {
  const [out, h, ...imgs] = process.argv.slice(2);
  const racine = path.join(__dirname, '..', '..');
  const html = `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#1c1c1c;display:flex;gap:24px;padding:16px;align-items:flex-end;width:max-content">${imgs.map((i) => `<img src="/${path.relative(racine, path.resolve(i)).split(path.sep).join('/')}?${Date.now()}" style="height:${h}px;width:auto">`).join('')}</body>`;
  fs.writeFileSync(path.join(__dirname, 'sortie', '_planche.html'), html);
  const { page, fermer } = await ouvrir('sortie/_planche.html', 3000, +h + 32);
  await page.evaluate(async () => { for (const i of document.images) await i.decode(); });
  const w = await page.evaluate(() => document.body.scrollWidth);
  await page.setViewport({ width: w, height: +h + 32 });
  await page.screenshot({ path: out });
  await fermer();
})();
