#!/usr/bin/env node
// Prépare les médias des exercices à partir du pack sous licence (dossier décompressé, hors dépôt) :
//   animations 960 px, 20 images par seconde  ->  assets/exercises/anim/<id>.webp   (720 px, toutes les images)
//   poses de départ et de fin 1024 px          ->  assets/exercises/poses/<id>-<pose>.webp (720 px)
// Les fichiers déjà faits sont gardés : la commande se relance sans tout refaire.
//
// Usage (depuis mobile/) : node tools/repdb/medias.mjs --source=<dossier du pack> [--seulement=bench-press,squat]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const ICI = path.dirname(fileURLToPath(import.meta.url));
const MOBILE = path.resolve(ICI, '..', '..');
const arg = (nom) => (process.argv.find((a) => a.startsWith(`--${nom}=`)) || '').split('=')[1];
const SOURCE = arg('source');
if (!SOURCE || !fs.existsSync(path.join(SOURCE, 'images'))) {
  console.error('Indique le dossier du pack décompressé : --source=<dossier>');
  process.exit(1);
}
const seulement = arg('seulement') ? new Set(arg('seulement').split(',')) : null;

// Qualité d'abord : à 720 px l'image reste nette en grand sur le téléphone, et la cadence d'origine est gardée.
const ANIM = { taille: 720, qualite: 75 };
const POSE = { taille: 720, qualite: 88 };
const EN_PARALLELE = 6;

const sortieAnim = path.join(MOBILE, 'assets', 'exercises', 'anim');
const sortiePoses = path.join(MOBILE, 'assets', 'exercises', 'poses');
fs.mkdirSync(sortieAnim, { recursive: true });
fs.mkdirSync(sortiePoses, { recursive: true });

async function animation(fichier) {
  const sortie = path.join(sortieAnim, fichier);
  if (fs.existsSync(sortie)) return false;
  const entree = path.join(SOURCE, 'images', 'animations', fichier);
  const tmp = `${sortie}.tmp`;
  await sharp(entree, { animated: true })
    .resize(ANIM.taille, ANIM.taille)
    .webp({ quality: ANIM.qualite, alphaQuality: 90, effort: 4, loop: 0 })
    .toFile(tmp);
  fs.renameSync(tmp, sortie);
  return true;
}

async function pose(fichier) {
  const sortie = path.join(sortiePoses, fichier);
  if (fs.existsSync(sortie)) return false;
  const tmp = `${sortie}.tmp`;
  await sharp(path.join(SOURCE, 'images', 'classic', fichier))
    .resize(POSE.taille, POSE.taille, { fit: 'inside' })
    .webp({ quality: POSE.qualite, alphaQuality: 90, effort: 5 })
    .toFile(tmp);
  fs.renameSync(tmp, sortie);
  return true;
}

const garde = (f) => !seulement || seulement.has(f.replace(/(-start|-peak|-main)?\.webp$/, ''));
const taches = [
  ...fs.readdirSync(path.join(SOURCE, 'images', 'classic')).filter((f) => f.endsWith('.webp') && garde(f)).map((f) => () => pose(f)),
  ...fs.readdirSync(path.join(SOURCE, 'images', 'animations')).filter((f) => f.endsWith('.webp') && garde(f)).map((f) => () => animation(f)),
];

let fait = 0, neufs = 0, rates = 0;
const debut = Date.now();
async function ouvrier() {
  while (taches.length) {
    const tache = taches.shift();
    try {
      if (await tache()) neufs++;
    } catch (e) {
      rates++;
      console.error('Échec :', e.message);
    }
    if (++fait % 50 === 0) console.log(`${fait} traités, ${Math.round((Date.now() - debut) / 1000)} s`);
  }
}
await Promise.all(Array.from({ length: EN_PARALLELE }, ouvrier));

const poids = (dossier) => fs.readdirSync(dossier).reduce((s, f) => s + fs.statSync(path.join(dossier, f)).size, 0) / 1048576;
console.log(`${neufs} fichiers créés, ${rates} échecs. Animations : ${poids(sortieAnim).toFixed(1)} Mo, poses : ${poids(sortiePoses).toFixed(1)} Mo.`);
