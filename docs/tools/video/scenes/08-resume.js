// Le résumé mensuel : un téléphone dont la page change comme une story, deux mots,
// et les dix tirets de la story qui se remplissent à côté.
(() => {
  // Les pages montrées : la capture, son rang dans les dix, le temps où elle arrive.
  const PAGES = [
    { capture: '16a-resume-titre', rang: 1, de: 0 },
    { capture: '16e-resume-comparaison', rang: 5, de: 1 },
    { capture: '16g-resume-muscles', rang: 7, de: 3 },
    { capture: '16j-resume-bilan', rang: 10, de: 5 },
  ];
  const GLISSE = 0.45; // durée d'un changement de page, en temps
  const deux = (n) => String(n).padStart(2, '0');

  scene({
    id: 'resume', de: 44, a: 50,
    css: `
      #res-mot{position:absolute;left:580px;top:214px;font-size:70px}
      #res-tirets{position:absolute;left:584px;top:400px;display:flex;gap:8px}
      .res-tiret{width:34px;height:6px;border-radius:3px;background:#34343a;position:relative;overflow:hidden}
      .res-tiret i{position:absolute;inset:0;background:#fff;border-radius:3px}
      #res-compte{position:absolute;left:584px;top:430px;font-size:30px;font-weight:700;color:#8e8e93;letter-spacing:1px}
      #res-compte b{color:#fff;font-weight:700}
    `,
    html: `<div class="fond"></div>
      <div class="tel" id="res-tel" style="--l:272px;left:162px;top:74px"><div class="v">
        ${PAGES.map((p, i) => `<img id="res-page-${i}" src="${BRUT}${p.capture}.png">`).join('')}
      </div></div>
      <div class="titre" id="res-mot"><span style="color:#8e8e93">CHAQUE</span><br>MOIS.</div>
      <div id="res-tirets">${Array.from({ length: 10 }, (_, i) => `<div class="res-tiret"><i id="res-tiret-${i}"></i></div>`).join('')}</div>
      <div class="mono" id="res-compte"><b id="res-rang">01</b> / 10</div>`,
    rendre(l, b) {
      // le téléphone monte, puis bat sur chaque pied
      const k = sortie(l / 0.9);
      $('res-tel').style.transform = `translateY(${(1 - k) * 90}px) rotate(${-5 + k * 2}deg) scale(${pouls(b)})`;

      // les pages se poussent l'une l'autre, sur un temps entier
      const arrivee = PAGES.map((p, i) => (i === 0 ? 1 : sortie((l - p.de) / GLISSE)));
      let rang = 1;
      PAGES.forEach((p, i) => {
        const suivante = i + 1 < PAGES.length ? arrivee[i + 1] : 0;
        const x = (1 - arrivee[i]) * 100 - suivante * 100;
        const e = $(`res-page-${i}`).style;
        e.transform = `translateX(${x}%)`;
        e.visibility = x > -100 && x < 100 ? 'visible' : 'hidden';
        rang = lerp(rang, p.rang, arrivee[i]);
      });

      // les deux mots
      $('res-mot').style.opacity = borne((l - 0.25) / 0.4);
      $('res-mot').style.transform = `translateX(${(1 - sortie((l - 0.25) / 0.8)) * 70}px)`;

      // les dix tirets et le compteur suivent la page
      const o = borne((l - 0.45) / 0.4);
      $('res-tirets').style.opacity = o;
      $('res-compte').style.opacity = o;
      for (let i = 0; i < 10; i++) $(`res-tiret-${i}`).style.transform = `translateX(${(borne(rang - i) - 1) * 100}%)`;
      let n = 1;
      for (const p of PAGES) if (l >= p.de) n = p.rang;
      $('res-rang').textContent = deux(n);
    },
  });
})();
