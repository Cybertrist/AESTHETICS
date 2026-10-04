// Les schémas animés du README.
//
// Des SVG plutôt que des GIF : quelques kilo-octets, nets à toute taille,
// et le texte reste du texte. Les animations sont en SMIL, que les
// navigateurs jouent même quand le SVG est chargé par une balise <img>,
// ce qui est le cas sur GitHub. Aucune police externe : un SVG affiché en
// <img> n'a pas le droit d'aller la chercher, on s'en tient aux familles
// du système.
//
//   node docs/tools/anime.js
//
// Ce fichier ne porte que les outils communs : chaque schéma a son fichier
// dans schemas/, avec sa traduction à côté (<nom>.en.json). Il se relance
// ensuite avec LANGUE=en, et les schémas anglais vont dans docs/en/schemas.
// Le moteur vient de SmartBudget.
const fs = require('fs');
const path = require('path');

const EN = process.env.LANGUE === 'en';
const SORTIE = path.join(__dirname, '..', ...(EN ? ['en'] : []), 'schemas');
const { traduire } = require('./traduire.js');
const manque = new Set();
/// Un texte dans la langue du rendu.
const tr = (s) => (EN ? traduire(s, manque) : s);
fs.mkdirSync(SORTIE, { recursive: true });

const MONO = 'ui-monospace,SFMono-Regular,Menlo,Consolas,monospace';
const SANS = 'system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif';
const FOND = '#0D1117';
const CARTE = '#15171C';
const BORD = '#26282E';
const TITRE = '#F5F5F7';
const TEXTE = '#9A9AA2';
const DISCRET = '#6A6A72';
const FIL = '#3A3A3F';
const ACCENT = '#E0393E'; // le rouge des muscles, l'accent de l'appli
const VERT = '#3FAE4A'; // une série validée
const NEON = '#22D85F';
const BLEU = '#1E9BF0'; // le minuteur de repos
const OR = '#FFC857';
const ROSE = '#9D8CFF';
const ROUGE = '#FF453A';
const INTERNE = '#8E8E93';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/// Le cadre commun : fond, grille estompée, filtre de halo.
function svg(nom, largeur, hauteur, corps, titre) {
  titre = tr(titre);
  const contenu = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${largeur} ${hauteur}" width="${largeur}" height="${hauteur}" role="img" aria-label="${esc(titre)}">
<title>${esc(titre)}</title>
<defs>
  <filter id="halo" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="6" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <pattern id="grille" width="40" height="40" patternUnits="userSpaceOnUse">
    <path d="M40 0H0V40" fill="none" stroke="#FFFFFF" stroke-opacity="0.035"/>
  </pattern>
  <pattern id="hachures" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
    <rect width="10" height="10" fill="#17181C"/><line x1="0" y1="0" x2="0" y2="10" stroke="#2C2D33" stroke-width="4"/>
  </pattern>
  <radialGradient id="lueur" cx="50%" cy="0%" r="80%">
    <stop offset="0" stop-color="#E0393E" stop-opacity="0.09"/><stop offset="1" stop-color="#E0393E" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="${largeur}" height="${hauteur}" rx="16" fill="${FOND}"/>
<rect width="${largeur}" height="${hauteur}" rx="16" fill="url(#grille)"/>
<rect width="${largeur}" height="${hauteur}" rx="16" fill="url(#lueur)"/>
${corps}
</svg>`;
  const leger = alleger(contenu);
  fs.writeFileSync(path.join(SORTIE, nom), leger);
  console.log(`  ${nom}  ${(leger.length / 1024).toFixed(1)} Ko`);
}

/// Allège un SVG sans rien changer à ce qu'on voit. Chrome redessine toute
/// l'image à chaque image d'une animation, et un élément transparent lui
/// coûte presque autant qu'un visible : pendant qu'il est à opacité 0, il
/// passe en display none et sort du rendu. Les nombres gardent trois
/// décimales, largement assez pour un pixel ou un instant.
function alleger(s) {
  // Les instants (keyTimes) gardent toute leur précision : arrondis, deux
  // instants voisins pourraient devenir égaux, et Chrome ignorerait
  // l'animation.
  s = s.replace(/(keyTimes="[^"]*")|(\d\.\d{3})\d+/g, (m, instants, court) => instants || court);
  // Un élément dont le premier enfant anime son opacité.
  return s.replace(/(<(?:g|rect|circle|path|text|line)\b[^>]*>)(\s*)<animate attributeName="opacity" dur="([\d.]+)s" repeatCount="indefinite" keyTimes="([^"]*)" values="([^"]*)"([^>]*)\/>/g,
    (m, ouverture, espace, dur, kt, vals, reste) => {
      const k = kt.split(';'), v = vals.split(';').map(Number);
      if (k.length !== v.length || v.some(Number.isNaN)) return m;
      const discret = /calcMode="discrete"/.test(reste);
      const cache = v.map((x, i) => (discret || i === v.length - 1 ? x === 0 : x === 0 && v[i + 1] === 0));
      if (!cache.some(Boolean)) return m;
      // Au départ, l'élément est déjà caché s'il commence transparent. Une
      // balise fermante sur elle-même n'est pas le parent de l'animation :
      // l'animation vaut pour le parent, qu'on ne touche pas.
      const debut = cache[0] && !ouverture.endsWith('/>') ? ouverture.replace(/>$/, ' display="none">') : ouverture;
      return `${debut}${espace}<animate attributeName="opacity" dur="${dur}s" repeatCount="indefinite" keyTimes="${kt}" values="${vals}"${reste}/>`
        + `<animate attributeName="display" dur="${dur}s" repeatCount="indefinite" keyTimes="${kt}" values="${cache.map((c) => (c ? 'none' : 'inline')).join(';')}" calcMode="discrete"/>`;
    });
}

/// Un texte.
const t = (x, y, s, { taille = 14, couleur = TEXTE, police = SANS, poids = 400, ancre = 'start', extra = '' } = {}) =>
  `<text x="${x}" y="${y}" font-family="${police}" font-size="${taille}" font-weight="${poids}" fill="${couleur}" text-anchor="${ancre}" ${extra}>${esc(tr(s))}</text>`;

/// Une valeur qui change par paliers au fil d'un cycle : [instant 0..1, valeur].
function paliers(attribut, cycle, etapes, extra = '') {
  const temps = etapes.map((e) => e[0]).join(';');
  const valeurs = etapes.map((e) => e[1]).join(';');
  return `<animate attributeName="${attribut}" dur="${cycle}s" repeatCount="indefinite" keyTimes="${temps}" values="${valeurs}" calcMode="discrete" ${extra}/>`;
}

/// Une valeur qui glisse d'un palier au suivant.
function fondu(attribut, cycle, etapes) {
  const temps = etapes.map((e) => e[0]).join(';');
  const valeurs = etapes.map((e) => e[1]).join(';');
  return `<animate attributeName="${attribut}" dur="${cycle}s" repeatCount="indefinite" keyTimes="${temps}" values="${valeurs}"/>`;
}

/// Apparaît à [de], disparaît à [a], sur un cycle.
function visible(cycle, de, a, douceur = 0.02) {
  const e = [[0, 0]];
  if (de > douceur) e.push([de - douceur, 0]);
  e.push([de, 1], [Math.min(a, 1), 1]);
  if (a + douceur < 1) e.push([a + douceur, 0], [1, 0]);
  else if (a < 1) e.push([1, 1]);
  return fondu('opacity', cycle, e);
}

/// Une carte de schéma : liseré coloré, titre en chasse fixe, sous-titre.
function carte(x, y, l, h, titre, sous, accent, { icone = '', allume = null, cycle = 10 } = {}) {
  const bord = allume
    ? `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="none" stroke="${accent}" stroke-width="1.5" opacity="0" filter="url(#halo)">${visible(cycle, allume[0], allume[1])}</rect>`
    : '';
  return `<g>
  <rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="${CARTE}" stroke="${BORD}"/>
  ${bord}
  <rect x="${x}" y="${y}" width="${l}" height="${h}" rx="13" fill="${accent}" fill-opacity="0.05" stroke="${accent}" stroke-opacity="0.3"/>
  ${icone ? `<g transform="translate(${x + 18},${y + h / 2 - 14})">${icone(accent)}</g>` : ''}
  ${t(x + (icone ? 58 : 20), y + h / 2 - 3, titre, { taille: 14.5, couleur: TITRE, police: MONO, poids: 700 })}
  ${t(x + (icone ? 58 : 20), y + h / 2 + 17, sous, { taille: 12.5 })}
</g>`;
}

/// Une bille lumineuse qui suit un chemin, avec une pause par étape.
function bille(chemin, cycle, points, temps, couleur = ACCENT, rayon = 6) {
  return `<g filter="url(#halo)">
  <circle r="${rayon + 5}" fill="${couleur}" opacity="0.22">
    <animateMotion dur="${cycle}s" repeatCount="indefinite" path="${chemin}" keyPoints="${points}" keyTimes="${temps}" calcMode="linear"/>
  </circle>
  <circle r="${rayon}" fill="${couleur}">
    <animateMotion dur="${cycle}s" repeatCount="indefinite" path="${chemin}" keyPoints="${points}" keyTimes="${temps}" calcMode="linear"/>
  </circle>
</g>`;
}

/// Un fil pointillé qui court.
const fil = (d, couleur = FIL) =>
  `<path d="${d}" fill="none" stroke="${couleur}" stroke-width="2" stroke-dasharray="6 7">
  <animate attributeName="stroke-dashoffset" from="26" to="0" dur="1.2s" repeatCount="indefinite"/></path>`;

// Des pictogrammes simples, dessinés en traits : téléphone, horloge, fichier…
const P = {
  telephone: (c) => `<rect x="4" y="0" width="20" height="28" rx="4" fill="none" stroke="${c}" stroke-width="2"/><circle cx="14" cy="23" r="1.6" fill="${c}"/>`,
  banque: (c) => `<path d="M2 11 L14 3 L26 11 Z M5 13 H23 M7 14 V23 M12 14 V23 M16 14 V23 M21 14 V23 M3 25 H25" fill="none" stroke="${c}" stroke-width="2" stroke-linejoin="round"/>`,
  nuage: (c) => `<path d="M8 22 H22 A5 5 0 0 0 21 12 A7 7 0 0 0 8 13 A4.5 4.5 0 0 0 8 22 Z" fill="none" stroke="${c}" stroke-width="2"/>`,
  page: (c) => `<rect x="4" y="2" width="20" height="24" rx="3" fill="none" stroke="${c}" stroke-width="2"/><path d="M9 10 H19 M9 15 H19 M9 20 H15" stroke="${c}" stroke-width="2"/>`,
  lien: (c) => `<path d="M11 17 L17 11 M9 13 L6 16 A4 4 0 0 0 12 22 L15 19 M19 15 L22 12 A4 4 0 0 0 16 6 L13 9" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"/>`,
  horloge: (c) => `<circle cx="14" cy="14" r="11" fill="none" stroke="${c}" stroke-width="2"/><path d="M14 8 V14 L18 17" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round"/>`,
  cle: (c) => `<circle cx="9" cy="14" r="5" fill="none" stroke="${c}" stroke-width="2"/><path d="M14 14 H26 M22 14 V18 M25 14 V17" stroke="${c}" stroke-width="2" stroke-linecap="round"/>`,
  cadenas: (c) => `<rect x="5" y="12" width="18" height="14" rx="3" fill="none" stroke="${c}" stroke-width="2"/><path d="M9 12 V8 A5 5 0 0 1 19 8 V12" fill="none" stroke="${c}" stroke-width="2"/>`,
  base: (c) => `<ellipse cx="14" cy="6" rx="10" ry="4" fill="none" stroke="${c}" stroke-width="2"/><path d="M4 6 V22 A10 4 0 0 0 24 22 V6 M4 14 A10 4 0 0 0 24 14" fill="none" stroke="${c}" stroke-width="2"/>`,
  empreinte: (c) => `<path d="M6 10 A9 9 0 0 1 22 10 M8 23 A12 12 0 0 1 7 16 A7 7 0 0 1 21 16 C21 19 20 21 19 23 M11 24 A10 10 0 0 1 10 16 A4 4 0 0 1 18 16 C18 19 17 21 15 24 M14 16 V20" fill="none" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>`,
  fichier: (c) => `<path d="M6 2 H17 L23 8 V26 H6 Z M17 2 V8 H23" fill="none" stroke="${c}" stroke-width="2" stroke-linejoin="round"/>`,
  phrase: (c) => `<rect x="2" y="8" width="24" height="12" rx="3" fill="none" stroke="${c}" stroke-width="2"/><path d="M7 14 H8 M12 14 H13 M17 14 H18 M22 14 H22.5" stroke="${c}" stroke-width="3" stroke-linecap="round"/>`,
};

const APP = { fond: '#000000', carte: '#131315', carte2: '#1D1D20', carte3: '#2A2A2E', trait: '#222226', texte: '#FFFFFF', second: '#8E8E93', discret: '#7E7E84', foret: '#228B22', serieFaite: '#12261A', minuteur: '#1E9BF0', muscle: '#E0393E', muscleRepos: '#5C6069', record: '#FFC857', feu: '#FF9A00' };

/// Un toucher : le doigt se pose, une onde s'ouvre.
function toucher(cx, cy, cycle, a) {
  return `<g opacity="0">${visible(cycle, a - 0.018, a + 0.012, 0.004)}
    <circle cx="${cx}" cy="${cy}" r="13" fill="#FFFFFF" fill-opacity="0.28" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="1.5"/>
  </g>
  <circle cx="${cx}" cy="${cy}" r="10" fill="none" stroke="#FFFFFF" stroke-width="2" opacity="0">
    ${fondu('opacity', cycle, [[0, 0], [a, 0], [a + 0.002, 0.8], [a + 0.035, 0], [1, 0]])}
    ${fondu('r', cycle, [[0, 10], [a, 10], [a + 0.035, 30], [1, 30]])}
  </circle>`;
}

let _frappes = 0;
/// Un texte qui se tape lettre à lettre, de [de] à [a].
function frappe(x, y, s, cycle, de, a, opts = {}) {
  const id = `frappe${_frappes++}`;
  const l = tr(s).length * (opts.taille || 14) * 0.62 + 6;
  return `<clipPath id="${id}"><rect x="${x - 2}" y="${y - 20}" height="28" width="0">
    ${fondu('width', cycle, [[0, 0], [de, 0], [a, l], [1, l]])}</rect></clipPath>
  <g clip-path="url(#${id})">${t(x, y, s, opts)}</g>`;
}

/// Un bouton en pilule.
const pilule = (x, y, l, h, texte, couleur, { plein = false, taille = 12.5 } = {}) =>
  `<rect x="${x}" y="${y}" width="${l}" height="${h}" rx="${h / 2}" fill="${plein ? couleur : couleur}" fill-opacity="${plein ? 1 : 0.1}" stroke="${couleur}" stroke-opacity="${plein ? 1 : 0.45}"/>
  ${t(x + l / 2, y + h / 2 + taille * 0.36, texte, { taille, couleur: plein ? '#000000' : couleur, poids: 800, ancre: 'middle' })}`;

/// Une pastille : des initiales dans un rond de couleur.
const pastille = (x, y, initiales, couleur) =>
  `<circle cx="${x}" cy="${y}" r="15" fill="${couleur}" fill-opacity="0.16" stroke="${couleur}" stroke-opacity="0.6"/>
  ${t(x, y + 4.5, initiales, { taille: 11, couleur, poids: 800, ancre: 'middle' })}`;

/// La vraie vignette d'un exercice, telle que l'application la montre : une
/// pose rangée dans docs/exercices/vignettes/, intégrée au SVG (un SVG
/// affiché en <img> ne peut pas aller chercher une image). L'image n'est
/// écrite qu'une fois par schéma, les suivantes la réutilisent. Rend null
/// si la pose n'est pas là : le schéma garde alors son dessin.
const VIGNETTES = path.join(__dirname, '..', 'exercices', 'vignettes');
let _photos = new Set();
function photo(nom, x, y, c, { rayon = 10, fond = APP.carte2 } = {}) {
  if (!fs.existsSync(VIGNETTES)) return null;
  const f = fs.readdirSync(VIGNETTES).sort().find((g) => g.replace(/\.[a-z]+$/, '') === nom);
  if (!f) return null;
  const id = `photo-${nom}`;
  let def = '';
  if (!_photos.has(id)) {
    _photos.add(id);
    const type = { webp: 'image/webp', png: 'image/png', jpg: 'image/jpeg' }[f.split('.').pop()];
    const donnees = fs.readFileSync(path.join(VIGNETTES, f)).toString('base64');
    def = `<defs><symbol id="${id}" viewBox="0 0 100 100"><image width="100" height="100" preserveAspectRatio="xMidYMid slice" href="data:${type};base64,${donnees}"/></symbol></defs>`;
  }
  return `${def}<rect x="${x}" y="${y}" width="${c}" height="${c}" rx="${rayon}" fill="${fond}"/><use href="#${id}" x="${x}" y="${y}" width="${c}" height="${c}"/>`;
}

// ------------------------------------------------------------------------
// Les autres schémas, un fichier chacun dans schemas/ : chaque module
// reçoit les outils de celui-ci et appelle svg() lui-même.
const OUTILS = {
  EN, tr, esc, svg, t, paliers, fondu, visible, carte, bille, fil, P, APP, toucher, frappe, pilule, pastille, photo,
  MONO, SANS, FOND, CARTE, BORD, TITRE, TEXTE, DISCRET, FIL, ACCENT, VERT, NEON, BLEU, OR, ROSE, ROUGE, INTERNE,
};
const DOSSIER = path.join(__dirname, 'schemas');
// Leurs traductions, à côté de chacun : <nom>.en.json. Un même mot peut se
// traduire autrement d'un schéma à l'autre (« Série » : « Set » dans la
// séance, « Streak » dans la flamme) : pendant qu'un module se dessine,
// son dictionnaire passe devant ceux des autres.
const DICO = require('./anglais.json');
const BASE = { ...DICO };
const DICOS = {};
for (const f of fs.existsSync(DOSSIER) ? fs.readdirSync(DOSSIER).filter((f) => f.endsWith('.en.json')) : []) {
  DICOS[f.replace(/\.en\.json$/, '')] = require(path.join(DOSSIER, f));
}
const dicoPour = (nom) => {
  for (const k of Object.keys(DICO)) delete DICO[k];
  Object.assign(DICO, ...Object.values(DICOS), BASE, DICOS[nom] || {});
};
// SEUL=seance,tests ne rend que ces schémas-là : pratique pendant qu'on en dessine un.
const SEUL = (process.env.SEUL || '').split(',').filter(Boolean);
for (const f of fs.existsSync(DOSSIER) ? fs.readdirSync(DOSSIER).filter((f) => f.endsWith('.js')).sort() : []) {
  if (SEUL.length && !SEUL.includes(f.replace(/\.js$/, ''))) continue;
  dicoPour(f.replace(/\.js$/, ''));
  _photos = new Set();
  require(path.join(DOSSIER, f))(OUTILS);
}

if (EN && manque.size) {
  console.error('  Absent de anglais.json :');
  for (const s of manque) console.error('    ' + s);
  process.exit(1);
}
if (!EN) {
  require('child_process').execFileSync(process.execPath, [__filename], { env: { ...process.env, LANGUE: 'en' }, stdio: 'inherit' });
}
