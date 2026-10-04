// Les exercices : quatre animations qui tournent pour de bon.
const EXOS_VIDEO = [['bench-press', 'Développé couché'], ['barbell-row', 'Rowing barre'], ['arnold-press', 'Développé Arnold'], ['bulgarian-split-squat', 'Fente bulgare']];
scene({
  id: 'exercices', de: 30, a: 36,
  css: `.exo{position:absolute;width:286px;height:286px;border-radius:30px;background:#131315;box-shadow:0 0 0 1px #2a2a2e,0 30px 60px -20px #000}
    .exo canvas{width:100%;height:100%}.exo b{position:absolute;left:0;right:0;bottom:-44px;text-align:center;font-size:21px;font-weight:500;color:#d8d8de}`,
  html: `<div class="fond"></div>
    <div class="titre" id="exo-titre" style="position:absolute;left:0;right:0;top:54px;text-align:center;font-size:64px">608 exercices</div>
    ${EXOS_VIDEO.map(([f, nom], i) => `<div class="exo" id="exo-${i}" style="left:${38 + i * 306}px;top:214px"><canvas id="exo-cv-${i}" width="480" height="480"></canvas><b>${nom}</b></div>`).join('')}
    <div class="texte" id="exo-sous" style="position:absolute;left:0;right:0;top:618px;text-align:center">496 sont animés. Vingt muscles, tous les matériels.</div>`,
  init: () => Promise.all(EXOS_VIDEO.map(([f]) => animation(f))),
  rendre(l, b, t) {
    $('exo-titre').style.opacity = sortie(l / 1);
    $('exo-sous').style.opacity = borne((l - 1.5) / 0.6);
    EXOS_VIDEO.forEach(([f], i) => {
      const de = 0.4 + i * 0.25;
      $('exo-' + i).style.opacity = borne((l - de) / 0.5);
      $('exo-' + i).style.transform = `translateY(${(1 - sortie((l - de) / 0.9)) * 60}px)`;
      dessiner($('exo-cv-' + i), f, t);
    });
  },
});
