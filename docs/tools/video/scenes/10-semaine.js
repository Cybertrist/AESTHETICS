// Chaque semaine : la série, la flamme et ses 27 semaines, puis l'accueil où on la retrouve.
sceneTelephone({
  id: 'semaine', de: 40, a: 44, p: 'sem', mots: ['Chaque', 'semaine.'], clips: ['resume'], captures: ['12e-partage'],
  // La page « série » du résumé est pleine à 4,75 s ; puis la carte de partage de la série.
  ecran: (l) => (l < 2 - 1e-6 ? { clip: 'resume', s: 4.75 } : { capture: '12e-partage' }),
});
