// Chaque badge : la page des badges, puis elle défile jusqu'aux secrets.
sceneTelephone({
  id: 'badges', de: 32, a: 36, p: 'bad', mots: ['Chaque', 'badge.'], clips: ['badges'],
  // La page est ouverte à 0,51 s ; le défilement part à 2,41 s.
  ecran: (l) => ({ clip: 'badges', s: l < 2 - 1e-6 ? 0.9 : 2.41 + (l - 2) * 1.3 }),
});
