// Les badges : neuf habitudes comptées sur les séances terminées.
//
// À gauche, les neuf badges à paliers, en écussons hexagonaux de leur
// couleur, avec ce que chacun mesure et ses seuils : gris et cadenassés au
// départ, ils s'allument un à un. À droite, le détail d'un badge, comme le
// montre l'appli : « Lève-tôt » passe du palier 1 au palier 5 quand une
// cinquième séance commence avant 7 h. En bas, les six badges secrets, dont
// un se révèle quand deux séances tombent le même jour, et les étapes en
// boucliers, qui ne comptent que les séances.
//
// Les couleurs, les paliers et les tracés des pictogrammes (Phosphor Icons,
// licence MIT) sont ceux de l'appli : lib/features/profil/data/grades.dart et
// widgets/ecusson.dart.
module.exports = (O) => {
  const {
    svg, t, visible, fondu, APP, EN,
    MONO, SANS, CARTE, BORD, TITRE, TEXTE, DISCRET, ACCENT, VERT,
  } = O;

  const C = 28;
  const FIN = 0.985;
  const g = (de, a, contenu, douceur = 0.006) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;

  // Les instants du récit.
  const T = {
    gagne: (i) => 0.11 + i * 0.024, apres: 0.11, compte: 0.33,
    ev1: 0.45, palier: 0.5, indice: 0.64, ev2: 0.75, double: 0.8,
  };

  // ------------------------------------------------------------ les écussons
  // Les pictogrammes de l'appli, dans un carré de 256.
  const PICTOS = {
    cible: 'M221.87,83.16A104.1,104.1,0,1,1,195.67,49l22.67-22.68a8,8,0,0,1,11.32,11.32L167.6,99.71h0l-37.71,37.71-23.95,23.95a40,40,0,0,0,62-35.67,8,8,0,1,1,16-.9,56,56,0,0,1-95.5,42.79h0a56,56,0,0,1,73.13-84.43L184.3,60.39a87.88,87.88,0,1,0,23.13,29.67,8,8,0,0,1,14.44-6.9Z',
    aube: 'M248,160a8,8,0,0,1-8,8H16a8,8,0,0,1,0-16H56.45a73.54,73.54,0,0,1-.45-8,72,72,0,0,1,144,0,73.54,73.54,0,0,1-.45,8H240A8,8,0,0,1,248,160Zm-40,32H48a8,8,0,0,0,0,16H208a8,8,0,0,0,0-16ZM80.84,59.58a8,8,0,0,0,14.32-7.16l-8-16a8,8,0,0,0-14.32,7.16ZM20.42,103.16l16,8a8,8,0,1,0,7.16-14.31l-16-8a8,8,0,1,0-7.16,14.31ZM216,112a8,8,0,0,0,3.57-.84l16-8a8,8,0,1,0-7.16-14.31l-16,8A8,8,0,0,0,216,112ZM164.42,63.16a8,8,0,0,0,10.74-3.58l8-16a8,8,0,0,0-14.32-7.16l-8,16A8,8,0,0,0,164.42,63.16Z',
    lune: 'M240,96a8,8,0,0,1-8,8H216v16a8,8,0,0,1-16,0V104H184a8,8,0,0,1,0-16h16V72a8,8,0,0,1,16,0V88h16A8,8,0,0,1,240,96ZM144,56h8v8a8,8,0,0,0,16,0V56h8a8,8,0,0,0,0-16h-8V32a8,8,0,0,0-16,0v8h-8a8,8,0,0,0,0,16Zm65.14,94.33A88.07,88.07,0,0,1,105.67,46.86a8,8,0,0,0-10.6-9.06A96,96,0,1,0,218.2,160.93a8,8,0,0,0-9.06-10.6Z',
    epee: 'M216,32H152a8,8,0,0,0-6.34,3.12l-64,83.21L72,108.69a16,16,0,0,0-22.64,0l-8.69,8.7a16,16,0,0,0,0,22.63l22,22-32,32a16,16,0,0,0,0,22.63l8.69,8.68a16,16,0,0,0,22.62,0l32-32,22,22a16,16,0,0,0,22.64,0l8.69-8.7a16,16,0,0,0,0-22.63l-9.64-9.64,83.21-64A8,8,0,0,0,224,104V40A8,8,0,0,0,216,32Zm-8,68.06-81.74,62.88L115.32,152l50.34-50.34a8,8,0,0,0-11.32-11.31L104,140.68,93.07,129.74,155.94,48H208Z',
    flamme: 'M143.38,17.85a8,8,0,0,0-12.63,3.41l-22,60.41L84.59,58.26a8,8,0,0,0-11.93.89C51,87.53,40,116.08,40,144a88,88,0,0,0,176,0C216,84.55,165.21,36,143.38,17.85Zm40.51,135.49a57.6,57.6,0,0,1-46.56,46.55A7.65,7.65,0,0,1,136,200a8,8,0,0,1-1.32-15.89c16.57-2.79,30.63-16.85,33.44-33.45a8,8,0,0,1,15.78,2.68Z',
    fiole: 'M221.69,199.77,160,96.92V40h8a8,8,0,0,0,0-16H88a8,8,0,0,0,0,16h8V96.92L34.31,199.77A16,16,0,0,0,48,224H208a16,16,0,0,0,13.72-24.23Zm-90.08-42.91c-15.91-8.05-31.05-12.32-45.22-12.81l24.47-40.8A7.93,7.93,0,0,0,112,99.14V40h32V99.14a7.93,7.93,0,0,0,1.14,4.11L183.36,167C171.4,169.34,154.29,168.34,131.61,156.86Z',
    cartes: 'M200,88V200a16,16,0,0,1-16,16H40a16,16,0,0,1-16-16V88A16,16,0,0,1,40,72H184A16,16,0,0,1,200,88Zm16-48H64a8,8,0,0,0,0,16H216V176a8,8,0,0,0,16,0V56A16,16,0,0,0,216,40Z',
    trophee: 'M232,64H208V48a8,8,0,0,0-8-8H56a8,8,0,0,0-8,8V64H24A16,16,0,0,0,8,80V96a40,40,0,0,0,40,40h3.65A80.13,80.13,0,0,0,120,191.61V216H96a8,8,0,0,0,0,16h64a8,8,0,0,0,0-16H136V191.58c31.94-3.23,58.44-25.64,68.08-55.58H208a40,40,0,0,0,40-40V80A16,16,0,0,0,232,64ZM48,120A24,24,0,0,1,24,96V80H48v32q0,4,.39,8ZM232,96a24,24,0,0,1-24,24h-.5a81.81,81.81,0,0,0,.5-8.9V80h24Z',
    chrono: 'M128,40a96,96,0,1,0,96,96A96.11,96.11,0,0,0,128,40Zm45.66,61.66-40,40a8,8,0,0,1-11.32-11.32l40-40a8,8,0,0,1,11.32,11.32ZM96,16a8,8,0,0,1,8-8h48a8,8,0,0,1,0,16H104A8,8,0,0,1,96,16Z',
    cadenas: 'M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM96,56a32,32,0,0,1,64,0V80H96Z',
  };
  const GRIS = '#2C3640';

  /// Une couleur dont la clarté est multipliée, comme `_ton` dans l'appli.
  const ton = (hex, k) => {
    const [r, v, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
    const max = Math.max(r, v, b), min = Math.min(r, v, b), d = max - min;
    let h = 0;
    if (d) h = max === r ? ((v - b) / d) % 6 : max === v ? (b - r) / d + 2 : (r - v) / d + 4;
    const l0 = (max + min) / 2, s = d ? d / (1 - Math.abs(2 * l0 - 1)) : 0;
    const l = Math.min(1, Math.max(0, l0 * k));
    const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h % 2 + 2) % 2 - 1)), m = l - c / 2;
    const hh = ((h % 6) + 6) % 6;
    const [r1, v1, b1] = hh < 1 ? [c, x, 0] : hh < 2 ? [x, c, 0] : hh < 3 ? [0, c, x] : hh < 4 ? [0, x, c] : hh < 5 ? [x, 0, c] : [c, 0, x];
    return '#' + [r1, v1, b1].map((n) => Math.round((n + m) * 255).toString(16).padStart(2, '0')).join('').toUpperCase();
  };

  const hexa = (r) => 'M' + [0, 1, 2, 3, 4, 5].map((i) => {
    const a = (-90 + 60 * i) * Math.PI / 180;
    return `${(r * Math.cos(a)).toFixed(2)} ${(r * Math.sin(a)).toFixed(2)}`;
  }).join('L') + 'Z';
  const bouc = (r) => {
    const w = (r * 0.92).toFixed(2), n = (k) => (r * k).toFixed(2);
    return `M-${w} -${n(0.62)}Q0 -${n(1.02)} ${w} -${n(0.62)}L${w} ${n(0.12)}Q${w} ${n(0.72)} 0 ${n(1.04)}Q-${w} ${n(0.72)} -${w} ${n(0.12)}Z`;
  };

  // Les dégradés et les tracés partagés.
  const degrades = new Set();
  const idDeg = (c) => { degrades.add(c); return 'bd' + c.slice(1); };
  let defs = () => `<defs>
    ${Object.entries(PICTOS).map(([n, d]) => `<path id="bp-${n}" d="${d}"/>`).join('')}
    <path id="bh44" d="${hexa(44)}"/><path id="bh41" d="${hexa(41)}"/><path id="bb47" d="${bouc(47)}"/><path id="bb44" d="${bouc(44)}"/>
    <clipPath id="bch"><path d="${hexa(45)}"/></clipPath><clipPath id="bcb"><path d="${bouc(45.5)}"/></clipPath>
    <linearGradient id="bliser" gradientUnits="userSpaceOnUse" x1="0" y1="-50" x2="0" y2="52"><stop offset="0" stop-color="#FFF" stop-opacity="0.75"/><stop offset="0.5" stop-color="#FFF" stop-opacity="0"/></linearGradient>
    ${[...degrades].map((c) => `<linearGradient id="bd${c.slice(1)}" gradientUnits="userSpaceOnUse" x1="0" y1="-50" x2="0" y2="52"><stop offset="0" stop-color="${ton(c, 1.16)}"/><stop offset="0.55" stop-color="${c}"/><stop offset="1" stop-color="${ton(c, 0.84)}"/></linearGradient>`).join('')}
  </defs>`;

  /// Un écusson de l'appli, centré en (cx, cy), large de [l]. Le repère du
  /// dessin est celui du code : 120 sur 134, centre de la forme en (60, 60).
  const ecusson = (cx, cy, l, couleur, { picto = null, nombre = null, gagne = true, bouclier = false } = {}) => {
    const c = gagne ? couleur : GRIS;
    const bord = ton(c, 0.56), deg = `url(#${idDeg(c)})`;
    const dehors = bouclier ? 'bb47' : 'bh44', dedans = bouclier ? 'bb44' : 'bh41';
    const e1 = bouclier ? 8 : 14, e2 = bouclier ? 3 : 9;
    let s = `<g transform="translate(${cx},${cy}) scale(${(l / 120).toFixed(4)})" stroke-linejoin="round">
      <use href="#${dehors}" y="5" fill="#000" fill-opacity="0.55" stroke="#000" stroke-opacity="0.55" stroke-width="${e1}"/>
      <use href="#${dehors}" fill="${bord}" stroke="${bord}" stroke-width="${e1}"/>
      <use href="#${dedans}" fill="${deg}" stroke="${deg}" stroke-width="${e2}"/>
      <g clip-path="url(#${bouclier ? 'bcb' : 'bch'})"><ellipse cx="-18" cy="-48" rx="62" ry="40" fill="#FFF" fill-opacity="0.13"/><rect x="-60" y="26" width="120" height="50" fill="#000" fill-opacity="0.12"/></g>
      <use href="#${dedans}" fill="none" stroke="url(#bliser)" stroke-width="1.6"/>`;
    const cle = gagne ? picto : 'cadenas';
    if (cle) {
      const ech = gagne ? (bouclier ? 0.15 : 0.2) : 0.17;
      const haut = gagne ? (bouclier ? -40 : -31) : (bouclier ? -26 : -24);
      const op = gagne ? 1 : 0.28;
      s += `<g transform="translate(${-128 * ech},${haut}) scale(${ech})"><use href="#bp-${cle}" y="14" fill="${bord}" fill-opacity="${(0.7 * op).toFixed(2)}"/><use href="#bp-${cle}" fill="#FFF" fill-opacity="${op}"/></g>`;
    }
    if (gagne && nombre != null) {
      const texte = String(nombre);
      const corps = bouclier ? (texte.length <= 3 ? 30 : 24) : 33;
      s += `<text x="0" y="${bouclier ? 14 : 50}" font-family="${SANS}" font-size="${corps}" font-weight="900" letter-spacing="-1.4" text-anchor="middle" fill="#FFF" stroke="${bord}" stroke-opacity="${bouclier ? 0.55 : 1}" stroke-width="${bouclier ? 5 : 8}" paint-order="stroke">${texte}</text>`;
    }
    return s + '</g>';
  };

  // ------------------------------------------------------------ les données
  // [nom, ce qui est mesuré (deux lignes), unité, paliers, couleur, pictogramme, compteur de l'exemple]
  const BADGES = [
    ['Semaine parfaite', ['semaines où ton objectif', 'de séances est atteint'], ['semaine', 'semaines'], [1, 3, 5, 10, 15, 20, 30, 40, 50, 75], '#FF3347', 'cible', 6],
    ['Lève-tôt', ['séances commencées', 'entre 4 h et 7 h'], ['séance', 'séances'], [1, 5, 10, 25, 50, 75, 100, 150, 200, 300], '#FF8419', 'aube', 4],
    ['Série', ['ta plus longue suite de', 'semaines avec une séance'], ['semaine', 'semaines'], [2, 4, 8, 12, 15, 20, 26, 39, 52, 104], '#FFBE0B', 'flamme', 9],
    ['Guerrier du week-end', ['séances commencées un', 'samedi ou un dimanche'], ['séance', 'séances'], [1, 5, 10, 25, 50, 75, 100, 150, 200, 300], '#2FCF55', 'epee', 12],
    ['Collectionneur de routines', ['routines dans', 'ta bibliothèque'], ['routine', 'routines'], [1, 3, 5, 10, 25], '#0FC9AE', 'cartes', 4],
    ['Explorateur d’exercices', ['exercices différents,', 'une série faite au moins'], ['exercice', 'exercices'], [5, 10, 25, 50, 75, 100, 150, 200, 300, 400], '#1FA8FF', 'fiole', 31],
    ['Marathon', ['séances de 2 h ou plus,', 'et de moins de 12 h'], ['séance', 'séances'], [1, 5, 10, 25, 50], '#3F66FF', 'chrono', 0],
    ['Noctambule', ['séances finies après', '23 h ou avant 4 h'], ['séance', 'séances'], [1, 5, 10, 25, 50, 75, 100, 150, 200, 300], '#8B55FF', 'lune', 1],
    ['Chasseur de records', ['exercices où tu tiens', 'un record de charge'], ['record', 'records'], [1, 5, 10, 25, 50, 75, 100, 150, 200, 300], '#FF48B0', 'trophee', 14],
  ];
  const niveau = (v, paliers) => paliers.filter((p) => v >= p).length;
  const compte = (n, [un, plusieurs]) => `${n} ${n >= 2 ? plusieurs : un}`;

  let corps = '';
  corps += t(60, 52, 'LES BADGES', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(200, 52, 'Neuf habitudes comptées sur tes séances terminées. Ni points, ni rang : un seuil atteint, un niveau de plus.', { taille: 14 });

  // ------------------------------------------------------------ les neuf badges
  const GX = 60, GY = 80, GL = 770, GH = 480;
  corps += `<rect x="${GX}" y="${GY}" width="${GL}" height="${GH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(GX + 22, GY + 30, 'NEUF BADGES À PALIERS', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const etat = (texte, c) => `<rect x="${GX + GL - 232}" y="${GY + 13}" width="210" height="26" rx="13" fill="${c}" fill-opacity="0.1" stroke="${c}" stroke-opacity="0.5"/>
    ${t(GX + GL - 127, GY + 30.5, texte, { taille: 11.5, couleur: c, poids: 700, ancre: 'middle' })}`;
  corps += g(0.004, T.apres, etat('au départ : 0 sur 9 gagnés', TEXTE));
  corps += g(T.apres, T.compte, etat('42 séances plus tard…', TEXTE));
  corps += g(T.compte, FIN, etat('8 sur 9 gagnés', VERT));

  const CL = 240, CH = 136, CPX = 11, CPY = 8;
  const caseX = (i) => GX + 14 + (i % 3) * (CL + CPX), caseY = (i) => GY + 46 + Math.floor(i / 3) * (CH + CPY);
  let rang = 0;
  BADGES.forEach(([nom, mesure, unite, paliers, couleur, picto, valeur], i) => {
    const x = caseX(i), y = caseY(i), leve = nom === 'Lève-tôt';
    const n = niveau(valeur, paliers), gagne = n > 0;
    const quand = gagne ? T.gagne(rang++) : null;
    corps += `<rect x="${x}" y="${y}" width="${CL}" height="${CH}" rx="12" fill="#101216" stroke="${BORD}"/>`;
    if (gagne) corps += `<rect x="${x}" y="${y}" width="${CL}" height="${CH}" rx="12" fill="${couleur}" fill-opacity="0.05" stroke="${couleur}" stroke-opacity="0.35" opacity="0">${visible(C, quand, FIN, 0.006)}</rect>`;
    // « Série » est aussi une série d'exercice dans le dictionnaire commun : ici, c'est une suite de semaines.
    corps += t(x + 14, y + 23, EN && nom === 'Série' ? 'Streak' : nom, { taille: 13, couleur: TITRE, poids: 700 });
    mesure.forEach((s, k) => { corps += t(x + 92, y + 50 + k * 15, s, { taille: 11.5 }); });
    const cx = x + 14 + 33, cy = y + 34 + 33;
    // Gris et cadenassé, puis à sa couleur, avec son dernier palier atteint.
    const gris = `${ecusson(cx, cy, 66, couleur, { gagne: false })}${t(x + 92, y + 88, 'à gagner', { taille: 11.5, couleur: DISCRET, poids: 700 })}`;
    if (!gagne) {
      corps += gris;
    } else {
      corps += g(0.004, quand, gris);
      const fin = leve ? T.palier : FIN;
      corps += g(quand, fin, `${ecusson(cx, cy, 66, couleur, { picto, nombre: paliers[n - 1] })}
        ${t(x + 92, y + 88, `${n} sur ${paliers.length}`, { taille: 11.5, couleur: TITRE, poids: 700 })}
        ${t(x + 92, y + 103, compte(valeur, unite), { taille: 11, couleur: DISCRET })}`);
      if (leve) {
        corps += g(T.palier, FIN, `${ecusson(cx, cy, 66, couleur, { picto, nombre: paliers[n] })}
          ${t(x + 92, y + 88, `${n + 1} sur ${paliers.length}`, { taille: 11.5, couleur: TITRE, poids: 700 })}
          ${t(x + 92, y + 103, compte(valeur + 1, unite), { taille: 11, couleur: DISCRET })}`);
        corps += `<rect x="${x}" y="${y}" width="${CL}" height="${CH}" rx="12" fill="none" stroke="${couleur}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, T.ev1, T.indice, 0.006)}</rect>`;
      }
    }
    // Les seuils : ceux qui sont atteints prennent la couleur du badge.
    let px = x + 14;
    paliers.forEach((p, k) => {
      const s = String(p);
      corps += `<text x="${px}" y="${y + 125}" font-family="${MONO}" font-size="10" font-weight="700" fill="#4A4C55">${s}</text>`;
      const de = k < n ? quand : (leve && k === n ? T.palier : null);
      if (de != null) corps += `<text x="${px}" y="${y + 125}" font-family="${MONO}" font-size="10" font-weight="700" fill="${couleur}" opacity="0">${visible(C, de, FIN, 0.006)}${s}</text>`;
      px += s.length * 6.02 + 7;
    });
  });

  // ------------------------------------------------------------ le détail d'un badge
  const RX = 846, RL = 374, RY = 80, RH = 480, RC = RX + RL / 2;
  const [, , uniteLeve, paliersLeve, ORANGE] = BADGES[1];
  corps += `<rect x="${RX}" y="${RY}" width="${RL}" height="${RH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(RX + 22, RY + 30, 'LE DÉTAIL D’UN BADGE, DANS L’APPLI', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const FX = RX + 14, FY = RY + 46, FL = RL - 28, FH = 310;
  corps += `<rect x="${FX}" y="${FY}" width="${FL}" height="${FH}" rx="22" fill="${APP.fond}" stroke="${APP.trait}"/>
    <rect x="${RC - 18}" y="${FY + 9}" width="36" height="4" rx="2" fill="${APP.carte3}"/>`;
  corps += t(RC, FY + 40, 'Lève-tôt', { taille: 17, couleur: APP.texte, poids: 800, ancre: 'middle' });
  corps += t(RC, FY + 186, 'Séances commencées avant 7 h du matin', { taille: 11.5, couleur: APP.second, ancre: 'middle' });
  const JX = FX + 22, JL = FL - 44, JY = FY + 226;
  corps += `<rect x="${JX}" y="${JY}" width="${JL}" height="7" rx="3.5" fill="${APP.carte3}"/>`;
  // Trois états : rien, palier 1 (4 séances), palier 5 (5 séances).
  const etats = [
    [0.004, T.gagne(1), { gagne: false }, '0 séance', 0, 'Encore 1 séance pour le niveau 1', 0],
    [T.gagne(1), T.palier, { nombre: 1 }, 'Niveau 1 · 4 séances', 0.75, 'Encore 1 séance pour le niveau 2', 1],
    [T.palier, FIN, { nombre: 5 }, 'Niveau 2 · 5 séances', 0, 'Encore 5 séances pour le niveau 3', 2],
  ];
  etats.forEach(([de, a, e, ligne, , encore]) => {
    corps += g(de, a, `${ecusson(RC, FY + 54 + 55, 110, ORANGE, { picto: 'aube', ...e })}
      ${t(RC, FY + 212, ligne, { taille: 13.5, couleur: APP.texte, poids: 700, ancre: 'middle' })}
      ${t(RC, FY + 252, encore, { taille: 11, couleur: APP.second, ancre: 'middle' })}`);
  });
  // La jauge : la part du chemin entre le palier atteint et le suivant.
  corps += `<rect x="${JX}" y="${JY}" height="7" rx="3.5" fill="${APP.texte}" width="0">
    ${fondu('width', C, [[0, 0], [T.gagne(1) - 0.006, 0], [T.gagne(1) + 0.02, JL * 0.75], [T.ev1, JL * 0.75], [T.palier - 0.012, JL], [T.palier, JL], [T.palier + 0.012, 0], [1, 0]])}</rect>`;
  // Les paliers en pastilles : blanches une fois atteintes.
  const PL = 30, PP = (JL + 10 - 10 * PL) / 9;
  paliersLeve.forEach((p, k) => {
    const x = JX - 5 + k * (PL + PP), y = FY + 266;
    corps += `<rect x="${x}" y="${y}" width="${PL}" height="24" rx="10" fill="${APP.carte3}"/>
      <text x="${x + PL / 2}" y="${y + 16}" font-family="${SANS}" font-size="10.5" font-weight="700" fill="${APP.second}" text-anchor="middle">${p}</text>`;
    const de = k === 0 ? T.gagne(1) : k === 1 ? T.palier : null;
    if (de != null) corps += g(de, FIN, `<rect x="${x}" y="${y}" width="${PL}" height="24" rx="10" fill="#FFFFFF"/>
      <text x="${x + PL / 2}" y="${y + 16}" font-family="${SANS}" font-size="10.5" font-weight="700" fill="#000" text-anchor="middle">${p}</text>`);
  });
  corps += `<rect x="${FX}" y="${FY}" width="${FL}" height="${FH}" rx="22" fill="none" stroke="${ORANGE}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, T.palier, T.palier + 0.07, 0.006)}</rect>`;

  // Ce qui fait bouger les compteurs : deux séances, le même jour.
  const EY = FY + FH + 12;
  corps += g(0.004, T.ev1, `${t(RX + 22, EY + 22, 'Chaque séance terminée est recomptée : rien à', { taille: 12.5 })}
    ${t(RX + 22, EY + 40, 'réclamer, le badge monte quand le seuil est atteint.', { taille: 12.5 })}`);
  const evenement = (y, heure, texte, effet, c) => `<rect x="${RX + 14}" y="${y}" width="${RL - 28}" height="46" rx="12" fill="#101216" stroke="${c}" stroke-opacity="0.5"/>
    <circle cx="${RX + 36}" cy="${y + 23}" r="5" fill="${c}"/>
    ${t(RX + 52, y + 19, heure, { taille: 12.5, couleur: TITRE, poids: 700 })}
    ${t(RX + 52, y + 36, texte, { taille: 11.5 })}
    ${t(RX + RL - 26, y + 28, effet, { taille: 11.5, couleur: c, poids: 700, ancre: 'end' })}`;
  corps += g(T.ev1, FIN, evenement(EY, 'Mardi, 6 h 42', 'une séance commence', '5ᵉ avant 7 h', ORANGE));
  corps += g(T.ev2, FIN, evenement(EY + 54, 'Le même mardi, 18 h 10', 'une deuxième séance', '2 le même jour', '#2FCF55'));

  // ------------------------------------------------------------ les secrets
  const BY = 576, BH = 180;
  const SX = 60, SL = 586;
  corps += `<rect x="${SX}" y="${BY}" width="${SL}" height="${BH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(SX + 22, BY + 30, 'SIX BADGES SECRETS', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  corps += g(0.004, T.double, t(SX + SL - 22, BY + 30, '0 sur 6', { taille: 11.5, couleur: TEXTE, poids: 700, ancre: 'end' }));
  corps += g(T.double, FIN, t(SX + SL - 22, BY + 30, '1 sur 6', { taille: 11.5, couleur: VERT, poids: 700, ancre: 'end' }));
  const SECRETS = [['#0FC9AE'], ['#FF3347'], ['#FF8419'], ['#8B55FF'], ['#2FCF55', 'Doublé', 'epee'], ['#1FA8FF']];
  const pas = (l) => (l - 28) / 6;
  SECRETS.forEach(([couleur, nom, picto], k) => {
    const cx = SX + 14 + pas(SL) * (k + 0.5), cy = BY + 44 + 32;
    const cache = `${ecusson(cx, cy, 62, couleur, { gagne: false })}
      ${t(cx, BY + 132, '???', { taille: 11.5, couleur: TEXTE, poids: 700, ancre: 'middle' })}
      ${t(cx, BY + 147, 'secret', { taille: 10.5, couleur: DISCRET, ancre: 'middle' })}`;
    if (!nom) { corps += cache; return; }
    corps += g(0.004, T.double, cache);
    corps += g(T.double, FIN, `${ecusson(cx, cy, 62, couleur, { picto, nombre: 1 })}
      ${t(cx, BY + 132, nom, { taille: 11.5, couleur: TITRE, poids: 700, ancre: 'middle' })}
      ${t(cx, BY + 147, '1 jour', { taille: 10.5, couleur: DISCRET, ancre: 'middle' })}`);
    corps += `<circle cx="${cx}" cy="${cy}" r="36" fill="none" stroke="${couleur}" stroke-width="2" opacity="0">
      ${fondu('opacity', C, [[0, 0], [T.double, 0], [T.double + 0.004, 0.9], [T.double + 0.05, 0], [1, 0]])}
      ${fondu('r', C, [[0, 30], [T.double, 30], [T.double + 0.05, 62], [1, 62]])}</circle>`;
  });
  corps += g(0.004, T.indice, t(SX + 22, BY + 168, 'Sous « ??? » tant que leur compteur est à zéro : aucun palier, le chiffre est le compteur.', { taille: 11.5, couleur: DISCRET }));
  corps += g(T.indice, T.double, t(SX + 22, BY + 168, 'Touché, un secret ne donne qu’un indice : « Une seule séance par jour ne suffit pas. »', { taille: 11.5, couleur: TEXTE }));
  corps += g(T.double, FIN, t(SX + 22, BY + 168, '« Doublé » : deux séances le même jour. Chaque jour où tu doubles compte pour un.', { taille: 11.5, couleur: TITRE }));

  // ------------------------------------------------------------ les étapes
  const EX = 660, EL = 560;
  corps += `<rect x="${EX}" y="${BY}" width="${EL}" height="${BH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += t(EX + 22, BY + 30, 'ÉTAPES IMPORTANTES', { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  [[0.004, T.apres, '0 séance terminée'], [T.apres, T.ev1, '42 séances terminées'], [T.ev1, T.ev2, '43 séances terminées'], [T.ev2, FIN, '44 séances terminées']].forEach(([de, a, s]) => {
    corps += g(de, a, t(EX + EL - 22, BY + 30, s, { taille: 11.5, couleur: de === 0.004 ? TEXTE : TITRE, poids: 700, ancre: 'end' }));
  });
  // Les trois dernières atteintes et les trois suivantes ; les couleurs
  // tournent parmi celles des neuf badges, décalées de trois.
  const ETAPES = [1, 10, 25, 50, 100, 150];
  const arc = BADGES.map((b) => b[4]);
  ETAPES.forEach((n, k) => {
    const cx = EX + 14 + pas(EL) * (k + 0.5), cy = BY + 44 + 32, couleur = arc[(k + 3) % arc.length];
    const nom = (c) => t(cx, BY + 132, n >= 2 ? `${n} séances` : `${n} séance`, { taille: 11.5, couleur: c, poids: 700, ancre: 'middle' });
    const detail = (s, c = DISCRET) => t(cx, BY + 147, s, { taille: 10.5, couleur: c, ancre: 'middle' });
    const verrou = ecusson(cx, cy, 62, couleur, { gagne: false, bouclier: true });
    if (k < 3) {
      corps += g(0.004, T.apres, `${verrou}${nom(TEXTE)}${detail(k === 0 ? 'encore 1' : 'à venir')}`);
      corps += g(T.apres, FIN, `${ecusson(cx, cy, 62, couleur, { nombre: n, bouclier: true })}${nom(TITRE)}${detail('atteint', VERT)}`);
    } else {
      corps += g(T.apres, FIN, `${verrou}${nom(TEXTE)}`);
      if (k === 3) [[T.apres, T.ev1, 'encore 8'], [T.ev1, T.ev2, 'encore 7'], [T.ev2, FIN, 'encore 6']].forEach(([de, a, s]) => { corps += g(de, a, detail(s, TEXTE)); });
      else corps += g(T.apres, FIN, detail('à venir'));
    }
  });
  corps += t(EX + 22, BY + 168, 'En boucliers : 18 étapes, de 1 à 2 000 séances. Ici, les 3 dernières atteintes et les 3 suivantes.', { taille: 11.5, couleur: DISCRET });

  corps += t(640, 786, 'Seules les séances terminées comptent. Gris et cadenassé tant que rien n’est gagné ; ensuite, le dernier palier atteint s’écrit en gros sur l’écusson.', { taille: 13, couleur: DISCRET, ancre: 'middle' });

  svg('badges.svg', 1280, 810, defs() + corps,
    'Les badges d’AESTHETICS. Neuf badges à paliers, en écussons hexagonaux de leur couleur, gris avec un cadenas tant que rien n’est gagné : Semaine parfaite (semaines où ton objectif de séances est atteint ; paliers 1, 3, 5, 10, 15, 20, 30, 40, 50, 75), Lève-tôt (séances commencées entre 4 h et 7 h ; 1, 5, 10, 25, 50, 75, 100, 150, 200, 300), Série (ta plus longue suite de semaines avec une séance ; 2, 4, 8, 12, 15, 20, 26, 39, 52, 104), Guerrier du week-end (séances commencées un samedi ou un dimanche ; mêmes paliers que Lève-tôt), Collectionneur de routines (routines dans ta bibliothèque ; 1, 3, 5, 10, 25), Explorateur d’exercices (exercices différents avec au moins une série faite ; 5, 10, 25, 50, 75, 100, 150, 200, 300, 400), Marathon (séances de deux heures ou plus, et de moins de douze ; 1, 5, 10, 25, 50), Noctambule (séances finies après 23 h ou avant 4 h ; mêmes paliers que Lève-tôt) et Chasseur de records (exercices où tu tiens un record de charge ; mêmes paliers). Après 42 séances, huit sont gagnés sur neuf et chaque écusson porte en gros son dernier palier atteint ; Marathon reste gris. Le détail de Lève-tôt, comme dans l’appli : « Niveau 1 · 4 séances », une jauge, « Encore 1 séance pour le niveau 2 ». Un mardi à 6 h 42, une cinquième séance commence avant 7 h : le seuil est atteint, l’écusson passe de 1 à 5, « Niveau 2 · 5 séances », « Encore 5 séances pour le niveau 3 ». Six badges secrets s’affichent « ??? » tant que leur compteur est à zéro et ne donnent qu’un indice ; une deuxième séance le même mardi révèle « Doublé », deux séances le même jour. Les étapes importantes, en boucliers, comptent les séances terminées : 1, 10 et 25 sont atteintes, il en reste 6 avant celle des 50. Ni points d’expérience, ni rang.');
};
