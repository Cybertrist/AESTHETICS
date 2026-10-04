// Chaque repos : le minuteur de l'appli, et le « +10 » qui tombe sur le pied.
sceneTelephone({
  id: 'repos', de: 20, a: 24, p: 'rep', mots: ['Chaque', 'repos.'], clips: ['repos'],
  // Les secondes du clip : 01:13 (image 61), 01:12 (73), le « +10 » fait 01:22 (100), puis 01:21 (104).
  ecran(l) {
    const k = Math.min(3, Math.floor(l + 1e-6)), f = l - k;
    const image = [62, 74, 100, 104][k] + Math.min(f, 0.95) * [10, 12, 3, 10][k];
    return { clip: 'repos', s: image / 30 };
  },
  sous: { quand: 3, html: 'Minuteur automatique.' },
});
