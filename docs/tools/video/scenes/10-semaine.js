// Chaque semaine : la flamme de la série et ses 27 semaines, puis le calendrier, puis la semaine.
sceneTelephone({
  id: 'semaine', de: 40, a: 44, p: 'sem', mots: ['Chaque', 'semaine.'], captures: ['12e-partage', '13d-progres-calendrier', '13a-progres-semaine'],
  // Une seule flamme : la carte de la série. Puis le calendrier du mois, puis la semaine dans Progrès.
  ecran: (l) => ({ capture: l < 2 - 1e-6 ? '12e-partage' : l < 3 - 1e-6 ? '13d-progres-calendrier' : '13a-progres-semaine' }),
});
