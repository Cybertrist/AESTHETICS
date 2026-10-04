// L'ouverture (temps 0 à 8) : huit pieds seuls dans la musique, et rien d'autre à l'écran que le
// logo et le nom. Le logo arrive énorme et se resserre d'un cran par pied jusqu'à sa place ; le
// nom frappe ; la ligne se pose en deux fois ; la plaque entière marque le dernier pied.
// La plaque finale (logo de 132 px au-dessus du nom) est exactement celle de la page de fin.
(() => {
  const LARGEUR_NOM = 1040, INTERLETTRE = 4;
  const TAILLES = [360, 264, 190, 132]; // le côté du logo aux temps 0, 1, 2 et 3
  let place = { x: 640, y: 300 };       // le centre du logo dans la plaque, mesuré dans init
  scene({
    id: 'ouverture', de: 0, a: 8,
    css: `
#ouv-groupe{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;transform-origin:50% 50%}
#ouv-place{width:132px;height:132px}
#ouv-nom{margin-top:26px;margin-right:-${INTERLETTRE}px;font-family:Syne,sans-serif;font-weight:800;font-size:128px;line-height:1;letter-spacing:${INTERLETTRE}px;text-transform:uppercase;white-space:nowrap;color:#fff;transform-origin:50% 50%}
#ouv-ligne{margin-top:34px;margin-right:-10px;font-size:32px;line-height:1.1;font-weight:500;letter-spacing:10px;text-transform:uppercase;white-space:nowrap;color:#8e8e93}
#ouv-logo{position:absolute;display:block;box-shadow:0 0 0 1px #2a2a2e}`,
    html: `<div class="fond"></div>
<div id="ouv-groupe">
  <div id="ouv-place"></div>
  <div id="ouv-nom">AESTHETICS</div>
  <div id="ouv-ligne"><span id="ouv-l1">Musculation</span><span id="ouv-l2"> · Android</span></div>
</div>
<img id="ouv-logo" src="${LOGO}" alt="">`,
    async init() {
      await document.fonts.load('800 100px Syne', 'AESTHETICS');
      const nom = $('ouv-nom');
      nom.style.fontSize = '100px';
      const parEm = (nom.getBoundingClientRect().width - 10 * INTERLETTRE) / 100;
      nom.style.fontSize = `${((LARGEUR_NOM - 9 * INTERLETTRE) / parEm).toFixed(2)}px`;
      const r = $('ouv-place').getBoundingClientRect();
      place = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    },
    rendre(l) {
      // 0, 1, 2, 3 : le logo, d'un cran par pied, du centre de l'image à sa place dans la plaque.
      const k = Math.min(3, Math.max(0, Math.floor(l + 1e-6)));
      const cote = TAILLES[k] * frappe(l - k, 0.07);
      const cx = k < 3 ? 640 : place.x, cy = k < 3 ? 360 : place.y;
      const logo = $('ouv-logo').style;
      logo.width = `${cote.toFixed(2)}px`; logo.height = `${cote.toFixed(2)}px`;
      logo.left = `${(cx - cote / 2).toFixed(2)}px`; logo.top = `${(cy - cote / 2).toFixed(2)}px`;
      logo.borderRadius = `${(cote * 0.227).toFixed(2)}px`;
      // 4 : le nom. 5 : « Musculation ». 6 : « · Android ». 7 : la plaque entière marque le pied.
      const nom = $('ouv-nom').style;
      nom.opacity = la(l - 4); nom.transform = `scale(${frappe(l - 4, 0.07).toFixed(4)})`;
      $('ouv-l1').style.opacity = la(l - 5);
      $('ouv-l2').style.opacity = la(l - 6);
      $('ouv-groupe').style.transform = `scale(${frappe(l - 7, 0.04).toFixed(4)})`;
      if (l >= 7 - 1e-6) { const f = frappe(l - 7, 0.04); logo.transform = `translate(${((place.x - 640) * (f - 1)).toFixed(2)}px, ${((place.y - 360) * (f - 1)).toFixed(2)}px) scale(${f.toFixed(4)})`; } else logo.transform = 'none';
    },
  });
})();
