// « CHAQUE SÉRIE. » (temps 16 à 20) : le vrai tableau des séries, en gros plan.
// Une coche par pied, prise dans l'enregistrement `seance-coches` ; au quatrième pied le
// cadrage saute en haut du même écran : minuteur parti, compteurs à jour.
(() => {
  const NOM = 'seance-coches';
  const L = 560, H = 364;        // le cadre, en px de page (0,93 px de page par px du clip)
  const HC = H * 600 / L;        // la hauteur de clip que le cadre montre : 390 px
  const Y_TABLE = 539;           // « Minuteur de repos », l'en-tête, puis les lignes É, 1 et 2
  const Y_HAUT = 86;             // la pilule du minuteur, Durée / Volume / Séries, l'exercice
  const AVANCE = 0.07;           // deux images après le repère : la coche est pleinement verte

  scene({
    id: 'serie', de: 16, a: 20,
    css: `
#ser-cadre{position:relative;width:${L}px;height:${H}px;border-radius:28px;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
#ser-clip{display:block;width:${L}px;height:${H}px}
`,
    html: `<div class="fond"></div>
<div class="zone"><div id="ser-cadre"><canvas id="ser-clip" width="${L * 1.5}" height="${H * 1.5}"></canvas></div></div>
${motCle('ser', 'Chaque', 'série.')}`,
    async init() { await clip(NOM); },
    rendre(l) {
      rendreMotCle('ser', l);
      const c = CLIPS[NOM]; if (!c) return;
      const r = c.reperes;
      // Chaque pied prend le clip au repère de sa coche, puis le laisse tourner (0,4 s par temps).
      // Du temps 2 au temps 4 le clip file sans saut : seul le cadrage bascule au temps 3.
      const k = l < 1 ? 0 : l < 2 ? 1 : 2;
      const s = [r.coche1, r.coche2, r.coche3][k] + AVANCE + (l - k) * T;
      const y = l >= 3 - 1e-6 ? Y_HAUT : Y_TABLE;
      const im = c.images[borne(Math.floor(s * c.ips), 0, c.images.length - 1)];
      const cv = $('ser-clip'), x = cv.getContext('2d');
      x.imageSmoothingQuality = 'high';
      x.drawImage(im, 0, y, 600, HC, 0, 0, cv.width, cv.height);
    },
  });
})();
