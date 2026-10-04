// La séance : le vrai tableau des séries en gros plan, et les coches qui
// claquent une à une sur les pieds. Les lignes pas encore validées sont la
// capture elle-même, passée en gris ; au temps voulu le gris tombe et la
// vraie ligne (verte, ou dorée pour le record) apparaît.
(() => {
  const L = 600, E = L / 1080;          // largeur du gros plan, échelle de la capture
  const HAUT = 1112, BAS = 1990;        // la tranche de la capture montrée (px d'origine)
  const H = Math.round((BAS - HAUT) * E);
  // les lignes validées : bords haut et bas (px d'origine), couleur, temps de la coche
  const LIGNES = [
    { y0: 1222, y1: 1374, c: '#22D85F', t: 1 },
    { y0: 1374, y1: 1524, c: '#FFBE0B', t: 2 },
    { y0: 1524, y1: 1676, c: '#22D85F', t: 3 },
    { y0: 1676, y1: 1826, c: '#22D85F', t: 4 },
  ];
  const img = (style = '') => `<img src="${BRUT}05-seance.png" style="position:absolute;left:0;width:${L}px;${style}">`;
  const lignes = LIGNES.map((g, i) => {
    const y = (g.y0 - HAUT) * E, h = (g.y1 - g.y0) * E;
    const px = 972 * E, py = y + h / 2, pw = 126 * E, ph = 92 * E; // la pastille de la coche
    return `<div class="sea-gris" id="sea-gris-${i}" style="top:${y}px;height:${h}px">${img(`top:${-g.y0 * E}px;filter:grayscale(1) brightness(.62)`)}</div>
      <div class="sea-flash" id="sea-flash-${i}" style="top:${y}px;height:${h}px;background:${g.c}"></div>
      <div class="sea-onde" id="sea-onde-${i}" style="left:${px - pw / 2}px;top:${py - ph / 2}px;width:${pw}px;height:${ph}px;border-color:${g.c}"></div>`;
  }).join('');

  scene({
    id: 'seance', de: 16, a: 22,
    css: `
      .sea-carte{position:absolute;left:80px;top:${Math.round((720 - H) / 2)}px;width:${L}px;height:${H}px;border-radius:34px;
        box-shadow:0 0 0 1px #4a4a52,0 0 0 10px #101013,0 0 0 11px #2c2c32,0 50px 90px -20px rgba(0,0,0,.9),0 0 90px -10px rgba(255,255,255,.16)}
      .sea-vue{position:absolute;inset:0;border-radius:34px;overflow:hidden;background:#000}
      .sea-gris{position:absolute;left:0;width:${L}px;overflow:hidden}
      .sea-flash{position:absolute;left:0;width:${L}px;mix-blend-mode:screen}
      .sea-onde{position:absolute;border:4px solid;border-radius:999px}
      .sea-mot{position:absolute;left:760px;top:299px;font-size:60px}
      .sea-mot span{display:block}
    `,
    html: `<div class="fond"></div>
      <div class="sea-carte" id="sea-carte"><div class="sea-vue">${img(`top:${-HAUT * E}px`)}${lignes}</div></div>
      <div class="titre sea-mot"><span id="sea-mot-1" style="color:#8e8e93">CHAQUE</span><span id="sea-mot-2">SÉRIE.</span></div>`,
    rendre(l, b) {
      // le gros plan : il arrive avec l'éclair, puis bat sur chaque pied
      const k = sortie(l / 0.8);
      $('sea-carte').style.transform = `scale(${lerp(1.12, 1, k) * pouls(b, 0.018)})`;
      // les coches, une par temps
      LIGNES.forEach((g, i) => {
        const d = l - g.t;                       // temps écoulé depuis la coche
        const fait = d >= 0;
        $(`sea-gris-${i}`).style.opacity = fait ? 0 : 1;
        $(`sea-flash-${i}`).style.opacity = fait ? 0.55 * Math.exp(-d * 4.5) : 0;
        const o = $(`sea-onde-${i}`).style;
        o.opacity = fait ? Math.max(0, 1 - d / 0.8) : 0;
        o.transform = `scale(${1 + 0.6 * sortie(d / 0.8)})`;
      });
      // le mot : « CHAQUE » avec l'éclair, « SÉRIE. » sur la première coche
      const m1 = $('sea-mot-1').style, m2 = $('sea-mot-2').style;
      m1.opacity = borne(l / 0.3);
      m1.transform = `translateX(${(1 - sortie(l / 0.7)) * 50}px)`;
      m2.opacity = l >= 1 ? 1 : 0;
      m2.transformOrigin = '0 60%';
      m2.transform = `scale(${l >= 1 ? lerp(1.22, 1, sortie((l - 1) / 0.5)) * pouls(b, 0.03) : 1})`;
    },
  });
})();
