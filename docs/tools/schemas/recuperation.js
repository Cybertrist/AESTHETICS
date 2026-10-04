// La récupération, muscle par muscle.
//
// Une séance (4 séries de développé couché, 3 de leg extension) charge la
// fatigue de quatre muscles ; la frise d'heures la fait retomber en ligne
// droite, chaque muscle à sa durée (60 h, 72 h, 48 h), jusqu'au seuil
// « prêt » de l'écran Récupération (90 %). À droite, le téléphone montre
// cet écran toutes les douze heures ; en bas, le groupe conseillé.
//
// Rien n'est écrit à la main : la formule de `Recovery.fatigue` et les
// règles de `Recup` (anneau, vignettes, conseil) sont reprises ici, et tous
// les pourcentages en sortent.
module.exports = (O) => {
  const { svg, t, tr, paliers, fondu, visible, APP, MONO, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT } = O;
  const C = 30, FIN = 0.972;
  const ORANGE = '#FFA928', PRET = '#22D85F', ALERTE = '#FFC857';

  // ------------------------------------------------------------ le calcul
  // Les dix-huit muscles suivis (ni le cou ni les abducteurs), dans l'ordre
  // de l'enum, avec leur groupe.
  const MUSCLES = [
    ['pectoraux', 'Pectoraux', 'poitrine'], ['deltoidesAnterieurs', 'Deltoïdes antérieurs', 'epaules'],
    ['deltoidesLateraux', 'Deltoïdes latéraux', 'epaules'], ['deltoidesPosterieurs', 'Deltoïdes postérieurs', 'epaules'],
    ['biceps', 'Biceps', 'bras'], ['triceps', 'Triceps', 'bras'], ['avantBras', 'Avant-bras', 'bras'],
    ['trapezes', 'Trapèzes', 'dos'], ['grandDorsal', 'Grand dorsal', 'dos'], ['rhomboides', 'Rhomboïdes', 'dos'],
    ['lombaires', 'Lombaires', 'dos'], ['abdominaux', 'Abdominaux', 'abdos'], ['obliques', 'Obliques', 'abdos'],
    ['fessiers', 'Fessiers', 'jambes'], ['quadriceps', 'Quadriceps', 'jambes'], ['ischios', 'Ischio-jambiers', 'jambes'],
    ['adducteurs', 'Adducteurs', 'jambes'], ['mollets', 'Mollets', 'jambes'],
  ];
  const NOM = Object.fromEntries(MUSCLES.map(([id, nom]) => [id, nom]));
  const duree = (m) => (['quadriceps', 'ischios', 'fessiers', 'grandDorsal', 'lombaires'].includes(m) ? 72
    : ['pectoraux', 'trapezes', 'rhomboides', 'adducteurs', 'abducteurs'].includes(m) ? 60 : 48);
  const SEANCE = [
    { nom: 'Développé couché', series: 4, principaux: ['pectoraux'], secondaires: ['deltoidesAnterieurs', 'triceps'], groupe: 'poitrine' },
    { nom: 'Leg extension', series: 3, principaux: ['quadriceps'], secondaires: [], groupe: 'jambes' },
  ];
  // Fatigue de chaque muscle, [heures] après la séance (null : avant).
  const fatigue = (heures) => {
    const charge = {};
    if (heures === null || heures > 96) return charge;
    for (const e of SEANCE) {
      const add = (m, poids) => {
        const reste = 1 - heures / duree(m);
        if (reste <= 0) return;
        charge[m] = (charge[m] || 0) + e.series * poids * reste / 6;
      };
      e.principaux.forEach((m) => add(m, 1));
      e.secondaires.forEach((m) => add(m, 0.5));
    }
    for (const m in charge) charge[m] = Math.min(1, charge[m]);
    return charge;
  };
  const SEUIL = 90;
  const GROUPES = [['jambes', 'Jambes', 'quadriceps'], ['poitrine', 'Pectoraux', 'pectoraux'], ['dos', 'Dos', 'grandDorsal'],
    ['epaules', 'Épaules', 'deltoidesLateraux'], ['bras', 'Bras', 'biceps'], ['abdos', 'Abdos', 'abdominaux']];
  const etat = (heures) => {
    const f = fatigue(heures);
    const pct = Object.fromEntries(MUSCLES.map(([id]) => [id, Math.round((1 - (f[id] || 0)) * 100)]));
    const global = Math.round(MUSCLES.reduce((a, [id]) => a + pct[id], 0) / MUSCLES.length);
    // Les six vignettes : « Épaules » prend le faisceau le moins récupéré.
    const epaule = ['deltoidesAnterieurs', 'deltoidesLateraux', 'deltoidesPosterieurs'].reduce((a, b) => (pct[b] < pct[a] ? b : a));
    const vignettes = [['Pectoraux', 'pectoraux'], ['Épaules', epaule], ['Triceps', 'triceps'], ['Grand dorsal', 'grandDorsal'], ['Biceps', 'biceps'], ['Quadriceps', 'quadriceps']];
    // Le conseil : le groupe dont le muscle le moins récupéré l'est le plus ;
    // à égalité, celui qui n'a pas travaillé depuis le plus longtemps.
    const derniere = {};
    if (heures !== null) for (const e of SEANCE) derniere[e.groupe] = 0;
    const quand = (r) => (r in derniere ? derniere[r] : -Infinity);
    let choix = null, noteChoix = -1;
    const notes = GROUPES.map(([r, label]) => {
      const l = MUSCLES.filter((m) => m[2] === r);
      const faible = l.reduce((a, b) => (pct[b[0]] < pct[a[0]] ? b : a));
      const note = pct[faible[0]];
      if (choix === null || note > noteChoix || (note === noteChoix && quand(r) < quand(choix))) { choix = r; noteChoix = note; }
      return { r, label, note, faible: faible[0] };
    });
    const [, label, phare] = GROUPES.find((x) => x[0] === choix);
    const sujet = phare === 'grandDorsal' ? 'Grand dorsal récupéré' : phare === 'deltoidesLateraux' ? 'Épaules récupérées' : `${NOM[phare]} récupérés`;
    return { heures, pct, global, vignettes, notes, choix, label, phrase: `${sujet} à ${pct[phare]} %` };
  };
  const HEURES = [null, 0, 12, 24, 36, 48, 60, 72];
  const ETATS = HEURES.map(etat);
  // L'heure où un muscle passe « prêt » : le pourcentage arrondi atteint 90.
  const heurePret = (m, f0) => duree(m) * (1 - (1 - (SEUIL - 0.5) / 100) / f0);

  // Les instants du récit : la séance, la fatigue, puis six pas de 12 h.
  const T = { serie: (i) => 0.025 + i * 0.012, finSeance: 0.118, ligne: (i) => 0.14 + i * 0.03, depart: (k) => 0.27 + (k - 1) * 0.095, arrivee: (k) => 0.27 + (k - 1) * 0.095 + 0.03, conseil: 0.8 };
  const E = [0, T.finSeance, ...[1, 2, 3, 4, 5, 6].map(T.arrivee)]; // début de chaque état
  const g = (de, a, contenu, douceur = 0.006) => `<g opacity="0">${visible(C, de, a, douceur)}${contenu}</g>`;
  /// Visible pendant l'état k seulement.
  const pendant = (k, contenu) => {
    const pas = k === 0 ? [[0, 1], [E[1], 0]] : k === E.length - 1 ? [[0, 0], [E[k], 1]] : [[0, 0], [E[k], 1], [E[k + 1], 0]];
    return `<g opacity="${k === 0 ? 1 : 0}">${paliers('opacity', C, pas)}${contenu}</g>`;
  };
  /// Une valeur d'attribut par état.
  const parEtat = (attribut, f) => {
    const v = ETATS.map(f);
    return paliers(attribut, C, v.map((x, k) => [E[k], x]));
  };
  const couleur = (p) => (p >= SEUIL ? PRET : ORANGE);
  const titreBloc = (x, y, s) => t(x, y, s, { taille: 11, couleur: DISCRET, police: MONO, poids: 700, extra: 'letter-spacing="2"' });
  const virgule = (v, d = 2) => v.toFixed(d).replace('.', ',');

  let corps = '';
  corps += t(60, 52, 'LA RÉCUPÉRATION', { taille: 13, couleur: ACCENT, police: MONO, poids: 700, extra: 'letter-spacing="3"' });
  corps += t(Math.round(66 + tr('LA RÉCUPÉRATION').length * 10.9 + 24), 52, 'Muscle par muscle : chaque série fatigue, chaque heure répare, en ligne droite.', { taille: 14 });

  // ------------------------------------------------- 1 · la séance
  const AX = 60, AL = 320;
  corps += `<rect x="${AX}" y="80" width="${AL}" height="172" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(AX + 20, 108, '1 · LA SÉANCE');
  let rang = 0;
  SEANCE.forEach((e, i) => {
    const y = 136 + i * 72;
    corps += t(AX + 20, y, e.nom, { taille: 14, couleur: TITRE, poids: 700 });
    for (let k = 0; k < e.series; k++) {
      const x = AX + AL - 20 - (e.series - k) * 27 + 5, a = T.serie(rang++);
      corps += `<rect x="${x}" y="${y - 16}" width="22" height="22" rx="6" fill="${CARTE}" stroke="${FIL}"/>
        <g opacity="0">${fondu('opacity', C, [[0, 0], [a, 0], [a + 0.004, 1], [1, 1]])}
          <rect x="${x}" y="${y - 16}" width="22" height="22" rx="6" fill="${APP.serieFaite}" stroke="${APP.foret}"/>
          <path d="M${x + 6} ${y - 5} l3.5 3.5 l7 -7" fill="none" stroke="${APP.foret}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>`;
    }
    corps += t(AX + 20, y + 20, `principal : ${e.principaux.map((m) => NOM[m].toLowerCase()).join(', ')}`, { taille: 12 });
    if (e.secondaires.length) corps += t(AX + 20, y + 37, `secondaires : ${e.secondaires.map((m) => NOM[m].toLowerCase()).join(', ')}`, { taille: 12 });
  });

  // ------------------------------------------------- 2 · la fatigue
  const FY = 266;
  corps += `<rect x="${AX}" y="${FY}" width="${AL}" height="258" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(AX + 20, FY + 28, '2 · LA FATIGUE, DE 0 À 1');
  corps += `<rect x="${AX + 16}" y="${FY + 42}" width="${AL - 32}" height="32" rx="9" fill="${ACCENT}" fill-opacity="0.07" stroke="${ACCENT}" stroke-opacity="0.35"/>`;
  corps += t(AX + AL / 2, FY + 63, 'séries × pondération × reste ÷ 6', { taille: 13, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' });
  corps += t(AX + 20, FY + 96, 'Pondération : 1 en principal, 0,5 en secondaire.', { taille: 12 });
  corps += t(AX + 20, FY + 114, 'Six séries saturent le muscle : plafond à 1.', { taille: 12 });
  corps += t(AX + 20, FY + 132, 'Juste après la séance, reste = 1 :', { taille: 12 });
  const lignes = [];
  for (const e of SEANCE) {
    for (const m of e.principaux) lignes.push([m, e.series, 1]);
    for (const m of e.secondaires) lignes.push([m, e.series, 0.5]);
  }
  lignes.forEach(([m, n, p], i) => {
    const y = FY + 156 + i * 21, f = n * p / 6, a = T.ligne(i);
    corps += t(AX + 20, y, m === 'deltoidesAnterieurs' ? 'Deltoïdes ant.' : NOM[m], { taille: 12, couleur: TITRE, poids: 600 });
    corps += g(a, 1, `${t(AX + 118, y, `${n} × ${String(p).replace('.', ',')} ÷ 6 = ${virgule(f)}`, { taille: 11.5, couleur: TEXTE, police: MONO })}
      ${t(AX + AL - 20, y, `${Math.round((1 - f) * 100)} %`, { taille: 12, couleur: ORANGE, police: MONO, poids: 700, ancre: 'end' })}`);
  });
  corps += t(AX + 20, FY + 244, 'Affiché : (1 − fatigue) × 100, arrondi.', { taille: 11.5, couleur: DISCRET });

  // ------------------------------------------------- le corps, face et dos
  const KY = 536, KH = 234;
  corps += `<rect x="${AX}" y="${KY}" width="${AL}" height="${KH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(AX + 20, KY + 28, 'LE CORPS, À L’HEURE DU CURSEUR');
  // Une silhouette schématique, dans une boîte de 100 × 220.
  const miroir = (x, l) => 100 - x - l;
  const paire = (f) => f(false) + f(true);
  const silhouette = (base) => `<g fill="${base}">
    <circle cx="50" cy="15" r="11"/><rect x="45" y="24" width="10" height="10"/>
    <path d="M30 33 H70 Q79 33 79 43 L70 100 Q70 107 63 107 H37 Q30 107 30 100 L21 43 Q21 33 30 33 Z"/>
    ${paire((d) => `<rect x="${d ? miroir(7.5, 13) : 7.5}" y="38" width="13" height="46" rx="6.5" transform="rotate(${d ? -7 : 7} ${d ? 86 : 14} 40)"/>
      <rect x="${d ? miroir(3, 11) : 3}" y="84" width="11" height="40" rx="5.5" transform="rotate(${d ? -3 : 3} ${d ? 91.5 : 8.5} 84)"/>
      <rect x="${d ? miroir(30, 19) : 30}" y="104" width="19" height="60" rx="9"/>
      <rect x="${d ? miroir(32, 15) : 32}" y="166" width="15" height="48" rx="7"/>`)}</g>`;
  const FORME = {
    pectoraux: (a, i) => paire((d) => `<rect x="${d ? miroir(33.5, 15) : 33.5}" y="45" width="15" height="14" rx="5.5" ${a}>${i}</rect>`),
    deltoides: (a, i) => paire((d) => `<circle cx="${d ? 75.5 : 24.5}" cy="42" r="6.5" ${a}>${i}</circle>`),
    bras: (a, i) => paire((d) => `<rect x="${d ? miroir(9, 10) : 9}" y="55" width="10" height="25" rx="5" transform="rotate(${d ? -7 : 7} ${d ? 86 : 14} 40)" ${a}>${i}</rect>`),
    quadriceps: (a, i) => paire((d) => `<rect x="${d ? miroir(32, 15) : 32}" y="112" width="15" height="46" rx="7" ${a}>${i}</rect>`),
    grandDorsal: (a, i) => paire((d) => `<path d="${d ? 'M70 56 L52 63 L53 98 L64 98 Z' : 'M30 56 L48 63 L47 98 L36 98 Z'}" stroke-linejoin="round" stroke-width="3" ${a}>${i}</path>`),
  };
  const FORME_DE = { pectoraux: 'pectoraux', deltoidesAnterieurs: 'deltoides', deltoidesLateraux: 'deltoides', deltoidesPosterieurs: 'deltoides', triceps: 'bras', biceps: 'bras', quadriceps: 'quadriceps', grandDorsal: 'grandDorsal' };
  const teinte = (m) => parEtat('fill', (e) => couleur(e.pct[m]));

  // Le vrai personnage de l'application, quand ses calques sont rangés dans
  // docs/exercices/corps/ : le corps de face et de dos, et un calque par
  // muscle, intégrés au SVG. Chaque calque est reteint, en orange tant que le
  // muscle récupère, en vert dès qu'il est prêt, comme sur l'écran. Sans ces
  // fichiers, le schéma garde la silhouette dessinée ci-dessus.
  const fs = require('fs'), chemin = require('path');
  const CORPS = chemin.join(__dirname, '..', '..', 'exercices', 'corps');
  const CALQUE_DE = { pectoraux: ['face', 'pectoraux'], deltoidesAnterieurs: ['face', 'deltoidesAnterieurs'], deltoidesLateraux: ['face', 'deltoidesAnterieurs'],
    deltoidesPosterieurs: ['face', 'deltoidesAnterieurs'], triceps: ['dos', 'triceps'], biceps: ['face', 'biceps'], quadriceps: ['face', 'quadriceps'], grandDorsal: ['dos', 'grandDorsal'] };
  const FICHIERS = ['face_base', 'dos_base', ...new Set(Object.values(CALQUE_DE).map(([v, m]) => `${v}_${m}`))];
  const VRAI = FICHIERS.every((f) => fs.existsSync(chemin.join(CORPS, `${f}.webp`)));
  // Reteindre un calque : sa clarté devient la couleur voulue, son modelé reste.
  const hex = (c) => [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16) / 255);
  const reteinte = (id, c, gain = 2.1) => `<filter id="${id}" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="${hex(c)
    .map((v) => [0.2126, 0.7152, 0.0722].map((l) => (l * gain * v).toFixed(3)).join(' ') + ' 0 0').join(' ')} 0 0 0 1 0"/></filter>`;
  if (VRAI) {
    corps += `<defs>${reteinte('recupOrange', ORANGE)}${reteinte('recupVert', PRET)}
      ${FICHIERS.map((f) => `<symbol id="recup-${f}" viewBox="0 0 100 220"><image width="100" height="220" preserveAspectRatio="xMidYMid meet" href="data:image/webp;base64,${fs.readFileSync(chemin.join(CORPS, `${f}.webp`)).toString('base64')}"/></symbol>`).join('')}</defs>`;
  }
  const pose = (f, extra = '') => `<use href="#recup-${f}" width="100" height="220" ${extra}/>`;
  /// Un muscle sur le vrai corps : orange dessous, vert dessus quand il est prêt.
  const calque = (m, pct) => {
    const f = CALQUE_DE[m].join('_');
    return `${pose(f, 'filter="url(#recupOrange)"')}<use href="#recup-${f}" width="100" height="220" filter="url(#recupVert)" opacity="1">${parEtat('opacity', (e) => (pct(e) >= SEUIL ? 1 : 0))}</use>`;
  };
  const figure = (x, y, k, muscles, legende, vue = 'face') => `<g transform="translate(${x},${y}) scale(${k})">${VRAI
    ? pose(`${vue}_base`) + muscles.map((m) => calque(m, (e) => e.pct[m])).join('')
    : silhouette('#2B2E36') + muscles.map((m) => FORME[FORME_DE[m]](`fill="${PRET}"`, teinte(m))).join('')}</g>
    ${t(x + 50 * k, y + 220 * k + 16, legende, { taille: 11, couleur: DISCRET, ancre: 'middle' })}`;
  corps += figure(AX + 26, KY + 40, 0.76, ['pectoraux', 'deltoidesAnterieurs', 'quadriceps'], 'de face');
  corps += figure(AX + 122, KY + 40, 0.76, ['triceps'], 'de dos', 'dos');
  const LX = AX + 222;
  corps += `<circle cx="${LX}" cy="${KY + 76}" r="6" fill="${ORANGE}"/>${t(LX + 13, KY + 80, 'en récupération', { taille: 11.5, couleur: TITRE })}
    <circle cx="${LX}" cy="${KY + 104}" r="6" fill="${PRET}"/>${t(LX + 13, KY + 108, 'prêt : 90 %', { taille: 11.5, couleur: TITRE })}
    ${t(LX + 13, KY + 124, 'et plus', { taille: 11.5, couleur: TITRE })}`;
  corps += t(LX - 6, KY + 166, 'Deux couleurs,', { taille: 11.5 }) + t(LX - 6, KY + 183, 'comme dans', { taille: 11.5 }) + t(LX - 6, KY + 200, 'l’appli.', { taille: 11.5 });

  // ------------------------------------------------- 3 · les heures
  const BX = 400, BL = 490, BY = 80, BH = 360;
  const X0 = 548, X1 = 846, YH = 170, YB = 322; // 0 h à 72 h ; fatigue 1 en haut, 0 en bas
  const X = (h) => X0 + (X1 - X0) * h / 72, Y = (f) => YB - (YB - YH) * f;
  corps += `<rect x="${BX}" y="${BY}" width="${BL}" height="${BH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(BX + 20, BY + 28, '3 · LES HEURES');
  corps += t(BX + 20, BY + 50, 'reste = 1 − heures ÷ durée : la fatigue s’efface en ligne droite.', { taille: 12.5 });
  // La zone « prêt », sous le seuil.
  const FSEUIL = 1 - (SEUIL - 0.5) / 100;
  corps += `<rect x="${X0}" y="${Y(FSEUIL)}" width="${X1 - X0}" height="${YB - Y(FSEUIL)}" fill="${PRET}" fill-opacity="0.1"/>
    <line x1="${X0}" y1="${Y(FSEUIL)}" x2="${X1}" y2="${Y(FSEUIL)}" stroke="${PRET}" stroke-opacity="0.8" stroke-dasharray="4 4"/>`;
  // Les axes : la fatigue à gauche, ce que l'écran affiche à droite.
  corps += `<path d="M${X0} ${YH - 8} V${YB} H${X1 + 4}" fill="none" stroke="${FIL}" stroke-width="1.5"/>`;
  corps += t(X0 - 44, YH - 22, 'fatigue', { taille: 10.5, couleur: DISCRET, poids: 700 });
  corps += t(X1 + 34, YH - 22, 'affiché', { taille: 10.5, couleur: DISCRET, poids: 700, ancre: 'end' });
  [[1, '1'], [4 / 6, '0,67'], [0.5, '0,50'], [2 / 6, '0,33'], [0, '0']].forEach(([f, s]) => {
    corps += `<line x1="${X0 - 4}" y1="${Y(f)}" x2="${X1}" y2="${Y(f)}" stroke="${FIL}" stroke-opacity="${f === 0 ? 0 : 0.35}" stroke-dasharray="2 5"/>`;
    corps += t(X0 - 26, Y(f) + 4, s, { taille: 10.5, couleur: TEXTE, police: MONO, ancre: 'end' });
    corps += t(X1 + 34, Y(f) + (f === 0 ? 8 : 4), `${Math.round((1 - f) * 100)} %`, { taille: 10.5, couleur: TEXTE, police: MONO, ancre: 'end' });
  });
  corps += t(X1 - 6, YH + 4, 'six séries : saturé', { taille: 10.5, couleur: DISCRET, ancre: 'end' });
  corps += t(X1 - 4, Y(FSEUIL) - 6, 'prêt', { taille: 11, couleur: PRET, poids: 700, ancre: 'end' });
  corps += t(X1 + 34, Y(FSEUIL) + 1, `${SEUIL} %`, { taille: 10.5, couleur: PRET, police: MONO, poids: 700, ancre: 'end' });
  for (let h = 0; h <= 72; h += 12) {
    corps += `<line x1="${X(h)}" y1="${YB}" x2="${X(h)}" y2="${YB + 5}" stroke="${FIL}" stroke-width="1.5"/>`;
    corps += t(X(h), YB + 20, `${h} h`, { taille: 11, couleur: TEXTE, police: MONO, ancre: 'middle' });
  }
  // Le curseur.
  corps += `<g opacity="0">${visible(C, T.finSeance, 1, 0.006)}<g>
    <animateTransform attributeName="transform" type="translate" dur="${C}s" repeatCount="indefinite" keyTimes="${[0, T.depart(1), ...[1, 2, 3, 4, 5, 6].flatMap((k) => (k > 1 ? [T.depart(k), T.arrivee(k)] : [T.arrivee(k)])), 1].join(';')}"
      values="${[0, 0, ...[1, 2, 3, 4, 5, 6].flatMap((k) => (k > 1 ? [(k - 1) * 12, k * 12] : [k * 12])), 72].map((h) => `${(X(h) - X0).toFixed(1)} 0`).join(';')}"/>
    <line x1="${X0}" y1="${YH - 8}" x2="${X0}" y2="${YB + 72}" stroke="${TITRE}" stroke-opacity="0.75" stroke-width="1.5"/>
    <path d="M${X0 - 5} ${YH - 13} h10 l-5 6 z" fill="${TITRE}"/></g></g>`;
  // Les trois droites : pointillées d'avance, pleines sous le curseur.
  const droites = [
    { nom: 'Pectoraux', court: 'Pectoraux', m: 'pectoraux', f0: 4 / 6 },
    { nom: 'Quadriceps', court: 'Quadriceps', m: 'quadriceps', f0: 3 / 6 },
    { nom: 'Deltoïdes antérieurs, triceps', court: 'Delt., triceps', m: 'triceps', f0: 2 / 6 },
  ];
  const balayage = (attribut, f) => {
    // Le curseur : immobile, puis six pas de 12 h.
    const temps = [0, T.depart(1)], valeurs = [f(0), f(0)];
    for (let k = 1; k <= 6; k++) { if (k > 1) { temps.push(T.depart(k)); valeurs.push(f((k - 1) * 12)); } temps.push(T.arrivee(k)); valeurs.push(f(k * 12)); }
    temps.push(1); valeurs.push(f(72));
    return `<animate attributeName="${attribut}" dur="${C}s" repeatCount="indefinite" keyTimes="${temps.join(';')}" values="${valeurs.join(';')}"/>`;
  };
  corps += `<clipPath id="recupTrace"><rect x="${X0 - 2}" y="${YH - 10}" height="${YB - YH + 14}" width="2">${balayage('width', (h) => X(h) - X0 + 2)}</rect></clipPath>`;
  let pointilles = '', pleins = '', reperes = '', passages = '';
  droites.forEach((d, i) => {
    const fin = duree(d.m), hp = heurePret(d.m, d.f0);
    const trace = (extra) => `<path d="M${X(0)} ${Y(d.f0)} L${X(hp)} ${Y(FSEUIL)}" fill="none" stroke="${ORANGE}" ${extra}/><path d="M${X(hp)} ${Y(FSEUIL)} L${X(fin)} ${Y(0)}" fill="none" stroke="${PRET}" ${extra}/>`;
    pointilles += trace('stroke-width="1.5" stroke-opacity="0.45" stroke-dasharray="3 4"');
    pleins += trace('stroke-width="2.6" stroke-linecap="round"');
    // Le numéro de la droite, à son départ.
    reperes += `<circle cx="${X0}" cy="${Y(d.f0)}" r="8" fill="${FOND}" stroke="${ORANGE}" stroke-width="1.5"/>${t(X0, Y(d.f0) + 3.8, String(i + 1), { taille: 10.5, couleur: ORANGE, police: MONO, poids: 700, ancre: 'middle' })}`;
    // L'instant où elle passe le seuil : le curseur y passe entre deux pas.
    const k = Math.ceil(hp / 12), quand = T.depart(k) + (T.arrivee(k) - T.depart(k)) * (hp - (k - 1) * 12) / 12;
    passages += g(quand, 1, `<circle cx="${X(hp)}" cy="${Y(FSEUIL)}" r="4.5" fill="${PRET}" stroke="${FOND}" stroke-width="1.5"/>
      <line x1="${X(hp)}" y1="${Y(FSEUIL) + 5}" x2="${X(hp)}" y2="${YB}" stroke="${PRET}" stroke-opacity="0.6"/>`, 0.004);
    // Et la fin de la droite : la durée du muscle.
    reperes += `<circle cx="${X(fin)}" cy="${YB}" r="3.5" fill="${FOND}" stroke="${PRET}" stroke-width="1.5"/>`;
  });
  corps += g(T.finSeance, 1, pointilles) + `<g clip-path="url(#recupTrace)">${g(T.finSeance, 1, pleins)}</g>` + g(T.finSeance, 1, reperes) + passages;
  // La légende, dans le coin vide du graphique.
  droites.forEach((d, i) => {
    const y = YH + 22 + i * 20, x = X0 + 96;
    corps += `<circle cx="${x}" cy="${y - 4}" r="8" fill="${FOND}" stroke="${ORANGE}" stroke-width="1.5"/>${t(x, y - 0.2, String(i + 1), { taille: 10.5, couleur: ORANGE, police: MONO, poids: 700, ancre: 'middle' })}`;
    corps += t(x + 15, y, d.nom, { taille: 11.5, couleur: TITRE, poids: 600 });
    corps += t(X1 - 6, y, `${duree(d.m)} h`, { taille: 11.5, couleur: TEXTE, police: MONO, poids: 700, ancre: 'end' });
  });
  // Le relevé, toutes les douze heures, sous la frise.
  droites.forEach((d, i) => {
    const y = YB + 42 + i * 21;
    corps += `<line x1="${BX + 16}" y1="${y - 14}" x2="${BX + BL - 16}" y2="${y - 14}" stroke="${BORD}"/>`;
    corps += `<circle cx="${BX + 26}" cy="${y - 4}" r="7" fill="${FOND}" stroke="${ORANGE}" stroke-width="1.2"/>${t(BX + 26, y - 0.5, String(i + 1), { taille: 9.5, couleur: ORANGE, police: MONO, poids: 700, ancre: 'middle' })}`;
    corps += t(BX + 38, y, d.court, { taille: 11, couleur: TITRE, poids: 600 });
    ETATS.slice(1).forEach((e, k) => {
      const p = e.pct[d.m];
      corps += g(E[k + 1], 1, `<rect x="${X(e.heures) - 21}" y="${y - 12.5}" width="42" height="17" rx="8.5" fill="${FOND}"/>${t(X(e.heures), y, `${p} %`, { taille: 11, couleur: couleur(p), police: MONO, poids: 700, ancre: 'middle' })}`, 0.004);
    });
  });
  corps += t(BX + 20, BY + BH - 12, 'Seules les séances des 96 dernières heures comptent.', { taille: 11.5, couleur: DISCRET });

  // ------------------------------------------------- 4 · le conseil
  const GY = 454, GH = 316;
  corps += `<rect x="${BX}" y="${GY}" width="${BL}" height="${GH}" rx="16" fill="${CARTE}" stroke="${BORD}"/>`;
  corps += titreBloc(BX + 20, GY + 28, '4 · CONSEILLÉ AUJOURD’HUI');
  corps += t(BX + BL - 20, GY + 28, 'le moins récupéré de chaque groupe', { taille: 11, couleur: DISCRET, ancre: 'end' });
  const BARX = BX + 326, BARL = 96;
  const parEtatDoc = ETATS.map(() => ''), parEtatEcran = ETATS.map(() => '');
  GROUPES.forEach(([r, label], i) => {
    const y = GY + 46 + i * 31;
    // Le groupe retenu, état par état.
    corps += `<rect x="${BX + 12}" y="${y}" width="${BL - 24}" height="27" rx="9" fill="${PRET}" fill-opacity="0.09" stroke="${PRET}" stroke-opacity="0.75" opacity="0">${parEtat('opacity', (e) => (e.choix === r ? 1 : 0))}</rect>`;
    corps += t(BX + 26, y + 18, label, { taille: 13, couleur: TITRE, poids: 700 });
    corps += `<rect x="${BARX}" y="${y + 10}" width="${BARL}" height="7" rx="3.5" fill="${FIL}" fill-opacity="0.6"/>
      <rect x="${BARX}" y="${y + 10}" width="${BARL}" height="7" rx="3.5" fill="${PRET}">${parEtat('width', (e) => (BARL * e.notes[i].note / 100).toFixed(1))}${parEtat('fill', (e) => couleur(e.notes[i].note))}</rect>`;
    ETATS.forEach((e, k) => {
      const n = e.notes[i];
      const travaille = e.heures !== null && SEANCE.some((x) => x.groupe === r);
      const quoi = n.note < 100 ? NOM[n.faible].toLowerCase() : travaille ? `tout récupéré, séance il y a ${e.heures} h` : 'tout récupéré, pas de séance';
      parEtatDoc[k] += `${t(BX + 112, y + 18, quoi, { taille: 12, couleur: n.note === 100 ? DISCRET : TEXTE })}
        ${t(BX + BL - 26, y + 18, `${n.note} %`, { taille: 12, couleur: couleur(n.note), police: MONO, poids: 700, ancre: 'end' })}`;
    });
  });
  const RY = GY + 248;
  corps += `<line x1="${BX + 16}" y1="${RY - 14}" x2="${BX + BL - 16}" y2="${RY - 14}" stroke="${BORD}"/>`;
  corps += t(BX + 20, RY + 6, 'Un groupe vaut son muscle le moins récupéré : le meilleur l’emporte.', { taille: 12.5, couleur: TITRE });
  corps += t(BX + 20, RY + 26, 'À égalité, celui qui n’a pas travaillé depuis le plus longtemps,', { taille: 12.5 });
  corps += t(BX + 20, RY + 44, 'sinon le premier de la liste.', { taille: 12.5 });

  // ------------------------------------------------- le téléphone
  const PX = 916, PY = 100, PL = 304, PH = 592;
  const SX = PX + 12, SY = PY + 16, SL = PL - 24, SH = PH - 32;
  ETATS.forEach((e, k) => {
    parEtatDoc[k] += t(PX + PL / 2, PY - 10, e.heures === null ? 'avant la séance' : e.heures === 0 ? 'juste après la séance' : `séance + ${e.heures} h`, { taille: 12, couleur: TITRE, police: MONO, poids: 700, ancre: 'middle' });
  });
  corps += parEtatDoc.map((x, k) => pendant(k, x)).join('');
  corps += `<rect x="${PX}" y="${PY}" width="${PL}" height="${PH}" rx="40" fill="#07090C" stroke="#2F3A47" stroke-width="2"/>
    <clipPath id="ecranRecup"><rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28"/></clipPath>
    <rect x="${SX}" y="${SY}" width="${SL}" height="${SH}" rx="28" fill="${APP.fond}"/>
    <rect x="${PX + PL / 2 - 34}" y="${PY + 6}" width="68" height="5" rx="2.5" fill="#1B222C"/>`;
  let ecran = '';
  ecran += t(SX + 16, SY + 54, 'Récupération', { taille: 21, couleur: APP.texte, poids: 700 });
  ecran += t(SX + 16, SY + 76, 'Les muscles prêts pour', { taille: 12, couleur: APP.second }) + t(SX + 16, SY + 92, 'l’entraînement', { taille: 12, couleur: APP.second });
  // L'anneau : la moyenne des dix-huit muscles suivis.
  const RX = SX + SL - 54, RYC = SY + 62, RR = 31, TOUR = 2 * Math.PI * RR;
  ecran += `<circle cx="${RX}" cy="${RYC}" r="${RR}" fill="none" stroke="${APP.carte2}" stroke-width="7"/>
    <circle cx="${RX}" cy="${RYC}" r="${RR}" fill="none" stroke="${PRET}" stroke-width="7" stroke-linecap="round" transform="rotate(-90 ${RX} ${RYC})" stroke-dasharray="${TOUR} ${TOUR}">${parEtat('stroke-dasharray', (e) => `${(TOUR * e.global / 100).toFixed(1)} ${TOUR.toFixed(1)}`)}</circle>`;
  ETATS.forEach((e, k) => { parEtatEcran[k] += t(RX, RYC + 5.5, `${e.global} %`, { taille: 15.5, couleur: APP.texte, poids: 800, ancre: 'middle' }); });
  // Les six vignettes : la silhouette resserrée sur le muscle, son nom, sa pastille.
  const VL = (SL - 32 - 16) / 3, VH = 132, VY = SY + 116;
  const CADRE = { pectoraux: [20, 0], deltoides: [20, 0], bras: [20, 0], grandDorsal: [20, 0], quadriceps: [98, 1] };
  ETATS[0].vignettes.forEach(([label], i) => {
    const x = SX + 16 + (i % 3) * (VL + 8), y = VY + Math.floor(i / 3) * (VH + 8);
    const forme = FORME_DE[ETATS[1].vignettes[i][1]];
    const k = 0.64, [haut] = CADRE[forme];
    ecran += `<rect x="${x}" y="${y}" width="${VL}" height="${VH}" rx="14" fill="${APP.carte}"/>
      <clipPath id="recupVignette${i}"><rect x="${x + 8}" y="${y + 10}" width="${VL - 16}" height="62" rx="8"/></clipPath>
      <g clip-path="url(#recupVignette${i})"><g transform="translate(${x + VL / 2 - 50 * k},${y + 12 - haut * k}) scale(${k})">${VRAI
        ? pose(`${CALQUE_DE[ETATS[1].vignettes[i][1]][0]}_base`) + calque(ETATS[1].vignettes[i][1], (e) => (e.vignettes[i][1] ? e.pct[e.vignettes[i][1]] : 100))
        : silhouette(APP.carte3) + FORME[forme](`fill="${PRET}"`, parEtat('fill', (e) => couleur(e.vignettes[i][1] ? e.pct[e.vignettes[i][1]] : 100)))}</g></g>
      ${t(x + VL / 2, y + 90, label, { taille: 11.5, couleur: APP.texte, poids: 600, ancre: 'middle' })}
      <rect x="${x + VL / 2 - 25}" y="${y + 100}" width="50" height="22" rx="11" fill="${PRET}" fill-opacity="0.14">${parEtat('fill', (e) => (e.pct[e.vignettes[i][1]] >= SEUIL ? PRET : ALERTE))}</rect>`;
    ETATS.forEach((e, n) => {
      const p = e.pct[e.vignettes[i][1]];
      parEtatEcran[n] += t(x + VL / 2, y + 115.5, `${p} %`, { taille: 11.5, couleur: p >= SEUIL ? PRET : ALERTE, poids: 700, ancre: 'middle' });
    });
  });
  const LY = VY + 2 * VH + 8 + 26;
  ecran += t(SX + 16, LY, `${ETATS[0].vignettes.length} muscles sur ${MUSCLES.length}`, { taille: 12, couleur: APP.second });
  ecran += t(SX + SL - 16, LY, 'Tout afficher', { taille: 12.5, couleur: APP.texte, poids: 600, ancre: 'end' });
  // La carte « Conseillé aujourd'hui ».
  const CY = LY + 18, CH = 92;
  ecran += `<rect x="${SX + 16}" y="${CY}" width="${SL - 32}" height="${CH}" rx="18" fill="${APP.carte}"/>
    ${t(SX + 30, CY + 26, 'CONSEILLÉ AUJOURD’HUI', { taille: 10, couleur: APP.second, poids: 600, extra: 'letter-spacing="1.3"' })}
    <rect x="${SX + SL - 30 - 66}" y="${CY + 26}" width="66" height="42" rx="21" fill="#FFFFFF"/>
    ${t(SX + SL - 30 - 33, CY + 52, 'Voir', { taille: 13.5, couleur: '#000000', poids: 700, ancre: 'middle' })}`;
  ETATS.forEach((e, k) => {
    parEtatEcran[k] += `${t(SX + 30, CY + 50, e.label, { taille: 15.5, couleur: APP.texte, poids: 700 })}
      ${t(SX + 30, CY + 69, e.phrase, { taille: 10.5, couleur: APP.second })}`;
  });
  ecran += parEtatEcran.map((x, k) => pendant(k, x)).join('');
  // Un éclat sur la carte quand le conseil change, puis à la fin.
  [T.finSeance, T.conseil].forEach((de) => {
    ecran += `<rect x="${SX + 16}" y="${CY}" width="${SL - 32}" height="${CH}" rx="18" fill="none" stroke="${PRET}" stroke-width="1.8" opacity="0">${visible(C, de, de + 0.07, 0.006)}</rect>`;
  });
  corps += `<g clip-path="url(#ecranRecup)">${ecran}</g>`;
  corps += t(PX + PL / 2, PY + PH + 30, 'Onglet Progrès, page Récupération.', { taille: 12.5, couleur: TEXTE, ancre: 'middle' });
  corps += t(PX + PL / 2, PY + PH + 50, 'L’anneau : la moyenne des 18 muscles suivis.', { taille: 12.5, couleur: DISCRET, ancre: 'middle' });

  // Le fondu avant la reprise.
  corps += `<rect x="1" y="66" width="1278" height="733" rx="16" fill="${FOND}" opacity="1">${fondu('opacity', C, [[0, 1], [0.012, 0], [FIN, 0], [0.994, 1], [1, 1]])}</rect>`;

  const e0 = ETATS[1], pr = droites.map((d) => Math.round(heurePret(d.m, d.f0)));
  svg('recuperation.svg', 1280, 800, corps,
    `La récupération, muscle par muscle. Une séance de 4 séries de développé couché (pectoraux en principal, deltoïdes antérieurs et triceps en secondaire) et de 3 séries de leg extension (quadriceps) charge la fatigue de chaque muscle : séries × pondération × reste ÷ 6, avec une pondération de 1 en principal et de 0,5 en secondaire, six séries saturant le muscle. Juste après, les pectoraux sont à 0,67 de fatigue, soit ${e0.pct.pectoraux} % de récupération, les quadriceps à 0,50, soit ${e0.pct.quadriceps} %, les deltoïdes antérieurs et les triceps à 0,33, soit ${e0.pct.triceps} %. La fatigue s’efface ensuite en ligne droite, chaque muscle à sa durée : 60 heures pour les pectoraux, 72 pour les quadriceps, 48 pour les deltoïdes et les triceps. Toutes les douze heures, la frise relève les pourcentages : ${ETATS.slice(2).map((e) => `à ${e.heures} heures, ${e.pct.pectoraux}, ${e.pct.quadriceps} et ${e.pct.triceps} %`).join(' ; ')}. Un muscle passe de l’orange au vert au seuil « prêt » de l’écran, 90 % : vers ${pr[2]} heures pour les triceps et les deltoïdes, ${pr[0]} heures pour les pectoraux, ${pr[1]} heures pour les quadriceps. Sur le téléphone, la page Récupération montre l’anneau global, moyenne des 18 muscles suivis, qui tombe à ${e0.global} % après la séance, six vignettes de muscles et la carte « Conseillé aujourd’hui » : avant la séance, les jambes ; après, le dos, dont le grand dorsal est récupéré à 100 %. Le groupe conseillé est celui dont le muscle le moins récupéré l’est le plus ; à égalité, celui qui n’a pas travaillé depuis le plus longtemps.`);
};
