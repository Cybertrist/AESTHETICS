// La fin : le logo retombe sur le dernier coup, puis le nom, la devise, l'adresse.
// Tout est posé au temps 4 ; l'image ne bouge plus jusqu'à la fin (c'est la vignette).
scene({
  id: 'fin', de: 56, a: 64,
  css: `
.fin-pile{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.fin-logo{width:124px;height:124px;border-radius:29px;box-shadow:0 0 0 1px #ffffff30,0 0 80px #ffffff24}
.fin-nom{font-size:92px;letter-spacing:2px;margin-top:34px;color:#fff;white-space:nowrap}
.fin-devise{margin-top:26px;font-size:34px;font-weight:500;color:#a8a8b0;white-space:nowrap}
.fin-devise span{display:inline-block}
.fin-devise b{font-weight:700;color:#fff}
.fin-trait{width:56px;height:2px;background:#fff;margin-top:44px;transform-origin:50% 50%}
.fin-url{margin-top:26px;font-size:28px;font-weight:500;letter-spacing:.5px;color:#8e8e93;white-space:nowrap}
`,
  html: `<div class="fond"></div><div class="fin-pile">
    <img class="fin-logo" id="fin-logo" src="${LOGO}">
    <div class="titre fin-nom" id="fin-nom">AESTHETICS</div>
    <div class="fin-devise"><span id="fin-d0">Chaque <b>série.</b></span>&nbsp; <span id="fin-d1">Chaque <b>record.</b></span>&nbsp; <span id="fin-d2">Chaque <b>progrès.</b></span></div>
    <div class="fin-trait" id="fin-trait"></div>
    <div class="mono fin-url" id="fin-url">github.com/Cybertrist/AESTHETICS</div></div>`,
  rendre(l) {
    // temps 0 : le logo retombe sur le dernier coup, sans rebond (plus calme qu'à l'ouverture)
    const logo = $('fin-logo').style;
    logo.transform = `scale(${lerp(1.45, 1, sortie(l / 1))})`;
    // temps 1 : le nom monte en place
    const kn = sortie((l - 1) / 0.7), nom = $('fin-nom').style;
    nom.opacity = kn;
    nom.transform = `translateY(${lerp(22, 0, kn)}px) scale(${lerp(1.05, 1, kn)})`;
    // temps 2 : la devise, trois mots en cascade
    for (let k = 0; k < 3; k++) {
      const kd = sortie((l - 2 - k * 0.25) / 0.5), d = $(`fin-d${k}`).style;
      d.opacity = kd;
      d.transform = `translateY(${lerp(14, 0, kd)}px)`;
    }
    // temps 3 : le trait s'ouvre, l'adresse apparaît
    const ku = sortie((l - 3) / 0.7);
    const trait = $('fin-trait').style;
    trait.opacity = ku * 0.5;
    trait.transform = `scaleX(${ku})`;
    const url = $('fin-url').style;
    url.opacity = ku;
    url.transform = `translateY(${lerp(10, 0, ku)}px)`;
  },
});
