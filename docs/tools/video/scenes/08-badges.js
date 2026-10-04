// « CHAQUE BADGE. » (temps 32 à 36) : la grille des écussons de la page Badges, rang par rang.
// Une seule idée : un rang d'écussons par pied, puis le compte. La capture 18-badges est
// réduite (500 px de page pour 1080 px de capture), jamais agrandie : les contours restent nets.
(() => {
  const L = 500;                        // largeur du cadre : 500 px de page pour 1080 px de capture
  // Les trois rangs, en px de page dans la capture réduite (haut, bas) : coupes dans le noir
  // entre le bas des libellés d'un rang et le haut des écussons du suivant.
  const RANGS = [[162, 362], [362, 580], [580, 799]];
  const H = RANGS[2][1] - RANGS[0][0];  // 637
  const rang = ([haut, bas], i) =>
    `<div class="bad-rang" id="bad-rang${i}" style="top:${haut - RANGS[0][0]}px;height:${bas - haut}px">` +
    `<img src="${BRUT}18-badges.png" style="top:${-haut}px"></div>`;
  scene({
    id: 'badges', de: 32, a: 36,
    css: `
#bad-cadre{position:relative;width:${L}px;height:${H}px;border-radius:28px;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
.bad-rang{position:absolute;left:0;width:${L}px;overflow:hidden;transform-origin:center center}
.bad-rang img{position:absolute;left:0;width:${L}px;display:block}
#bad-sous b{font-weight:700;font-variant-numeric:tabular-nums;color:#fff}
`,
    html: `<div class="fond"></div>
<div class="zone"><div id="bad-cadre">${RANGS.map(rang).join('')}</div></div>
${motCle('bad', 'Chaque', 'badge.')}
<div class="mc-sous" id="bad-sous"><b>9</b> à paliers, <b>6</b> secrets.</div>`,
    rendre(l) {
      rendreMotCle('bad', l);
      // Temps 0, 1, 2 : un rang de plus, entier sur l'image de son temps, posé en 0,3 temps.
      for (let i = 0; i < 3; i++) {
        const e = $(`bad-rang${i}`).style;
        e.opacity = la(l - i);
        e.transform = `scale(${frappe(l - i, 0.06).toFixed(4)})`;
        e.zIndex = l >= i && l < i + 1 ? 2 : 1;
      }
      // Temps 3 : le compte.
      const s = $('bad-sous').style;
      s.opacity = la(l - 3);
      s.transformOrigin = 'left center';
      s.transform = `scale(${frappe(l - 3, 0.1).toFixed(4)})`;
    },
  });
})();
