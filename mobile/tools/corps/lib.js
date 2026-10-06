// Moteur du générateur de personnage : courbes, miroir, repère du bras, rendu SVG, coloration.
// Principe : une surface continue. Chaque membre reçoit un seul dégradé cylindrique (bords sombres,
// centre clair), partagé par tous ses muscles ; un muscle ne varie que de quelques pour cent autour
// (bombé doux, ombre interne légère). Les limites sont rendues par l'ombre et par des traits blancs
// effilés qui s'arrêtent, jamais par une couture fermée autour de chaque pièce.
'use strict';

const CX = 200; // axe de symétrie
const W = 400, H = 860;

// Teintes du gris satiné (clair, moyen, sombre). Le widget Flutter remplace ces trois valeurs.
const GRIS = ['#D6D8DB', '#B3B6BB', '#7F838A'];
const NEUTRE = GRIS;
const COUTURE = '#F6F7F8';
const FOND = '#B9BCC0';
const NOIR = '#1A1C20';

const f = (n) => Math.round(n * 10) / 10;
const mx = (p) => [2 * CX - p[0], p[1], p[2]];
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

// Repère du bras droit de l'image : origine à l'épaule, u le long du bras, v vers l'extérieur.
const BRAS = { o: [292, 182], a: (14 * Math.PI) / 180 };
function P(u, v) {
  const s = Math.sin(BRAS.a), c = Math.cos(BRAS.a);
  return [BRAS.o[0] + v * c + u * s, BRAS.o[1] - v * s + u * c];
}
const arm = (pts) => pts.map(([u, v, k]) => { const p = P(u, v); return k ? [p[0], p[1], k] : p; });

// Segments de Bézier d'une courbe lissée (Catmull-Rom). Un point [x,y,'c'] est un angle vif.
function segments(pts, closed = true, tension = 1) {
  const n = pts.length, out = [];
  const last = closed ? n : n - 1;
  const at = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]);
  for (let i = 0; i < last; i++) {
    const p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    const k = tension / 6;
    let c1 = [p1[0] + (p2[0] - p0[0]) * k, p1[1] + (p2[1] - p0[1]) * k];
    let c2 = [p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k];
    if (p1[2] === 'c') c1 = lerp(p1, p2, 0.3);
    if (p2[2] === 'c') c2 = lerp(p2, p1, 0.3);
    out.push([p1, c1, c2, p2]);
  }
  return out;
}
function segPath(segs, closed) {
  let d = `M${f(segs[0][0][0])} ${f(segs[0][0][1])}`;
  for (const [, a, b, c] of segs) d += `C${f(a[0])} ${f(a[1])} ${f(b[0])} ${f(b[1])} ${f(c[0])} ${f(c[1])}`;
  return closed ? d + 'Z' : d;
}
const smoothClosed = (pts, tension = 1) => segPath(segments(pts, true, tension), true);
const smoothOpen = (pts) => segPath(segments(pts, false), false);

// Points régulièrement espacés le long d'une courbe (pas d'environ `pas` unités).
function echantillons(segs, pas = 1.5) {
  const out = [];
  for (const [p0, c1, c2, p3] of segs) {
    const len = Math.hypot(p3[0] - p0[0], p3[1] - p0[1]) + Math.hypot(c1[0] - p0[0], c1[1] - p0[1]) * 0.3;
    const n = Math.max(3, Math.ceil(len / pas));
    for (let i = 0; i < n; i++) {
      const t = i / n, u = 1 - t;
      out.push([
        u * u * u * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * p3[0],
        u * u * u * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * p3[1],
      ]);
    }
  }
  return out;
}

// Trait blanc effilé : une forme pleine dont la largeur suit un profil (fin aux extrémités).
// forme : 'deux' (effilé des deux côtés), 'debut' (fin au début), 'fin' (fin à la fin).
function effile(pts, w, forme = 'deux') {
  if (pts.length < 2) return '';
  const len = [0];
  for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
  const L = len[len.length - 1] || 1;
  const prof = (t) => {
    if (forme === 'debut') return Math.pow(Math.sin((Math.PI / 2) * t), 0.7);
    if (forme === 'fin') return Math.pow(Math.cos((Math.PI / 2) * t), 0.7);
    return Math.pow(Math.sin(Math.PI * t), 0.65);
  };
  const g = [], d = [];
  for (let i = 0; i < pts.length; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], n = Math.hypot(dx, dy) || 1;
    const nx = -dy / n, ny = dx / n, h = (w * prof(len[i] / L)) / 2;
    g.push([pts[i][0] + nx * h, pts[i][1] + ny * h]);
    d.push([pts[i][0] - nx * h, pts[i][1] - ny * h]);
  }
  const all = g.concat(d.reverse());
  return 'M' + all.map((p) => `${f(p[0])} ${f(p[1])}`).join('L') + 'Z';
}

// Portion d'un contour fermé entre deux fractions de sa longueur (t0 > t1 : on passe par le départ).
function portion(samples, t0, t1) {
  const n = samples.length;
  const i0 = Math.round(t0 * n), i1 = Math.round(t1 * n);
  const out = [];
  if (i1 >= i0) for (let i = i0; i <= i1; i++) out.push(samples[i % n]);
  else for (let i = i0; i <= i1 + n; i++) out.push(samples[i % n]);
  return out;
}

function symOutline(half) {
  const left = half.slice(1, -1).map(mx).reverse();
  return half.concat(left);
}

function ellipsePts(cx, cy, rx, ry, rot = 0, n = 10) {
  const out = [];
  const a = (rot * Math.PI) / 180;
  for (let i = 0; i < n; i++) {
    const t = (i / n) * Math.PI * 2;
    const x = Math.cos(t) * rx, y = Math.sin(t) * ry;
    out.push([cx + x * Math.cos(a) - y * Math.sin(a), cy + x * Math.sin(a) + y * Math.cos(a)]);
  }
  return out;
}

// Sillon d'ombre : trois traits sombres superposés, du plus large au plus fin, effilés aux bouts.
function sillon(g, mir) {
  const k = g.s2 ? ' class="s2"' : '';
  if (g.net) {
    const q = mir ? g.pts.map(mx) : g.pts;
    return `<path${k} d="${effile(echantillons(segments(q, false), 1), g.w, g.forme)}" fill="${NOIR}" fill-opacity="${g.op}"/>`;
  }
  const pts = mir ? g.pts.map(mx) : g.pts;
  const s = echantillons(segments(pts, false), 2.4);
  const w = g.w ?? 6, op = (g.op ?? 0.2) * 1.5;
  // Deux couches : un halo large et doux, un cœur plus étroit.
  return `<path${k} d="${effile(s, w * 2, g.forme)}" fill="${NOIR}" fill-opacity="${f(op * 38) / 100}"/>` +
    `<path${k} d="${effile(s, w * 0.8, g.forme)}" fill="${NOIR}" fill-opacity="${f(op * 62) / 100}"/>`;
}

// Construit le SVG complet.
// silhouette : [{ pts, centre }] contours fermés (miroir automatique sauf `centre`).
// regions : { nom: { a, b, r, clair } } axe du membre (a vers b), demi-largeur r, position du reflet (0..1).
// pieces : { m, pts, region, centre, tension, relief, ombre, lignes: [[t0, t1, w, forme, s2]], fibres, detail(mir), s2 }
// sillons : [{ pts, w, op, centre, forme }] ; traits : [{ pts, w, op, centre, forme, s2 }] (blancs, effilés).
function build({ silhouette, regions, pieces, sillons = [], traits = [] }) {
  let defs =
    // Bombé d'un muscle : centre plus clair, bord un peu plus sombre, par-dessus le dégradé du membre.
    `<radialGradient id="bombe" cx="0.42" cy="0.38" r="0.58"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.32"/>` +
    `<stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.07"/><stop offset="0.8" stop-color="${NOIR}" stop-opacity="0.1"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.2"/></radialGradient>` +
    // Chute de lumière verticale dans chaque muscle : haut éclairé, bas dans l'ombre.
    `<linearGradient id="chute" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.1"/>` +
    `<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.12"/></linearGradient>` +
    // Versions pour un muscle coloré : reflet discret, ombre de bord un peu plus franche, rouge presque uni.
    `<radialGradient id="bombeC" cx="0.42" cy="0.38" r="0.58"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.06"/>` +
    `<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="0.82" stop-color="${NOIR}" stop-opacity="0.06"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.16"/></radialGradient>` +
    // Reflet sans bord sombre, pour les bosses internes (blocs des abdominaux).
    `<radialGradient id="reflet" cx="0.45" cy="0.4" r="0.6"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.3"/><stop offset="0.6" stop-color="#FFFFFF" stop-opacity="0.08"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>` +
    `<linearGradient id="bloc" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.2"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.03"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.16"/></linearGradient>` +
    `<linearGradient id="blocC" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.05"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.14"/></linearGradient>` +
    `<radialGradient id="refletC" cx="0.45" cy="0.4" r="0.6"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.09"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>` +
    `<linearGradient id="chuteC" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.03"/>` +
    `<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="${NOIR}" stop-opacity="0.1"/></linearGradient>`;
  let body = '', lignes = '';
  let gid = 0, cid = 0;

  const cylindre = (id, reg, mir, cols) => {
    let a = reg.a, b = reg.b;
    if (mir) { a = mx(a); b = mx(b); }
    const dx = b[0] - a[0], dy = b[1] - a[1], n = Math.hypot(dx, dy) || 1;
    let nx = -dy / n, ny = dx / n;
    if (nx < 0 || (nx === 0 && ny < 0)) { nx = -nx; ny = -ny; }
    const m = lerp(a, b, 0.5), r = reg.r;
    // Lumière venue de la gauche de l'image : reflet décalé vers la gauche du membre.
    const c = reg.clair ?? 0.4;
    return `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${f(m[0] - nx * r)}" y1="${f(m[1] - ny * r)}" x2="${f(m[0] + nx * r)}" y2="${f(m[1] + ny * r)}">` +
      `<stop offset="0" stop-color="${cols[2]}"/><stop offset="${f(c * 45) / 100}" stop-color="${cols[1]}"/>` +
      `<stop offset="${c}" stop-color="${cols[0]}"/><stop offset="${f((c + (1 - c) * 0.55) * 100) / 100}" stop-color="${cols[1]}"/>` +
      `<stop offset="1" stop-color="${cols[2]}"/></linearGradient>`;
  };

  const trait = (pts, w, op = 0.9, forme = 'deux', s2 = false) =>
    `<path${s2 ? ' class="s2"' : ''} d="${effile(pts, w, forme)}" fill="${COUTURE}" fill-opacity="${op}"/>`;

  const renderPiece = (p, mir) => {
    const pts = mir ? p.pts.map(mx) : p.pts;
    const segs = segments(pts, true, p.tension ?? 1);
    const d = segPath(segs, true);
    const reg = regions[p.region];
    if (!reg) throw new Error(`région inconnue : ${p.region}`);
    const id = `g-${p.m || 'n'}-${gid++}`;
    defs += cylindre(id, reg, mir, p.m ? GRIS : NEUTRE);
    let s = `<path class="forme${p.m ? ' m-' + p.m : ''}" d="${d}" fill="url(#${id})"/>`;
    const relief = p.relief ?? 1, ombre = p.ombre ?? 0;
    if (relief > 0 || ombre > 0 || p.fibres || p.detail) {
      const cp = `c${cid++}`;
      defs += `<clipPath id="${cp}"><path d="${d}"/></clipPath>`;
      s += `<g clip-path="url(#${cp})">`;
      // Voiles du modelé ; la coloration les remplace par leur version pour la couleur (moins de blanc).
      const k = p.m ? ` class="vol m-${p.m}"` : '';
      if (relief > 0) s += `<path${k} fill="url(#chute)" d="${d}"/><path${k} fill="url(#bombe)" fill-opacity="${f(Math.min(1, relief) * 100) / 100}" d="${d}"/>`;
      if (ombre > 0) s += `<path d="${d}" fill="none" stroke="${NOIR}" stroke-opacity="${f(ombre * 5) / 100}" stroke-width="9"/>` +
        `<path d="${d}" fill="none" stroke="${NOIR}" stroke-opacity="${f(ombre * 5) / 100}" stroke-width="3.5"/>`;
      if (p.fibres) s += `<path class="fib" d="${fibres(p.fibres, mir)}" fill="none" stroke="#FFFFFF" stroke-opacity="${p.fop ?? 0.14}" stroke-width="0.5" stroke-linecap="round"/>`;
      if (p.detail) s += `<g class="det">${p.detail(mir)}</g>`;
      s += `</g>`;
    }
    // Bord blanc net, invisible tant que le muscle est gris : la coloration l'allume (comme les références).
    if (p.m && !p.sansBord) s += `<path class="bord m-${p.m}" stroke-opacity="0" d="${d}" fill="none" stroke="${COUTURE}" stroke-width="1.3" stroke-linejoin="round"/>`;
    if (p.lignes) {
      const smp = echantillons(segs, 1.2);
      for (const [t0, t1, w = 1.2, forme = 'deux', s2 = false] of p.lignes) lignes += trait(portion(smp, t0, t1), w, 0.92, forme, s2);
    }
    return s;
  };

  let last = null, buf = '';
  const flush = () => {
    if (last === null) return;
    body += last === 'neutre' ? `<g>${buf}</g>` : `<g id="${last}">${buf}</g>`;
    buf = '';
  };
  for (const p of pieces) {
    const key = p.m ? `m-${p.m}` : 'neutre';
    if (key !== last) { flush(); last = key; }
    for (const mir of p.centre ? [false] : [false, true]) buf += renderPiece(p, mir);
  }
  flush();
  // Un muscle réparti sur plusieurs couches : seul le premier groupe porte l'id, les suivants une classe.
  const seen = new Set();
  body = body.replace(/<g id="(m-[a-zA-Z]+)">/g, (all, id) => {
    if (seen.has(id)) return `<g class="${id}">`;
    seen.add(id);
    return all;
  });

  let ombres = '';
  for (const g of sillons) for (const mir of g.centre ? [false] : [false, true]) ombres += sillon(g, mir);
  for (const t of traits) {
    for (const mir of t.centre ? [false] : [false, true]) {
      const pts = mir ? t.pts.map(mx) : t.pts;
      lignes += trait(echantillons(segments(pts, false), 1.8), t.w ?? 1.1, t.op ?? 0.9, t.forme, t.s2);
    }
  }

  let silD = '';
  for (const s of silhouette) {
    silD += smoothClosed(s.pts, s.tension ?? 1);
    if (!s.centre) silD += smoothClosed(s.pts.map(mx).reverse(), s.tension ?? 1);
  }
  defs += `<clipPath id="silhouette"><path d="${silD}"/></clipPath>`;
  // Lumière d'ensemble : un voile clair en haut à gauche, à peine plus sombre en bas.
  defs += `<linearGradient id="voile" gradientUnits="userSpaceOnUse" x1="80" y1="60" x2="300" y2="840">` +
    `<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.07"/><stop offset="0.4" stop-color="#FFFFFF" stop-opacity="0"/>` +
    `<stop offset="1" stop-color="${NOIR}" stop-opacity="0.1"/></linearGradient>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">` +
    `<defs>${defs}</defs>` +
    `<path d="${silD}" fill="none" stroke="${COUTURE}" stroke-width="2.4" stroke-linejoin="round"/>` +
    `<g clip-path="url(#silhouette)"><path d="${silD}" fill="${FOND}"/>${body}${ombres}<path d="${silD}" fill="url(#voile)"/>${lignes}</g>` +
    `</svg>`;
}

// Fibres : lignes de l'origine (segment a) vers l'insertion (segment b), légèrement courbées.
function fibres(spec, mirror) {
  const out = [];
  for (const s of spec) {
    const n = s.n || 6;
    const A = s.a.map((p) => (mirror ? mx(p) : p)), B = s.b.map((p) => (mirror ? mx(p) : p));
    const bend = (s.bend || 0) * (mirror ? -1 : 1);
    for (let i = 0; i < n; i++) {
      const t = (i + 0.5) / n;
      const p = lerp(A[0], A[1], t), q = lerp(B[0], B[1], t);
      const m = lerp(p, q, 0.5);
      const dx = q[0] - p[0], dy = q[1] - p[1];
      const c = [m[0] - dy * bend, m[1] + dx * bend];
      const p2 = lerp(p, c, 0.3), q2 = lerp(q, c, 0.3);
      out.push(`M${f(p2[0])} ${f(p2[1])}Q${f(c[0])} ${f(c[1])} ${f(q2[0])} ${f(q2[1])}`);
    }
  }
  return out.join('');
}

// Coloration perceptuelle (OKLCH). Même calcul que `BodySvgRepository.shades()` et `tint()` côté Flutter.
function hex(c) { return [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16) / 255); }
function toHex(a) { return '#' + a.map((v) => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, '0').toUpperCase()).join(''); }
const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const gam = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055);
function toLch(h) {
  const [r, g, b] = hex(h).map(lin);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  return [L, Math.hypot(A, B), Math.atan2(B, A)];
}
function fromLch([L, C, h]) {
  const A = C * Math.cos(h), B = C * Math.sin(h);
  const l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s = (L - 0.0894841775 * A - 1.291485548 * B) ** 3;
  return toHex([
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ].map(gam));
}
// Trois teintes presque unies (reflet = la couleur, cœur un peu plus profond, ombre) : rouge plein et mat.
function shades(base) {
  const [L, C, h] = toLch(base);
  return [base.toUpperCase(), fromLch([L * 0.95, C, h]), fromLch([L * 0.83, C * 0.97, h])];
}
// Intensité partielle : même teinte et même luminosité, saturation réduite (jamais un gris assombri).
function tint(target, t) {
  if (t >= 1) return target;
  const [L, C, h] = toLch(target);
  return fromLch([L, C * (0.5 + 0.5 * t), h]);
}
function colorize(svg, intensities, highlight = '#E0393E') {
  const target = shades(highlight);
  const noms = Object.keys(intensities).filter((m) => intensities[m] > 0);
  let out = svg.replace(/<linearGradient id="g-([a-zA-Z]+)-\d+"[^>]*>.*?<\/linearGradient>/g, (block, m) => {
    const t = intensities[m];
    if (!t) return block;
    let o = block;
    GRIS.forEach((g, i) => { o = o.split(g).join(tint(target[i], Math.min(1, t))); });
    return o;
  });
  for (const m of noms) {
    out = out.split(`class="bord m-${m}" stroke-opacity="0"`).join(`class="bord m-${m}" stroke-opacity="0.9"`)
      .split(`class="vol m-${m}" fill="url(#bombe)"`).join(`class="vol m-${m}" fill="url(#bombeC)"`)
      .split(`class="vol m-${m}" fill="url(#chute)"`).join(`class="vol m-${m}" fill="url(#chuteC)"`)
      .split(`class="vol m-${m}" fill="url(#reflet)"`).join(`class="vol m-${m}" fill="url(#refletC)"`)
      .split(`class="vol m-${m}" fill="url(#bloc)"`).join(`class="vol m-${m}" fill="url(#blocC)"`);
  }
  return out;
}
// Variante petit format : sans fibres, détails ni traits secondaires.
const simplify = (svg) => svg.replace(/<path class="(?:fib|s2)"[^>]*\/>/g, '').replace(/<g class="det">.*?<\/g>/g, '');

module.exports = { CX, W, H, build, colorize, simplify, shades, smoothClosed, smoothOpen, symOutline, ellipsePts, mx, f, P, arm, lerp, GRIS, NEUTRE, COUTURE };
