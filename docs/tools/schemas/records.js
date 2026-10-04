// Le 1RM estimé et les records.
//
// En haut, une série passe dans les deux formules : 80 kg × 8 donne 101,33
// par Epley et 99,31 par Brzycki, leur moyenne 100,32 ; 60 kg × 12, au-delà
// de dix répétitions, ne garde qu'Epley, 84,00. En bas, la séance du jour
// (un échauffement et trois séries) est comparée aux meilleures valeurs des
// séances d'avant, pour les cinq types de record, puis les quatre règles.
//
// Les calculs, vérifiés au centième :
//   80 × (1 + 8/30) = 101,3333        80 × 36 / 29 = 99,3103      moyenne 100,3218
//   82,5 × (1 + 8/30) = 104,5000      82,5 × 36 / 29 = 102,4138   moyenne 103,4569
//   82,5 × (1 + 6/30) = 99,0000       82,5 × 36 / 31 = 95,8065    moyenne 97,4032
//   60 × (1 + 12/30) = 84,0000        60 × 36 / 25 = 86,4000      (écartée)
//   volumes : 660 + 495 + 640 = 1 795 ; avant : 640 + 640 + 560 = 1 840
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
  verifie('1RM 82,5 × 8', unRm(82.5, 8), '103,46');
  verifie('1RM 82,5 × 6', unRm(82.5, 6), '97,40');
  verifie('Epley 60 × 12', epley(60, 12), '84,00');
  verifie('Brzycki 60 × 12', brzycki(60, 12), '86,40');

  // Les instants du récit.
  const T = {
    ex1: 0.03, epley1: 0.07, brz1: 0.11, moy1: 0.15,
    ex2: 0.21, epley2: 0.25, brz2: 0.29, res2: 0.33,
    serie: (i) => 0.38 + i * 0.03, total: 0.5,
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
  const BY = 352;
  corps += `<line x1="60" y1="${BY - 20}" x2="1220" y2="${BY - 20}" stroke="${BORD}"/>`;
  corps += t(60, BY + 6, 'LES CINQ RECORDS, COMPARÉS À LA FIN DE LA SÉANCE', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });

  corps += t(1220, BY + 6, 'Avant : une seule séance, 80 kg × 8, 80 kg × 8 et 80 kg × 7.', { taille: 12, couleur: TEXTE, ancre: 'end' });
  // La séance du jour, à gauche.
  const SXg = 60, SLg = 410, SYg = BY + 22, SH = 244;
  corps += `<rect x="${SXg}" y="${SYg}" width="${SLg}" height="${SH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(SXg + 20, SYg + 28, 'Développé couché', { taille: 14.5, couleur: TITRE, poids: 700 });
  corps += t(SXg + SLg - 20, SYg + 28, 'la séance du jour', { taille: 12, couleur: DISCRET, ancre: 'end' });
  const CX = { serie: SXg + 36, charge: SXg + 130, volume: SXg + 262, rm: SXg + SLg - 22 };
  corps += [['Série', CX.serie, 'middle'], ['Charge × reps', CX.charge, 'middle'], ['Volume', CX.volume, 'end'], ['1RM estimé', CX.rm, 'end']]
    .map(([n, x, ancre]) => t(x, SYg + 54, n, { taille: 11, couleur: DISCRET, ancre })).join('');
  const series = [['É', 40, 10, false], ['1', 82.5, 8, true], ['2', 82.5, 6, true], ['3', 80, 8, true]];
  const RH = 34, R0 = SYg + 64;
  series.forEach(([nom, p, r, compte], i) => {
    const y = R0 + i * RH;
    const charge = `${fr(p, p % 1 ? 1 : 0)} kg × ${r}`;
    corps += g(T.serie(i), FIN, `${compte ? (i % 2 ? `<rect x="${SXg + 10}" y="${y}" width="${SLg - 20}" height="${RH}" rx="8" fill="#FFFFFF" fill-opacity="0.025"/>` : '')
      : `<rect x="${SXg + 10}" y="${y + 2}" width="${SLg - 20}" height="${RH - 4}" rx="8" fill="url(#hachures)" fill-opacity="0.9"/>`}
      ${t(CX.serie, y + 22, nom, { taille: 13.5, couleur: compte ? TITRE : OR, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(CX.charge, y + 22, charge, { taille: 13.5, couleur: compte ? TITRE : DISCRET, police: MONO, poids: 700, ancre: 'middle' })}
      ${compte
        ? t(CX.volume, y + 22, kg(p * r, 0), { taille: 13, couleur: TEXTE, police: MONO, ancre: 'end' }) + t(CX.rm, y + 22, fr(unRm(p, r)), { taille: 13, couleur: TEXTE, police: MONO, ancre: 'end' })
        : t(CX.rm, y + 22, 'échauffement : ne compte pas', { taille: 11.5, couleur: DISCRET, ancre: 'end' })}`);
  });
  const volumeJour = series.filter((s) => s[3]).reduce((a, [, p, r]) => a + p * r, 0);
  const rmJour = Math.max(...series.filter((s) => s[3]).map(([, p, r]) => unRm(p, r)));
  if (volumeJour !== 1795) throw new Error('records : volume du jour ' + volumeJour);
  const TYg = R0 + 4 * RH + 8;
  corps += `<line x1="${SXg + 20}" y1="${TYg}" x2="${SXg + SLg - 20}" y2="${TYg}" stroke="${BORD}"/>`;
  corps += g(T.total, FIN, `${t(SXg + 20, TYg + 23, 'Volume de l’exercice', { taille: 12.5, couleur: TEXTE })}
    ${t(CX.volume, TYg + 23, kg(volumeJour, 0), { taille: 13.5, couleur: TITRE, police: MONO, poids: 700, ancre: 'end' })}`);

  // Les cinq records, à droite : avant, aujourd'hui, le verdict.
  const TX = 490, TL = 730, TYt = SYg;
  corps += `<rect x="${TX}" y="${TYt}" width="${TL}" height="${SH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  const KX = { nom: TX + 22, avant: TX + 300, jour: TX + 452, verdict: TX + TL - 20 };
  corps += [['Type de record', KX.nom, 'start'], ['Avant', KX.avant, 'middle'], ['Aujourd’hui', KX.jour, 'middle'], ['Verdict', KX.verdict - 60, 'middle']]
    .map(([n, x, ancre]) => t(x, TYt + 28, n, { taille: 11, couleur: DISCRET, police: MONO, poids: 700, ancre, extra: 'letter-spacing="1.5"' })).join('');
  // La dernière fois : 80 × 8, 80 × 8, 80 × 7.
  const avant = { poids: 80, rm: unRm(80, 8), serie: 640, reps: 8, seance: 640 + 640 + 560 };
  const lignes = [
    ['Charge maximale', court(avant.poids), '', court(82.5), '', true, `+${court(82.5 - avant.poids)}`],
    ['1RM estimé', court(avant.rm), '80 kg × 8', court(rmJour), '82,5 kg × 8', true, `+${court(rmJour - avant.rm)}`],
    ['Meilleure série (volume)', kg(avant.serie, 0), '80 kg × 8', kg(660, 0), '82,5 kg × 8', true, `+${kg(660 - avant.serie, 0)}`],
    ['Répétitions maximales', '8', '', '8', '', false, 'égalité : rien'],
    ['Volume en une séance', kg(avant.seance, 0), '', kg(volumeJour, 0), '', false, 'en dessous : rien'],
  ];
  const QH = 40, Q0 = TYt + 40;
  lignes.forEach(([nom, av, avSous, jr, jrSous, battu, verdict], i) => {
    const y = Q0 + i * QH, de = T.rec(i), c = battu ? OR : DISCRET;
    const cellule = (x, v, sous, couleur) => (sous
      ? t(x, y + 19, v, { taille: 13.5, couleur, police: MONO, poids: 700, ancre: 'middle' }) + t(x, y + 33, sous, { taille: 10.5, couleur: DISCRET, ancre: 'middle' })
      : t(x, y + 25, v, { taille: 13.5, couleur, police: MONO, poids: 700, ancre: 'middle' }));
    corps += `<line x1="${TX + 16}" y1="${y}" x2="${TX + TL - 16}" y2="${y}" stroke="${BORD}"/>
      <rect x="${TX + 8}" y="${y + 3}" width="${TL - 16}" height="${QH - 6}" rx="9" fill="${c}" fill-opacity="0.07" stroke="${c}" stroke-opacity="0.7" opacity="0">${visible(C, de, de + 0.055, 0.006)}</rect>
      ${t(KX.nom, y + 25, nom, { taille: 13.5, couleur: TITRE, poids: 700 })}
      ${cellule(KX.avant, av, avSous, TEXTE)}
      ${g(de, FIN, `<path d="M${KX.avant + 62} ${y + 20} h22 m-5 -5 l5 5 l-5 5" fill="none" stroke="${FIL}" stroke-width="2"/>
        ${cellule(KX.jour, jr, jrSous, battu ? TITRE : TEXTE)}
        <rect x="${KX.verdict - 132}" y="${y + 8}" width="132" height="24" rx="12" fill="${c}" fill-opacity="${battu ? 0.14 : 0.08}" stroke="${c}" stroke-opacity="0.55"/>
        ${battu
          ? t(KX.verdict - 120, y + 24.5, 'RECORD', { taille: 10, couleur: OR, poids: 800, extra: 'letter-spacing="1"' }) + t(KX.verdict - 12, y + 24.5, verdict, { taille: 12, couleur: OR, police: MONO, poids: 700, ancre: 'end' })
          : t(KX.verdict - 66, y + 24.5, verdict, { taille: 11.5, couleur: TEXTE, poids: 700, ancre: 'middle' })}`)}`;
  });

  // Les quatre règles.
  const NY = BY + 22 + SH + 16, NH = 92, NL = 278, NG = (1160 - 4 * NL) / 3;
  const regles = [
    ['Strictement supérieur', ['Égaler l’ancienne valeur ne suffit pas :', '8 répétitions contre 8, ce n’est pas', 'un record.'], OR],
    ['L’échauffement ne compte pas', ['Ses 400 kg et ses 10 répétitions restent', 'hors du volume, du 1RM et des records.', 'Les onze autres types de série comptent.'], OR],
    ['Les répétitions, au poids du corps', ['Le record de répétitions ne vaut que', 'pour un exercice qui n’a jamais eu', 'de charge.'], VERT],
    ['Pas de record sans historique', ['Un exercice fait pour la première fois', 'n’en bat aucun : c’est une première.'], ROUGE],
  ];
  regles.forEach(([titre, texte, c], k) => {
    const x = 60 + k * (NL + NG), de = T.regle(k), a = k < 3 ? T.regle(k + 1) : FIN;
    corps += `<rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="${c}" fill-opacity="0.05" stroke="${c}" stroke-opacity="0.3"/>
      <rect x="${x}" y="${NY}" width="${NL}" height="${NH}" rx="12" fill="none" stroke="${c}" stroke-opacity="0.9" opacity="0">${visible(C, de, a, 0.006)}</rect>
      ${t(x + 18, NY + 27, titre, { taille: 13.5, couleur: TITRE, poids: 700 })}
      ${texte.map((s, i) => t(x + 18, NY + 47 + i * 16.5, s, { taille: 12, couleur: TEXTE })).join('')}`;
  });

  corps += t(60, NY + NH + 30, 'Pendant la séance, l’alerte de record suit trois repères : la charge maximale, le 1RM estimé (plus de 0,05 kg d’écart) et les répétitions à une charge donnée.', { taille: 13, couleur: DISCRET });

  svg('records.svg', 1280, NY + NH + 54, corps,
    'Le 1RM estimé et les records. Le 1RM estimé d’une série cochée, hors échauffement, se calcule par deux formules : Epley, poids × (1 + reps / 30), et Brzycki, poids × 36 / (37 − reps). Pour 80 kg × 8, Epley donne 101,33 kg et Brzycki 99,31 kg ; jusqu’à 10 répétitions on retient leur moyenne, 100,32 kg. Pour 60 kg × 12, au-delà de 10 répétitions, Brzycki (86,40 kg) est écartée et Epley seul donne 84,00 kg. À 1 répétition, le 1RM est la charge elle-même. À la fin de la séance, cinq types de record sont comparés aux meilleures valeurs des séances d’avant. Sur le développé couché, la séance du jour compte un échauffement de 40 kg × 10, puis 82,5 kg × 8, 82,5 kg × 6 et 80 kg × 8, soit 1 795 kg. Charge maximale : 80 kg avant, 82,5 kg aujourd’hui, record de 2,5 kg. 1RM estimé : 100,3 kg avant, 103,5 kg aujourd’hui, record de 3,1 kg. Meilleure série en volume : 640 kg avant, 660 kg aujourd’hui, record de 20 kg. Répétitions maximales : 8 contre 8, égalité, pas de record. Volume en une séance : 1 840 kg avant, 1 795 kg aujourd’hui, pas de record. Quatre règles : il faut dépasser strictement l’ancienne valeur ; l’échauffement ne compte ni dans le volume, ni dans le 1RM, ni dans les records ; le record de répétitions ne vaut que pour un exercice qui n’a jamais eu de charge ; un exercice fait pour la première fois ne bat aucun record. Pendant la séance, l’alerte de record suit la charge maximale, le 1RM estimé et les répétitions à une charge donnée.');
};
