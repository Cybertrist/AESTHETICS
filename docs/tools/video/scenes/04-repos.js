// Le repos : un écran, deux mots.
scene({
  id: 'repos', de: 22, a: 26,
  html: `<div class="fond"></div>${tel('06-repos', 'left:210px;top:40px', 290, 'tel-repos')}
    <div class="titre" id="mot-repos" style="position:absolute;left:640px;top:236px;font-size:76px"><span style="color:#8e8e93">CHAQUE</span><br>REPOS.</div>`,
  rendre(l, b) {
    const k = sortie(l / 0.9);
    $('tel-repos').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;
    $('mot-repos').style.opacity = borne((l - 0.25) / 0.4);
    $('mot-repos').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;
  },
});
