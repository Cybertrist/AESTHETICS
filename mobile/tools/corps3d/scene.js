// Rendu du personnage ÆSTHETIC à partir des maillages BodyParts3D / Z-Anatomy.
// Étapes : chargement, tri des muscles, déformation (physique sec et musclé),
// passes 3D (identifiant, normale et profondeur, fibres), puis composition en image.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { mergeVertices, mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { MeshBVH } from 'three-mesh-bvh';
import { REGLAGES, GROUPES, EXCLUS, FUSIONS, EVENTAILS } from './reglages.js';
import { composer } from './compo.js';

const renderer = new THREE.WebGLRenderer({ antialias: false, preserveDrawingBuffer: true, alpha: true });
renderer.setPixelRatio(1);
document.body.appendChild(renderer.domElement);

const nom = (s) => s.replace(/_/g, ' ').replace(/\s+/g, ' ').trim();

// ---------- Chargement ----------
async function charger() {
  const l = new GLTFLoader();
  l.setMeshoptDecoder(MeshoptDecoder);
  const g = await l.loadAsync('/tools/corps3d/cache/anatomy.glb');
  g.scene.updateMatrixWorld(true);
  const muscles = [];
  g.scene.traverse((o) => {
    if (!o.isMesh) return;
    const n = nom(o.name || o.parent?.name || '');
    const geo = o.geometry.clone();
    for (const k of Object.keys(geo.attributes)) if (k !== 'position') geo.deleteAttribute(k);
    // positions quantifiées : repasser en flottants
    const p = geo.attributes.position;
    const f = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) { f[i * 3] = p.getX(i); f[i * 3 + 1] = p.getY(i); f[i * 3 + 2] = p.getZ(i); }
    geo.setAttribute('position', new THREE.BufferAttribute(f, 3));
    geo.applyMatrix4(o.matrixWorld);
    muscles.push({ nom: n, geo });
  });
  const peau = await new OBJLoader().loadAsync('/tools/corps3d/cache/peau.obj');
  let geoPeau;
  peau.traverse((o) => { if (o.isMesh) geoPeau = o.geometry; });
  return { muscles, geoPeau };
}

// ---------- Outils géométriques ----------
function souder(geo) {
  const g = geo.index ? geo.toNonIndexed() : geo;
  for (const k of Object.keys(g.attributes)) if (k !== "position") g.deleteAttribute(k);
  const m = mergeVertices(g, 1e-3);
  // orientation : normales vers l extérieur (volume signé positif)
  const p = m.attributes.position.array, ix = m.index.array;
  let vol = 0;
  for (let i = 0; i < ix.length; i += 3) {
    const a = ix[i] * 3, b = ix[i + 1] * 3, c = ix[i + 2] * 3;
    vol += p[a] * (p[b + 1] * p[c + 2] - p[b + 2] * p[c + 1]) - p[a + 1] * (p[b] * p[c + 2] - p[b + 2] * p[c]) + p[a + 2] * (p[b] * p[c + 1] - p[b + 1] * p[c]);
  }
  if (vol < 0) for (let i = 0; i < ix.length; i += 3) { const t = ix[i + 1]; ix[i + 1] = ix[i + 2]; ix[i + 2] = t; }
  m.computeVertexNormals();
  return m;
}

function voisins(geo) {
  const n = geo.attributes.position.count;
  const idx = geo.index.array;
  const v = Array.from({ length: n }, () => new Set());
  for (let i = 0; i < idx.length; i += 3) {
    const a = idx[i], b = idx[i + 1], c = idx[i + 2];
    v[a].add(b); v[a].add(c); v[b].add(a); v[b].add(c); v[c].add(a); v[c].add(b);
  }
  return v.map((s) => Uint32Array.from(s));
}

// Lissage de Taubin pondéré (poids 0..1 par sommet).
function lisser(geo, poids, iterations, lambda = 0.5, mu = -0.53) {
  const pos = geo.attributes.position.array;
  const vois = voisins(geo);
  const n = vois.length;
  const tmp = new Float32Array(pos.length);
  const pas = (k) => {
    for (let i = 0; i < n; i++) {
      const w = poids[i] * k;
      const vs = vois[i];
      if (!w || !vs.length) { tmp[i * 3] = pos[i * 3]; tmp[i * 3 + 1] = pos[i * 3 + 1]; tmp[i * 3 + 2] = pos[i * 3 + 2]; continue; }
      let x = 0, y = 0, z = 0;
      for (const j of vs) { x += pos[j * 3]; y += pos[j * 3 + 1]; z += pos[j * 3 + 2]; }
      x /= vs.length; y /= vs.length; z /= vs.length;
      tmp[i * 3] = pos[i * 3] + w * (x - pos[i * 3]);
      tmp[i * 3 + 1] = pos[i * 3 + 1] + w * (y - pos[i * 3 + 1]);
      tmp[i * 3 + 2] = pos[i * 3 + 2] + w * (z - pos[i * 3 + 2]);
    }
    pos.set(tmp);
  };
  for (let it = 0; it < iterations; it++) { pas(lambda); pas(mu); }
  geo.attributes.position.needsUpdate = true;
  geo.computeVertexNormals();
}

// La peau est une coque (surfaces externe et interne) : on ne garde que les triangles
// visibles depuis l extérieur, rendus d identifiant sous de nombreuses directions.
function garderVisible(geo) {
  const ix = geo.index.array;
  const nt = ix.length / 3;
  const pos = geo.attributes.position.array;
  const nonIdx = new Float32Array(nt * 9), col = new Float32Array(nt * 9);
  for (let t = 0; t < nt; t++) {
    const id = t + 1;
    const c = [(id & 255) / 255, ((id >> 8) & 255) / 255, ((id >> 16) & 255) / 255];
    for (let k = 0; k < 3; k++) {
      const v = ix[t * 3 + k];
      nonIdx.set([pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]], t * 9 + k * 3);
      col.set(c, t * 9 + k * 3);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.BufferAttribute(nonIdx, 3));
  g.setAttribute("color", new THREE.BufferAttribute(col, 3));
  const mat = new THREE.ShaderMaterial({
    vertexShader: "attribute vec3 color; varying vec3 c; void main(){ c = color; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
    fragmentShader: "varying vec3 c; void main(){ gl_FragColor = vec4(c, 1.0); }",
    side: THREE.DoubleSide,
  });
  const scene = new THREE.Scene();
  const mesh = new THREE.Mesh(g, mat); mesh.frustumCulled = false; scene.add(mesh);
  const T = 2048;
  const rt = new THREE.WebGLRenderTarget(T, T);
  const buf = new Uint8Array(T * T * 4);
  const vu = new Uint8Array(nt + 1);
  g.computeBoundingSphere();
  const bs = g.boundingSphere;
  const dirs = [];
  const K = 64;
  for (let i = 0; i < K; i++) {
    const y = 1 - (i + 0.5) / K * 2, r = Math.sqrt(1 - y * y), a = i * 2.39996;
    dirs.push(new THREE.Vector3(Math.cos(a) * r, Math.sin(a) * r, y));
  }
  for (const d of dirs) {
    const cam = new THREE.OrthographicCamera(-bs.radius, bs.radius, bs.radius, -bs.radius, 1, bs.radius * 4);
    cam.position.copy(bs.center).addScaledVector(d, bs.radius * 2);
    cam.up.set(Math.abs(d.z) > 0.9 ? 1 : 0, 0, Math.abs(d.z) > 0.9 ? 0 : 1);
    cam.lookAt(bs.center);
    renderer.setRenderTarget(rt); renderer.setClearColor(0, 0); renderer.clear(); renderer.render(scene, cam);
    renderer.readRenderTargetPixels(rt, 0, 0, T, T, buf);
    for (let i = 0; i < T * T; i++) { const id = buf[i * 4] | (buf[i * 4 + 1] << 8) | (buf[i * 4 + 2] << 16); if (id) vu[id] = 1; }
  }
  renderer.setRenderTarget(null); rt.dispose(); g.dispose(); mat.dispose();
  const garde = [];
  for (let t = 0; t < nt; t++) if (vu[t + 1]) garde.push(ix[t * 3], ix[t * 3 + 1], ix[t * 3 + 2]);
  console.log("peau : triangles visibles", garde.length / 3, "sur", nt);
  geo.setIndex(garde);
  geo.computeVertexNormals();
}

const lisse = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const bosse = (x, c, r) => { const d = Math.abs(x - c) / r; return d >= 1 ? 0 : 0.5 + 0.5 * Math.cos(Math.PI * d); };

// Champ de déformation commun à tous les maillages (muscles et peau) : proportions esthétiques.
function deformer(v, estBras) {
  const R = REGLAGES.forme;
  let { x, y, z } = v;
  const ax = Math.abs(x);
  // bras : écartement autour de l'épaule (rotation dans le plan frontal), sommets du bras seulement
  const bras = estBras * lisse(R.epauleZ + 40, R.epauleZ - 40, z);
  // bras plus épais autour de leur axe
  if (estBras > 0) {
    const e = estBras * lisse(R.epauleZ + 20, R.epauleZ - 80, z) * R.brasEpais;
    const axx = Math.sign(x) * (185 + Math.max(0, R.epauleZ - z) * 0.14);
    x = axx + (x - axx) * (1 + e); y = R.brasY + (y - R.brasY) * (1 + e);
  }
  if (bras > 0 && R.abduction) {
    const a = R.abduction * bras * Math.PI / 180;
    const s = Math.sign(x), c = Math.cos(a), sn = Math.sin(a);
    const dx = x - s * R.epauleX, dz = z - R.epauleZ;
    x = s * R.epauleX + dx * c - s * dz * sn;
    z = R.epauleZ + dz * c + s * dx * sn;
  }
  // épaules plus larges, taille plus fine
  const haut = bosse(z, R.epauleZ - 20, 260);
  x *= 1 + R.epaules * haut * lisse(60, 170, ax);
  const taille = bosse(z, R.tailleZ, 170) * lisse(215, 150, ax);
  x *= 1 - R.taille * taille * (1 - estBras);
  // cou plus large
  const cou = bosse(z, R.couZ, 110) * lisse(110, 60, Math.abs(x));
  x *= 1 + R.cou * cou; y = R.couY + (y - R.couY) * (1 + R.cou * 0.6 * cou);
  // jambes plus épaisses autour de leur propre axe
  const jambe = lisse(R.jambeZ, R.jambeZ - 120, z) * lisse(20, 45, Math.abs(x)) * (1 - estBras);
  if (jambe > 0) {
    const cx = Math.sign(x) * (80 + Math.max(0, z) / 900 * 25);
    x = cx + (x - cx) * (1 + R.jambes * jambe);
    y = R.jambeY + (y - R.jambeY) * (1 + R.jambes * 0.6 * jambe);
  }
  return { x, y, z };
}

function appliquerForme(geo, bras) {
  const p = geo.attributes.position.array;
  for (let i = 0; i < p.length; i += 3) {
    const r = deformer({ x: p[i], y: p[i + 1], z: p[i + 2] }, typeof bras === "number" ? bras : bras[i / 3]);
    p[i] = r.x; p[i + 1] = r.y; p[i + 2] = r.z;
  }
  geo.attributes.position.needsUpdate = true;
  geo.computeVertexNormals();
}

function gonfler(geo, mm) {
  if (!mm) return;
  const p = geo.attributes.position.array, n = geo.attributes.normal.array;
  for (let i = 0; i < p.length; i++) p[i] += n[i] * mm;
  geo.attributes.position.needsUpdate = true;
  geo.computeVertexNormals();
}

// Retire les triangles dont le centre vérifie `test`.
function couper(geo, test) {
  const ix = geo.index.array, p = geo.attributes.position.array;
  const garde = [];
  for (let i = 0; i < ix.length; i += 3) {
    let x = 0, y = 0, z = 0;
    for (let k = 0; k < 3; k++) { x += p[ix[i + k] * 3] / 3; y += p[ix[i + k] * 3 + 1] / 3; z += p[ix[i + k] * 3 + 2] / 3; }
    if (!test(x, y, z)) garde.push(ix[i], ix[i + 1], ix[i + 2]);
  }
  geo.setIndex(garde);
  geo.computeVertexNormals();
}

// Coordonnées de fibres par sommet : (travers, long) en mm.
function fibres(geo, nomMuscle) {
  const p = geo.attributes.position.array;
  const n = p.length / 3;
  const c = new THREE.Vector3();
  for (let i = 0; i < n; i++) c.add(new THREE.Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]));
  c.divideScalar(n);
  // ACP
  const C = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (let i = 0; i < n; i++) {
    const d = [p[i * 3] - c.x, p[i * 3 + 1] - c.y, p[i * 3 + 2] - c.z];
    for (let a = 0; a < 3; a++) for (let b = 0; b < 3; b++) C[a * 3 + b] += d[a] * d[b];
  }
  const axes = pca(C);
  const out = new Float32Array(n * 2);
  const ev = EVENTAILS.find(([re]) => re.test(nomMuscle));
  if (ev) {
    // éventail : les fibres convergent vers un point d'insertion
    const apex = trouverApex(p, n, ev[1]);
    const a2 = axes[0], a3 = axes[1];
    for (let i = 0; i < n; i++) {
      const d = new THREE.Vector3(p[i * 3] - apex.x, p[i * 3 + 1] - apex.y, p[i * 3 + 2] - apex.z);
      const r = d.length();
      const ang = Math.atan2(d.dot(a3), d.dot(a2));
      out[i * 2] = ang * 180; // environ 3 mm par fibre à 180 mm du point
      out[i * 2 + 1] = r;
    }
  } else {
    const a1 = axes[0], a2 = axes[1], a3 = axes[2];
    let rm = 0;
    for (let i = 0; i < n; i++) {
      const d = new THREE.Vector3(p[i * 3] - c.x, p[i * 3 + 1] - c.y, p[i * 3 + 2] - c.z);
      rm += Math.hypot(d.dot(a2), d.dot(a3));
    }
    rm = Math.max(8, rm / n);
    for (let i = 0; i < n; i++) {
      const d = new THREE.Vector3(p[i * 3] - c.x, p[i * 3 + 1] - c.y, p[i * 3 + 2] - c.z);
      out[i * 2] = Math.atan2(d.dot(a3), d.dot(a2)) * rm;
      out[i * 2 + 1] = d.dot(a1);
    }
  }
  geo.setAttribute('fibre', new THREE.BufferAttribute(out, 2));
}

function trouverApex(p, n, mode) {
  let best = -Infinity, k = 0;
  for (let i = 0; i < n; i++) {
    const x = p[i * 3], z = p[i * 3 + 2];
    const s = mode === 'lateral' ? Math.abs(x) : mode === 'bas' ? -z : mode === 'hautLateral' ? Math.abs(x) + z * 0.6 : 0;
    if (s > best) { best = s; k = i; }
  }
  return new THREE.Vector3(p[k * 3], p[k * 3 + 1], p[k * 3 + 2]);
}

function pca(C) {
  // itération de puissance avec déflation
  const M = C.slice();
  const res = [];
  for (let k = 0; k < 3; k++) {
    let v = new THREE.Vector3(Math.random(), Math.random(), Math.random()).normalize();
    for (let it = 0; it < 60; it++) {
      const w = new THREE.Vector3(
        M[0] * v.x + M[1] * v.y + M[2] * v.z,
        M[3] * v.x + M[4] * v.y + M[5] * v.z,
        M[6] * v.x + M[7] * v.y + M[8] * v.z);
      for (const r of res) w.addScaledVector(r, -w.dot(r));
      if (w.lengthSq() < 1e-12) break;
      v = w.normalize();
    }
    res.push(v);
  }
  return res;
}

// ---------- Construction de la scène ----------
let MODELE = null;

function groupeDe(n) {
  for (const [g, re] of GROUPES) if (re.test(n)) return g;
  return null;
}

async function preparer() {
  const { muscles, geoPeau } = await charger();
  const objets = [];
  const regionsParNom = new Map();
  const bruts = [];
  for (const m of muscles) {
    if (EXCLUS.some((re) => re.test(m.nom))) continue;
    const geo = souder(m.geo);
    if (/latissimus dorsi/.test(m.nom)) couper(geo, (x, y, z) => Math.abs(x) < REGLAGES.dorsalMedial(z) || (Math.abs(x) > REGLAGES.dorsalLateralX && z > 1150));
    if (/external oblique/.test(m.nom)) couper(geo, (x, y, z) => Math.abs(x) < REGLAGES.obliqueX && y < -40);
    lisser(geo, new Float32Array(geo.attributes.position.count).fill(1), REGLAGES.lissageMuscles);
    bruts.push({ m, geo, bras: REGLAGES.bras.test(m.nom) ? 1 : 0 });
  }
  // peau : tête, mains et pieds visibles, reste en sous-couche rentrée (comble les trous)
  const P = REGLAGES.peau;
  const peau = souder(geoPeau);
  garderVisible(peau);
  // chaque sommet de peau suit le muscle le plus proche (bras ou tronc)
  const brasPeau = new Float32Array(peau.attributes.position.count);
  {
    const geos = bruts.map((b) => { const g = new THREE.BufferGeometry(); g.setAttribute("position", b.geo.attributes.position); g.setIndex(b.geo.index); return g; });
    // drapeau par sommet (le BVH réordonne les triangles, pas les sommets)
    const drap = [];
    bruts.forEach((b) => { for (let k = 0; k < b.geo.attributes.position.count; k++) drap.push(b.bras); });
    const fus = mergeGeometries(geos);
    const bvh0 = new MeshBVH(fus);
    const p = peau.attributes.position.array, v = new THREE.Vector3();
    const utilises = new Uint8Array(brasPeau.length);
    for (const i of peau.index.array) utilises[i] = 1;
    for (let i = 0; i < brasPeau.length; i++) {
      if (!utilises[i]) continue;
      v.set(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
      const h = bvh0.closestPointToPoint(v);
      brasPeau[i] = h ? drap[fus.index.array[h.faceIndex * 3]] : 0;
    }
    // mains : toujours bras
    for (let i = 0; i < brasPeau.length; i++) if (p[i * 3 + 2] < P.mainZ && Math.abs(p[i * 3]) > P.mainX) brasPeau[i] = 1;
    const vois = voisins(peau);
    // triangles à cheval entre bras et tronc : retirés (sinon une membrane se tend à l aisselle)
    { const ix = peau.index.array, g = []; for (let t = 0; t < ix.length; t += 3) { const a = brasPeau[ix[t]], b = brasPeau[ix[t + 1]], c = brasPeau[ix[t + 2]]; const zc = peau.attributes.position.array[ix[t] * 3 + 2]; if ((a === b && b === c) || zc < 1000) g.push(ix[t], ix[t + 1], ix[t + 2]); } peau.setIndex(g); peau.computeVertexNormals(); }
    for (let it = 0; it < 0; it++) { const b2 = brasPeau.slice(); for (let i = 0; i < b2.length; i++) { const vs = vois[i]; if (!vs.length) continue; let m = 0; for (const j of vs) m += brasPeau[j]; b2[i] = 0.5 * brasPeau[i] + 0.5 * m / vs.length; } brasPeau.set(b2); }
  }
  appliquerForme(peau, brasPeau);
  for (const { m, geo, bras } of bruts) {
    appliquerForme(geo, bras);
    const g = groupeDe(m.nom);
    const infl = REGLAGES.gonflement.find(([re]) => re.test(m.nom));
    gonfler(geo, infl ? infl[1] : REGLAGES.gonflementDefaut);
    fibres(geo, m.nom);
    // région : un muscle entier (parties fusionnées), gauche et droite séparées
    let region = m.nom.replace(/ \(\d+\)$/, '');
    for (const [re, rep] of FUSIONS) region = region.replace(re, rep);
    if (/rectus abdominis/.test(m.nom)) {
      // intersections tendineuses : le grand droit découpé en blocs (tablette)
      geo.computeBoundingBox();
      const z0 = geo.boundingBox.min.z, z1 = geo.boundingBox.max.z;
      const cuts = REGLAGES.abdos.map((f) => z1 - f * (z1 - z0));
      const p = geo.attributes.position.array, ix = geo.index.array;
      const bandes = cuts.map(() => []).concat([[]]);
      for (let t = 0; t < ix.length; t += 3) {
        const zc = (p[ix[t] * 3 + 2] + p[ix[t + 1] * 3 + 2] + p[ix[t + 2] * 3 + 2]) / 3;
        let k = 0; while (k < cuts.length && zc < cuts[k]) k++;
        bandes[k].push(ix[t], ix[t + 1], ix[t + 2]);
      }
      bandes.forEach((tri, k) => {
        const gk = new THREE.BufferGeometry();
        for (const n of Object.keys(geo.attributes)) gk.setAttribute(n, geo.attributes[n]);
        gk.setIndex(tri);
        const rn = region + " bloc " + k;
        if (!regionsParNom.has(rn)) regionsParNom.set(rn, regionsParNom.size + 1);
        objets.push({ nom: m.nom + " bloc " + k, geo: gk, groupe: g, region: regionsParNom.get(rn) });
      });
      continue;
    }
    if (!regionsParNom.has(region)) regionsParNom.set(region, regionsParNom.size + 1);
    objets.push({ nom: m.nom, geo, groupe: g, region: regionsParNom.get(region), profond: g === 'rhomboides' });
  }
  // aine lissée (personnage neutre)
  {
    const p = peau.attributes.position.array, A = P.aine;
    for (let i = 0; i < p.length; i += 3) {
      const x = p[i], z = p[i + 2];
      if (Math.abs(x) > A.x || z < A.z0 || z > A.z1) continue;
      const plan = A.y1 + (A.z1 - z) * A.pente + (x / A.x) ** 2 * 25;
      if (p[i + 1] < plan) p[i + 1] = plan;
    }
    peau.computeVertexNormals();
  }
  const pp = peau.attributes.position.array;
  const nv = pp.length / 3;
  const role = new Uint8Array(nv); // 0 sous-couche, 1 tête, 2 main, 3 pied
  const poidsTete = new Float32Array(nv);
  for (let i = 0; i < nv; i++) {
    const x = pp[i * 3], y = pp[i * 3 + 1], z = pp[i * 3 + 2];
    const coupeTete = P.teteZ + (y - P.teteY0) * P.tetePente;
    if (z > coupeTete) { role[i] = 1; poidsTete[i] = lisse(coupeTete, coupeTete + 40, z); }
    else if (z < P.mainZ && Math.abs(x) > P.mainX) role[i] = 2;
    else if (z < P.piedZ) role[i] = 3;
  }
  lisser(peau, poidsTete, P.lissageTete, 0.6, 0);
  let oeuf = null;
  // tête de mannequin : projection vers un oeuf lisse, un peu plus grand
  {
    const p = peau.attributes.position.array;
    const bb = new THREE.Box3();
    for (let i = 0; i < nv; i++) if (poidsTete[i] >= 1) bb.expandByPoint(new THREE.Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]));
    const c = bb.getCenter(new THREE.Vector3()), t = bb.getSize(new THREE.Vector3()).multiplyScalar(0.5 * P.teteEchelle);
    c.z -= t.z * 0.05;
    oeuf = { c: c.clone(), t: t.clone() };
    for (let i = 0; i < nv; i++) {
      const w = poidsTete[i] * P.teteOeuf;
      if (!w) continue;
      const d = new THREE.Vector3(p[i * 3] - c.x, p[i * 3 + 1] - c.y, p[i * 3 + 2] - c.z);
      const bas = Math.max(0, -d.z / t.z);
      const rx = t.x * P.teteLargeur * (1 - 0.3 * bas * bas), ry = t.y * (1 - 0.12 * bas);
      const k = 1 / Math.sqrt((d.x / rx) ** 2 + (d.y / ry) ** 2 + (d.z / t.z) ** 2);
      for (let j = 0; j < 3; j++) p[i * 3 + j] += (c.getComponent(j) + d.getComponent(j) * k - p[i * 3 + j]) * w;
    }
    peau.computeVertexNormals();
  }
  // la tête a fondu au lissage : on lui rend du volume
  { const p = peau.attributes.position.array, n = peau.attributes.normal.array; for (let i = 0; i < nv; i++) if (poidsTete[i]) for (let k = 0; k < 3; k++) p[i * 3 + k] += n[i * 3 + k] * P.teteGonfle * poidsTete[i]; peau.computeVertexNormals(); }
  // rentrer la sous-couche
  // sous-couche plaquée juste sous les muscles (lancer de rayons vers l intérieur),
  // et peu rentrée là où il n y a pas de muscle (genou, tibia, coude, crête iliaque)
  const nn = peau.attributes.normal.array;
  const tous = mergeGeometries(objets.map((o) => { const g = new THREE.BufferGeometry(); g.setAttribute("position", o.geo.attributes.position); g.setIndex(o.geo.index); return g; }));
  const bvh = new MeshBVH(tous);
  const ray = new THREE.Ray();
  const retrait = new Float32Array(nv);
  const utilises = new Uint8Array(nv);
  for (const v of peau.index.array) utilises[v] = 1;
  for (let i = 0; i < nv; i++) {
    if (!utilises[i] || role[i] !== 0) continue;
    const n = new THREE.Vector3(nn[i * 3], nn[i * 3 + 1], nn[i * 3 + 2]);
    ray.origin.set(pp[i * 3], pp[i * 3 + 1], pp[i * 3 + 2]).addScaledVector(n, 2);
    ray.direction.copy(n).negate();
    const hit = bvh.raycastFirst(ray, THREE.DoubleSide);
    const t = hit ? hit.distance - 2 : Infinity;
    retrait[i] = t < P.retraitMax ? Math.max(0, t + P.sousMuscle) : P.retraitOs;
  }
  // lissage des retraits
  const vois = voisins(peau);
  for (let it = 0; it < P.lissageRetrait; it++) {
    const r2 = retrait.slice();
    for (let i = 0; i < nv; i++) {
      if (!utilises[i] || role[i] !== 0) continue;
      let m = 0, c = 0;
      for (const j of vois[i]) if (role[j] === 0) { m += retrait[j]; c++; }
      if (c) r2[i] = 0.5 * retrait[i] + 0.5 * m / c;
    }
    retrait.set(r2);
  }
  for (let i = 0; i < nv; i++) {
    const k = retrait[i];
    pp[i * 3] -= nn[i * 3] * k; pp[i * 3 + 1] -= nn[i * 3 + 1] * k; pp[i * 3 + 2] -= nn[i * 3 + 2] * k;
  }
  peau.computeVertexNormals();
  const idx = peau.index.array;
  const parRole = [[], [], [], []];
  for (let t = 0; t < idx.length; t += 3) {
    const a = idx[t], b = idx[t + 1], c = idx[t + 2];
    const r = Math.max(role[a], role[b], role[c]) === 0 ? 0 : (role[a] || role[b] || role[c]);
    parRole[r].push(a, b, c);
  }
  const nomsRole = ['sous-couche', 'tete', 'main', 'pied'];
  for (let r = 0; r < 4; r++) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', peau.attributes.position);
    g.setAttribute('normal', peau.attributes.normal);
    g.setAttribute('fibre', new THREE.BufferAttribute(new Float32Array(nv * 2), 2));
    g.setIndex(parRole[r]);
    const region = regionsParNom.size + 1;
    regionsParNom.set('peau ' + nomsRole[r], region);
    if (r !== 1) objets.push({ nom: 'peau ' + nomsRole[r], geo: g, groupe: null, region, peau: true, sousCouche: r === 0 });
    if (r === 1) {
      // tête de mannequin lisse : ellipsoïde, mâchoire un peu resserrée
      const sp = new THREE.SphereGeometry(1, 96, 64);
      sp.rotateX(Math.PI / 2);
      const q = sp.attributes.position.array;
      for (let i = 0; i < q.length; i += 3) {
        const bas = Math.max(0, -q[i + 2]);
        q[i] *= oeuf.t.x * P.teteLargeur * (1 - P.teteMachoire * bas * bas);
        q[i + 1] = q[i + 1] * oeuf.t.y * (1 - 0.1 * bas) - P.teteMenton * bas * bas * oeuf.t.y * (q[i + 1] < 0 ? 1 : 0);
        q[i + 2] *= oeuf.t.z;
      }
      sp.translate(oeuf.c.x, oeuf.c.y, oeuf.c.z + P.teteZDecal);
      sp.computeVertexNormals();
      sp.deleteAttribute('uv');
      sp.setAttribute('fibre', new THREE.BufferAttribute(new Float32Array(sp.attributes.position.count * 2), 2));
      objets.push({ nom: 'peau tete', geo: sp, groupe: null, region, peau: true });
    }
  }
  MODELE = { objets, nbRegions: regionsParNom.size, regions: [...regionsParNom.keys()] };
  window.MODELE = MODELE;
  return { objets: objets.length, regions: MODELE.nbRegions };
}

// ---------- Passes ----------
const VS_COMMUN = /* glsl */`
  attribute vec2 fibre;
  varying vec3 vN; varying vec3 vP; varying vec2 vF;
  void main() {
    vN = normalize(normalMatrix * normal);
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    vP = mv.xyz; vF = fibre;
    gl_Position = projectionMatrix * mv;
  }`;

function materiauId(id, face) {
  const c = new THREE.Color((id & 255) / 255, ((id >> 8) & 255) / 255, 0);
  return new THREE.ShaderMaterial({
    vertexShader: VS_COMMUN,
    fragmentShader: `uniform vec3 c; void main(){ gl_FragColor = vec4(c, 1.0); }`,
    uniforms: { c: { value: new THREE.Vector3(c.r, c.g, c.b) } },
    side: face ? THREE.FrontSide : THREE.DoubleSide,
  });
}
const matGeo = (face) => new THREE.ShaderMaterial({
  vertexShader: VS_COMMUN,
  fragmentShader: `varying vec3 vN; varying vec3 vP; varying vec2 vF;
    void main(){ vec3 n = normalize(vN); if (!gl_FrontFacing) n = -n; gl_FragColor = vec4(n, -vP.z); }`,
  side: face ? THREE.FrontSide : THREE.DoubleSide,
});
const matFib = (face) => new THREE.ShaderMaterial({
  vertexShader: VS_COMMUN,
  fragmentShader: `varying vec3 vN; varying vec3 vP; varying vec2 vF;
    void main(){ gl_FragColor = vec4(vF, 0.0, 1.0); }`,
  side: face ? THREE.FrontSide : THREE.DoubleSide,
});

function cible(w, h, flottant) {
  return new THREE.WebGLRenderTarget(w, h, {
    type: flottant ? THREE.FloatType : THREE.UnsignedByteType,
    format: THREE.RGBAFormat, minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter,
    depthBuffer: true,
  });
}

function lire(rt, w, h, flottant) {
  const buf = flottant ? new Float32Array(w * h * 4) : new Uint8Array(w * h * 4);
  renderer.readRenderTargetPixels(rt, 0, 0, w, h, buf);
  return buf;
}

// Cadrages en mm (repère du modèle) : centre x, z et hauteur visible ; taille de sortie en px.
export function camera(vue, cadre) {
  const { cx, cz, hauteurMm, largeur, hauteur } = cadre;
  const h = hauteurMm / 2, w = h * largeur / hauteur;
  const cam = new THREE.OrthographicCamera(-w, w, h, -h, 10, 6000);
  cam.up.set(0, 0, 1);
  const s = vue === 'dos' ? 1 : -1;
  cam.position.set(vue === 'dos' ? -cx : cx, s * 3000, cz);
  cam.position.x = cx;
  cam.lookAt(cx, 0, cz);
  return cam;
}

window.passes = async (vue, nomCadre) => {
  const cadre = REGLAGES.cadres[nomCadre];
  const S = REGLAGES.surech;
  const W = cadre.largeur * S, H = cadre.hauteur * S;
  renderer.setSize(W, H);
  const cam = camera(vue, cadre);
  const scene = new THREE.Scene();
  const meshes = MODELE.objets.map((o, i) => {
    const m = new THREE.Mesh(o.geo, materiauId(i + 1, o.peau));
    m.userData = o; m.frustumCulled = false;
    scene.add(m); return m;
  });
  const mg = [matGeo(false), matGeo(true)], mf = [matFib(false), matFib(true)];
  const mid = meshes.map((m) => m.material);
  // rend une couche (filtre sur les objets) : identifiants, normales et profondeur, fibres
  const couche = (filtre) => {
    const rtId = cible(W, H, false), rtF = cible(W, H, true);
    const scene = new THREE.Scene();
    for (const m of meshes) if (filtre(m.userData)) scene.add(m);
    meshes.forEach((m, i) => { m.material = mid[i]; });
    renderer.setClearColor(0x000000, 0);
    renderer.setRenderTarget(rtId); renderer.clear(); renderer.render(scene, cam);
    const id = lire(rtId, W, H, false);
    meshes.forEach((m) => { m.material = mg[m.userData.peau ? 1 : 0]; });
    renderer.setRenderTarget(rtF); renderer.clear(); renderer.render(scene, cam);
    const geo = lire(rtF, W, H, true);
    meshes.forEach((m) => { m.material = mf[m.userData.peau ? 1 : 0]; });
    renderer.clear(); renderer.render(scene, cam);
    const fib = lire(rtF, W, H, true);
    rtId.dispose(); rtF.dispose();
    for (const m of [...scene.children]) scene.remove(m);
    return { id, geo, fib };
  };
  // muscles (et tête, mains, pieds), puis la sous-couche seule : elle ne comble que les vrais trous
  const A = couche((o) => !o.profond && !o.sousCouche);
  const B = couche((o) => o.sousCouche);
  const P = couche((o) => o.profond);
  const tol = REGLAGES.peau.toleranceTrou;
  for (let i = 0; i < W * H; i++) {
    const a = A.id[i * 4] + A.id[i * 4 + 1] * 256, bb = B.id[i * 4] + B.id[i * 4 + 1] * 256;
    if (!bb) continue;
    if (!a || B.geo[i * 4 + 3] < A.geo[i * 4 + 3] - tol) {
      for (let k = 0; k < 4; k++) { A.id[i * 4 + k] = B.id[i * 4 + k]; A.geo[i * 4 + k] = B.geo[i * 4 + k]; A.fib[i * 4 + k] = B.fib[i * 4 + k]; }
    }
  }
  meshes.forEach((m, i) => { m.material = mid[i]; });
  [...mg, ...mf].forEach((m) => m.dispose());
  renderer.setRenderTarget(null);
  for (const m of meshes) m.material.dispose();
  const pxParMm = H / cadre.hauteurMm;
  return composer({ W, H, S, id: A.id, idProfond: P.id, geo: A.geo, fib: A.fib, vue, cadre, pxParMm, modele: MODELE, renderer });
};

window.preparer = preparer;
window.pret = true;

// Aperçu brut (mise au point) : objets dont le nom correspond à `re`.
window.apercu = (re, vue = 'face', nomCadre = 'corps') => {
  const cadre = REGLAGES.cadres[nomCadre];
  renderer.setSize(cadre.largeur, cadre.hauteur);
  const scene = new THREE.Scene();
  const rx = new RegExp(re);
  for (const o of MODELE.objets) if (rx.test(o.nom)) {
    const m = new THREE.Mesh(o.geo, new THREE.MeshStandardMaterial({ color: o.peau ? 0xbbbbbb : new THREE.Color().setHSL((o.region * 0.618) % 1, 0.6, 0.55), roughness: 0.6, side: o.peau ? THREE.FrontSide : THREE.DoubleSide }));
    m.frustumCulled = false; scene.add(m);
  }
  scene.add(new THREE.HemisphereLight(0xffffff, 0x555555, 1.6));
  const d = new THREE.DirectionalLight(0xffffff, 2); d.position.set(0.3, vue === 'dos' ? 1 : -1, 1.2); scene.add(d);
  renderer.setRenderTarget(null); renderer.setClearColor(0xffffff, 1);
  renderer.render(scene, camera(vue, cadre));
  return renderer.domElement.toDataURL();
};
