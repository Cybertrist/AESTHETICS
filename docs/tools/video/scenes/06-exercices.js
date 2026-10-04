// Les exercices : le chiffre d'abord, énorme, puis trois tuiles où le vrai
// personnage exécute le mouvement. Une tuile par pied (1, 2, 3), « 496 animés »
// tombe sur le pied 4.
const EXO_TUILES = [['bench-press', 'Développé couché'], ['barbell-row', 'Rowing barre'], ['bulgarian-split-squat', 'Fente bulgare']];
scene({
  id: 'exercices', de: 30, a: 36,
  css: `
    #exo-nombre{position:absolute;left:64px;top:56px;font-size:196px;line-height:.86;letter-spacing:-4px;transform-origin:0 60%}
    #exo-mot{position:absolute;left:0;top:62px;font-size:66px;line-height:1;transform-origin:0 50%}
    #exo-animes{position:absolute;left:0;top:163px;font-size:46px;line-height:1;font-weight:500;color:#a8a8b0;white-space:nowrap;transform-origin:0 50%}
    #exo-animes b{font-family:'JetBrains Mono',monospace;font-weight:700;color:#fff}
    .exo-tuile{position:absolute;top:266px;width:360px;height:390px;border-radius:34px;background:#141416;
      box-shadow:0 0 0 1px #2a2a2e,0 30px 60px -20px #000}
    .exo-cadre{position:absolute;left:14px;top:14px;width:332px;height:306px;border-radius:24px;background:#1e1e21;overflow:hidden}
    .exo-cadre canvas{position:absolute;left:-2px;top:-15px;width:336px;height:336px}
    .exo-nom{position:absolute;left:0;right:0;top:334px;text-align:center;font-size:29px;line-height:1.2;font-weight:700;color:#fff;white-space:nowrap}`,
  html: `<div class="fond"></div>
    <div class="titre" id="exo-nombre">608</div>
    <div id="exo-droite" style="position:absolute;left:0;top:0">
      <div class="titre" id="exo-mot">Exercices</div>
      <div id="exo-animes"><b>496</b> animés</div>
    </div>
    ${EXO_TUILES.map(([f, nom], i) => `<div class="exo-tuile" id="exo-t${i}" style="left:${64 + i * 396}px">
      <div class="exo-cadre"><canvas id="exo-cv${i}" width="540" height="540"></canvas></div>
      <div class="exo-nom">${nom}</div></div>`).join('')}`,
  async init() {
    await Promise.all(EXO_TUILES.map(([f]) => animation(f)));
    // « Exercices » et « 496 animés » se rangent juste à droite du chiffre, quelle que soit sa largeur réelle.
    const x = 64 + $('exo-nombre').offsetWidth + 34, m = $('exo-mot');
    $('exo-droite').style.left = x + 'px';
    // le mot prend toute la place qui reste jusqu'à la marge de droite, sans la dépasser
    m.style.fontSize = Math.min(66, 66 * (1216 - x) / m.offsetWidth) + 'px';
  },
  rendre(l, b, t) {
    // pied 0 : le chiffre claque, le mot le suit
    const n = $('exo-nombre');
    n.style.opacity = borne(l / 0.25);
    n.style.transform = `scale(${lerp(1.14, 1, sortie(l / 0.6)) * pouls(b, 0.02)})`;
    const m = $('exo-mot');
    m.style.opacity = borne((l - 0.15) / 0.35);
    m.style.transform = `translateX(${(1 - sortie((l - 0.15) / 0.7)) * 24}px)`;
    // pieds 1, 2, 3 : une tuile par pied, et le mouvement tourne pour de bon
    EXO_TUILES.forEach(([f], i) => {
      const k = l - (1 + i), e = $('exo-t' + i);
      e.style.opacity = borne(k / 0.3);
      e.style.transform = `translateY(${(1 - rebond(k / 0.6)) * 70}px) scale(${lerp(0.94, 1, sortie(k / 0.6))})`;
      dessiner($('exo-cv' + i), f, t);
    });
    // pied 4 : « 496 animés »
    const a = $('exo-animes'), ka = l - 4;
    a.style.opacity = borne(ka / 0.25);
    a.style.transform = `scale(${lerp(1.18, 1, sortie(ka / 0.6))})`;
  },
});
