// Reprendre son historique : un fichier CSV devient des séances.
//
// En haut à gauche, le fichier exporté par une autre appli : ses colonnes
// sont reconnues une à une, puis ses lignes sont lues et deviennent, à côté,
// deux séances et leurs séries. Dessous, chaque nom d'exercice est rapproché
// du catalogue : normalisé, cherché dans la table de synonymes, puis parmi
// les noms identiques, puis noté par ressemblance. Trois noms passent seuls,
// le quatrième hésite entre deux exercices : sur le téléphone, l'étape
// « Exercices » le montre avant d'importer, et un toucher tranche.
//
// Les scores de l'exemple sont ceux que donne le calcul de l'appli
// (lib/features/import/logic/exercise_matcher.dart) sur son catalogue.
module.exports = (O) => {
  const {
    svg, t, visible, fondu, toucher, APP, EN, esc,
    MONO, SANS, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, OR,
  } = O;

  const C = 30;
  const FIN = 0.985;
  const g = (de, a, contenu, douceur = 0.005) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  /// Un texte repris tel quel dans les deux langues : le contenu du fichier,
  /// une clé normalisée. Seule la virgule décimale suit la langue.
  const dec = (s) => (EN ? String(s).replace(/(\d),(\d)/g, '$1.$2') : String(s));
  const brut = (x, y, s, { taille = 11, couleur = TEXTE, police = MONO, poids = 400, ancre = 'start' } = {}) =>
    `<text x="${x}" y="${y}" font-family="${police}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}">${esc(s)}</text>`;
  const coche = (x, y, c = VERT) => `<circle cx="${x}" cy="${y}" r="7" fill="${c}" fill-opacity="0.15" stroke="${c}" stroke-opacity="0.6"/>
    <path d="M${x - 3} ${y} l2 2 l4 -4" fill="none" stroke="${c}" stroke-width="1.6"/>`;

  // Les instants du récit.
  const T = {
    parcourir: 0.02, col: (i) => 0.045 + i * 0.022, ligne: (i) => 0.165 + i * 0.028, bilan: 0.345,
    rang: (r) => 0.385 + r * 0.08, exos: 0.705, touche: 0.8, choisi: 0.815,
  };

  let corps = '';
  corps += t(60, 52, 'REPRENDRE SON HISTORIQUE', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(352, 52, 'Le fichier CSV d’une autre appli devient des séances, des séries et des records, sans rien ressaisir.', { taille: 14 });

  // ------------------------------------------------------------ le fichier
  const AX = 60, AY = 80, AL = 456, AH = 258;
  corps += `<rect x="${AX}" y="${AY}" width="${AL}" height="${AH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(AX + 22, AY + 30, 'LE FICHIER EXPORTÉ PAR TON ANCIENNE APPLI', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  corps += `<g transform="translate(${AX + 22},${AY + 42}) scale(0.62)"><path d="M6 2 H17 L23 8 V26 H6 Z M17 2 V8 H23" fill="none" stroke="${TEXTE}" stroke-width="2.4" stroke-linejoin="round"/></g>`;
  corps += brut(AX + 44, AY + 56, 'export.csv', { taille: 12.5, couleur: TITRE, poids: 700 });
  corps += t(AX + 126, AY + 56, 'le séparateur « ; » est trouvé sur l’en-tête', { taille: 11.5, couleur: DISCRET });
  // L'en-tête : chaque colonne est reconnue.
  const COLS = [['Date', 52, 'Date'], ['Séance', 66, 'Nom de la séance'], ['Exercice', 74, 'Exercice'], ['Charge (kg)', 94, 'Charge, en kilos'], ['Répétitions', 94, 'Répétitions']];
  let cx = AX + 22;
  COLS.forEach(([entete, l, champ], i) => {
    const y = AY + 70, de = T.col(i);
    corps += `<rect x="${cx}" y="${y}" width="${l}" height="24" rx="8" fill="#101216" stroke="${BORD}"/>`;
    corps += `<rect x="${cx}" y="${y}" width="${l}" height="24" rx="8" fill="${VERT}" fill-opacity="0.1" stroke="${VERT}" stroke-opacity="0.6" opacity="0">${visible(C, de, FIN, 0.005)}</rect>`;
    corps += brut(cx + l / 2, y + 16, entete, { taille: 10.5, couleur: TITRE, poids: 700, ancre: 'middle' });
    corps += g(de, FIN, t(cx + l / 2, y + 39, champ, { taille: 9.5, couleur: VERT, poids: 700, ancre: 'middle' }));
    cx += l + 8;
  });
  // Les lignes, lues l'une après l'autre.
  const LIGNES = [
    ['2026-03-02 18:30', 'Haut du corps', 'Développé couché barre', '80', '8'],
    ['2026-03-02 18:30', 'Haut du corps', 'Développé couché barre', '80', '7'],
    ['2026-03-02 18:30', 'Haut du corps', 'Tirage horizontal poulie', '55', '10'],
    ['2026-03-04 18:45', 'Jambes', 'Squats', '100', '5'],
    ['2026-03-04 18:45', 'Jambes', 'Squat avant barre', '60', '8'],
    ['2026-03-04 18:45', 'Jambes', 'Squat avant barre', '62,5', '6'],
  ];
  LIGNES.forEach((l, i) => {
    const y = AY + 136 + i * 17;
    corps += `<rect x="${AX + 14}" y="${y - 12}" width="${AL - 28}" height="17" rx="5" fill="${VERT}" fill-opacity="0.14" opacity="0">${visible(C, T.ligne(i), T.ligne(i + 1), 0.004)}</rect>`;
    corps += brut(AX + 22, y, l.join(';'), { taille: 10.5, couleur: DISCRET });
    corps += g(T.ligne(i), FIN, brut(AX + 22, y, l.join(';'), { taille: 10.5, couleur: TITRE }));
  });
  corps += t(AX + 22, AY + 243, '« 62,5 » : la virgule décimale est comprise. Tout est enregistré en kilos.', { taille: 11, couleur: DISCRET });

  // ------------------------------------------------------------ les séances
  const BX = 532, BY = 80, BL = 364, BH = 258;
  corps += `<rect x="${BX}" y="${BY}" width="${BL}" height="${BH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(BX + 22, BY + 30, 'SES LIGNES DEVIENNENT DES SÉANCES', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  // [titre, date, [nom, [[charge, reps, ligne]]]]
  const SEANCES = [
    ['Haut du corps', '2 mars 2026 · 18 h 30', [['Développé couché barre', [['80', '8', 0], ['80', '7', 1]]], ['Tirage horizontal poulie', [['55', '10', 2]]]]],
    ['Jambes', '4 mars 2026 · 18 h 45', [['Squats', [['100', '5', 3]]], ['Squat avant barre', [['60', '8', 4], ['62,5', '6', 5]]]]],
  ];
  SEANCES.forEach(([titre, date, exos], k) => {
    const y = BY + 44 + k * 82, de = T.ligne(exos[0][1][0][2]);
    let s = `<rect x="${BX + 14}" y="${y}" width="${BL - 28}" height="76" rx="12" fill="#101216" stroke="${BORD}"/>
      ${brut(BX + 28, y + 21, titre, { taille: 13, couleur: TITRE, police: SANS, poids: 700 })}
      ${t(BX + BL - 28, y + 21, date, { taille: 11, couleur: DISCRET, ancre: 'end' })}`;
    corps += g(de, FIN, s);
    exos.forEach(([nom, series], e) => {
      const ye = y + 43 + e * 22;
      corps += g(T.ligne(series[0][2]), FIN, brut(BX + 28, ye, nom, { taille: 11.5, couleur: TEXTE, police: SANS }));
      // Les séries, de droite à gauche.
      [...series].reverse().forEach(([charge, reps, ligne], n) => {
        const x = BX + BL - 28 - n * 76;
        corps += g(T.ligne(ligne), FIN, `<rect x="${x - 70}" y="${ye - 13}" width="70" height="18" rx="9" fill="${VERT}" fill-opacity="0.1" stroke="${VERT}" stroke-opacity="0.45"/>
          ${brut(x - 35, ye, `${dec(charge)} kg × ${reps}`, { taille: 10, couleur: VERT, poids: 700, ancre: 'middle' })}`);
      });
    });
  });
  corps += t(BX + 22, BY + 220, 'Même date et même titre : une séance.', { taille: 11, couleur: DISCRET });
  corps += t(BX + 22, BY + 234, 'Lignes qui se suivent pour un même exercice : ses séries.', { taille: 11, couleur: DISCRET });
  corps += g(T.bilan, FIN, t(BX + 22, BY + 249, '6 lignes lues : 2 séances, 4 exercices, 6 séries.', { taille: 11, couleur: VERT, poids: 700 }));

  // ------------------------------------------------------------ le rapprochement
  const RX = 60, RY = 354, RL = 836, RH = 328;
  corps += `<rect x="${RX}" y="${RY}" width="${RL}" height="${RH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(RX + 22, RY + 30, 'CHAQUE NOM EST RAPPROCHÉ DU CATALOGUE', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  corps += t(RX + RL - 22, RY + 30, 'dans l’ordre : tes choix passés, la table, le nom identique, la ressemblance', { taille: 11.5, couleur: TEXTE, ancre: 'end' });
  const K1 = RX + 28, K2 = RX + 214, K3 = RX + 398, K4 = RX + 648;
  [[K1, 'DANS LE FICHIER'], [K2, 'NORMALISÉ'], [K3, 'PAR OÙ IL PASSE'], [K4, 'DANS L’APPLI']].forEach(([x, s]) => {
    corps += t(x, RY + 56, s, { taille: 9.5, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="1.5"' });
  });
  // L'axe des scores, de 0,60 à 1 : le seuil est à 0,90.
  const AX0 = K3 + 96, AXL = 132;
  const sx = (v) => AX0 + ((v - 0.6) / 0.4) * AXL;
  const axe = (y, points, c) => `<line x1="${AX0}" y1="${y}" x2="${AX0 + AXL}" y2="${y}" stroke="${FIL}" stroke-width="2" stroke-linecap="round"/>
    <rect x="${sx(0.9)}" y="${y - 1}" width="${AX0 + AXL - sx(0.9)}" height="2" fill="${VERT}" fill-opacity="0.7"/>
    <line x1="${sx(0.9)}" y1="${y - 7}" x2="${sx(0.9)}" y2="${y + 7}" stroke="${VERT}" stroke-width="1.5"/>
    ${brut(sx(0.9), y - 10, dec('0,90'), { taille: 8.5, couleur: VERT, poids: 700, ancre: 'middle' })}
    ${points.map((v, k) => `<circle cx="${sx(v)}" cy="${y}" r="${k === 0 ? 5 : 3.5}" fill="${k === 0 ? c : DISCRET}" stroke="${CARTE}" stroke-width="1.5"/>`).join('')}`;
  // [nom, compte, clé normalisée, voie, détail, scores, résultat, verdict, couleur]
  const NOMS = [
    ['Développé couché barre', '2 séries · 1 séance', 'bench press barbell', 'table de synonymes', 'une de ses 85 entrées, l’ordre des mots ignoré', null, '→ Développé couché', 'Reconnu automatiquement', VERT],
    ['Squats', '1 série · 1 séance', 'squat', 'nom identique', 'la même clé qu’un nom du catalogue', null, '→ Squat', 'Nom identique', VERT],
    ['Tirage horizontal poulie', '1 série · 1 séance', 'seated row cable', 'ressemblance', '0,97 ; le suivant à 0,85 : écart de 0,12', [0.97, 0.85], '→ Tirage horizontal', 'Reconnu automatiquement', VERT],
    ['Squat avant barre', '2 séries · 1 séance', 'squat avant barbell', 'ressemblance', '0,84 et 0,70 : aucun n’atteint 0,90', [0.84, 0.7], '→ Squat ou Squat avant ?', 'À confirmer', OR],
  ];
  NOMS.forEach(([nom, compte, cle, voie, detail, scores, resultat, verdict, c], r) => {
    const y = RY + 66 + r * 56, t0 = T.rang(r), t1 = t0 + 0.022, t2 = t0 + 0.046, dernier = r === 3;
    corps += `<rect x="${RX + 14}" y="${y}" width="${RL - 28}" height="50" rx="12" fill="#101216" stroke="${BORD}"/>`;
    corps += `<rect x="${RX + 14}" y="${y}" width="${RL - 28}" height="50" rx="12" fill="${c}" fill-opacity="0.04" stroke="${c}" stroke-opacity="0.4" opacity="0">${visible(C, t2, dernier ? T.choisi : FIN, 0.005)}</rect>`;
    corps += brut(K1, y + 22, nom, { taille: 12.5, couleur: TITRE, police: SANS, poids: 700 });
    corps += t(K1, y + 38, compte, { taille: 10.5, couleur: DISCRET });
    // La clé : minuscules, sans accents, mots ramenés à une forme unique.
    corps += g(t0, FIN, `<path d="M${K2 - 22} ${y + 25} h10 m-4 -4 l4 4 l-4 4" fill="none" stroke="${FIL}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
      <rect x="${K2}" y="${y + 13}" width="160" height="24" rx="8" fill="${CARTE}" stroke="${BORD}"/>
      ${brut(K2 + 80, y + 29, cle, { taille: 11, couleur: TITRE, ancre: 'middle' })}`);
    corps += g(t1, FIN, `${t(K3, y + 22, voie, { taille: 11.5, couleur: TITRE, poids: 700 })}
      ${t(K3, y + 38, detail, { taille: 10.5, couleur: TEXTE })}
      ${scores ? axe(y + 18, scores, c) : ''}`);
    const issue = (res, ver, cv) => `${t(K4, y + 22, res, { taille: 12.5, couleur: TITRE, poids: 700 })}${t(K4, y + 38, ver, { taille: 10.5, couleur: cv, poids: 700 })}`;
    if (!dernier) {
      corps += g(t2, FIN, issue(resultat, verdict, c));
    } else {
      corps += g(t2, T.choisi, issue(resultat, verdict, c));
      corps += g(T.choisi, FIN, issue('→ Squat avant', 'Choisi par toi', VERT));
      corps += `<rect x="${RX + 14}" y="${y}" width="${RL - 28}" height="50" rx="12" fill="${VERT}" fill-opacity="0.04" stroke="${VERT}" stroke-opacity="0.5" opacity="0">${visible(C, T.choisi, FIN, 0.005)}</rect>`;
      corps += `<rect x="${RX + 14}" y="${y}" width="${RL - 28}" height="50" rx="12" fill="none" stroke="${OR}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, t2, T.choisi, 0.005)}</rect>`;
    }
  });
  // Les règles du calcul.
  const regles = ['seul si score ≥ 0,90 et écart ≥ 0,05', 'sous 0,60, rien n’est proposé', '0,8 × mots pondérés + 0,2 × lettres'];
  let rx = RX + 22;
  regles.forEach((s) => {
    corps += `${coche(rx + 8, RY + 304)}${t(rx + 22, RY + 308.5, s, { taille: 12, couleur: TEXTE })}`;
    rx += s.length * 6.3 + 34 + 26;
  });
  corps += t(RX, 716, 'Un nom ambigu est toujours montré avant d’importer. Ton choix est retenu pour les prochains imports, et chaque import peut être revu ou annulé.', { taille: 13, couleur: DISCRET });

  // ------------------------------------------------------------ le téléphone
  const PX = 916, PY = 80, PL = 304, PH = 612;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="ecranImport"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  const carteApp = (x, y, l, h, extra = '') => `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="16" fill="${APP.carte}" ${extra}/>`;
  const entete = (titre, sous, etape, libelle) => `<path d="M${SX + 24} ${SY + 38} l-7 7 l7 7" fill="none" stroke="${APP.texte}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    ${t(SX + 40, SY + 46, titre, { taille: 18, couleur: APP.texte, poids: 800 })}
    ${t(SX + 40, SY + 63, sous, { taille: 10.5, couleur: APP.second })}
    ${[0, 1, 2, 3, 4].map((i) => `<rect x="${SX + 20 + i * ((SL - 40 + 4) / 5)}" y="${SY + 80}" width="${(SL - 40 + 4) / 5 - 4}" height="4" rx="2" fill="${i <= etape ? APP.texte : APP.carte3}"/>`).join('')}
    ${t(SX + 20, SY + 101, libelle, { taille: 9, couleur: APP.second, poids: 700, extra: 'letter-spacing="1.2"' })}`;
  const halo = (x, y, r, dessin) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${APP.carte2}"/>${dessin}`;
  let ecran = '';

  // 1. Le fichier : « Parcourir », puis l'analyse.
  const ZY = SY + 164, ZH = 196, ZC = SX + SL / 2;
  const conseils = [
    ['Dans ton ancienne appli, ouvre les réglages', 'ou ton profil et cherche « Exporter les', 'données » ou « Exporter en CSV ».'],
    ['Enregistre le fichier sur le téléphone ou', 'envoie-le toi par mail, puis reviens ici.'],
    ['Le format est reconnu tout seul : séances,', 'séries, charges, répétitions, échauffements', 'et supersets.'],
  ];
  let cy = SY + 404;
  const liste = conseils.map((lignes, i) => {
    const s = `<circle cx="${SX + 36}" cy="${cy + 9}" r="10" fill="${APP.carte2}"/>${brut(SX + 36, cy + 13, i + 1, { taille: 10, couleur: APP.texte, police: SANS, poids: 700, ancre: 'middle' })}
      ${lignes.map((l, k) => t(SX + 56, cy + 12 + k * 13.5, l, { taille: 10, couleur: APP.second })).join('')}`;
    cy += lignes.length * 13.5 + 12;
    return s;
  }).join('');
  ecran += g(0.004, T.exos, `${entete('Importer un historique', 'Une autre application de suivi (CSV)', 0, 'ÉTAPE 1 SUR 5 · FICHIER')}
    <rect x="${SX + 16}" y="${SY + 116}" width="${SL - 32}" height="32" rx="16" fill="${APP.carte}"/>
    <rect x="${SX + 18}" y="${SY + 118}" width="${(SL - 36) / 2}" height="28" rx="14" fill="#FFFFFF"/>
    ${t(SX + 18 + (SL - 36) / 4, SY + 136, 'Autre application', { taille: 11, couleur: '#000', poids: 700, ancre: 'middle' })}
    ${t(SX + 18 + (SL - 36) * 0.75, SY + 136, 'Tableau', { taille: 11, couleur: APP.second, poids: 700, ancre: 'middle' })}
    ${carteApp(SX + 16, ZY, SL - 32, ZH, `stroke="${APP.discret}"`)}
    ${g(0.004, T.parcourir + 0.014, `${halo(ZC, ZY + 48, 24, `<path d="M${ZC - 8} ${ZY + 38} h10 l6 6 v14 h-16 z M${ZC} ${ZY + 55} v-9 m-4 4 l4 -4 l4 4" fill="none" stroke="${APP.texte}" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"/>`)}
      ${t(ZC, ZY + 98, 'Choisir un fichier CSV', { taille: 15, couleur: APP.texte, poids: 700, ancre: 'middle' })}
      ${t(ZC, ZY + 117, 'Depuis le téléphone, Google Drive', { taille: 10.5, couleur: APP.second, ancre: 'middle' })}
      ${t(ZC, ZY + 131, 'ou tes téléchargements', { taille: 10.5, couleur: APP.second, ancre: 'middle' })}
      <rect x="${ZC - 62}" y="${ZY + 146}" width="124" height="34" rx="17" fill="#FFFFFF"/>
      ${t(ZC, ZY + 167.5, 'Parcourir', { taille: 12.5, couleur: '#000', poids: 700, ancre: 'middle' })}
      ${toucher(ZC, ZY + 163, C, T.parcourir)}`, 0.004)}
    ${g(T.parcourir + 0.014, T.exos, `<circle cx="${ZC}" cy="${ZY + 62}" r="19" fill="none" stroke="${APP.texte}" stroke-width="3" stroke-dasharray="76 44" stroke-linecap="round"><animateTransform attributeName="transform" type="rotate" from="0 ${ZC} ${ZY + 62}" to="360 ${ZC} ${ZY + 62}" dur="1s" repeatCount="indefinite"/></circle>
      ${t(ZC, ZY + 116, 'Analyse de export.csv', { taille: 15, couleur: APP.texte, poids: 700, ancre: 'middle' })}
      ${t(ZC, ZY + 136, 'Lecture des séances et rapprochement', { taille: 10.5, couleur: APP.second, ancre: 'middle' })}
      ${t(ZC, ZY + 150, 'des exercices…', { taille: 10.5, couleur: APP.second, ancre: 'middle' })}`, 0.004)}
    ${t(SX + 20, SY + 384, 'Où trouver le fichier', { taille: 13, couleur: APP.texte, poids: 700 })}
    ${carteApp(SX + 16, SY + 394, SL - 32, cy - SY - 394 + 4)}
    ${liste}`, 0.004);

  // 2. Les exercices : un nom à confirmer, puis tout est associé.
  const onglets = (noms, choisi) => {
    let x = SX + 16, s = '';
    noms.forEach((n, k) => {
      const l = k === 0 ? 96 : k === 1 ? 84 : 60;
      s += `<rect x="${x}" y="${SY + 116}" width="${l}" height="30" rx="15" fill="${k === choisi ? '#FFFFFF' : APP.carte}"/>
        ${t(x + l / 2, SY + 135, n, { taille: 10.5, couleur: k === choisi ? '#000' : APP.second, poids: 700, ancre: 'middle' })}`;
      x += l + 6;
    });
    return s;
  };
  const bouton = (texte, actif) => `<line x1="${SX}" y1="${SY + SH - 70}" x2="${SX + SL}" y2="${SY + SH - 70}" stroke="${APP.trait}"/>
    <rect x="${SX + 16}" y="${SY + SH - 58}" width="${SL - 32}" height="42" rx="21" fill="${actif ? '#FFFFFF' : APP.carte2}"/>
    ${t(SX + SL / 2 - 8, SY + SH - 32.5, texte, { taille: 13, couleur: actif ? '#000' : APP.discret, poids: 700, ancre: 'middle' })}
    <path d="M${SX + SL - 52} ${SY + SH - 37} h12 m-5 -5 l5 5 l-5 5" fill="none" stroke="${actif ? '#000' : APP.discret}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`;
  const puce = (x, y, l, texte, signe) => `<rect x="${x}" y="${y}" width="${l}" height="28" rx="14" fill="${APP.carte2}"/>
    <path d="${signe === '+' ? `M${x + 12} ${y + 14} h8 m-4 -4 v8` : `M${x + 11} ${y + 14} l3 3 l6 -6`}" fill="none" stroke="${APP.texte}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    ${t(x + 26, y + 18, texte, { taille: 10.5, couleur: APP.texte, poids: 700 })}`;
  const CY = SY + 226;
  ecran += g(T.exos, T.choisi, `${entete('Exercices', '1 nom à confirmer', 2, 'ÉTAPE 3 SUR 5 · EXERCICES')}
    ${onglets(['À confirmer 1', 'Reconnus 3', 'Perso 0'], 0)}
    ${['1 à confirmer une par une. Touche une suggestion', 'pour l’accepter, ou le nom pour chercher dans le', 'catalogue. Tes choix sont retenus pour les', 'prochains imports.'].map((s, k) => t(SX + 18, SY + 166 + k * 13.5, s, { taille: 10, couleur: APP.second })).join('')}
    ${carteApp(SX + 16, CY, SL - 32, 138)}
    ${halo(SX + 44, CY + 30, 16, t(SX + 44, CY + 35, '?', { taille: 14, couleur: APP.texte, poids: 700, ancre: 'middle' }))}
    ${brut(SX + 70, CY + 27, 'Squat avant barre', { taille: 13, couleur: APP.texte, police: SANS, poids: 700 })}
    ${t(SX + 70, CY + 43, 'À confirmer · 2 séries · 1 séance', { taille: 10, couleur: APP.second })}
    <path d="M${SX + SL - 38} ${CY + 25} l5 5 l-5 5" fill="none" stroke="${APP.discret}" stroke-width="1.6" stroke-linecap="round"/>
    ${puce(SX + 28, CY + 60, 96, 'Squat · 84 %', 'v')}
    ${puce(SX + 130, CY + 60, 126, 'Squat avant · 70 %', 'v')}
    ${puce(SX + 28, CY + 94, 112, 'Exercice perso', '+')}
    ${bouton('Encore 1 à confirmer', false)}
    ${toucher(SX + 196, CY + 74, C, T.touche)}`, 0.004);
  const RECONNUS = [
    ['Développé couché barre', '→ Développé couché · Reconnu', 'automatiquement · 2 séries'],
    ['Tirage horizontal poulie', '→ Tirage horizontal · Reconnu', 'automatiquement · 1 série'],
    ['Squats', '→ Squat · Nom identique · 1 série', null],
    ['Squat avant barre', '→ Squat avant · Choisi par toi · 2 séries', null],
  ];
  ecran += g(T.choisi, FIN, `${entete('Exercices', 'Tout est associé', 2, 'ÉTAPE 3 SUR 5 · EXERCICES')}
    ${onglets(['À confirmer 0', 'Reconnus 4', 'Perso 0'], 1)}
    ${RECONNUS.map(([nom, l1, l2], k) => {
      const y = SY + 160 + k * 62;
      return `${k > 0 ? `<line x1="${SX + 20}" y1="${y}" x2="${SX + SL - 20}" y2="${y}" stroke="${APP.trait}"/>` : ''}
        ${halo(SX + 36, y + 30, 16, `<path d="M${SX + 30} ${y + 30} l4 4 l8 -8" fill="none" stroke="${APP.texte}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`)}
        ${brut(SX + 62, y + (l2 ? 22 : 27), nom, { taille: 12.5, couleur: APP.texte, police: SANS, poids: 700 })}
        ${t(SX + 62, y + (l2 ? 37 : 42), l1, { taille: 10, couleur: APP.second })}
        ${l2 ? t(SX + 62, y + 50, l2, { taille: 10, couleur: APP.second }) : ''}
        <path d="M${SX + SL - 30} ${y + 25} l5 5 l-5 5" fill="none" stroke="${APP.discret}" stroke-width="1.6" stroke-linecap="round"/>
        ${k === 3 ? `<rect x="${SX + 12}" y="${y + 6}" width="${SL - 24}" height="50" rx="12" fill="${VERT}" fill-opacity="0.1" stroke="${VERT}" stroke-opacity="0.6" opacity="0">${visible(C, T.choisi, T.choisi + 0.08, 0.005)}</rect>` : ''}`;
    }).join('')}
    ${bouton('Continuer', true)}`, 0.004);
  corps += `<g clip-path="url(#ecranImport)">${ecran}</g>`;

  svg('import.svg', 1280, 744, corps,
    'Reprendre son historique dans AESTHETICS depuis le fichier CSV exporté par une autre appli. Le fichier export.csv a cinq colonnes, séparées par des points-virgules : Date, Séance, Exercice, Charge (kg) et Répétitions. Chacune est reconnue : la date, le nom de la séance, l’exercice, la charge en kilos, les répétitions. Ses six lignes sont lues l’une après l’autre et deviennent deux séances : « Haut du corps », le 2 mars 2026 à 18 h 30, avec deux séries de Développé couché barre à 80 kg et une de Tirage horizontal poulie à 55 kg, puis « Jambes », le 4 mars à 18 h 45, avec une série de Squats à 100 kg et deux de Squat avant barre, à 60 et 62,5 kg. Même date et même titre font une séance ; les lignes qui se suivent pour un même exercice font ses séries. Chaque nom est ensuite rapproché du catalogue, dans l’ordre : tes choix passés, la table de synonymes, le nom identique, puis la ressemblance. « Développé couché barre », normalisé en « bench press barbell », est dans la table de 85 entrées : Développé couché, reconnu automatiquement. « Squats » devient « squat », nom identique à Squat. « Tirage horizontal poulie » obtient 0,97 pour Tirage horizontal, le suivant 0,85 : au-dessus du seuil de 0,90 avec un écart d’au moins 0,05, il est reconnu automatiquement. « Squat avant barre » obtient 0,84 pour Squat et 0,70 pour Squat avant : aucun n’atteint 0,90, le nom est à confirmer. Sur le téléphone, après « Parcourir » et l’analyse, l’étape 3 sur 5, « Exercices », affiche ce nom avec ses suggestions « Squat · 84 % », « Squat avant · 70 % » et « Exercice perso », et le bouton « Encore 1 à confirmer » reste bloqué. Un toucher sur « Squat avant · 70 % » : tout est associé, quatre noms reconnus, « Continuer ». Le score vaut 0,8 fois les mots communs pondérés plus 0,2 fois les lettres ; sous 0,60, rien n’est proposé. Le choix est retenu pour les prochains imports.');
};
