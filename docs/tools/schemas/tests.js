// Les tests : ce que la suite contient, dossier par dossier.
//
// En haut, un compteur et un ruban de 98 cases, une par fichier de test :
// le compteur monte du nombre de cas que chaque fichier contient, jusqu'à
// 905. Les 92 fichiers de la musculation et de son socle passent d'abord,
// groupés par sous-dossier de mobile/test/ ; les 6 des modules rangés
// (coach, nutrition, santé) viennent à part. En bas, une carte par
// sous-dossier : ce qu'il vérifie, et un vrai nom de test tiré du code.
//
// Ce sont des comptages dans le texte, pas le résultat d'un lancement :
// rien ici ne dit qu'un test est passé. Les nombres par fichier viennent de
//   grep -cE '^\s*(test|testWidgets)\(' <fichier>
// sur mobile/test/**/*_test.dart : 543 test( et 362 testWidgets(, soit 905.
module.exports = (O) => {
  const { svg, t, tr, esc, visible, fondu, paliers, MONO, SANS, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, ROSE, INTERNE } = O;

  const C = 26, FIN = 0.985;
  const CLAIR = '#CFC7FF';
  const g = (de, a, contenu, douceur = 0.004) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  // Un nom du code : jamais traduit.
  const brut = (x, y, s, { taille = 13, couleur = TITRE, poids = 700, ancre = 'start' } = {}) =>
    `<text x="${x}" y="${y}" font-family="${MONO}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}">${esc(s)}</text>`;

  // Un paragraphe coupé à la largeur donnée, dans la langue du rendu.
  const chasse = (ch) => {
    if (ch === ' ' || ch === ' ') return 0.28;
    if (/[iljI.,;:'’!|()]/.test(ch)) return 0.27;
    if (/[ftr]/.test(ch)) return 0.35;
    if (/[mwMW]/.test(ch)) return 0.84;
    if (/[A-Z]/.test(ch)) return 0.65;
    if (/[0-9]/.test(ch)) return 0.56;
    return 0.51;
  };
  const largeur = (s, taille) => [...s].reduce((a, ch) => a + chasse(ch), 0) * taille;
  const couper = (s, l, taille) => {
    const insecable = s.replace(/ ([:;!?»])/g, ' $1').replace(/« /g, '« ');
    const lignes = [''];
    for (const m of insecable.split(' ')) {
      const der = lignes[lignes.length - 1];
      const essai = der ? `${der} ${m}` : m;
      if (der && largeur(essai, taille) > l) lignes.push(m);
      else lignes[lignes.length - 1] = essai;
    }
    return lignes;
  };
  const para = (x, y, s, l, { taille = 12.5, couleur = TEXTE, pas = 17 } = {}) =>
    `<text font-family="${SANS}" font-size="${taille}" fill="${couleur}">${couper(tr(s), l, taille)
      .map((li, k) => `<tspan x="${x}" y="${y + k * pas}">${esc(li)}</tspan>`).join('')}</text>`;

  // ------------------------------------------------------- les dossiers
  // [sous-dossier de mobile/test/, cas par fichier (ordre alphabétique des
  //  fichiers), ce qu'il vérifie, un vrai nom de test, son fichier]
  const dossiers = [
    ['seance', [23, 1, 2, 1, 5, 2, 6, 5, 5, 12, 5, 13, 6, 4, 5, 12, 9, 17],
      'La saisie des séries, le repos, les disques, la fin et l’enregistrement, le partage.',
      'deux appuis coup sur coup sur la coche valident la série une seule fois', 'test_saisie_series_test.dart'],
    ['entrainer', [15, 2, 17, 3, 8, 25, 10, 3, 8, 29, 13, 2, 4, 12, 15],
      'La bibliothèque d’exercices, les routines, les programmes et leurs éditeurs.',
      'exercice au poids du corps : seules les répétitions comptent', 'bibliotheque_test.dart'],
    ['progres', [6, 21, 1, 8, 7, 1, 3, 33, 22, 1, 14, 41, 35],
      'Les calculs, les statistiques, les objectifs, le résumé de l’année, la navigation.',
      'une séance encore ouverte ne compte nulle part', 'test_bilan_calculs_test.dart'],
    ['profil', [9, 22, 3, 22, 8, 2, 19, 26, 3],
      'Les badges, les unités, les mesures, les photos, les écrans du profil.',
      'la séance en cours ne compte pas ; les étapes suivent le nombre de séances', 'grades_test.dart'],
    ['import', [11, 20, 6, 1, 1, 16, 14, 12],
      'La lecture des CSV, le rapprochement des noms d’exercices, les doublons.',
      'matériel différent : jamais accepté seul', 'exercise_matcher_test.dart'],
    ['aujourdhui', [9, 32, 5, 1, 1, 1, 2, 2],
      'L’accueil, vide, étroit ou large, et le résumé du jour.',
      'deux séances le même jour : la pastille montre la première, comme le calendrier', 'accueil_defauts_test.dart'],
    ['inscription', [2, 1, 5, 2, 5, 1],
      'Le premier lancement, le brouillon, un profil abîmé à la bienvenue.',
      'le profil créé efface le brouillon, même si une sauvegarde était en attente', 'test_donnees_brouillon_test.dart'],
    ['parcours', [14, 11, 5, 17],
      'La navigation d’un écran à l’autre et les parcours de bout en bout.',
      '« Reprendre » rouvre la séance, le retour la réduit sans la perdre', 'test_transverse_navigation_test.dart'],
    ['core', [1, 9, 7, 5, 16, 5],
      'Les formats d’écriture, les modèles et leur relecture, les équivalents.',
      'douze types de série, anciens noms relus', 'equivalents_test.dart'],
    ['data', [1, 15],
      'Le catalogue d’exercices et le stockage : écritures, fichiers abîmés.',
      'atomique : aucun fichier temporaire ne reste, le contenu est complet', 'test_donnees_store_test.dart'],
    ['body', [4],
      'La carte du corps, avec la seule comparaison à une image de référence.',
      'chaque muscle du contrat a un masque sur au moins une vue du corps', 'body_map_test.dart'],
    ['fondation_rendu', [1, 8],
      'Le socle commun : contrastes, tailles des zones à toucher, rendu.',
      'le texte secondaire (#8E8E93) passe 4,5 sur le fond, la carte et la surface', 'test_transverse_socle_test.dart'],
    // Les modules rangés, comptés à part.
    ['coach', [14, 1]], ['nutrition', [4, 1]], ['sante', [1, 9]],
  ];
  const NM = 12; // les dossiers de la musculation et de son socle
  const somme = (l) => l.reduce((a, b) => a + b, 0);
  const fichiers = [];
  dossiers.forEach(([nom, cas], d) => cas.forEach((n) => fichiers.push({ d, n })));
  const N = fichiers.length, TOTAL = somme(fichiers.map((f) => f.n));
  const NF_MUSCU = somme(dossiers.slice(0, NM).map((d) => d[1].length)), CAS_MUSCU = somme(dossiers.slice(0, NM).map((d) => somme(d[1])));
  const NF_RANGES = N - NF_MUSCU, CAS_RANGES = TOTAL - CAS_MUSCU;
  if (N !== 98 || TOTAL !== 905 || NF_MUSCU !== 92 || CAS_MUSCU !== 875) throw new Error(`tests : ${N} fichiers, ${TOTAL} cas, ${NF_MUSCU}/${CAS_MUSCU}`);

  // L'instant où chaque fichier est compté. Un dossier prend un temps de
  // lecture, puis un pas par fichier ; les modules rangés viennent après
  // une pause.
  const debut = [], PAUSE = 0.02, PAS = 0.0045;
  {
    let s = 0.05, i = 0;
    dossiers.forEach(([, cas], d) => {
      if (d === NM) s += 0.03;
      debut[d] = s;
      cas.forEach((_, k) => { fichiers[i++].s = s + PAUSE * 0.5 + k * PAS; });
      s += PAUSE + cas.length * PAS;
    });
    debut.push(s);
  }
  const TOUT = debut[dossiers.length] + 0.005;

  let corps = '';
  corps += t(60, 52, 'LES TESTS', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(Math.round(66 + tr('LES TESTS').length * 10.9 + 24), 52, '905 cas de test écrits dans 98 fichiers : ce que vérifie chaque dossier, avec un vrai nom de test.', { taille: 14 });

  // ------------------------------------------------------- le déroulé
  const PX = 40, PY = 74, PL = 1200, PH = 176;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;

  // Le compteur : une valeur par fichier compté.
  {
    let cumul = 0, compteur = '';
    const valeurs = [0, ...fichiers.map((f) => (cumul += f.n))];
    valeurs.forEach((v, k) => {
      const de = k === 0 ? 0 : fichiers[k - 1].s, a = k === N ? null : fichiers[k].s;
      const etapes = k === 0 ? [[0, 1], [a, 0]] : a === null ? [[0, 0], [de, 1]] : [[0, 0], [de, 1], [a, 0]];
      compteur += `<text x="176" y="146"${k === N ? ` fill="${CLAIR}"` : ''} opacity="0">${v}${paliers('opacity', C, etapes)}</text>`;
    });
    corps += `<g font-family="${MONO}" font-size="54" font-weight="700" fill="${TITRE}" text-anchor="end">${compteur}</g>`;
  }
  corps += brut(184, 146, '/ 905', { taille: 21, couleur: DISCRET });
  corps += t(66, 173, 'cas de test écrits', { taille: 12.5, couleur: TEXTE });

  // La console : comment on compte, le fichier, un vrai nom de test.
  const KX = 284, KY = 92, KL = 932, KH = 84;
  corps += `<rect x="${KX}" y="${KY}" width="${KL}" height="${KH}" rx="11" fill="${FOND}" stroke="${BORD}"/>
    ${brut(KX + 20, KY + 30, '$', { couleur: ROSE })}
    ${brut(KX + 38, KY + 30, 'grep -cE "^\\s*(test|testWidgets)\\(" test/**/*_test.dart')}`;
  const ligne = (s, de, a, couleur = TITRE) => g(de, a, `${brut(KX + 20, KY + 61, '›', { taille: 15, couleur: ROSE })}
    ${t(KX + 40, KY + 61, s, { taille: 13.5, couleur })}`, 0.003);
  dossiers.forEach(([nom, cas, , test, fichier], d) => {
    const de = debut[d], a = debut[d + 1];
    const chemin = d < NM ? `test/${nom}/${fichier}` : `test/${nom}/`;
    corps += g(de, d + 1 === dossiers.length ? TOUT : a, brut(KX + KL - 20, KY + 30, chemin, { taille: 11.5, couleur: DISCRET, poids: 400, ancre: 'end' }), 0.003);
    if (d < NM) corps += ligne(test, de, a);
  });
  corps += ligne('les modules rangés, comptés à part : coach, nutrition, santé', debut[NM], TOUT, TEXTE);
  corps += ligne('905 cas écrits : 875 pour la musculation et son socle, 30 pour les modules rangés.', TOUT, FIN, CLAIR);

  // Le ruban : une case par fichier, un groupe par dossier.
  const RX = 66, RL = 1148, RY = 192, PETIT = 6, GRAND = 26;
  const pasCase = (RL - (dossiers.length - 2) * PETIT - GRAND) / N, CL = pasCase - 3;
  const xCase = (i) => RX + i * pasCase + fichiers[i].d * PETIT + (fichiers[i].d >= NM ? GRAND - PETIT : 0);
  let ruban = '';
  fichiers.forEach((f, i) => {
    const x = xCase(i).toFixed(1), range = f.d >= NM;
    ruban += `<rect x="${x}" y="${RY}" width="${CL.toFixed(1)}" height="20" rx="3" fill="${range ? 'url(#hachures)' : '#1D1C2A'}" stroke="${BORD}"/>
      <rect x="${x}" y="${RY}" width="${CL.toFixed(1)}" height="20" rx="3" fill="${range ? INTERNE : ROSE}" opacity="0">${fondu('opacity', C, [[0, 0], [f.s, 0], [f.s + 0.002, range ? 0.75 : 1], [FIN, range ? 0.75 : 1], [FIN + 0.006, 0], [1, 0]])}</rect>`;
  });
  // Le curseur, sur le fichier qu'on compte.
  {
    const pos = fichiers.map((f, i) => [i === 0 ? 0 : fichiers[i - 1].s + 0.0001, xCase(i).toFixed(1)]);
    pos.push([fichiers[N - 1].s + 0.0001, xCase(N - 1).toFixed(1)], [1, xCase(N - 1).toFixed(1)]);
    ruban += `<rect y="${RY - 3}" width="${(CL + 4).toFixed(1)}" height="26" rx="5" fill="none" stroke="#FFFFFF" stroke-width="1.5" filter="url(#halo)" opacity="0" transform="translate(-2,0)">
      ${paliers('x', C, pos)}${fondu('opacity', C, [[0, 0], [0.045, 0], [0.05, 1], [fichiers[N - 1].s, 1], [fichiers[N - 1].s + 0.005, 0], [1, 0]])}</rect>`;
  }
  corps += ruban;
  const finMuscu = xCase(NF_MUSCU - 1) + CL;
  corps += `<path d="M${RX} ${RY + 27} H${finMuscu.toFixed(1)}" stroke="${ROSE}" stroke-opacity="0.7" stroke-width="2"/>
    <path d="M${xCase(NF_MUSCU).toFixed(1)} ${RY + 27} H${RX + RL}" stroke="${INTERNE}" stroke-opacity="0.7" stroke-width="2"/>`;
  corps += brut(RX, RY + 44, String(NF_MUSCU), { taille: 12.5 });
  corps += t(RX + 24, RY + 44, 'fichiers, 875 cas : la musculation et son socle, un groupe de cases par dossier', { taille: 12.5 });
  corps += t(RX + RL, RY + 44, '6 fichiers, 30 cas : modules rangés', { taille: 12.5, ancre: 'end' });

  // ------------------------------------------------------- les familles
  const CY0 = PY + PH + 14, CW = 392, CH = 120, CG = 10;
  const pastille = (ox, oy, s, n) => `<circle cx="${ox}" cy="${oy}" r="13" fill="none" stroke="${FIL}" stroke-width="2" stroke-dasharray="4 4"/>
    ${g(s, FIN, `<circle cx="${ox}" cy="${oy}" r="13" fill="${ROSE}"/>
      <text x="${ox}" y="${oy + 4.2}" font-family="${MONO}" font-size="12" font-weight="800" fill="#000000" text-anchor="middle">${n}</text>`, 0.003)}
    <circle cx="${ox}" cy="${oy}" r="13" fill="none" stroke="${CLAIR}" stroke-width="2" opacity="0">
      ${fondu('opacity', C, [[0, 0], [s, 0], [s + 0.002, 0.9], [s + 0.05, 0], [1, 0]])}${fondu('r', C, [[0, 13], [s, 13], [s + 0.05, 29], [1, 29]])}</circle>`;
  const cadre = (x, y, l, h, s) => `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
    <rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="${ROSE}" fill-opacity="0.04" stroke="${ROSE}" stroke-opacity="0.45" opacity="0">${visible(C, s, FIN, 0.004)}</rect>
    <rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="none" stroke="${ROSE}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, s, s + 0.06, 0.006)}</rect>`;
  dossiers.slice(0, NM).forEach(([nom, cas, texte, test], k) => {
    const x = PX + (k % 3) * (CW + CG), y = CY0 + Math.floor(k / 3) * (CH + CG), s = debut[k];
    corps += `${cadre(x, y, CW, CH, s)}
      ${pastille(x + 31, y + 29, s, cas.length)}
      ${brut(x + 56, y + 34, `test/${nom}/`, { taille: 14.5 })}
      <text x="${x + CW - 20}" y="${y + 34}" font-family="${MONO}" font-size="12" font-weight="700" fill="${TEXTE}" text-anchor="end">${somme(cas)} ${esc(tr('cas'))}</text>
      ${para(x + 56, y + 56, texte, CW - 56 - 22)}
      ${brut(x + 40, y + 93, '›', { taille: 14, couleur: ROSE })}
      ${para(x + 56, y + 93, test, CW - 56 - 22, { taille: 12, couleur: CLAIR, pas: 16 })}`;
  });
  // Deux bandes : les modules rangés, et ce que ces chiffres sont.
  const BY = CY0 + 4 * (CH + CG), BH = 80, BL = (PL - CG) / 2;
  corps += `${cadre(PX, BY, BL, BH, debut[NM])}
    ${pastille(PX + 31, BY + 29, debut[NM], NF_RANGES)}
    ${t(PX + 56, BY + 34, 'Modules rangés', { taille: 14.5, couleur: TITRE, police: MONO, poids: 700 })}
    <text x="${PX + BL - 20}" y="${BY + 34}" font-family="${MONO}" font-size="12" font-weight="700" fill="${TEXTE}" text-anchor="end">${CAS_RANGES} ${esc(tr('cas'))}</text>
    ${para(PX + 56, BY + 55, 'test/coach/, test/nutrition/ et test/sante/ : les tests de trois modules cachés par défaut. Ils sont écrits, et comptés à part.', BL - 56 - 22)}`;
  const BX2 = PX + BL + CG;
  corps += `${cadre(BX2, BY, BL, BH, TOUT)}
    ${pastille(BX2 + 31, BY + 29, TOUT, '∑')}
    ${t(BX2 + 56, BY + 34, 'Comptés, pas lancés', { taille: 14.5, couleur: TITRE, police: MONO, poids: 700 })}
    ${para(BX2 + 56, BY + 55, 'Des appels lus dans le texte : 543 test( et 362 testWidgets(. Huit sont marqués skip : trois pour des défauts connus, cinq sous condition.', BL - 56 - 22)}`;

  svg('tests.svg', 1280, BY + BH + 22, corps,
    'Les tests d’AESTHETICS, comptés fichier par fichier. Un compteur monte de 0 à 905 et un ruban de 98 cases s’allume, une case par fichier de test, groupées par sous-dossier de mobile/test : d’abord les 92 fichiers et 875 cas de la musculation et de son socle, puis, à part, les 6 fichiers et 30 cas des modules rangés. Ce sont des cas de test écrits, comptés dans le texte par grep, pas le résultat d’un lancement. Chaque dossier s’allume à son tour, avec ce qu’il vérifie et un vrai nom de test. test/seance, 18 fichiers, 133 cas : la saisie des séries, le repos, les disques, la fin et l’enregistrement, le partage ; par exemple, deux appuis coup sur coup sur la coche valident la série une seule fois. test/entrainer, 15 fichiers, 166 cas : la bibliothèque d’exercices, les routines, les programmes et leurs éditeurs ; exercice au poids du corps, seules les répétitions comptent. test/progres, 13 fichiers, 193 cas : les calculs, les statistiques, les objectifs, le résumé de l’année, la navigation ; une séance encore ouverte ne compte nulle part. test/profil, 9 fichiers, 114 cas : les badges, les unités, les mesures, les photos, les écrans du profil ; la séance en cours ne compte pas, les étapes suivent le nombre de séances. test/import, 8 fichiers, 81 cas : la lecture des CSV, le rapprochement des noms d’exercices, les doublons ; matériel différent, jamais accepté seul. test/aujourdhui, 8 fichiers, 53 cas : l’accueil, vide, étroit ou large, et le résumé du jour ; deux séances le même jour, la pastille montre la première, comme le calendrier. test/inscription, 6 fichiers, 16 cas : le premier lancement, le brouillon, un profil abîmé à la bienvenue ; le profil créé efface le brouillon, même si une sauvegarde était en attente. test/parcours, 4 fichiers, 47 cas : la navigation d’un écran à l’autre et les parcours de bout en bout ; Reprendre rouvre la séance, le retour la réduit sans la perdre. test/core, 6 fichiers, 43 cas : les formats d’écriture, les modèles et leur relecture, les équivalents ; douze types de série, anciens noms relus. test/data, 2 fichiers, 16 cas : le catalogue d’exercices et le stockage, écritures et fichiers abîmés ; atomique, aucun fichier temporaire ne reste, le contenu est complet. test/body, 1 fichier, 4 cas : la carte du corps, avec la seule comparaison à une image de référence ; chaque muscle du contrat a un masque sur au moins une vue du corps. test/fondation_rendu, 2 fichiers, 9 cas : le socle commun, contrastes, tailles des zones à toucher, rendu ; le texte secondaire passe 4,5 sur le fond, la carte et la surface. Modules rangés, 6 fichiers, 30 cas : test/coach, test/nutrition et test/sante, les tests de trois modules cachés par défaut, écrits et comptés à part. Comptés, pas lancés : des appels lus dans le texte, 543 test( et 362 testWidgets( ; huit portent un skip, trois pour des défauts connus, cinq sous condition.');
};
