#!/usr/bin/env node
// Prépare le personnage de l'appli à partir du pack sous licence (images/muscle_heatmap) : le même
// bonhomme que dans les animations. Sortie dans assets/body/pack/ :
//   <vue>_base.webp, <vue>_buste_base.webp, <vue>_jambes_base.webp   corps gris : entier, buste, jambes
//   <vue>_<muscle>.webp, <vue>_buste_<muscle>.webp, <vue>_jambes_<muscle>.webp   calque coloré d'un muscle
//   manifeste.json                                  muscles disponibles par vue
// Les muscles suivent l'enum Muscle (lib/core/models/muscle.dart).
//
// Usage (depuis mobile/) : node tools/repdb/corps.mjs --source=<dossier du pack>

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const ICI = path.dirname(fileURLToPath(import.meta.url));
const MOBILE = path.resolve(ICI, '..', '..');
const SOURCE = (process.argv.find((a) => a.startsWith('--source=')) || '').split('=')[1];
const CARTE = SOURCE && path.join(SOURCE, 'images', 'muscle_heatmap');
if (!SOURCE || !fs.existsSync(path.join(CARTE, 'manifest.json'))) {
  console.error('Indique le dossier du pack décompressé : --source=<dossier>');
  process.exit(1);
}
const SORTIE = path.join(MOBILE, 'assets', 'body', 'pack');
fs.mkdirSync(SORTIE, { recursive: true });

// Toile commune aux deux vues (mêmes proportions qu'avant : 424 x 1000), et cadrages carrés :
// le buste, du menton aux hanches, et les jambes, de la taille aux pieds.
const LARGEUR = 636, HAUTEUR = 1500;
const CADRAGES = { buste: { haut: 165, hauteur: LARGEUR }, jambes: { haut: 600, hauteur: 900 } };

// Calques du pack vers muscles de l'appli. Un calque peut servir plusieurs muscles (deltoïdes).
const VUES = {
  face: {
    tag: 'front',
    muscles: {
      pectoralis_major: ['pectoraux'],
      deltoids: ['deltoidesAnterieurs', 'deltoidesLateraux'],
      biceps_brachii: ['biceps'],
      triceps: ['triceps'],
      brachioradialis: ['avantBras'],
      palmaris_longus: ['avantBras'],
      trapezius: ['trapezes'],
      abdominals: ['abdominaux'],
      obliques: ['obliques'],
      rectus_femoris: ['quadriceps'],
      vastus_lateralis: ['quadriceps'],
      vastus_medialis: ['quadriceps'],
      adductor_longus: ['adducteurs'],
      gracilis: ['adducteurs'],
      pectineus_sartorius: ['adducteurs'],
      gracilis_gastrocnemius: ['mollets'],
      tibialis_anterior: ['mollets'],
      sternocleidomastoid: ['cou'],
    },
  },
  dos: {
    tag: 'back',
    muscles: {
      deltoids: ['deltoidesPosterieurs', 'deltoidesLateraux'],
      triceps: ['triceps'],
      anconeus: ['triceps'],
      brachioradialis: ['avantBras'],
      extensor_carpi: ['avantBras'],
      trapezius: ['trapezes'],
      latissimus_dorsi: ['grandDorsal'],
      infraspinatus_teres_minor: ['rhomboides'],
      erector_spinae: ['lombaires'],
      gluteus_maximus: ['fessiers'],
      gluteus_medius: ['abducteurs'],
      iliotibial_band: ['abducteurs'],
      biceps_femoris: ['ischios'],
      semimembranosus: ['ischios'],
      semitendinosus: ['ischios'],
      adductor_magnus: ['adducteurs'],
      gracilis: ['adducteurs'],
      gastrocnemius: ['mollets'],
      soleus: ['mollets'],
    },
  },
};

const pack = JSON.parse(fs.readFileSync(path.join(CARTE, 'manifest.json'), 'utf8'));
const webp = { quality: 88, alphaQuality: 90, effort: 5 };
const vide = () => sharp({ create: { width: LARGEUR, height: HAUTEUR, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } });
// Une image du pack posée sur la toile commune, centrée.
const surToile = async (fichier) => {
  const img = await sharp(path.join(CARTE, fichier)).resize({ height: HAUTEUR }).png().toBuffer();
  return vide().composite([{ input: img, gravity: 'centre' }]).png().toBuffer();
};
// Bande du corps ramenée dans un carré de la largeur de la toile, centrée.
const cadrer = (tampon, { haut, hauteur }) =>
  sharp(tampon)
    .extract({ left: 0, top: haut, width: LARGEUR, height: hauteur })
    .resize(LARGEUR, LARGEUR, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } });
const couverture = async (image) => (await image.clone().extractChannel(3).stats()).channels[0].mean;

const manifeste = {};
for (const [vue, def] of Object.entries(VUES)) {
  const source = pack[def.tag];
  const base = await surToile(source.base);
  await sharp(base).webp(webp).toFile(path.join(SORTIE, `${vue}_base.webp`));
  for (const [nom, cadre] of Object.entries(CADRAGES)) {
    await cadrer(base, cadre).webp(webp).toFile(path.join(SORTIE, `${vue}_${nom}_base.webp`));
    manifeste[`${vue}_${nom}`] = { largeur: LARGEUR, hauteur: LARGEUR, masques: [] };
  }

  const calques = {};
  const inconnus = new Set();
  for (const m of source.muscles) {
    const cibles = def.muscles[m.name];
    if (!cibles) {
      inconnus.add(m.name);
      continue;
    }
    for (const c of cibles) (calques[c] ??= []).push(m.file);
  }
  if (inconnus.size) console.warn(`${vue} : calques sans muscle : ${[...inconnus].join(', ')}`);

  manifeste[vue] = { largeur: LARGEUR, hauteur: HAUTEUR, masques: [] };
  for (const [muscle, fichiers] of Object.entries(calques)) {
    const couches = [];
    for (const f of fichiers) couches.push({ input: await surToile(f) });
    const union = await vide().composite(couches).png().toBuffer();
    await sharp(union).webp(webp).toFile(path.join(SORTIE, `${vue}_${muscle}.webp`));
    manifeste[vue].masques.push(muscle);
    // Dans un cadrage, seulement les muscles qui s'y voient vraiment.
    for (const [nom, cadre] of Object.entries(CADRAGES)) {
      const image = await cadrer(union, cadre).png().toBuffer();
      if ((await couverture(sharp(image))) > 0.4) {
        await sharp(image).webp(webp).toFile(path.join(SORTIE, `${vue}_${nom}_${muscle}.webp`));
        manifeste[`${vue}_${nom}`].masques.push(muscle);
      }
    }
  }
}
fs.writeFileSync(path.join(SORTIE, 'manifeste.json'), JSON.stringify(manifeste, null, 1));

const fichiers = fs.readdirSync(SORTIE);
const poids = fichiers.reduce((s, f) => s + fs.statSync(path.join(SORTIE, f)).size, 0) / 1048576;
console.log(`${fichiers.length} fichiers, ${poids.toFixed(1)} Mo.`);
for (const [k, v] of Object.entries(manifeste)) console.log(`${k} : ${v.masques.join(', ')}`);
