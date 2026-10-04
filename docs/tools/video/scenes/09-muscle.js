// « Chaque muscle. » (temps 36 à 40) : la récupération, muscle par muscle, sur le vrai
// personnage. L'état est celui de la page Récupération de l'appli : pectoraux, épaules et
// triceps récupèrent (orange) ; grand dorsal, biceps et quadriceps sont prêts (vert).
// Un événement par pied : les corps gris, l'orange, le vert, la légende.
(() => {
  // Les calques, dans l'ordre où ils s'allument : [vue, muscle, teinte, temps].
  const CALQUES = [
    ['face', 'pectoraux', 'orange', 1],
    ['face', 'deltoidesAnterieurs', 'orange', 1],
    ['dos', 'triceps', 'orange', 1],
    ['dos', 'grandDorsal', 'vert', 2],
    ['face', 'biceps', 'vert', 2],
    ['face', 'quadriceps', 'vert', 2],
  ];
  const corps = (vue) =>
    `<div class="mus-corps"><img src="${CORPS}${vue}_base.webp">${CALQUES.filter((c) => c[0] === vue)
      .map(([v, m, teinte]) => `<img id="mus-${v}-${m}" src="${CORPS}${v}_${m}.webp" style="filter:url(#${teinte})">`)
      .join('')}</div>`;
  // La pastille est un morceau du calque lui-même, reteint par le même filtre : sa couleur est
  // donc exactement celle des muscles d'à côté.
  const ligne = (id, teinte, top, texte) =>
    `<div class="mc-sous mus-ligne" id="${id}" style="top:${top}px"><i class="mus-pastille" style="filter:url(#${teinte})"></i>${texte}</div>`;

  scene({
    id: 'muscle', de: 36, a: 40,
    css: `
.mus-duo{display:flex;gap:18px;width:560px;height:640px}
.mus-corps{position:relative;width:271px;height:640px}
.mus-corps img{position:absolute;left:0;top:0;width:271px;height:640px;display:block}
.mus-ligne{display:flex;align-items:center;gap:14px;transform-origin:left center}
.mus-pastille{display:block;width:22px;height:22px;border-radius:50%;flex:none;
  background:url(${CORPS}face_pectoraux.webp) -89px -132px/271px 640px no-repeat}
`,
    html: `<div class="fond"></div>
<div class="zone"><div class="mus-duo">${corps('face')}${corps('dos')}</div></div>
${motCle('mus', 'Chaque', 'muscle.')}
${ligne('mus-l1', 'orange', 444, 'Orange&nbsp;: il récupère.')}
${ligne('mus-l2', 'vert', 490, 'Vert&nbsp;: il est prêt.')}`,
    rendre(l) {
      rendreMotCle('mus', l);
      // temps 1 : l'orange ; temps 2 : le vert. Là d'un coup, à peine trop grand, posé en 0,3 temps.
      for (const [v, m, , quand] of CALQUES) {
        const e = $(`mus-${v}-${m}`).style;
        e.opacity = la(l - quand);
        e.transform = `scale(${frappe(l - quand, 0.03).toFixed(4)})`;
      }
      // temps 3 : la légende, les deux lignes ensemble.
      for (const id of ['mus-l1', 'mus-l2']) {
        const e = $(id).style;
        e.opacity = la(l - 3);
        e.transform = `scale(${frappe(l - 3, 0.08).toFixed(4)})`;
      }
    },
  });
})();
