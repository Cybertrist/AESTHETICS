// Chaque muscle : la page Récupération, puis tous les muscles.
sceneTelephone({
  id: 'muscle', de: 36, a: 40, p: 'mus', mots: ['Chaque', 'muscle.'], clips: ['recuperation'],
  // La page s'ouvre à 0,50 s ; « Tous les muscles » à 2,45 s ; le défilement part à 3,60 s.
  ecran: (l) => ({ clip: 'recuperation', s: l < 2 - 1e-6 ? 1.1 : l < 3 - 1e-6 ? 2.9 : 3.6 + (l - 3) * 1.6 }),
});
