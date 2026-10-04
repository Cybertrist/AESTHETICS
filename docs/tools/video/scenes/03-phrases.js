// La scène « phrases » (temps 8 à 16) : la respiration de la musique, sans pied.
// Deux phrases, les mots de Tristan. La première se pose groupe par groupe sur les temps
// 0, 1, 2 et tient jusqu'à la coupe du temps 4. La seconde frappe bloc par bloc sur les
// temps 4, 5, 6, les trois au même corps ; le dernier grandit par crans sur les coups du
// roulement de caisse claire, puis s'inverse (fond blanc, texte noir) sur les huitièmes
// du dernier temps.
(() => {
  const LARGEUR = 1100;      // le bloc le plus long tient dans cette largeur
  const MAX = 1280 - 2 * 64; // jamais à moins de 64 px des bords
  const BLOCS = ['C’est le moment', 'D’atteindre', 'Mes objectifs.'];
  let corps = 110;           // recalculé dans init, d'après la police réellement chargée
  let grandMax = 1.04;       // l'échelle du dernier cran de « MES OBJECTIFS. »

  // Les coups du roulement (voir musique.js) : par quart de temps de 6 à 7, par huitième
  // de 7 à 8. Douze coups après celui du temps 6 : onze crans d'échelle, de 1 à grandMax.
  const cran = (l) => {
    const e = 1e-6;
    if (l < 6) return 0;
    if (l < 7 - e) return Math.floor((l - 6 + e) / 0.25);        // 0 à 3
    return 4 + Math.min(3, Math.floor((l - 7 + e) / 0.125));     // 4 à 11
  };
  const negatif = (l) => l >= 7 - 1e-6 && Math.min(3, Math.floor((l - 7 + 1e-6) / 0.25)) % 2 === 0;

  scene({
    id: 'phrases', de: 8, a: 16,
    css: `
#phr-neg{position:absolute;inset:0;background:#fff;opacity:0}
#phr-p1{font-family:'Space Grotesk',sans-serif;font-weight:500;font-size:92px;line-height:1.16;letter-spacing:-1px;color:#fff;text-align:center;white-space:nowrap}
#phr-p1 span{display:block;opacity:0}
.phr-bloc{position:absolute;left:0;top:0;width:1280px;height:720px;display:flex;align-items:center;justify-content:center;opacity:0}
.phr-bloc span{display:block;white-space:nowrap;line-height:1;color:#fff;transform-origin:center center}
#phr-mesure{position:absolute;left:0;top:0;visibility:hidden;white-space:nowrap;font-size:100px;line-height:1}
`,
    html: `<div class="fond"></div>
<div id="phr-neg"></div>
<div class="c" id="phr-c1"><div id="phr-p1">
  <span id="phr-g0">Je me suis toujours</span>
  <span id="phr-g1">senti mal</span>
  <span id="phr-g2">dans mon corps.</span>
</div></div>
${BLOCS.map((x, i) => `<div class="phr-bloc" id="phr-b${i}"><span class="titre" id="phr-t${i}">${x}</span></div>`).join('')}
<span class="titre" id="phr-mesure"></span>`,
    async init() {
      // Le même corps pour les trois blocs : celui qui fait tenir le plus long dans 1100 px.
      try { await document.fonts.load("800 100px Syne", 'C’EST LE MOMENT D’ATTEINDRE MES OBJECTIFS.'); } catch (e) { /* la police de repli sera mesurée */ }
      const m = $('phr-mesure');
      const larg = BLOCS.map((x) => { m.textContent = x; return m.getBoundingClientRect().width; });
      const plus = Math.max(...larg);
      if (plus > 0) {
        corps = Math.floor((LARGEUR / plus) * 100);
        // « MES OBJECTIFS. » peut grandir jusqu'à 64 px des bords, pas plus (et pas plus de 1,3).
        grandMax = Math.min(1.3, MAX / ((larg[2] * corps) / 100));
      }
      m.textContent = '';
      window.phrMesures = { corps, grandMax, largeurs: larg.map((w) => Math.round((w * corps) / 100)) };
    },
    rendre(l) {
      const e = 1e-6;
      const neg = negatif(l);
      $('phr-neg').style.opacity = neg ? 1 : 0;

      // La première phrase : chaque groupe est là d'un coup sur son temps, et tout
      // disparaît en coupe franche au temps 4.
      $('phr-c1').style.opacity = l < 4 - e ? 1 : 0;
      for (let i = 0; i < 3; i++) $(`phr-g${i}`).style.opacity = la(l - i);

      // La seconde : un bloc à la fois, chacun remplace le précédent.
      const actif = l < 4 - e ? -1 : l < 5 - e ? 0 : l < 6 - e ? 1 : 2;
      for (let i = 0; i < 3; i++) {
        const b = $(`phr-b${i}`).style, s = $(`phr-t${i}`).style;
        b.opacity = i === actif ? 1 : 0;
        s.fontSize = `${corps}px`;
        s.color = neg ? '#000' : '#fff';
        // Les deux premiers frappent (un excès court, qui reste dans les marges) ; le
        // dernier monte par crans, immobile entre deux coups.
        const k = i < 2 ? frappe(l - (4 + i), 0.04, 0.25) : 1 + ((grandMax - 1) * cran(l)) / 11;
        s.transform = `scale(${k.toFixed(4)})`;
      }
    },
  });
})();
