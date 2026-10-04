// Chaque série : dans le téléphone, les séries se cochent, une par pied.
sceneTelephone({
  id: 'serie', de: 16, a: 20, p: 'ser', mots: ['Chaque', 'série.'], clips: ['seance-coches'],
  // Les repères du clip : coche1 0,77 s, coche2 1,80 s, coche3 3,00 s. Deux images plus tard la ligne
  // est pleinement verte ; le clip tourne ensuite en vrai jusqu'au pied suivant.
  ecran(l) {
    const k = Math.min(3, Math.floor(l + 1e-6)), f = l - k;
    const depart = [0.84, 1.87, 3.07, 3.47][k];
    return { clip: 'seance-coches', s: depart + Math.min(f, 0.95) * 0.4 };
  },
  sous: { quand: 3, html: '<b style="font-weight:700;color:#fff">12</b>&nbsp;types de série.' },
});
