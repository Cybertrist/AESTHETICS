// La routine suggérée du jour.
//
// À gauche, huit semaines de séances, jour par jour : la lecture descend la
// colonne du vendredi et compte les fois où la même routine y a été faite.
// Six sur huit : elle est proposée. À droite, le téléphone montre le volet
// Routines ; le doigt touche « Une autre » et la file avance, rang après
// rang. En bas, les trois rangs de la file et les cas où rien n'est proposé.
//
// Les règles sont celles de features/entrainer/routines/logic/suggestion.dart ;
// le programme et ses routines sont ceux du modèle « Haut/Bas 4 jours »,
// l'historique est inventé.
module.exports = (O) => {
  const { svg, t, tr, fondu, visible, toucher, APP, MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, ROUGE } = O;

  const C = 30;
  const FIN = 0.985;
  const VEN = '#818CF8'; // le vendredi des cartes de jour
  const g = (de, a, contenu, douceur = 0.005) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;

  const T = { lit: (k) => 0.03 + k * 0.02, verdict: 0.205, carte: 0.225, tap1: 0.4, tap2: 0.56, tap3: 0.72 };

  let corps = `<defs>
    <linearGradient id="sgLun" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF5A5F"/><stop offset="1" stop-color="#FF9A5A"/></linearGradient>
    <linearGradient id="sgMar" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFB02E"/><stop offset="1" stop-color="#FFE066"/></linearGradient>
    <linearGradient id="sgMer" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#34D399"/><stop offset="1" stop-color="#A3E635"/></linearGradient>
    <linearGradient id="sgVen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#818CF8"/><stop offset="1" stop-color="#C084FC"/></linearGradient>
  </defs>`;
  corps += t(60, 52, 'LA ROUTINE SUGGÉRÉE', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(60 + tr('LA ROUTINE SUGGÉRÉE').length * 10.9 + 32, 52, 'Une routine n’est proposée que si tes habitudes du jour la désignent clairement.', { taille: 14 });

  // ------------------------------------------------------- les huit semaines
  const GX = 60, GL = 836, GY = 80, GH = 402;
  const X0 = 196, COL = 56, RY0 = GY + 92, RPAS = 30;
  corps += `<rect x="${GX}" y="${GY}" width="${GL}" height="${GH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(GX + 22, GY + 30, 'HUIT SEMAINES DE SÉANCES, JOUR PAR JOUR', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  // La colonne du vendredi.
  corps += `<rect x="${X0 + 4 * COL}" y="${GY + 46}" width="${COL}" height="${GH - 90}" rx="12" fill="${VEN}" fill-opacity="0.09" stroke="${VEN}" stroke-opacity="0.45"/>`;
  ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'].forEach((j, k) => {
    corps += t(X0 + k * COL + COL / 2, GY + 66, j, { taille: 12, couleur: k === 4 ? VEN : TEXTE, poids: k === 4 ? 700 : 400, ancre: 'middle' });
  });
  // [semaine, séances par jour (lundi = 0)]
  const HF = 'HF', BF = 'BF', HV = 'HV', BV = 'BV';
  const semaines = [
    ['3 août', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['10 août', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['17 août', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['24 août', { 0: HF, 1: BF, 3: HV }],
    ['31 août', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['7 sept.', { 1: BF, 3: HV, 4: HF, 5: BV }],
    ['14 sept.', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['21 sept.', { 0: HF, 1: BF, 3: HV, 4: BV }],
    ['28 sept.', { 0: HF, 1: BF }],
  ];
  const pastille = (cx, cy, code, c, plein = false) => `<rect x="${cx - 21}" y="${cy - 10}" width="42" height="20" rx="7" fill="${c}" fill-opacity="${plein ? 0.22 : 0.08}" stroke="${c}" stroke-opacity="${plein ? 0.9 : 0.35}"/>
    ${t(cx, cy + 4, code, { taille: 10.5, couleur: plein ? TITRE : c, police: MONO, poids: 700, ancre: 'middle' })}`;
  let compte = 0;
  const etapes = []; // [instant, total après cette semaine]
  semaines.forEach(([debut, jours], i) => {
    const y = RY0 + i * RPAS, auj = i === 8;
    corps += t(GX + 22, y + 4, auj ? 'cette semaine' : `sem. du ${debut}`, { taille: 11.5, couleur: auj ? TITRE : TEXTE, poids: auj ? 700 : 400 });
    corps += `<line x1="${X0}" y1="${y + RPAS / 2}" x2="${X0 + 7 * COL}" y2="${y + RPAS / 2}" stroke="${BORD}" stroke-opacity="${i < 8 ? 0.8 : 0}"/>`;
    for (let j = 0; j < 7; j++) {
      const cx = X0 + j * COL + COL / 2, code = jours[j];
      if (!code) {
        if (!(auj && j >= 4)) corps += `<circle cx="${cx}" cy="${y}" r="2" fill="${FIL}"/>`;
        continue;
      }
      corps += pastille(cx, y, code, TEXTE);
    }
    if (auj) return;
    // La lecture du vendredi : un cadre passe, la routine comptée s'allume.
    const cx = X0 + 4 * COL + COL / 2, lu = T.lit(i), code = jours[4];
    corps += `<rect x="${cx - 25}" y="${y - 13}" width="50" height="26" rx="9" fill="none" stroke="${TITRE}" stroke-width="1.5" opacity="0">${visible(C, lu, lu + 0.018, 0.004)}</rect>`;
    const xc = X0 + 7 * COL + 22;
    if (code === BV) {
      compte++;
      corps += g(lu + 0.006, FIN, pastille(cx, y, BV, VEN, true));
      corps += g(lu + 0.006, FIN, t(xc, y + 4, String(compte), { taille: 12, couleur: VEN, police: MONO, poids: 700, ancre: 'middle' }));
    } else {
      corps += g(lu + 0.006, FIN, t(xc, y + 4, '–', { taille: 12, couleur: DISCRET, police: MONO, poids: 700, ancre: 'middle' }));
    }
    etapes.push([lu + 0.006, compte]);
  });
  // Aujourd'hui : la case à remplir.
  {
    const y = RY0 + 8 * RPAS, cx = X0 + 4 * COL + COL / 2;
    corps += `<rect x="${cx - 21}" y="${y - 10}" width="42" height="20" rx="7" fill="none" stroke="${VEN}" stroke-dasharray="3 3">${fondu('opacity', C, [[0, 1], [T.verdict, 1], [T.verdict + 0.005, 0], [FIN, 0], [1, 1]])}</rect>`;
    corps += `<g>${fondu('opacity', C, [[0, 1], [T.verdict, 1], [T.verdict + 0.005, 0], [FIN, 0], [1, 1]])}${t(cx, y + 4, '?', { taille: 11, couleur: VEN, police: MONO, poids: 700, ancre: 'middle' })}</g>`;
    corps += g(T.verdict, FIN, `${pastille(cx, y, BV, VERT, true)}
      <rect x="${cx - 21}" y="${y - 10}" width="42" height="20" rx="7" fill="none" stroke="${VERT}" stroke-width="1.5">${fondu('opacity', 1.8, [[0, 0.9], [1, 0]])}${fondu('width', 1.8, [[0, 42], [1, 58]])}${fondu('x', 1.8, [[0, cx - 21], [1, cx - 29]])}${fondu('height', 1.8, [[0, 20], [1, 32]])}${fondu('y', 1.8, [[0, y - 10], [1, y - 16]])}</rect>`);
    corps += t(X0 + 5 * COL + 12, y + 4, 'aujourd’hui, 2 octobre', { taille: 11.5, couleur: VEN, poids: 700 });
  }

  // Le compte, à droite.
  const BX = 662, BL = 212, BY = GY + 50;
  corps += `<rect x="${BX}" y="${BY}" width="${BL}" height="232" rx="14" fill="${FOND}" stroke="${BORD}"/>`;
  corps += t(BX + 16, BY + 24, 'LES 8 DERNIERS VENDREDIS', { taille: 9.5, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="1.5"' });
  corps += pastille(BX + 37, BY + 50, BV, VEN, true) + t(BX + 66, BY + 54.5, 'Bas volume', { taille: 14, couleur: TITRE, poids: 700 });
  // Le chiffre monte au fil de la lecture.
  for (let n = 0; n <= 6; n++) {
    const de = n === 0 ? 0 : etapes.find((e) => e[1] === n)[0];
    const suivant = etapes.find((e) => e[1] === n + 1);
    const a = suivant ? suivant[0] : FIN;
    const chiffre = t(BX + 16, BY + 108, String(n), { taille: 44, couleur: n >= 6 ? VERT : TITRE, police: MONO, poids: 700 });
    corps += n === 0
      ? `<g>${fondu('opacity', C, [[0, 1], [a - 0.001, 1], [a, 0], [FIN, 0], [1, 1]])}${chiffre}</g>`
      : `<g opacity="0">${fondu('opacity', C, suivant ? [[0, 0], [de - 0.001, 0], [de, 1], [a - 0.001, 1], [a, 0], [1, 0]] : [[0, 0], [de - 0.001, 0], [de, 1], [FIN, 1], [1, 0]])}${chiffre}</g>`;
  }
  corps += t(BX + 50, BY + 108, 'sur 8', { taille: 15, couleur: TEXTE });
  // Huit cases, le seuil après la sixième.
  for (let k = 0; k < 8; k++) {
    const x = BX + 16 + k * 22.5;
    corps += `<rect x="${x}" y="${BY + 124}" width="18" height="10" rx="3" fill="${FIL}" fill-opacity="0.6"/>`;
    if (k < 6) corps += g(etapes.find((e) => e[1] === k + 1)[0], FIN, `<rect x="${x}" y="${BY + 124}" width="18" height="10" rx="3" fill="${k === 5 ? VERT : VEN}"/>`);
  }
  corps += `<line x1="${BX + 16 + 6 * 22.5 - 2.5}" y1="${BY + 118}" x2="${BX + 16 + 6 * 22.5 - 2.5}" y2="${BY + 142}" stroke="${TITRE}" stroke-width="1.5" stroke-dasharray="2 3"/>`;
  corps += t(BX + 16, BY + 158, 'seuil : 6 fois sur 8', { taille: 11.5, couleur: TEXTE });
  corps += g(T.verdict, FIN, `<rect x="${BX + 16}" y="${BY + 172}" width="${BL - 32}" height="26" rx="13" fill="${VERT}" fill-opacity="0.14" stroke="${VERT}" stroke-opacity="0.7"/>
    ${t(BX + BL / 2, BY + 189.5, 'proposée ce vendredi', { taille: 12, couleur: VERT, poids: 700, ancre: 'middle' })}`);
  corps += t(BX + 16, BY + 220, 'Haut force : 1 sur 8, sous le seuil', { taille: 11, couleur: DISCRET });
  // La légende des routines.
  const legende = [[HF, 'Haut force'], [BF, 'Bas force'], [HV, 'Haut volume'], [BV, 'Bas volume']];
  legende.forEach(([code, nom], k) => {
    const x = GX + 22 + k * 200, y = GY + GH - 26;
    corps += pastille(x + 21, y, code, code === BV ? VEN : TEXTE, code === BV) + t(x + 50, y + 4, nom, { taille: 11.5, couleur: TEXTE });
  });

  // ------------------------------------------------------- la file
  const FY = 508, FL = 266, FE = 19;
  corps += t(GX, FY, '« UNE AUTRE » : LA FILE AVANCE, EN TROIS RANGS', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const rangs = [
    ['Les habitudes du jour', 'Faites ce jour-là, même une seule', 'fois sur 8 : les plus régulières d’abord.', 'Haut force · 1 vendredi sur 8', [T.tap1, T.tap2]],
    ['La suite du programme', 'Dans le cycle du programme en cours,', 'celle qui suit la dernière faite.', 'Haut volume · après Bas force', [T.tap2, T.tap3]],
    ['Celle qui attend le plus', 'Les autres, la plus ancienne d’abord,', 'les jamais faites à la fin.', 'Abdos · depuis le 18 juillet', [T.tap3, FIN]],
  ];
  rangs.forEach(([titre, l1, l2, exemple, [de, a]], k) => {
    const x = GX + k * (FL + FE), y = FY + 14, h = 112;
    corps += `<rect x="${x}" y="${y}" width="${FL}" height="${h}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${FL}" height="${h}" rx="13" fill="${VEN}" fill-opacity="0.08" stroke="${VEN}" stroke-opacity="0.9" opacity="0">${visible(C, de + 0.012, a, 0.006)}</rect>
      <circle cx="${x + 28}" cy="${y + 28}" r="13" fill="${FOND}" stroke="${FIL}" stroke-width="1.5"/>
      ${g(de + 0.012, FIN, `<circle cx="${x + 28}" cy="${y + 28}" r="13" fill="${VEN}"/>`)}
      ${t(x + 28, y + 32.5, String(k + 1), { taille: 13, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(x + 52, y + 33, titre, { taille: 14.5, couleur: TITRE, poids: 700 })}
      ${t(x + 18, y + 60, l1, { taille: 12 })}${t(x + 18, y + 77, l2, { taille: 12 })}
      ${t(x + 18, y + 99, exemple, { taille: 11.5, couleur: VEN, police: MONO, poids: 700 })}`;
  });

  // ------------------------------------------------------- rien n'est proposé
  const NY = 662;
  corps += t(GX, NY, 'RIEN N’EST PROPOSÉ D’EMBLÉE SI…', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  ['aucune routine n’atteint 6 sur 8', 'elle a déjà été faite aujourd’hui', 'la routine n’existe plus'].forEach((s, k) => {
    const x = GX + k * (FL + FE), y = NY + 12;
    corps += `<rect x="${x}" y="${y}" width="${FL}" height="38" rx="12" fill="${CARTE}" stroke="${BORD}"/>
      <circle cx="${x + 22}" cy="${y + 19}" r="8" fill="${ROUGE}" fill-opacity="0.14" stroke="${ROUGE}" stroke-opacity="0.6"/>
      <path d="M${x + 19} ${y + 16} l6 6 m0 -6 l-6 6" stroke="${ROUGE}" stroke-width="1.6" stroke-linecap="round"/>
      ${t(x + 40, y + 23.5, s, { taille: 12.5, couleur: TEXTE })}`;
  });
  corps += t(GX, 742, 'La file épuisée, l’appli le dit : « Pas d’autre suggestion pour aujourd’hui : choisis une routine ci-dessous. »', { taille: 13, couleur: TEXTE });
  corps += t(GX, 768, '« Une autre » écarte la routine jusqu’au lendemain. Ni la récupération des muscles ni les jours prévus n’entrent dans ce choix.', { taille: 13, couleur: DISCRET });

  // ------------------------------------------------------- le téléphone
  const PX = 916, PY = 80, PL = 304, PH = 698;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="sgEcran"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  const x = (v) => SX + v, y = (v) => SY + v;
  /// Une carte de jour : cadre et jour abrégé peints du même dégradé.
  const carteJour = (cx, cy, s, jour, id) => `<rect x="${cx}" y="${cy}" width="${s}" height="${s}" rx="${s * 0.24}" fill="#0C0C0E" stroke="url(#${id})" stroke-width="1.6"/>
    <text x="${cx + s / 2}" y="${cy + s / 2 + s * 0.11}" font-family="${O.SANS}" font-size="${s * 0.3}" font-weight="800" fill="url(#${id})" text-anchor="middle">${O.esc(tr(jour))}</text>`;
  const calendrier = (cx, cy, c) => `<g transform="translate(${cx},${cy})"><rect x="0" y="2" width="13" height="12" rx="2.5" fill="none" stroke="${c}" stroke-width="1.4"/><path d="M0 6 H13 M4 0 V3.5 M9 0 V3.5" stroke="${c}" stroke-width="1.4" stroke-linecap="round"/></g>`;
  const horloge = (cx, cy, c) => `<circle cx="${cx}" cy="${cy}" r="5" fill="none" stroke="${c}" stroke-width="1.2"/><path d="M${cx} ${cy - 2.6} V${cy} L${cx + 2} ${cy + 1.2}" fill="none" stroke="${c}" stroke-width="1.2" stroke-linecap="round"/>`;

  let ecran = '';
  ecran += t(x(18), y(48), 'Entraîner', { taille: 23, couleur: APP.texte, poids: 800 });
  ecran += `<rect x="${x(12)}" y="${y(64)}" width="${SL - 24}" height="32" rx="16" fill="${APP.carte}"/>`;
  ['Programmes', 'Routines', 'Exercices'].forEach((s, k) => {
    const l = (SL - 28) / 3, vx = x(14) + k * l;
    if (k === 1) ecran += `<rect x="${vx}" y="${y(66)}" width="${l}" height="28" rx="14" fill="${APP.carte3}"/>`;
    ecran += t(vx + l / 2, y(84.5), s, { taille: 11.5, couleur: k === 1 ? APP.texte : APP.second, poids: 700, ancre: 'middle' });
  });
  ecran += t(x(16), y(122), 'SUGGÉRÉ POUR CE VENDREDI', { taille: 10, couleur: APP.second, poids: 700, extra: 'letter-spacing="1.6"' });
  // La carte de la suggestion : quatre états, un par rang.
  const KY = 134, KH = 216;
  ecran += `<rect x="${x(12)}" y="${y(KY)}" width="${SL - 24}" height="${KH}" rx="20" fill="${APP.carte}" stroke="#3A3A3C"/>`;
  // En attendant le compte : rien à montrer encore.
  ecran += `<g>${fondu('opacity', C, [[0, 1], [T.carte - 0.008, 1], [T.carte, 0], [FIN, 0], [1, 1]])}
    <rect x="${x(26)}" y="${y(KY + 14)}" width="56" height="56" rx="13" fill="${APP.carte2}"/>
    <rect x="${x(96)}" y="${y(KY + 22)}" width="120" height="12" rx="6" fill="${APP.carte2}"/>
    <rect x="${x(96)}" y="${y(KY + 44)}" width="84" height="9" rx="4.5" fill="${APP.carte2}"/>
    <rect x="${x(26)}" y="${y(KY + 92)}" width="${SL - 52}" height="9" rx="4.5" fill="${APP.carte2}"/>
    <rect x="${x(26)}" y="${y(KY + 110)}" width="${SL - 120}" height="9" rx="4.5" fill="${APP.carte2}"/></g>`;
  const suggestion = (de, a, nom, programme, detail, raison) => g(de, a, `
    ${carteJour(x(26), y(KY + 14), 56, 'Ven', 'sgVen')}
    ${t(x(96), y(KY + 34), nom, { taille: 17, couleur: APP.texte, poids: 800 })}
    ${programme ? t(x(96), y(KY + 52), programme, { taille: 11, couleur: APP.second }) : ''}
    ${t(x(96), y(KY + (programme ? 67 : 52)), detail, { taille: 11, couleur: APP.second })}
    ${calendrier(x(26), y(KY + 88), APP.second)}
    ${raison.map((s, i) => t(x(50), y(KY + 100 + i * 15), s, { taille: 11, couleur: APP.second })).join('')}`, 0.006);
  const prog = 'Haut/Bas 4 jours';
  ecran += suggestion(T.carte, T.tap1 + 0.008, 'Bas volume', prog, '7 exercices · 50 min', ['Tu as fait cette séance 6 des 8', 'derniers vendredis. Dernière fois :', 'le 25 septembre.']);
  ecran += suggestion(T.tap1 + 0.012, T.tap2 + 0.008, 'Haut force', prog, '6 exercices · 1 h 06', ['Tu as fait cette séance 1 des 8', 'derniers vendredis. Dernière fois :', 'le 28 septembre.']);
  ecran += suggestion(T.tap2 + 0.012, T.tap3 + 0.008, 'Haut volume', prog, '8 exercices · 50 min', ['La suite de ton programme.', 'Dernière fois : le 24 septembre.']);
  ecran += suggestion(T.tap3 + 0.012, FIN, 'Abdos', null, '3 exercices · 16 min', ['Pas faite depuis le 18 juillet.']);
  // Commencer, Une autre.
  const BYB = KY + 158;
  ecran += g(T.carte, FIN, `<rect x="${x(26)}" y="${y(BYB)}" width="134" height="44" rx="22" fill="#FFFFFF"/>
    ${t(x(93), y(BYB + 27), 'Commencer', { taille: 13, couleur: '#000000', poids: 800, ancre: 'middle' })}
    <rect x="${x(168)}" y="${y(BYB)}" width="${SL - 26 - 168}" height="44" rx="22" fill="${APP.carte2}"/>
    ${t(x(168) + (SL - 26 - 168) / 2, y(BYB + 27), 'Une autre', { taille: 13, couleur: APP.texte, poids: 700, ancre: 'middle' })}`, 0.006);
  for (const tap of [T.tap1, T.tap2, T.tap3]) ecran += toucher(x(168) + (SL - 26 - 168) / 2, y(BYB + 22), C, tap);
  // Nouvel entraînement.
  const NYP = KY + KH + 16;
  ecran += `<rect x="${x(12)}" y="${y(NYP)}" width="${SL - 24}" height="68" rx="16" fill="${APP.carte}"/>
    <circle cx="${x(46)}" cy="${y(NYP + 34)}" r="18" fill="#FFFFFF"/><path d="M${x(41.5)} ${y(NYP + 27)} L${x(53)} ${y(NYP + 34)} L${x(41.5)} ${y(NYP + 41)} Z" fill="#000000"/>
    ${t(x(78), y(NYP + 27), 'Nouvel entraînement', { taille: 13, couleur: APP.texte, poids: 700 })}
    ${t(x(78), y(NYP + 43), 'Ajoute des exercices et', { taille: 10.5, couleur: APP.second })}
    ${t(x(78), y(NYP + 56), 'commence le suivi', { taille: 10.5, couleur: APP.second })}
    <path d="M${x(SL - 34)} ${y(NYP + 28)} l6 6 l-6 6" fill="none" stroke="${APP.discret}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>`;
  // Tes routines.
  const LY = NYP + 68 + 30;
  ecran += t(x(16), y(LY), 'TES ROUTINES', { taille: 10, couleur: APP.second, poids: 700, extra: 'letter-spacing="1.6"' });
  [['Lun', 'sgLun', 'Haut force', '6 exercices', 'Il y a 4 jours'], ['Mar', 'sgMar', 'Bas force', '6 exercices', 'Il y a 3 jours'], ['Mer', 'sgMer', 'Haut volume', '8 exercices', '24 septembre']].forEach(([jour, id, nom, n, quand], k) => {
    const ry = LY + 14 + k * 66;
    ecran += `${carteJour(x(14), y(ry), 54, jour, id)}
      ${t(x(82), y(ry + 18), nom, { taille: 13.5, couleur: APP.texte, poids: 700 })}
      ${t(x(82), y(ry + 34), n, { taille: 10.5, couleur: APP.second })}
      ${horloge(x(87), y(ry + 45.5), APP.second)}${t(x(97), y(ry + 49), quand, { taille: 10.5, couleur: APP.second })}
      <circle cx="${x(SL - 62)}" cy="${y(ry + 27)}" r="15" fill="${APP.carte2}"/><path d="M${x(SL - 66)} ${y(ry + 21)} L${x(SL - 56)} ${y(ry + 27)} L${x(SL - 66)} ${y(ry + 33)} Z" fill="${APP.texte}"/>
      ${[0, 1, 2].map((i) => `<circle cx="${x(SL - 26)}" cy="${y(ry + 21 + i * 6)}" r="1.6" fill="${APP.second}"/>`).join('')}`;
  });
  corps += `<g clip-path="url(#sgEcran)">${ecran}</g>`;

  svg('suggestion.svg', 1280, 798, corps,
    'La routine suggérée du jour, sur huit semaines de séances et un téléphone animé. Aujourd’hui, vendredi 2 octobre. La lecture descend la colonne des huit derniers vendredis, du 7 août au 25 septembre, et compte les fois où la même routine y a été faite : Bas volume six fois, Haut force une fois, et un vendredi sans séance. Le seuil est de 6 fois sur 8 : Bas volume est proposée. Sur le téléphone, le volet Routines de l’onglet Entraîner affiche, sous « Suggéré pour ce vendredi », la carte Bas volume du programme Haut/Bas 4 jours, 7 exercices, 50 minutes, avec sa raison : « Tu as fait cette séance 6 des 8 derniers vendredis. Dernière fois : le 25 septembre. », et deux boutons, Commencer et Une autre. Le doigt touche Une autre, et la file avance en trois rangs. 1, les habitudes du jour, même une seule fois sur 8, les plus régulières d’abord : Haut force. 2, la suite du programme en cours, la routine qui suit dans le cycle la dernière faite : Haut volume, « La suite de ton programme. Dernière fois : le 24 septembre. ». 3, les autres, celle qui attend depuis le plus longtemps d’abord et les jamais faites à la fin : Abdos, « Pas faite depuis le 18 juillet. ». Rien n’est proposé d’emblée si aucune routine n’atteint 6 sur 8, si elle a déjà été faite aujourd’hui ou si elle n’existe plus. La file épuisée, l’appli écrit : « Pas d’autre suggestion pour aujourd’hui : choisis une routine ci-dessous. ». Une autre écarte la routine jusqu’au lendemain ; ni la récupération des muscles ni les jours prévus du programme n’entrent dans ce choix.');
};
