// Le corps (temps 4 à 8) : le vrai personnage 3D de l'appli, de face et de dos, en grand.
// Aucun texte : sur chaque pied, un groupe de muscles s'allume en rouge, comme dans l'appli.
(() => {
  // [vue, calque, temps local où il s'allume]
  const MUSCLES = [['face', 'pectoraux', 1], ['face', 'deltoidesAnterieurs', 1], ['dos', 'grandDorsal', 2], ['dos', 'triceps', 2],
    ['face', 'biceps', 3], ['face', 'quadriceps', 3]];
  const corps = (vue) => `<div class="cor-corps" id="cor-${vue}"><img src="${CORPS}${vue}_base.webp">
    ${MUSCLES.filter((m) => m[0] === vue).map(([v, m]) => `<img id="cor-${v}-${m}" src="${CORPS}${v}_${m}.webp" style="filter:url(#rouge)">`).join('')}</div>`;
  scene({
    id: 'corps', de: 4, a: 8,
    css: `#cor-duo{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;gap:90px}
      .cor-corps{position:relative;width:271px;height:640px;transform-origin:50% 55%}
      .cor-corps img{position:absolute;left:0;top:0;width:271px;height:640px;display:block}`,
    html: `<div class="fond"></div><div id="cor-duo">${corps('face')}${corps('dos')}</div>`,
    rendre(l) {
      // Temps 0 : les deux corps frappent, gris. Puis un groupe de muscles par pied.
      for (const vue of ['face', 'dos']) {
        const coups = [0, ...MUSCLES.filter((m) => m[0] === vue).map((m) => m[2])];
        const dernier = Math.max(...coups.filter((c) => l >= c - 1e-6));
        $(`cor-${vue}`).style.transform = `scale(${frappe(l - dernier, dernier === 0 ? 0.08 : 0.03).toFixed(4)})`;
      }
      for (const [v, m, quand] of MUSCLES) $(`cor-${v}-${m}`).style.opacity = la(l - quand);
    },
  });
})();
