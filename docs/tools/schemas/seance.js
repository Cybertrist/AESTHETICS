// La séance, sur un téléphone animé.
//
// À gauche, l'écran de séance : on coche la première série du développé
// couché, elle passe au vert et le minuteur de repos part seul ; un toucher
// sur la pilule l'ouvre en grand, « +10 » ajoute dix secondes ; le repos se
// termine, la deuxième série passe à 82,5 kg et bat deux records ; puis le
// chevron réduit la séance en une barre posée au-dessus des onglets.
// À droite, les six étapes, qui s'allument tour à tour.
//
// Les chiffres : la dernière fois, 80 kg × 8, 80 kg × 8, 80 kg × 7. Le 1RM
// estimé de 80 × 8 vaut (101,33 + 99,31) / 2 = 100,32 ; celui de 82,5 × 8,
// (104,50 + 102,41) / 2 = 103,46.
module.exports = (O) => {
  const {
    svg, t, visible, fondu, paliers, toucher, tr, APP,
    MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, BLEU, OR, ROUGE,
  } = O;

  const C = 30;
  const OR_VIF = '#FFBE0B', OR_PALE = '#FDE68A', POIGNEE = '#48454E', ENCRE = '#A2A2A8';
  const PX = 60, PY = 96, PL = 304, PH = 612;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;

  // Les instants du récit, en fraction du cycle.
  const T = {
    coche1: 0.07, pilule: 0.15, plein: 0.165, plus: 0.25, ferme: 0.31, retour: 0.325, saut: 0.37, finRepos: 0.47,
    kg: 0.52, tape: 0.54, coche2: 0.59, ligne1: 0.62, ligne2: 0.69, finBandeau: 0.76,
    reduire: 0.82, mini: 0.835, fin: 0.985,
  };

  // ------------------------------------------------------------ le temps
  // Le repos de 90 s lancé par la première série, allongé de 10 s, et dont
  // on saute le milieu pour n'en montrer que les trois dernières secondes.
  const repos1 = (f) => (f < T.saut ? 90 - C * (f - T.coche1) + (f >= T.plus ? 10 : 0) : 3 - C * (f - T.saut));
  const repos2 = (f) => 90 - C * (f - T.coche2);
  // Le chrono de la séance : la série est cochée à 0:04:06, le repos de
  // 100 s finit donc à 0:05:46.
  const seance = (f) => (f < T.saut ? 246 + C * (f - T.coche1) : 343 + C * (f - T.saut));
  const deux = (n) => String(n).padStart(2, '0');
  const court = (s) => { const n = Math.ceil(s); return `${Math.floor(n / 60)}:${deux(n % 60)}`; };
  const minSec = (s) => { const n = Math.ceil(s); return `${deux(Math.floor(n / 60))}:${deux(n % 60)}`; };
  const chrono = (s) => { const n = Math.floor(s); return `${Math.floor(n / 3600)}:${deux(Math.floor(n / 60) % 60)}:${deux(n % 60)}`; };
  /// Les valeurs successives d'un texte entre deux instants : [instant, texte].
  const tranches = (f, de, a) => {
    const out = [];
    let avant = null;
    for (let i = Math.round(de * 1000); i < Math.round(a * 1000); i++) {
      const s = f(i / 1000 + 0.0005);
      if (s !== avant) { out.push([i / 1000, s]); avant = s; }
    }
    return out;
  };
  /// Un texte qui change par paliers.
  const suite = (x, y, segs, fin, opts) => segs.map(([de, s], i) => {
    const a = i + 1 < segs.length ? segs[i + 1][0] : fin;
    return `<g opacity="0">${paliers('opacity', C, de > 0 ? [[0, 0], [de, 1], [a, 0]] : [[0, 1], [a, 0]])}${t(x, y, s, opts)}</g>`;
  }).join('');
  const g = (de, a, contenu, douceur = 0.004) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;

  let corps = '';
  corps += t(60, 52, 'LA SÉANCE', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(210, 52, 'Un exercice, trois séries : cocher, souffler, battre un record, réduire.', { taille: 14 });

  // ---------------------------------------------------------------- outils
  /// L'écusson « PR » : un hexagone doré.
  const ecusson = (cx, cy, r) => {
    const pts = [0, 1, 2, 3, 4, 5].map((k) => `${(cx + r * Math.sin(k * Math.PI / 3)).toFixed(1)},${(cy - r * Math.cos(k * Math.PI / 3)).toFixed(1)}`).join(' ');
    return `<polygon points="${pts}" fill="${OR_VIF}" fill-opacity="0.2" stroke="${OR_VIF}" stroke-width="1.4" stroke-linejoin="round"/>
      ${t(cx, cy + r * 0.3, 'PR', { taille: r * 0.82, couleur: OR_VIF, poids: 800, ancre: 'middle' })}`;
  };
  /// La vignette d'un exercice : une barre et ses disques, ou deux haltères.
  const vignette = (x, y, s, halteres = false, nom = null) => {
    // La vraie pose de l'exercice, si elle est dans docs/exercices/vignettes.
    const vraie = nom && O.photo(nom, x, y, s, { rayon: s * 0.23 });
    if (vraie) return vraie;
    const m = y + s / 2;
    const barre = (bx, l) => `<path d="M${bx} ${m} h${l}" stroke="${APP.second}" stroke-width="2" stroke-linecap="round"/>`;
    const disque = (dx, h) => `<rect x="${dx}" y="${m - h / 2}" width="4" height="${h}" rx="1.5" fill="${APP.texte}"/>`;
    const dessin = halteres
      ? [0.14, 0.56].map((k) => `${barre(x + s * k + 3, s * 0.3 - 6)}${disque(x + s * k, 14)}${disque(x + s * (k + 0.3) - 4, 14)}`).join('')
      : `${barre(x + 6, s - 12)}${disque(x + 10, 22)}${disque(x + 15, 15)}${disque(x + s - 14, 22)}${disque(x + s - 19, 15)}`;
    return `<rect x="${x}" y="${y}" width="${s}" height="${s}" rx="${s * 0.23}" fill="${APP.carte2}"/>${dessin}`;
  };
  const sablier = (x, y, c) => `<circle cx="${x}" cy="${y}" r="5.5" fill="none" stroke="${c}" stroke-width="1.6"/><path d="M${x} ${y - 3} V${y} L${x + 2.2} ${y + 1.6} M${x - 2} ${y - 8} h4" fill="none" stroke="${c}" stroke-width="1.6" stroke-linecap="round"/>`;
  const points = (x, y) => [0, 1, 2].map((k) => `<circle cx="${x}" cy="${y - 5 + k * 5}" r="1.5" fill="${APP.second}"/>`).join('');
  const bouton = (x, y, l, h, texte, fond, encre, taille = 12) => `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="${h / 2}" fill="${fond}"/>
    ${t(x + l / 2, y + h / 2 + taille * 0.35, texte, { taille, couleur: encre, poids: 700, ancre: 'middle' })}`;

  // ------------------------------------------------------------- téléphone
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="ecranSeance"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  let ecran = '';

  // 1. L'écran de séance.
  let s = '';
  // La barre du haut : réduire, la pilule du minuteur, « Terminer ».
  const PILX = SX + 54, PILY = SY + 24, PILL = 82, PILH = 32;
  const part = [
    [0, 0], [T.coche1, 0], [T.coche1 + 0.002, 1], [T.plus, repos1(T.plus - 0.0001) / 90], [T.plus + 0.001, repos1(T.plus + 0.001) / 100],
    [T.saut, 0.91], [T.saut + 0.001, 0.03], [T.finRepos, 0], [T.coche2, 0], [T.coche2 + 0.002, 1], [T.mini, repos2(T.mini) / 90], [1, repos2(T.mini) / 90],
  ];
  const textePilule = [[0, 'Repos'], ...tranches((f) => court(repos1(f)), T.coche1, T.finRepos), [T.finRepos, 'Repos'], ...tranches((f) => court(repos2(f)), T.coche2, T.mini + 0.02)];
  s += `<circle cx="${SX + 30}" cy="${SY + 40}" r="16" fill="${APP.carte2}"/>
    <path d="M${SX + 24} ${SY + 38} l6 6 l6 -6" fill="none" stroke="${APP.texte}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    <clipPath id="pilule"><rect x="${PILX}" y="${PILY}" width="${PILL}" height="${PILH}" rx="${PILH / 2}"/></clipPath>
    <g clip-path="url(#pilule)"><rect x="${PILX}" y="${PILY}" width="${PILL}" height="${PILH}" fill="${APP.carte3}"/>
      <rect x="${PILX}" y="${PILY}" width="0" height="${PILH}" fill="${APP.minuteur}">${fondu('width', C, part.map(([k, v]) => [k, (v * PILL).toFixed(1)]))}</rect></g>
    ${sablier(PILX + 17, SY + 41, APP.texte)}
    ${suite(PILX + 30, SY + 44.5, textePilule, 0.999, { taille: 12.5, couleur: APP.texte, poids: 700 })}
    ${bouton(SX + SL - 98, SY + 24, 84, 32, 'Terminer', '#FFFFFF', '#000000')}`;
  // L'encadré : durée, volume, séries, et les records dès le premier.
  const EX = SX + 14, EY = SY + 70, EL = SL - 28;
  const duree = (de, a) => tranches((f) => chrono(seance(f)), de, a);
  const chiffres = (n, de, a, valeurs) => {
    const cx = (i) => EX + EL * (i + 0.5) / n;
    return g(de, a, valeurs.map(([nom, v, c], i) => `${t(cx(i), EY + 20, nom, { taille: 10.5, couleur: APP.second, ancre: 'middle' })}
      ${typeof v === 'function' ? v(cx(i)) : t(cx(i), EY + 41, v, { taille: n > 3 ? 12.5 : 14.5, couleur: c || APP.texte, poids: 700, ancre: 'middle' })}`).join(''), 0.003);
  };
  const vDuree = (de, a, taille = 14.5) => (cx) => suite(cx, EY + 41, duree(de, a), a, { taille, couleur: APP.minuteur, poids: 700, ancre: 'middle' });
  s += `<rect x="${EX}" y="${EY}" width="${EL}" height="54" rx="13" fill="none" stroke="${APP.carte3}"/>`;
  s += chiffres(3, 0.004, T.coche1, [['Durée', vDuree(0, T.coche1 + 0.01)], ['Volume', '0 kg'], ['Séries', '0']]);
  s += chiffres(3, T.coche1, T.coche2, [['Durée', vDuree(T.coche1 - 0.01, T.coche2 + 0.01)], ['Volume', '640 kg'], ['Séries', '1']]);
  s += chiffres(4, T.coche2, T.mini, [['Durée', vDuree(T.coche2 - 0.01, T.mini + 0.02, 12.5)], ['Volume', '1 300 kg'], ['Séries', '2'],
    ['Records', (cx) => `${ecusson(cx - 9, EY + 36, 8)}${t(cx + 8, EY + 41, '2', { taille: 12.5, couleur: APP.texte, poids: 700, ancre: 'middle' })}`]]);
  // L'exercice ouvert.
  s += `${vignette(SX + 14, SY + 138, 44, false, 'bench-press')}
    ${t(SX + 70, SY + 165, 'Développé couché', { taille: 14, couleur: APP.texte, poids: 700 })}
    ${points(SX + SL - 22, SY + 160)}
    ${t(SX + 16, SY + 204, 'Ajouter une note…', { taille: 11.5, couleur: APP.discret })}
    ${sablier(SX + 22, SY + 228, APP.minuteur)}
    ${t(SX + 36, SY + 232, 'Minuteur de repos : 1:30', { taille: 12, couleur: APP.minuteur, poids: 500 })}
    <line x1="${SX + 14}" y1="${SY + 244}" x2="${SX + SL - 14}" y2="${SY + 244}" stroke="${APP.trait}"/>`;
  // Le tableau des séries.
  const COL = { serie: SX + 30, precedent: SX + 98, kg: SX + 166, reps: SX + 208, coche: SX + 251 };
  const TY = SY + 262, RY = SY + 272, RH = 40;
  s += [['Série', COL.serie], ['Précédent', COL.precedent], ['Kg', COL.kg], ['Reps', COL.reps]]
    .map(([n, x]) => t(x, TY, n, { taille: 10.5, couleur: APP.second, ancre: 'middle' })).join('');
  const valeur = (x, y, v, c) => t(x, y + 25, v, { taille: 14, couleur: c, poids: 700, ancre: 'middle' });
  const coche = (y, fond, trait = APP.texte) => `<rect x="${COL.coche - 17}" y="${y + 8}" width="34" height="24" rx="12" fill="${fond}"/>
    <path d="M${COL.coche - 5} ${y + 20} l3.5 3.5 l7 -7.5" fill="none" stroke="${trait}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>`;
  const repere = (y, n) => valeur(COL.serie, y, n, APP.minuteur);
  const precedent = (y, v) => t(COL.precedent, y + 24, v, { taille: 11, couleur: APP.second, ancre: 'middle' });
  const y1 = RY, y2 = RY + RH, y3 = RY + 2 * RH;
  // Série 1 : 80 kg × 8, cochée, verte.
  s += `<rect x="${SX}" y="${y1}" width="${SL}" height="${RH}" fill="${APP.serieFaite}" opacity="0">${visible(C, T.coche1, T.mini, 0.004)}</rect>
    ${repere(y1, '1')}${precedent(y1, '80 kg × 8')}
    ${g(0.004, T.coche1, valeur(COL.kg, y1, '80', ENCRE) + valeur(COL.reps, y1, '8', ENCRE) + coche(y1, POIGNEE))}
    ${g(T.coche1, T.mini, valeur(COL.kg, y1, '80', APP.texte) + valeur(COL.reps, y1, '8', APP.texte) + coche(y1, APP.foret))}`;
  // Série 2 : 82,5 kg × 8, un record : la ligne passe à l'or.
  s += `<rect x="${SX}" y="${y2}" width="${SL}" height="${RH}" fill="${APP.carte2}" fill-opacity="0.85"/>
    ${g(0.004, T.coche2, repere(y2, '2') + precedent(y2, '80 kg × 8') + valeur(COL.reps, y2, '8', ENCRE) + coche(y2, POIGNEE))}
    ${g(0.004, T.tape, valeur(COL.kg, y2, '80', ENCRE), 0.002)}
    ${g(T.tape, T.coche2, valeur(COL.kg, y2, '82,5', ENCRE), 0.002)}
    ${g(T.kg, T.coche2 - 0.01, `<rect x="${COL.kg + 17}" y="${y2 + 11}" width="1.6" height="18" fill="${APP.minuteur}"><animate attributeName="opacity" values="1;1;0;0" keyTimes="0;0.5;0.5;1" dur="0.9s" repeatCount="indefinite"/></rect>`, 0.002)}
    ${g(T.coche2, T.mini, `<rect x="${SX}" y="${y2}" width="${SL}" height="${RH}" fill="#1D180B"/>
      <path d="M${SX} ${y2 + 0.5} h${SL} M${SX} ${y2 + RH - 0.5} h${SL}" stroke="${OR_PALE}" stroke-opacity="0.24"/>
      <clipPath id="ligneOr"><rect x="${SX}" y="${y2}" width="${SL}" height="${RH}"/></clipPath>
      <g clip-path="url(#ligneOr)"><path d="M0 ${y2} h26 l-18 ${RH} h-26 Z" fill="${OR_PALE}" fill-opacity="0.13">
        <animateTransform attributeName="transform" type="translate" values="${SX - 40} 0;${SX + SL + 30} 0;${SX + SL + 30} 0" keyTimes="0;0.34;1" dur="3.4s" repeatCount="indefinite"/></path></g>
      ${ecusson(COL.serie, y2 + 20, 12)}
      <rect x="${COL.precedent - 32}" y="${y2 + 10}" width="64" height="20" rx="10" fill="${OR_PALE}" fill-opacity="0.14"/>
      ${t(COL.precedent, y2 + 24, 'RECORD', { taille: 9.5, couleur: OR_PALE, poids: 800, ancre: 'middle', extra: 'letter-spacing="1"' })}
      ${valeur(COL.kg, y2, '82,5', APP.texte)}${valeur(COL.reps, y2, '8', APP.texte)}${coche(y2, OR_PALE, '#000000')}`)}`;
  // Série 3 : pas encore faite.
  s += `${repere(y3, '3')}${precedent(y3, '80 kg × 7')}${valeur(COL.kg, y3, '80', ENCRE)}${valeur(COL.reps, y3, '7', ENCRE)}${coche(y3, POIGNEE)}`;
  s += bouton(SX + 14, SY + 402, SL - 28, 34, '+ Ajouter une série', APP.carte2, APP.texte);
  // L'exercice suivant, replié, et les deux boutons du bas.
  s += `${vignette(SX + 14, SY + 450, 40, true, 'cable-fly')}
    ${t(SX + 66, SY + 467, 'Écarté à la poulie', { taille: 13, couleur: APP.texte, poids: 700 })}
    ${t(SX + 66, SY + 484, '0/3 effectués', { taille: 11.5, couleur: APP.second })}
    ${points(SX + SL - 22, SY + 470)}
    ${bouton(SX + 14, SY + 502, SL - 28, 30, 'Ajouter des exercices', '#FFFFFF', '#000000', 11.5)}
    ${bouton(SX + 14, SY + 538, SL - 28, 30, 'Plus', APP.carte2, APP.texte, 11.5)}`;
  // Le bandeau du record : l'écusson seul, puis la pilule et ses deux lignes.
  const BY = EY + 3, BC = SX + SL / 2, BL = 252;
  s += g(T.coche2 + 0.003, T.ligne1, `<rect x="${BC - 24}" y="${BY}" width="48" height="48" rx="24" fill="#0E0E10" stroke="${OR_PALE}" stroke-opacity="0.35" stroke-width="1.2"/>${ecusson(BC, BY + 24, 15)}`, 0.006);
  s += g(T.ligne1, T.finBandeau, `<rect x="${BC - BL / 2}" y="${BY}" width="${BL}" height="48" rx="24" fill="#0E0E10" stroke="${OR_PALE}" stroke-opacity="0.35" stroke-width="1.2"/>
    ${vignette(BC - BL / 2 + 8, BY + 7, 34, false, 'bench-press')}
    ${t(BC - BL / 2 + 52, BY + 21, 'Développé couché', { taille: 11.5, couleur: APP.texte, poids: 700 })}
    ${g(T.ligne1, T.ligne2, t(BC - BL / 2 + 52, BY + 37, 'Charge maximale · 82,5 kg', { taille: 11, couleur: OR_PALE, poids: 600 }), 0.006)}
    ${g(T.ligne2, T.finBandeau, t(BC - BL / 2 + 52, BY + 37, '1RM estimé · 103,5 kg', { taille: 11, couleur: OR_PALE, poids: 600 }), 0.006)}
    ${ecusson(BC + BL / 2 - 24, BY + 24, 12)}`, 0.006);
  s += toucher(COL.coche, y1 + 20, C, T.coche1) + toucher(PILX + 40, SY + 40, C, T.pilule) + toucher(COL.kg, y2 + 20, C, T.kg)
    + toucher(COL.coche, y2 + 20, C, T.coche2) + toucher(SX + 30, SY + 40, C, T.reduire);
  ecran += g(0.004, T.mini, s);

  // 2. Le minuteur en plein écran : l'anneau bleu, −10, +10, « Arrêter ».
  const AX = SX + SL / 2, AY = SY + 226, AR = 92, TOUR = 2 * Math.PI * AR;
  const arc = [[T.plein, repos1(T.plein) / 90], [T.plus, repos1(T.plus - 0.0001) / 90], [T.plus + 0.001, repos1(T.plus + 0.001) / 100], [T.retour + 0.01, repos1(T.retour + 0.01) / 100]];
  const croix = (x, y) => `<path d="M${x - 6} ${y - 6} l12 12 M${x + 6} ${y - 6} l-12 12" stroke="${APP.texte}" stroke-width="2" stroke-linecap="round"/>`;
  const rond = (x, y, texte) => `<circle cx="${x}" cy="${y}" r="24" fill="${APP.carte2}"/>${t(x, y + 4.5, texte, { taille: 13, couleur: APP.texte, poids: 700, ancre: 'middle' })}`;
  ecran += g(T.plein, T.retour, `<rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" fill="${APP.fond}"/>
    ${croix(SX + 28, SY + 40)}<g transform="rotate(90 ${SX + SL - 26} ${SY + 40})">${points(SX + SL - 26, SY + 40)}</g>
    <circle cx="${AX}" cy="${AY}" r="${AR}" fill="none" stroke="${APP.carte2}" stroke-width="9"/>
    <circle cx="${AX}" cy="${AY}" r="${AR}" fill="none" stroke="${APP.minuteur}" stroke-width="9" stroke-linecap="round" transform="rotate(-90 ${AX} ${AY})" stroke-dasharray="${TOUR} ${TOUR}">
      <animate attributeName="stroke-dasharray" dur="${C}s" repeatCount="indefinite" keyTimes="0;${arc.map((a) => a[0]).join(';')};1" values="${[arc[0], ...arc, arc[arc.length - 1]].map((a) => `${(a[1] * TOUR).toFixed(1)} ${TOUR.toFixed(1)}`).join(';')}"/></circle>
    ${suite(AX, AY + 15, tranches((f) => minSec(repos1(f)), T.plein - 0.02, T.retour + 0.02), 0.999, { taille: 42, couleur: APP.texte, poids: 500, ancre: 'middle' })}
    ${rond(AX - 44, SY + 396, '−10')}${rond(AX + 44, SY + 396, '+10')}
    ${bouton(AX - 76, SY + 444, 152, 40, 'Arrêter', APP.carte2, ROUGE, 13)}
    ${t(AX - 44, SY + 536, 'Compte à rebours', { taille: 11.5, couleur: APP.texte, poids: 600, ancre: 'middle' })}
    <rect x="${AX - 92}" y="${SY + 546}" width="96" height="2.5" fill="${APP.texte}"/>
    ${t(AX + 66, SY + 536, 'Chronomètre', { taille: 11.5, couleur: APP.second, poids: 600, ancre: 'middle' })}
    ${toucher(AX + 44, SY + 396, C, T.plus)}${toucher(SX + 28, SY + 40, C, T.ferme)}`);

  // 3. La séance réduite : une barre au-dessus des onglets.
  const MX = SX + 10, MY = SY + 424, ML = SL - 20, MB = (ML - 20 - 8) / 2;
  const onglets = [
    ['Accueil', (x, y, c) => `<path d="M${x - 7} ${y} l7 -6 l7 6 M${x - 5} ${y - 1} v7 h10 v-7" fill="none" stroke="${c}" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/>`],
    ['Entraîner', (x, y, c) => `<path d="M${x - 5} ${y} h10 M${x - 7} ${y - 5} v10 M${x + 7} ${y - 5} v10 M${x - 10} ${y - 3} v6 M${x + 10} ${y - 3} v6" fill="none" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>`],
    ['Progrès', (x, y, c) => `<path d="M${x - 6} ${y + 6} v-5 M${x} ${y + 6} v-12 M${x + 6} ${y + 6} v-8" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round"/>`],
    ['Profil', (x, y, c) => `<circle cx="${x}" cy="${y - 3}" r="3.4" fill="none" stroke="${c}" stroke-width="1.7"/><path d="M${x - 7} ${y + 7} a7 6 0 0 1 14 0" fill="none" stroke="${c}" stroke-width="1.7" stroke-linecap="round"/>`],
  ];
  ecran += g(T.mini, T.fin, `<rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" fill="${APP.fond}"/>
    ${[[52, 26, 120], [96, 118, SL - 28], [228, 84, SL - 28], [326, 84, SL - 28]].map(([y, h, l]) => `<rect x="${SX + 14}" y="${SY + y}" width="${l}" height="${h}" rx="${h > 40 ? 16 : 8}" fill="${APP.carte}"/>`).join('')}
    <rect x="${MX}" y="${MY}" width="${ML}" height="84" rx="13" fill="${APP.carte2}" stroke="${APP.carte3}"/>
    <rect x="${MX}" y="${MY}" width="${ML}" height="84" rx="13" fill="none" stroke="${ACCENT}" stroke-width="1.5" filter="url(#halo)" opacity="0">${visible(C, T.mini, T.mini + 0.07, 0.008)}</rect>
    ${t(MX + 14, MY + 24, 'Entraînement en cours', { taille: 12, couleur: APP.texte, poids: 700 })}
    ${suite(MX + ML - 14, MY + 24, duree(T.mini - 0.02, 0.999), 0.999, { taille: 12, couleur: APP.texte, poids: 700, ancre: 'end' })}
    <rect x="${MX + 10}" y="${MY + 40}" width="${MB}" height="32" rx="9" fill="#FFFFFF"/>
    ${t(MX + 10 + MB / 2, MY + 60.5, 'Reprendre', { taille: 11.5, couleur: '#000000', poids: 700, ancre: 'middle' })}
    <rect x="${MX + 18 + MB}" y="${MY + 40}" width="${MB}" height="32" rx="9" fill="${APP.carte3}"/>
    ${t(MX + 18 + MB * 1.5, MY + 60.5, 'Abandonner', { taille: 11.5, couleur: ROUGE, poids: 700, ancre: 'middle' })}
    <line x1="${SX}" y1="${SY + 520}" x2="${SX + SL}" y2="${SY + 520}" stroke="${APP.trait}"/>
    ${onglets.map(([nom, icone], k) => {
      const x = SX + SL * (k + 0.5) / 4, c = k === 1 ? APP.texte : APP.discret;
      return `${icone(x, SY + 540, c)}${t(x, SY + 564, nom, { taille: 9.5, couleur: c, poids: k === 1 ? 700 : 500, ancre: 'middle' })}`;
    }).join('')}`);
  corps += `<g clip-path="url(#ecranSeance)">${ecran}</g>`;

  // Le vibreur : un tic à 3, 2 et 1 seconde, un coup plus long à la fin.
  const onde = (de, a, r) => [-1, 1].map((cote) => {
    const x = cote < 0 ? PX - 8 : PX + PL + 8;
    return g(de, a, [0, 1].map((k) => `<path d="M${x + cote * k * 7} ${PY + PH / 2 - r - k * 6} q${cote * 7} ${r + k * 6} 0 ${2 * (r + k * 6)}" fill="none" stroke="${BLEU}" stroke-width="2" stroke-linecap="round" stroke-opacity="${1 - k * 0.4}"/>`).join(''), 0.003);
  }).join('');
  [0, 1, 2].forEach((k) => { corps += onde(T.saut + k / C + 0.003, T.saut + k / C + 0.012, 12); });
  corps += onde(T.finRepos, T.finRepos + 0.03, 24);

  // ------------------------------------------------ à droite : les six étapes
  const RX = 420, RL = 800, EH = 88, EP = 98, E0 = 80;
  const etapes = [
    ['Cocher la série', VERT, [0.004, T.coche1 + 0.015],
      ['Un toucher sur la coche : la ligne passe au vert, le volume et le compteur de séries montent.',
        'Un champ vide reprend la valeur « Précédent » ; une série vide, sans précédent, n’est pas validée.'],
      [['80 kg × 8', TITRE], ['+640 kg', VERT], ['+1 série', VERT]]],
    ['Le repos part seul', BLEU, [T.coche1 + 0.015, T.pilule],
      ['Le minuteur de l’exercice démarre à la validation : 90 s par défaut, 60 s au plus après un échauffement.',
        'Il ne part ni au milieu d’un superset, ni après la dernière série de la séance.'],
      [['90 s par défaut', BLEU], ['60 · 90 · 120 · 150 s', TEXTE]]],
    ['Le régler en grand', BLEU, [T.pilule, T.retour],
      ['Un toucher sur la pilule ouvre le minuteur en plein écran : l’anneau bleu se vide avec le temps qui reste.',
        '« −10 » et « +10 » retirent ou ajoutent dix secondes ; « Arrêter » coupe le repos.'],
      [['−10', TITRE], ['+10', TITRE], ['Arrêter', ROUGE]]],
    ['La fin du repos', BLEU, [T.retour, T.kg - 0.01],
      ['Le vibreur donne un tic à 3, 2 et 1 seconde, puis un coup plus long, avec le son de fin.',
        'Appli en arrière-plan : une notification « Repos terminé » prend le relais.'],
      [['3', BLEU], ['2', BLEU], ['1', BLEU], ['son de fin', BLEU]]],
    ['Le record', OR, [T.kg - 0.01, T.reduire - 0.01],
      ['82,5 kg × 8 bat la charge la plus lourde des séances d’avant (80 kg) et leur meilleur 1RM estimé (100,3 kg).',
        'La ligne passe à l’or, l’écusson « PR » annonce chaque record. À 80 kg × 8, la série 1 égalait sans dépasser.'],
      [['Charge maximale · 82,5 kg', OR], ['1RM estimé · 103,5 kg', OR]]],
    ['Réduire la séance', ACCENT, [T.reduire - 0.01, 0.996],
      ['Le chevron ferme l’écran sans arrêter la séance : une barre reste au-dessus des onglets.',
        'Elle montre le chrono, « Reprendre » et « Abandonner » ; ni l’exercice en cours, ni le repos.'],
      [['Reprendre', TITRE], ['Abandonner', ROUGE]]],
  ];
  etapes.forEach(([titre, c, [de, a], lignes, puces], k) => {
    const y = E0 + k * EP;
    corps += `<rect x="${RX}" y="${y}" width="${RL}" height="${EH}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
      <rect x="${RX}" y="${y}" width="${RL}" height="${EH}" rx="13" fill="${c}" fill-opacity="0.07" stroke="${c}" stroke-opacity="0.85" opacity="0">${visible(C, de, a, 0.006)}</rect>
      <circle cx="${RX + 30}" cy="${y + 30}" r="13" fill="${FOND}" stroke="${FIL}" stroke-width="2"/>
      <circle cx="${RX + 30}" cy="${y + 30}" r="13" fill="${c}" opacity="0">${visible(C, de, 0.996, 0.006)}</circle>
      ${t(RX + 30, y + 34.5, String(k + 1), { taille: 12.5, couleur: TEXTE, police: MONO, poids: 700, ancre: 'middle' })}
      ${g(de, 0.996, t(RX + 30, y + 34.5, String(k + 1), { taille: 12.5, couleur: '#000', police: MONO, poids: 800, ancre: 'middle' }), 0.006)}
      ${t(RX + 56, y + 35, titre, { taille: 15, couleur: TITRE, poids: 700 })}
      ${lignes.map((l, i) => t(RX + 56, y + 57 + i * 18, l, { taille: 12.5, couleur: TEXTE })).join('')}`;
    if (k < etapes.length - 1) corps += `<path d="M${RX + 30} ${y + EH + 1} v${EP - EH - 2}" stroke="${FIL}" stroke-width="2"/>`;
    // Les puces, alignées à droite sur la ligne du titre.
    let x = RX + RL - 16;
    [...puces].reverse().forEach(([texte, cp]) => {
      const l = Math.round(tr(texte).length * 6.5 + 22);
      x -= l;
      corps += `<rect x="${x}" y="${y + 17}" width="${l}" height="26" rx="13" fill="${cp}" fill-opacity="0.09" stroke="${cp}" stroke-opacity="0.45"/>
        ${t(x + l / 2, y + 34.5, texte, { taille: 11.5, couleur: cp, poids: 700, ancre: 'middle' })}`;
      x -= 8;
    });
  });

  corps += t(RX, 688, 'Chaque geste est écrit sur le téléphone : la séance en cours se retrouve telle quelle après une fermeture de l’appli.', { taille: 13, couleur: DISCRET });

  svg('seance.svg', 1280, 740, corps,
    'La séance, sur un téléphone animé, en six étapes. L’écran de séance montre la barre du haut (réduire, pilule du minuteur, Terminer), l’encadré Durée, Volume, Séries, et l’exercice Développé couché avec son tableau : Série, Précédent, Kg, Reps, trois séries dont le précédent vaut 80 kg × 8, 80 kg × 8 et 80 kg × 7. Étape 1 : un toucher sur la coche valide la première série, 80 kg × 8 ; la ligne passe au vert, le volume monte à 640 kg et le compteur à 1 série. Étape 2 : le minuteur de repos part seul, 90 secondes par défaut, 60 au plus après un échauffement, jamais au milieu d’un superset ni après la dernière série ; la pilule bleue affiche le temps qui reste. Étape 3 : un toucher sur la pilule ouvre le minuteur en plein écran, un anneau bleu qui se vide, avec les boutons −10, +10 et Arrêter ; +10 ajoute dix secondes. Étape 4 : à la fin du repos, le vibreur donne un tic à 3, 2 et 1 seconde, puis un coup plus long avec le son de fin ; en arrière-plan, une notification Repos terminé prend le relais. Étape 5 : la deuxième série passe à 82,5 kg × 8 et bat deux records, la charge maximale (80 kg avant) et le 1RM estimé (100,3 kg avant, 103,5 kg maintenant) ; la ligne passe à l’or, l’écusson PR s’ouvre en haut de l’écran et annonce chaque record, et l’encadré gagne une colonne Records. Étape 6 : le chevron réduit la séance en une barre Entraînement en cours posée au-dessus des onglets, avec le chrono et les boutons Reprendre et Abandonner. Chaque geste est écrit sur le téléphone.');
};
