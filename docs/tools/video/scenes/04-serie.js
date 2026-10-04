// Chaque série : le tableau arrive sans aucune coche, puis les séries se cochent, une par pied.
sceneTelephone({
  id: 'serie', de: 16, a: 20, p: 'ser', mots: ['Chaque', 'série.'], clips: ['seance-coches'],
  // Les repères du clip : coche1 0,77 s, coche2 1,80 s, coche3 3,00 s. Deux images plus tard la ligne
  // est pleinement verte ; le clip tourne ensuite en vrai jusqu'au pied suivant.
  ecran(l) {
    const k = Math.min(3, Math.floor(l + 1e-6)), f = l - k;
    // Temps 0 : rien n'est coché. Puis une coche par pied, aux temps 1, 2 et 3.
    const depart = [0.4, 0.84, 1.87, 3.07][k];
    return { clip: 'seance-coches', s: depart + Math.min(f, 0.95) * (k === 0 ? 0.3 : 0.4) };
  },
});
