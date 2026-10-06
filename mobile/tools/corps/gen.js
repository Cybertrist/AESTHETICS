// Génère assets/body/front.svg et back.svg, puis la page de contrôle controle.html.
// Utilisation : node tools/corps/gen.js
'use strict';
const fs = require('fs');
const path = require('path');
const { build, colorize, simplify } = require('./lib');

const racine = path.resolve(__dirname, '../..');
const vues = { front: require('./face') };
try { vues.back = require('./dos'); } catch (e) { if (e.code !== 'MODULE_NOT_FOUND') throw e; }

const svgs = {};
for (const [nom, def] of Object.entries(vues)) {
  svgs[nom] = build(def);
  fs.writeFileSync(path.join(racine, 'assets/body', `${nom}.svg`), svgs[nom]);
  console.log(`${nom}.svg : ${(svgs[nom].length / 1024).toFixed(0)} Ko`);
}

const inline = (svg) => svg.replace(/ width="\d+" height="\d+"/, '').replace(/id="(g-[^"]+|c\d+|silhouette)"/g, (a, id) => a)
  ;
// Chaque SVG en ligne a besoin d'ids uniques dans la page : on préfixe.
let n = 0;
const uniq = (svg) => {
  const p = `v${n++}`;
  return inline(svg).replace(/id="([^"]+)"/g, `id="${p}$1"`).replace(/url\(#([^)]+)\)/g, `url(#${p}$1)`);
};

const scenes = [
  { titre: 'Neutre', i: {} },
  { titre: 'Poussée : pectoraux, épaules, triceps', i: { pectoraux: 1, deltoidesAnterieurs: 1, deltoidesLateraux: 0.6, triceps: 0.7 } },
  { titre: 'Tirage : dos, arrière d\'épaule, biceps', i: { grandDorsal: 1, trapezes: 0.7, rhomboides: 1, deltoidesPosterieurs: 0.8, biceps: 0.6, avantBras: 0.3 } },
  { titre: 'Jambes et gainage', i: { quadriceps: 1, fessiers: 1, ischios: 0.7, mollets: 0.5, abdominaux: 1, obliques: 0.6, adducteurs: 0.5, abducteurs: 0.4, lombaires: 0.5 } },
  { titre: 'Récupération : intensités de 0 à 1', i: { pectoraux: 0.25, deltoidesAnterieurs: 0.5, deltoidesLateraux: 0.5, biceps: 0.75, triceps: 0.75, avantBras: 1, trapezes: 0.25, grandDorsal: 0.5, quadriceps: 0.15, mollets: 1, cou: 0.5 } },
  { titre: "Sélection d'un filtre (accent Ambre)", i: { abdominaux: 1, obliques: 1, lombaires: 1 }, couleur: '#F0A042' },
];

const vuesNoms = Object.keys(svgs);
const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Personnage</title>
<style>
body{margin:0;background:#1E1F22;font-family:Inter,Segoe UI,sans-serif;color:#F2F3F5}
.grille{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;padding:18px}
.carte{background:#2B2D31;border-radius:12px;padding:12px}
.carte h2{font-size:13px;font-weight:600;margin:0 0 8px;color:#B5BAC1}
.duo{display:flex;gap:4px}.duo svg{width:50%;height:auto}
</style></head><body><div class="grille">
${scenes.map((s) => `<div class="carte"><h2>${s.titre}</h2><div class="duo">${vuesNoms.map((v) => uniq(colorize(svgs[v], s.i, s.couleur))).join('')}</div></div>`).join('\n')}
</div></body></html>`;
fs.writeFileSync(path.join(__dirname, 'controle.html'), html);

// Page de zoom : une vue en grand, pour juger les détails.
const zoom = (v, i) => `<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;background:#2B2D31}svg{display:block;width:100%;height:auto}</style></head><body>${uniq(colorize(svgs[v], i))}</body></html>`;
for (const v of vuesNoms) {
  fs.writeFileSync(path.join(__dirname, `zoom-${v}.html`), zoom(v, {}));
  fs.writeFileSync(path.join(__dirname, `zoom-${v}-rouge.html`), zoom(v, v === 'front' ? scenes[1].i : scenes[2].i));
}
console.log('controle.html écrit');

// Planche petit format : 80 et 120 px, version simplifiée, à côté des références à la même hauteur.
const R = path.resolve(racine, 'refs').split(path.sep).join('/');
const img = (svg, h) => `<img style="height:${h}px" src="data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}">`;
const coupe = (ref, h, l, t, w) => `<div style="width:${w}px;height:80px;overflow:hidden;position:relative"><img src="file:///${R}/${ref}" style="position:absolute;height:${h}px;left:-${l}px;top:-${t}px"></div>`;
const rougeFace = colorize(svgs.front, { pectoraux: 1, deltoidesAnterieurs: 1 });
const rougeDos = colorize(svgs.back, { deltoidesPosterieurs: 1, trapezes: 1 });
const planche = `<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;background:#2B2D31;font:11px sans-serif;color:#B5BAC1;padding-bottom:8px}
.l{display:flex;gap:14px;align-items:flex-end;padding:10px 12px}.c{text-align:center}</style></head><body>
<div class="l">
<div class="c">${img(simplify(rougeFace), 80)}${img(simplify(rougeDos), 80)}<br>80 px simplifié</div>
${coupe('ref4.jpg', 830, 210, 201, 46)}${coupe('ref4.jpg', 830, 270, 201, 46)}
<div class="c">${img(rougeFace, 80)}${img(rougeDos, 80)}<br>80 px complet</div>
${coupe('ref5.jpg', 830, 209, 424, 46)}${coupe('ref5.jpg', 830, 270, 424, 46)}
<div class="c" style="background:#1E1F22;padding:6px;border-radius:8px">${img(rougeFace, 120)}${img(rougeDos, 120)}<br>120 px</div>
<div class="c" style="background:#383A40;padding:6px;border-radius:8px">${img(simplify(colorize(svgs.front, { abdominaux: 1 })), 56)}${img(simplify(colorize(svgs.back, { grandDorsal: 1 })), 56)}<br>56 px</div>
</div></body></html>`;
fs.writeFileSync(path.join(__dirname, 'planche.html'), planche);

// Planche des muscles colorés seuls : chaque muscle de l'enum, face et dos, à 300 px et à 80 px, à côté de ref4.
const MUSCLES = ['pectoraux', 'deltoidesAnterieurs', 'deltoidesLateraux', 'deltoidesPosterieurs', 'biceps', 'triceps', 'avantBras',
  'trapezes', 'grandDorsal', 'rhomboides', 'lombaires', 'abdominaux', 'obliques', 'fessiers', 'quadriceps', 'ischios', 'adducteurs',
  'abducteurs', 'mollets', 'cou'];
// Les variantes sont écrites dans le dossier temporaire du système et chargées par chemin (page légère).
const TMP = path.join(require("os").tmpdir(), "aesthetic-corps-variantes");
fs.mkdirSync(TMP, { recursive: true });
const fichier = (nom, svg) => { fs.writeFileSync(path.join(TMP, nom), svg); return `file:///${TMP.split(path.sep).join("/")}/${nom}?${Date.now()}`; };
const present = (svg, m) => svg.includes(`id="m-${m}"`);
const vues2 = (m) => ["front", "back"].filter((v) => present(svgs[v], m));
const carte = (m, h) => `<div class="c"><div class="d">${vues2(m).map((v) => `<img style="height:${h}px" src="${fichier(`${m}-${v}.svg`, colorize(svgs[v], { [m]: 1 }))}">`).join("")}</div><span>${m}</span></div>`;
const petit = (m) => vues2(m).map((v) => `<img style="height:80px" src="${fichier(`${m}-${v}-p.svg`, simplify(colorize(svgs[v], { [m]: 1 })))}">`).join("");
const plancheMuscles = `<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;background:#2B2D31;font:12px Inter,sans-serif;color:#B5BAC1}
.g{display:flex;flex-wrap:wrap;gap:10px;padding:10px}.c{background:#1E1F22;border-radius:10px;padding:8px;text-align:center}.d{display:flex;gap:4px}
.p{display:flex;flex-wrap:wrap;gap:6px;padding:10px;align-items:flex-end}.p div{background:#1E1F22;border-radius:8px;padding:4px}</style></head><body>
<div class="g"><div class="c" style="width:290px;height:300px;overflow:hidden;position:relative"><img src="file:///${R}/ref4.jpg" style="position:absolute;height:3000px;left:-700px;top:-720px"><span style="position:absolute;bottom:4px;left:8px">ref4</span></div>
${MUSCLES.map((m) => carte(m, 300)).join('\n')}</div>
<div class="p">${MUSCLES.map((m) => `<div>${petit(m)}</div>`).join('')}${coupe('ref4.jpg', 830, 210, 201, 46)}${coupe('ref4.jpg', 830, 270, 201, 46)}</div>
</body></html>`;
fs.writeFileSync(path.join(__dirname, 'planche-muscles.html'), plancheMuscles);
