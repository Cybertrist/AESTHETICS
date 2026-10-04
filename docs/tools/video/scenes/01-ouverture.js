// L'ouverture : le logo tombe, le nom s'écrit lettre à lettre.
scene({
  id: 'ouverture', de: 0, a: 8,
  html: `<div class="fond"></div><div class="c">
    <img id="ouv-logo" src="${LOGO}" style="width:190px;height:190px;border-radius:44px;box-shadow:0 0 0 1px #ffffff30,0 0 90px #ffffff30">
    <div class="titre" id="ouv-nom" style="font-size:112px;margin-top:44px;letter-spacing:2px">AESTHETICS</div></div>`,
  rendre(l, b) {
    $('ouv-logo').style.transform = `scale(${rebond(l / 1.5) * pouls(b)})`;
    $('ouv-nom').innerHTML = [...'AESTHETICS'].map((x, k) => `<span style="opacity:${borne((l - 2 - k * 0.3) / 0.3)}">${x}</span>`).join('');
  },
});
