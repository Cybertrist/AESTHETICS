// La série : la flamme comptée en semaines.
//
// À gauche, six semaines de calendrier et un « aujourd'hui » qui avance :
// une séance suffit pour qu'une semaine compte, la semaine en cours encore
// vide ne casse rien, la première semaine vide passée derrière arrête le
// compte. À droite, le téléphone montre la page Série suivre le compte.
//
// La règle est celle de Dates.semainesConsecutives (core/logic/dates.dart) ;
// les textes et le calendrier sont ceux de
// features/aujourdhui/pages/serie_page.dart ; les séances sont inventées.
module.exports = (O) => {
  const { svg, t, tr, fondu, visible, APP, MONO, SANS, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, ROUGE } = O;

  const C = 30;
  const FIN = 0.985;
  const FEU = '#FF9A00', JAUNE = '#FFCB1F', BANDE = '#4A2D00';
  const g = (de, a, contenu, douceur = 0.005) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  /// Visible dès le début du cycle, jusqu'à [a].
  const dAbord = (a, contenu) => `<g>${fondu('opacity', C, [[0, 1], [a - 0.005, 1], [a, 0], [FIN, 0], [1, 1]])}${contenu}</g>`;
  /// Un texte que le dictionnaire commun traduit déjà autrement : le titre de
  /// la page, « Série », y vaut « Set » (une série d'exercice).
  const brut = (x, y, fr, en, { taille, couleur, poids, police = SANS, extra = '' }) =>
    `<text x="${x}" y="${y}" font-family="${police}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" ${extra}>${O.esc(O.EN ? en : fr)}</text>`;

  /// La flamme de l'appli, sur sa grille de 82 par 100.
  const flamme = (x, y, taille, opacite = 1) => `<g transform="translate(${x},${y}) scale(${taille / 100})" opacity="${opacite}">
    <path d="M44 2 C56 18 80 36 80 62 C80 84 63 98 41 98 C19 98 2 84 2 62 C2 46 10 33 20 24 L23 38 C30 26 36 14 44 2 Z" fill="${FEU}"/>
    <path d="M41 50 C52 60 64 70 64 82 C64 92 54 98 41 98 C28 98 18 92 18 82 C18 70 30 60 41 50 Z" fill="${JAUNE}"/></g>`;

  // ----------------------------------------------------------------------
  // Le récit. Les semaines vont du lundi 31 août au dimanche 11 octobre 2026.
  const SEM = [
    ['31 août', [31, 1, 2, 3, 4, 5, 6]],
    ['7 sept.', [7, 8, 9, 10, 11, 12, 13]],
    ['14 sept.', [14, 15, 16, 17, 18, 19, 20]],
    ['21 sept.', [21, 22, 23, 24, 25, 26, 27]],
    ['28 sept.', [28, 29, 30, 1, 2, 3, 4]],
    ['5 oct.', [5, 6, 7, 8, 9, 10, 11]],
  ];
  // Les étapes : [semaine, jour (lundi = 0), séances ajoutées, série, ce qui se passe]
  const ETAPES = [
    [0, 2, [[0, 2]], 1, 'mer. 2 sept. : une première séance'],
    [1, 4, [[1, 0], [1, 2], [1, 4]], 2, 'ven. 11 sept. : trois séances cette semaine'],
    [2, 6, [[2, 6]], 3, 'dim. 20 sept. : une seule, le dimanche'],
    [3, 0, [], 3, 'lun. 21 sept. : la semaine en cours est vide'],
    [3, 3, [[3, 3]], 4, 'jeu. 24 sept. : une séance'],
    [4, 2, [], 4, 'mer. 30 sept. : toujours rien cette semaine'],
    [5, 0, [], 0, 'lun. 5 oct. : la semaine vide est derrière'],
    [5, 1, [[5, 1]], 1, 'mar. 6 oct. : une séance, la série repart'],
  ];
  const Tq = (k) => 0.035 + k * 0.112; // l'instant de l'étape k
  const finEtape = (k) => (k + 1 < ETAPES.length ? Tq(k + 1) : FIN);
  // L'instant où chaque séance apparaît, et celui où chaque semaine se remplit.
  const seances = [];
  ETAPES.forEach(([, , ajoutees], k) => ajoutees.forEach(([s, j], i) => seances.push([s, j, Tq(k) + i * 0.012])));
  const tenue = (s) => Math.min(...seances.filter((x) => x[0] === s).map((x) => x[2]).concat([2]));

  let corps = '';
  corps += brut(60, 52, 'LA SÉRIE', 'THE STREAK', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(60 + (O.EN ? 'THE STREAK' : 'LA SÉRIE').length * 10.9 + 32, 52, 'La flamme compte des semaines, pas des jours : une séance suffit pour en gagner une.', { taille: 14 });

  // ------------------------------------------------------- le calendrier
  const GX = 60, GL = 836, GY = 80, GH = 372;
  const X0 = 190, COL = 46, RY0 = GY + 98, RPAS = 42;
  corps += `<rect x="${GX}" y="${GY}" width="${GL}" height="${GH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(GX + 22, GY + 30, 'SIX SEMAINES, ET UN AUJOURD’HUI QUI AVANCE', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'].forEach((j, k) => {
    corps += t(X0 + k * COL + COL / 2, GY + 66, j, { taille: 12, couleur: TEXTE, ancre: 'middle' });
  });
  SEM.forEach(([debut, jours], s) => {
    const y = RY0 + s * RPAS, quand = tenue(s);
    corps += t(GX + 22, y + 4, `sem. du ${debut}`, { taille: 11.5, couleur: TEXTE });
    corps += `<rect x="${X0}" y="${y - 17}" width="${7 * COL}" height="34" rx="17" fill="${FOND}" stroke="${BORD}"/>`;
    // La bande : la semaine compte dès sa première séance.
    if (quand < 1) corps += g(quand, FIN, `<rect x="${X0}" y="${y - 17}" width="${7 * COL}" height="34" rx="17" fill="${BANDE}"/>`);
    jours.forEach((n, j) => {
      const cx = X0 + j * COL + COL / 2;
      const se = seances.find((x) => x[0] === s && x[1] === j);
      corps += t(cx, y + 4.5, String(n), { taille: 12.5, couleur: TEXTE, poids: 500, ancre: 'middle' });
      if (se) {
        corps += g(se[2], FIN, `<circle cx="${cx}" cy="${y}" r="14" fill="${FEU}"/>
          ${t(cx, y + 4.5, String(n), { taille: 12.5, couleur: '#000000', poids: 700, ancre: 'middle' })}`);
      }
    });
  });
  // La semaine vide, quand elle est passée derrière.
  {
    const y = RY0 + 4 * RPAS;
    corps += g(Tq(6), FIN, `<rect x="${X0 - 3}" y="${y - 20}" width="${7 * COL + 6}" height="40" rx="20" fill="none" stroke="${ROUGE}" stroke-width="1.5" stroke-dasharray="4 4"/>`);
  }
  // Aujourd'hui : un anneau blanc qui passe d'un jour à l'autre.
  {
    const pos = [[0, 0], ...ETAPES.map(([s, j]) => [s, j])];
    const kt = [0], xs = [], ys = [];
    pos.forEach(([s, j], i) => {
      xs.push(X0 + j * COL + COL / 2); ys.push(RY0 + s * RPAS);
      if (i > 0) kt.push(Tq(i - 1));
    });
    kt.push(1); xs.push(xs[xs.length - 1]); ys.push(ys[ys.length - 1]);
    const anime = (attr, v) => `<animate attributeName="${attr}" dur="${C}s" repeatCount="indefinite" keyTimes="${kt.join(';')}" values="${v.join(';')}" calcMode="discrete"/>`;
    corps += `<g>${fondu('opacity', C, [[0, 1], [FIN, 1], [1, 0]])}<circle r="18" cx="${xs[0]}" cy="${ys[0]}" fill="none" stroke="${TITRE}" stroke-width="2">${anime('cx', xs)}${anime('cy', ys)}</circle></g>`;
  }
  corps += `<circle cx="${GX + 30}" cy="${GY + GH - 22}" r="7" fill="none" stroke="${TITRE}" stroke-width="2"/>` + t(GX + 46, GY + GH - 17.5, 'aujourd’hui', { taille: 11.5, couleur: TEXTE });
  corps += `<circle cx="${GX + 146}" cy="${GY + GH - 22}" r="8" fill="${FEU}"/>` + t(GX + 162, GY + GH - 17.5, 'une séance', { taille: 11.5, couleur: TEXTE });
  corps += `<rect x="${GX + 256}" y="${GY + GH - 30}" width="34" height="16" rx="8" fill="${BANDE}"/>` + t(GX + 298, GY + GH - 17.5, 'une semaine qui compte', { taille: 11.5, couleur: TEXTE });

  // Le fil des jours, à droite du calendrier.
  const JX = 548, JL = 326;
  ETAPES.forEach(([, , , serie, texte], k) => {
    const y = GY + 62 + k * 37, casse = serie === 0;
    const c = casse ? ROUGE : FEU;
    corps += `<rect x="${JX}" y="${y - 13}" width="${JL}" height="30" rx="10" fill="${FOND}" stroke="${BORD}"/>`;
    corps += `<rect x="${JX}" y="${y - 13}" width="${JL}" height="30" rx="10" fill="${c}" fill-opacity="0.1" stroke="${c}" stroke-opacity="0.85" opacity="0">${visible(C, Tq(k), finEtape(k) - 0.012, 0.006)}</rect>`;
    corps += g(Tq(k), FIN, `${t(JX + 14, y + 6.5, texte, { taille: 12, couleur: TITRE })}
      ${flamme(JX + JL - 62, y - 8, 18, casse ? 0.35 : 1)}
      ${t(JX + JL - 16, y + 7.5, String(serie), { taille: 16, couleur: casse ? ROUGE : TITRE, police: MONO, poids: 700, ancre: 'end' })}`);
  });

  // ------------------------------------------------------- les trois règles
  const FY = 478, FL = 266, FE = 19;
  corps += t(GX, FY, 'ON REMONTE DEPUIS LA SEMAINE EN COURS, ET ON S’ARRÊTE AU PREMIER TROU', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const regles = [
    ['Une séance suffit', ['Une semaine compte dès sa première', 'séance. Trois séances n’en font', 'pas une de plus.'], VERT, [[Tq(0), Tq(3)], [Tq(4), Tq(5)], [Tq(7), FIN]]],
    ['La semaine en cours ne casse rien', ['Encore vide, elle n’ajoute rien,', 'et le compte continue sur', 'les semaines d’avant.'], FEU, [[Tq(3), Tq(4)], [Tq(5), Tq(6)]]],
    ['Un trou remet à zéro', ['La première semaine vide passée', 'derrière arrête le compte :', 'la série repart de la suivante.'], ROUGE, [[Tq(6), Tq(7)]]],
  ];
  regles.forEach(([titre, lignes, c, moments], k) => {
    const x = GX + k * (FL + FE), y = FY + 14, h = 112;
    corps += `<rect x="${x}" y="${y}" width="${FL}" height="${h}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${FL}" height="${h}" rx="13" fill="${c}" fill-opacity="0.04" stroke="${c}" stroke-opacity="0.3"/>`;
    moments.forEach(([de, a]) => {
      corps += `<rect x="${x}" y="${y}" width="${FL}" height="${h}" rx="13" fill="${c}" fill-opacity="0.07" stroke="${c}" stroke-opacity="0.95" opacity="0">${visible(C, de, a - 0.012, 0.006)}</rect>`;
    });
    corps += t(x + 18, y + 31, titre, { taille: 14.5, couleur: TITRE, poids: 700 });
    lignes.forEach((s, i) => { corps += t(x + 18, y + 55 + i * 18, s, { taille: 12.5 }); });
  });
  corps += t(GX, 642, 'L’objectif de séances par semaine n’entre pas dans la série, et c’est le début de la séance qui la date.', { taille: 13, couleur: TEXTE });
  corps += t(GX, 668, 'La même flamme se retrouve en tête de l’accueil, sur le profil et sur la carte de partage d’une séance.', { taille: 13, couleur: DISCRET });

  // ------------------------------------------------------- le téléphone
  const PX = 916, PY = 80, PL = 304, PH = 632;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="srEcran"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  const x = (v) => SX + v, y = (v) => SY + v;
  let ecran = '';
  ecran += `<path d="M${x(28)} ${y(30)} l-7 7 l7 7" fill="none" stroke="${APP.texte}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
  ecran += brut(x(44), y(43), 'Série', 'Streak', { taille: 17, couleur: APP.texte, poids: 700 });

  // Le chiffre, la flamme et le message : un état par étape.
  const messages = {
    0: ['Une séance cette semaine et ta', 'série démarre.'],
    1: ['Première semaine de ta série.', 'Reviens la semaine prochaine pour', 'la faire grandir.'],
    2: ['Tu as tenu 2 semaines d’affilée.', 'Bien vu !'],
    3: ['Tu as tenu 3 semaines d’affilée.', 'Bien vu !'],
    4: ['Tu as tenu 4 semaines d’affilée.', 'Bien vu !'],
  };
  ecran += `<rect x="${x(12)}" y="${y(204)}" width="${SL - 24}" height="68" rx="16" fill="${APP.carte}"/>`;
  ecran += flamme(x(26), y(222), 32);
  const etat = (n) => `${t(x(20), y(150), String(n), { taille: 92, couleur: APP.texte, poids: 800, extra: 'letter-spacing="-3"' })}
    ${flamme(x(SL - 108), y(62), 104, n === 0 ? 0.35 : 1)}
    ${t(x(20), y(186), n <= 1 ? 'semaine d’affilée !' : 'semaines d’affilée !', { taille: 19, couleur: APP.texte, poids: 700 })}
    ${messages[n].map((s, i) => t(x(66), y((messages[n].length === 3 ? 227 : 235) + i * 15), s, { taille: 11.5, couleur: APP.texte })).join('')}`;
  ecran += dAbord(Tq(0), etat(0));
  ETAPES.forEach(([, , , serie], k) => {
    // Deux étapes de suite au même compte : l'écran ne change pas.
    if (k > 0 && ETAPES[k - 1][3] === serie) return;
    let a = k;
    while (a + 1 < ETAPES.length && ETAPES[a + 1][3] === serie) a++;
    ecran += g(Tq(k), finEtape(a), etat(serie), 0.004);
  });
  // Un éclat quand le compte change.
  ETAPES.forEach(([, , , serie], k) => {
    if (k > 0 && ETAPES[k - 1][3] === serie) return;
    const c = serie === 0 ? ROUGE : FEU;
    ecran += `<rect x="${x(10)}" y="${y(64)}" width="${SL - 20}" height="132" rx="20" fill="${c}" fill-opacity="0.12" opacity="0">${fondu('opacity', C, [[0, 0], [Tq(k), 0], [Tq(k) + 0.006, 1], [Tq(k) + 0.05, 0], [1, 0]])}</rect>`;
  });

  ecran += `<rect x="${SX}" y="${y(286)}" width="${SL}" height="4" fill="${APP.carte}"/>`;
  ecran += t(x(20), y(318), 'Calendrier de la série', { taille: 15.5, couleur: APP.texte, poids: 700 });
  // Le mois : septembre, puis octobre quand aujourd'hui y passe.
  const KY = 332, KH = 258, LC = (SL - 44) / 7;
  ecran += `<rect x="${x(12)}" y="${y(KY)}" width="${SL - 24}" height="${KH}" rx="18" fill="none" stroke="${APP.trait}" stroke-width="1.5"/>`;
  ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'].forEach((j, k) => {
    ecran += t(x(22) + k * LC + LC / 2, y(KY + 54), j, { taille: 10.5, couleur: APP.second, poids: 500, ancre: 'middle' });
  });
  /// Un mois de la page : son nom, ses semaines, les jours du mois voisin (semaine, jour), les flèches actives.
  const mois = (de, a, nom, rangs, voisins, precedent, suivant) => {
    let s = t(x(SL / 2), y(KY + 27), nom, { taille: 13, couleur: APP.texte, poids: 700, ancre: 'middle' });
    s += `<path d="M${x(34)} ${y(KY + 17)} l-5 5 l5 5" fill="none" stroke="${precedent ? APP.texte : APP.discret}" stroke-opacity="${precedent ? 1 : 0.35}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`;
    s += `<path d="M${x(SL - 34)} ${y(KY + 17)} l5 5 l-5 5" fill="none" stroke="${suivant ? APP.texte : APP.discret}" stroke-opacity="${suivant ? 1 : 0.35}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`;
    rangs.forEach((sem, r) => {
      const ry = KY + 80 + r * 38;
      if (sem === null) return;
      const quand = Math.max(tenue(sem), de);
      if (tenue(sem) < a) s += g(quand, a, `<rect x="${x(22)}" y="${y(ry - 16)}" width="${7 * LC}" height="32" rx="16" fill="${BANDE}"/>`, 0.004);
      SEM[sem][1].forEach((n, j) => {
        const cx = x(22) + j * LC + LC / 2;
        const dehors = voisins.some(([vs, vj]) => vs === sem && vj === j);
        s += t(cx, y(ry + 4), String(n), { taille: 11.5, couleur: dehors ? APP.discret : APP.second, poids: 500, ancre: 'middle' });
        const se = seances.find((v) => v[0] === sem && v[1] === j);
        if (se && se[2] < a) {
          s += g(Math.max(se[2], de), a, `<circle cx="${cx}" cy="${y(ry)}" r="13" fill="${FEU}"/>
            ${t(cx, y(ry + 4), String(n), { taille: 11.5, couleur: '#000000', poids: 700, ancre: 'middle' })}`, 0.004);
        }
      });
    });
    return s;
  };
  // Octobre continue après le 11 : deux semaines de plus, sans séance.
  SEM.push(['12 oct.', [12, 13, 14, 15, 16, 17, 18]], ['19 oct.', [19, 20, 21, 22, 23, 24, 25]], ['26 oct.', [26, 27, 28, 29, 30, 31, 1]]);
  ecran += dAbord(Tq(6), mois(0, Tq(6), 'Septembre 2026', [0, 1, 2, 3, 4], [[0, 0], [4, 3], [4, 4], [4, 5], [4, 6]], false, false));
  ecran += g(Tq(6), FIN, mois(Tq(6), FIN, 'Octobre 2026', [4, 5, 6, 7, 8], [[4, 0], [4, 1], [4, 2], [8, 6]], true, false), 0.004);
  corps += `<g clip-path="url(#srEcran)">${ecran}</g>`;

  svg('serie.svg', 1280, 732, corps,
    'La série, la flamme comptée en semaines, sur un calendrier de six semaines et un téléphone animé. Aujourd’hui avance du 31 août au 6 octobre 2026. Mercredi 2 septembre, une première séance : la série vaut 1, et la page Série écrit « Première semaine de ta série. Reviens la semaine prochaine pour la faire grandir. ». Vendredi 11 septembre, trois séances dans la semaine : 2, car trois séances ne font qu’une semaine. Dimanche 20 septembre, une seule séance, le dimanche : 3. Lundi 21 septembre, la semaine en cours est encore vide : elle ne casse rien, la série reste à 3. Jeudi 24 septembre, une séance : 4, « Tu as tenu 4 semaines d’affilée. Bien vu ! ». Mercredi 30 septembre, toujours rien cette semaine : encore 4. Lundi 5 octobre, la semaine vide est passée derrière : le compte s’arrête, la série tombe à 0, la flamme pâlit et la page écrit « Une séance cette semaine et ta série démarre. ». Mardi 6 octobre, une séance : la série repart à 1. Sur la page Série, le grand chiffre et la flamme suivent, et le calendrier de la série souligne d’une bande chaque semaine qui compte, avec un disque orange par jour de séance. Trois règles : une séance suffit pour qu’une semaine compte ; la semaine en cours, encore vide, ne casse rien ; la première semaine vide passée derrière remet à zéro. L’objectif de séances par semaine n’entre pas dans la série, et c’est le début de la séance qui la date. La même flamme se retrouve en tête de l’accueil, sur le profil et sur la carte de partage d’une séance.');
};
