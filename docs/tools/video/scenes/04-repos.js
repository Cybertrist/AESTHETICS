// Le repos : l'anneau bleu du minuteur, qui se vide sur les quatre pieds, et deux mots.
// Les 90 secondes du repos par défaut s'écoulent en accéléré : l'anneau et le décompte
// se calculent tous deux depuis l, et arrivent à zéro sur la coupe vers la scène suivante.
(() => {
  const R = 218, EP = 24, C = 2 * Math.PI * R, DUREE = 90, TEMPS = 4;
  const chiffre = (i) => `<span class="rep-ch" id="rep-c${i}">0</span>`;
  scene({
    id: 'repos', de: 22, a: 26,
    css: `
      #rep-anneau{position:absolute;left:96px;top:116px;width:488px;height:488px}
      #rep-anneau svg{position:absolute;inset:0;overflow:visible}
      #rep-temps{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;
        font-family:'Space Grotesk',sans-serif;font-weight:500;font-size:128px;line-height:1;color:#fff}
      .rep-ch{display:inline-block;width:76px;text-align:center}
      .rep-pt{display:inline-block;width:40px;text-align:center;position:relative;top:-8px}
      #rep-mot{position:absolute;left:640px;top:240px;font-size:70px}
      #rep-mot span{display:block}
      #rep-chaque{color:#8e8e93}
    `,
    html: `<div class="fond"></div>
      <div id="rep-anneau">
        <svg viewBox="0 0 488 488">
          <circle cx="244" cy="244" r="${R}" fill="none" stroke="#1f1f22" stroke-width="${EP}"/>
          <circle id="rep-arc" cx="244" cy="244" r="${R}" fill="none" stroke="#1E9BF0" stroke-width="${EP}"
            stroke-linecap="round" transform="rotate(-90 244 244)"/>
        </svg>
        <div id="rep-temps">${chiffre(0)}${chiffre(1)}<span class="rep-pt">:</span>${chiffre(2)}${chiffre(3)}</div>
      </div>
      <div class="titre" id="rep-mot"><span id="rep-chaque">CHAQUE</span><span id="rep-repos">REPOS.</span></div>`,
    rendre(l, b) {
      // le temps qui reste, de 90 à 0 seconde sur les quatre pieds
      const reste = DUREE * (1 - borne(l / TEMPS));
      const part = reste / DUREE;
      const arc = $('rep-arc');
      arc.style.opacity = part > 0.002 ? 1 : 0;
      arc.setAttribute('stroke-dasharray', `${Math.max(0.01, part * C)} ${C}`);
      const s = Math.ceil(reste - 1e-6);
      const txt = String(Math.floor(s / 60)).padStart(2, '0') + String(s % 60).padStart(2, '0');
      for (let i = 0; i < 4; i++) $(`rep-c${i}`).textContent = txt[i];

      // l'anneau arrive sur le premier pied, puis bat sur chaque temps
      const k = rebond(l / 0.7);
      $('rep-anneau').style.transform = `scale(${(0.82 + 0.18 * k) * pouls(b, 0.03)})`;

      // « CHAQUE » sur le premier pied, « REPOS. » sur le deuxième
      const k1 = sortie(l / 0.6), k2 = sortie((l - 1) / 0.6);
      $('rep-chaque').style.opacity = borne(l / 0.3);
      $('rep-chaque').style.transform = `translateX(${(1 - k1) * 60}px)`;
      $('rep-repos').style.opacity = borne((l - 1) / 0.3);
      $('rep-repos').style.transform = `translateX(${(1 - k2) * 60}px)`;
    },
  });
})();
