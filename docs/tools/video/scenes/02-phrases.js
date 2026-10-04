// Les deux phrases de Tristan, sur la respiration de la musique.
//
// La première se dit calmement, mot après mot, sur la nappe (temps 0 à 4).
// La seconde frappe : trois blocs, un par temps, chacun en très grand et
// seul à l'écran (« C'EST LE MOMENT », « D'ATTEINDRE », « MES OBJECTIFS. »),
// le dernier tenu et tremblant sur le roulement, jusqu'à la bascule.
(() => {
  const MOTS = ['Je', 'me', 'suis', 'toujours', 'senti', 'mal', 'dans', 'mon', 'corps.'];
  const COUPE = 6; // « Je me suis toujours senti mal / dans mon corps. »
  const BLOCS = [['C’EST LE MOMENT', 4], ['D’ATTEINDRE', 5], ['MES OBJECTIFS.', 6]];
  const LARGEUR = 1080; // la place d'un bloc, entre deux marges de 100 px
  const mot = (m, k) => `<span id="phr-m${k}" style="display:inline-block;margin:0 0.14em">${m}</span>`;
  scene({
    id: 'phrases', de: 8, a: 16,
    css: `
      #phr-une{position:absolute;left:0;right:0;top:268px;text-align:center;font-size:60px;font-weight:500;line-height:1.3}
      .phr-bloc{position:absolute;left:0;right:0;top:0;bottom:0;display:flex;align-items:center;justify-content:center;white-space:nowrap}
      #phr-lueur{position:absolute;inset:0;background:radial-gradient(50% 60% at 50% 50%,#ffffff 0,transparent 70%)}`,
    html: `<div id="phr-lueur"></div>
      <div id="phr-une">${MOTS.slice(0, COUPE).map(mot).join('')}<br>${MOTS.slice(COUPE).map((m, k) => mot(m, k + COUPE)).join('')}</div>
      ${BLOCS.map(([texte], i) => `<div class="phr-bloc titre" id="phr-b${i}"><span id="phr-t${i}">${texte}</span></div>`).join('')}`,
    async init() {
      // Chaque bloc prend toute la largeur : son corps est mesuré une fois Syne chargée.
      BLOCS.forEach((x, i) => {
        const e = $(`phr-t${i}`);
        e.style.fontSize = '100px';
        e.style.fontSize = `${Math.min(150, (LARGEUR / e.getBoundingClientRect().width) * 100).toFixed(1)}px`;
      });
    },
    rendre(l) {
      // La première phrase : un mot tous les tiers de temps, puis elle s'efface avant la montée.
      const part = 1 - borne((l - 3.4) / 0.5);
      MOTS.forEach((m, k) => {
        const q = sortie((l - 0.15 - k * 0.3) / 0.7), e = $(`phr-m${k}`).style;
        e.opacity = q * part;
        e.transform = `translateY(${(1 - q) * 18}px)`;
      });
      $('phr-une').style.transform = `translateY(${-(1 - part) * 14}px)`;

      // La seconde : un bloc par temps, qui claque en grand puis laisse la place.
      BLOCS.forEach(([, de], i) => {
        const fin = i + 1 < BLOCS.length ? BLOCS[i + 1][1] : 99;
        const vu = l >= de && l < fin;
        const k = sortie((l - de) / 0.35);
        // Le dernier bloc tient deux temps : il grossit et tremble avec le roulement.
        const tenue = i === BLOCS.length - 1 ? borne((l - de) / 2) : 0;
        const pas = l < 7 ? 0.25 : 0.125, coup = Math.floor(l / pas);
        const dx = tenue * 5 * Math.sin(coup * 12.9898), dy = tenue * 5 * Math.sin(coup * 78.233);
        const e = $(`phr-b${i}`).style;
        e.opacity = vu ? borne((l - de) / 0.08) : 0;
        e.transform = `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${(lerp(1.28, 1, k) * (1 + 0.08 * tenue)).toFixed(4)})`;
      });
      // Une lueur qui monte avec le bruit, jusqu'à l'éclair du plein.
      $('phr-lueur').style.opacity = 0.16 * entree((l - 4) / 4);
    },
  });
})();
