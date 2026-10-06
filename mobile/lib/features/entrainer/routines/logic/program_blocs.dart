/// Séances types du catalogue de programmes.
///
/// Une ligne par exercice : « rôle identifiant [options] ».
/// Le rôle dit la place de l'exercice dans la séance, et la formule du
/// programme en tire séries, répétitions et repos :
/// B mouvement de base, S second mouvement, I isolation, U abdos,
/// G tenue ou portée, P explosif, H intervalle, C cardio long, E étirement.
///
/// Options, dans n'importe quel ordre : une lettre (a à d) pour un superset,
/// `=4x6-8` pour imposer séries et répétitions, `x3` pour les séries seules,
/// `r90` pour le repos, `w1` pour les échauffements, `@30` pour les secondes.
class Bloc {
  const Bloc(this.nom, this.lignes);
  final String nom;
  final List<String> lignes;
}

// Salle : corps entier.
const fbA = Bloc('Corps entier A', ['B squat', 'B developpe-couche', 'S rowing-barre', 'S developpe-militaire', 'I curl-halteres a', 'I extension-triceps-poulie-haute a', 'G gainage']);
const fbB = Bloc('Corps entier B', ['B souleve-de-terre', 'S developpe-incline-halteres', 'S tirage-vertical', 'S fentes-avant', 'I elevations-laterales', 'U crunch']);
const fbC = Bloc('Corps entier C', ['B presse-a-cuisses', 'S dips-pectoraux', 'S rowing-haltere-unilateral', 'S souleve-de-terre-roumain', 'I face-pull', 'I mollets-debout-machine']);
const fbD = Bloc('Corps entier D', ['B squat-avant', 'B developpe-militaire', 'S tractions', 'S hip-thrust', 'I ecarte-a-la-poulie-vis-a-vis', 'I curl-marteau', 'U releves-de-genoux-suspendu']);

// Salle : pousser, tirer, jambes.
const pushA = Bloc('Push A', ['B developpe-couche', 'S developpe-incline-halteres', 'S developpe-militaire-assis', 'I elevations-laterales', 'I ecarte-a-la-poulie-vis-a-vis', 'I extension-triceps-poulie-haute a', 'I extension-nuque-haltere a']);
const pushB = Bloc('Push B', ['B developpe-militaire', 'S developpe-incline', 'S dips-pectoraux', 'I elevations-laterales-a-la-poulie', 'I pec-deck', 'I barre-au-front', 'I v-bar-tricep-pushdown']);
const pullA = Bloc('Pull A', ['B tractions', 'S rowing-barre', 'S tirage-horizontal', 'I face-pull', 'I shrugs-halteres', 'I curl-barre-ez a', 'I curl-marteau a']);
const pullB = Bloc('Pull B', ['B souleve-de-terre', 'S tirage-vertical', 'S rowing-t-bar', 'I pull-over-poulie-haute', 'I oiseau', 'I curl-incline', 'I curl-pupitre']);
const legsA = Bloc('Legs A', ['B squat', 'S souleve-de-terre-roumain', 'S presse-a-cuisses', 'I leg-curl-assis', 'I leg-extension', 'I mollets-debout-machine', 'U crunch-a-la-poulie']);
const legsB = Bloc('Legs B', ['B hack-squat', 'S hip-thrust', 'S squat-bulgare', 'I leg-curl-allonge', 'I leg-extension', 'I mollets-assis-machine', 'U releves-de-jambes-suspendu']);

// Salle : haut et bas.
const hautA = Bloc('Haut A', ['B developpe-couche', 'B rowing-barre', 'S developpe-militaire', 'S tractions', 'I curl-barre a', 'I extension-triceps-poulie-haute a']);
const hautB = Bloc('Haut B', ['S developpe-incline-halteres w1', 'S tirage-vertical', 'S rowing-haltere-unilateral', 'I elevations-laterales', 'I ecarte-a-la-poulie-vis-a-vis a', 'I oiseau a', 'I curl-incline b', 'I extension-nuque-barre-ez b']);
const basA = Bloc('Bas A', ['B squat', 'S souleve-de-terre-roumain', 'S presse-a-cuisses =3x8-12', 'I leg-curl-allonge', 'I mollets-debout-machine', 'G gainage']);
const basB = Bloc('Bas B', ['B souleve-de-terre', 'S fentes-avant', 'S hip-thrust', 'I leg-extension', 'I leg-curl-assis', 'I mollets-assis-machine', 'U crunch-inverse']);
const hautLourd = Bloc('Haut B', ['B developpe-militaire', 'B tractions-lestees', 'S developpe-couche-prise-serree', 'S rowing-haltere-unilateral', 'I face-pull', 'I curl-barre a', 'I barre-au-front a']);
const basLourd = Bloc('Bas B', ['B souleve-de-terre', 'S squat-avant', 'S fentes-avant', 'I leg-curl-assis', 'I mollets-debout-machine', 'U releves-de-jambes-suspendu']);

// Salle : un ou deux groupes par séance.
const pecs = Bloc('Pectoraux', ['B developpe-couche', 'S developpe-incline-halteres', 'S dips-pectoraux', 'I ecarte-a-la-poulie-vis-a-vis', 'I pec-deck']);
const pecsB = Bloc('Pectoraux, haut du torse', ['B developpe-incline', 'S developpe-couche-halteres', 'S developpe-decline', 'I ecarte-incline-halteres', 'I cable-chest-press', 'I pull-over-haltere']);
const dos = Bloc('Dos', ['B tractions', 'S rowing-barre', 'S tirage-vertical', 'S tirage-horizontal', 'I shrugs-halteres']);
const dosB = Bloc('Dos et soulevé de terre', ['B souleve-de-terre', 'S tractions-prise-large', 'S rowing-t-bar', 'S tirage-vertical-prise-serree', 'I pull-over-poulie-haute', 'I extensions-lombaires']);
const dosSansTerre = Bloc('Dos', ['B rowing-barre', 'S tractions-prise-large', 'S rowing-t-bar', 'S tirage-vertical-prise-serree', 'I pull-over-poulie-haute', 'I extensions-lombaires']);
const epaules = Bloc('Épaules', ['B developpe-militaire', 'S developpe-arnold', 'I elevations-laterales', 'I elevations-laterales-a-la-poulie', 'I oiseau', 'I face-pull']);
const epaulesB = Bloc('Épaules, arrière et côtés', ['B developpe-halteres-assis', 'S rowing-menton-halteres', 'I elevations-laterales-machine', 'I oiseau-halteres-assis', 'I rotation-externe-a-la-poulie', 'I shrugs-halteres']);
const jambes = Bloc('Jambes', ['B squat', 'S presse-a-cuisses', 'S souleve-de-terre-roumain', 'I leg-extension', 'I leg-curl-allonge', 'I mollets-debout-machine']);
const quads = Bloc('Quadriceps', ['B squat', 'S hack-squat', 'S fentes-avant', 'S close-stance-leg-press', 'I leg-extension', 'I mollets-debout-machine']);
const ischiosFessiers = Bloc('Ischios et fessiers', ['B souleve-de-terre-roumain', 'S hip-thrust', 'I nordic-curl', 'I leg-curl-allonge', 'I extensions-lombaires', 'I pull-through-a-la-poulie']);
const bras = Bloc('Bras', ['S curl-barre a', 'S barre-au-front a', 'I curl-incline b', 'I extension-triceps-poulie-haute b', 'I curl-marteau c', 'I kickback-haltere c']);
const brasA = Bloc('Bras, biceps d’abord', ['S curl-barre', 'S developpe-couche-prise-serree', 'I curl-incline', 'I extension-triceps-poulie-haute', 'I curl-pupitre', 'I extension-nuque-haltere', 'I curl-poignets']);
const brasB = Bloc('Bras, triceps d’abord', ['S barre-au-front', 'S curl-barre-ez', 'I dips-sur-banc', 'I curl-concentre', 'I v-bar-tricep-pushdown', 'I curl-marteau', 'I curl-inverse']);
const pecsTriceps = Bloc('Pectoraux et triceps', ['B developpe-couche', 'S developpe-incline-halteres', 'S developpe-couche-prise-serree', 'I ecarte-couche-halteres', 'I extension-triceps-poulie-haute', 'I extension-nuque-haltere']);
const dosBiceps = Bloc('Dos et biceps', ['B tractions', 'S rowing-barre', 'S tirage-horizontal', 'I pull-over-poulie-haute', 'I curl-barre-ez', 'I curl-marteau']);
const epaulesAbdos = Bloc('Épaules et abdos', ['B developpe-militaire', 'S developpe-halteres-assis', 'I elevations-laterales', 'I oiseau', 'I shrugs-barre', 'U crunch-a-la-poulie', 'U releves-de-genoux-suspendu', 'G gainage']);
const pecsDos = Bloc('Pectoraux et dos', ['B developpe-couche', 'B tractions-prise-large', 'S developpe-incline-halteres a', 'S rowing-barre a', 'I ecarte-couche-halteres b', 'I pull-over-haltere b']);
const epaulesBras = Bloc('Épaules et bras', ['B developpe-arnold', 'I elevations-laterales', 'I oiseau', 'I curl-barre a', 'I extension-nuque-barre-ez a', 'I curl-incline b', 'I v-bar-tricep-pushdown b']);
const torse = Bloc('Torse', ['B developpe-couche', 'B rowing-t-bar', 'S developpe-incline-halteres', 'S tirage-vertical', 'I pec-deck', 'I face-pull']);
const membres = Bloc('Membres', ['B squat', 'S souleve-de-terre-roumain', 'I leg-extension', 'I mollets-debout-machine', 'I elevations-laterales', 'I curl-barre-ez a', 'I barre-au-front a']);
const anterieur = Bloc('Chaîne antérieure', ['B squat-avant', 'B developpe-couche', 'S developpe-militaire', 'I leg-extension', 'I elevations-laterales', 'I extension-triceps-poulie-haute', 'U crunch-a-la-poulie']);
const posterieur = Bloc('Chaîne postérieure', ['B souleve-de-terre', 'S tractions', 'S rowing-barre', 'I leg-curl-allonge', 'I face-pull', 'I curl-barre', 'I mollets-debout-machine']);
const posterieurB = Bloc('Chaîne postérieure B', ['B souleve-de-terre-roumain', 'S tirage-vertical', 'S rowing-haltere-unilateral', 'I leg-curl-assis', 'I oiseau', 'I curl-marteau', 'I mollets-assis-machine']);
const carrure = Bloc('Dos et épaules', ['B tractions-prise-large', 'S rowing-barre', 'S developpe-militaire', 'S tirage-horizontal', 'I elevations-laterales', 'I oiseau', 'I face-pull']);
const carrureB = Bloc('Épaules et dos', ['B developpe-halteres-assis', 'S tirage-vertical-prise-serree', 'S rowing-haltere-unilateral', 'I elevations-laterales-a-la-poulie', 'I pull-over-poulie-haute', 'I oiseau-halteres-assis', 'I shrugs-halteres']);
const abdosSalle = Bloc('Abdos chargés', ['U crunch-a-la-poulie', 'U roue-abdominale', 'U releves-de-jambes-suspendu', 'U pallof-press', 'G gainage']);
const poigne = Bloc('Poigne', ['S curl-poignets', 'S curl-inverse', 'G marche-du-fermier', 'G dead-hang', 'G pince-au-disque']);

// Volume allemand : les deux premiers exercices en dix séries de dix.
const dixA = Bloc('Pectoraux et dos', ['B developpe-couche', 'B rowing-barre', 'I ecarte-incline-halteres', 'I oiseau']);
const dixB = Bloc('Jambes et abdos', ['B squat', 'B leg-curl-allonge', 'I mollets-assis-machine', 'U crunch-a-la-poulie']);
const dixC = Bloc('Bras et épaules', ['B developpe-couche-prise-serree', 'B curl-incline', 'I elevations-laterales', 'I oiseau']);

// Salle : machines et barre guidée.
const machinesA = Bloc('Machines A', ['B presse-a-cuisses', 'S developpe-couche-machine', 'S tirage-vertical', 'I elevations-laterales-machine', 'I leg-curl-assis', 'U crunch-machine']);
const machinesB = Bloc('Machines B', ['B hack-squat', 'S developpe-epaules-machine', 'S tirage-horizontal', 'I pec-deck', 'I leg-curl-allonge', 'I machine-bicep-curl a', 'I extension-triceps-machine a']);
const machinesHaut = Bloc('Haut aux machines', ['S developpe-couche-machine w1', 'S tirage-vertical', 'S developpe-epaules-machine', 'S tirage-horizontal', 'I pec-deck', 'I machine-bicep-curl a', 'I extension-triceps-machine a']);
const machinesBas = Bloc('Bas aux machines', ['B presse-a-cuisses', 'I leg-extension', 'I leg-curl-assis', 'I abducteurs-machine', 'I adducteurs-machine', 'I mollets-assis-machine', 'U crunch-machine']);
const machinesHautB = Bloc('Haut aux machines B', ['S developpe-epaules-machine w1', 'S v-bar-lat-pulldown', 'S machine-chest-fly', 'S tirage-horizontal-prise-large', 'I elevations-laterales-machine', 'I face-pull', 'I curl-pupitre-machine a', 'I extension-triceps-machine a']);
const machinesBasB = Bloc('Bas aux machines B', ['B hack-squat', 'S single-leg-press', 'I leg-curl-allonge', 'I leg-extension', 'I machine-a-fessiers', 'I mollets-debout-machine', 'U crunch-a-la-poulie']);
const machinesPush = Bloc('Pousser', ['S developpe-couche-machine w1', 'S developpe-epaules-machine', 'I machine-chest-fly', 'I elevations-laterales-machine', 'I extension-triceps-machine']);
const machinesPull = Bloc('Tirer', ['S tirage-vertical w1', 'S tirage-horizontal', 'I face-pull', 'I shrugs-machine', 'I curl-pupitre-machine', 'I curl-poulie-basse']);
const machinesLegs = Bloc('Jambes', ['B hack-squat', 'S presse-a-cuisses', 'I leg-extension', 'I leg-curl-allonge', 'I machine-a-fessiers', 'I mollets-debout-machine']);
const guideeA = Bloc('Barre guidée A', ['B squat-a-la-smith', 'B developpe-couche-a-la-smith', 'S smith-machine-bent-over-row', 'S developpe-epaules-a-la-smith', 'I mollets-a-la-smith', 'G gainage']);
const guideeB = Bloc('Barre guidée B', ['B smith-machine-rdl', 'S squat-bulgare-a-la-smith', 'S smith-machine-incline-bench-press', 'S tirage-vertical', 'S hip-thrust-a-la-smith', 'I shrugs-a-la-smith']);
const guideA = Bloc('Renforcement A', ['B presse-a-cuisses', 'S developpe-couche-machine', 'S tirage-vertical', 'I leg-curl-assis', 'I elevations-laterales', 'G gainage']);
const guideB = Bloc('Renforcement B', ['B squat-goblet', 'S developpe-incline-halteres', 'S tirage-horizontal', 'S souleve-de-terre-roumain-halteres', 'I face-pull', 'U crunch']);

// Salle à la maison : une barre, un banc, un support.
const rackA = Bloc('Barre A', ['B squat', 'B developpe-couche', 'S rowing-barre', 'S souleve-de-terre-roumain', 'I curl-barre', 'G gainage']);
const rackB = Bloc('Barre B', ['B souleve-de-terre', 'B developpe-militaire', 'S fentes-barre', 'S tractions-australiennes', 'I developpe-couche-prise-serree', 'U crunch']);
const rackC = Bloc('Barre C', ['B squat-avant', 'S developpe-incline', 'S rowing-pendlay', 'S good-morning =3x8-10', 'I barre-au-front', 'I mollets-barre-debout']);

// Force.
const jourSquat = Bloc('Jour squat', ['B squat', 'S pause-squat', 'S souleve-de-terre-roumain', 'I leg-extension', 'I leg-curl-allonge', 'G gainage']);
const jourCouche = Bloc('Jour développé couché', ['B developpe-couche', 'S developpe-couche-prise-serree', 'S rowing-barre', 'I extension-triceps-poulie-haute', 'I face-pull']);
const jourTerre = Bloc('Jour soulevé de terre', ['B souleve-de-terre', 'S souleve-de-terre-roumain =3x6-8', 'S tractions', 'S hip-thrust =3x8-12', 'I leg-curl-assis', 'U releves-de-jambes-suspendu']);
const jourMilitaire = Bloc('Jour développé militaire', ['B developpe-militaire', 'S push-press', 'S tractions-supination', 'I elevations-laterales', 'I curl-barre', 'I barre-au-front']);
const coucheVolume = Bloc('Développé couché, volume', ['B paused-bench-press =4x4-6 r180 w2', 'S developpe-incline-halteres', 'S rowing-haltere-unilateral', 'S tirage-vertical', 'I barre-au-front', 'I face-pull']);
const squatVolume = Bloc('Squat, volume', ['B squat-avant', 'S squat-bulgare', 'S souleve-de-terre-roumain', 'I leg-curl-assis', 'I extensions-lombaires', 'G gainage']);
const forceA = Bloc('Force A', ['B squat', 'B developpe-couche w1', 'B rowing-pendlay w1']);
const forceB = Bloc('Force B', ['B souleve-de-terre', 'B developpe-militaire w1', 'B tractions-lestees']);
const halteroA = Bloc('Épaulé-jeté', ['B epaule-jete', 'B squat-avant', 'S hang-power-clean', 'S push-jerk', 'G gainage']);
const halteroB = Bloc('Arraché', ['B arrache', 'S muscle-snatch', 'S squat-bras-tendus', 'S souleve-de-terre-roumain', 'U releves-de-jambes-suspendu']);
const porterA = Bloc('Soulever et porter', ['B souleve-de-terre-trap-bar', 'S push-press =3x3-5 w1', 'G marche-du-fermier', 'G suitcase-carry @30', 'G dead-hang @25']);
const porterB = Bloc('Pousser et porter', ['B squat-avant', 'B developpe-militaire w1', 'S rowing-t-bar', 'G dumbbell-farmers-walk', 'G db-overhead-carry @30', 'U releves-de-jambes-suspendu']);

// Haltères.
const halteresA = Bloc('Haltères A', ['B squat-halteres', 'B developpe-couche-halteres', 'S rowing-haltere-unilateral', 'S developpe-halteres-assis', 'I curl-halteres a', 'I extension-nuque-haltere a', 'G gainage']);
const halteresB = Bloc('Haltères B', ['B souleve-de-terre-roumain-halteres', 'S developpe-incline-halteres', 'S rowing-halteres-buste-penche', 'S fentes-avant', 'I elevations-laterales', 'I mollets-debout-halteres', 'U crunch-velo']);
const halteresC = Bloc('Haltères C', ['B fentes-arriere', 'S developpe-au-sol-halteres', 'S rowing-halteres-sur-banc-incline', 'S dumbbell-hip-thrust', 'I oiseau', 'I curl-marteau', 'U russian-twist']);
const halteresHaut = Bloc('Haut aux haltères', ['B developpe-couche-halteres', 'S rowing-haltere-unilateral', 'S developpe-halteres-assis', 'S rowing-halteres-buste-penche', 'I elevations-laterales', 'I curl-incline a', 'I extension-triceps-couche-halteres a']);
const halteresBas = Bloc('Bas aux haltères', ['B squat-halteres', 'S souleve-de-terre-roumain-halteres', 'S fentes-arriere', 'S dumbbell-hip-thrust', 'I mollets-debout-halteres', 'U crunch-inverse']);
const halteresPush = Bloc('Pousser', ['B developpe-couche-halteres', 'S developpe-incline-halteres', 'S developpe-halteres-assis', 'I elevations-laterales', 'I ecarte-couche-halteres', 'I extension-nuque-haltere']);
const halteresPull = Bloc('Tirer', ['B rowing-haltere-unilateral', 'S rowing-halteres-buste-penche', 'S pull-over-haltere', 'I oiseau', 'I curl-halteres', 'I curl-marteau']);
const halteresLegs = Bloc('Jambes', ['B squat-halteres', 'S souleve-de-terre-roumain-halteres', 'S squat-bulgare', 'S dumbbell-hip-thrust', 'I mollets-debout-halteres', 'G gainage']);
const sansBancA = Bloc('Sans banc A', ['B dumbbell-front-squat', 'S developpe-au-sol-halteres', 'S rowing-halteres-buste-penche', 'S developpe-halteres-debout', 'I curl-halteres', 'G gainage']);
const sansBancB = Bloc('Sans banc B', ['B souleve-de-terre-roumain-halteres', 'S fentes-arriere', 'S push-press-halteres', 'S rowing-menton-halteres', 'I elevations-laterales', 'U russian-twist']);
const halteresCircuit = Bloc('Enchaînement haltères', ['S dumbbell-front-squat', 'S push-press-halteres', 'S rowing-halteres-buste-penche', 'S fentes-arriere', 'S one-arm-dumbbell-swing', 'U russian-twist', 'H mountain-climbers']);
const halteresCircuitB = Bloc('Enchaînement haltères B', ['S souleve-de-terre-roumain-halteres', 'S developpe-au-sol-halteres', 'S squat-sumo-haltere', 'S rowing-menton-halteres', 'S arrache-haltere =3x8 r60', 'U crunch-velo', 'H high-knees']);

// Poids du corps, à la maison.
const maisonA = Bloc('Maison A', ['B pompes', 'B squat-au-poids-du-corps', 'S pont-fessier', 'S pike-push-ups', 'G gainage']);
const maisonB = Bloc('Maison B', ['B fentes-au-poids-du-corps', 'S pompes-prise-serree', 'S squat-saute', 'I extensions-lombaires-au-sol', 'U crunch-velo']);
const maisonDebutA = Bloc('Premiers pas A', ['S pompes-sur-les-genoux', 'S squat-au-poids-du-corps', 'S pont-fessier', 'I bird-dog', 'G gainage']);
const maisonDebutB = Bloc('Premiers pas B', ['S pompes-inclinees', 'S fente-statique', 'S bodyweight-good-morning', 'U dead-bug', 'G chaise-au-mur']);
const maisonHaut = Bloc('Haut du corps', ['B pompes', 'S pike-push-ups', 'S pompes-declinees', 'S dips-sur-banc', 'I extensions-lombaires-au-sol', 'G reverse-plank', 'G gainage']);
const maisonBas = Bloc('Bas du corps', ['B fentes-marchees', 'S squat-saute', 'S pont-fessier-unilateral', 'S squat-cosaque', 'I mollets-unilateral', 'G chaise-au-mur']);
const maisonBasDebut = Bloc('Cuisses et fessiers', ['S squat-au-poids-du-corps', 'S fente-statique', 'S pont-fessier', 'I mollets-au-poids-du-corps', 'G chaise-au-mur @30']);
const maisonDos = Bloc('Dos et gainage', ['S extensions-lombaires-au-sol', 'S bird-dog', 'S pont-fessier-unilateral', 'S pilates-leg-pull-back', 'G reverse-plank', 'G gainage-lateral']);
const maisonAbdosA = Bloc('Abdos A', ['U crunch', 'U crunch-inverse', 'U russian-twist', 'G gainage', 'G gainage-lateral']);
const maisonAbdosB = Bloc('Abdos B', ['U crunch-velo', 'U dead-bug', 'U releves-de-jambes-allonge', 'U scissor-kicks', 'G high-plank']);
const maisonIntervalles = Bloc('Intervalles au chrono', ['H high-knees', 'H mountain-climbers', 'H heel-flicks', 'H marche-de-l-ours', 'H battements-de-jambes', 'G gainage']);
const maisonRafales = Bloc('Séries rapides', ['H jumping-jacks =3x30', 'H squat-saute =3x10-12', 'H pompes =3x8-12', 'H plyo-lunge =3x8-10', 'H burpees =3x8-10', 'H crunch-velo =3x20']);
const maisonSilence = Bloc('Sans saut A', ['S squat-au-poids-du-corps', 'S pompes', 'S bodyweight-reverse-lunge', 'S pont-fessier', 'I bird-dog', 'G gainage', 'G chaise-au-mur']);
const maisonSilenceB = Bloc('Sans saut B', ['S pompes-inclinees', 'S fente-statique', 'S pont-fessier-unilateral', 'I extensions-lombaires-au-sol', 'U dead-bug', 'G gainage-lateral @20']);
const maisonPompes = Bloc('Pompes', ['B pompes', 'S pike-push-ups =3x5-10', 'S pompes-declinees', 'S pompes-diamant', 'I pompes-prise-large =2x12-20', 'G high-plank']);
const maisonSquats = Bloc('Squats', ['B squat-au-poids-du-corps =4x15-25', 'S squat-saute', 'S fentes-marchees', 'S fentes-laterales', 'I pont-fessier-unilateral', 'G chaise-au-mur']);
const maisonFessiers = Bloc('Fessiers au sol', ['S pont-fessier-unilateral', 'S bodyweight-reverse-lunge', 'I kickback-au-sol', 'I clamshells', 'I abduction-debout', 'I side-plank-leg-lift', 'G glute-bridge-hold']);
const vingtA = Bloc('20 minutes A', ['S squat-au-poids-du-corps', 'S pompes-inclinees', 'S pont-fessier', 'G gainage']);
const vingtB = Bloc('20 minutes B', ['S fente-statique', 'S pompes-sur-les-genoux', 'I bird-dog', 'G chaise-au-mur']);
const vingtC = Bloc('20 minutes C', ['S bodyweight-reverse-lunge', 'S dips-sur-banc', 'U dead-bug', 'G gainage-lateral @20']);
const porteA = Bloc('Barre de porte A', ['B tractions', 'B pompes', 'S tractions-australiennes', 'S pike-push-ups', 'U releves-de-genoux-suspendu', 'G dead-hang']);
const porteB = Bloc('Barre de porte B', ['B tractions-supination', 'S pompes-declinees', 'S fentes-marchees', 'S pont-fessier-unilateral', 'I tractions-scapulaires', 'G gainage']);

// Kettlebell.
const kettlebellA = Bloc('Balancé et squat', ['B kettlebell-swing', 'B squat-goblet', 'S developpe-kettlebell', 'S rowing-kettlebell', 'G suitcase-carry @30', 'G gainage']);
const kettlebellB = Bloc('Soulevé et fentes', ['B kettlebell-deadlift', 'S kettlebell-goblet-lunge', 'S kettlebell-floor-press', 'S rowing-kettlebell', 'I kettlebell-halo', 'U kettlebell-russian-twist']);
const kettlebellC = Bloc('Un bras', ['S turkish-get-up', 'S one-arm-kettlebell-swing', 'S kettlebell-reverse-lunge', 'S push-press-kettlebell-a-un-bras', 'S rowing-kettlebell', 'S kettlebell-swing-clean =3x6-8']);
const kettlebellDebutA = Bloc('Les bases A', ['S kettlebell-deadlift', 'S squat-goblet', 'S kettlebell-floor-press', 'S rowing-kettlebell', 'G gainage']);
const kettlebellDebutB = Bloc('Les bases B', ['S kettlebell-deadlift =2x10', 'S kettlebell-swing', 'S kettlebell-goblet-lunge', 'S developpe-kettlebell', 'G suitcase-carry @30']);
const kettlebellComplexeA = Bloc('Enchaînement A', ['S kettlebell-swing =4x15 r45', 'S squat-goblet =4x12 r45', 'S developpe-kettlebell =4x8 r45', 'S rowing-kettlebell =4x10 r45', 'H mountain-climbers']);
const kettlebellComplexeB = Bloc('Enchaînement B', ['S kettlebell-swing-clean =4x8 r45', 'S kettlebell-goblet-lunge =4x10 r45', 'S push-press-kettlebell-a-un-bras =4x8 r45', 'S kettlebell-deadlift =4x12 r45', 'G suitcase-carry @30']);
const kettlebellDouble = Bloc('Double kettlebell', ['B double-kettlebell-clean-and-press =4x4-6 r150', 'B one-arm-kettlebell-front-squat =4x6-8 r120', 'S double-kettlebell-row', 'S kettlebell-sumo-deadlift', 'S double-kettlebell-push-press', 'G marche-du-fermier']);

// Élastiques.
const elastiquesA = Bloc('Élastiques A', ['S squat-a-l-elastique', 'S banded-romanian-deadlift', 'S pompes', 'S ecartes-a-l-elastique', 'S curl-a-l-elastique', 'G gainage']);
const elastiquesB = Bloc('Élastiques B', ['S banded-hip-thrust', 'S banded-good-morning', 'S marche-laterale-a-l-elastique', 'S pompes-inclinees', 'I ecartes-a-l-elastique', 'U crunch-velo']);
const elastiquesFessiers = Bloc('Fessiers à l’élastique', ['S banded-hip-thrust', 'S pont-fessier-a-l-elastique', 'I banded-clamshell', 'I banded-fire-hydrant', 'I banded-sumo-walk', 'I abduction-a-l-elastique-assis', 'I hip-thrust-a-genoux-a-l-elastique']);
const elastiquesCuisses = Bloc('Cuisses et fessiers', ['S squat-a-l-elastique', 'S banded-romanian-deadlift', 'S bodyweight-reverse-lunge', 'S banded-good-morning', 'I marche-laterale-a-l-elastique', 'I banded-standing-hip-abduction']);

// Barres, dips, sangles et anneaux.
const barrePush = Bloc('Pousser', ['B dips-pectoraux', 'S pseudo-planche-push-ups', 'S pike-push-ups', 'S pompes-declinees', 'I pompes-diamant', 'G l-sit']);
const barrePull = Bloc('Tirer', ['B tractions', 'S tractions-supination', 'S tractions-australiennes', 'I tractions-scapulaires', 'U releves-de-jambes-suspendu', 'G dead-hang']);
const barreLegs = Bloc('Jambes', ['P squat-saute =3x6-8', 'B pistol-squat', 'S fentes-marchees', 'I nordic-curl', 'I mollets-unilateral', 'G chaise-au-mur']);
const barreComplet = Bloc('Barre et dips', ['B tractions', 'B dips-pectoraux', 'S tractions-australiennes', 'S pompes', 'U releves-de-genoux-suspendu', 'G gainage']);
const barreDebut = Bloc('Bases à la barre', ['S negative-pull-ups', 'S tractions-australiennes', 'S pompes', 'S dips-sur-banc', 'G dead-hang', 'G gainage']);
const barreFigures = Bloc('Figures', ['B muscle-up', 'G front-lever', 'G planche', 'S pompes-en-equilibre', 'S tractions-archer', 'U toes-to-bar', 'G l-sit']);
const figuresTirer = Bloc('Tirage lourd', ['B tractions-lestees =4x4-6 r150', 'S tractions-archer', 'S tractions-australiennes', 'G front-lever', 'U toes-to-bar', 'G dead-hang']);
const figuresPousser = Bloc('Poussée lourde', ['B dips-lestes =4x4-6 r150', 'S pompes-en-equilibre', 'S pseudo-planche-push-ups', 'S pike-push-ups', 'G planche', 'G l-sit']);
const barreTractions = Bloc('Vers la traction', ['S negative-pull-ups', 'S tractions-assistees-a-l-elastique', 'S tractions-australiennes', 'I tractions-scapulaires', 'G dead-hang @25']);
const barreLeste = Bloc('Lesté', ['B tractions-lestees', 'B dips-lestes', 'S tractions-supination', 'S pompes-declinees =3x12-20 r75', 'U releves-de-jambes-suspendu']);
const jambesAthlete = Bloc('Jambes', ['P squat-saute =4x5', 'B pistol-squat', 'S squat-bulgare =3x8-12', 'I nordic-curl', 'I mollets-unilateral']);
const sanglesA = Bloc('Sangles A', ['S trx-chest-press', 'S trx-row', 'S trx-squat', 'S trx-lunge', 'I trx-bicep-curl', 'I trx-tricep-extension', 'G trx-plank']);
const sanglesB = Bloc('Sangles B', ['S trx-pistol-squat', 'S trx-hamstring-curl', 'S trx-face-pull', 'S trx-chest-press', 'I trx-y-fly', 'G trx-side-plank']);
const anneaux = Bloc('Anneaux', ['B dips-aux-anneaux', 'B tractions', 'S ring-push-up', 'S ring-row', 'I ring-face-pull', 'G ring-dead-hang']);

// Fessiers.
const fessiersA = Bloc('Fessiers A', ['B hip-thrust', 'S squat-bulgare', 'S fentes-arriere-barre', 'I kickback-fessier-a-la-poulie', 'I abducteurs-machine', 'I machine-a-fessiers']);
const fessiersB = Bloc('Fessiers B', ['B sumo-squat', 'S souleve-de-terre-roumain', 'S pull-through-a-la-poulie', 'S high-foot-leg-press =3x10-12 r120', 'I leg-curl-assis', 'I extensions-lombaires']);
const fessiersC = Bloc('Fessiers C', ['B souleve-de-terre-sumo', 'S hip-thrust-a-la-smith', 'S single-leg-press', 'S step-up', 'I kickback-fessier-a-la-poulie', 'I abducteurs-machine']);

// Sèche, circuits et cardio.
const secheA = Bloc('Sèche A', ['B squat-goblet', 'S developpe-couche-halteres a', 'S tirage-horizontal a', 'S fentes-arriere', 'I elevations-laterales', 'H rameur']);
const secheB = Bloc('Sèche B', ['B souleve-de-terre-roumain', 'S developpe-militaire-assis a', 'S tirage-vertical a', 'S step-up', 'U crunch-a-la-poulie', 'H air-bike']);
const secheC = Bloc('Sèche C', ['B presse-a-cuisses', 'S pompes a', 'S rowing-haltere-unilateral a', 'S hip-thrust', 'I face-pull', 'H corde-a-sauter']);
const circuitA = Bloc('Circuit A', ['S squat-goblet', 'S developpe-couche-halteres', 'S tirage-horizontal', 'S kettlebell-swing =3x15 r30', 'S push-press-halteres', 'H rameur', 'G gainage']);
const circuitB = Bloc('Circuit B', ['S dumbbell-front-squat', 'S rowing-kettlebell', 'S fentes-arriere', 'S pompes-inclinees', 'S slam-ball', 'H battle-rope', 'U crunch-velo']);
const intervallesSalle = Bloc('Intervalles', ['C velo-d-appartement @300', 'H air-bike', 'H rameur', 'H skierg', 'H battle-rope', 'H corde-a-sauter']);
const cardioA = Bloc('Cardio doux', ['C marche-inclinee-sur-tapis', 'C velo-d-appartement', 'C velo-elliptique']);
const cardioB = Bloc('Cardio soutenu', ['C rameur', 'C course-sur-tapis', 'H corde-a-sauter']);
const cardioC = Bloc('Cardio varié', ['C velo-elliptique', 'C stepper', 'C rameur']);
const cardioLong = Bloc('Cardio long', ['C rameur @900', 'C velo-elliptique @900']);
const marcheInclinee = Bloc('Marche inclinée', ['C marche-inclinee-sur-tapis @1800']);
const courseFacile = Bloc('Footing', ['C walking @300', 'C course @1200']);
const courseFractionnee = Bloc('Fractionné', ['C walking @300', 'H course x6 @60 r90']);
const courseLongue = Bloc('Sortie longue', ['C course @1800']);

// Renfort pour un sport.
const courseA = Bloc('Renfort A', ['B squat-goblet', 'S fentes-marchees', 'S souleve-de-terre-roumain-halteres', 'I mollets-debout-machine', 'I leg-curl-assis', 'G gainage', 'G gainage-lateral']);
const courseB = Bloc('Renfort B', ['S step-up', 'S pont-fessier-unilateral', 'S squat-bulgare', 'I mollets-unilateral', 'I banded-terminal-knee-extension', 'U dead-bug', 'G chaise-au-mur']);
const explosifA = Bloc('Explosif A', ['P box-jump', 'P epaule', 'B squat', 'S push-press', 'S souleve-de-terre-roumain', 'G gainage']);
const explosifB = Bloc('Explosif B', ['P squat-saute =4x5', 'P pompes-claquees', 'B souleve-de-terre-trap-bar', 'S tractions', 'S fentes-barre', 'U releves-de-jambes-suspendu']);
const footballA = Bloc('Appuis et détente', ['P box-jump', 'B squat', 'S fentes-laterales', 'S step-up', 'I adducteurs-machine', 'I mollets-debout-machine', 'G gainage']);
const footballB = Bloc('Sprint et ischios', ['P plyo-lunge =3x6-8', 'B souleve-de-terre-trap-bar', 'S squat-bulgare', 'I nordic-curl =2x5-6', 'I banded-standing-hip-adduction', 'G gainage-lateral', 'G side-plank-leg-lift-hold @20']);
const combat = Bloc('Frapper fort', ['P pompes-claquees', 'S tractions', 'S landmine-press', 'S rowing-haltere-unilateral', 'U russian-twist', 'U pallof-press', 'H battle-rope']);
const combatCircuit = Bloc('Tenir les rounds', ['S kettlebell-swing =4x12-15 r45', 'S pompes =4x12-15 r45', 'S slam-ball =4x10 r45', 'S tractions-australiennes =4x10 r45', 'U russian-twist', 'H corde-a-sauter x3 @180 r60']);
const natationA = Bloc('Tirage du nageur', ['S tirage-vertical w1', 'S pull-over-poulie-haute', 'S developpe-halteres-assis', 'I rotation-externe-a-la-poulie', 'I face-pull', 'I extension-triceps-poulie-haute', 'G hollow-body-hold', 'G battements-de-jambes']);
const natationB = Bloc('Épaules et gainage', ['S developpe-incline-halteres w1', 'S tirage-horizontal', 'S squat-goblet', 'I oiseau', 'I ecartes-a-l-elastique', 'G gainage', 'G reverse-plank']);
const cyclismeA = Bloc('Puissance des jambes', ['B presse-a-cuisses', 'S squat-bulgare', 'S souleve-de-terre-roumain', 'I leg-curl-assis', 'I mollets-assis-machine', 'I extensions-lombaires', 'G gainage']);
const cyclismeB = Bloc('Hanches et tronc', ['B squat-goblet', 'S step-up', 'S hip-thrust', 'S rowing-haltere-unilateral', 'G gainage-lateral', 'G bird-dog-hold @20']);
const skiA = Bloc('Cuisses du skieur', ['B squat-goblet', 'S fentes-laterales', 'S squat-cosaque', 'I adducteurs-machine', 'G chaise-au-mur', 'G gainage-lateral']);
const skiB = Bloc('Rebond et endurance', ['P squat-saute =3x8', 'B presse-a-cuisses', 'S fentes-arriere', 'I leg-curl-assis', 'I mollets-debout-machine', 'U russian-twist', 'G chaise-au-mur']);
const raquetteA = Bloc('Rotation et épaule', ['S landmine-press', 'S tirage-horizontal-unilateral', 'S fentes-laterales', 'I rotation-externe-a-la-poulie', 'I curl-poignets-haltere', 'U pallof-press', 'U russian-twist']);
const raquetteB = Bloc('Appuis latéraux', ['P squat-saute =3x6-8', 'S squat-cosaque', 'S step-up', 'S developpe-halteres-assis', 'I face-pull', 'I mollets-unilateral', 'G gainage-lateral']);
const escaladeA = Bloc('Tirage du grimpeur', ['B tractions', 'S tractions-prise-neutre', 'S rowing-haltere-unilateral', 'I curl-marteau', 'I curl-poignets-inverse-haltere', 'U toes-to-bar', 'G dead-hang']);
const escaladeB = Bloc('Muscles opposés', ['S pompes', 'S developpe-halteres-assis', 'I rotation-externe-a-la-poulie', 'I face-pull', 'I oiseau', 'G reverse-plank', 'G gainage']);
const rugbyA = Bloc('Contact', ['P epaule', 'B souleve-de-terre-trap-bar', 'B developpe-couche w1', 'S rowing-barre', 'I nordic-curl', 'G marche-du-fermier']);
const rugbyB = Bloc('Haut du corps', ['B developpe-militaire', 'S tractions-lestees', 'S developpe-incline-halteres', 'S rowing-haltere-unilateral', 'I face-pull', 'I shrugs-barre']);

// Mobilité, yoga, bien-être.
const mobiliteMatin = Bloc('Réveil', ['E cat-cow', 'E downward-dog', 'E low-lunge', 'E thread-the-needle', 'E standing-side-bend', 'E standing-forward-fold', 'E childs-pose']);
const echauffement = Bloc('Échauffement', ['E cat-cow', 'E leg-swing-front-to-back', 'E lateral-leg-swing', 'E torso-twists', 'E downward-dog-to-low-lunge', 'S squat-au-poids-du-corps =1x15 r30', 'S pompes-inclinees =1x10 r30']);
const etirementsHaut = Bloc('Étirements du haut', ['E doorway-chest-stretch', 'E cross-body-shoulder-stretch', 'E etirement-des-triceps', 'E bench-lat-stretch', 'E etirement-lateral-du-cou', 'E kneeling-wrist-stretch', 'E puppy-pose']);
const etirementsBas = Bloc('Étirements du bas', ['E kneeling-hip-flexor-stretch', 'E standing-quad-stretch', 'E seated-forward-fold', 'E pigeon-stretch', 'E posture-du-papillon', 'E standing-calf-stretch', 'E knee-to-chest-stretch']);
const yogaA = Bloc('Postures debout', ['E mountain-pose', 'E downward-dog', 'E warrior-one', 'E warrior-two', 'E triangle-pose', 'E chair-pose', 'E childs-pose', 'E savasana']);
const yogaB = Bloc('Hanches et dos', ['E cat-cow', 'E low-lunge-to-half-split', 'E crescent-lunge', 'E tree-pose', 'E cobra-stretch', 'E pigeon-stretch', 'E seated-spinal-twist', 'E happy-baby']);
const yogaC = Bloc('Équilibres', ['E downward-dog-pedal', 'E warrior-three', 'E half-moon-pose', 'E cobra-stretch', 'E camel-pose', 'E boat-pose', 'E supine-spinal-twist', 'E legs-up-the-wall']);
const yogaD = Bloc('Force debout', ['E downward-dog-to-low-lunge', 'E warrior-two', 'E extended-side-angle', 'E triangle-pose', 'E pyramid-pose', 'E chair-pose', 'E eagle-pose', 'E childs-pose']);
const yogaE = Bloc('Ouvertures', ['E cat-cow', 'E crescent-lunge', 'E revolved-crescent-lunge', 'E tree-pose', 'E dancer-pose', 'E sphinx', 'E bow-pose', 'E happy-baby']);
const dosSante = Bloc('Dos solide', ['E cat-cow', 'S bird-dog', 'U dead-bug', 'S pont-fessier', 'S extensions-lombaires-au-sol', 'G gainage-lateral @20', 'E childs-pose', 'E knee-to-chest-stretch']);
const dosSanteB = Bloc('Lombaires et hanches', ['E cat-cow', 'U dead-bug', 'S pont-fessier', 'G bird-dog-hold @20', 'G gainage @20', 'E kneeling-hip-flexor-stretch', 'E pigeon-stretch', 'E supine-spinal-twist']);
const posture = Bloc('Posture', ['E doorway-chest-stretch', 'S ecartes-a-l-elastique', 'S bird-dog', 'G chin-tuck-hold', 'E thread-the-needle', 'E etirement-lateral-du-cou', 'E puppy-pose']);
const postureDebout = Bloc('Pause au bureau', ['E standing-side-bend', 'E cross-body-shoulder-stretch', 'E etirement-lateral-du-cou', 'E torso-twists', 'E standing-forward-fold', 'G chin-tuck-hold']);
const pilates = Bloc('Pilates', ['S pont-fessier', 'S pilates-leg-pull-front', 'S pilates-side-bend =2x5-6', 'S pilates-kneeling-side-kick', 'S extensions-lombaires-au-sol', 'U dead-bug', 'E pilates-saw', 'E pilates-spine-stretch-forward']);
const souplesse = Bloc('Hanches', ['E leg-swing-front-to-back', 'E posture-du-papillon', 'E lizard-stretch', 'E pigeon-stretch', 'E low-lunge-to-half-split', 'E seated-straddle-stretch', 'E standing-split']);
const souplesseB = Bloc('Arrière des cuisses', ['E lateral-leg-swing', 'E standing-forward-fold', 'E head-to-knee-pose', 'E seated-forward-fold', 'E wide-legged-forward-fold', 'E pyramid-pose', 'E happy-baby']);
const recuperation = Bloc('Récupération', ['E leg-swing-front-to-back', 'E lateral-leg-swing', 'E torso-twists', 'E cat-stretch', 'E sphinx', 'E happy-baby', 'E supine-spinal-twist', 'E savasana']);
const douceurA = Bloc('En douceur A', ['S box-squat', 'S developpe-couche-machine', 'S tirage-horizontal', 'S step-up', 'I mollets-au-poids-du-corps', 'S heel-to-toe-walk =3x20 r30', 'G tree-pose @30']);
const douceurB = Bloc('En douceur B', ['S presse-a-cuisses', 'S developpe-epaules-machine', 'S tirage-vertical', 'S pont-fessier', 'I leg-curl-assis', 'U dead-bug', 'G tree-pose @30']);
const epaulesSante = Bloc('Coiffe et omoplates', ['S rotation-externe-a-la-poulie', 'S face-pull', 'S ecartes-a-l-elastique', 'S tractions-scapulaires', 'I elevation-laterale-allonge-sur-le-cote', 'E cross-body-shoulder-stretch', 'E doorway-chest-stretch']);

// Quand le temps manque.
const expressA = Bloc('Express A', ['B squat', 'S developpe-couche-halteres a', 'S tirage-horizontal a', 'I elevations-laterales b', 'I leg-curl-assis b']);
const expressB = Bloc('Express B', ['B souleve-de-terre-roumain', 'S developpe-militaire-assis a', 'S tirage-vertical a', 'I leg-extension b', 'I curl-halteres b']);
const expressC = Bloc('Express C', ['B presse-a-cuisses', 'S developpe-incline-halteres a', 'S rowing-haltere-unilateral a', 'I extension-triceps-poulie-haute b', 'I face-pull b']);
const midiA = Bloc('Midi A', ['S developpe-couche-machine a w1', 'S tirage-horizontal a', 'S presse-a-cuisses', 'I leg-curl-assis b', 'I leg-extension b', 'U crunch-machine']);
const midiB = Bloc('Midi B', ['S developpe-epaules-machine a w1', 'S tirage-vertical a', 'S hack-squat', 'I pec-deck b', 'I face-pull b', 'G gainage']);
const maintienA = Bloc('Maintien A', ['B squat', 'B developpe-couche', 'S tirage-vertical', 'S souleve-de-terre-roumain', 'I elevations-laterales']);
const maintienB = Bloc('Maintien B', ['B souleve-de-terre', 'B developpe-militaire', 'S rowing-haltere-unilateral', 'S presse-a-cuisses', 'I curl-halteres a', 'I extension-triceps-poulie-haute a']);
