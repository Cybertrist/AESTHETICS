// Les badges : un écran, deux mots.
scene({
  id: 'badges', de: 50, a: 56,
  html: `<div class="fond"></div>${tel('18-badges', 'left:210px;top:40px', 290, 'tel-badges')}
    <div class="titre" id="mot-badges" style="position:absolute;left:640px;top:236px;font-size:76px"><span style="color:#8e8e93">LES</span><br>BADGES.</div>`,
  rendre(l, b) {
    const k = sortie(l / 0.9);
    $('tel-badges').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;
    $('mot-badges').style.opacity = borne((l - 0.25) / 0.4);
    $('mot-badges').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;
  },
});
