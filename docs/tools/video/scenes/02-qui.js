// Scène « qui » (temps 4 à 8) : qui parle, juste avant la confidence. Quatre pieds seuls,
// quatre événements : « 7 » frappe à côté du corps gris ; les pectoraux et les épaules
// s'allument ; « 460 » remplace « 7 » ; les biceps et les cuisses s'allument.
// Le corps est le vrai personnage de l'appli, ses muscles reteints du rouge des muscles travaillés.
scene({
  id: 'qui', de: 4, a: 8,
  css: `
#qui-corps{position:relative;width:263px;height:620px;transform-origin:center center}
#qui-corps img{position:absolute;left:0;top:0;width:100%;height:100%;display:block}
#qui-corps .qui-muscle{filter:url(#rouge)}
.qui-nombre{position:absolute;left:696px;top:188px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:270px;line-height:1;letter-spacing:-6px;font-variant-numeric:tabular-nums;color:#fff;white-space:nowrap;transform-origin:left center}
.qui-quoi{position:absolute;left:704px;top:464px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:40px;line-height:1;letter-spacing:2px;text-transform:uppercase;color:#8e8e93;white-space:nowrap}
`,
  html: `<div class="fond"></div>
<div class="zone"><div id="qui-corps">
  <img src="${CORPS}face_base.webp">
  <img class="qui-muscle" id="qui-pecs" src="${CORPS}face_pectoraux.webp">
  <img class="qui-muscle" id="qui-delts" src="${CORPS}face_deltoidesAnterieurs.webp">
  <img class="qui-muscle" id="qui-biceps" src="${CORPS}face_biceps.webp">
  <img class="qui-muscle" id="qui-quadris" src="${CORPS}face_quadriceps.webp">
</div></div>
<div class="qui-nombre" id="qui-n7">7</div>
<div class="qui-quoi" id="qui-q7">Séances par semaine</div>
<div class="qui-nombre" id="qui-n460">460</div>
<div class="qui-quoi" id="qui-q460">Séances, et plus</div>`,
  rendre(l) {
    const second = la(l - 2); // 0 : « 7 séances par semaine » ; 1 : « 460 séances, et plus »
    // Les chiffres frappent sur les temps 0 et 2 ; leur libellé est là sur la même image.
    $('qui-n7').style.opacity = 1 - second;
    $('qui-n7').style.transform = `scale(${frappe(l, 0.12).toFixed(4)})`;
    $('qui-q7').style.opacity = 1 - second;
    $('qui-n460').style.opacity = second;
    $('qui-n460').style.transform = `scale(${frappe(l - 2, 0.08).toFixed(4)})`;
    $('qui-q460').style.opacity = second;
    // Les muscles s'allument sur les temps 1 et 3, d'un coup ; le corps marque le coup.
    $('qui-pecs').style.opacity = la(l - 1);
    $('qui-delts').style.opacity = la(l - 1);
    $('qui-biceps').style.opacity = la(l - 3);
    $('qui-quadris').style.opacity = la(l - 3);
    const coup = l >= 3 ? frappe(l - 3, 0.03) : frappe(l - 1, 0.03);
    $('qui-corps').style.transform = `scale(${coup.toFixed(4)})`;
  },
});
