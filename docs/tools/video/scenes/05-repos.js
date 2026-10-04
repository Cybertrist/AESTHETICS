// « Chaque repos. » (temps 20 à 24) : le vrai minuteur de l'appli, recadré sur son anneau et
// ses deux boutons. Un chiffre change sur chaque pied, et tous viennent du clip :
//   temps 0 : 01:13   ·   temps 1 : 01:12   ·   temps 2 : « +10 » → 01:22   ·   temps 3 : 01:21
// On part de 01:13 et non de 01:15 pour que le toucher sur « +10 » tombe juste : 12 + 10 = 22.
(() => {
  // Le recadrage dans le clip (600 × 1334) : l'anneau et les boutons « −10 » et « +10 »,
  // sans le bouton « Arrêter » (rouge). 520 × 770 px du clip sur 396 × 586 px de page,
  // soit 1,14 pixel de sortie par pixel du clip.
  const SX = 40, SY = 322, SL = 520, SH = 770, L = 396, H = 586, K = L / SL;
  // Les images du clip (à partir de 0) où le chiffre bascule, lues une à une sur le clip.
  const I_12 = 73, I_22 = 100, I_21 = 104;
  // Le centre du bouton « +10 » dans le clip, ramené dans le cadre.
  const BX = (384 - SX) * K, BY = (1017 - SY) * K;

  function image(l) {
    if (l < 1) return I_12 - 12 * (1 - l);            // 01:13, à vitesse réelle, jusqu'à la bascule
    if (l < 2) return I_12 + (I_22 - I_12) * (l - 1); // 01:12, jusqu'au toucher
    if (l < 3) return I_22 + (I_21 - I_22) * (l - 2); // 01:22, tenu un temps entier
    return I_21 + 12 * (l - 3);                       // 01:21, à vitesse réelle
  }

  scene({
    id: 'repos', de: 20, a: 24,
    css: `
#rep-cadre{position:relative;width:${L}px;height:${H}px;border-radius:28px;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
#rep-ecran{display:block;width:${L}px;height:${H}px}
#rep-doigt{position:absolute;left:${(BX - 23).toFixed(1)}px;top:${(BY - 23).toFixed(1)}px;width:46px;height:46px;border-radius:50%;background:#fff;opacity:0}
`,
    html: `<div class="fond"></div>
<div class="zone"><div id="rep-cadre">
  <canvas id="rep-ecran" width="${Math.round(L * 1.5)}" height="${Math.round(H * 1.5)}"></canvas>
  <div id="rep-doigt"></div>
</div></div>${motCle('rep', 'Chaque', 'repos.')}`,
    async init() { await clip('repos'); },
    rendre(l) {
      rendreMotCle('rep', l);
      const e = l + 1e-4; // un temps entier tombe toujours du bon côté de la bascule
      const c = CLIPS.repos;
      if (c) {
        const im = c.images[borne(Math.floor(image(e)), 0, c.images.length - 1)];
        const cv = $('rep-ecran'), x = cv.getContext('2d');
        x.imageSmoothingQuality = 'high';
        x.drawImage(im, SX, SY, SL, SH, 0, 0, cv.width, cv.height);
      }
      // Le doigt : il arrive un quart de temps avant le pied, se pose dessus, puis s'efface.
      const d = $('rep-doigt').style;
      d.opacity = e < 1.75 ? 0 : e < 2 ? 0.42 : (0.42 * (1 - borne((e - 2) / 0.4))).toFixed(3);
      d.transform = `scale(${(e < 2 ? lerp(1.5, 1, (e - 1.75) / 0.25) : 1).toFixed(3)})`;
    },
  });
})();
