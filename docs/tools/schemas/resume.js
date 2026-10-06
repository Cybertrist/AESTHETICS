// Le résumé mensuel, façon story.
//
// Au centre, un téléphone fait défiler les dix pages du résumé de
// septembre 2026, une touche à droite pour avancer. À gauche, la liste des
// dix pages. À droite, la cinquième page décortiquée : le volume du mois
// converti en un objet et un « × N », avec l'échelle des 25 objets et la
// règle qui choisit.
//
// Le mois est un exemple, mais rien n'est écrit à la main : la table et le
// choix de `lib/core/logic/equivalents.dart` sont repris ici, comme les
// écarts, la série de semaines et les cases du calendrier.
module.exports = (O) => {
  const { svg, t, tr, paliers, fondu, visible, toucher, MONO, SANS, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT } = O;
  const C = 30, FIN = 0.972;
  const BLANC = '#FFFFFF', ENCRE2 = 'rgba(255,255,255,0.6)', HAUSSE = '#86F05A';
  const nombre = (v) => String(Math.round(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

  // --------------------------------------------------- les objets
  // [nom, pluriel, masse en kg, couleur du fond, couleur d'accent, sorte]
  const OBJETS = [
    ['burger', 'burgers', 0.25, '#7A1F2B', '#FFB3A8', 'absurde'], ['baguette', 'baguettes', 0.25, '#7A4A1E', '#FFE2A8', 'absurde'],
    ['chat', 'chats', 4, '#7A4A1E', '#FFD9A8'], ['toilettes', 'toilettes', 30, '#1F5D7A', '#9FE3FF'], ['canapé', 'canapés', 50, '#4A3A78', '#C9B6FF'],
    ['baignoire', 'baignoires', 150, '#12406B', '#8FD3FF'], ['gorille', 'gorilles', 160, '#3A3F4A', '#D6DDE8'], ['moto', 'motos', 200, '#5A1A1A', '#FF9A8A'],
    ['cheval', 'chevaux', 500, '#5A3A1C', '#F0C890'], ['vache', 'vaches', 700, '#2C6B34', '#D9FF7A'], ['requin', 'requins', 1000, '#0F3D5C', '#8FD3FF'],
    ['girafe', 'girafes', 1200, '#7A5A0C', '#FFD84D'], ['tracteur', 'tracteurs', 3600, '#2C6B34', '#D9FF7A'],
    ['soucoupe volante', 'soucoupes volantes', 5000, '#1B1650', '#B6A8FF'], ['mammouth', 'mammouths', 6000, '#6B3A14', '#FFCF99'],
    ['éléphant', 'éléphants', 6000, '#4A3A78', '#C9B6FF'], ['tyrannosaure', 'tyrannosaures', 8000, '#1F5D2C', '#B9F27A'], ['bus', 'bus', 11000, '#7A5A0C', '#FFD84D'],
    ['statue de l’île de Pâques', 'statues de l’île de Pâques', 11000, '#3A3F4A', '#D6DDE8'], ['camion de pompiers', 'camions de pompiers', 14000, '#8A1F1F', '#FFB199'],
    ['diplodocus', 'diplodocus', 15000, '#2A5A4A', '#A8F0C8'], ['fusée', 'fusées', 26000, '#1B1650', '#FFB02E'], ['baleine à bosse', 'baleines à bosse', 30000, '#12406B', '#6FD0FF'],
    ['avion de ligne', 'avions de ligne', 41000, '#1F5D7A', '#9FE3FF'], ['statue de la Liberté', 'statues de la Liberté', 225000, '#0F5A52', '#7FF0D8', 'pourcent'],
  ].map(([nom, pluriel, kg, couleur, accent, sorte]) => ({ nom, pluriel, kg, couleur, accent, sorte }));
  const LIBERTE = OBJETS.find((o) => o.sorte === 'pourcent');
  // Un entier quand il ne trahit pas le rapport (8 % au plus) ou dès 10 ;
  // sinon une décimale.
  const arrondir = (r) => {
    const e = Math.round(r), erreurEntier = e <= 0 ? 1 : Math.abs(e - r) / r;
    if (erreurEntier <= 0.08 || r >= 10) return { valeur: e, decimale: false, erreur: erreurEntier };
    const d = Math.round(r * 10) / 10;
    return { valeur: d, decimale: d !== Math.round(d), erreur: Math.abs(d - r) / r };
  };
  const chiffre = (m) => (m.decimale ? `${nombre(Math.floor(m.valeur))},${Math.round((m.valeur - Math.floor(m.valeur)) * 10)}` : nombre(m.valeur));
  // `equivalentPour(kg, graine, mois: true)`.
  const equivalent = (kg, graine) => {
    const lisibles = [];
    for (const o of OBJETS) {
      if (o.sorte === 'absurde') continue;
      const r = kg / o.kg;
      if (r < 0.93 || r >= 99.5) continue;
      lisibles.push({ o, ...arrondir(r) });
    }
    lisibles.sort((a, b) => {
      if (a.decimale !== b.decimale) return a.decimale ? 1 : -1;
      const e = Math.floor(a.erreur * 50) - Math.floor(b.erreur * 50);
      return e !== 0 ? e : a.valeur - b.valeur;
    });
    const part = kg / LIBERTE.kg * 100, enPourcent = part >= 10 && part < 93;
    const nb = lisibles.length + (enPourcent ? 1 : 0);
    const minuscule = Math.round(kg / 0.25);
    if (nb === 0 || (graine % 6 === 5 && kg >= 50)) throw new Error('exemple à revoir : la graine sort un objet minuscule');
    const rang = Math.floor(graine / 6) * 5 + graine % 6, i = rang % nb;
    if (i >= lisibles.length) throw new Error('exemple à revoir : la graine sort le pourcentage');
    const m = lisibles[i];
    return { lisibles, part: Math.round(part), enPourcent, nb, rang, i, minuscule, o: m.o, m, etiquette: `× ${chiffre(m)}`, fort: `${chiffre(m)} ${m.valeur >= 2 ? m.o.pluriel : m.o.nom}` };
  };

  // --------------------------------------------------- le mois d'exemple
  const AN = 2026, MOIS = 9; // septembre 2026
  const COURTS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const ROUTINES = ['Pectoraux et triceps', 'Dos et biceps', 'Jambes'];
  // [jour, routine, minutes, volume en kg]
  const SEANCES = [[2, 0, 62, 5480], [4, 1, 58, 5120], [7, 2, 71, 6880], [9, 0, 64, 5560], [11, 1, 55, 5040], [14, 2, 74, 7010],
    [16, 0, 61, 5610], [18, 1, 60, 5230], [21, 2, 69, 6950], [23, 0, 66, 5720], [25, 1, 57, 5190], [28, 2, 76, 7120]];
  const VOLUME = SEANCES.reduce((a, s) => a + s[3], 0), MINUTES = SEANCES.reduce((a, s) => a + s[2], 0);
  // Douze mois de volume, d'octobre 2025 à septembre 2026 ; août : 10 séances.
  const VOLUMES = [48200, 51900, 44600, 55300, 53800, 60100, 58700, 64900, 61200, 57400, 63300, VOLUME];
  const SEANCES_AOUT = 10;
  const ecart = (actuel, avant) => Math.round((actuel - avant) / avant * 100);
  const ECART_SEANCES = ecart(SEANCES.length, SEANCES_AOUT), ECART_VOLUME = ecart(VOLUME, VOLUMES[10]);
  // Les jours de séance, mois par mois : le calendrier de la page « régularité » et la série.
  const JOURS = {
    1: [5, 7, 9, 12, 16, 19, 23, 26, 30], 2: [2, 4, 9, 11, 13, 18, 20, 23, 27], 3: [2, 4, 6, 9, 13, 16, 18, 20, 25, 27, 30],
    4: [1, 3, 8, 10, 13, 15, 20, 22, 24, 29], 5: [4, 6, 8, 11, 13, 15, 18, 20, 22, 25, 27, 29], 6: [1, 3, 5, 8, 10, 15, 17, 19, 22, 24, 29],
    7: [1, 3, 6, 8, 10, 20, 22, 27, 29], 8: [3, 5, 7, 10, 12, 17, 19, 24, 26, 31], 9: SEANCES.map((s) => s[0]),
  };
  // La série : les semaines d'affilée avec une séance, comptées au dernier
  // jour du mois (`Dates.semainesConsecutives`, semaine du lundi).
  const lundi = (d) => { const x = new Date(d); x.setDate(x.getDate() - (x.getDay() + 6) % 7); return x.getTime(); };
  const SERIE = (() => {
    const semaines = new Set();
    for (const m in JOURS) for (const j of JOURS[m]) semaines.add(lundi(new Date(AN, m - 1, j)));
    let s = new Date(lundi(new Date(AN, MOIS, 0))), n = semaines.has(s.getTime()) ? 1 : 0;
    for (;;) { s.setDate(s.getDate() - 7); if (!semaines.has(s.getTime())) return n; n++; }
  })();
  // La toile : les séries par muscle du mois et du mois d'avant.
  const TOILE = [['Pectoraux', 64, 54], ['Épaules', 52, 44], ['Triceps', 58, 50], ['Grand dorsal', 60, 52], ['Biceps', 46, 40], ['Abdominaux', 24, 20], ['Quadriceps', 56, 44], ['Ischios', 38, 30], ['Trapèzes', 30, 26]];
  const RECORDS = [['Squat', '110 kg × 5'], ['Développé couché', '85 kg × 6'], ['Tirage vertical', '70 kg × 8']];
  const FAVORIS = [['Développé couché', 16], ['Squat', 16], ['Tirage vertical', 16], ['Soulevé de terre', 12], ['Rowing barre', 12]];
  const GRAINE = AN * 12 + MOIS;
  const EQ = equivalent(VOLUME, GRAINE);
  // L'année, jusqu'ici : la graine devient l'année.
  const VOLUME_AN = VOLUMES.slice(3).reduce((a, v) => a + v, 0), EQ_AN = equivalent(VOLUME_AN, AN);
  const duree = (min) => (min >= 60 ? `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, '0')}` : `${min} min`);

  // --------------------------------------------------- le récit
  const PAS = 0.085;
  const p = (k) => 0.012 + k * PAS + (k > 4 ? PAS : 0); // l'entrée de la page k ; la cinquième reste deux fois plus
  const R = { lisibles: p(4) + 0.02, tri: p(4) + 0.06, choix: p(4) + 0.105 };
  const g = (de, a, contenu, douceur = 0.006) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  const pendant = (k, contenu) => {
    const pas = k === 0 ? [[0, 1], [p(1), 0]] : k === 9 ? [[0, 0], [p(9), 1]] : [[0, 0], [p(k), 1], [p(k + 1), 0]];
    return `<g opacity="${k === 0 ? 1 : 0}">${paliers('opacity', C, pas)}${contenu}</g>`;
  };
  const titreBloc = (x, y, s, couleur = DISCRET) => t(x, y, s, { taille: 11, couleur, police: MONO, poids: 700, extra: 'letter-spacing="2"' });

  let corps = '';
  corps += t(60, 52, 'LE RÉSUMÉ MENSUEL', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(Math.round(66 + tr('LE RÉSUMÉ MENSUEL').length * 10.9 + 24), 52, 'Dix pages façon story, une touche pour avancer. La cinquième pèse le mois en objets.', { taille: 14 });

  // --------------------------------------------------- les dix pages, à gauche
  const LX = 60, LL = 268, LY = 104, LPAS = 60;
  const PAGES = [
    ['Ouverture', 'Sept barres et le titre,', 'sur fond noir.'],
    ['Les séances', 'Une ligne par séance : sa durée,', 'son volume, puis le total.'],
    ['La régularité', 'Le nombre de séances, et', 'le calendrier du mois.'],
    ['Le volume', 'Le poids soulevé, et douze', 'mois en barres.'],
    ['En objets', 'Le volume du mois converti', 'en un objet : « × N ».'],
    ['La série', 'Les semaines d’affilée avec', 'au moins une séance.'],
    ['Les muscles', 'Une toile à neuf axes, devant', 'celle du mois d’avant.'],
    ['Les records', 'Les cinq plus fortes', 'progressions du mois.'],
    ['Les favoris', 'Les cinq exercices', 'les plus pratiqués.'],
    ['Le résumé', 'Tout le mois sur une page,', 'prête à partager.'],
  ];
  corps += titreBloc(LX, 92, 'LES DIX PAGES, DANS L’ORDRE');
  PAGES.forEach(([nom, l1, l2], k) => {
    const y = LY + k * LPAS;
    corps += `<rect x="${LX}" y="${y}" width="${LL}" height="${LPAS - 8}" rx="12" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${LX}" y="${y}" width="${LL}" height="${LPAS - 8}" rx="12" fill="${ACCENT}" fill-opacity="0.08" stroke="${ACCENT}" stroke-width="1.5" opacity="${k === 0 ? 1 : 0}">${paliers('opacity', C, k === 0 ? [[0, 1], [p(1), 0]] : k === 9 ? [[0, 0], [p(9), 1]] : [[0, 0], [p(k), 1], [p(k + 1), 0]])}</rect>
      <circle cx="${LX + 24}" cy="${y + 26}" r="13" fill="${ACCENT}" fill-opacity="0.14" stroke="${ACCENT}" stroke-opacity="0.55"/>
      ${t(LX + 24, y + 30.5, String(k + 1), { taille: 12, couleur: ACCENT, police: MONO, poids: 700, ancre: 'middle' })}
      ${t(LX + 48, y + 20, nom, { taille: 13, couleur: TITRE, poids: 700 })}
      ${t(LX + 48, y + 35, l1, { taille: 11 })}${t(LX + 48, y + 48, l2, { taille: 11 })}`;
  });
  const NY = LY + 10 * LPAS + 16;
  corps += t(LX, NY, 'Aucune minuterie : on touche l’écran pour', { taille: 12 }) + t(LX, NY + 17, 'avancer, son tiers gauche pour revenir.', { taille: 12 });
  corps += t(LX, NY + 40, '« Partager » envoie la page affichée,', { taille: 12, couleur: DISCRET }) + t(LX, NY + 57, 'en image.', { taille: 12, couleur: DISCRET });

  // --------------------------------------------------- le téléphone
  const PX = 350, PY = 84, PL = 326, PH = 706;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  const G = SX + 22, D = SX + SL - 22, W = D - G, CX = SX + SL / 2, MIL = SY + 322; // la page : ses bords, son milieu
  const FONDS = [['#000000', '#000000'], ['#2C2C30', '#050506'], ['#226640', '#000000'], ['#175673', '#000000'], [EQ.o.couleur, '#000000'],
    ['#8A3B14', '#000000'], ['#0D1838', '#02040A'], ['#7D5C12', '#000000'], ['#0E2B2B', '#020606'], ['#8A3B14', '#000000']];
  corps += `<defs>${FONDS.map(([h, b], k) => `<linearGradient id="resumeFond${k}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${h}"/><stop offset="0.68" stop-color="${b}"/></linearGradient>`).join('')}
    <filter id="resumeRouge" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="0.41 1.38 0.14 0 0  0.10 0.35 0.04 0 0  0.11 0.38 0.04 0 0  0 0 0 1 0"/></filter>
    <radialGradient id="resumeHalo"><stop offset="0" stop-color="${EQ.o.accent}" stop-opacity="0.5"/><stop offset="1" stop-color="${EQ.o.accent}" stop-opacity="0"/></radialGradient>
    <clipPath id="ecranResume"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="30"/></clipPath></defs>`;
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="42" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="30" fill="#000000"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  // Les textes des pages : blancs, en gras, comme une affiche.
  const b = (x, y, s, taille, o = {}) => t(x, y, s, { taille, couleur: BLANC, poids: 800, ...o });
  // « Série » veut dire ailleurs une série d'exercice : ici la série de semaines se traduit avec son voisin, d'un bloc.
  const brut = (x, y, s, taille, { couleur = BLANC, poids = 800, ancre = 'start' } = {}) => `<text x="${x}" y="${y}" font-family="${SANS}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}">${O.esc(s)}</text>`;
  const haltere = (x, y, k = 1) => `<g transform="translate(${x},${y}) scale(${k}) rotate(-45)" fill="none" stroke="${BLANC}" stroke-width="2.6" stroke-linecap="round"><path d="M-12 0 H12 M-15 -10 V10 M-21 -6 V6 M15 -10 V10 M21 -6 V6"/></g>`;
  const ecartLigne = (x, y, e, suite, ancre = 'middle') => {
    const l = (`${e} % ${tr(suite)}`.length * 5.9 + 14) * (ancre === 'middle' ? 0.5 : 0);
    return `<path d="M${x - l} ${y} h9 l-4.5 -7 z" fill="${HAUSSE}"/>
      <text x="${x - l + 14}" y="${y}" font-family="${SANS}" font-size="11.5" font-weight="800" fill="${HAUSSE}">${e} % <tspan fill="${ENCRE2}" font-weight="600">${O.esc(tr(suite))}</tspan></text>`;
  };
  const grandVolume = (y, taille) => `<text x="${CX}" y="${y}" text-anchor="middle" font-family="${SANS}" font-size="${taille}" font-weight="800" fill="${BLANC}" letter-spacing="${-taille * 0.03}">${nombre(VOLUME)}<tspan font-size="${taille * 0.4}" letter-spacing="0"> kg</tspan></text>`;
  const titreMois = (x, y, taille) => b(x, y, 'SEPTEMBRE', taille) + b(x, y + taille, String(AN), taille);
  const page = [];

  // 1 · l'ouverture
  {
    const H = 182, l = (W - 6 * 7) / 7, y0 = MIL - 140;
    page.push([0.35, 0.55, 0.45, 0.72, 0.60, 0.85, 1.0].map((h, i) => `<rect x="${(G + i * (l + 7)).toFixed(1)}" y="${(y0 + H * (1 - h)).toFixed(1)}" width="${l.toFixed(1)}" height="${(H * h).toFixed(1)}" rx="5.5" fill="${ACCENT}"/>`).join('')
      + b(CX, y0 + H + 52, 'Résumé', 28, { ancre: 'middle' }) + b(CX, y0 + H + 90, 'mensuel', 28, { ancre: 'middle' }));
  }
  // 2 · les séances
  {
    const y0 = MIL - 140, ligne = (y, nom, d, v) => b(G, y, nom, 9.6) + b(D - 62, y, d, 9.6, { ancre: 'end' }) + b(D, y, v, 9.6, { ancre: 'end' });
    let s = titreMois(G, y0, 27);
    SEANCES.forEach(([, r, min, v], i) => { s += ligne(y0 + 60 + i * 14.4, ROUTINES[r].toUpperCase(), duree(min), `${nombre(v)} kg`); });
    s += ligne(y0 + 60 + SEANCES.length * 14.4 + 8, 'TOTAL', duree(MINUTES), `${nombre(VOLUME)} kg`);
    page.push(s);
  }
  // 3 · la régularité : le calendrier du mois, les jours d'entraînement en vert
  {
    const y0 = MIL - 196, e = 5.4, c = (W - 6 * e) / 7;
    let s = b(CX, y0, 'Entraînements en septembre', 14.5, { poids: 700, ancre: 'middle' });
    s += haltere(CX - 34, y0 + 46, 1.25) + b(CX + 6, y0 + 64, String(SEANCES.length), 54, { extra: 'letter-spacing="-1.6"' });
    s += ecartLigne(CX, y0 + 92, ECART_SEANCES, 'par rapport à août');
    tr('L|M|M|J|V|S|D').split('|').forEach((l, i) => { s += brut(G + i * (c + e) + c / 2, y0 + 128, l, 9.4, { couleur: ENCRE2, poids: 700, ancre: 'middle' }); });
    const decalage = (new Date(AN, MOIS - 1, 1).getDay() + 6) % 7, nb = new Date(AN, MOIS, 0).getDate();
    for (let j = 1; j <= nb; j++) {
      const n = decalage + j - 1, fait = JOURS[MOIS].includes(j);
      const x = G + (n % 7) * (c + e), y = y0 + 138 + Math.floor(n / 7) * (c + e);
      s += `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${c.toFixed(1)}" height="${c.toFixed(1)}" rx="${(c * 0.26).toFixed(1)}" fill="${fait ? HAUSSE : BLANC}"${fait ? '' : ' fill-opacity="0.13"'}/>`;
      s += brut((x + c / 2).toFixed(1), (y + c / 2 + 4.2).toFixed(1), String(j), 11.6, { couleur: fait ? '#000000' : ENCRE2, poids: 700, ancre: 'middle' });
    }
    page.push(s);
  }
  // 4 · le volume
  {
    const y0 = MIL - 208, max = Math.max(...VOLUMES), LB = W - 60;
    let s = b(CX, y0, 'Poids soulevé en septembre', 14.5, { poids: 700, ancre: 'middle' });
    s += grandVolume(y0 + 62, 54) + ecartLigne(CX, y0 + 90, ECART_VOLUME, 'par rapport à août');
    VOLUMES.forEach((v, i) => {
      const m = (MOIS + i) % 12, annee = i < 12 - MOIS ? AN - 1 : AN, y = y0 + 108 + i * 25.4, courant = i === 11;
      const l = LB * Math.max(v / max, 0.015);
      s += b(G, y + 14, annee === AN ? COURTS[m] : `${COURTS[m]} ${annee % 100}`, 10.8, { poids: courant ? 700 : 600 });
      s += `<rect x="${G + 60}" y="${y}" width="${l.toFixed(1)}" height="20" rx="2.8" fill="${BLANC}"${courant ? '' : ' fill-opacity="0.32"'}/>`;
      if (v === max) s += t(G + 60 + l - 6, y + 14, `${nombre(v)} kg`, { taille: 9.2, couleur: '#000000', poids: 700, ancre: 'end' });
    });
    page.push(s);
  }
  // 5 · l'équivalent : le vrai objet en 3D de l'appli s'il est dans
  // docs/exercices/objets/, sinon un pictogramme dessiné ici.
  const OBJET_3D = `objets/${{ 'éléphant': 'elephant_3d' }[EQ.o.nom || EQ.o[0]] || 'absent'}.png`;
  const elephant = (c, ombre) => `<ellipse cx="14" cy="2" rx="60" ry="42" fill="${c}"/>
    <rect x="42" y="26" width="22" height="46" rx="10" fill="${ombre}"/><rect x="-30" y="26" width="22" height="46" rx="10" fill="${ombre}"/>
    <rect x="22" y="30" width="22" height="46" rx="10" fill="${c}"/><rect x="-12" y="30" width="22" height="46" rx="10" fill="${c}"/>
    <path d="M73 -12 q14 12 7 30" fill="none" stroke="${c}" stroke-width="5" stroke-linecap="round"/>
    <circle cx="-48" cy="-14" r="33" fill="${c}"/>
    <path d="M-72 -6 C-92 4 -88 44 -74 58" fill="none" stroke="${c}" stroke-width="15" stroke-linecap="round"/>
    <ellipse cx="-30" cy="-16" rx="17" ry="25" fill="${ombre}"/>
    <path d="M-62 8 q-6 14 -18 12" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>
    <circle cx="-60" cy="-22" r="3.4" fill="#1B1430"/>`;
  {
    const y0 = MIL - 172, oy = y0 + 178;
    let s = b(CX, y0, 'Poids soulevé en septembre', 12, { poids: 700, ancre: 'middle' });
    s += grandVolume(y0 + 50, 41);
    s += `<ellipse cx="${CX}" cy="${oy}" rx="${W * 0.5}" ry="92" fill="url(#resumeHalo)"/>
      ${!require('fs').existsSync(require('path').join(__dirname, '..', '..', 'exercices', OBJET_3D)) ? `<g transform="translate(${CX - 96},${oy - 62}) rotate(-16) scale(0.36)" opacity="0.45">${elephant(EQ.o.accent, '#A892EA')}</g>
      <g transform="translate(${CX + 92},${oy + 66}) rotate(14) scale(-0.28,0.28)" opacity="0.4">${elephant(EQ.o.accent, '#A892EA')}</g>
      <g transform="translate(${CX + 6},${oy - 4}) rotate(-6) scale(0.94)">${elephant(EQ.o.accent, '#A892EA')}</g>`
    : `<g transform="translate(${CX - 96},${oy - 62}) rotate(-16)" opacity="0.5">${O.image(OBJET_3D, -27, -27, 54, 54)}</g>
      <g transform="translate(${CX + 92},${oy + 66}) rotate(14)" opacity="0.45">${O.image(OBJET_3D, -22, -22, 44, 44)}</g>
      <g transform="translate(${CX + 4},${oy - 2}) rotate(-6)">${O.image(OBJET_3D, -84, -84, 168, 168)}</g>`}
      <g transform="translate(${D - 34},${oy - 78}) rotate(8)"><rect x="-38" y="-17" width="76" height="34" rx="17" fill="#FFFFFF"/>${t(0, 6.5, EQ.etiquette, { taille: 18, couleur: '#000000', poids: 900, ancre: 'middle' })}</g>`;
    s += b(CX, y0 + 300, 'C’est comme soulever', 17, { ancre: 'middle' });
    s += `<text x="${CX}" y="${y0 + 322}" text-anchor="middle" font-family="${SANS}" font-size="17" font-weight="800" fill="${EQ.o.accent}">${O.esc(tr(EQ.fort))}<tspan fill="${BLANC}">${O.EN ? '!' : ' !'}</tspan></text>`;
    page.push(s);
  }
  // 6 · la série
  {
    const y0 = MIL - 92;
    page.push(`<g transform="translate(${CX - 62},${y0 + 40})" fill="none" stroke="${BLANC}" stroke-width="5" stroke-linejoin="round"><path d="M0 -44 C10 -22 30 -12 30 12 A30 30 0 0 1 -30 12 C-30 0 -24 -10 -15 -18 C-14 -8 -9 -2 -3 0 C-9 -16 -6 -30 0 -44 Z"/></g>
      ${b(CX - 20, y0 + 74, String(SERIE), 94, { extra: 'letter-spacing="-2.8"' })}
      ${tr('Série|hebdomadaire !').split('|').map((l, i) => brut(CX, y0 + 124 + i * 26, l, 22, { ancre: 'middle' })).join('')}`);
  }
  // 7 · les muscles
  // Un axe, une figurine : le fond (buste ou jambes, de face ou de dos) et le calque du muscle.
  const FIGURINE = [['face_buste_base', 'face_buste_pectoraux'], ['face_buste_base', 'face_buste_deltoidesLateraux'], ['dos_buste_base', 'dos_buste_triceps'],
    ['dos_buste_base', 'dos_buste_grandDorsal'], ['face_buste_base', 'face_buste_biceps'], ['face_buste_base', 'face_buste_abdominaux'],
    ['face_jambes_base', 'face_jambes_quadriceps'], ['dos_jambes_base', 'dos_jambes_ischios'], ['dos_buste_base', 'dos_buste_trapezes']];
  {
    const cy = MIL - 22, r = 84, n = TOILE.length, max = Math.max(...TOILE.flatMap((a) => [a[1], a[2]]));
    const pt = (i, k) => { const a = -Math.PI / 2 + i * 2 * Math.PI / n; return `${(CX + Math.cos(a) * r * k).toFixed(1)} ${(cy + Math.sin(a) * r * k).toFixed(1)}`; };
    const poly = (f) => `M${TOILE.map((a, i) => pt(i, f(a))).join(' L')} Z`;
    let s = [0.25, 0.5, 0.75, 1].map((f) => `<path d="${poly(() => f)}" fill="none" stroke="${BLANC}" stroke-opacity="0.3"/>`).join('');
    s += TOILE.map((a, i) => `<path d="M${CX} ${cy} L${pt(i, 1)}" stroke="${BLANC}" stroke-opacity="0.18"/>`).join('');
    s += `<path d="${poly((a) => a[2] / max)}" fill="#A0A0AA" fill-opacity="0.22" stroke="#A0A0AA" stroke-width="1.6" stroke-linejoin="round"/>
      <path d="${poly((a) => a[1] / max)}" fill="#4D8DFF" fill-opacity="0.3" stroke="#4D8DFF" stroke-width="2" stroke-linejoin="round"/>`;
    TOILE.forEach((a, i) => {
      const ang = -Math.PI / 2 + i * 2 * Math.PI / n, x = CX + Math.cos(ang) * (r + 22), y = cy + Math.sin(ang) * (r + 18);
      // Comme dans l'appli : le buste ou les jambes du personnage, le muscle en rouge.
      const [base, calque] = FIGURINE[i] || [];
      const fx = CX + Math.cos(ang) * (r + 30), fy = cy + Math.sin(ang) * (r + 30);
      const corpsFig = base && O.image(`corps/${base}.webp`, fx - 20, fy - 20, 40, 40);
      const muscleFig = corpsFig && O.image(`corps/${calque}.webp`, fx - 20, fy - 20, 40, 40, 'filter="url(#resumeRouge)"');
      s += muscleFig ? corpsFig + muscleFig : b(x, y + 3.5, a[0], 9.6, { poids: 700, ancre: 'middle' });
    });
    const ly = cy + r + 62;
    s += `<circle cx="${CX - 92}" cy="${ly - 4.5}" r="4" fill="#4D8DFF"/>${b(CX - 82, ly, 'Septembre', 13, { poids: 700 })}
      <circle cx="${CX + 26}" cy="${ly - 4.5}" r="4" fill="#A0A0AA"/>${b(CX + 36, ly, 'Août', 13, { poids: 700, couleur: ENCRE2 })}`;
    page.push(s);
  }
  // 8 · les records
  {
    const y0 = MIL - 130;
    let s = titreMois(G, y0, 27);
    s += O.ecussonPR(G + 20, y0 + 62, 22);
    s += b(G + 50, y0 + 71, `${RECORDS.length} nouveaux records`, 19);
    s += `<rect x="${G}" y="${y0 + 100}" width="100" height="2" fill="${BLANC}"/>`;
    s += b(G, y0 + 130, 'Exercice', 12.6) + b(D, y0 + 130, 'Meilleure série', 12.6, { ancre: 'end' });
    RECORDS.forEach(([nom, serie], i) => { s += b(G, y0 + 158 + i * 28, nom, 11) + b(D, y0 + 158 + i * 28, serie, 11, { poids: 600, ancre: 'end' }); });
    page.push(s);
  }
  // 9 · les favoris
  {
    const y0 = MIL - 196;
    let s = `<g transform="translate(${CX},${y0 + 34}) skewY(-8)"><rect x="${-SL / 2 - 10}" y="-26" width="${SL + 20}" height="52" fill="#E9FBF8"/>${t(0, 4.5, 'TOP EXERCICES DE SEPTEMBRE', { taille: 12.6, couleur: '#0D2A2A', poids: 800, ancre: 'middle', extra: 'letter-spacing="0.3"' })}</g>`;
    FAVORIS.forEach(([nom, n], i) => {
      const y = y0 + 100 + i * 57;
      s += b(G + 7, y + 31, String(i + 1), 18, { ancre: 'middle' });
      const POSES = ['bench-press', 'squat', 'lat-pulldown', 'deadlift', 'barbell-row'];
      const posee = O.photo(POSES[i], G + 26, y, 48, { rayon: 9, fond: '#E9FBF8' });
      s += posee || `<rect x="${G + 26}" y="${y}" width="48" height="48" rx="9" fill="#E9FBF8"/><g transform="translate(${G + 50},${y + 24}) scale(0.72)" fill="none" stroke="#0D2A2A" stroke-width="2.8" stroke-linecap="round"><path d="M-12 0 H12 M-15 -10 V10 M-21 -6 V6 M15 -10 V10 M21 -6 V6"/></g>`;
      s += b(G + 86, y + 22, nom, 12.4, { poids: 700 }) + b(G + 86, y + 38, `${n} séries`, 10, { poids: 600, couleur: ENCRE2 });
    });
    page.push(s);
  }
  // 10 · le résumé
  {
    const y0 = MIL - 186;
    const bloc = (x, y, titre, valeur, unite, deja) => `${deja ? brut(x, y, titre, 11.8) : b(x, y, titre, 11.8)}<text x="${x}" y="${y + 33}" font-family="${SANS}" font-size="30.6" font-weight="800" fill="${BLANC}" letter-spacing="-0.6">${valeur}${unite ? `<tspan font-size="14.4" letter-spacing="0"> ${O.esc(deja ? unite : tr(unite))}</tspan>` : ''}</text>`;
    let s = haltere(G + 20, y0 + 6, 1.1) + titreMois(G + 54, y0, 22.5);
    s += bloc(G, y0 + 62, 'Entraînements', SEANCES.length) + ecartLigne(G, y0 + 112, ECART_SEANCES, 'du mois dernier', 'start');
    s += bloc(G, y0 + 142, 'Volume', nombre(VOLUME), 'kg') + ecartLigne(G, y0 + 192, ECART_VOLUME, 'du mois dernier', 'start');
    s += bloc(G, y0 + 222, 'Temps', Math.floor(MINUTES / 60), 'heures');
    s += bloc(G, y0 + 290, 'Records', RECORDS.length) + bloc(G + W / 2, y0 + 290, tr('Série|sem.').split('|')[0], SERIE, tr('Série|sem.').split('|')[1], true);
    page.push(s);
  }
  let ecran = '';
  page.forEach((s, k) => { ecran += pendant(k, `<rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" fill="url(#resumeFond${k})"/>${s}`); });
  // La barre de dix segments, la croix, la marque et « Partager ».
  const sl = (W - 9 * 2.8) / 10;
  for (let i = 0; i < 10; i++) {
    const x = (G + i * (sl + 2.8)).toFixed(1);
    ecran += `<rect x="${x}" y="${SY + 24}" width="${sl.toFixed(1)}" height="2.8" rx="1.4" fill="${BLANC}" fill-opacity="0.28"/>`;
    ecran += `<rect x="${x}" y="${SY + 24}" width="${sl.toFixed(1)}" height="2.8" rx="1.4" fill="${BLANC}" opacity="${i === 0 ? 1 : 0}">${i === 0 ? '' : paliers('opacity', C, [[0, 0], [p(i), 1]])}</rect>`;
  }
  ecran += `<path d="M${G + 1} ${SY + 44} l11 11 M${G + 12} ${SY + 44} l-11 11" stroke="${BLANC}" stroke-width="2.4" stroke-linecap="round"/>`;
  ecran += b(CX, SY + SH - 62, 'AESTHETICS', 15.5, { poids: 900, ancre: 'middle', extra: 'letter-spacing="0.3"' });
  ecran += `<g transform="translate(${CX - 48},${SY + SH - 39}) scale(0.8)"><path d="M12.5 4.5 L18.5 10 L12.5 15.5 V12.2 C8.5 12.2 5.7 13.2 4 16.2 C4 11.4 6.5 7.9 12.5 7.7 Z" fill="${BLANC}" stroke="${BLANC}" stroke-width="1.7" stroke-linejoin="round"/></g>`;
  ecran += b(CX - 24, SY + SH - 26, 'Partager', 13.5, { poids: 600 });
  for (let k = 1; k <= 9; k++) ecran += toucher(SX + SL * 0.78, SY + SH * 0.6, C, p(k));
  corps += `<g clip-path="url(#ecranResume)">${ecran}</g>`;
  PAGES.forEach(([nom], k) => { corps += pendant(k, `<text x="${PX + PL / 2}" y="${PY + PH + 28}" font-family="${MONO}" font-size="12" font-weight="700" fill="${TITRE}" text-anchor="middle">${k + 1} / 10 · ${O.esc(tr(nom))}</text>`); });

  // --------------------------------------------------- la page 5, à droite
  const RX = 706, RL = 514, RY = 80, RH = 600;
  corps += `<rect x="${RX}" y="${RY}" width="${RL}" height="${RH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>
    <rect x="${RX}" y="${RY}" width="${RL}" height="${RH}" rx="16" fill="none" stroke="${ACCENT}" stroke-width="1.5" opacity="0">${visible(C, p(4), p(5), 0.006)}</rect>`;
  corps += titreBloc(RX + 20, RY + 28, 'LA PAGE 5 : 25 OBJETS, DU PLUS LÉGER AU PLUS LOURD');
  corps += `<text x="${RX + 20}" y="${RY + 52}" font-family="${SANS}" font-size="13" fill="${TEXTE}">${O.esc(tr('Septembre 2026 :'))} <tspan fill="${TITRE}" font-weight="700">${nombre(VOLUME)} kg</tspan> ${O.esc(tr('soulevés. Quel objet, et combien ?'))}</text>`;
  const masse = (kg) => (kg < 1000 ? `${String(kg).replace('.', ',')} kg` : `${String(kg / 1000).replace('.', ',')} t`);
  const CL = (RL - 40 - 14) / 2, TY = RY + 66, TPAS = 20.5;
  OBJETS.forEach((o, i) => {
    const col = i < 13 ? 0 : 1, x = RX + 20 + col * (CL + 14), y = TY + (i < 13 ? i : i - 13) * TPAS;
    const rang = EQ.lisibles.findIndex((m) => m.o === o), lisible = rang >= 0, m = lisible ? EQ.lisibles[rang] : null;
    const pourcent = o === LIBERTE && EQ.enPourcent, choisi = lisible && rang === EQ.i;
    if (lisible || pourcent) corps += g(R.lisibles, 1, `<rect x="${x}" y="${y}" width="${CL}" height="${TPAS - 2.5}" rx="6" fill="${BLANC}" fill-opacity="0.06"/>`);
    if (choisi) corps += g(R.choix, 1, `<rect x="${x}" y="${y}" width="${CL}" height="${TPAS - 2.5}" rx="6" fill="${ACCENT}" fill-opacity="0.16" stroke="${ACCENT}" stroke-width="1.5"/>`);
    corps += t(x + 26, y + 13, o.nom, { taille: 11, couleur: TITRE, poids: 600 });
    corps += t(x + CL - 52, y + 13, masse(o.kg), { taille: 10.5, couleur: DISCRET, police: MONO, ancre: 'end' });
    if (lisible) {
      corps += g(R.lisibles, 1, t(x + CL - 6, y + 13, `× ${chiffre(m)}`, { taille: 11, couleur: m.decimale ? TEXTE : TITRE, police: MONO, poids: 700, ancre: 'end' }));
      corps += g(R.tri, 1, `<circle cx="${x + 13}" cy="${y + 9}" r="7.5" fill="${choisi ? ACCENT : FOND}" stroke="${choisi ? ACCENT : FIL}"/>${t(x + 13, y + 12.5, String(rang + 1), { taille: 9, couleur: choisi ? BLANC : TEXTE, police: MONO, poids: 700, ancre: 'middle' })}`);
    } else if (pourcent) {
      corps += g(R.lisibles, 1, t(x + CL - 6, y + 13, `${EQ.part} %`, { taille: 11, couleur: TEXTE, police: MONO, poids: 700, ancre: 'end' }));
      corps += g(R.tri, 1, `<circle cx="${x + 13}" cy="${y + 9}" r="7.5" fill="${FOND}" stroke="${FIL}"/>${t(x + 13, y + 12.5, String(EQ.nb), { taille: 9, couleur: TEXTE, police: MONO, poids: 700, ancre: 'middle' })}`);
    } else if (o.sorte === 'absurde') {
      corps += t(x + CL - 6, y + 13, '1 / 6', { taille: 10, couleur: DISCRET, police: MONO, ancre: 'end' });
    }
  });
  // La règle, en quatre temps, avec les chiffres de l'exemple.
  const borne = (kg) => (kg < 1000 ? `${nombre(kg)} kg` : `${Math.round(kg / 1000)} t`);
  const q = Math.floor(GRAINE / 6), reste = GRAINE % 6;
  const regles = [
    [R.lisibles, 'Lisible', ['Un objet est gardé si volume ÷ masse va de 0,93 à 99,5 :', `ici de ${borne(VOLUME / 99.5)} à ${borne(VOLUME / 0.93)}, soit ${EQ.lisibles.length} objets. La statue de la Liberté`, 's’ajoute en pourcentage, de 10 à 93 %.']],
    [R.lisibles, 'Arrondi', ['À l’entier s’il s’écarte de 8 % au plus, ou dès × 10 ; sinon à une décimale.']],
    [R.tri, 'Tri', ['Les entiers d’abord, du plus juste au moins juste par tranches de 2 %,', 'puis le plus petit multiple. Le pourcentage ferme la liste.']],
    [R.choix, 'Graine', [`${AN} × 12 + ${MOIS} = ${nombre(GRAINE)} = 6 × ${nombre(q)} + ${reste}. Rang : ${nombre(q)} × 5 + ${reste} = ${nombre(EQ.rang)}.`, `Reste ${EQ.i} sur ${EQ.nb} choix : le n° ${EQ.i + 1}. Le même objet à chaque ouverture.`]],
  ];
  let ry = TY + 13 * TPAS + 22;
  corps += `<line x1="${RX + 16}" y1="${ry - 16}" x2="${RX + RL - 16}" y2="${ry - 16}" stroke="${BORD}"/>`;
  regles.forEach(([quand, nom, lignes], i) => {
    corps += `<circle cx="${RX + 30}" cy="${ry - 4}" r="10" fill="${ACCENT}" fill-opacity="0.14" stroke="${ACCENT}" stroke-opacity="0.55"/>${t(RX + 30, ry, String(i + 1), { taille: 11, couleur: ACCENT, police: MONO, poids: 700, ancre: 'middle' })}`;
    corps += t(RX + 50, ry, nom, { taille: 12.5, couleur: TITRE, poids: 700 });
    lignes.forEach((l, j) => { corps += t(RX + 124, ry + j * 16, l, { taille: 11.5, couleur: TEXTE }); });
    corps += `<rect x="${RX + 12}" y="${ry - 18}" width="${RL - 24}" height="${lignes.length * 16 + 12}" rx="9" fill="none" stroke="${ACCENT}" stroke-opacity="0.7" opacity="0">${visible(C, quand, quand + 0.04, 0.006)}</rect>`;
    ry += lignes.length * 16 + 14;
  });
  corps += g(R.choix, 1, `<rect x="${RX + 16}" y="${ry - 12}" width="${RL - 32}" height="34" rx="10" fill="${ACCENT}" fill-opacity="0.1" stroke="${ACCENT}" stroke-opacity="0.6"/>
    ${t(RX + RL / 2, ry + 10, `${nombre(VOLUME)} kg ÷ ${nombre(EQ.o.kg)} kg = ${String(Math.round(VOLUME / EQ.o.kg * 100) / 100).replace('.', ',')} → ${EQ.etiquette} ${EQ.o.pluriel}`, { taille: 13, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' })}`);
  ry += 48;
  corps += t(RX + 20, ry, `Une graine sur six (reste 5) sort un burger ou une baguette de 250 g : × ${nombre(EQ.minuscule)}.`, { taille: 11.5, couleur: DISCRET });

  // --------------------------------------------------- le résumé annuel
  const AY = RY + RH + 14;
  corps += `<rect x="${RX}" y="${AY}" width="${RL}" height="118" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(RX + 20, AY + 28, 'ET LE RÉSUMÉ ANNUEL');
  corps += t(RX + 20, AY + 52, 'Les mêmes dix pages pour l’année, depuis la vue Année de Progrès :', { taille: 12.5, couleur: TITRE });
  corps += t(RX + 20, AY + 71, 'une ligne par mois, douze mois de cases, la plus longue série de l’année.', { taille: 12.5 });
  corps += t(RX + 20, AY + 98, `La graine devient l’année. ${AN}, jusqu’ici : ${nombre(VOLUME_AN)} kg, soit ${EQ_AN.etiquette} ${EQ_AN.o.pluriel}.`, { taille: 12.5 });

  // Le fondu avant la reprise.
  corps += `<rect x="1" y="66" width="1278" height="${860 - 67}" rx="16" fill="${FOND}" opacity="1">${fondu('opacity', C, [[0, 1], [0.012, 0], [FIN, 0], [0.994, 1], [1, 1]])}</rect>`;

  svg('resume.svg', 1280, 860, corps,
    `Le résumé mensuel, façon story, sur un téléphone animé. Dix pages se suivent, une touche sur l’écran pour avancer, son tiers gauche pour revenir, sans minuterie : l’ouverture ; les séances de septembre 2026, une ligne chacune avec sa durée et son volume, puis le total, ${duree(MINUTES)} et ${nombre(VOLUME)} kg ; la régularité, ${SEANCES.length} entraînements, ${ECART_SEANCES} % de plus qu’en août, et le calendrier du mois, les jours d’entraînement en vert ; le volume, ${nombre(VOLUME)} kg, ${ECART_VOLUME} % de plus qu’en août, et douze mois en barres ; le volume en objets ; la série, ${SERIE} semaines d’affilée ; les muscles, une toile à neuf axes devant celle du mois d’avant ; les records, ${RECORDS.length} nouveaux ; les cinq exercices favoris ; le résumé à partager. La cinquième page convertit le volume en un objet parmi 25, du burger de 250 g à la statue de la Liberté de 225 tonnes. Un objet est gardé si le volume divisé par sa masse va de 0,93 à 99,5 : ici ${EQ.lisibles.length} objets, de ${borne(VOLUME / 99.5)} à ${borne(VOLUME / 0.93)}. Le multiple est arrondi à l’entier s’il s’écarte de 8 % au plus ou dès 10, sinon à une décimale ; les entiers passent d’abord, du plus juste au moins juste, puis le plus petit multiple ; la statue de la Liberté, en pourcentage, ferme la liste. La graine du mois, ${AN} × 12 + ${MOIS} = ${nombre(GRAINE)}, désigne le choix n° ${EQ.i + 1} sur ${EQ.nb} : ${EQ.etiquette} ${EQ.o.pluriel}, « C’est comme soulever ${EQ.fort} ! ». Une graine sur six sort un burger ou une baguette. Le résumé annuel suit la même mécanique, avec l’année pour graine : pour ${AN} jusqu’ici, ${nombre(VOLUME_AN)} kg, soit ${EQ_AN.etiquette} ${EQ_AN.o.pluriel}.`);
};
