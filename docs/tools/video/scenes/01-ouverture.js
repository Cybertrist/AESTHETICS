// L'ouverture (temps 0 à 4) : quatre pieds seuls, quatre événements.
//   0  le logo, en grand, frappe au centre (c'est la vignette de la vidéo) ;
//   1  le logo prend sa place définitive, d'un cran ;
//   2  le nom AESTHETICS frappe, sur 1040 px de large ;
//   3  la ligne « MUSCULATION · ANDROID » se pose dessous.
// La plaque finale (logo de 132 px au-dessus du nom de 1040 px, le groupe centré
// verticalement) est celle que la scène de fin reprend : ses cotes sont dans OUV.
const OUV = {
  logo: 132,        // côté du logo posé
  grand: 340,       // côté du logo au temps 0
  rayon: 0.224,     // coins arrondis, en part du côté (ceux de l'icône elle-même)
  largeur: 1040,    // largeur visible du nom
  inter: 4,         // interlettrage du nom, fixe
  ecart: 44,        // du bas du logo au haut des capitales
  // réglés dans init, d'après la police réellement chargée (valeurs de secours ici)
  corps: 118, x: 120, haut: 226, base: 486,
};
scene({
  id: 'ouverture', de: 0, a: 4,
  css: `
#ouv-logo{position:absolute;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
#ouv-logo img{display:block;width:100%;height:100%}
#ouv-nom{position:absolute;left:0;top:0;width:1280px;height:720px;transform-origin:640px 440px}
#ouv-nom text{font-family:Syne,sans-serif;font-weight:800;fill:#fff;letter-spacing:4px}
#ouv-ligne{position:absolute;left:0;width:1280px;text-align:center;font-size:32px;line-height:32px;font-weight:500;
  letter-spacing:10px;padding-left:10px;color:#8e8e93;text-transform:uppercase;white-space:nowrap;transform-origin:640px 16px}
`,
  html: `<div class="fond"></div>
<div id="ouv-logo"><img src="${LOGO}" alt=""></div>
<svg id="ouv-nom" viewBox="0 0 1280 720"><text id="ouv-mot" x="120" y="486" font-size="118">AESTHETICS</text></svg>
<div id="ouv-ligne">Musculation · Android</div>`,
  async init() {
    // La police fixe la taille : le nom doit faire 1040 px d'encre, avec 4 px entre les lettres.
    const x = document.createElement('canvas').getContext('2d');
    x.font = `800 200px Syne`;
    const m = x.measureText('AESTHETICS');
    const encre = m.actualBoundingBoxLeft + m.actualBoundingBoxRight; // à 200 px, sans interlettrage
    const hauteur = x.measureText('H').actualBoundingBoxAscent;       // hauteur des capitales à 200 px
    if (encre > 0 && hauteur > 0) {
      OUV.corps = (OUV.largeur - 9 * OUV.inter) / encre * 200;
      const k = OUV.corps / 200, capitale = hauteur * k;
      OUV.x = (1280 - OUV.largeur) / 2 + m.actualBoundingBoxLeft * k;
      OUV.haut = Math.round(360 - (OUV.logo + OUV.ecart + capitale) / 2);
      OUV.base = OUV.haut + OUV.logo + OUV.ecart + capitale;
    }
    const mot = $('ouv-mot');
    mot.setAttribute('font-size', OUV.corps.toFixed(2));
    mot.setAttribute('x', OUV.x.toFixed(2));
    mot.setAttribute('y', OUV.base.toFixed(2));
    $('ouv-nom').style.transformOrigin = `640px ${(OUV.base - (OUV.base - OUV.haut - OUV.logo - OUV.ecart) / 2).toFixed(1)}px`;
    $('ouv-ligne').style.top = `${Math.round(OUV.base + 40)}px`;
  },
  rendre(l) {
    // Le logo : grand et centré au temps 0, puis à sa place d'un cran au temps 1.
    const pose = l >= 1 - 1e-6;
    const cote = (pose ? OUV.logo * frappe(l - 1) : OUV.grand * frappe(l));
    const cy = pose ? OUV.haut + OUV.logo / 2 : 360;
    const g = $('ouv-logo').style;
    g.width = g.height = `${cote.toFixed(2)}px`;
    g.left = `${(640 - cote / 2).toFixed(2)}px`;
    g.top = `${(cy - cote / 2).toFixed(2)}px`;
    g.borderRadius = `${(cote * OUV.rayon).toFixed(2)}px`;
    // Le nom : là, entier, sur l'image du temps 2. Un excès contenu : il reste à plus de 64 px des bords.
    const n = $('ouv-nom').style;
    n.opacity = la(l - 2);
    n.transform = `scale(${frappe(l - 2, 0.08).toFixed(4)})`;
    // La ligne du dessous, au temps 3.
    const s = $('ouv-ligne').style;
    s.opacity = la(l - 3);
    s.transform = `scale(${frappe(l - 3, 0.1).toFixed(4)})`;
  },
});
