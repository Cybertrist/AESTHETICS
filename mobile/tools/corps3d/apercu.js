// node apercu.js "regex" vue cadre sortie.png
const { ouvrir, ecrireDataUrl } = require('./serveur');
(async () => {
  const [re, vue = 'face', cadre = 'corps', out = 'sortie/apercu.png'] = process.argv.slice(2);
  const { page, fermer } = await ouvrir('scene.html', 400, 400);
  await page.waitForFunction('window.pret === true', { timeout: 120000 });
  await page.evaluate('preparer()');
  ecrireDataUrl(await page.evaluate((a, b, c) => window.apercu(a, b, c), re, vue, cadre), out);
  await fermer();
})();
