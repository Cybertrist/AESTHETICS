// La scène « mois » (temps 44 à 52) : le résumé mensuel, feuilleté comme une story.
// Le vrai clip `resume` dans un téléphone droit ; une page pleine par pied, sans fondu :
// on saute d'une page entièrement affichée à la suivante sur l'image même du temps.
// Au temps 3, le téléphone cède la place à un gros plan de la page des camions de pompiers
// (la capture de 1080 px, plus nette que le clip) ; au temps 4, quand le thème repart,
// le téléphone revient sur la toile des muscles et « Dix pages. » frappe.
(() => {
  // Temps local → page du clip montrée (repère de `clip.json`). Le temps 3 garde la page 5
  // sous le gros plan.
  const PAGES = ['page1', 'page3', 'page5', 'page5', 'page7', 'page8', 'page9', 'page10'];
  // Chaque page entre en fondu pendant 0,25 s environ : on la montre 0,45 s après son repère,
  // pleinement affichée, et bien avant le fondu de la suivante.
  const PLEINE = 0.45;
  // Le gros plan : la capture 16e (1080 × 2400), recadrée sur x 60…1020, y 840…1840,
  // à 0,5625 px de page par pixel de capture (0,84 px de sortie : net).
  const K = 540 / 960;

  scene({
    id: 'mois', de: 44, a: 52,
    css: `
#moi-tel{left:120.7px;top:5px;transform-origin:center center}
#moi-plan{position:absolute;left:10px;top:39px;width:540px;height:${(1000 * K).toFixed(1)}px;overflow:hidden;
  border-radius:28px;box-shadow:0 0 0 1px #2a2a2e;background:#000;transform-origin:center center}
#moi-plan img{position:absolute;left:${(-60 * K).toFixed(2)}px;top:${(-840 * K).toFixed(2)}px;width:${(1080 * K).toFixed(2)}px;display:block}
#moi-sous{transform-origin:left center}
`,
    html: `<div class="fond"></div>
<div class="zone">
  ${telClip('', 300, 'moi-ecran', 'moi-tel')}
  <div id="moi-plan"><img src="${BRUT}16e-resume-comparaison.png" alt=""></div>
</div>
${motCle('moi', 'Chaque', 'mois.')}
<div class="mc-sous" id="moi-sous">Dix pages.</div>`,
    async init() { await clip('resume'); },
    rendre(l) {
      rendreMotCle('moi', l);
      const pied = borne(Math.floor(l + 1e-6), 0, PAGES.length - 1); // le pied en cours
      const depuis = l - pied;                                       // temps écoulé depuis ce pied
      const plan = pied === 3;

      // Le téléphone : la page du pied en cours, figée à son instant plein.
      dessinerClip($('moi-ecran'), 'resume', CLIPS.resume ? CLIPS.resume.reperes[PAGES[pied]] + PLEINE : 0);
      const tel = $('moi-tel').style;
      tel.opacity = plan ? 0 : 1;
      // Un léger sursaut à chaque changement de page (pas au temps 0 : la scène s'ouvre posée).
      tel.transform = `scale(${(pied > 0 ? frappe(depuis, 0.03) : 1).toFixed(4)})`;

      // Le gros plan : là au temps 3, parti au temps 4.
      const p = $('moi-plan').style;
      p.opacity = plan ? 1 : 0;
      p.transform = `scale(${(plan ? frappe(depuis, 0.04) : 1).toFixed(4)})`;

      // « Dix pages. » : frappe à la reprise du thème.
      const s = $('moi-sous').style;
      s.opacity = la(l - 4);
      s.transform = `scale(${frappe(l - 4).toFixed(4)})`;
    },
  });
})();
