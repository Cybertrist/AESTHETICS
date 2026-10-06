#!/usr/bin/env node
// Construit assets/data/exercises.json à partir du pack d'exercices sous licence (dossier décompressé,
// hors dépôt). Chaque exercice pointe vers ses médias embarqués, préparés par medias.mjs :
//   assets/exercises/anim/<id du pack>.webp          animation en boucle, fond transparent
//   assets/exercises/poses/<id du pack>-<pose>.webp  poses de départ et de fin (ou pose unique d'un maintien)
//
// Les exercices historiques de l'appli gardent leur identifiant français, leur nom court et leurs alias
// (tools/repdb/identifiants.json) : programmes et démo pointent dessus. Les autres prennent l'identifiant du pack.
//
// Usage (depuis mobile/) : node tools/repdb/catalogue.mjs --source=<dossier du pack>

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ICI = path.dirname(fileURLToPath(import.meta.url));
const MOBILE = path.resolve(ICI, '..', '..');
const arg = (nom) => (process.argv.find((a) => a.startsWith(`--${nom}=`)) || '').split('=')[1];
const SOURCE = arg('source');
if (!SOURCE || !fs.existsSync(path.join(SOURCE, 'exercises.json'))) {
  console.error('Indique le dossier du pack décompressé : --source=<dossier>');
  process.exit(1);
}
const SORTIE = path.join(MOBILE, 'assets', 'data', 'exercises.json');
const IDENTIFIANTS = path.join(ICI, 'identifiants.json');

// Muscles du pack vers l'enum Muscle (lib/core/models/muscle.dart). null : pas d'équivalent.
const MUSCLES = {
  pectoralis_major: 'pectoraux',
  anterior_deltoid: 'deltoidesAnterieurs',
  lateral_deltoid: 'deltoidesLateraux',
  supraspinatus: 'deltoidesLateraux',
  posterior_deltoid: 'deltoidesPosterieurs',
  biceps_brachii: 'biceps',
  brachialis: 'biceps',
  triceps_brachii: 'triceps',
  brachioradialis: 'avantBras',
  forearms: 'avantBras',
  forearm_flexors: 'avantBras',
  forearm_extensors: 'avantBras',
  trapezius: 'trapezes',
  latissimus_dorsi: 'grandDorsal',
  rhomboids: 'rhomboides',
  erector_spinae: 'lombaires',
  quadratus_lumborum: 'lombaires',
  rectus_abdominis: 'abdominaux',
  transverse_abdominis: 'abdominaux',
  obliques: 'obliques',
  serratus_anterior: null,
  gluteus_maximus: 'fessiers',
  gluteus_medius: 'abducteurs',
  abductors: 'abducteurs',
  adductors: 'adducteurs',
  quadriceps: 'quadriceps',
  hip_flexors: null,
  hamstrings: 'ischios',
  gastrocnemius: 'mollets',
  soleus: 'mollets',
};

// Matériel du pack vers les clés de Equipements.labels (lib/core/models/exercise.dart).
const MATERIEL = {
  barbell: 'barre', trap_bar: 'barre', landmine: 'barre',
  ez_bar: 'barre ez',
  dumbbell: 'halteres',
  kettlebell: 'kettlebell',
  cable: 'poulie',
  smith_machine: 'smith',
  resistance_band: 'elastique', loop_band: 'elastique',
  stability_ball: 'ballon', bosu_ball: 'ballon', medicine_ball: 'ballon', slam_ball: 'ballon', wall_ball: 'ballon',
  plates: 'disque',
  flat_bench: 'banc', incline_bench: 'banc', decline_bench: 'banc',
  treadmill: 'cardio', elliptical: 'cardio', rower: 'cardio', air_bike: 'cardio', stationary_bike: 'cardio',
  stair_climber: 'cardio', stepmill: 'cardio', ski_erg: 'cardio', jump_rope: 'cardio',
  // Barre de traction, station à dips, anneaux, sangles : on travaille avec son poids.
  pull_up_bar: 'poids du corps', dip_station: 'poids du corps', rings: 'poids du corps',
  suspension_trainer: 'poids du corps', climbing_rope: 'poids du corps', plyo_box: 'poids du corps',
  ab_wheel: 'autre', battle_rope: 'autre', sled: 'autre', sandbag: 'autre', hand_gripper: 'autre', wrist_roller: 'autre',
};
const materiel = (r) => {
  if (!r.equipment) return 'poids du corps';
  if (MATERIEL[r.equipment]) return MATERIEL[r.equipment];
  return 'machine';
};

// Famille plus fine pour le filtre « Matériel » (Equipements.fins), quand elle dit plus que la clé ci-dessus.
const MATERIEL_FIN = {
  trap_bar: 'barre trapeze',
  leg_press: 'presse', hack_squat: 'presse', belt_squat: 'presse', pendulum_squat: 'presse',
  pull_up_bar: 'barre de traction', assisted_pullup_machine: 'barre de traction',
  suspension_trainer: 'suspension', rings: 'suspension',
  loop_band: 'mini-bande',
  medicine_ball: 'medecine-ball', slam_ball: 'medecine-ball', wall_ball: 'medecine-ball',
  bosu_ball: 'bosu',
  battle_rope: 'corde ondulatoire',
  ab_wheel: 'roue abdominale',
  jump_rope: 'corde a sauter',
  sled: 'traineau',
};

const CATEGORIE_DU_MUSCLE = {
  pectoraux: 'pectoraux',
  deltoidesAnterieurs: 'epaules', deltoidesLateraux: 'epaules', deltoidesPosterieurs: 'epaules',
  biceps: 'biceps', triceps: 'triceps', avantBras: 'avantBras',
  trapezes: 'dos', grandDorsal: 'dos', rhomboides: 'dos', lombaires: 'dos',
  abdominaux: 'abdos', obliques: 'abdos',
  fessiers: 'fessiers', abducteurs: 'fessiers',
  quadriceps: 'jambes', adducteurs: 'jambes',
  ischios: 'ischios', mollets: 'mollets',
};
const CATEGORIE_DE_LA_ZONE = {
  chest: 'pectoraux', back: 'dos', shoulders: 'epaules', core: 'abdos', upper_arms: 'biceps',
  lower_arms: 'avantBras', upper_legs: 'jambes', lower_legs: 'mollets', full_body: 'completCorps',
};
const MECANIQUE = { compound: 'polyarticulaire', isolation: 'isolation' };
const NIVEAU = { beginner: 'debutant', intermediate: 'intermediaire', advanced: 'avance' };

// Aucun tiret long ni moyen dans l'appli.
const propre = (s) => (s || '').replace(/\s*[—–]\s*/g, ', ').replace(/\s+/g, ' ').trim();
const cle = (s) => (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/\bdb\b/g, 'dumbbell').replace(/\bkb\b/g, 'kettlebell').replace(/\bbb\b/g, 'barbell')
  .replace(/[^a-z0-9]+/g, ' ').replace(/\b(the|a)\b/g, '').replace(/s\b/g, '').replace(/\s+/g, ' ').trim();
const uniques = (liste) => {
  const vus = new Set();
  return liste.filter((x) => x && !vus.has(cle(x)) && vus.add(cle(x)));
};

const pack = JSON.parse(fs.readFileSync(path.join(SOURCE, 'exercises.json'), 'utf8')).exercises;
// Exercices historiques de l'appli : identifiant, nom court, alias, catégorie et suivi, par identifiant du pack.
const identifiants = JSON.parse(fs.readFileSync(IDENTIFIANTS, 'utf8'));
const pris = new Set(Object.values(identifiants).map((v) => v.id));

function muscles(liste) {
  const out = [];
  for (const m of liste || []) {
    const v = MUSCLES[m];
    if (v === undefined) console.warn(`Muscle inconnu : ${m}`);
    if (v && !out.includes(v)) out.push(v);
  }
  return out;
}

function suivi(r, categorie, equipement, vieux) {
  if (vieux?.suivi) return vieux.suivi;
  if (r.category === 'cardio') return 'distanceDuree';
  const maintien = r.force_type === 'static';
  if (r.category === 'stretching' || (maintien && !r.animation)) return 'duree';
  if (maintien && !r.is_bodyweight) return 'poidsDuree';
  if (equipement === 'poids du corps') return categorie === 'abdos' ? 'repsSeules' : 'poidsDuCorpsLeste';
  return 'poidsReps';
}

const idsPris = new Set();
const sortie = [];
for (const r of pack) {
  const vieux = identifiants[r.id];
  let id = vieux?.id ?? r.id;
  // Un identifiant du pack peut être celui d'un autre exercice historique.
  if (!vieux && pris.has(id)) id = `${id}-2`;
  if (idsPris.has(id)) throw new Error(`Identifiant en double : ${id}`);
  idsPris.add(id);

  let principaux = muscles(r.primary_muscles);
  let secondaires = muscles(r.secondary_muscles).filter((m) => !principaux.includes(m));
  if (!principaux.length && secondaires.length) principaux = [secondaires.shift()];
  // Fléchisseurs de hanche seuls : rattachés aux quadriceps (étirements) ou aux abdominaux.
  if (!principaux.length) principaux = [r.category === 'stretching' ? 'quadriceps' : 'abdominaux'];

  const equipement = materiel(r);
  const categorie = vieux?.categorie
    ?? (r.category === 'stretching' ? 'etirements'
      : r.category === 'cardio' ? 'cardio'
        : r.body_part === 'full_body' ? 'completCorps'
          : CATEGORIE_DU_MUSCLE[principaux[0]] ?? CATEGORIE_DE_LA_ZONE[r.body_part] ?? 'completCorps');

  const poses = (r.images?.classic || []).map((p) => `assets/exercises/poses/${r.id}-${p}.webp`);
  const media = {};
  if (r.animation) media.gif = `assets/exercises/anim/${r.id}.webp`;
  if (poses.length) media.imagesLocales = poses;

  const nom = vieux?.nom ?? propre(r.name_fr || r.name_en);
  sortie.push({
    id,
    nom,
    nomEn: r.name_en,
    alias: uniques([...(vieux?.alias || []), propre(r.name_fr), r.name_en, ...(r.synonyms || [])]).filter((a) => cle(a) !== cle(nom)),
    musclesPrincipaux: principaux,
    musclesSecondaires: secondaires,
    equipement,
    materiel: MATERIEL_FIN[r.equipment],
    categorie,
    mecanique: MECANIQUE[r.mechanic],
    niveau: NIVEAU[r.difficulty],
    suivi: suivi(r, categorie, equipement, vieux),
    instructions: (r.instructions_fr || r.instructions_en || []).map(propre),
    conseils: (r.tips_fr || r.tips_en || []).map(propre),
    media,
    source: `repdb:${r.id}`,
  });
}

// Les exercices historiques d'abord (les plus courants), puis le reste par nom.
const rang = new Map(Object.values(identifiants).map((v, i) => [v.id, i]));
sortie.sort((a, b) => (rang.get(a.id) ?? 1e9) - (rang.get(b.id) ?? 1e9) || a.nom.localeCompare(b.nom, 'fr'));

// Chaque média annoncé doit exister.
let manquants = 0;
for (const e of sortie) {
  for (const f of [e.media.gif, ...(e.media.imagesLocales || [])]) {
    if (f && !fs.existsSync(path.join(MOBILE, f))) {
      manquants++;
      if (manquants <= 5) console.warn(`Média absent : ${f}`);
    }
  }
}

fs.writeFileSync(SORTIE, JSON.stringify(sortie));
console.log(`${sortie.length} exercices, dont ${sortie.filter((e) => e.media.gif).length} animés ; `
  + `${Object.keys(identifiants).length} gardent leur identifiant historique ; ${manquants} médias absents.`);
