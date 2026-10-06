const { ouvrir } = require('./serveur');
(async () => {
  const { page, fermer } = await ouvrir(process.argv[4] || 'scene.html', 400, 400);
  await page.waitForFunction('window.pret === true', { timeout: 120000 });
  if (process.argv[3] !== 'x') await page.evaluate('preparer()');
  console.log(await page.evaluate(process.argv[2]));
  await fermer();
})();
