// Chaque mois : le résumé mensuel, une page par pied.
sceneTelephone({
  id: 'mois', de: 44, a: 48, p: 'moi', mots: ['Chaque', 'mois.'], clips: ['resume'],
  // Chaque page du clip a un fondu d'entrée : on la prend 0,45 s après son repère, pleine.
  ecran(l) {
    // Quatre pages, une par pied : le titre, les camions de pompiers, la toile des muscles, les records.
    const PAGES = [0.65, 3.96, 5.58, 6.36];
    return { clip: 'resume', s: PAGES[Math.min(3, Math.floor(l + 1e-6))] };
  },
});
