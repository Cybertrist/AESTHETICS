// Récupère une fois pour toutes les images du personnage anatomique
// (API Muscle Visualizer d'ExerciseDB, via RapidAPI) et les range dans
// ~/.aesthetic/gymvisual/. La clé est lue dans ~/.aesthetic/rapidapi.key.
// Relançable : un fichier déjà présent n'est pas redemandé.
//
//   node tools/gymvisual/telecharger.mjs            tout récupérer
//   node tools/gymvisual/telecharger.mjs --essai    une seule image, pour vérifier l'offre

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const DOSSIER = path.join(os.homedir(), '.aesthetic', 'gymvisual');
const CLE = fs.readFileSync(path.join(os.homedir(), '.aesthetic', 'rapidapi.key'), 'utf8').trim();
const HOTE = 'muscle-visualizer-api.p.rapidapi.com';
const RACINE = `https://${HOTE}/api/v1`;
const GENRES = ['male', 'female'];
const ROUGE = '#FF0000';

async function appel(chemin, params, format = 'png') {
  const q = new URLSearchParams({ ...params, size: 'xlarge', format, background: 'transparent' });
  for (let essai = 1; essai <= 5; essai++) {
    const r = await fetch(`${RACINE}${chemin}?${q}`, { headers: { 'X-RapidAPI-Key': CLE, 'X-RapidAPI-Host': HOTE } });
    if (r.ok) return Buffer.from(await r.arrayBuffer());
    const texte = await r.text();
    if (r.status === 400 || r.status === 403) throw new Error(`${r.status} ${texte}`);
    await new Promise((ok) => setTimeout(ok, 1000 * essai));
  }
  throw new Error(`échec répété sur ${chemin}`);
}

async function enregistrer(fichier, fabriquer) {
  const cible = path.join(DOSSIER, fichier);
  if (fs.existsSync(cible)) return false;
  fs.mkdirSync(path.dirname(cible), { recursive: true });
  fs.writeFileSync(cible, await fabriquer());
  return true;
}

async function parLots(taches, n = 6) {
  let i = 0, faits = 0;
  const ouvrier = async () => {
    while (i < taches.length) {
      const t = taches[i++];
      if (await t()) faits++;
      if (faits && faits % 20 === 0) console.log(`${faits} images`);
    }
  };
  await Promise.all(Array.from({ length: n }, ouvrier));
  return faits;
}

const nomFichier = (m) => m.toLowerCase().replace(/[^a-z0-9]+/g, '_');

async function main() {
  if (process.argv.includes('--essai')) {
    const img = await appel('/visualize', { muscles: 'CHEST', color: ROUGE, gender: 'male' });
    fs.mkdirSync(DOSSIER, { recursive: true });
    fs.writeFileSync(path.join(DOSSIER, 'essai.png'), img);
    console.log(`offre active : essai.png, ${img.length} octets`);
    return;
  }

  const r = await fetch(`${RACINE}/muscles`, { headers: { 'X-RapidAPI-Key': CLE, 'X-RapidAPI-Host': HOTE } });
  const muscles = (await r.json()).data;
  fs.mkdirSync(DOSSIER, { recursive: true });
  fs.writeFileSync(path.join(DOSSIER, 'muscles.json'), JSON.stringify(muscles, null, 2));
  console.log(`${muscles.length} muscles`);

  const taches = [];
  for (const g of GENRES) {
    // Chaque muscle seul, en rouge pur : sert à découper son masque.
    for (const m of muscles) {
      taches.push(() => enregistrer(`${g}/muscles/${nomFichier(m)}.png`,
        () => appel('/visualize', { muscles: m, color: ROUGE, gender: g })));
    }
    // Deux images aux muscles disjoints : leur fusion donne le corps sans aucune couleur.
    taches.push(() => enregistrer(`${g}/base_a.png`, () => appel('/visualize', { muscles: 'BICEPS', color: ROUGE, gender: g })));
    taches.push(() => enregistrer(`${g}/base_b.png`, () => appel('/visualize', { muscles: 'CALVES', color: ROUGE, gender: g })));
    // Le rouge de l'appli, pour comparer le rendu natif avec celui du widget.
    taches.push(() => enregistrer(`${g}/exemples/pectoraux_epaules.png`,
      () => appel('/visualize', { muscles: 'CHEST,DELTOIDS', color: '#E0393E', gender: g })));
    taches.push(() => enregistrer(`${g}/exemples/dos.png`,
      () => appel('/visualize', { muscles: 'LATISSIMUS DORSI,TRAPEZIUS', color: '#E0393E', gender: g })));
    taches.push(() => enregistrer(`${g}/exemples/seance.png`,
      () => appel('/visualize/workout', { targetMuscles: 'CHEST', targetMusclesColor: '#E0393E', secondaryMuscles: 'TRICEPS,ANTERIOR DELTOID', secondaryMusclesColor: '#F08A8C', gender: g })));
  }
  const faits = await parLots(taches);
  console.log(`terminé : ${faits} nouvelles images dans ${DOSSIER}`);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
