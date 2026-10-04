// La scène « record » (temps 24 à 28) : le vrai moment où un record tombe, pris dans le clip
// de la séance et recadré en gros plan. Un événement par pied :
//   0  la ligne de la série passe à l'or (repère « record » du clip), « CHAQUE » est là ;
//   1  « RECORD. » frappe, en or ;
//   2  le cadre bascule sur le bandeau du haut et son écusson « PR » ;
//   3  la valeur du record, reprise du bandeau, s'affiche sous le mot-clé.
// Le clip fait 600 px de large et le cadre 560 : 0,93 px de page par pixel du clip.
(() => {
  const CLIP = 'seance-coches';
  const LARGEUR = 560, HAUTEUR = 392, DENSITE = 1.5;
  const TRANCHE = 420;              // hauteur montrée, en pixels du clip (600 × 420 → 560 × 392)
  const Y_LIGNE = 681;              // les séries É à 4 : trois vertes, le record, la suivante
  const Y_BANDEAU = 68;             // le bandeau du record, les totaux, le nom de l’exercice
  const S_BANDEAU_POSE = 5.3;       // le bandeau est entièrement déployé (il s'ouvre à 5,03 s)

  scene({
    id: 'record', de: 24, a: 28,
    css: `
      #rcd-cadre{position:relative;width:${LARGEUR}px;height:${HAUTEUR}px;border-radius:28px;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
      #rcd-vue{display:block;width:${LARGEUR}px;height:${HAUTEUR}px}
      #rcd-mc2{color:#FFBE0B}
      #rcd-sous{color:#FFBE0B;transform-origin:left center}
      #rcd-sous b{font-weight:700;font-variant-numeric:tabular-nums}
    `,
    html: `<div class="fond"></div>
      <div class="zone"><div id="rcd-cadre"><canvas id="rcd-vue" width="${LARGEUR * DENSITE}" height="${Math.round(HAUTEUR * DENSITE)}"></canvas></div></div>
      ${motCle('rcd', 'Chaque', 'record.')}
      <div class="mc-sous" id="rcd-sous">Charge maximale · <b>80&nbsp;kg</b></div>`,
    async init() { await clip(CLIP); },
    rendre(l) {
      rendreMotCle('rcd', l);
      $('rcd-mc2').style.color = '#FFBE0B';

      // Quelle image du clip, et quelle tranche de l'écran.
      const c = CLIPS[CLIP];
      if (c) {
        const haut = l >= 2 - 1e-6;
        const s = haut
          ? Math.min(S_BANDEAU_POSE + (l - 2) * T, c.duree - 0.05)          // le bandeau, posé
          : c.reperes.record + 0.01 + Math.max(0, l) * T;                    // l = 0 : la ligne passe à l'or
        const im = c.images[borne(Math.floor(s * c.ips), 0, c.images.length - 1)];
        const vue = $('rcd-vue'), x = vue.getContext('2d');
        x.imageSmoothingQuality = 'high';
        x.drawImage(im, 0, haut ? Y_BANDEAU : Y_LIGNE, im.naturalWidth, TRANCHE, 0, 0, vue.width, vue.height);
      }
      // Le cadre frappe à chaque bascule : il est là, entier, sur l'image même du temps.
      $('rcd-cadre').style.transform = `scale(${(l >= 2 - 1e-6 ? frappe(l - 2, 0.02) : frappe(l, 0.02)).toFixed(4)})`;

      const sous = $('rcd-sous').style;
      sous.opacity = la(l - 3);
      sous.transform = `scale(${frappe(l - 3).toFixed(4)})`;
    },
  });
})();
