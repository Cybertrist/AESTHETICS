// Ce qu'on gagne à tenir : la série (la flamme, en semaines), puis les badges.
// Deux idées, une à la fois : temps 0 à 3 la série, temps 3 à 6 les écussons.
// Tout est recadré dans les vraies captures ; leur fond noir se fond dans le
// nôtre (mélange « screen » : le noir disparaît, les couleurs restent).
(() => {
  /// Un détail d'une capture : (x, y, l, h) en pixels de la capture, affiché à l'échelle e.
  const detail = (capture, id, x, y, l, h, e, style) =>
    `<div class="bad-detail" id="${id}" style="width:${l * e}px;height:${h * e}px;${style}">` +
    `<img src="${BRUT}${capture}.png" style="width:${1080 * e}px;left:${-x * e}px;top:${-y * e}px"></div>`;

  // Les six écussons gagnés de la page des badges (centres en pixels de la capture),
  // rangés trois par trois : rouge, doré, vert, puis turquoise, bleu, rose.
  const ECUSSONS = [[220, 499], [861, 499], [220, 929], [540, 929], [861, 929], [861, 1402]];
  const COTE = 244, CASE = 220, PAS = 228, GX = 540, GY = 136;
  const ecussons = ECUSSONS.map(([cx, cy], i) =>
    detail('18-badges', `bad-e${i}`, cx - COTE / 2, cy - COTE / 2, COTE, COTE, CASE / COTE,
      `left:${GX + (i % 3) * PAS}px;top:${GY + Math.floor(i / 3) * PAS}px`)).join('');

  scene({
    id: 'badges', de: 50, a: 56,
    css: `
      .bad-detail{position:absolute;overflow:hidden;mix-blend-mode:screen}
      .bad-detail img{position:absolute}
      .bad-mot{position:absolute;left:80px;top:298px;font-size:60px;white-space:nowrap}
    `,
    html: `<div class="fond"></div>
      ${detail('12e-partage', 'bad-serie', 180, 750, 720, 660, 0.8, 'left:590px;top:96px')}
      <div class="titre bad-mot" id="bad-mot1"><span style="color:#8e8e93">LA</span><br>SÉRIE.</div>
      ${ecussons}
      <div class="titre bad-mot" id="bad-mot2"><span style="color:#8e8e93">LES</span><br>BADGES.</div>`,
    rendre(l, b) {
      // ---- la série : la flamme et son chiffre au temps 0, le mot au temps 1, sortie avant 3
      const part = 1 - borne((l - 2.6) / 0.4);
      const s = $('bad-serie');
      s.style.opacity = borne(l / 0.25) * part;
      s.style.transform = `scale(${lerp(0.8, 1, rebond(l / 0.8)) * pouls(b, 0.025)})`;
      const m1 = $('bad-mot1');
      m1.style.opacity = borne((l - 1) / 0.3) * part;
      m1.style.transform = `translateX(${(1 - sortie((l - 1) / 0.7)) * -60}px)`;

      // ---- les badges : le mot et le premier rang au temps 3, le second rang au temps 4
      const m2 = $('bad-mot2');
      m2.style.opacity = borne((l - 3) / 0.3);
      m2.style.transform = `translateX(${(1 - sortie((l - 3) / 0.7)) * -60}px)`;
      for (let i = 0; i < 6; i++) {
        const d = 3 + Math.floor(i / 3) + (i % 3) * 0.1;   // un rang par temps, léger décalé
        const e = $(`bad-e${i}`);
        e.style.opacity = borne((l - d) / 0.2);
        e.style.transform = `scale(${lerp(0.5, 1, rebond((l - d) / 0.7)) * (l >= 5 ? pouls(b, 0.03) : 1)})`;
      }
    },
  });
})();
