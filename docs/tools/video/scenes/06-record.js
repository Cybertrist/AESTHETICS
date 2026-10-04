// Chaque record : la ligne passe à l'or, puis le bandeau et l'écusson « PR ».
sceneTelephone({
  id: 'record', de: 24, a: 28, p: 'rcd', mots: ['Chaque', 'record.'], clips: ['seance-coches'],
  css: '#rcd-mc2{color:#FFBE0B}',
  // Le repère record est à 4,00 s (la ligne dorée), le bandeau est posé à 5,30 s.
  ecran: (l) => ({ clip: 'seance-coches', s: l < 2 - 1e-6 ? 4.07 + l * 0.4 : 5.3 + (l - 2) * 0.4 }),
  sous: { quand: 3, html: 'Charge maximale · <b style="font-weight:700">80&nbsp;kg</b>', style: 'color:#FFBE0B' },
});
