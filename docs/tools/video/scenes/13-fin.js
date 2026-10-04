// La fin (temps 56 à 64) : le dernier coup pose la plaque de l'ouverture, logo et nom
// ensemble ; la devise suit, un membre par temps ; puis ce qu'il faut savoir et l'adresse.
// Du temps 5 au temps 8 plus rien ne bouge : c'est l'image sur laquelle la vidéo s'arrête.
// Toutes les lignes occupent leur place dès le début (seule leur opacité change) : le groupe
// est centré pour son état final et rien ne se décale quand une ligne apparaît.
const FIN_LARGEUR_NOM = 1040; // largeur du nom, du bord du A au bord du S
const FIN_INTERLETTRE = 4;
scene({
  id: 'fin', de: 56, a: 64,
  css: `
#fin-groupe{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
#fin-plaque{display:flex;flex-direction:column;align-items:center;transform-origin:50% 50%}
#fin-logo{display:block;width:132px;height:132px;border-radius:30px;box-shadow:0 0 0 1px #2a2a2e}
#fin-nom{margin-top:26px;margin-right:-${FIN_INTERLETTRE}px;font-family:Syne,sans-serif;font-weight:800;font-size:128px;line-height:1;letter-spacing:${FIN_INTERLETTRE}px;text-transform:uppercase;white-space:nowrap;color:#fff}
#fin-devise{margin-top:30px;font-size:42px;line-height:1.1;white-space:nowrap;color:#8e8e93;font-weight:500}
#fin-devise span{display:inline-block;transform-origin:50% 50%}
#fin-devise b{font-weight:700;color:#fff}
#fin-faits{margin-top:40px;margin-right:-6px;font-size:30px;line-height:1.1;font-weight:500;letter-spacing:6px;text-transform:uppercase;white-space:nowrap;color:#fff;transform-origin:50% 50%}
#fin-adresse{margin-top:22px;font-size:30px;line-height:1.1;font-weight:500;white-space:nowrap;color:#8e8e93;transform-origin:50% 50%}
`,
  html: `<div class="fond"></div>
<div id="fin-groupe">
  <div id="fin-plaque"><img id="fin-logo" src="${LOGO}" alt=""><div id="fin-nom">AESTHETICS</div></div>
  <div id="fin-devise"><span id="fin-d1">Chaque <b>série.</b></span>&nbsp;&nbsp;<span id="fin-d2">Chaque <b>record.</b></span>&nbsp;&nbsp;<span id="fin-d3">Chaque <b>progrès.</b></span></div>
  <div id="fin-faits">Android · Hors ligne · Aucun compte</div>
  <div id="fin-adresse" class="mono">github.com/Cybertrist/AESTHETICS</div>
</div>`,
  async init() {
    // Syne est très large : on mesure le nom à 100 px et on règle la taille pour que les
    // lettres couvrent exactement FIN_LARGEUR_NOM (l'interlettrage qui suit le S ne compte pas).
    await document.fonts.load('800 100px Syne', 'AESTHETICS');
    const nom = $('fin-nom');
    nom.style.fontSize = '100px';
    const l100 = nom.getBoundingClientRect().width; // dix lettres + dix interlettrages
    const parEm = (l100 - 10 * FIN_INTERLETTRE) / 100;
    nom.style.fontSize = `${((FIN_LARGEUR_NOM - 9 * FIN_INTERLETTRE) / parEm).toFixed(2)}px`;
  },
  rendre(l) {
    // 0 : le dernier coup. Logo et nom frappent ensemble (excès réduit : le nom reste dans les marges).
    const plaque = $('fin-plaque').style;
    plaque.opacity = 1;
    plaque.transform = `scale(${frappe(l, 0.08).toFixed(4)})`;
    // 1, 2, 3 : la devise, un membre par temps ; 4 : les faits ; 5 : l'adresse.
    const pose = (id, quand, exces) => {
      const e = $(id).style;
      e.opacity = la(l - quand);
      e.transform = `scale(${frappe(l - quand, exces).toFixed(4)})`;
    };
    pose('fin-d1', 1, 0.1);
    pose('fin-d2', 2, 0.1);
    pose('fin-d3', 3, 0.1);
    pose('fin-faits', 4, 0.06);
    pose('fin-adresse', 5, 0.06);
  },
});
