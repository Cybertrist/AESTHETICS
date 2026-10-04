// La progression des charges d'un programme.
//
// En haut, le réglage : les quatre modes, l'incrément, la semaine de
// décharge. Puis quatre cases, chacune avec un exemple chiffré qui se
// déroule de séance en séance : la charge progressive, la double
// progression, l'ondulée par semaine et la semaine de décharge.
//
// Les règles sont celles de
// features/entrainer/routines/logic/progression.dart et program_plan.dart ;
// les exercices et les charges des exemples sont inventés, les calculs
// refaits ici avec les mêmes formules.
module.exports = (O) => {
  const { svg, t, tr, fondu, visible, MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, ROSE, ROUGE } = O;

  const C = 30;
  const FIN = 0.985;
  const g = (de, contenu, a = FIN, douceur = 0.006) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  /// Un nombre à la française, que l'anglais réécrit avec un point.
  const nb = (v, d = 1) => {
    const s = (Math.round(v * 10 ** d) / 10 ** d).toString();
    return s.replace('.', ',');
  };

  // Les mêmes calculs que l'appli (core/logic/strength.dart).
  const epley = (p, r) => (r === 1 ? p : p * (1 + r / 30));
  const brzycki = (p, r) => (r === 1 ? p : (p * 36) / (37 - r));
  const unRm = (p, r) => (r <= 10 ? (epley(p, r) + brzycki(p, r)) / 2 : epley(p, r));
  const poidsPourReps = (rm, r) => (r <= 1 ? rm : rm / (1 + r / 30));
  const arrondir = (p, pas) => Math.round(p / pas) * pas;
  const PAS = 2.5;

  // Les quatre temps : un par case.
  const TA = 0.03, TB = 0.2, TC = 0.37, TD = 0.52;

  let corps = '';
  corps += t(60, 52, 'LA PROGRESSION DES CHARGES', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(60 + tr('LA PROGRESSION DES CHARGES').length * 10.9 + 32, 52, 'Lancée depuis un programme, la séance part de ce que tu as fait la dernière fois.', { taille: 14 });

  // ------------------------------------------------------- le réglage
  const RY = 76, RH = 92;
  corps += `<rect x="60" y="${RY}" width="1160" height="${RH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(82, RY + 27, 'PROGRESSION : UN RÉGLAGE PAR PROGRAMME', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const modes = [
    ['Aucune', 104, null, TEXTE],
    ['Charge progressive', 176, [TA, TB], VERT],
    ['Double progression', 176, [TB, TC], VERT],
    ['Ondulée par semaine', 186, [TC, TD], ACCENT],
  ];
  let mx = 82;
  modes.forEach(([nom, l, quand, c]) => {
    const y = RY + 40;
    corps += `<rect x="${mx}" y="${y}" width="${l}" height="36" rx="18" fill="${FOND}" stroke="${BORD}"/>`;
    if (quand) {
      corps += `<rect x="${mx}" y="${y}" width="${l}" height="36" rx="18" fill="${c}" fill-opacity="0.14" stroke="${c}" stroke-opacity="0.9" opacity="0">${visible(C, quand[0], quand[1] - 0.012, 0.006)}</rect>`;
    }
    corps += t(mx + l / 2, y + 23, nom, { taille: 13, couleur: quand ? TITRE : TEXTE, poids: 700, ancre: 'middle' });
    mx += l + 12;
  });
  // Les deux autres réglages du programme.
  const reglage = (x, l, titre, valeur, quand, c) => {
    let s = `<rect x="${x}" y="${RY + 16}" width="${l}" height="60" rx="12" fill="${FOND}" stroke="${BORD}"/>`;
    if (quand) s += `<rect x="${x}" y="${RY + 16}" width="${l}" height="60" rx="12" fill="${c}" fill-opacity="0.12" stroke="${c}" stroke-opacity="0.9" opacity="0">${visible(C, quand[0], quand[1], 0.006)}</rect>`;
    s += t(x + 16, RY + 40, titre, { taille: 12, couleur: TEXTE });
    s += t(x + 16, RY + 62, valeur, { taille: 14, couleur: TITRE, police: MONO, poids: 700 });
    return s;
  };
  corps += reglage(798, 178, 'Incrément de charge', `${nb(PAS)} kg`, null);
  corps += reglage(988, 214, 'Semaine de décharge', 'toutes les 4 semaines', [TD, FIN - 0.01], ROSE);

  // ------------------------------------------------------- les quatre cases
  const PL = 570, PH = 300;
  const cases = { a: [60, 188], b: [650, 188], c: [60, 508], d: [650, 508] };
  const cadre = ([x, y], titre, exemple, lignes, c, quand) => {
    let s = `<rect x="${x}" y="${y}" width="${PL}" height="${PH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${PL}" height="${PH}" rx="16" fill="${c}" fill-opacity="0.04" stroke="${c}" stroke-opacity="0.75" opacity="0">${visible(C, quand[0], quand[1] - 0.012, 0.006)}</rect>`;
    s += t(x + 20, y + 32, titre, { taille: 14.5, couleur: TITRE, police: MONO, poids: 700 });
    s += t(x + PL - 20, y + 32, exemple, { taille: 11.5, couleur: c, poids: 700, ancre: 'end' });
    lignes.forEach((l, i) => { s += t(x + 20, y + 54 + i * 16, l, { taille: 12 }); });
    return s;
  };
  const legende = ([x, y], s) => t(x + 20, y + PH - 20, s, { taille: 12, couleur: DISCRET });

  /// Une barre chargée : des disques de chaque côté, du plus gros au plus petit.
  const barre = (cx, cy, disques, c = TEXTE) => {
    let s = `<line x1="${cx - 40}" y1="${cy}" x2="${cx + 40}" y2="${cy}" stroke="${c}" stroke-width="2.5" stroke-linecap="round"/>`;
    disques.forEach((h, k) => {
      for (const cote of [-1, 1]) {
        const x = cx + cote * (14 + k * 7) - 2.5;
        s += `<rect x="${x}" y="${cy - h / 2}" width="5" height="${h}" rx="2" fill="${k === disques.length - 1 && disques.length > 2 ? VERT : c}"/>`;
      }
    });
    return s;
  };

  /// Une séance : la charge, la cible, les séries faites, ce que ça donne.
  const CL = 104, CH = 150, ECART = 38;
  const seance = ([px, py], k, de, { charge, disques, cible, faites, verdict, couleur, cibles }) => {
    const x = px + 20 + k * (CL + ECART), y = py + 96;
    let s = `<rect x="${x}" y="${y}" width="${CL}" height="${CH}" rx="12" fill="${FOND}" stroke="${BORD}"/>`;
    s += t(x + CL / 2, y + 19, `SÉANCE ${k + 1}`, { taille: 9.5, couleur: DISCRET, police: MONO, poids: 700, ancre: 'middle', extra: 'letter-spacing="1.5"' });
    s += t(x + CL / 2, y + 46, `${nb(charge)} kg`, { taille: 20, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' });
    s += barre(x + CL / 2, y + 66, disques);
    s += t(x + CL / 2, y + 92, cible, { taille: 11, couleur: TEXTE, ancre: 'middle' });
    // Les trois séries, cochées l'une après l'autre.
    [0, 1, 2].forEach((i) => {
      const cx = x + 13 + i * 27;
      s += `<rect x="${cx}" y="${y + 101}" width="24" height="22" rx="6" fill="none" stroke="${FIL}" stroke-dasharray="${faites ? '0' : '3 3'}"/>`;
      if (faites) {
        const ok = faites[i] >= cibles[i];
        const c = ok ? VERT : ROUGE;
        s += g(de + 0.012 + i * 0.01, `<rect x="${cx}" y="${y + 101}" width="24" height="22" rx="6" fill="${c}" fill-opacity="0.16" stroke="${c}" stroke-opacity="0.8"/>
          ${t(cx + 12, y + 116.5, String(faites[i]), { taille: 11.5, couleur: c, police: MONO, poids: 700, ancre: 'middle' })}`, FIN, 0.004);
      }
    });
    const quand = faites ? de + 0.044 : de + 0.012;
    s = g(de, s) + g(quand, t(x + CL / 2, y + 141, verdict, { taille: 10.5, couleur, poids: 700, ancre: 'middle' }));
    return s;
  };
  /// Entre deux séances : ce qui change.
  const pas = ([px, py], k, de, haut, bas, c) => {
    const x = px + 20 + k * (CL + ECART) + CL, y = py + 96 + CH / 2;
    return g(de, `<path d="M${x + 7} ${y} H${x + ECART - 9} m-5 -4 l5 4 l-5 4" fill="none" stroke="${c}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
      ${t(x + ECART / 2, y - 9, haut, { taille: 10.5, couleur: c, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(x + ECART / 2, y + 18, bas, { taille: 10, couleur: c, ancre: 'middle' })}`);
  };

  // --- Charge progressive : 3 × 8, pas de 2,5 kg.
  corps += cadre(cases.a, 'Charge progressive', `Développé couché · 3 × 8 · pas de ${nb(PAS)} kg`,
    ['Toutes les répétitions réussies la dernière fois : la charge monte', 'd’un incrément. Sinon, la même charge revient.'], VERT, [TA, TB]);
  {
    const d = 0.042;
    const s = [
      { charge: 60, disques: [20, 20], cible: '3 × 8 prévues', faites: [8, 8, 8], cibles: [8, 8, 8], verdict: 'tout est réussi', couleur: VERT },
      { charge: 62.5, disques: [20, 20, 9], cible: '3 × 8 prévues', faites: [8, 8, 6], cibles: [8, 8, 8], verdict: 'il manque 2 reps', couleur: ROUGE },
      { charge: 62.5, disques: [20, 20, 9], cible: '3 × 8 prévues', faites: [8, 8, 8], cibles: [8, 8, 8], verdict: 'tout est réussi', couleur: VERT },
      { charge: 65, disques: [20, 20, 14], cible: '3 × 8 prévues', faites: null, verdict: 'à faire', couleur: DISCRET },
    ];
    s.forEach((e, k) => { corps += seance(cases.a, k, TA + k * d, e); });
    corps += pas(cases.a, 0, TA + d - 0.008, `+${nb(PAS)}`, 'kg', VERT);
    corps += pas(cases.a, 1, TA + 2 * d - 0.008, '=', '', TEXTE);
    corps += pas(cases.a, 2, TA + 3 * d - 0.008, `+${nb(PAS)}`, 'kg', VERT);
  }
  corps += legende(cases.a, 'La référence : la dernière fois où l’exercice a été fait, séries cochées, hors échauffement.');

  // --- Double progression : fourchette de 8 à 10.
  corps += cadre(cases.b, 'Double progression', `Rowing barre · 3 séries de 8 à 10 · pas de ${nb(PAS)} kg`,
    ['On gagne une répétition par séance jusqu’au haut de la fourchette,', 'puis la charge monte et les répétitions repartent du bas.'], VERT, [TB, TC]);
  {
    const d = 0.042;
    const s = [
      { charge: 50, disques: [20, 14], cible: 'cible : 8 reps', faites: [8, 8, 8], cibles: [8, 8, 8], verdict: 'bas de fourchette', couleur: TEXTE },
      { charge: 50, disques: [20, 14], cible: 'cible : 9 reps', faites: [9, 9, 9], cibles: [9, 9, 9], verdict: 'une de plus', couleur: TEXTE },
      { charge: 50, disques: [20, 14], cible: 'cible : 10 reps', faites: [10, 10, 10], cibles: [10, 10, 10], verdict: 'haut atteint', couleur: VERT },
      { charge: 52.5, disques: [20, 14, 9], cible: 'cible : 8 reps', faites: null, verdict: 'à faire', couleur: DISCRET },
    ];
    s.forEach((e, k) => { corps += seance(cases.b, k, TB + k * d, e); });
    corps += pas(cases.b, 0, TB + d - 0.008, '+1', 'rep', TITRE);
    corps += pas(cases.b, 1, TB + 2 * d - 0.008, '+1', 'rep', TITRE);
    corps += pas(cases.b, 2, TB + 3 * d - 0.008, `+${nb(PAS)}`, 'kg', VERT);
  }
  corps += legende(cases.b, 'Tant qu’une série reste sous le haut de la fourchette, la charge ne bouge pas.');

  // --- Ondulée par semaine : la charge se calcule depuis le 1RM estimé.
  const rm = unRm(80, 8);
  corps += cadre(cases.c, 'Ondulée par semaine', `Squat · dernière fois 80 kg × 8 · 1RM estimé ${nb(rm)} kg`,
    ['Les semaines alternent lourd (5 reps), moyen (8 reps) et léger (12 reps).', 'Charge = 1RM ÷ (1 + reps ÷ 30) × 0,92, arrondie au pas.'], ACCENT, [TC, TD]);
  {
    const phases = [['lourde', 5, 8.5], ['moyenne', 8, 8], ['légère', 12, 7]];
    const L = 163, E = 20.5, [px, py] = cases.c;
    phases.forEach(([nom, reps, rpe], k) => {
      const x = px + 20 + k * (L + E), y = py + 96, de = TC + 0.012 + k * 0.046;
      const brut = poidsPourReps(rm, reps) * 0.92, kg = arrondir(brut, PAS);
      let s = `<rect x="${x}" y="${y}" width="${L}" height="${CH}" rx="12" fill="${FOND}" stroke="${BORD}"/>`;
      s += t(x + 14, y + 21, `SEMAINE ${k + 1}`, { taille: 9.5, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="1.5"' });
      s += t(x + L - 14, y + 21, nom, { taille: 11.5, couleur: ACCENT, poids: 700, ancre: 'end' });
      s += t(x + 14, y + 47, `${reps} reps · RPE ${nb(rpe)}`, { taille: 14, couleur: TITRE, poids: 700 });
      s = g(de, s);
      s += g(de + 0.016, t(x + 14, y + 70, `${nb(rm)} ÷ (1 + ${reps} ÷ 30)`, { taille: 10.5, couleur: TEXTE, police: MONO })
        + t(x + 14, y + 86, `× ${nb(0.92, 2)} = ${nb(brut)} kg`, { taille: 10.5, couleur: TEXTE, police: MONO }));
      s += g(de + 0.034, t(x + 14, y + 122, `${nb(kg)} kg`, { taille: 23, couleur: TITRE, police: MONO, poids: 700 })
        + `<rect x="${x + 14}" y="${y + 131}" width="${(L - 28) * (kg / 80)}" height="5" rx="2.5" fill="${ACCENT}"/>
          <rect x="${x + 14}" y="${y + 131}" width="${L - 28}" height="5" rx="2.5" fill="${ACCENT}" fill-opacity="0.18"/>`);
      corps += s;
    });
  }
  corps += legende(cases.c, 'La quatrième semaine repart sur une lourde. Le 1RM : le meilleur de la dernière séance.');

  // --- La semaine de décharge : toutes les 4 semaines ici.
  corps += cadre(cases.d, 'Semaine de décharge', 'une semaine sur 4 · 4 × 8 à 80 kg, RPE 8',
    ['Toutes les 4 semaines : moitié des séries, charge à 90 %.', 'Elle s’ajoute au mode choisi, et les échauffements restent.'], ROSE, [TD, FIN]);
  {
    const [px, py] = cases.d;
    // Huit semaines : la quatrième et la huitième sont allégées.
    const L = 58, E = 9.4, y = py + 90;
    for (let k = 0; k < 8; k++) {
      const x = px + 20 + k * (L + E), dech = (k + 1) % 4 === 0;
      corps += `<rect x="${x}" y="${y}" width="${L}" height="28" rx="9" fill="${FOND}" stroke="${BORD}"/>`;
      if (dech) corps += `<rect x="${x}" y="${y}" width="${L}" height="28" rx="9" fill="${ROSE}" fill-opacity="0.18" stroke="${ROSE}" stroke-opacity="0.9" opacity="0">${visible(C, TD + 0.012 + (k > 3 ? 0.012 : 0), FIN, 0.006)}</rect>`;
      corps += t(x + L / 2, y + 18.5, `S${k + 1}`, { taille: 11.5, couleur: dech ? TITRE : TEXTE, police: MONO, poids: 700, ancre: 'middle' });
    }
    // Avant, après.
    const ligne = (x, ly, l, n, texte, rpe, c, raye = false) => `<rect x="${x}" y="${ly}" width="${l}" height="22" rx="7" fill="${c}" fill-opacity="${raye ? 0 : 0.1}" stroke="${c}" stroke-opacity="${raye ? 0.35 : 0.5}" ${raye ? 'stroke-dasharray="3 3"' : ''}/>
      ${t(x + 14, ly + 15.5, String(n), { taille: 11, couleur: raye ? DISCRET : c, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(x + 30, ly + 15.5, texte, { taille: 11.5, couleur: raye ? DISCRET : TITRE, police: raye ? O.SANS : MONO, poids: raye ? 400 : 700 })}
      ${rpe ? t(x + l - 10, ly + 15.5, rpe, { taille: 10.5, couleur: TEXTE, ancre: 'end' }) : ''}`;
    const y0 = py + 150, GAUCHE = px + 20, DROITE = px + 300, LG = 220, LD = 250;
    const brut = 80 * 0.9, kg = arrondir(brut, PAS);
    let avant = t(GAUCHE, y0 - 8, 'PRÉVU CE JOUR-LÀ', { taille: 9.5, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="1.5"' });
    for (let i = 0; i < 4; i++) avant += ligne(GAUCHE, y0 + i * 26, LG, i + 1, '80 kg × 8', 'RPE 8', TEXTE);
    corps += g(TD + 0.04, avant);
    corps += g(TD + 0.075, `<path d="M${GAUCHE + LG + 14} ${y0 + 50} H${DROITE - 16} m-6 -5 l6 5 l-6 5" fill="none" stroke="${ROSE}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`);
    corps += g(TD + 0.075, t(DROITE, y0 - 8, 'EN SEMAINE DE DÉCHARGE', { taille: 9.5, couleur: ROSE, police: MONO, poids: 700, extra: 'letter-spacing="1.5"' }));
    for (let i = 0; i < 4; i++) {
      corps += g(TD + 0.09 + i * 0.014, i < 2 ? ligne(DROITE, y0 + i * 26, LD, i + 1, `${nb(kg)} kg × 8`, 'RPE 6', ROSE) : ligne(DROITE, y0 + i * 26, LD, i + 1, 'série retirée', '', DISCRET, true));
    }
    corps += g(TD + 0.16, legende(cases.d, `4 séries ÷ 2 = 2 · 80 × ${nb(0.9)} = ${nb(brut)}, arrondi au pas : ${nb(kg)} kg · RPE 8 − 2 = 6`));
  }

  corps += t(60, 838, '« Aucune » : les séries restent celles de la routine. La semaine du programme avance avec les séances terminées, pas avec le calendrier.', { taille: 13, couleur: DISCRET });

  svg('progression.svg', 1280, 862, corps,
    'La progression des charges d’un programme, en quatre exemples chiffrés. Le réglage se fait par programme : quatre modes, Aucune, Charge progressive, Double progression et Ondulée par semaine, un incrément de charge, ici 2,5 kg, et une semaine de décharge, ici toutes les 4 semaines. Charge progressive, au développé couché, 3 séries de 8 : à 60 kg tout est réussi, la séance suivante passe à 62,5 kg ; là, la troisième série s’arrête à 6 répétitions, la même charge revient ; réussie cette fois, elle monte à 65 kg. Double progression, au rowing barre, 3 séries de 8 à 10 répétitions à 50 kg : la cible passe de 8 à 9 puis à 10 répétitions, une de plus par séance ; le haut de la fourchette atteint partout, la charge monte à 52,5 kg et la cible revient à 8. Ondulée par semaine, au squat : la dernière séance, 80 kg pour 8 répétitions, donne un 1RM estimé de 100,3 kg, et la charge vaut le 1RM divisé par 1 plus les répétitions sur 30, multiplié par 0,92 et arrondi au pas ; semaine lourde, 5 répétitions à RPE 8,5, 80 kg ; semaine moyenne, 8 répétitions à RPE 8, 72,5 kg ; semaine légère, 12 répétitions à RPE 7, 65 kg ; la quatrième semaine repart sur une lourde. Semaine de décharge, la quatrième et la huitième : sur 4 séries de 8 à 80 kg et RPE 8, il en reste 2, à 72,5 kg, soit 90 % arrondis au pas, et RPE 6 ; les échauffements restent. Avec le mode Aucune, les séries restent celles de la routine. La semaine du programme avance avec les séances terminées, pas avec le calendrier.');
};
