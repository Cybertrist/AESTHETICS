// Chaque record : l'écran, puis la ligne passe à l'or, « RECORD. » frappe, et le bandeau arrive.
sceneTelephone({
  id: 'record', de: 24, a: 28, p: 'rcd', mots: ['Chaque', 'record.'], clips: ['seance-coches'], quandMot: 2,
  css: '#rcd-mc2{color:#FFBE0B}',
  // Le repère record est à 4,00 s (la ligne dorée), le bandeau « PR » est posé à 5,30 s.
  ecran(l) {
    if (l < 1 - 1e-6) return { clip: 'seance-coches', s: 3.6 + l * 0.3 };          // 0 : la série n'est pas encore cochée
    if (l < 3 - 1e-6) return { clip: 'seance-coches', s: 4.07 + (l - 1) * 0.4 };   // 1 : la ligne à l'or ; 2 : le mot frappe
    return { clip: 'seance-coches', s: 5.3 + (l - 3) * 0.4 };                      // 3 : le bandeau et l'écusson
  },
});
