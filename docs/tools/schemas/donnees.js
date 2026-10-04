// Mes données : où tout vit, et les trois gestes pour en garder la main.
//
// À gauche, le téléphone ouvert sur Réglages > « Mes données ». À droite, le
// dossier de l'appli (un fichier JSON par collection, les copies rangées à
// côté), puis les trois gestes que le doigt déclenche l'un après l'autre :
// exporter en tableau, faire une sauvegarde à restaurer sur un autre
// téléphone, garder une copie sur le téléphone. En bas, l'alerte que l'appli
// affiche quand un fichier ne se relit plus.
//
// Aucune sauvegarde n'est automatique : une copie ne se fait que sur
// demande, ou avant « Tout effacer » si l'option reste cochée.
module.exports = (O) => {
  const {
    svg, t, visible, fondu, toucher, fil, APP, esc,
    MONO, SANS, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, ROUGE,
  } = O;

  const C = 28;
  const FIN = 0.985;
  const g = (de, a, contenu, douceur = 0.005) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  /// Un nom de fichier : le même dans les deux langues.
  const brut = (x, y, s, { taille = 11, couleur = TEXTE, police = MONO, poids = 400, ancre = 'start' } = {}) =>
    `<text x="${x}" y="${y}" font-family="${police}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}">${esc(s)}</text>`;
  const dossier = (x, y, c) => `<path d="M${x} ${y + 3} a2 2 0 0 1 2 -2 h6 l3 3 h9 a2 2 0 0 1 2 2 v10 a2 2 0 0 1 -2 2 h-18 a2 2 0 0 1 -2 -2 z" fill="${c}" fill-opacity="0.14" stroke="${c}" stroke-width="1.6" stroke-linejoin="round"/>`;
  const feuille = (x, y, c) => `<path d="M${x} ${y} h8 l5 5 v13 h-13 z m8 0 v5 h5" fill="none" stroke="${c}" stroke-width="1.6" stroke-linejoin="round"/>`;
  const puceFichier = (x, y, nom, c, { l = null, plein = false } = {}) => {
    const larg = l ?? nom.length * 6.35 + 18;
    return `<rect x="${x}" y="${y}" width="${larg}" height="24" rx="8" fill="${plein ? c : '#101216'}" fill-opacity="${plein ? 0.12 : 1}" stroke="${plein ? c : BORD}" stroke-opacity="${plein ? 0.6 : 1}"/>
      ${brut(x + larg / 2, y + 16, nom, { taille: 10.5, couleur: plein ? c : TEXTE, poids: plein ? 700 : 400, ancre: 'middle' })}`;
  };
  const point = (x, y, s, c = TEXTE, puce = true) => `${puce ? `<circle cx="${x + 3}" cy="${y - 4}" r="2.2" fill="${DISCRET}"/>` : ''}${t(x + 13, y, s, { taille: 11.5, couleur: c })}`;

  // Les instants du récit.
  const T = {
    t1: 0.09, f1: 0.14, t2: 0.36, f2: 0.41, voyage: 0.48, restaure: 0.55,
    t3: 0.67, bouton: 0.73, f3: 0.755,
  };

  let corps = '';
  corps += t(60, 52, 'MES DONNÉES', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(212, 52, 'Tout vit sur ton téléphone, dans des fichiers lisibles. Les sortir, les mettre à l’abri, les remettre : trois gestes.', { taille: 14 });

  // ------------------------------------------------------------ où tout vit
  const DX = 392, DY = 80, DL = 828, DH = 170;
  corps += `<rect x="${DX}" y="${DY}" width="${DL}" height="${DH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(DX + 22, DY + 30, 'OÙ TOUT VIT : LE DOSSIER DE L’APPLI', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  corps += `<rect x="${DX + DL - 322}" y="${DY + 13}" width="300" height="26" rx="13" fill="${VERT}" fill-opacity="0.08" stroke="${VERT}" stroke-opacity="0.45"/>
    ${t(DX + DL - 172, DY + 30.5, '« Aucun compte, aucun serveur, aucune publicité. »', { taille: 11, couleur: VERT, poids: 700, ancre: 'middle' })}`;
  // Le dossier des données : une collection par fichier.
  corps += dossier(DX + 22, DY + 52, TITRE);
  corps += brut(DX + 54, DY + 67, 'donnees/', { taille: 12.5, couleur: TITRE, poids: 700 });
  let fx = DX + 132;
  ['profil.json', 'seances.json', 'routines.json', 'programmes.json', 'mesures.json'].forEach((n) => {
    corps += puceFichier(fx, DY + 50, n, TEXTE);
    fx += n.length * 6.35 + 18 + 6;
  });
  corps += brut(fx + 2, DY + 66, '…', { taille: 12, couleur: DISCRET });
  corps += puceFichier(fx + 22, DY + 50, 'medias/', TEXTE);
  corps += t(DX + 132, DY + 92, 'Un fichier JSON par collection, les photos à part. Chaque écriture : un fichier temporaire, puis un renommage.', { taille: 11.5, couleur: DISCRET });
  // Le dossier des copies : à côté, pas dedans.
  corps += dossier(DX + 22, DY + 110, TITRE);
  corps += brut(DX + 54, DY + 125, 'sauvegardes/', { taille: 12.5, couleur: TITRE, poids: 700 });
  corps += g(0.004, T.f3, `<rect x="${DX + 160}" y="${DY + 108}" width="214" height="24" rx="8" fill="none" stroke="${FIL}" stroke-dasharray="4 5"/>
    ${t(DX + 267, DY + 124, 'aucune copie pour l’instant', { taille: 10.5, couleur: DISCRET, ancre: 'middle' })}`);
  corps += g(T.f3, FIN, puceFichier(DX + 160, DY + 108, 'aesthetic-20261004-1830.json', VERT, { l: 214, plein: true }));
  corps += `<rect x="${DX + 160}" y="${DY + 108}" width="214" height="24" rx="8" fill="none" stroke="${VERT}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, T.f3, T.f3 + 0.08, 0.005)}</rect>`;
  corps += t(DX + 132, DY + 152, 'À côté des données, pas dedans : « Tout effacer » vide donnees/ et peut laisser ces copies.', { taille: 11.5, couleur: DISCRET });

  // ------------------------------------------------------------ les trois gestes
  const GY = 266, GH = 272, GL = 266, GP = 15;
  const gx = (k) => DX + k * (GL + GP);
  const cadre = (k, numero, titre, libelle, de, a) => {
    const x = gx(k);
    return `<rect x="${x}" y="${GY}" width="${GL}" height="${GH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${GY}" width="${GL}" height="${GH}" rx="16" fill="${VERT}" fill-opacity="0.04" stroke="${VERT}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, de, a, 0.006)}</rect>
      <circle cx="${x + 30}" cy="${GY + 28}" r="11" fill="${ACCENT}" fill-opacity="0.14" stroke="${ACCENT}" stroke-opacity="0.6"/>
      ${brut(x + 30, GY + 32, numero, { taille: 11.5, couleur: ACCENT, police: SANS, poids: 800, ancre: 'middle' })}
      ${t(x + 50, GY + 32, titre, { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="1.6"' })}
      ${t(x + 20, GY + 62, libelle, { taille: 14, couleur: TITRE, poids: 700 })}`;
  };
  const choix = (x, y, noms) => {
    let cx = x;
    return noms.map(([n, l], k) => {
      const s = `<rect x="${cx}" y="${y}" width="${l}" height="24" rx="12" fill="${k === 0 ? '#FFFFFF' : '#101216'}" stroke="${k === 0 ? '#FFFFFF' : BORD}"/>
        ${t(cx + l / 2, y + 16, n, { taille: 10.5, couleur: k === 0 ? '#000' : TEXTE, poids: 700, ancre: 'middle' })}`;
      cx += l + 6;
      return s;
    }).join('');
  };
  const attente = (x, y, l, s) => `<rect x="${x}" y="${y}" width="${l}" height="24" rx="8" fill="none" stroke="${FIL}" stroke-dasharray="4 5"/>
    ${t(x + l / 2, y + 16, s, { taille: 10.5, couleur: DISCRET, ancre: 'middle' })}`;

  // 1. Exporter en tableau.
  corps += cadre(0, 1, 'EXPORTER', 'Exporter en tableau', T.t1 + 0.015, T.t2);
  {
    const x = gx(0) + 20;
    corps += choix(x, GY + 76, [['CSV', 62], ['JSON', 62]]);
    corps += t(x + 140, GY + 92, 'au choix', { taille: 11, couleur: DISCRET });
    corps += g(0.004, T.f1, attente(x, GY + 110, GL - 40, 'le fichier sort ici'));
    corps += g(T.f1, FIN, puceFichier(x, GY + 110, 'aesthetic-seances-2026-10-04.csv', VERT, { l: GL - 40, plein: true }));
    ['séances, exercices perso, mesures', 'une ligne par série, réimportable', 'virgule ou point-virgule, en UTF-8', 'plusieurs tableaux : un seul ZIP', 'JSON : un seul fichier structuré'].forEach((s, k) => { corps += point(x, GY + 160 + k * 19, s); });
    corps += t(x, GY + 257, '« Enregistrer » ou « Partager »', { taille: 11.5, couleur: TITRE, poids: 700 });
  }

  // 2. Faire une sauvegarde, la restaurer ailleurs.
  corps += cadre(1, 2, 'SAUVEGARDER, RESTAURER', 'Faire une sauvegarde', T.t2 + 0.015, T.t3);
  {
    const x = gx(1) + 20;
    corps += choix(x, GY + 76, [['Sauvegarde complète', 126], ['Données seules', 94]]);
    corps += g(0.004, T.f2, attente(x, GY + 110, GL - 40, 'le fichier sort ici'));
    corps += g(T.f2, FIN, puceFichier(x, GY + 110, 'aesthetic-sauvegarde-2026-10-04.zip', VERT, { l: GL - 40, plein: true }));
    corps += brut(x, GY + 151, 'donnees.json · manifeste.json · medias/', { taille: 10, couleur: TEXTE });
    // Le fichier voyage vers un autre téléphone.
    const ty = GY + 164;
    corps += `<rect x="${x}" y="${ty}" width="${GL - 40}" height="34" rx="10" fill="#101216" stroke="${BORD}"/>
      <rect x="${x + 10}" y="${ty + 6}" width="14" height="22" rx="3.5" fill="none" stroke="${TEXTE}" stroke-width="1.6"/>
      ${t(x + 34, ty + 21.5, 'sur un autre téléphone', { taille: 11.5, couleur: TEXTE })}`;
    corps += g(T.voyage, T.restaure, `<g opacity="0.9">${fil(`M${x + GL - 100} ${ty + 17} H${x + GL - 52}`, VERT)}</g>`);
    corps += g(T.restaure, FIN, `<rect x="${x}" y="${ty}" width="${GL - 40}" height="34" rx="10" fill="${VERT}" fill-opacity="0.08" stroke="${VERT}" stroke-opacity="0.6"/>
      <circle cx="${x + GL - 58}" cy="${ty + 17}" r="8" fill="${VERT}" fill-opacity="0.18" stroke="${VERT}" stroke-opacity="0.7"/>
      <path d="M${x + GL - 62} ${ty + 17} l3 3 l5 -5.5" fill="none" stroke="${VERT}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>`);
    ['aperçu du contenu avant de confirmer', 'elle remplace tout, sans fusionner', 'refusée si l’appli est plus ancienne'].forEach((s, k) => { corps += point(x, GY + 220 + k * 19, s); });
  }

  // 3. Les copies du téléphone.
  corps += cadre(2, 3, 'COPIES DU TÉLÉPHONE', 'Copies du téléphone', T.t3 + 0.015, FIN);
  {
    const x = gx(2) + 20;
    corps += `<rect x="${x}" y="${GY + 74}" width="${GL - 40}" height="28" rx="14" fill="#FFFFFF"/>
      ${t(x + (GL - 40) / 2, GY + 92.5, 'Sauvegarder maintenant', { taille: 11.5, couleur: '#000', poids: 700, ancre: 'middle' })}
      ${toucher(x + (GL - 40) / 2, GY + 88, C, T.bouton)}`;
    corps += g(0.004, T.f3, attente(x, GY + 110, GL - 40, 'la copie se range ici'));
    corps += g(T.f3, FIN, puceFichier(x, GY + 110, 'aesthetic-20261004-1830.json', VERT, { l: GL - 40, plein: true }));
    [['sans les photos, les 10 dernières', TEXTE, true], ['faite quand tu la demandes', TEXTE, true], ['et avant « Tout effacer », sauf refus', TEXTE, true],
      ['jamais toute seule : aucune', TITRE, true], ['sauvegarde automatique', TITRE, false]].forEach(([s, c, puce], k) => { corps += point(x, GY + 160 + k * 19, s, c, puce); });
  }

  // ------------------------------------------------------------ le fichier abîmé
  const LY = 554, LH = 190;
  corps += `<rect x="${DX}" y="${LY}" width="${DL}" height="${LH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(DX + 22, LY + 30, 'SI UN FICHIER NE SE RELIT PLUS', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  ['Au démarrage, un fichier illisible est mis de côté', 'tel quel, et l’appli démarre sans lui.'].forEach((s, k) => { corps += t(DX + 22, LY + 58 + k * 18, s, { taille: 12, couleur: TEXTE }); });
  corps += puceFichier(DX + 22, LY + 92, 'seances.json', TEXTE);
  corps += `<path d="M${DX + 124} ${LY + 104} h22 m-5 -5 l5 5 l-5 5" fill="none" stroke="${ROUGE}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>`;
  corps += puceFichier(DX + 154, LY + 92, 'seances.json.abime', ROUGE, { plein: true });
  ['Cette copie n’est jamais écrasée. À l’ouverture,', 'l’écran Aujourd’hui affiche cette alerte.'].forEach((s, k) => { corps += t(DX + 22, LY + 144 + k * 18, s, { taille: 12, couleur: TEXTE }); });
  // L'alerte, telle que l'appli l'affiche.
  const NX = DX + 356, NY = LY + 14, NL = DL - 370, NH = LH - 28;
  corps += `<rect x="${NX}" y="${NY}" width="${NL}" height="${NH}" rx="18" fill="${APP.carte}" stroke="${ROUGE}" stroke-opacity="0.55"/>
    <rect x="${NX}" y="${NY}" width="${NL}" height="${NH}" rx="18" fill="none" stroke="${ROUGE}" stroke-width="1.5" filter="url(#halo)">${fondu('opacity', 3.2, [[0, 0], [0.5, 0.7], [1, 0]])}</rect>
    <circle cx="${NX + 34}" cy="${NY + 30}" r="15" fill="${APP.carte2}"/>
    <path d="M${NX + 34} ${NY + 23} v9" stroke="${APP.texte}" stroke-width="2.4" stroke-linecap="round"/><circle cx="${NX + 34}" cy="${NY + 37}" r="1.5" fill="${APP.texte}"/>
    ${t(NX + 60, NY + 35, 'Un fichier de données est abîmé', { taille: 15, couleur: APP.texte, poids: 700 })}
    ${t(NX + 20, NY + 64, 'L’appli n’a pas pu relire tes séances et a démarré sans.', { taille: 11.5, couleur: APP.second })}
    ${t(NX + 20, NY + 80, 'Rien n’a été effacé.', { taille: 11.5, couleur: APP.second })}
    ${t(NX + 20, NY + 102, 'La copie de secours est gardée ici :', { taille: 11.5, couleur: APP.second })}
    <rect x="${NX + 20}" y="${NY + 112}" width="${NL - 150}" height="34" rx="10" fill="${APP.carte2}"/>
    ${brut(NX + 34, NY + 133.5, 'seances.json.abime', { taille: 11.5, couleur: APP.texte, police: SANS, poids: 600 })}
    <rect x="${NX + NL - 118}" y="${NY + 112}" width="98" height="34" rx="17" fill="${APP.carte2}"/>
    ${t(NX + NL - 69, NY + 133.5, 'Compris', { taille: 12, couleur: APP.texte, poids: 700, ancre: 'middle' })}`;

  // ------------------------------------------------------------ le téléphone
  const PX = 60, PY = 80, PL = 304, PH = 664;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="ecranDonnees"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  let ecran = '';
  ecran += `<path d="M${SX + 24} ${SY + 33} l-7 7 l7 7" fill="none" stroke="${APP.texte}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    ${t(SX + 40, SY + 46, 'Mes données', { taille: 18, couleur: APP.texte, poids: 800 })}
    ${t(SX + 18, SY + 78, 'SUR CE TÉLÉPHONE', { taille: 9, couleur: APP.second, poids: 700, extra: 'letter-spacing="1.4"' })}
    ${t(SX + SL - 18, SY + 78, '1,8 Mo', { taille: 10, couleur: APP.second, ancre: 'end' })}`;
  [['44', 'séances'], ['6', 'routines'], ['12', 'mesures']].forEach(([v, l], k) => {
    const lt = (SL - 32 - 16) / 3, x = SX + 16 + k * (lt + 8);
    ecran += `<rect x="${x}" y="${SY + 88}" width="${lt}" height="52" rx="14" fill="${APP.carte}"/>
      ${brut(x + lt / 2, SY + 112, v, { taille: 17, couleur: APP.texte, police: SANS, poids: 800, ancre: 'middle' })}
      ${t(x + lt / 2, SY + 128, l, { taille: 9.5, couleur: APP.second, ancre: 'middle' })}`;
  });
  // [titre du groupe, [titre, [détail], pictogramme, rouge ?]]
  const picto = {
    boite: (x, y) => `<rect x="${x - 6}" y="${y - 5}" width="12" height="10" rx="2" fill="none" stroke="${APP.texte}" stroke-width="1.5"/><path d="M${x - 7} ${y - 5} h14 M${x - 2} ${y - 1} h4" stroke="${APP.texte}" stroke-width="1.5" stroke-linecap="round"/>`,
    haut: (x, y) => `<path d="M${x} ${y + 6} v-11 m-4 4 l4 -4 l4 4" fill="none" stroke="${APP.texte}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>`,
    bas: (x, y) => `<path d="M${x} ${y - 6} v11 m-4 -4 l4 4 l4 -4" fill="none" stroke="${APP.texte}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>`,
    tour: (x, y) => `<path d="M${x - 5} ${y - 2} a5.5 5.5 0 1 1 1.5 5.5 M${x - 6} ${y - 6} v4 h4" fill="none" stroke="${APP.texte}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>`,
    base: (x, y) => `<ellipse cx="${x}" cy="${y - 4}" rx="6" ry="2.6" fill="none" stroke="${APP.texte}" stroke-width="1.5"/><path d="M${x - 6} ${y - 4} v8 a6 2.6 0 0 0 12 0 v-8" fill="none" stroke="${APP.texte}" stroke-width="1.5"/>`,
    croix: (x, y) => `<path d="M${x - 5} ${y - 4} h10 M${x - 4} ${y - 4} l1 10 h6 l1 -10 M${x - 2} ${y - 6} h4" fill="none" stroke="${ROUGE}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>`,
  };
  const GROUPES = [
    ['Mettre mes données à l’abri', [
      ['Faire une sauvegarde', ['Un fichier avec tout, photos comprises,', 'à garder ailleurs que sur ce téléphone'], 'base'],
      ['Restaurer une sauvegarde', ['Remettre un fichier de sauvegarde : il', 'remplace les données actuelles'], 'tour'],
      ['Copies du téléphone', null, 'boite'],
    ]],
    ['Venir d’une autre appli', [
      ['Importer mes séances', ['Depuis le fichier CSV exporté par ton', 'ancienne appli'], 'bas'],
      ['Imports précédents', ['Revoir ou annuler un import'], 'tour'],
    ]],
    ['Utiliser mes données ailleurs', [
      ['Exporter en tableau', ['Séances et mesures en CSV ou JSON, pour', 'un tableur ou une autre appli'], 'haut'],
    ]],
    ['Zone sensible', [
      ['Tout effacer', ['Profil, séances, mesures, photos :', 'l’appli repart de zéro'], 'croix', true],
    ]],
  ];
  const HL = 52;
  const ou = {};
  let y = SY + 164;
  GROUPES.forEach(([titre, lignes]) => {
    ecran += t(SX + 18, y, titre, { taille: 11, couleur: APP.second, poids: 700 });
    ecran += `<rect x="${SX + 16}" y="${y + 8}" width="${SL - 32}" height="${lignes.length * HL}" rx="14" fill="${APP.carte}"/>`;
    lignes.forEach(([nom, detail, p, rouge], k) => {
      const ly = y + 8 + k * HL;
      ou[nom] = ly;
      if (k > 0) ecran += `<line x1="${SX + 58}" y1="${ly}" x2="${SX + SL - 28}" y2="${ly}" stroke="${APP.trait}"/>`;
      ecran += `<circle cx="${SX + 38}" cy="${ly + HL / 2}" r="13" fill="${APP.carte2}"/>${picto[p](SX + 38, ly + HL / 2)}
        ${t(SX + 60, ly + (detail && detail.length === 1 ? 23 : 19), nom, { taille: 12, couleur: rouge ? ROUGE : APP.texte, poids: 700 })}
        ${(detail || []).map((s, i) => t(SX + 60, ly + (detail.length === 1 ? 37 : 32) + i * 11.5, s, { taille: 9, couleur: APP.second })).join('')}
        <path d="M${SX + SL - 30} ${ly + HL / 2 - 5} l5 5 l-5 5" fill="none" stroke="${APP.discret}" stroke-width="1.5" stroke-linecap="round"/>`;
    });
    y += 8 + lignes.length * HL + 22;
  });
  // La ligne des copies : aucune, puis une.
  {
    const ly = ou['Copies du téléphone'];
    ecran += t(SX + 60, ly + 32, 'Copies rapides, sans les photos.', { taille: 9, couleur: APP.second });
    ecran += g(0.004, T.f3, `${t(SX + 60, ly + 43.5, 'Aucune pour l’instant', { taille: 9, couleur: APP.second })}${brut(SX + SL - 38, ly + HL / 2 + 4, '0', { taille: 11.5, couleur: APP.second, police: SANS, poids: 700, ancre: 'end' })}`);
    ecran += g(T.f3, FIN, `${t(SX + 60, ly + 43.5, 'Dernière : aujourd’hui à 18:30', { taille: 9, couleur: APP.second })}${brut(SX + SL - 38, ly + HL / 2 + 4, '1', { taille: 11.5, couleur: APP.texte, police: SANS, poids: 700, ancre: 'end' })}`);
  }
  // Les trois touchers.
  [['Exporter en tableau', T.t1, T.t2], ['Faire une sauvegarde', T.t2, T.t3], ['Copies du téléphone', T.t3, FIN]].forEach(([nom, de, a]) => {
    const ly = ou[nom];
    ecran += `<rect x="${SX + 20}" y="${ly + 4}" width="${SL - 40}" height="${HL - 8}" rx="11" fill="${VERT}" fill-opacity="0.1" stroke="${VERT}" stroke-opacity="0.6" opacity="0">${visible(C, de + 0.004, a, 0.005)}</rect>`;
    ecran += toucher(SX + 150, ly + HL / 2, C, de);
  });
  corps += `<g clip-path="url(#ecranDonnees)">${ecran}</g>`;

  corps += t(DX, 770, 'Rien ne part tout seul : un fichier ne quitte le téléphone que lorsque tu l’enregistres ou le partages toi-même.', { taille: 13, couleur: DISCRET });

  svg('donnees.svg', 1280, 792, corps,
    'Mes données, dans AESTHETICS. Tout vit sur le téléphone, dans le dossier de l’appli : un fichier JSON par collection (profil, réglages, séances, routines, programmes, mesures…), les photos à part, et chaque écriture passe par un fichier temporaire puis un renommage. L’appli le dit elle-même : « Aucun compte, aucun serveur, aucune publicité. » Sur le téléphone, la page « Mes données » des réglages affiche ce qu’il y a sur ce téléphone (1,8 Mo, 44 séances, 6 routines, 12 mesures) et quatre groupes : mettre mes données à l’abri, venir d’une autre appli, utiliser mes données ailleurs, zone sensible. Trois gestes en partent. Un : « Exporter en tableau », en CSV ou en JSON, pour les séances, les exercices personnels et les mesures ; le fichier aesthetic-seances-2026-10-04.csv a une ligne par série et se réimporte tel quel, avec une virgule ou un point-virgule, en UTF-8 ; plusieurs tableaux sont réunis dans un ZIP. Deux : « Faire une sauvegarde », complète (une archive ZIP avec donnees.json, manifeste.json et les photos) ou en données seules (un fichier JSON) ; le fichier aesthetic-sauvegarde-2026-10-04.zip se restaure sur un autre téléphone, où son contenu s’affiche avant de confirmer ; elle remplace tout, rien n’est fusionné, et elle est refusée si elle vient d’une version plus récente de l’appli. Trois : « Copies du téléphone » ; « Sauvegarder maintenant » range aesthetic-20261004-1830.json dans le dossier des copies, à côté des données, sans les photos, et les dix dernières sont gardées. Une copie n’est faite que sur demande, ou avant « Tout effacer » si l’option reste cochée : il n’y a aucune sauvegarde automatique. Si un fichier ne se relit plus au démarrage, il est mis de côté sous le nom seances.json.abime, jamais écrasé, et l’appli affiche l’alerte « Un fichier de données est abîmé » : rien n’a été effacé, et elle indique où est la copie de secours.');
};
