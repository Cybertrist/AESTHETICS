// Les deux phrases, l'une après l'autre.
scene({
  id: 'phrases', de: 8, a: 16,
  html: `<div class="c" style="gap:26px">
    <div id="phr-1" style="font-size:50px;font-weight:700;text-align:center">Je me suis toujours senti mal dans mon corps.</div>
    <div id="phr-2" style="font-size:50px;font-weight:700;text-align:center;color:#a8a8b0">C’est le moment d’atteindre mes objectifs.</div></div>`,
  rendre(l) {
    for (const [id, de] of [['phr-1', 0.3], ['phr-2', 3.5]]) {
      const k = sortie((l - de) / 1.2);
      $(id).style.opacity = k; $(id).style.transform = `translateY(${(1 - k) * 34}px)`;
    }
  },
});
