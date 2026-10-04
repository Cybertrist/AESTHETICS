// La récupération, sur le vrai personnage : le corps est le héros. Les muscles
// travaillés sont orange, puis passent au vert un par un, sur les pieds, pendant
// que l'anneau monte de 50 à 100 % (il vire au vert à 90 %, le seuil « prêt »).
const REC_MUSCLES = { face: ['pectoraux', 'deltoidesAnterieurs', 'biceps', 'quadriceps'], dos: ['triceps', 'grandDorsal'] };
// Le temps (local) où chaque muscle passe au vert : pectoraux, épaules, bras
// (biceps de face et triceps de dos ensemble), grand dorsal, quadriceps.
const REC_QUAND = { 'face-0': 2, 'face-1': 3, 'face-2': 4, 'dos-0': 4, 'dos-1': 5, 'face-3': 6 };
const REC_TOUR = 2 * Math.PI * 97;
scene({
  id: 'recuperation', de: 40, a: 48,
  css: `
    .rec-corps{position:absolute;top:36px;width:275px;height:648px}
    .rec-corps img{position:absolute;inset:0;width:100%;height:100%}
    .rec-halo{position:absolute;left:-90px;right:-90px;top:-30px;bottom:-10px;
      background:radial-gradient(50% 46% at 50% 38%,rgba(255,255,255,.13) 0,rgba(255,255,255,.04) 55%,rgba(255,255,255,0) 100%)}
    #rec-titre{position:absolute;left:664px;top:150px;font-size:38px}
    #rec-sous{position:absolute;left:666px;top:250px;font-size:29px;line-height:1.2;color:#a8a8b0}
    #rec-anneau{position:absolute;left:664px;top:340px;overflow:visible}
  `,
  html: `<div class="fond"></div>
    ${['face', 'dos'].map((vue, n) => `<div class="rec-corps" id="rec-${vue}" style="left:${56 + n * 264}px">
      <div class="rec-halo"></div><img src="${CORPS}${vue}_base.webp">
      ${REC_MUSCLES[vue].map((m, k) => `<img src="${CORPS}${vue}_${m}.webp" style="filter:url(#orange)"><img id="rec-${vue}-${k}" src="${CORPS}${vue}_${m}.webp" style="filter:url(#vert);opacity:0">`).join('')}</div>`).join('')}
    <div class="titre" id="rec-titre">La<br>récupération</div>
    <div id="rec-sous">Muscle par muscle.</div>
    <svg id="rec-anneau" width="230" height="230" viewBox="0 0 230 230">
      <circle cx="115" cy="115" r="97" fill="none" stroke="#1d1d20" stroke-width="16"/>
      <circle id="rec-arc" cx="115" cy="115" r="97" fill="none" stroke="#FFA928" stroke-width="16" stroke-linecap="round" transform="rotate(-90 115 115)" stroke-dasharray="0 ${REC_TOUR.toFixed(1)}"/>
      <text id="rec-pct" class="mono" x="115" y="132" text-anchor="middle" font-size="46" font-weight="700" fill="#fff"><tspan id="rec-nb">50</tspan><tspan dx="8">%</tspan></text></svg>`,
  rendre(l) {
    // 0 : le corps de face entre, avec le titre ; 1 : le dos, la ligne et l'anneau.
    for (const [vue, de] of [['face', 0], ['dos', 1]]) {
      const k = sortie((l - de) / 0.9), e = $('rec-' + vue);
      e.style.opacity = borne((l - de) / 0.5);
      e.style.transform = `translateY(${((1 - k) * 46).toFixed(2)}px) scale(${(1.05 - 0.05 * k).toFixed(4)})`;
    }
    const kt = sortie(l / 0.8);
    $('rec-titre').style.opacity = borne(l / 0.4);
    $('rec-titre').style.transform = `translateX(${((1 - kt) * 30).toFixed(2)}px)`;
    const ks = sortie((l - 1) / 0.8);
    $('rec-sous').style.opacity = borne((l - 1) / 0.4);
    $('rec-sous').style.transform = `translateX(${((1 - ks) * 30).toFixed(2)}px)`;

    // Les muscles : un par pied, avec un éclat qui retombe.
    for (const [cle, q] of Object.entries(REC_QUAND)) {
      const e = $('rec-' + cle), f = l >= q ? Math.exp(-(l - q) * 3.2) : 0;
      e.style.opacity = borne((l - q) / 0.22);
      e.style.filter = `url(#vert) brightness(${(1 + 0.85 * f).toFixed(3)}) drop-shadow(0 0 ${(22 * f).toFixed(1)}px rgba(34,216,95,${(0.9 * f).toFixed(3)}))`;
    }

    // L'anneau : 50 % à son arrivée, puis dix points par pied, de 2 à 6.
    const pas = Math.floor(borne(l, 2, 6.999)) - 1;                 // 1 au temps 2 … 5 au temps 6
    const cible = l < 2 ? 50 : 50 + 10 * pas;
    const p = l < 2 ? 50 * sortie((l - 1) / 0.8) : cible - 10 + 10 * sortie((l - (pas + 1)) / 0.4);
    const pret = cible >= 90;
    const f = l >= 2 ? Math.exp(-(l - Math.floor(l)) * 4) : 0;       // l'éclat de chaque pied
    $('rec-anneau').style.opacity = borne((l - 1) / 0.4);
    $('rec-anneau').style.transform = `scale(${(1 + (l >= 6 ? 0.06 : 0.035) * f).toFixed(4)})`;
    $('rec-arc').setAttribute('stroke-dasharray', `${(REC_TOUR * p / 100).toFixed(1)} ${REC_TOUR.toFixed(1)}`);
    $('rec-arc').setAttribute('stroke', pret ? '#22D85F' : '#FFA928');
    $('rec-arc').style.filter = `drop-shadow(0 0 ${(6 + 16 * f).toFixed(1)}px ${pret ? 'rgba(34,216,95,.75)' : 'rgba(255,169,40,.6)'})`;
    $('rec-nb').textContent = Math.round(p);
  },
});
