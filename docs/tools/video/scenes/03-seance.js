// La séance : un écran, deux mots.
scene({
  id: 'seance', de: 16, a: 22,
  html: `<div class="fond"></div>${tel('05-seance', 'left:210px;top:40px', 290, 'tel-seance')}
    <div class="titre" id="mot-seance" style="position:absolute;left:640px;top:236px;font-size:76px"><span style="color:#8e8e93">CHAQUE</span><br>SÉRIE.</div>`,
  rendre(l, b) {
    const k = sortie(l / 0.9);
    $('tel-seance').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;
    $('mot-seance').style.opacity = borne((l - 0.25) / 0.4);
    $('mot-seance').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;
  },
});
