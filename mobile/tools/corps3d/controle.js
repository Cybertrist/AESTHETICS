// Planche de contrôle : références et rendu avec les mêmes muscles en rouge.
// node controle.js [dossier des images, relatif à mobile/] [sortie.png]
const { ouvrir } = require('./serveur');
(async () => {
  const dossier = '/' + (process.argv[2] || 'tools/corps3d/sortie/rendu');
  const out = process.argv[3] || 'sortie/controle.png';
  const { page, fermer } = await ouvrir('controle.html', 2600, 400);
  await page.waitForFunction('window.pret === true');
  const R = '/tools/corps3d/refs_zoom/';
  const lignes = [
    [620, [R + 'r4a.png', { dossier, pre: 'face', muscles: { pectoraux: 1, deltoidesAnterieurs: 1, deltoidesLateraux: 1 } }, R + 'r4b.png', { dossier, pre: 'dos', muscles: { deltoidesPosterieurs: 1, deltoidesLateraux: 1, trapezes: 1 } }]],
    [400, [R + 'r1.png', { dossier, pre: 'face_buste', muscles: { abdominaux: 1 } }, { dossier, pre: 'face_buste', muscles: { abdominaux: 1, obliques: 1 } }]],
    [400, [R + 'r3.png', { dossier, pre: 'dos_buste', muscles: {} }]],
    [400, [R + 'r2a.png', { dossier, pre: 'dos_buste', muscles: { trapezes: 1 } }, R + 'r2b.png', { dossier, pre: 'dos_buste', muscles: { grandDorsal: 1 } }, { dossier, pre: 'face_buste', muscles: { pectoraux: 1, deltoidesAnterieurs: 1 } }]],
  ];
  for (const [h, el] of lignes) await page.evaluate((h, el) => window.ligne(h, el), h, el);
  const { w, h } = await page.evaluate(() => ({ w: document.body.scrollWidth, h: document.body.scrollHeight }));
  await page.setViewport({ width: w, height: h });
  await page.screenshot({ path: out, fullPage: true });
  await fermer();
})();
