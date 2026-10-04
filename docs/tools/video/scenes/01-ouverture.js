// L'ouverture : quatre pieds pour le logo, seul et en grand, puis quatre pour le nom.
// Temps 0 : le logo s'écrase au centre sous l'éclair, une onde part à chaque pied.
// Temps 4 : il monte, AESTHETICS frappe sur toute la largeur, puis tout se pose.
(() => {
  const NOM_LARGEUR = 1120;  // largeur finale du nom, en px (80 px de marge de chaque côté)
  const ESPACE_DEBUT = 2, ESPACE_FIN = 12; // l'espacement des lettres s'ouvre lentement
  const LOGO_COTE = 150, LOGO_HAUT = 196;  // le logo une fois rangé au-dessus du nom
  const NOM_CENTRE = 462;                  // le milieu vertical du nom
  const GRAND = 1.72;                      // le logo seul, au centre de l'image
  const DESCENTE = 360 - (LOGO_HAUT + LOGO_COTE / 2);
  let corps = 88;                          // recalculé dans init, polices chargées

  scene({
    id: 'ouverture', de: 0, a: 8,
    css: `
      .ouv-pose{position:absolute;left:${640 - LOGO_COTE / 2}px;top:${LOGO_HAUT}px;width:${LOGO_COTE}px;height:${LOGO_COTE}px;border-radius:${LOGO_COTE * 0.232}px}
      #ouv-halo{position:absolute;left:240px;top:${LOGO_HAUT + LOGO_COTE / 2 - 400}px;width:800px;height:800px;
        background:radial-gradient(closest-side,rgba(255,255,255,.34) 0,rgba(255,255,255,.10) 38%,rgba(255,255,255,0) 100%)}
      .ouv-onde{border:2px solid #fff}
      #ouv-logo{display:block;box-shadow:0 0 0 1px rgba(255,255,255,.22)}
      #ouv-trait{position:absolute;left:0;top:${NOM_CENTRE - 1}px;width:1280px;height:2px;
        background:linear-gradient(90deg,rgba(255,255,255,0) 0,#fff 50%,rgba(255,255,255,0) 100%)}
      #ouv-nom{position:absolute;left:0;top:${NOM_CENTRE - 80}px;width:1280px;height:160px;
        display:flex;align-items:center;justify-content:center;white-space:nowrap;color:#fff;line-height:1}
    `,
    html: `<div class="fond"></div>
      <div id="ouv-halo"></div>
      <div class="ouv-pose ouv-onde" id="ouv-onde1"></div>
      <div class="ouv-pose ouv-onde" id="ouv-onde2"></div>
      <img class="ouv-pose" id="ouv-logo" src="${LOGO}">
      <div id="ouv-trait"></div>
      <div class="titre" id="ouv-nom"><span id="ouv-mot">AESTHETICS</span></div>`,
    async init() {
      // Le nom occupe exactement NOM_LARGEUR à son espacement final, quelle que soit la chasse de Syne.
      const mot = $('ouv-mot');
      mot.style.fontSize = '100px';
      mot.style.letterSpacing = '0px';
      const cent = mot.getBoundingClientRect().width;
      if (cent > 0) corps = Math.floor(((NOM_LARGEUR - 9 * ESPACE_FIN) / cent) * 1000) / 10;
    },
    rendre(l, b) {
      const pied = l - Math.floor(l);                     // 0 juste sur le pied, 1 juste avant le suivant
      const k = sortie((l - 4) / 0.6);                    // 0 : logo seul au centre ; 1 : logo rangé
      const calme = borne((l - 4) / 3.5);                 // les battements s'éteignent vers la fin

      // Le logo : il tombe de très près au temps 0, bat à chaque pied, puis monte au temps 4.
      const chute = lerp(2.3, 1, sortie(l / 0.55));
      const battement = pouls(b, lerp(0.06, 0, calme));
      const echelle = lerp(GRAND, 1, k) * chute * battement;
      const dy = lerp(DESCENTE, 0, k);
      const logo = $('ouv-logo');
      logo.style.transform = `translateY(${dy}px) scale(${echelle})`;
      logo.style.opacity = 1;

      // Deux ondes : celle du pied en cours, et la queue de celle du pied d'avant.
      const onde = (el, age, n) => {
        const vivante = n >= 0 && n < 4 && age < 1.6;
        const p = borne(age / 1.6);
        el.style.transform = `translateY(${DESCENTE}px) scale(${GRAND * (1 + 1.5 * sortie(p))})`;
        el.style.opacity = vivante ? (n === 0 ? 0.6 : 0.42) * Math.pow(1 - p, 2) : 0;
        el.style.borderWidth = `${2 / (1 + 1.5 * sortie(p))}px`;
      };
      const n = Math.floor(l);
      // chaque élément garde les pieds de même parité : aucune onde ne saute d'un élément à l'autre
      const pair = n % 2 === 0 ? n : n - 1, impair = n % 2 === 1 ? n : n - 1;
      onde($('ouv-onde1'), l - pair, pair);
      onde($('ouv-onde2'), l - impair, impair);

      // Le halo : il s'allume à chaque pied derrière le logo, puis reste bas.
      const halo = $('ouv-halo');
      const eclat = Math.exp(-pied * 3.2);
      halo.style.transform = `translateY(${dy}px) scale(${lerp(1.25, 0.8, k) * (1 + 0.1 * eclat * (1 - calme))})`;
      halo.style.opacity = lerp(0.3 + 0.7 * eclat, 0.5, calme);

      // Le nom : il frappe au temps 4, un peu trop grand, puis ses lettres s'écartent lentement.
      const a = l - 4;
      const nom = $('ouv-nom'), mot = $('ouv-mot');
      const espace = lerp(ESPACE_DEBUT, ESPACE_FIN, sortie(a / 4));
      mot.style.fontSize = `${corps}px`;
      mot.style.letterSpacing = `${espace}px`;
      mot.style.marginRight = `${-espace}px`;            // l'espace après le S ne décentre pas le mot
      nom.style.opacity = a < 0 ? 0 : borne(a / 0.1);
      nom.style.transform = `scale(${lerp(1.22, 1, sortie(a / 0.5))})`;
      const lueur = a < 0 ? 0 : 0.12 + 0.6 * Math.exp(-a * 2.2);
      nom.style.textShadow = `0 0 ${lerp(60, 34, borne(a / 2))}px rgba(255,255,255,${lueur.toFixed(3)})`;

      // Un trait de lumière part du centre sous le coup du temps 4 et s'efface aussitôt.
      const trait = $('ouv-trait');
      trait.style.transform = `scaleX(${lerp(0.15, 1, sortie(a / 0.7))}) scaleY(${lerp(3, 1, borne(a / 0.7))})`;
      trait.style.opacity = a < 0 ? 0 : 0.9 * Math.pow(1 - borne(a / 0.8), 2);
    },
  });
})();
