// La fin : le logo, le nom, la devise, l'adresse.
scene({
  id: 'fin', de: 56, a: 64,
  html: `<div class="fond"></div><div class="c">
    <img id="fin-logo" src="${LOGO}" style="width:150px;height:150px;border-radius:36px;box-shadow:0 0 0 1px #ffffff30,0 0 80px #ffffff26">
    <div class="titre" id="fin-nom" style="font-size:96px;margin-top:36px;letter-spacing:2px">AESTHETICS</div>
    <div id="fin-devise" style="font-size:30px;margin-top:26px;color:#d8d8de;font-weight:500">Chaque série. Chaque record. Chaque progrès.</div>
    <div class="mono" id="fin-url" style="margin-top:34px;font-size:22px;letter-spacing:1px;color:#8e8e93">github.com/Cybertrist/AESTHETICS</div></div>`,
  rendre(l) {
    $('fin-logo').style.transform = `scale(${rebond(l / 1.5)})`;
    $('fin-nom').style.opacity = borne((l - 0.6) / 0.6);
    $('fin-devise').style.opacity = borne((l - 2) / 0.8); $('fin-url').style.opacity = borne((l - 3.5) / 0.8);
  },
});
