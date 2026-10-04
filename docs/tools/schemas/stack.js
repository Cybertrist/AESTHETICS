// La pile : ce sur quoi l'application est bâtie.
//
// Flutter en socle, cinq prises posées dessus, ce que la musculation
// demande : l'écran, les données, la séance, les médias, le partage. Les
// paquets tombent un à un et s'empilent sur la prise qu'ils servent. Puis
// deux trajets les traversent : une série cochée pendant la séance, de
// l'écran allumé jusqu'à la notification de fin de repos, et une
// sauvegarde, du dossier des fichiers JSON jusqu'au fichier qu'on choisit
// pour restaurer. Sous le socle, à part : ce qui est rangé pour plus tard.
//
// Tout vient de mobile/pubspec.yaml et des imports de mobile/lib : les 26
// paquets posés ici sont importés par un module visible ; mobile_scanner,
// http et flutter_markdown_plus ne le sont que par nutrition et coach ;
// flutter_svg et csv ne sont importés nulle part.
module.exports = (O) => {
  const { svg, t, tr, esc, visible, P, MONO, SANS, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, ACCENT, VERT, NEON, BLEU, OR, ROSE, INTERNE } = O;

  const C = 28, FIN = 0.975;
  const TURQUOISE = '#4FD1C5';
  const g = (de, a, contenu, douceur = 0.004) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  // Un nom du code : jamais traduit.
  const brut = (x, y, s, { taille = 13.5, couleur = TITRE, poids = 700, ancre = 'start' } = {}) =>
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
  // La hauteur ne change pas d'une langue à l'autre : on compte les lignes
  // des deux, et l'on garde la plus haute.
  const DICO = require('../anglais.json');
  const nLignes = (s, l, taille) => Math.max(couper(s, l, taille).length, couper(DICO[s] || s, l, taille).length);
  const para = (x, y, s, l, { taille = 12, couleur = TEXTE, pas = 16.5 } = {}) =>
    `<text font-family="${SANS}" font-size="${taille}" fill="${couleur}">${couper(tr(s), l, taille)
      .map((li, k) => `<tspan x="${x}" y="${y + k * pas}">${esc(li)}</tspan>`).join('')}</text>`;

  let corps = '';
  corps += t(60, 52, 'LA PILE', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(Math.round(66 + tr('LA PILE').length * 10.9 + 24), 52, 'Flutter en socle, et chaque paquet branché sur ce qu’il sert : l’écran, les données, la séance, les médias, le partage.', { taille: 14 });

  // ------------------------------------------------------- les prises
  const image = (c) => `<rect x="3" y="4" width="22" height="20" rx="3.5" fill="none" stroke="${c}" stroke-width="2"/><circle cx="10" cy="11" r="2.2" fill="${c}"/><path d="M4 21 L11 15 L15 18.5 L20 13 L24 17.5" fill="none" stroke="${c}" stroke-width="2" stroke-linejoin="round"/>`;
  const envoi = (c) => `<path d="M14 17 V3 M8.5 8.5 L14 3 L19.5 8.5 M5 14 V24 H23 V14" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
  const prises = [
    ['ecran', 'L’écran', 'ce que tu vois et touches', P.telephone, ACCENT],
    ['donnees', 'Les données', 'en JSON, sur le téléphone', P.fichier, VERT],
    ['seance', 'La séance', 'le repos : sons, vibrations, alertes', P.horloge, BLEU],
    ['medias', 'Les médias', 'photos, vidéos, images', image, TURQUOISE],
    ['partage', 'Le partage', 'ce qui sort de l’appli, ou y entre', envoi, ROSE],
  ];
  const X0 = 40, CL = 228, CG = 15;
  const colonne = {};
  prises.forEach(([id, , , , c], k) => { colonne[id] = { x: X0 + k * (CL + CG), c }; });

  // Les paquets, dans l'ordre où ils tombent : [nom, rôle, prise]. Le
  // premier tombé d'une prise est celui du bas.
  const paquets = [
    ['provider', 'L’état : les dépôts fournis à tout l’arbre, et l’écran qui les écoute.', 'ecran'],
    ['path_provider', 'Le dossier de l’appli, où chaque collection a son fichier JSON.', 'donnees'],
    ['wakelock_plus', 'L’écran reste allumé tant que la séance est ouverte.', 'seance'],
    ['image_picker', 'Les photos de séance, de profil, d’évolution, d’exercice personnalisé.', 'medias'],
    ['share_plus', 'Partager une carte de séance, un export, une sauvegarde.', 'partage'],
    ['go_router', 'Toutes les routes : chaque module apporte les siennes.', 'ecran'],
    ['uuid', 'Un identifiant v4 par séance, par exercice, par série.', 'donnees'],
    ['flutter_local_notifications', 'La fin du repos, la séance en cours, les rappels.', 'seance'],
    ['video_player', 'Les vidéos d’exercice et de séance.', 'medias'],
    ['file_picker', 'Choisir le fichier à importer ou à restaurer.', 'partage'],
    ['fl_chart', 'Les courbes de la fiche d’exercice et les graphiques de Progrès.', 'ecran'],
    ['archive', 'La sauvegarde complète et l’export, dans une archive ZIP.', 'donnees'],
    ['audioplayers', 'Le son de fin de repos, le décompte vocal, le son d’un record.', 'seance'],
    ['cached_network_image', 'Les images d’exercice données par une adresse.', 'medias'],
    ['url_launcher', 'Ouvrir un lien : à propos, média d’exercice, musique.', 'partage'],
    ['path_drawing', 'Les pictogrammes, dessinés depuis des tracés.', 'ecran'],
    ['collection', 'Chercher et regrouper dans les listes des dépôts.', 'donnees'],
    ['vibration', 'Un tic par seconde sur les trois dernières, puis un coup plus long.', 'seance'],
    ['path', 'Les noms de fichiers des médias de séance.', 'medias'],
    ['permission_handler', 'L’autorisation des notifications, à l’inscription.', 'partage'],
    ['intl + flutter_localizations', 'Dates, nombres et textes du système, en français.', 'ecran'],
    ['shared_preferences', 'Une seule clé dans tout le code : apparence.accent.', 'donnees'],
    ['timezone + flutter_timezone', 'L’heure locale des notifications planifiées.', 'seance'],
    ['health', 'L’envoi d’une séance terminée vers Health Connect, à la demande.', 'partage'],
  ];
  const TL = CL - 34, TAILLE = 12, PAS = 16.5, ECART = 8;
  const hauteur = (role) => 39 + nLignes(role, TL, TAILLE) * PAS;
  // Les piles, de bas en haut, pour trouver la plus haute.
  const piles = {};
  for (const [, role, id] of paquets) piles[id] = (piles[id] || 0) + hauteur(role) + ECART;
  const HAUT = 80;
  const HY = Math.round(HAUT + Math.max(...Object.values(piles)) + 4); // le haut des prises
  const PH = 64, SY = HY + PH + 18, SH = 62; // prises, puis socle

  // Le socle.
  const SX = X0, SL = 1200;
  corps += g(0.02, FIN, `<rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="14" fill="${CARTE}" stroke="${BORD}"/>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="14" fill="${INTERNE}" fill-opacity="0.05" stroke="${INTERNE}" stroke-opacity="0.45"/>
    <path d="M${SX + 30} ${SY + 22} l-9 9 l9 9 M${SX + 44} ${SY + 22} l9 9 l-9 9 M${SX + 40} ${SY + 20} l-6 22" fill="none" stroke="${TITRE}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    ${brut(SX + 72, SY + 38, 'Flutter 3', { taille: 16 })}
    ${t(SX + 190, SY + 38, 'L’application entière, en Dart : un seul code pour le téléphone et l’écran déplié, sans génération de code.', { taille: 13.5 })}`, 0.01);

  // Les prises, posées sur le socle.
  prises.forEach(([id, titre, sous, icone, c], k) => {
    const x = colonne[id].x, de = 0.045 + k * 0.01;
    corps += g(de, FIN, `
      <path d="M${x + CL / 2 - 30} ${HY + PH} V${SY} M${x + CL / 2 + 30} ${HY + PH} V${SY}" stroke="${c}" stroke-opacity="0.5" stroke-width="2"/>
      <circle cx="${x + CL / 2 - 30}" cy="${SY}" r="3.5" fill="${c}"/><circle cx="${x + CL / 2 + 30}" cy="${SY}" r="3.5" fill="${c}"/>
      <rect x="${x}" y="${HY}" width="${CL}" height="${PH}" rx="13" fill="${CARTE}" stroke="${c}" stroke-opacity="0.55"/>
      <rect x="${x}" y="${HY}" width="${CL}" height="${PH}" rx="13" fill="${c}" fill-opacity="0.07"/>
      <g transform="translate(${x + 14},${HY + PH / 2 - 14})">${icone(c)}</g>
      ${t(x + 52, HY + 28, titre, { taille: 15, couleur: TITRE, poids: 800 })}
      ${t(x + 52, HY + 47, sous, { taille: 11.5, couleur: c })}`, 0.006);
  });

  // Les paquets tombent et s'empilent.
  const TOMBE = (i) => 0.105 + i * 0.0138;
  const hautPile = {};
  const briques = {};
  paquets.forEach(([nom, role, id], i) => {
    const col = colonne[id], h = hauteur(role);
    const bas = (hautPile[id] ?? HY - 4);
    const y = bas - ECART + 3 - h;
    hautPile[id] = y;
    const x = col.x, s = TOMBE(i), c = col.c;
    briques[nom] = { x, y, h };
    corps += `<g opacity="0">${visible(C, s, FIN, 0.004)}<g>
      <animateTransform attributeName="transform" type="translate" dur="${C}s" repeatCount="indefinite" keyTimes="0;${s.toFixed(4)};${(s + 0.02).toFixed(4)};1" values="0 -70;0 -70;0 0;0 0" calcMode="spline" keySplines="0 0 1 1;0.5 0 0.8 1;0 0 1 1"/>
      <rect x="${x}" y="${y}" width="${CL}" height="${h}" rx="11" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${x}" y="${y}" width="${CL}" height="${h}" rx="11" fill="${c}" fill-opacity="0.05" stroke="${c}" stroke-opacity="0.3"/>
      ${brut(x + 17, y + 25, nom, { taille: nom.length > 24 ? 11.5 : nom.length > 20 ? 12.5 : 13.5 })}
      ${para(x + 17, y + 46, role, TL, { taille: TAILLE, pas: PAS })}
    </g></g>`;
    // Il se branche : la prise s'allume.
    corps += `<rect x="${x}" y="${HY}" width="${CL}" height="${PH}" rx="13" fill="none" stroke="${c}" stroke-width="1.8" filter="url(#halo)" opacity="0">${visible(C, s + 0.018, s + 0.04, 0.005)}</rect>`;
  });

  // ------------------------------------------------- rangés pour plus tard
  const RY = SY + SH + 14, RH = 58, RL1 = 742, RX2 = X0 + RL1 + 14, RL2 = SL - RL1 - 14;
  const noms = (x, y, liste) => {
    let s = '', xc = x;
    for (const n of liste) {
      const l = Math.round(n.length * 7.3 + 18);
      s += `<rect x="${xc}" y="${y - 15}" width="${l}" height="22" rx="7" fill="${FOND}" stroke="${BORD}"/>${brut(xc + l / 2, y, n, { taille: 12, couleur: TEXTE, ancre: 'middle' })}`;
      xc += l + 8;
    }
    return s;
  };
  corps += g(0.075, FIN, `<rect x="${X0}" y="${RY}" width="${RL1}" height="${RH}" rx="13" fill="url(#hachures)" stroke="${BORD}"/>
    ${t(X0 + 20, RY + 24, 'Rangés pour plus tard', { taille: 13.5, couleur: TITRE, poids: 700 })}
    ${t(X0 + 20, RY + 44, 'Importés seulement par nutrition et coach, deux modules cachés par défaut.', { taille: 12 })}
    ${noms(X0 + RL1 - 16 - (14 * 7.3 + 18) - 8 - (4 * 7.3 + 18) - 8 - (21 * 7.3 + 18), RY + 25, ['mobile_scanner', 'http', 'flutter_markdown_plus'])}
    <rect x="${RX2}" y="${RY}" width="${RL2}" height="${RH}" rx="13" fill="url(#hachures)" stroke="${BORD}"/>
    ${t(RX2 + 20, RY + 24, 'Déclarés, jamais importés', { taille: 13.5, couleur: TITRE, poids: 700 })}
    ${t(RX2 + 20, RY + 44, 'L’import CSV a son propre lecteur.', { taille: 12 })}
    ${noms(RX2 + RL2 - 16 - (11 * 7.3 + 18) - 8 - (3 * 7.3 + 18), RY + 25, ['flutter_svg', 'csv'])}`, 0.01);

  // ------------------------------------------------------- deux trajets
  const trajets = [
    {
      de: 0.48, pas: 0.036, couleur: NEON,
      legende: 'En séance : l’écran reste allumé, la série cochée s’écrit, et la fin du repos vibre, sonne, ou te prévient si l’appli est en arrière-plan.',
      arrets: ['wakelock_plus', 'provider', 'path_provider', 'vibration', 'audioplayers', 'flutter_local_notifications'],
    },
    {
      de: 0.75, pas: 0.044, couleur: OR,
      legende: 'Une sauvegarde complète : les fichiers JSON et les photos entrent dans une archive, qu’on partage ; pour restaurer, tu choisis le fichier.',
      arrets: ['path_provider', 'archive', 'share_plus', 'file_picker'],
    },
  ];
  const LY = RY + RH + 34;
  corps += g(0.1, 0.465, t(640, LY, 'Vingt-six paquets importés par la musculation, chacun branché sur ce qu’il sert, tous posés sur Flutter.', { taille: 14, couleur: TEXTE, ancre: 'middle' }));
  trajets.forEach(({ de, pas, couleur, legende, arrets }) => {
    const fin = de + (arrets.length - 1) * pas + 0.05;
    corps += g(de - 0.01, fin, t(640, LY, legende, { taille: 14, couleur: TITRE, poids: 700, ancre: 'middle' }), 0.006);
    // Chaque arrêt : une brique. Le numéro se pose sur son bord droit.
    const boites = arrets.map((a) => [briques[a].x, briques[a].y, CL, briques[a].h, 11]);
    const points = boites.map(([x, y, l, h]) => [x + l, y + h / 2]);
    boites.forEach(([x, y, l, h, r], k) => {
      const s = de + k * pas;
      corps += `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="${r}" fill="${couleur}" fill-opacity="0.06" stroke="${couleur}" stroke-width="1.8" opacity="0">${visible(C, s, fin, 0.004)}</rect>`;
      corps += `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="${r}" fill="none" stroke="${couleur}" stroke-width="2" filter="url(#halo)" opacity="0">${visible(C, s, s + 0.03, 0.004)}</rect>`;
    });
    // La bille file d'un numéro au suivant, et attend à chacun.
    const d = points.map(([x, y], k) => `${k ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
    const longueurs = [0];
    for (let k = 1; k < points.length; k++) {
      longueurs.push(longueurs[k - 1] + Math.hypot(points[k][0] - points[k - 1][0], points[k][1] - points[k - 1][1]));
    }
    const total = longueurs[longueurs.length - 1];
    const kp = [0], kt = [0];
    points.forEach((_, k) => {
      const s = de + k * pas, f = (longueurs[k] / total).toFixed(4);
      kt.push(s.toFixed(4)); kp.push(f);
      if (k < points.length - 1) { kt.push((s + pas * 0.4).toFixed(4)); kp.push(f); }
    });
    kt.push(1); kp.push(1);
    const motion = `<animateMotion dur="${C}s" repeatCount="indefinite" path="${d}" keyPoints="${kp.join(';')}" keyTimes="${kt.join(';')}" calcMode="linear"/>`;
    corps += `<g opacity="0" filter="url(#halo)">${visible(C, de, fin, 0.004)}
      <circle r="15" fill="${couleur}" opacity="0.25">${motion}</circle>
      <circle r="7" fill="${couleur}">${motion}</circle></g>`;
    points.forEach(([x, y], k) => {
      const s = de + k * pas;
      corps += g(s, fin, `<circle cx="${x}" cy="${y}" r="11" fill="${couleur}" stroke="${FOND}" stroke-width="2"/><text x="${x}" y="${y + 4.2}" font-family="${MONO}" font-size="12" font-weight="700" fill="#000000" text-anchor="middle">${k + 1}</text>`, 0.004);
    });
  });

  const H = LY + 30;
  svg('stack.svg', 1280, H, corps,
    'La pile d’AESTHETICS. En socle, Flutter 3 : l’application entière, en Dart, un seul code pour le téléphone et l’écran déplié, sans génération de code. Dessus, cinq prises, ce que la musculation demande, et chaque paquet s’empile sur la sienne. L’écran : provider pour l’état, les dépôts fournis à tout l’arbre et l’écran qui les écoute ; go_router pour toutes les routes, chaque module apportant les siennes ; fl_chart pour les courbes de la fiche d’exercice et les graphiques de Progrès ; path_drawing pour les pictogrammes, dessinés depuis des tracés ; intl et flutter_localizations pour les dates, les nombres et les textes du système en français. Les données, des fichiers JSON sur le téléphone : path_provider, le dossier de l’appli où chaque collection a son fichier ; uuid, un identifiant v4 par séance, par exercice, par série ; archive, la sauvegarde complète et l’export dans une archive ZIP ; collection, pour chercher et regrouper dans les listes des dépôts ; shared_preferences, une seule clé dans tout le code. La séance : wakelock_plus, l’écran reste allumé tant que la séance est ouverte ; flutter_local_notifications, la fin du repos, la séance en cours et les rappels ; audioplayers, le son de fin de repos, le décompte vocal et le son d’un record ; vibration, un tic par seconde sur les trois dernières secondes puis un coup plus long ; timezone et flutter_timezone, l’heure locale des notifications planifiées. Les médias : image_picker, les photos de séance, de profil, d’évolution et d’exercice personnalisé ; video_player, les vidéos d’exercice et de séance ; cached_network_image, les images d’exercice données par une adresse ; path, les noms de fichiers des médias de séance. Le partage : share_plus, pour partager une carte de séance, un export ou une sauvegarde ; file_picker, pour choisir le fichier à importer ou à restaurer ; url_launcher, pour ouvrir un lien ; permission_handler, l’autorisation des notifications à l’inscription ; health, l’envoi d’une séance terminée vers Health Connect, à la demande. Sous le socle, à part : mobile_scanner, http et flutter_markdown_plus sont rangés pour plus tard, importés seulement par nutrition et coach, deux modules cachés par défaut ; flutter_svg et csv sont déclarés mais jamais importés, l’import CSV ayant son propre lecteur. Deux trajets traversent la pile. En séance, l’écran reste allumé, la série cochée s’écrit, et la fin du repos vibre, sonne, ou te prévient si l’appli est en arrière-plan. Pour une sauvegarde complète, les fichiers JSON et les photos entrent dans une archive, qu’on partage ; pour restaurer, tu choisis le fichier.');
};
