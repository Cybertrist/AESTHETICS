// Le résumé mensuel : un écran, deux mots.
scene({
  id: 'resume', de: 44, a: 50,
  html: `<div class="fond"></div>${tel('16e-resume-comparaison', 'left:210px;top:40px', 290, 'tel-resume')}
    <div class="titre" id="mot-resume" style="position:absolute;left:640px;top:236px;font-size:76px"><span style="color:#8e8e93">CHAQUE</span><br>MOIS.</div>`,
  rendre(l, b) {
    const k = sortie(l / 0.9);
    $('tel-resume').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;
    $('mot-resume').style.opacity = borne((l - 0.25) / 0.4);
    $('mot-resume').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;
  },
});
