// La scène « semaine » (temps 40 à 44) : la série de l'appli, comptée en semaines.
// Un cadre arrondi de 540 px montre la vraie carte « 27 semaines d'affilée ! » (capture
// 12e-partage, recadrée à 0,75 px de page par pixel de capture), puis bascule au temps 3 sur
// le haut de l'accueil (capture 01-accueil, à 0,5), où la même flamme « 27 » attend chaque jour.
//   temps 0 : la flamme et le 27 sont là ; « CHAQUE » est là
//   temps 1 : « SEMAINE. » frappe
//   temps 2 : « 27 semaines d'affilée. » frappe
//   temps 3 : le cadre bascule sur l'accueil
scene({
  id: 'semaine', de: 40, a: 44,
  css: `
#sem-cadre{position:relative;width:540px;height:540px;border-radius:28px;overflow:hidden;background:#000;box-shadow:0 0 0 1px #2a2a2e}
#sem-cadre img{position:absolute;display:block}
#sem-carte{width:810px;left:-135px;top:-538px}
#sem-accueil{width:540px;left:0;top:-68px}
#sem-mot{display:inline-block}
#sem-sous{transform-origin:left center}
#sem-sous b{font-weight:700;font-variant-numeric:tabular-nums;color:#FF9A00}
`,
  html: `<div class="fond"></div>
<div class="zone"><div id="sem-cadre">
  <img id="sem-carte" src="${BRUT}12e-partage.png">
  <img id="sem-accueil" src="${BRUT}01-accueil.png">
</div></div>
${motCle('sem', 'Chaque', '<span id="sem-mot">semaine.</span>')}
<div class="mc-sous" id="sem-sous"><b>27</b> semaines d’affilée.</div>`,
  rendre(l) {
    rendreMotCle('sem', l);
    const sous = $('sem-sous').style;
    sous.opacity = la(l - 2);
    sous.transform = `scale(${frappe(l - 2).toFixed(4)})`;
    // Temps 3 : la carte laisse la place à l'accueil, d'un coup ; le cadre frappe.
    const accueil = la(l - 3);
    $('sem-carte').style.opacity = 1 - accueil;
    $('sem-accueil').style.opacity = accueil;
    $('sem-cadre').style.transform = `scale(${frappe(l - 3, 0.06).toFixed(4)})`;
  },
});
