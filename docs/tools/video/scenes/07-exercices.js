// 608 exercices : la bibliothèque qui défile, puis une fiche où le personnage exécute le mouvement.
sceneTelephone({
  id: 'exercices', de: 28, a: 32, p: 'exo', mots: ['608', 'exercices.'], clips: ['bibliotheque', 'fiche-exercice'],
  // Le chiffre en Space Grotesk : en Syne, son zéro se lit « o ».
  css: `#exo-mc{top:262px}
    #exo-mc1{font-family:'Space Grotesk',sans-serif;font-weight:700;font-variant-numeric:tabular-nums;color:#fff;font-size:104px;line-height:.98;letter-spacing:0}
    #exo-mc2{font-size:44px}`,
  ecran: (l) => (l < 2 - 1e-6 ? { clip: 'bibliotheque', s: 0.65 + l * 0.6 } : { clip: 'fiche-exercice', s: (l - 2) * 0.9 + (l >= 3 - 1e-6 ? 1.2 : 0) }),
  sous: { quand: 2, html: '<b style="font-weight:700;color:#fff">496</b>&nbsp;animés.', style: 'top:456px' },
});
