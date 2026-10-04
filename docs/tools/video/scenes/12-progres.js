// « Chaque progrès. » (temps 52 à 56) : le sommet, et la réponse à la confidence du début.
// La vraie carte de la fiche du développé couché, onglet Progrès : la courbe du 1RM estimé
// sur trois mois. Elle monte par crans, un par pied, puis le gain que l'appli écrit dessus
// est repris en grand sous le mot-clé.
//   0 : la carte, un tiers de la courbe, « CHAQUE »     1 : deux tiers, « PROGRÈS. » frappe
//   2 : la courbe entière, jusqu'à son dernier point     3 : « +24 kg depuis le 5 juil. »
(() => {
  // Tout est mesuré en pixels de la capture (1080 × 2400).
  // La carte va de x 58 à 1021 et de y 821 à 1727 ; le recadrage reste 6 px en dedans, pour
  // que son arrondi ne morde jamais sur le noir de la page.
  const X0 = 64, Y0 = 827, LC = 952;
  // 560 px de page pour 952 px de capture : 0,59 px de page par pixel (la limite est 1,5).
  // Le canevas a un pixel par pixel de sortie (1920 × 1080, soit 1,5 par pixel de page).
  const LP = 840, HP = 790, HC = LC * HP / LP;
  const CARTE = '#131315', GRILLE = '#222226';       // le fond de la carte et ses lignes, relevés sur la capture
  const TRACE = { x0: 205, x1: 950, y0: 1140, y1: 1600 }; // tout ce qui porte la courbe (elle va de x 212 à 941)
  const LIGNES = [[1159, 3], [1280, 3], [1401, 2], [1522, 2]]; // les lignes de la grille : y, épaisseur
  const LIGNE_X0 = 219, LIGNE_X1 = 934;
  // Où s'arrête la courbe à chaque cran : juste après un point, jamais dedans.
  const CRANS = [457, 677];
  let pleine = null, vide = null;

  const toile = (im) => {
    const c = document.createElement('canvas'); c.width = im.naturalWidth; c.height = im.naturalHeight;
    c.getContext('2d').drawImage(im, 0, 0);
    return c;
  };

  scene({
    id: 'progres', de: 52, a: 56,
    html: `<div class="fond"></div>
<div class="zone"><div class="pro-cadre"><canvas id="pro-toile" width="${LP}" height="${HP}"></canvas></div></div>
${motCle('pro', 'Chaque', 'progrès.')}
<div class="mc-sous pro-gain" id="pro-gain">+24&nbsp;kg depuis le 5&nbsp;juil.</div>`,
    css: `
.pro-cadre{width:560px;height:${(HP / 1.5).toFixed(3)}px;border-radius:28px;overflow:hidden;background:${CARTE};box-shadow:0 0 0 1px #2a2a2e}
.pro-cadre canvas{display:block;width:100%;height:100%}
/* « PROGRÈS. » est large : on resserre ses lettres pour garder 64 px de marge à droite. */
#pro-mc2{letter-spacing:-2px}
.pro-gain{color:#22D85F;font-weight:700;font-variant-numeric:tabular-nums;transform-origin:left center}
`,
    async init() {
      const im = new Image();
      im.src = `${BRUT}08a-fiche-progres.png`;
      await im.decode();
      pleine = toile(im);
      // La même carte sans sa courbe : le fond de la carte, puis les lignes de la grille
      // reposées au pixel près. La courbe « monte » en découvrant la vraie image par-dessus.
      vide = toile(im);
      const x = vide.getContext('2d');
      x.fillStyle = CARTE; x.fillRect(TRACE.x0, TRACE.y0, TRACE.x1 - TRACE.x0, TRACE.y1 - TRACE.y0);
      x.fillStyle = GRILLE;
      for (const [y, e] of LIGNES) x.fillRect(LIGNE_X0, y, LIGNE_X1 - LIGNE_X0, e);
    },
    rendre(l) {
      rendreMotCle('pro', l);
      // La courbe : un tiers, deux tiers, entière.
      const jusque = l >= 2 - 1e-6 ? TRACE.x1 : l >= 1 - 1e-6 ? CRANS[1] : CRANS[0];
      if (pleine) {
        const x = $('pro-toile').getContext('2d');
        x.imageSmoothingEnabled = true; x.imageSmoothingQuality = 'high';
        x.clearRect(0, 0, LP, HP);
        x.drawImage(vide, X0, Y0, LC, HC, 0, 0, LP, HP);
        x.save();
        x.beginPath(); x.rect(0, 0, Math.round((jusque - X0) * LP / LC), HP); x.clip();
        x.drawImage(pleine, X0, Y0, LC, HC, 0, 0, LP, HP);
        x.restore();
      }
      // Le gain, tel que l'appli l'écrit sur la carte, frappe au temps 3.
      const g = $('pro-gain').style;
      g.opacity = la(l - 3); g.transform = `scale(${frappe(l - 3).toFixed(4)})`;
    },
  });
})();
