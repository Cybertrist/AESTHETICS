// Composition : nettoyage des régions, coussins de volume, occlusion, fibres, coutures, masques.
import * as THREE from 'three';
import { GROUPES } from './reglages.js';
import { LUMIERE } from './lumiere.js';

const NOMS_GROUPES = GROUPES.map((g) => g[0]);

// Transformée de distance euclidienne exacte (Felzenszwalb) ; `f` : 1 sur les pixels source.
export function edt(f, W, H) {
  const INF = 1e20;
  const d = new Float32Array(W * H);
  for (let i = 0; i < W * H; i++) d[i] = f[i] ? 0 : INF;
  const n = Math.max(W, H);
  const z = new Float32Array(n + 1), v = new Int32Array(n), g = new Float32Array(n), o = new Float32Array(n);
  const passe = (len, get, set) => {
    for (let q = 0; q < len; q++) g[q] = get(q);
    let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
    for (let q = 1; q < len; q++) {
      let s = ((g[q] + q * q) - (g[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
      while (s <= z[k]) { k--; s = ((g[q] + q * q) - (g[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]); }
      k++; v[k] = q; z[k] = s; z[k + 1] = INF;
    }
    k = 0;
    for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; o[q] = (q - v[k]) * (q - v[k]) + g[v[k]]; }
    for (let q = 0; q < len; q++) set(q, o[q]);
  };
  for (let x = 0; x < W; x++) passe(H, (y) => d[y * W + x], (y, val) => { d[y * W + x] = val; });
  for (let y = 0; y < H; y++) passe(W, (x) => d[y * W + x], (x, val) => { d[y * W + x] = val; });
  for (let i = 0; i < W * H; i++) d[i] = Math.sqrt(d[i]);
  return d;
}

// Supprime les îlots trop petits (remplacés par la région voisine la plus présente).
function nettoyer(R, W, H, aireMin, dB = null, epMin = 0, enclaves = null) {
  const lab = new Int32Array(W * H).fill(-1);
  const pile = new Int32Array(W * H);
  let n = 0;
  for (let s = 0; s < W * H; s++) {
    if (lab[s] >= 0 || R[s] === 0) continue;
    const r = R[s];
    let top = 0, aire = 0, ep = 0; pile[top++] = s; lab[s] = n;
    const membres = [];
    const voisins = new Map();
    while (top) {
      const p = pile[--top]; aire++; membres.push(p);
      if (dB && dB[p] > ep) ep = dB[p];
      const x = p % W, y = (p / W) | 0;
      const vs = [x > 0 ? p - 1 : -1, x < W - 1 ? p + 1 : -1, y > 0 ? p - W : -1, y < H - 1 ? p + W : -1];
      for (const q of vs) {
        if (q < 0) continue;
        if (R[q] === r) { if (lab[q] < 0) { lab[q] = n; pile[top++] = q; } }
        else if (R[q] !== 0) voisins.set(R[q], (voisins.get(R[q]) || 0) + 1);
      }
    }
    // sous-couche entièrement entourée par un seul muscle (aponévrose) : rendue à ce muscle
    if (enclaves && enclaves.has(r) && voisins.size === 1 && !membres.some((p) => { const x = p % W, y = (p / W) | 0; return (x > 0 && !R[p - 1]) || (x < W - 1 && !R[p + 1]) || (y > 0 && !R[p - W]) || (y < H - 1 && !R[p + W]); })) { const [k] = voisins.keys(); for (const p of membres) R[p] = k; }
    else if ((aire < aireMin || (dB && ep < epMin)) && !voisins.size) { for (const p of membres) R[p] = 0; }
    else if ((aire < aireMin || (dB && ep < epMin)) && voisins.size) {
      let best = 0, bc = -1;
      for (const [k, c] of voisins) if (c > bc) { bc = c; best = k; }
      for (const p of membres) R[p] = best;
    }
    n++;
  }
}

// Filtre de majorité (lisse les bords des régions sans toucher à la silhouette).
function majorite(R, W, H, r, dBord) {
  const out = new Int32Array(R);
  const cpt = new Map();
  for (let y = r; y < H - r; y++) {
    for (let x = r; x < W - r; x++) {
      const p = y * W + x;
      if (!R[p]) continue;
      // rapide : si tout le voisinage en croix est identique, on garde
      if (dBord && dBord[p] > r) continue;
      cpt.clear();
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > r * r) continue;
        const v = R[p + dy * W + dx]; if (v) cpt.set(v, (cpt.get(v) || 0) + 1);
      }
      let best = R[p], bc = 0;
      for (const [k, c] of cpt) if (c > bc) { bc = c; best = k; }
      out[p] = best;
    }
  }
  R.set(out);
}

// Flou en boîte séparable, limité aux pixels de la même région (normales xyz et profondeur).
function flouRegion(geo, R, W, H, r) {
  if (r < 1) return;
  const tmp = new Float32Array(geo.length);
  const passe = (src, dst, dx, dy) => {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const p = y * W + x, lab = R[p];
      if (!lab) { for (let k = 0; k < 4; k++) dst[p * 4 + k] = src[p * 4 + k]; continue; }
      let a = 0, b = 0, cc = 0, d = 0, n = 0;
      for (let t = -r; t <= r; t++) {
        const xx = x + t * dx, yy = y + t * dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        const q = yy * W + xx;
        if (R[q] !== lab) continue;
        a += src[q * 4]; b += src[q * 4 + 1]; cc += src[q * 4 + 2]; d += src[q * 4 + 3]; n++;
      }
      dst[p * 4] = a / n; dst[p * 4 + 1] = b / n; dst[p * 4 + 2] = cc / n; dst[p * 4 + 3] = d / n;
    }
  };
  for (let it = 0; it < 2; it++) { passe(geo, tmp, 1, 0); passe(tmp, geo, 0, 1); }
}

const VS_PLEIN = `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

function texture(data, W, H) {
  const t = new THREE.DataTexture(data, W, H, THREE.RGBAFormat, THREE.FloatType);
  t.minFilter = t.magFilter = THREE.NearestFilter; t.needsUpdate = true; return t;
}

export function composer({ W, H, S, id, idProfond, geo, fib, vue, cadre, pxParMm, modele, renderer }) {
  const L = LUMIERE;
  const N = W * H;
  const objets = modele.objets;
  // 1. régions
  const R = new Int32Array(N);
  const regionGroupe = new Map();
  const regionPeau = new Set(), regionSous = new Set();
  for (let i = 0; i < N; i++) {
    const m = id[i * 4] + id[i * 4 + 1] * 256;
    if (!m) continue;
    const o = objets[m - 1];
    R[i] = o.region;
    if (o.groupe) regionGroupe.set(o.region, o.groupe);
    if (o.peau && !o.sousCouche) regionPeau.add(o.region);
    if (o.sousCouche) regionSous.add(o.region);
  }
  nettoyer(R, W, H, Math.round((L.ilotMm * pxParMm) ** 2));
  for (let k = 0; k < 3; k++) {
    const f = new Uint8Array(N);
    for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) { const p = y * W + x; if (R[p] !== R[p + 1] || R[p] !== R[p + W]) f[p] = f[p + 1] = f[p + W] = 1; }
    majorite(R, W, H, Math.max(1, Math.round(L.majoriteMm * pxParMm)), edt(f, W, H));
  }
  nettoyer(R, W, H, Math.round((L.ilotMm * pxParMm) ** 2), null, 0, regionSous);
  // ouverture de la silhouette : retire les lanières qui dépassent (tendons étirés)
  {
    const k = L.ouvertureMm * pxParMm;
    const hors = new Uint8Array(N); for (let i = 0; i < N; i++) hors[i] = R[i] ? 0 : 1;
    const dI = edt(hors, W, H);
    const coeur = new Uint8Array(N); for (let i = 0; i < N; i++) coeur[i] = dI[i] > k ? 1 : 0;
    const dC = edt(coeur, W, H);
    for (let i = 0; i < N; i++) if (R[i] && dC[i] > k + 0.5) R[i] = 0;
  }
  // 2. distances aux coutures et à la silhouette
  const bord = new Uint8Array(N), corps = new Uint8Array(N), dehors = new Uint8Array(N);
  const bords = () => {
    bord.fill(0); corps.fill(0); dehors.fill(0);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const p = y * W + x, r = R[p];
      if (!r) { dehors[p] = 1; continue; }
      corps[p] = 1;
      // couture entre deux muscles seulement (pas avec la peau ni le fond : la silhouette a son liseré)
      if (regionPeau.has(r)) continue;
      const diff = (q) => R[q] !== r && R[q] !== 0 && !regionPeau.has(R[q]);
      if ((x > 0 && diff(p - 1)) || (x < W - 1 && diff(p + 1)) || (y > 0 && diff(p - W)) || (y < H - 1 && diff(p + W))) bord[p] = 1;
    }
    return edt(bord, W, H);
  };
  // lanières trop fines : fondues dans la région voisine
  nettoyer(R, W, H, 0, bords(), L.epaisseurMinMm * pxParMm);
  const dB = bords();
  const dOut = edt(corps, W, H);
  const dIn = edt(dehors, W, H);
  // largeur des coussins par région
  const dmax = new Map();
  for (let i = 0; i < N; i++) if (R[i]) dmax.set(R[i], Math.max(dmax.get(R[i]) || 0, dB[i]));
  const t1 = new Float32Array(N * 4);
  for (let i = 0; i < N; i++) {
    const r = R[i];
    if (!r) { t1[i * 4 + 1] = 0; t1[i * 4 + 2] = dOut[i]; continue; }
    const peau = regionPeau.has(r);
    const w = Math.min(L.coussinMaxMm * pxParMm, Math.max(L.coussinMinMm * pxParMm, L.coussinPart * dmax.get(r)));
    const h = peau ? 0 : w * (1 - Math.exp(-dB[i] / w)) * L.coussinHauteur;
    t1[i * 4] = h;
    t1[i * 4 + 1] = dB[i];
    t1[i * 4 + 2] = -dIn[i];
    t1[i * 4 + 3] = peau || regionSous.has(r) ? 2 : 1;
  }
  // coussins arrondis : la hauteur (issue de la distance aux coutures) est floutée dans sa région
  {
    const tmp = new Float32Array(N * 4);
    for (let i = 0; i < N; i++) tmp[i * 4] = t1[i * 4];
    for (let k = 0; k < L.coussinFlouPasses; k++) flouRegion(tmp, R, W, H, Math.round(L.coussinFlouMm * pxParMm));
    for (let i = 0; i < N; i++) if (R[i]) t1[i * 4] = tmp[i * 4];
  }
  // normales et profondeur adoucies à l intérieur de chaque région (efface les plis du maillage)
  flouRegion(geo, R, W, H, Math.round(L.flouMm * pxParMm));
  // 3. ombrage sur le GPU
  const tGeo = texture(geo, W, H), tT1 = texture(t1, W, H), tFib = texture(fib, W, H);
  const mat = new THREE.ShaderMaterial({
    vertexShader: VS_PLEIN,
    fragmentShader: FS_OMBRE,
    uniforms: {
      tGeo: { value: tGeo }, tT1: { value: tT1 }, tFib: { value: tFib },
      px: { value: new THREE.Vector2(1 / W, 1 / H) },
      pxParMm: { value: pxParMm }, S: { value: S }, traitCadre: { value: cadre.trait ?? 1 }, fibreCadre: { value: cadre.fibre ?? 1 }, pasFibre: { value: Math.max(L.fibrePasMm, L.fibrePasPx * S / pxParMm) },
      vueDos: { value: vue === 'dos' ? 1 : 0 },
      ...Object.fromEntries(Object.entries(L.shader).map(([k, v]) => [k, { value: Array.isArray(v) ? new THREE.Vector3(...v) : v }])),
    },
    depthTest: false, depthWrite: false,
  });
  const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
  const sc = new THREE.Scene(); sc.add(quad);
  const cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const rt = new THREE.WebGLRenderTarget(W, H, { type: THREE.UnsignedByteType });
  const out = new Uint8Array(N * 4);
  mat.uniforms.mode = { value: 0 };
  renderer.setRenderTarget(rt); renderer.setClearColor(0, 0); renderer.clear(); renderer.render(sc, cam);
  renderer.readRenderTargetPixels(rt, 0, 0, W, H, out);
  // couche des coutures seules (blanc, alpha)
  mat.uniforms.mode.value = 1;
  renderer.clear(); renderer.render(sc, cam);
  const traits = new Uint8Array(N * 4);
  renderer.readRenderTargetPixels(rt, 0, 0, W, H, traits);
  renderer.setRenderTarget(null);
  rt.dispose(); tGeo.dispose(); tT1.dispose(); tFib.dispose(); mat.dispose();

  // 4. réduction et images
  const w = W / S, h = H / S;
  const base = reduire(out, W, H, S, true);
  const couche = reduire(traits, W, H, S, true);
  const masques = {};
  const G = new Int8Array(N).fill(-1), GP = new Int8Array(N).fill(-1); // GP : muscles profonds, vus à travers (masques qui se chevauchent)
  for (let i = 0; i < N; i++) {
    const g = regionGroupe.get(R[i]);
    if (g) G[i] = NOMS_GROUPES.indexOf(g);
    // muscles profonds (rhomboïdes) : silhouette vue à travers
    const mp = idProfond[i * 4] + idProfond[i * 4 + 1] * 256;
    if (mp && R[i] && vue === 'dos') GP[i] = NOMS_GROUPES.indexOf(objets[mp - 1].groupe);
  }
  for (let gi = 0; gi < NOMS_GROUPES.length; gi++) {
    const a = new Float32Array(w * h);
    let total = 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (G[y * W + x] === gi || GP[y * W + x] === gi) { a[(h - 1 - ((y / S) | 0)) * w + ((x / S) | 0)] += 1 / (S * S); total++; }
    }
    if (total / (S * S) < L.masqueMinPx) continue;
    const img = new Uint8ClampedArray(w * h * 4);
    for (let i = 0; i < w * h; i++) { img[i * 4] = img[i * 4 + 1] = img[i * 4 + 2] = 255; img[i * 4 + 3] = Math.round(a[i] * 255); }
    masques[NOMS_GROUPES[gi]] = versPng(img, w, h);
  }
  const aires = new Map(); for (let i = 0; i < N; i++) if (R[i]) aires.set(R[i], (aires.get(R[i]) || 0) + 1);
  const stats = [...aires].sort((a, b) => b[1] - a[1]).slice(0, 12).map(([r, n]) => modele.regions[r - 1] + " " + n);
  const points = (window.DEBUG_POINTS || []).map(([fx, fy]) => { const x = Math.round(fx * W), y = Math.round((1 - fy) * H); const r = R[y * W + x]; return r ? modele.regions[r - 1] : "fond"; });
  let carte = null;
  if (window.DEBUG_REGIONS) {
    const im = new Uint8ClampedArray(N * 4);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const i = y * W + x, q = ((H - 1 - y) * W + x) * 4, r = R[i]; if (!r) continue; const g = regionGroupe.get(r); im[q] = (r * 97) % 255; im[q + 1] = (r * 57) % 255; im[q + 2] = g ? 255 : 0; im[q + 3] = 255; }
    carte = versPng(im, W, H).url;
  }
  return { points, carte, stats, base: versPng(base, w, h), traits: versPng(couche, w, h), masques, largeur: w, hauteur: h };
}

// Réduction SxS en alpha prémultiplié ; retourne des lignes de haut en bas.
function reduire(src, W, H, S, retourner) {
  const w = W / S, h = H / S;
  const out = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let dy = 0; dy < S; dy++) for (let dx = 0; dx < S; dx++) {
      const p = ((y * S + dy) * W + x * S + dx) * 4;
      const al = src[p + 3] / 255;
      r += src[p] * al; g += src[p + 1] * al; b += src[p + 2] * al; a += al;
    }
    const yy = retourner ? h - 1 - y : y;
    const q = (yy * w + x) * 4;
    if (a > 0) { out[q] = r / a; out[q + 1] = g / a; out[q + 2] = b / a; }
    out[q + 3] = Math.round(a / (S * S) * 255);
  }
  return out;
}

function versPng(rgba, w, h) {
  // les masques sont calculés de bas en haut : on retourne ici aussi
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d');
  const id = new ImageData(rgba, w, h);
  g.putImageData(id, 0, 0);
  return { url: c.toDataURL('image/png'), canvas: c };
}

const FS_OMBRE = /* glsl */`
  uniform sampler2D tGeo, tT1, tFib;
  uniform vec2 px; uniform float pxParMm, S, vueDos, pasFibre, traitCadre, fibreCadre; uniform int mode;
  uniform vec3 lumiere1, lumiere2; uniform float fort1, fort2, ambiant, albedo, satin, satinExp,
    coussinPente, aoForce, aoRayonMm, fibreForce, traitMm, traitForce, bordMm, gamma, ombreBord, rimForce;
  varying vec2 vUv;

  float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
  float bruit(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }

  void main(){
    vec4 g = texture2D(tGeo, vUv);
    vec4 t = texture2D(tT1, vUv);
    float lw = max(traitMm * pxParMm, 0.9 * S);
    if (t.w < 0.5) {
      // dehors : liseré clair autour de la silhouette
      float a = (1.0 - smoothstep(lw * 0.6, lw * 1.4, t.z)) * rimForce;
      gl_FragColor = vec4(vec3(0.96), a);
      return;
    }
    if (mode == 1) {
      float a = (1.0 - smoothstep(lw * 0.5, lw * 1.2, t.y)) * traitForce * traitCadre;
      gl_FragColor = vec4(vec3(0.97), a);
      return;
    }
    // normale : géométrie + coussin de chaque muscle
    float hx = texture2D(tT1, vUv + vec2(px.x, 0.0)).x - texture2D(tT1, vUv - vec2(px.x, 0.0)).x;
    float hy = texture2D(tT1, vUv + vec2(0.0, px.y)).x - texture2D(tT1, vUv - vec2(0.0, px.y)).x;
    vec3 n = normalize(g.xyz);
    n = normalize(vec3(n.xy - coussinPente * vec2(hx, hy) * 0.5, n.z));
    // occlusion ambiante (horizon, en mm de profondeur)
    float d0 = g.w, occ = 0.0, tot = 0.0;
    for (int i = 0; i < 12; i++) {
      float an = float(i) * 0.5236 + hash(vUv * 931.0) * 0.5;
      vec2 dir = vec2(cos(an), sin(an));
      for (int k = 1; k <= 4; k++) {
        float rmm = aoRayonMm * float(k) / 4.0;
        vec2 o = dir * rmm * pxParMm * px;
        vec4 q = texture2D(tGeo, vUv + o);
        float dq = q.w > 0.0 ? q.w : d0 + 1000.0;
        float hgt = (d0 - dq) / rmm;
        occ += clamp(hgt, 0.0, 1.0) * (1.0 - float(k) / 5.0);
        tot += 1.0 - float(k) / 5.0;
      }
    }
    float ao = 1.0 - aoForce * occ / tot;
    // lumière douce du haut et de face, satin
    vec3 l1 = normalize(lumiere1), l2 = normalize(lumiere2);
    float w = 0.35;
    float d1 = max(0.0, (dot(n, l1) + w) / (1.0 + w));
    float d2 = max(0.0, (dot(n, l2) + w) / (1.0 + w));
    vec3 hv = normalize(l1 + vec3(0.0, 0.0, 1.0));
    float sp = pow(max(dot(n, hv), 0.0), satinExp) * satin;
    // fibres
    vec4 f = texture2D(tFib, vUv);
    float fib = 0.0;
    if (t.w < 1.5) {
      float u = f.x / pasFibre + 0.8 * bruit(vec2(f.x * 0.08, f.y * 0.015));
      float fl = abs(fract(u) - 0.5) * 2.0;
      float ligne = smoothstep(0.7, 0.97, fl);
      float id = floor(u);
      float var = smoothstep(0.35, 0.8, hash(vec2(id, 7.0))) * smoothstep(0.25, 0.6, bruit(vec2(id * 3.1, f.y / (pasFibre * 6.0))));
      fib = ligne * var;
    }
    float bordOmbre = 1.0 - ombreBord * exp(-t.y / (2.5 * pxParMm));
    float val = albedo * (ambiant * ao + fort1 * d1 * mix(1.0, ao, 0.5) + fort2 * d2) * bordOmbre;
    val += sp * ao;
    val += fibreForce * fibreCadre * fib * (0.6 + 0.4 * d1);
    val = pow(clamp(val, 0.0, 1.0), gamma);
    // couture claire
    float a = (1.0 - smoothstep(lw * 0.5, lw * 1.2, t.y)) * traitForce * traitCadre;
    val = mix(val, 0.97, a);
    // liseré intérieur clair le long de la silhouette
    float rim = (1.0 - smoothstep(lw * 0.4, lw * 1.1, -t.z)) * rimForce;
    val = mix(val, 0.96, rim);
    gl_FragColor = vec4(vec3(val), 1.0);
  }`;
