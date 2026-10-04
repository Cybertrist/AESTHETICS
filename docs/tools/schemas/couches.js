// Les couches de l'application, traversées par une écriture.
//
// À gauche, le téléphone : la séance en cours, « Développé couché », et le
// doigt coche la deuxième série, 80 kg × 8. Au milieu, les dossiers réels
// de mobile/lib, en une colonne. Des flèches numérotées vont d'une carte à
// l'autre dans l'ordre du code : en vert, à gauche, l'écriture qui
// descend ; en bleu, ce qui remonte vers l'écran ; en or, le calcul d'un
// record. La bille suit chaque flèche, qui reste tracée : à la fin, tout le
// trajet se lit d'un coup.
//
// Tout suit le code : SerieLigne._cocher (features/seance/widgets/
// serie_ligne.dart) appelle onToggle, où ExerciceCarte appelle
// SeanceEditeur.validerSerie (logic/editeur.dart), qui construit un nouveau
// WorkoutSet (core/models/workout.dart) ; EditeurDirect.commit appelle
// SessionRepo.updateActive (core/data/repos/session_repo.dart), qui garde
// la séance, appelle notifyListeners(), puis écrit par Store.write
// (core/data/store.dart) : fichier .tmp, puis renommage. L'écriture finie,
// _serieValidee (pages/seance_page.dart) cherche un record, par
// Strength.oneRepMax (core/logic/strength.dart), et lance le repos.
module.exports = (O) => {
  const { svg, t, tr, esc, visible, fondu, toucher, P, APP, MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, ACCENT, VERT, NEON, BLEU, OR, ROSE, INTERNE } = O;
  const C = 26;
  const TURQUOISE = '#4FD1C5';
  let corps = '';
  corps += t(60, 52, 'LES COUCHES', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(Math.round(66 + tr('LES COUCHES').length * 10.9 + 24), 52, 'Cocher une série : le geste descend jusqu’au fichier JSON, et l’écran se redessine sans attendre le disque.', { taille: 14 });
  // Un nom du code : jamais traduit.
  const brut = (x, y, s, { taille = 12.5, couleur = TEXTE, poids = 400, ancre = 'start' } = {}) =>
    `<text x="${x}" y="${y}" font-family="${MONO}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}">${esc(s)}</text>`;

  // Les instants du cycle.
  const TAP = 0.06;          // le doigt touche la coche
  const REDESSIN = 0.48;     // la ligne passe au vert
  const REPOS = 0.83;        // le minuteur de repos part
  const FIN = 0.975;
  // Les étapes, dans l'ordre du code. [de, a] : le temps que met la bille.
  const E1 = [TAP + 0.005, 0.1], E2 = [0.13, 0.19], E3 = [0.22, 0.3], E4 = [0.33, 0.41];
  const E5 = [0.43, REDESSIN], E6 = [0.52, 0.6], E7 = [0.64, 0.73], E8 = [0.77, REPOS];

  // ---------------------------------------------------------------- téléphone
  const PX = 60, PY = 88, PL = 316, PH = 640;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="ecranCouches"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  const quand = (de, a, contenu) => `<g opacity="0">${visible(C, de, a, 0.004)}${contenu}</g>`;
  const X = (v) => SX + v, Y = (v) => SY + v;
  const haltere = (x, y, nom) => (nom && O.photo(nom, x, y, 36)) || `<rect x="${x}" y="${y}" width="36" height="36" rx="10" fill="${APP.carte2}"/>
    <path d="M${x + 8} ${y + 18} H${x + 28}" stroke="${APP.second}" stroke-width="2" stroke-linecap="round"/>
    <rect x="${x + 9}" y="${y + 11}" width="4" height="14" rx="2" fill="${APP.second}"/><rect x="${x + 23}" y="${y + 11}" width="4" height="14" rx="2" fill="${APP.second}"/>`;
  const coche = (cx, cy, fond) => `<rect x="${cx - 17}" y="${cy - 12}" width="34" height="24" rx="12" fill="${fond}"/>
    <path d="M${cx - 5} ${cy} l3.5 3.5 l7 -7.5" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
  const minuteur = (x, y, c) => `<circle cx="${x}" cy="${y + 1}" r="6" fill="none" stroke="${c}" stroke-width="1.7"/><path d="M${x} ${y - 2.5} V${y + 1} L${x + 2.5} ${y + 2.5} M${x - 2} ${y - 7.5} H${x + 2}" fill="none" stroke="${c}" stroke-width="1.7" stroke-linecap="round"/>`;

  // Le tableau : trois séries de 80 kg × 8, la première déjà validée.
  const RY = [262, 302, 342], RH = 38;
  const CS = 40, CP = 104, CK = 168, CR = 210, CC = 252; // les colonnes
  const ligne = (i, fait) => `${fait ? `<rect x="${X(12)}" y="${Y(RY[i])}" width="${SL - 24}" height="${RH}" fill="${APP.serieFaite}"/>` : i === 1 ? `<rect x="${X(12)}" y="${Y(RY[i])}" width="${SL - 24}" height="${RH}" fill="${APP.carte2}" fill-opacity="0.7"/>` : ''}
    ${t(X(CS), Y(RY[i] + 24), String(i + 1), { taille: 13.5, couleur: APP.texte, poids: 700, ancre: 'middle' })}
    ${t(X(CP), Y(RY[i] + 23.5), '80 kg × 8', { taille: 11.5, couleur: APP.second, ancre: 'middle' })}
    ${t(X(CK), Y(RY[i] + 24), '80', { taille: 14, couleur: APP.texte, poids: 700, ancre: 'middle' })}
    ${t(X(CR), Y(RY[i] + 24), '8', { taille: 14, couleur: APP.texte, poids: 700, ancre: 'middle' })}
    ${coche(X(CC), Y(RY[i] + RH / 2), fait ? APP.foret : '#48454E')}`;
  const chiffre = (k, libelle, valeur, couleur = APP.texte) => {
    const cx = X(12 + (SL - 24) * (2 * k + 1) / 6);
    return `${t(cx, Y(96), libelle, { taille: 11, couleur: APP.second, ancre: 'middle' })}
      ${t(cx, Y(119), valeur, { taille: 16, couleur, poids: 800, ancre: 'middle' })}`;
  };
  const pilule = (actif) => `<rect x="${X(58)}" y="${Y(24)}" width="${actif ? 76 : 84}" height="32" rx="16" fill="${actif ? APP.minuteur : APP.carte3}"/>
    ${minuteur(X(74), Y(39), '#FFFFFF')}
    ${t(X(87), Y(44.5), actif ? '1:30' : 'Repos', { taille: 12.5, couleur: APP.texte, poids: 700 })}`;

  let ecran = '';
  // La barre du haut : réduire, la pilule du minuteur, « Terminer ».
  ecran += `<circle cx="${X(32)}" cy="${Y(40)}" r="17" fill="${APP.carte2}"/>
    <path d="M${X(26)} ${Y(38)} l6 6 l6 -6" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="${X(SL - 14 - 92)}" y="${Y(23)}" width="92" height="34" rx="17" fill="#FFFFFF"/>
    ${t(X(SL - 14 - 46), Y(44.5), 'Terminer', { taille: 13, couleur: '#000000', poids: 800, ancre: 'middle' })}`;
  ecran += `<g>${fondu('opacity', C, [[0, 1], [REPOS, 1], [REPOS + 0.004, 0], [0.99, 0], [0.994, 1], [1, 1]])}${pilule(false)}</g>`;
  ecran += quand(REPOS, 0.988, `${pilule(true)}
    <rect x="${X(58)}" y="${Y(24)}" width="76" height="32" rx="16" fill="none" stroke="${APP.minuteur}" stroke-width="2" filter="url(#halo)"/>`);
  // L'encadré : durée, volume, séries.
  ecran += `<rect x="${X(12)}" y="${Y(72)}" width="${SL - 24}" height="62" rx="16" fill="${APP.carte}"/>
    ${chiffre(0, 'Durée', '0:12:40', APP.minuteur)}
    ${t(X(12 + (SL - 24) / 2), Y(96), 'Volume', { taille: 11, couleur: APP.second, ancre: 'middle' })}
    ${t(X(12 + (SL - 24) * 5 / 6), Y(96), 'Séries', { taille: 11, couleur: APP.second, ancre: 'middle' })}`;
  const valeurs = (volume, series) => `${t(X(12 + (SL - 24) / 2), Y(119), volume, { taille: 16, couleur: APP.texte, poids: 800, ancre: 'middle' })}
    ${t(X(12 + (SL - 24) * 5 / 6), Y(119), series, { taille: 16, couleur: APP.texte, poids: 800, ancre: 'middle' })}`;
  ecran += `<g>${fondu('opacity', C, [[0, 1], [REDESSIN, 1], [REDESSIN + 0.004, 0], [0.99, 0], [0.994, 1], [1, 1]])}${valeurs('640 kg', '1')}</g>`;
  ecran += quand(REDESSIN, 0.988, valeurs('1 280 kg', '2'));
  // L'exercice ouvert.
  ecran += `<rect x="${X(12)}" y="${Y(146)}" width="${SL - 24}" height="300" rx="16" fill="${APP.carte}"/>
    ${haltere(X(24), Y(158), 'bench-press')}
    ${t(X(70), Y(181), 'Développé couché', { taille: 14, couleur: APP.texte, poids: 700 })}
    <circle cx="${X(SL - 40)}" cy="${Y(176)}" r="1.8" fill="${APP.second}"/><circle cx="${X(SL - 33)}" cy="${Y(176)}" r="1.8" fill="${APP.second}"/><circle cx="${X(SL - 26)}" cy="${Y(176)}" r="1.8" fill="${APP.second}"/>
    ${minuteur(X(32), Y(215), APP.minuteur)}
    ${t(X(46), Y(220), 'Minuteur de repos : 1:30', { taille: 12.5, couleur: APP.minuteur, poids: 500 })}
    <line x1="${X(24)}" y1="${Y(232)}" x2="${X(SL - 24)}" y2="${Y(232)}" stroke="${APP.trait}"/>
    ${[[CS, 'Série'], [CP, 'Précédent'], [CK, 'Kg'], [CR, 'Reps']].map(([x, s]) => t(X(x), Y(252), s, { taille: 11, couleur: APP.second, ancre: 'middle' })).join('')}
    ${ligne(0, true)}${ligne(1, false)}${ligne(2, false)}
    <rect x="${X(24)}" y="${Y(392)}" width="${SL - 48}" height="38" rx="19" fill="${APP.carte2}"/>
    ${t(X(SL / 2), Y(416), '+ Ajouter une série', { taille: 12.5, couleur: APP.texte, poids: 700, ancre: 'middle' })}`;
  // La deuxième série validée : fond vert sombre, coche vert forêt.
  ecran += quand(REDESSIN, 0.988, `<rect x="${X(12)}" y="${Y(RY[1])}" width="${SL - 24}" height="${RH}" fill="${APP.carte}"/>${ligne(1, true)}`);
  ecran += `<rect x="${X(13)}" y="${Y(RY[1])}" width="${SL - 26}" height="${RH}" fill="none" stroke="${VERT}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, REDESSIN, REDESSIN + 0.07, 0.006)}</rect>
    <rect x="${X(12)}" y="${Y(72)}" width="${SL - 24}" height="62" rx="16" fill="none" stroke="${VERT}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, REDESSIN, REDESSIN + 0.07, 0.006)}</rect>`;
  // L'exercice suivant, replié, et les deux boutons du bas.
  ecran += `<rect x="${X(12)}" y="${Y(458)}" width="${SL - 24}" height="64" rx="16" fill="${APP.carte}"/>
    ${haltere(X(24), Y(472), 'incline-db-press')}
    ${t(X(70), Y(487), 'Développé incliné aux haltères', { taille: 12.5, couleur: APP.texte, poids: 700 })}
    ${t(X(70), Y(505), '0/3 effectués', { taille: 11.5, couleur: APP.second })}
    <rect x="${X(14)}" y="${Y(544)}" width="182" height="44" rx="22" fill="#FFFFFF"/>
    ${t(X(105), Y(571), 'Ajouter des exercices', { taille: 13, couleur: '#000000', poids: 800, ancre: 'middle' })}
    <rect x="${X(204)}" y="${Y(544)}" width="74" height="44" rx="22" fill="${APP.carte2}"/>
    ${t(X(241), Y(571), 'Plus', { taille: 13, couleur: APP.texte, poids: 700, ancre: 'middle' })}`;
  ecran += toucher(X(CC), Y(RY[1] + RH / 2), C, TAP);
  corps += `<g clip-path="url(#ecranCouches)">${ecran}</g>`;

  // ------------------------------------------------------------------ couches
  // Une colonne de cartes ; l'écriture passe à gauche, entre le téléphone et
  // les cartes, ce qui remonte à droite. Chaque flèche va d'une carte à une
  // autre et ne coupe jamais un texte.
  const KX = 600, KL = 360, KY = 88, ECART = 16;
  const couches = [
    { cle: 'features', nom: 'lib/features/seance/', c: ACCENT, h: 146, regle: ['Un dossier par module, dix en tout, chacun avec', 'ses routes. L’écran de séance lit le dépôt et lui', 'confie chaque geste par SeanceEditeur : il n’ouvre', 'jamais lui-même le fichier de la séance.'], code: 'serie_ligne · exercice_carte · editeur' },
    { cle: 'models', nom: 'lib/core/models/', c: ROSE, regle: ['Des objets qu’on recopie au lieu de les modifier,', 'avec toJson et fromJson écrits à la main.'] },
    { cle: 'data', nom: 'lib/core/data/', c: VERT, regle: ['SessionRepo, un ChangeNotifier, garde la séance en', 'mémoire, prévient qui l’écoute, puis écrit par Store :', 'un fichier JSON par collection, écriture atomique.'] },
    { cle: 'fichier', nom: 'seance_active.json', c: INTERNE, h: 96, regle: ['La séance en cours, dans le dossier donnees/ : elle', 'survit à la fermeture de l’appli.'] },
    { cle: 'logic', nom: 'lib/core/logic/', c: OR, regle: ['Du Dart pur, sans écran : dates, 1RM estimé,', 'records, récupération, unités.'] },
    { cle: 'theme', nom: 'lib/core/theme/ · lib/core/ui/', c: TURQUOISE, regle: ['Jetons, couleurs et composants partagés : le vert', 'sombre d’une série validée, setDone, vient d’ici.'] },
    { cle: 'app', nom: 'lib/app/', c: BLEU, regle: ['AestheticApp fournit les dépôts à tout l’arbre ;', 'le routeur assemble les routes de chaque module.'] },
  ];
  let yc = KY;
  const K = {};
  for (const k of couches) {
    k.h = k.h || 62 + (k.regle.length - 1) * 17;
    k.y = yc;
    yc += k.h + ECART;
    K[k.cle] = k;
  }

  // Des pictogrammes dans une grille de 28, dessinés en traits.
  const trait = (c) => `fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"`;
  const I = {
    features: (c) => `<g ${trait(c)}><rect x="3" y="3" width="10" height="13" rx="2.5"/><rect x="15" y="3" width="10" height="7" rx="2.5"/><rect x="15" y="12" width="10" height="13" rx="2.5"/><rect x="3" y="18" width="10" height="7" rx="2.5"/></g>`,
    models: (c) => `<g ${trait(c)}><path d="M9 4 C5 4 8 14 3 14 C8 14 5 24 9 24 M19 4 C23 4 20 14 25 14 C20 14 23 24 19 24"/></g>`,
    data: (c) => `<g ${trait(c)}><rect x="3" y="3" width="22" height="6" rx="2"/><rect x="3" y="11" width="22" height="6" rx="2"/><rect x="3" y="19" width="22" height="6" rx="2"/></g><circle cx="7" cy="6" r="1.3" fill="${c}"/><circle cx="7" cy="14" r="1.3" fill="${c}"/><circle cx="7" cy="22" r="1.3" fill="${c}"/>`,
    fichier: P.fichier,
    logic: (c) => `<path d="M21 5 H7 L15 14 L7 23 H21" ${trait(c)}/>`,
    theme: (c) => `<g ${trait(c)}><circle cx="10" cy="11" r="6.5"/><circle cx="18" cy="11" r="6.5"/><circle cx="14" cy="18" r="6.5"/></g>`,
    app: (c) => `<g ${trait(c)}><rect x="9" y="3" width="10" height="7" rx="2.5"/><rect x="2" y="18" width="10" height="7" rx="2.5"/><rect x="16" y="18" width="10" height="7" rx="2.5"/><path d="M14 10 V14 M7 18 V14 H21 V18"/></g>`,
  };

  // Les cartes, allumées quand une bille y arrive.
  const allume = {
    features: [[E1[1], E2[0] + 0.02], [E4[1], E5[0] + 0.02], [E6[1] + 0.02, E7[0] + 0.02]],
    models: [[E2[1], E3[0] + 0.02]],
    data: [[E3[1], E4[0] + 0.02], [E5[1] + 0.03, E6[0] + 0.02]],
    fichier: [[E6[1], E6[1] + 0.06]],
    logic: [[E7[1], E7[1] + 0.05]],
    theme: [[REDESSIN, REDESSIN + 0.05]],
    app: [],
  };
  for (const k of couches) {
    const x = KX, y = k.y, h = k.h;
    const lignes = (couleur) => k.regle.map((l, i) => t(x + 20, y + 52 + i * 17, l, { taille: 12.5, couleur })).join('');
    corps += `<rect x="${x}" y="${y}" width="${KL}" height="${h}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${KL}" height="${h}" rx="13" fill="${k.c}" fill-opacity="0.05" stroke="${k.c}" stroke-opacity="0.3"/>
      <g transform="translate(${x + 16},${y + 11}) scale(0.82)">${I[k.cle](k.c)}</g>
      ${brut(x + 50, y + 29, k.nom, { taille: 14.5, couleur: k.cle === 'fichier' ? TITRE : k.c, poids: 700 })}
      ${lignes(TEXTE)}
      ${k.code ? brut(x + 20, y + 52 + k.regle.length * 17 + 6, k.code, { taille: 11.5, couleur: DISCRET }) : ''}`;
    for (const [de, a] of allume[k.cle]) {
      corps += `<rect x="${x}" y="${y}" width="${KL}" height="${h}" rx="13" fill="${k.c}" fill-opacity="0.05" stroke="${k.c}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, de, a, 0.006)}</rect>
        <g opacity="0">${visible(C, de, a, 0.006)}${lignes(TITRE)}</g>`;
    }
  }
  // Ce que le fichier contient une fois la série écrite.
  corps += `<g opacity="0">${visible(C, E6[1], FIN, 0.006)}${brut(KX + 20, K.fichier.y + 86, '"poids": 80.0, "reps": 8, "fait": true', { taille: 12, couleur: NEON, poids: 700 })}</g>`;
  // lib/app : posé avant, hors de ce trajet.
  corps += `<rect x="${KX}" y="${K.app.y}" width="${KL}" height="${K.app.h}" rx="13" fill="${FOND}" opacity="0.5"/>`;
  {
    const s = 'hors de ce trajet', l = Math.round(tr(s).length * 6.9 + 24);
    corps += `<rect x="${KX + KL - 16 - l}" y="${K.app.y + 12}" width="${l}" height="24" rx="12" fill="${CARTE}" stroke="${DISCRET}" stroke-opacity="0.8"/>
      ${t(KX + KL - 16 - l / 2, K.app.y + 28.5, s, { taille: 11.5, couleur: TEXTE, police: MONO, poids: 700, ancre: 'middle' })}`;
  }

  // --------------------------------------------------------------- flèches
  // Une cubique de A à B ; sa longueur et ses points, calculés ici.
  const bez = (p, u) => {
    const v = 1 - u;
    return [0, 1].map((i) => v * v * v * p[0][i] + 3 * v * v * u * p[1][i] + 3 * v * u * u * p[2][i] + u * u * u * p[3][i]);
  };
  const longueur = (p) => {
    let l = 0, a = p[0];
    for (let i = 1; i <= 60; i++) { const b = bez(p, i / 60); l += Math.hypot(b[0] - a[0], b[1] - a[1]); a = b; }
    return Math.ceil(l);
  };
  const r1 = (n) => Math.round(n * 10) / 10;
  // Un arc qui quitte le bord d'une carte et revient sur le bord d'une autre,
  // bombé jusqu'à [sommet] ; ou une ligne droite.
  const arc = (x, y1, y2, sommet) => {
    const xc = x + (sommet - x) / 0.75;
    return [[x, y1], [xc, y1], [xc, y2], [x, y2]];
  };
  const droit = (x1, y, x2) => [[x1, y], [x1 + (x2 - x1) / 3, y], [x1 + 2 * (x2 - x1) / 3, y], [x2, y]];

  const G = KX, D = KX + KL; // les bords gauche et droit des cartes
  const PD = PX + PL;        // le bord droit du téléphone
  const Ky = (cle, f) => K[cle].y + f;
  // [numéro, points, couleur, [de, a], étiquette (une ou deux lignes, [texte, à traduire]), où la poser (0..1)]
  const fleches = [
    ['1', droit(PD + 2, Ky('features', 16), G - 2), NEON, E1, [['toucher la coche', true]], 0.5],
    ['2', arc(G - 2, Ky('features', 136), Ky('models', 30), 520), NEON, E2, [['validerSerie()', false]], 0.5],
    ['3', arc(G - 2, Ky('features', 122), Ky('data', 30), 420), NEON, E3, [['SessionRepo', false], ['.updateActive()', false]], 0.75],
    ['4', arc(D + 2, Ky('data', 20), Ky('features', 120), 1060), BLEU, E4, [['notifyListeners()', false]], 0.35],
    ['5', droit(G - 2, Ky('features', 54), PD + 2), BLEU, E5, [['l’écran se redessine :', true], ['Séries 2 · 1 280 kg', true]], 0.5],
    ['6', arc(G - 2, Ky('data', 72), Ky('fichier', 30), 500), NEON, E6, [['Store.write()', false], ['.tmp, puis rename', true]], 0.5],
    ['7', arc(D + 2, Ky('features', 80), Ky('logic', 40), 1150), OR, E7, [['un record ?', true], ['Strength.oneRepMax()', false]], 0.5],
    ['8', droit(G - 2, Ky('features', 92), PD + 2), BLEU, E8, [['le repos démarre : 1:30', true]], 0.5],
  ];
  let traits = '', billes = '', etiquettes = '';
  for (const [n, p, c, [de, a], lignes, ou] of fleches) {
    const d = `M${p.map((q) => q.map(r1).join(' ')).join(' ').replace(/^(\S+ \S+) /, '$1 C')}`;
    const l = longueur(p);
    // Le trait se dessine derrière la bille, puis reste jusqu'à la fin.
    traits += `<path d="${d}" fill="none" stroke="${c}" stroke-width="3.5" stroke-linecap="round" stroke-dasharray="${l}" stroke-dashoffset="${l}" opacity="0">
      ${fondu('stroke-dashoffset', C, [[0, l], [de, l], [a, 0], [1, 0]])}${visible(C, de, FIN, 0.004)}</path>`;
    // La pointe, orientée comme la fin de la courbe.
    const [x2, y2] = p[3], [xa, ya] = bez(p, 0.97);
    const ang = Math.atan2(y2 - ya, x2 - xa) * 180 / Math.PI;
    traits += `<g opacity="0">${visible(C, a - 0.004, FIN, 0.004)}<path transform="translate(${r1(x2)},${r1(y2)}) rotate(${r1(ang)})" d="M-11 -7 L1 0 L-11 7 Z" fill="${c}"/></g>`;
    // La bille.
    billes += `<g filter="url(#halo)" opacity="0">${visible(C, de, a, 0.003)}
      <circle r="11" fill="${c}" opacity="0.25"><animateMotion dur="${C}s" repeatCount="indefinite" path="${d}" keyPoints="0;0;1;1" keyTimes="0;${de};${a};1" calcMode="linear"/></circle>
      <circle r="6.5" fill="${c}"><animateMotion dur="${C}s" repeatCount="indefinite" path="${d}" keyPoints="0;0;1;1" keyTimes="0;${de};${a};1" calcMode="linear"/></circle></g>`;
    // Le numéro dans sa pastille, et l'étiquette posée sur la flèche.
    const [cx, cy] = bez(p, ou);
    const textes = lignes.map(([s, traduit]) => (traduit ? tr(s) : s));
    const larg = Math.round(Math.max(...textes.map((s) => s.length)) * 6.9 + 44);
    const haut = lignes.length > 1 ? 40 : 26;
    const x0 = cx - larg / 2, y0 = cy - haut / 2;
    etiquettes += `<g opacity="0">${visible(C, de + 0.01, FIN, 0.005)}
      <rect x="${r1(x0)}" y="${r1(y0)}" width="${larg}" height="${haut}" rx="10" fill="${FOND}" stroke="${c}" stroke-width="1.5"/>
      <circle cx="${r1(x0 + 14)}" cy="${r1(cy)}" r="9.5" fill="${c}"/>
      <text x="${r1(x0 + 14)}" y="${r1(cy + 4)}" font-family="${MONO}" font-size="11.5" font-weight="800" fill="#000000" text-anchor="middle">${n}</text>
      ${lignes.map(([s, traduit], i) => {
    const y = r1(cy + 4 + (i - (lignes.length - 1) / 2) * 15);
    return traduit ? t(r1(x0 + 30), y, s, { taille: 11.5, couleur: c, police: MONO, poids: 700 }) : brut(r1(x0 + 30), y, s, { taille: 11.5, couleur: c, poids: 700 });
  }).join('')}
    </g>`;
  }
  corps += traits + etiquettes + billes;

  // La légende, sous le téléphone.
  const LY = PY + PH + 30;
  const legende = (k, c, s) => `<line x1="${PX + 4}" y1="${LY + k * 26}" x2="${PX + 44}" y2="${LY + k * 26}" stroke="${c}" stroke-width="3.5" stroke-linecap="round"/>
    <path transform="translate(${PX + 48},${LY + k * 26})" d="M-11 -7 L1 0 L-11 7 Z" fill="${c}"/>
    ${t(PX + 62, LY + k * 26 + 4.5, s, { taille: 13, couleur: TITRE })}`;
  corps += `${legende(0, NEON, 'l’écriture qui descend')}${legende(1, BLEU, 'ce qui remonte vers l’écran')}${legende(2, OR, 'le calcul d’un record')}
    ${t(PX + 4, LY + 84, 'Les numéros suivent l’ordre du code : l’écran', { taille: 12, couleur: DISCRET })}
    ${t(PX + 4, LY + 100, 'est prévenu avant que le fichier soit écrit.', { taille: 12, couleur: DISCRET })}`;

  const H = yc - ECART + 50;
  corps += t(KX + KL / 2, H - 22, 'L’état : provider et ChangeNotifier, sans génération de code. Neuf dépôts fournis à la racine, et chaque collection écrite par Store.', { taille: 13, couleur: DISCRET, ancre: 'middle' });

  svg('couches.svg', 1280, H, corps,
    'Les couches d’AESTHETICS, traversées par une écriture, étape par étape : cocher une série pendant la séance. Les dossiers réels de l’application, de haut en bas. lib/features/seance : un dossier par module, dix en tout, chacun avec ses routes ; l’écran de séance lit le dépôt et lui confie chaque geste par SeanceEditeur, il n’ouvre jamais lui-même le fichier de la séance. lib/core/models : des objets qu’on recopie au lieu de les modifier, avec toJson et fromJson écrits à la main. lib/core/data : SessionRepo, un ChangeNotifier, garde la séance en mémoire, prévient qui l’écoute, puis écrit par Store, un fichier JSON par collection, d’un coup ou pas du tout. seance_active.json : la séance en cours, dans le dossier donnees de l’appli, elle survit à la fermeture. lib/core/logic : du Dart pur, sans écran, pour les dates, le 1RM estimé, les records, la récupération et les unités. lib/core/theme et lib/core/ui : jetons, couleurs et composants partagés, d’où vient le vert sombre d’une série validée. lib/app : AestheticApp fournit les dépôts à tout l’arbre, par provider, et le routeur assemble les routes des modules ; il est hors de ce trajet. Sur le téléphone, la séance en cours : Développé couché, trois séries de 80 kg × 8, la première déjà validée ; l’encadré dit Durée 0:12:40, Volume 640 kg, Séries 1. Le trajet, dans l’ordre du code. 1, en vert, le doigt touche la coche de la deuxième série. 2, l’écran appelle validerSerie(), qui construit une nouvelle série, validée. 3, il la confie à SessionRepo.updateActive(). 4, en bleu, le dépôt appelle notifyListeners(). 5, l’écran se redessine : la ligne passe au vert, Séries 2, Volume 1 280 kg. 6, en vert, le dépôt écrit par Store.write() : un fichier .tmp, puis un renommage, et seance_active.json contient la série, poids 80, reps 8, fait vrai. 7, en or, l’écriture finie, l’écran cherche un record par Strength.oneRepMax(). 8, en bleu, le repos démarre : la pilule du haut affiche 1:30. L’écran est donc prévenu avant que le fichier soit écrit. L’état : provider et ChangeNotifier, sans génération de code ; neuf dépôts fournis à la racine, et chaque collection écrite par Store.');
};
