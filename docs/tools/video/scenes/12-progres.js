// Chaque progrès : l'onglet Progrès, puis la courbe du 1RM qui a monté.
sceneTelephone({
  id: 'progres', de: 48, a: 52, p: 'pro', mots: ['Chaque', 'progrès.'], clips: ['progres'], captures: ['08a-fiche-progres'],
  css: '#pro-mc2{letter-spacing:-1px}',
  // Le défilement du clip part à 1,05 s.
  ecran: (l) => (l < 2 - 1e-6 ? { clip: 'progres', s: 0.5 } : l < 3 - 1e-6 ? { clip: 'progres', s: 2.6 + (l - 2) * 1.2 } : { capture: '08a-fiche-progres' }), // 2 : la page défile ; 3 : la courbe
});
