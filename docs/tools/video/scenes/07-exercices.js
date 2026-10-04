// La scène « exercices » (temps 28 à 32) : le catalogue par ce qu'il a de plus
// spectaculaire, le vrai personnage qui exécute le mouvement. Une grande tuile,
// et un exercice différent sur chaque pied.
//   temps 0 : développé couché ; « 608 » est là
//   temps 1 : rowing barre ; « EXERCICES. » frappe
//   temps 2 : fente bulgare ; « 496 animés » frappe
//   temps 3 : développé Arnold
// Chaque animation est jouée deux fois plus vite, depuis l'image où le geste
// est le plus ample : seize images d'animation par temps.
const EXO_PLANS = [
  ['bench-press', 10],            // la barre descend des bras tendus à la poitrine
  ['barbell-row', 22],            // la barre monte du sol au ventre
  ['bulgarian-split-squat', 2],   // la descente, de debout à genou bas
  ['arnold-press', 16],           // les haltères montent des épaules à bras tendus
];
scene({
  id: 'exercices', de: 28, a: 32,
  css: `
    #exo-tuile{position:relative;width:520px;height:520px;border-radius:28px;background:#141416;box-shadow:0 0 0 1px #2a2a2e;overflow:hidden}
    #exo-anim{position:absolute;left:0;top:0;width:520px;height:520px;display:block;transform-origin:center center}
    /* Le seul écart à la charte du mot-clé : le nombre en Space Grotesk (le zéro de Syne se lit « o »),
       blanc et en grand. Le bloc remonte, pour que le bas de « EXERCICES. » reste où finit d'ordinaire le mot-clé. */
    #exo-mc{top:252px}
    #exo-mc1{font-family:'Space Grotesk',sans-serif;font-weight:700;font-variant-numeric:tabular-nums;font-size:150px;line-height:135px;letter-spacing:-3px;color:#fff;margin-left:-2px}
    #exo-sous{transform-origin:left center}
    #exo-sous b{font-weight:700;font-variant-numeric:tabular-nums;color:#fff}
  `,
  html: `<div class="fond"></div>
    <div class="zone"><div id="exo-tuile"><canvas id="exo-anim" width="720" height="720"></canvas></div></div>
    ${motCle('exo', '608', 'exercices.')}
    <div class="mc-sous" id="exo-sous"><b>496</b>&nbsp;animés</div>`,
  async init() {
    await Promise.all(EXO_PLANS.map(([nom]) => animation(nom)));
    // « EXERCICES. » en Syne à 72 px fait près de 770 px de large et sortirait du cadre : la ligne est
    // réduite, une fois pour toutes, à 480 px de large (elle finit à 1184 px, et à 1213 px au plus fort
    // de sa frappe), ce qui la laisse au-dessus de 30 px de corps.
    const m = $('exo-mc2');
    m.style.fontSize = '72px';
    m.style.fontSize = `${(72 * 480 / m.getBoundingClientRect().width).toFixed(2)}px`;
  },
  rendre(l) {
    rendreMotCle('exo', l);
    // Même frappe que partout, au temps 1, mais moins ample : la ligne est longue et ne doit pas passer 1216 px.
    $('exo-mc2').style.transform = `scale(${frappe(l - 1, 0.06).toFixed(4)})`;
    // Un exercice par temps : la coupe tombe sur le pied, puis le geste se déroule.
    const n = borne(Math.floor(l + 1e-6), 0, 3), dans = borne(l - n, 0, 1);
    const [nom, depart] = EXO_PLANS[n];
    const image = depart + Math.min(15, Math.floor(dans * 16 + 1e-6));
    dessiner($('exo-anim'), nom, (image + 0.5) / 20);
    $('exo-anim').style.transform = `scale(${frappe(dans, 0.06).toFixed(4)})`;
    const s = $('exo-sous').style;
    s.opacity = la(l - 2); s.transform = `scale(${frappe(l - 2).toFixed(4)})`;
  },
});
