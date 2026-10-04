// Les deux phrases de Tristan, seules sur le noir. La première se pose sur la
// nappe (temps locaux 0 à 4) ; la seconde arrive ligne par ligne avec la montée
// (4 à 8), grandit, se resserre et tremble sur le roulement, pendant qu'un trait
// s'étire comme une mèche jusqu'à l'éclair du temps 16.
scene({
  id: 'phrases', de: 8, a: 16,
  css: `
    #phr-lueur{position:absolute;inset:0;background:radial-gradient(52% 60% at 50% 47%,rgba(255,255,255,.2) 0,rgba(255,255,255,0) 70%)}
    .phr-bloc{position:absolute;left:0;right:0;top:0;height:680px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
    .phr-a{display:block;font-size:58px;font-weight:500;line-height:1.28;letter-spacing:-.5px;white-space:nowrap}
    .phr-b{display:block;font-size:60px;line-height:1.14;white-space:nowrap}
    #phr-trait{position:absolute;left:50%;top:520px;height:2px;background:#fff;border-radius:2px}
  `,
  html: `<div class="fond"></div><div id="phr-lueur"></div>
    <div class="phr-bloc" id="phr-1">
      <span class="phr-a" id="phr-a1">Je me suis toujours senti mal</span>
      <span class="phr-a" id="phr-a2">dans mon corps.</span>
    </div>
    <div class="phr-bloc" id="phr-2">
      <span class="phr-b titre" id="phr-b1">C’est le moment</span>
      <span class="phr-b titre" id="phr-b2">d’atteindre</span>
      <span class="phr-b titre" id="phr-b3">mes objectifs.</span>
    </div>
    <div id="phr-trait"></div>`,
  // La ligne la plus large de la seconde phrase fait 1000 px, quelle que soit la chasse de Syne.
  async init() {
    const lignes = ['phr-b1', 'phr-b2', 'phr-b3'].map($);
    for (const e of lignes) { e.style.fontSize = '100px'; e.style.letterSpacing = '0'; }
    const large = Math.max(...lignes.map((e) => e.getBoundingClientRect().width));
    this.corps = Math.floor(100 * 1000 / large);
    for (const e of lignes) e.style.fontSize = this.corps + 'px';
  },
  rendre(l) {
    // --- la première phrase : deux lignes, sur les temps 0 et 1, puis elle s'efface avant le temps 4
    const part = borne((l - 3.4) / 0.6);
    $('phr-1').style.opacity = 1 - part;
    $('phr-1').style.transform = `translateY(${-10 * entree(part)}px)`;
    for (const [id, de] of [['phr-a1', 0], ['phr-a2', 1]]) {
      const k = sortie((l - de) / 0.9);
      $(id).style.opacity = borne((l - de) / 0.6);
      $(id).style.transform = `translateY(${(1 - k) * 16}px)`;
    }

    // --- la seconde : une ligne par temps (4, 5, 6), puis tout se tend jusqu'à 8
    const m = borne((l - 4) / 4);                  // la montée, de 0 à 1
    const tension = m * m;
    // le roulement : des coups de plus en plus serrés à partir du temps 6
    let dx = 0, dy = 0;
    if (l >= 6) {
      const pas = l < 7 ? 0.25 : 0.125;
      const n = Math.floor(l / pas), ph = (l / pas) % 1;
      const force = lerp(0, 3.5, (l - 6) / 2) * Math.exp(-ph * 2.5);
      dx = (n % 2 ? 1 : -1) * force;
      dy = (n % 3 === 0 ? -1 : 1) * force * 0.5;
    }
    $('phr-2').style.opacity = l >= 4 ? 1 : 0;
    $('phr-2').style.transform = `translate(${dx}px,${dy}px) scale(${lerp(0.94, 1.07, tension)})`;
    const serre = lerp(0.08, 0.008, sortie(m));    // l'interlettrage se resserre
    for (const [id, de] of [['phr-b1', 4], ['phr-b2', 5], ['phr-b3', 6]]) {
      const k = sortie((l - de) / 0.7);
      const e = $(id);
      e.style.opacity = borne((l - de) / 0.35);
      e.style.transform = `translateY(${(1 - k) * 22}px)`;
      e.style.letterSpacing = serre + 'em';
      e.style.paddingLeft = serre + 'em';          // garde la ligne centrée malgré l'interlettrage
    }

    // --- le trait : un tiret sous la première phrase (temps 2), une mèche pendant la montée
    const pose = sortie((l - 2) / 1);
    const w = l < 4 ? 56 * pose : lerp(56, 1152, Math.pow(m, 1.7));
    const trait = $('phr-trait');
    trait.style.width = w + 'px';
    trait.style.marginLeft = -w / 2 + 'px';
    trait.style.height = lerp(2, 4, tension) + 'px';
    trait.style.opacity = l < 4 ? 0.55 * borne((l - 2) / 0.5) : lerp(0.55, 1, m * 2);

    // --- la lumière monte avec le bruit
    $('phr-lueur').style.opacity = tension;
  },
});
