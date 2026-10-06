// Le 1RM estimé et les records.
//
// En haut, une série passe dans les deux formules : 80 kg × 8 donne 101,33
// par Epley et 99,31 par Brzycki, leur moyenne 100,32 ; 60 kg × 12, au-delà
// de dix répétitions, ne garde qu'Epley, 84,00. En bas, chaque série de la
// séance du jour est comparée à ce qui a été fait avant et reçoit au plus
// une médaille (or, argent, bronze), puis les quatre règles.
//
// Les calculs, vérifiés au centième :
//   80 × (1 + 8/30) = 101,3333        80 × 36 / 29 = 99,3103      moyenne 100,3218
//   80 × (1 + 9/30) = 104,0000        80 × 36 / 28 = 102,8571     moyenne 103,4286
//   75 × (1 + 10/30) = 100,0000       75 × 36 / 27 = 100,0000     moyenne 100,0000
//   60 × (1 + 12/30) = 84,0000        60 × 36 / 25 = 86,4000      (écartée)
module.exports = (O) => {
  const {
    svg, t, visible, fondu, bille, tr,
    MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, OR, ROSE, ROUGE,
  } = O;

  const C = 28;
  const g = (de, a, contenu, douceur = 0.006) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  const FIN = 0.996;

  // Les formules de l'appli, pour que chaque chiffre affiché soit calculé.
  const epley = (p, r) => (r <= 0 ? 0 : r === 1 ? p : p * (1 + r / 30));
  const brzycki = (p, r) => (r <= 0 ? 0 : r === 1 ? p : r >= 37 ? epley(p, r) : p * 36 / (37 - r));
  const unRm = (p, r) => (p <= 0 || r <= 0 ? 0 : r <= 10 ? (epley(p, r) + brzycki(p, r)) / 2 : epley(p, r));
  const fr = (v, d = 2) => v.toFixed(d).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  const kg = (v, d = 2) => `${fr(v, d)} kg`;
  /// Comme l'appli : une décimale au plus, sans zéro inutile.
  const court = (v) => `${fr(Math.round(v * 10) / 10, 1).replace(/,0$/, '')} kg`;
  const verifie = (nom, v, attendu) => { if (fr(v) !== attendu) throw new Error(`records : ${nom} vaut ${fr(v)}, pas ${attendu}`); };
  verifie('Epley 80 × 8', epley(80, 8), '101,33');
  verifie('Brzycki 80 × 8', brzycki(80, 8), '99,31');
  verifie('1RM 80 × 8', unRm(80, 8), '100,32');
  verifie('Epley 60 × 12', epley(60, 12), '84,00');
  verifie('Brzycki 60 × 12', brzycki(60, 12), '86,40');

  // Les instants du récit.
  const T = {
    ex1: 0.03, epley1: 0.07, brz1: 0.11, moy1: 0.15,
    ex2: 0.21, epley2: 0.25, brz2: 0.29, res2: 0.33,
    serie: (i) => 0.38 + i * 0.025, total: 0.5,
    rec: (i) => 0.55 + i * 0.06,
    regle: (i) => [0.73, 0.79, 0.85, 0.91][i],
  };

  let corps = '';
  corps += t(60, 52, 'LE 1RM ESTIMÉ ET LES RECORDS', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(400, 52, 'Une série devient une force estimée ; une séance se mesure à toutes celles d’avant.', { taille: 14 });

  // ============================================================ le 1RM estimé
  const COLS = [[60, 190], [280, 290], [590, 290], [920, 300]];
  const entetes = [
    ['LA SÉRIE', 'cochée, hors échauffement'],
    ['EPLEY', 'poids × (1 + reps / 30)'],
    ['BRZYCKI', 'poids × 36 / (37 − reps)'],
    ['LE 1RM ESTIMÉ', 'la moyenne jusqu’à 10 reps, Epley au-delà'],
  ];
  entetes.forEach(([titre, sous], k) => {
    const [x] = COLS[k];
    corps += t(x, 92, titre, { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
    corps += t(x, 112, sous, { taille: 12.5, couleur: k === 1 || k === 2 ? TITRE : TEXTE, police: k === 1 || k === 2 ? MONO : undefined });
  });
  const LH = 60;
  const case_ = (k, y, couleur, de, contenu, eteint = false) => {
    const [x, l] = COLS[k];
    return `<rect x="${x}" y="${y}" width="${l}" height="${LH}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${l}" height="${LH}" rx="13" fill="${couleur}" fill-opacity="0.05" stroke="${couleur}" stroke-opacity="${eteint ? 0.15 : 0.3}"/>
      <rect x="${x}" y="${y}" width="${l}" height="${LH}" rx="13" fill="none" stroke="${couleur}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, de, de + 0.05, 0.006)}</rect>
      ${g(de, FIN, contenu(x, l))}`;
  };
  const calcul = (y, texte, resultat, couleur = TITRE) => (x, l) => `${t(x + 18, y + 36, texte, { taille: 13, couleur: TEXTE, police: MONO })}
    ${t(x + l - 18, y + 37, resultat, { taille: 15.5, couleur, police: MONO, poids: 700, ancre: 'end' })}`;
  const fleche = (x1, x2, y, de) => g(de, FIN, `<path d="M${x1} ${y} H${x2 - 2}" stroke="${FIL}" stroke-width="2"/><path d="M${x2 - 7} ${y - 5} l5 5 l-5 5" fill="none" stroke="${FIL}" stroke-width="2"/>`);
  const passe = (d, de, a, c) => `<g opacity="0">${visible(C, de, a + 0.004, 0.003)}${bille(d, C, '0;0;1;1', `0;${de};${a};1`, c, 5)}</g>`;

  // Première série : dix répétitions ou moins, la moyenne des deux formules.
  const Y1 = 126, Y2 = 198;
  corps += `<rect x="60" y="${Y1}" width="190" height="${LH}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
    <rect x="60" y="${Y1}" width="190" height="${LH}" rx="13" fill="none" stroke="${TITRE}" stroke-opacity="0.7" opacity="0">${visible(C, T.ex1, T.ex2, 0.006)}</rect>
    ${t(155, Y1 + 30, '80 kg × 8', { taille: 19, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' })}
    ${t(155, Y1 + 48, '8 répétitions : 10 ou moins', { taille: 11.5, couleur: DISCRET, ancre: 'middle' })}`;
  corps += case_(1, Y1, ROSE, T.epley1, calcul(Y1, '80 × (1 + 8 / 30)', kg(epley(80, 8))));
  corps += case_(2, Y1, ROSE, T.brz1, calcul(Y1, '80 × 36 / 29', kg(brzycki(80, 8))));
  corps += case_(3, Y1, ACCENT, T.moy1, calcul(Y1, `(${fr(epley(80, 8))} + ${fr(brzycki(80, 8))}) / 2`, kg(unRm(80, 8)), ACCENT));
  corps += fleche(252, 278, Y1 + LH / 2, T.epley1) + fleche(882, 918, Y1 + LH / 2, T.moy1);
  corps += g(T.brz1, FIN, t(580, Y1 + 36, '+', { taille: 16, couleur: DISCRET, police: MONO, poids: 700, ancre: 'middle' }));
  corps += passe(`M250 ${Y1 + LH / 2} H280`, T.ex1 + 0.01, T.epley1, ROSE);
  corps += passe(`M880 ${Y1 + LH / 2} H920`, T.brz1 + 0.01, T.moy1, ACCENT);

  // Seconde série : plus de dix répétitions, Epley seul.
  corps += `<rect x="60" y="${Y2}" width="190" height="${LH}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
    <rect x="60" y="${Y2}" width="190" height="${LH}" rx="13" fill="none" stroke="${TITRE}" stroke-opacity="0.7" opacity="0">${visible(C, T.ex2, T.serie(0), 0.006)}</rect>
    ${t(155, Y2 + 30, '60 kg × 12', { taille: 19, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' })}
    ${t(155, Y2 + 48, '12 répétitions : plus de 10', { taille: 11.5, couleur: DISCRET, ancre: 'middle' })}`;
  corps += case_(1, Y2, ROSE, T.epley2, calcul(Y2, '60 × (1 + 12 / 30)', kg(epley(60, 12))));
  corps += case_(2, Y2, DISCRET, T.brz2, (x, l) => `${t(x + 18, Y2 + 28, '60 × 36 / 25', { taille: 13, couleur: DISCRET, police: MONO })}
    ${t(x + 18, Y2 + 46, 'écartée au-delà de 10 répétitions', { taille: 11.5, couleur: DISCRET })}
    ${t(x + l - 18, Y2 + 29, kg(brzycki(60, 12)), { taille: 15.5, couleur: DISCRET, police: MONO, poids: 700, ancre: 'end' })}
    <path d="M${x + l - 112} ${Y2 + 24} h96" stroke="${ROUGE}" stroke-width="1.6" stroke-opacity="0.8"/>`, true);
  corps += case_(3, Y2, ACCENT, T.res2, calcul(Y2, 'Epley seul', kg(unRm(60, 12)), ACCENT));
  corps += fleche(252, 278, Y2 + LH / 2, T.epley2);
  // Epley saute par-dessus Brzycki.
  corps += g(T.res2, FIN, `<path d="M570 ${Y2 + LH / 2} H582 V${Y2 + LH + 7} H904 V${Y2 + LH / 2} H916" fill="none" stroke="${FIL}" stroke-width="2"/><path d="M911 ${Y2 + LH / 2 - 5} l5 5 l-5 5" fill="none" stroke="${FIL}" stroke-width="2"/>`);
  corps += passe(`M250 ${Y2 + LH / 2} H280`, T.ex2 + 0.01, T.epley2, ROSE);
  corps += passe(`M570 ${Y2 + LH / 2} H582 V${Y2 + LH + 7} H904 V${Y2 + LH / 2} H920`, T.brz2 + 0.01, T.res2, ACCENT);

  // La frise des répétitions : où passe la limite.
  const FY = 286, FX = 280, FL = 30;
  corps += t(60, FY + 19, 'SELON LES RÉPÉTITIONS', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  for (let r = 1; r <= 15; r++) {
    const x = FX + (r - 1) * FL, c = r === 1 ? TITRE : r <= 10 ? ROSE : ACCENT;
    corps += `<rect x="${x + 2}" y="${FY}" width="${FL - 4}" height="28" rx="7" fill="${c}" fill-opacity="0.1" stroke="${c}" stroke-opacity="0.4"/>
      ${t(x + FL / 2, FY + 18.5, String(r), { taille: 11.5, couleur: c, police: MONO, poids: 700, ancre: 'middle' })}`;
    if (r === 8) corps += `<rect x="${x + 2}" y="${FY}" width="${FL - 4}" height="28" rx="7" fill="${ROSE}" fill-opacity="0.25" stroke="${ROSE}" stroke-width="1.5" opacity="0">${visible(C, T.ex1, FIN, 0.006)}</rect>`;
    if (r === 12) corps += `<rect x="${x + 2}" y="${FY}" width="${FL - 4}" height="28" rx="7" fill="${ACCENT}" fill-opacity="0.25" stroke="${ACCENT}" stroke-width="1.5" opacity="0">${visible(C, T.ex2, FIN, 0.006)}</rect>`;
  }
  corps += t(FX + 15 * FL + 8, FY + 18.5, '…', { taille: 13, couleur: DISCRET });
  const legende = (x, c, texte) => `<rect x="${x}" y="${FY + 8}" width="12" height="12" rx="3.5" fill="${c}" fill-opacity="0.25" stroke="${c}" stroke-opacity="0.7"/>${t(x + 19, FY + 18.5, texte, { taille: 12, couleur: TEXTE })}`;
  corps += legende(770, TITRE, '1 : la charge') + legende(884, ROSE, '2 à 10 : la moyenne') + legende(1046, ACCENT, '11 et plus : Epley seul');

  // ============================================================== les records
  // La règle de `Strength.newRecords` : chaque série validée est comparée à
  // ce qui a été fait avant la séance et reçoit au plus une médaille.
  const ARGENT = '#B9C3CE', BRONZE = '#CB7F45';
  const BY = 352;
  corps += `<line x1="60" y1="${BY - 20}" x2="1220" y2="${BY - 20}" stroke="${BORD}"/>`;
  corps += t(60, BY + 6, 'LES RECORDS : UNE MÉDAILLE PAR SÉRIE, LA PLUS HAUTE', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  corps += t(1220, BY + 6, 'Avant : une seule séance, 80 kg × 8, 80 kg × 8 et 77,5 kg × 8.', { taille: 12, couleur: TEXTE, ancre: 'end' });
  // Ce qu'il faut battre : la charge la plus lourde, le meilleur 1RM estimé,
  // et le plus de répétitions faites à une charge ou plus lourd.
  const passe_ = [[80, 8], [80, 8], [77.5, 8]];
  const avant = { poids: Math.max(...passe_.map((s) => s[0])), rm: Math.max(...passe_.map(([p, r]) => unRm(p, r))), repsA: (p) => Math.max(0, ...passe_.filter((s) => s[0] >= p - 1e-9).map((s) => s[1])) };
  const series = [['É', 40, 10, false], ['1', 82.5, 6, true], ['2', 80, 9, true], ['3', 75, 10, true], ['4', 80, 8, true]];
  const medaille = ([, p, r, compte]) => {
    if (!compte) return null;
    if (p > avant.poids + 1e-9) return 'or';
    if (unRm(p, r) > avant.rm + 0.05) return 'argent';
    return r > avant.repsA(p) ? 'bronze' : null;
  };
  if (series.map(medaille).join() !== ',or,argent,bronze,') throw new Error('records : médailles ' + series.map(medaille).join());
  verifie('1RM 80 × 9', unRm(80, 9), '103,43');
  verifie('1RM 75 × 10', unRm(75, 10), '100,00');

  // La séance du jour, à gauche.
  const SXg = 60, SLg = 410, SYg = BY + 22, SH = 278;
  corps += `<rect x="${SXg}" y="${SYg}" width="${SLg}" height="${SH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(SXg + 20, SYg + 28, 'Développé couché', { taille: 14.5, couleur: TITRE, poids: 700 });
  corps += t(SXg + SLg - 20, SYg + 28, 'la séance du jour', { taille: 12, couleur: DISCRET, ancre: 'end' });
  const CX = { serie: SXg + 36, charge: SXg + 130, volume: SXg + 262, rm: SXg + SLg - 22 };
  corps += [['Série', CX.serie, 'middle'], ['Charge × reps', CX.charge, 'middle'], ['Volume', CX.volume, 'end'], ['1RM estimé', CX.rm, 'end']]
    .map(([n, x, ancre]) => t(x, SYg + 54, n, { taille: 11, couleur: DISCRET, ancre })).join('');
  const RH = 34, R0 = SYg + 64;
  const texteSerie = (p, r) => `${fr(p, p % 1 ? 1 : 0)} kg × ${r}`;
  series.forEach(([nom, p, r, compte], i) => {
    const y = R0 + i * RH;
    corps += g(T.serie(i), FIN, `${compte ? (i % 2 ? `<rect x="${SXg + 10}" y="${y}" width="${SLg - 20}" height="${RH}" rx="8" fill="#FFFFFF" fill-opacity="0.025"/>` : '')
      : `<rect x="${SXg + 10}" y="${y + 2}" width="${SLg - 20}" height="${RH - 4}" rx="8" fill="url(#hachures)" fill-opacity="0.9"/>`}
      ${t(CX.serie, y + 22, nom, { taille: 13.5, couleur: compte ? TITRE : OR, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(CX.charge, y + 22, texteSerie(p, r), { taille: 13.5, couleur: compte ? TITRE : DISCRET, police: MONO, poids: 700, ancre: 'middle' })}
      ${compte
        ? t(CX.volume, y + 22, kg(p * r, 0), { taille: 13, couleur: TEXTE, police: MONO, ancre: 'end' }) + t(CX.rm, y + 22, fr(unRm(p, r)), { taille: 13, couleur: TEXTE, police: MONO, ancre: 'end' })
        : t(CX.rm, y + 22, 'échauffement : ne compte pas', { taille: 11.5, couleur: DISCRET, ancre: 'end' })}`);
  });
  const volumeJour = series.filter((s) => s[3]).reduce((a, [, p, r]) => a + p * r, 0);
  const TYg = R0 + series.length * RH + 8;
  corps += `<line x1="${SXg + 20}" y1="${TYg}" x2="${SXg + SLg - 20}" y2="${TYg}" stroke="${BORD}"/>`;
  corps += g(T.total, FIN, `${t(SXg + 20, TYg + 23, 'Volume de l’exercice', { taille: 12.5, couleur: TEXTE })}
    ${t(CX.volume, TYg + 23, kg(volumeJour, 0), { taille: 13.5, couleur: TITRE, police: MONO, poids: 700, ancre: 'end' })}`);

  // Chaque série du jour, à droite : ce qu'il fallait battre, ce qu'elle fait, sa médaille.
  const TX = 490, TL = 730, TYt = SYg;
  corps += `<rect x="${TX}" y="${TYt}" width="${TL}" height="${SH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  const KX = { nom: TX + 22, avant: TX + 300, jour: TX + 452, verdict: TX + TL - 20 };
  corps += [['La série du jour', KX.nom, 'start'], ['À battre', KX.avant, 'middle'], ['Aujourd’hui', KX.jour, 'middle'], ['Médaille', KX.verdict - 70, 'middle']]
    .map(([n, x, ancre]) => t(x, TYt + 28, n, { taille: 11, couleur: DISCRET, police: MONO, poids: 700, ancre, extra: 'letter-spacing="1.5"' })).join('');
  const MEDAILLES = { or: ['OR', OR], argent: ['ARGENT', ARGENT], bronze: ['BRONZE', BRONZE] };
  const lignes = [
    [series[1], 'une charge jamais soulevée', court(avant.poids), 'la charge maximale', court(82.5), `+${court(82.5 - avant.poids)}`],
    [series[2], 'un meilleur 1RM estimé', court(avant.rm), 'le 1RM estimé', court(unRm(80, 9)), `+${court(unRm(80, 9) - avant.rm)}`],
    [series[3], 'plus de répétitions à cette charge', `${avant.repsA(75)} reps`, 'à 75 kg ou plus lourd', '10 reps', `+${10 - avant.repsA(75)} reps`],
    [series[4], 'rien de mieux qu’avant', `${avant.repsA(80)} reps`, 'à 80 kg ou plus lourd', '8 reps', 'égalité : rien'],
    [series[0], 'un échauffement', '—', '', '—', 'ne compte pas'],
  ];
  const QH = 46, Q0 = TYt + 40;
  lignes.forEach(([serie, quoi, av, avSous, jr, verdict], i) => {
    const m = medaille(serie), [nomM, c] = m ? MEDAILLES[m] : ['', DISCRET];
    const y = Q0 + i * QH, de = T.rec(i);
    const cellule = (x, v, sous, couleur) => (sous
      ? t(x, y + 21, v, { taille: 13.5, couleur, police: MONO, poids: 700, ancre: 'middle' }) + t(x, y + 35, sous, { taille: 10.5, couleur: DISCRET, ancre: 'middle' })
      : t(x, y + 28, v, { taille: 13.5, couleur, police: MONO, poids: 700, ancre: 'middle' }));
    corps += `<line x1="${TX + 16}" y1="${y}" x2="${TX + TL - 16}" y2="${y}" stroke="${BORD}"/>
      <rect x="${TX + 8}" y="${y + 3}" width="${TL - 16}" height="${QH - 6}" rx="9" fill="${c}" fill-opacity="0.07" stroke="${c}" stroke-opacity="0.7" opacity="0">${visible(C, de, de + 0.055, 0.006)}</rect>
      ${t(KX.nom, y + 21, texteSerie(serie[1], serie[2]), { taille: 13.5, couleur: TITRE, police: MONO, poids: 700 })}
      ${t(KX.nom, y + 35, quoi, { taille: 10.5, couleur: DISCRET })}
      ${cellule(KX.avant, av, avSous, TEXTE)}
      ${g(de, FIN, `<path d="M${KX.avant + 66} ${y + 23} h22 m-5 -5 l5 5 l-5 5" fill="none" stroke="${FIL}" stroke-width="2"/>
        ${cellule(KX.jour, jr, '', m ? TITRE : TEXTE)}
        <rect x="${KX.verdict - 140}" y="${y + 11}" width="140" height="24" rx="12" fill="${c}" fill-opacity="${m ? 0.14 : 0.08}" stroke="${c}" stroke-opacity="0.55"/>
        ${m
          ? t(KX.verdict - 128, y + 27.5, nomM, { taille: 10, couleur: c, poids: 800, extra: 'letter-spacing="1"' }) + t(KX.verdict - 12, y + 27.5, verdict, { taille: 12, couleur: c, police: MONO, poids: 700, ancre: 'end' })
          : t(KX.verdict - 70, y + 27.5, verdict, { taille: 11.5, couleur: TEXTE, poids: 700, ancre: 'middle' })}`)}`;
  });

  // Les quatre règles.
  const NY = BY + 22 + SH + 16, NH = 92, NL = 278, NG = (1160 - 4 * NL) / 3;
  const regles = [
    ['Une seule médaille, la plus haute', ['L’or passe avant l’argent, l’argent avant', 'le bronze : une série n’en reçoit', 'jamais deux.'], OR],
    ['Strictement mieux', ['Égaler ne suffit pas : 8 répétitions', 'contre 8, rien. Le 1RM estimé doit', 'gagner plus de 0,05 kg.'], ARGENT],
    ['L’échauffement ne compte pas', ['Ses 400 kg et ses 10 répétitions restent', 'hors du volume, du 1RM et des records.', 'Les onze autres types de série comptent.'], BRONZE],
    ['Pas de record sans historique', ['Un exercice fait pour la première fois', 'n’en bat aucun. Au poids du corps, seul', 'compte le plus de répétitions.'], ROUGE],
  ];
  regles.forEach(([titre, texte, c], k) => {
    const x = 60 + k * (NL + NG), de = T.regle(k), a = k < 3 ? T.regle(k + 1) : FIN;
    corps += `<rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="${c}" fill-opacity="0.05" stroke="${c}" stroke-opacity="0.3"/>
      <rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="none" stroke="${c}" stroke-opacity="0.9" opacity="0">${visible(C, de, a, 0.006)}</rect>
      ${t(x + 18, NY + 27, titre, { taille: 13.5, couleur: TITRE, poids: 700 })}
      ${texte.map((s, i) => t(x + 18, NY + 47 + i * 16.5, s, { taille: 12, couleur: TEXTE })).join('')}`;
  });

  corps += t(60, NY + NH + 30, 'La même règle partout : pendant la séance, à la fin, sur l’accueil et dans les résumés. Par séance et par exercice : un or et un argent au plus, un bronze par charge.', { taille: 13, couleur: DISCRET });

  svg('records.svg', 1280, NY + NH + 54, corps,
    `Le 1RM estimé et les records. Le 1RM estimé d’une série cochée, hors échauffement, se calcule par deux formules : Epley, poids × (1 + reps / 30), et Brzycki, poids × 36 / (37 − reps). Pour 80 kg × 8, Epley donne 101,33 kg et Brzycki 99,31 kg ; jusqu’à 10 répétitions on retient leur moyenne, 100,32 kg. Pour 60 kg × 12, au-delà de 10 répétitions, Brzycki (86,40 kg) est écartée et Epley seul donne 84,00 kg. À 1 répétition, le 1RM est la charge elle-même. Les records : chaque série validée est comparée à ce qui a été fait avant la séance, et reçoit au plus une médaille, la plus haute. L’or, pour une charge jamais soulevée sur l’exercice ; l’argent, pour un meilleur 1RM estimé sans charge record ; le bronze, pour plus de répétitions qu’on n’en a jamais fait à cette charge ou plus lourd. Sur le développé couché, la séance d’avant comptait 80 kg × 8, 80 kg × 8 et 77,5 kg × 8. Aujourd’hui, après un échauffement de 40 kg × 10 qui ne compte pas : 82,5 kg × 6 dépasse la charge maximale de 80 kg, médaille d’or, +2,5 kg ; 80 kg × 9 porte le 1RM estimé de ${court(avant.rm)} à ${court(unRm(80, 9))}, médaille d’argent ; 75 kg × 10 fait 10 répétitions là où le mieux à 75 kg ou plus lourd était de 8, médaille de bronze ; 80 kg × 8 égale ce qui a déjà été fait, rien. Le volume de l’exercice est de ${kg(volumeJour, 0)}. Quatre règles : une seule médaille par série, la plus haute ; il faut faire strictement mieux, et le 1RM estimé doit gagner plus de 0,05 kg ; l’échauffement ne compte ni dans le volume, ni dans le 1RM, ni dans les records ; un exercice fait pour la première fois ne bat aucun record, et au poids du corps seul compte le plus de répétitions. La même règle vaut pendant la séance, à la fin, sur l’accueil et dans les résumés ; par séance et par exercice, un or et un argent au plus, un bronze par charge.`);
};
