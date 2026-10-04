// La devise (temps 52 à 56) : les quatre derniers pieds de la musique. Un membre par pied, seul
// et en très grand, puis les trois ensemble sur le dernier, juste avant le coup final.
(() => {
  const MEMBRES = ['série.', 'record.', 'progrès.'];
  scene({
    id: 'devise', de: 52, a: 56,
    css: `.dev-bloc{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;white-space:nowrap}
      .dev-bloc .dev-1{color:#8e8e93}
      #dev-tout{gap:6px}`,
    html: `<div class="fond"></div>
      ${MEMBRES.map((m, i) => `<div class="dev-bloc titre" id="dev-b${i}" style="font-size:118px"><span class="dev-1">Chaque</span><span>${m}</span></div>`).join('')}
      <div class="dev-bloc titre" id="dev-tout" style="font-size:66px">${MEMBRES.map((m) => `<div><span class="dev-1">Chaque</span> ${m}</div>`).join('')}</div>`,
    rendre(l) {
      MEMBRES.forEach((m, i) => {
        const e = $(`dev-b${i}`).style;
        e.opacity = l >= i - 1e-6 && l < i + 1 - 1e-6 ? 1 : 0;
        e.transform = `scale(${frappe(l - i, 0.07).toFixed(4)})`;
      });
      const t = $('dev-tout').style;
      t.opacity = la(l - 3);
      t.transform = `scale(${frappe(l - 3, 0.06).toFixed(4)})`;
    },
  });
})();
