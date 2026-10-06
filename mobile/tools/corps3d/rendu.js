// Rendu reproductible : node rendu.js [dossier de sortie]
// Écrit <vue>_base.png, <vue>_traits.png, masques/<vue>_<muscle>.png pour chaque cadrage.
const fs = require('fs');
const path = require('path');
const { ouvrir, ecrireDataUrl } = require('./serveur');

const sortie = path.resolve(process.argv[2] || path.join(__dirname, 'sortie', 'rendu'));
const seulement = process.argv[3]; // ex. "face:corps"

(async () => {
  const t0 = Date.now();
  const { page, fermer } = await ouvrir('scene.html', 400, 400);
  await page.waitForFunction('window.pret === true', { timeout: 120000 });
  console.log('préparation', await page.evaluate('preparer()'), ((Date.now() - t0) / 1000).toFixed(1) + ' s');
  const manifeste = {};
  for (const cadre of ['corps', 'buste']) {
    for (const vue of ['face', 'dos']) {
      if (seulement && seulement !== `${vue}:${cadre}`) continue;
      const r = await page.evaluate(async (v, c) => {
        const x = await window.passes(v, c);
        return { base: x.base.url, traits: x.traits.url, masques: Object.fromEntries(Object.entries(x.masques).map(([k, m]) => [k, m.url])), largeur: x.largeur, hauteur: x.hauteur };
      }, vue, cadre);
      const pre = cadre === 'corps' ? vue : `${vue}_buste`;
      ecrireDataUrl(r.base, path.join(sortie, `${pre}_base.png`));
      ecrireDataUrl(r.traits, path.join(sortie, `${pre}_traits.png`));
      for (const [m, url] of Object.entries(r.masques)) ecrireDataUrl(url, path.join(sortie, 'masques', `${pre}_${m}.png`));
      manifeste[pre] = { largeur: r.largeur, hauteur: r.hauteur, masques: Object.keys(r.masques) };
      console.log(pre, r.largeur + 'x' + r.hauteur, Object.keys(r.masques).length + ' masques', ((Date.now() - t0) / 1000).toFixed(1) + ' s');
    }
  }
  if (!seulement) fs.writeFileSync(path.join(sortie, 'masques', 'manifeste.json'), JSON.stringify(manifeste, null, 1));
  await fermer();
})();
