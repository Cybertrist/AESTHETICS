const { ouvrir, ecrireDataUrl } = require('./serveur');
(async () => {
  const [vue, cadre] = process.argv.slice(2);
  const { page, fermer } = await ouvrir('scene.html', 400, 400);
  await page.waitForFunction('window.pret === true', { timeout: 120000 });
  await page.evaluate('preparer()');
  const u = await page.evaluate(async (v, c) => { window.DEBUG_REGIONS = 1; return (await passes(v, c)).carte; }, vue, cadre);
  ecrireDataUrl(u, 'sortie/carte.png');
  await fermer();
})();
