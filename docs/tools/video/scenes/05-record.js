// Le record : un écran, deux mots.
scene({
  id: 'record', de: 26, a: 30,
  html: `<div class="fond"></div>${tel('11-fin-records', 'left:210px;top:40px', 290, 'tel-record')}
    <div class="titre" id="mot-record" style="position:absolute;left:640px;top:236px;font-size:76px"><span style="color:#8e8e93">CHAQUE</span><br>RECORD.</div>`,
  rendre(l, b) {
    const k = sortie(l / 0.9);
    $('tel-record').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;
    $('mot-record').style.opacity = borne((l - 0.25) / 0.4);
    $('mot-record').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;
  },
});
