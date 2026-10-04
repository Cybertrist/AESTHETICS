// Chaque mois : le résumé mensuel, une page par pied.
sceneTelephone({
  id: 'mois', de: 44, a: 52, p: 'moi', mots: ['Chaque', 'mois.'], clips: ['resume'],
  // Chaque page du clip a un fondu d'entrée : on la prend 0,45 s après son repère, pleine.
  ecran(l) {
    // Pages 1, 2, 4, 5, 6, 7, 8 et 9 : ni le compte des entraînements ni le bilan, dont les chiffres sont ceux de la démo.
    const PAGES = [0.65, 1.58, 3.17, 3.96, 4.75, 5.58, 6.36, 7.15];
    return { clip: 'resume', s: PAGES[Math.min(7, Math.floor(l + 1e-6))] };
  },
  sous: { quand: 4, html: 'Dix pages.' },
});
