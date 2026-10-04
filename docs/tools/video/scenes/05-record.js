// Le record : l'écusson doré « PR » de l'appli claque sur un pied, deux mots,
// et la vraie valeur du record (capture 11b-record-en-seance : « Charge
// maximale · 75 kg »). L'or est la seule couleur.
//   l = 0  « CHAQUE RECORD. » entre ; à gauche, l'empreinte grise de l'écusson attend
//   l = 1  l'écusson tombe dans son empreinte : éclat doré, « RECORD. » passe à l'or
//   l = 2  la valeur du record s'inscrit sous le titre
//   l = 3  un dernier battement, puis la scène s'efface
(() => {
  const HEX = 'M0 -24 L20.8 -12 V12 L0 24 L-20.8 12 V-12 Z';
  // L'écusson de l'appli, repris de ecussonPR (docs/tools/anime.js), autour de (0,0), rayon 24.
  const ECUSSON = `
    <path d="${HEX}" fill="#9A6400" transform="translate(0,2.6)"/>
    <path d="${HEX}" fill="#FFBE0B" stroke="#C98A00" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 -19.5 L16.9 -9.8 V-2 L-16.9 -2 V-9.8 Z" fill="#FFD95A" opacity="0.75"/>
    <path d="M-7 -14 H7 V-9 A7 7 0 0 1 -7 -9 Z M-2 -2.4 H2 V1.6 H-2 Z M-5 1.6 H5 V4.4 H-5 Z" fill="#FFFFFF"/>
    <path d="M-7 -12.4 H-10.4 A4.2 4.2 0 0 0 -6.4 -6.4 M7 -12.4 H10.4 A4.2 4.2 0 0 1 6.4 -6.4" fill="none" stroke="#FFFFFF" stroke-width="1.8"/>
    <text x="0" y="20" text-anchor="middle" font-family="'Space Grotesk',sans-serif" font-size="13" font-weight="700" fill="#FFFFFF" stroke="#8A5A00" stroke-width="2.8" paint-order="stroke" stroke-linejoin="round">PR</text>`;
  const N = 12; // les traits de l'éclat
  const traits = Array.from({ length: N }, (_, i) =>
    `<line id="rcd-trait-${i}" x1="0" y1="0" x2="0" y2="0" stroke="#FFBE0B" stroke-width="1.5" stroke-linecap="round"/>`).join('');

  scene({
    id: 'record', de: 26, a: 30,
    css: `
      #rcd-svg{position:absolute;left:64px;top:74px;width:572px;height:572px;overflow:visible}
      #rcd-mot{position:absolute;left:640px;top:240px;font-size:70px;white-space:nowrap}
      #rcd-valeur{position:absolute;left:643px;top:406px;font-size:34px;font-weight:500;color:#FFBE0B;white-space:nowrap}
    `,
    html: `<div class="fond"></div>
      <svg id="rcd-svg" viewBox="-45 -45 90 90">
        <defs><radialGradient id="rcd-halo-g"><stop offset="0" stop-color="#FFBE0B" stop-opacity=".55"/><stop offset="1" stop-color="#FFBE0B" stop-opacity="0"/></radialGradient></defs>
        <circle id="rcd-halo" r="44" fill="url(#rcd-halo-g)"/>
        <path id="rcd-empreinte" d="${HEX}" fill="none" stroke="#8e8e93" stroke-width=".5" stroke-dasharray="2 2" stroke-linejoin="round"/>
        <path id="rcd-onde" d="${HEX}" fill="none" stroke="#FFBE0B" stroke-linejoin="round"/>
        ${traits}
        <g id="rcd-ecusson">${ECUSSON}</g>
      </svg>
      <div class="titre" id="rcd-mot"><span style="color:#8e8e93">CHAQUE</span><br><span id="rcd-record">RECORD.</span></div>
      <div id="rcd-valeur">Charge maximale · 75&nbsp;kg</div>`,
    rendre(l, b) {
      // le titre entre comme dans les deux scènes d'avant
      $('rcd-mot').style.opacity = borne(l / 0.4);
      $('rcd-mot').style.transform = `translateX(${(1 - sortie(l / 0.8)) * 40}px)`;

      // l'empreinte attend l'écusson, puis disparaît dessous
      $('rcd-empreinte').style.opacity = l < 1 ? 0.75 * borne(l / 0.4) : 0;
      $('rcd-empreinte').setAttribute('transform', `scale(${pouls(b, 0.05)})`);

      // l = 1 : l'écusson tombe de près, dépasse, se pose
      const c = l - 0.75;                    // la chute part un quart de temps avant : l'écusson touche pile sur le pied
      const k = borne(c / 0.3);
      const pose = c < 0.3 ? lerp(2.6, 0.9, entree(k) * 0.4 + k * 0.6) : lerp(0.9, 1, rebond((c - 0.3) / 0.5));
      const bat = c >= 1 ? pouls(b, 0.05) : 1;
      const e = $('rcd-ecusson');
      e.style.opacity = c < 0 ? 0 : borne(c / 0.12);
      e.setAttribute('transform', `rotate(${lerp(-14, 0, sortie(c / 0.4))}) scale(${pose * bat})`);

      // l'éclat : un halo, une onde hexagonale et douze traits qui partent
      const x = borne((c - 0.25) / 1.1);     // part quand l'écusson touche
      const vu = c >= 0.25 ? 1 : 0;
      $('rcd-halo').style.opacity = vu * (0.35 + 0.65 * (1 - sortie(x)));
      $('rcd-halo').setAttribute('transform', `scale(${lerp(0.7, 1, sortie(x))})`);
      $('rcd-onde').style.opacity = vu * (1 - x);
      $('rcd-onde').setAttribute('transform', `scale(${lerp(1, 1.75, sortie(x))})`);
      $('rcd-onde').setAttribute('stroke-width', lerp(1.6, 0.2, x));
      for (let i = 0; i < N; i++) {
        const a = (i / N) * Math.PI * 2 + Math.PI / N, long = i % 2 ? 5 : 9;
        const r1 = lerp(27, 34, sortie(x)), r2 = r1 + long * (1 - entree(x));
        const t = $(`rcd-trait-${i}`);
        t.setAttribute('x1', Math.cos(a) * r1); t.setAttribute('y1', Math.sin(a) * r1);
        t.setAttribute('x2', Math.cos(a) * r2); t.setAttribute('y2', Math.sin(a) * r2);
        t.style.opacity = vu * (1 - entree(x));
      }

      // « RECORD. » passe à l'or au coup
      $('rcd-record').style.color = c >= 0.25 ? '#FFBE0B' : '#fff';

      // l = 2 : la valeur, lue sur la capture
      $('rcd-valeur').style.opacity = borne((l - 2) / 0.3);
      $('rcd-valeur').style.transform = `translateY(${(1 - sortie((l - 2) / 0.5)) * 18}px)`;
    },
  });
})();
