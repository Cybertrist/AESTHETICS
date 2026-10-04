// La récupération, sur le vrai personnage : les muscles passent de l'orange au vert.
const RECUP_MUSCLES = { face: ['pectoraux', 'deltoidesAnterieurs', 'biceps', 'quadriceps'], dos: ['triceps', 'grandDorsal'] };
scene({
  id: 'recuperation', de: 36, a: 44,
  css: `.corps{position:absolute;width:300px;height:660px}.corps img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}`,
  html: `<div class="fond"></div>
    ${['face', 'dos'].map((vue, n) => `<div class="corps" id="rec-${vue}" style="left:${60 + n * 290}px;top:36px"><img src="${CORPS}${vue}_base.webp">
      ${RECUP_MUSCLES[vue].map((m, k) => `<img src="${CORPS}${vue}_${m}.webp" style="filter:url(#orange)"><img id="rec-${vue}-${k}" src="${CORPS}${vue}_${m}.webp" style="filter:url(#vert);opacity:0">`).join('')}</div>`).join('')}
    <div class="titre" id="rec-titre" style="position:absolute;left:690px;top:166px;font-size:37px">La<br>récupération</div>
    <div class="texte" id="rec-sous" style="position:absolute;left:694px;top:290px">Muscle par muscle.<br>De l’orange au vert.</div>
    <svg id="rec-anneau" style="position:absolute;left:694px;top:410px" width="170" height="170" viewBox="0 0 170 170">
      <circle cx="85" cy="85" r="70" fill="none" stroke="#1d1d20" stroke-width="14"/>
      <circle id="rec-arc" cx="85" cy="85" r="70" fill="none" stroke="#22D85F" stroke-width="14" stroke-linecap="round" transform="rotate(-90 85 85)" stroke-dasharray="0 440"/>
      <text id="rec-pct" x="85" y="98" text-anchor="middle" font-family="Space Grotesk" font-size="38" font-weight="700" fill="#fff">0 %</text></svg>`,
  rendre(l) {
    for (const [vue, de] of [['face', 0], ['dos', 0.5]]) {
      const k = sortie((l - de) / 1.2);
      $('rec-' + vue).style.opacity = k; $('rec-' + vue).style.transform = `translateY(${(1 - k) * 50}px)`;
    }
    $('rec-titre').style.opacity = borne((l - 1) / 0.5); $('rec-sous').style.opacity = borne((l - 1.6) / 0.5);
    $('rec-anneau').style.opacity = borne((l - 2) / 0.5);
    const p = Math.round(33 + 67 * borne((l - 2.2) / 4.6));
    $('rec-arc').setAttribute('stroke-dasharray', `${(440 * p / 100).toFixed(1)} 440`);
    $('rec-arc').setAttribute('stroke', p >= 90 ? '#22D85F' : '#FFA928');
    $('rec-pct').textContent = `${p} %`;
    const SEUILS = { 'face-0': 5.6, 'face-1': 3.8, 'face-2': 3.2, 'face-3': 6.2, 'dos-0': 3.8, 'dos-1': 3.2 };
    for (const [cle, quand] of Object.entries(SEUILS)) $('rec-' + cle).style.opacity = borne((l - quand) / 0.6);
  },
});
