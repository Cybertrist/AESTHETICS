// Table de synonymes de noms d'exercices en anglais, vérifiée à la main
// contre le catalogue. Elle passe avant tout calcul de ressemblance : un nom
// de cette table ne dépend jamais d'un score.
//
// Trois cas :
// - `sur` : le nom désigne sans ambiguïté un exercice du catalogue ;
// - `proches` : un ou plusieurs exercices voisins, à confirmer (matériel non
//   précisé dans le nom, ou variante absente du catalogue) ;
// - `perso` seul : rien ne convient dans le catalogue, l'exercice est créé
//   comme exercice personnel, déjà rempli.

/// Exercice personnel proposé quand le catalogue n'a pas d'équivalent.
class ModelePerso {
  const ModelePerso(this.nom, {this.muscles = const [], this.equipement});

  /// Nom français de l'exercice à créer.
  final String nom;

  /// Muscles principaux, par nom de valeur de l'enum `Muscle`.
  final List<String> muscles;

  /// Clé de matériel de l'appli (`machine`, `poulie`, `halteres`...).
  final String? equipement;
}

class SynonymeExercice {
  const SynonymeExercice(this.noms, {this.sur, this.proches = const [], this.perso});

  /// Écritures anglaises du même exercice.
  final List<String> noms;

  /// Identifiant du catalogue quand la correspondance est certaine.
  final String? sur;

  /// Identifiants voisins à proposer, le plus plausible d'abord.
  final List<String> proches;

  /// Exercice personnel à créer faute d'équivalent.
  final ModelePerso? perso;

  /// Tous les identifiants cités.
  List<String> get ids => [?sur, ...proches];
}

/// La table. Les noms sont comparés après normalisation, sans tenir compte de
/// l'ordre des mots (« Seated Row Lever » vaut « Lever Seated Row »).
const synonymesExercices = <SynonymeExercice>[
  // Pectoraux
  SynonymeExercice(['Bench Press', 'Barbell Bench Press'], sur: 'developpe-couche'),
  SynonymeExercice(['Dumbbell Bench Press'], sur: 'developpe-couche-halteres'),
  SynonymeExercice(['Smith Bench Press'], sur: 'developpe-couche-a-la-smith'),
  SynonymeExercice(['Lever Chest Press'], sur: 'developpe-couche-machine'),
  SynonymeExercice(['Decline Bench Press'], sur: 'developpe-decline'),
  SynonymeExercice(['Dumbbell Incline Bench Press'], sur: 'developpe-incline-halteres'),
  SynonymeExercice(
    ['Incline Bench Press'],
    proches: ['developpe-incline', 'developpe-incline-halteres', 'smith-machine-incline-bench-press'],
  ),
  SynonymeExercice(['Lever Seated Fly'], sur: 'pec-deck'),
  SynonymeExercice(['Cable Standing Fly'], sur: 'ecarte-a-la-poulie-vis-a-vis'),
  SynonymeExercice(['Chest Dip'], sur: 'dips-pectoraux'),

  // Dos
  SynonymeExercice(['Pull-up'], sur: 'tractions'),
  SynonymeExercice(['Assisted Pull-up'], sur: 'tractions-assistees'),
  SynonymeExercice(['Pulldown', 'Cable Wide-Grip Lat Pulldown'], sur: 'tirage-vertical'),
  SynonymeExercice(['Cable Lateral Pulldown with V-bar'], sur: 'tirage-vertical-prise-serree'),
  SynonymeExercice(['Cable One Arm Lat Pulldown'], sur: 'one-arm-lat-pulldown'),
  SynonymeExercice(['Cable Low Seated Row', 'Cable Seated Row with V bar'], sur: 'tirage-horizontal'),
  SynonymeExercice(
    ['Lever Seated Row'],
    perso: ModelePerso('Rowing assis à la machine', muscles: ['grandDorsal', 'rhomboides'], equipement: 'machine'),
  ),
  SynonymeExercice(
    ['Barbell Narrow Row'],
    proches: ['rowing-barre', 'rowing-t-bar'],
    perso: ModelePerso('Rowing barre prise serrée', muscles: ['grandDorsal', 'rhomboides'], equipement: 'barre'),
  ),
  SynonymeExercice(['One Arm Bent-over Row'], sur: 'rowing-haltere-unilateral'),
  SynonymeExercice(['Dumbbell Hammer Grip Incline Bench Two Arm Row'], sur: 'rowing-halteres-sur-banc-incline'),
  SynonymeExercice(['Incline Row'], proches: ['rowing-halteres-sur-banc-incline']),
  SynonymeExercice(['45 Degree Hyperextension'], sur: 'extensions-lombaires'),
  SynonymeExercice(
    ['Trap Bar Standing Shrug'],
    perso: ModelePerso('Shrugs à la barre hexagonale', muscles: ['trapezes'], equipement: 'barre'),
  ),
  SynonymeExercice(
    ['Suspender Scapular Retraction'],
    perso: ModelePerso('Rétraction scapulaire aux sangles', muscles: ['rhomboides', 'trapezes'], equipement: 'poids du corps'),
  ),

  // Épaules
  SynonymeExercice(['Lever Seated Shoulder Press'], sur: 'developpe-epaules-machine'),
  SynonymeExercice(['Smith Seated Shoulder Press'], sur: 'developpe-epaules-a-la-smith'),
  SynonymeExercice(['Dumbbell Seated Shoulder Press'], sur: 'developpe-halteres-assis'),
  SynonymeExercice(['Lateral Raise'], sur: 'elevations-laterales'),
  SynonymeExercice(['Seated Lateral Raise'], sur: 'seated-dumbbell-lateral-raise'),
  SynonymeExercice(
    ['One Arm Lateral Raise'],
    proches: ['elevations-laterales-a-la-poulie', 'elevations-laterales', 'single-arm-plate-loaded-lateral-raise'],
  ),
  SynonymeExercice(['Dumbbell Front Raise'], sur: 'elevations-frontales-halteres-prise-neutre'),
  SynonymeExercice(['Dumbbell Rear Delt Fly'], sur: 'oiseau'),
  SynonymeExercice(
    ['Lever Seated Reverse Fly'],
    perso: ModelePerso('Oiseau à la machine', muscles: ['deltoidesPosterieurs', 'rhomboides'], equipement: 'machine'),
  ),
  SynonymeExercice(
    ['Dumbbell Incline Y-Raise'],
    perso: ModelePerso('Élévations en Y sur banc incliné', muscles: ['trapezes', 'deltoidesPosterieurs'], equipement: 'halteres'),
  ),

  // Biceps et avant-bras
  SynonymeExercice(['Biceps Curl'], proches: ['curl-halteres', 'curl-barre', 'machine-bicep-curl', 'curl-poulie-basse']),
  SynonymeExercice(['Alternate Biceps Curl'], sur: 'curl-halteres'),
  SynonymeExercice(['EZ Barbell Curl'], sur: 'curl-barre-ez'),
  SynonymeExercice(['Dumbbell Incline Curl'], sur: 'curl-incline'),
  SynonymeExercice(['Hammer Curl', 'Seated Hammer Curl'], sur: 'curl-marteau'),
  SynonymeExercice(['Lever Preacher Curl'], sur: 'curl-pupitre-machine'),
  SynonymeExercice(
    ['Dumbbell Preacher Curl'],
    proches: ['curl-pupitre'],
    perso: ModelePerso('Curl pupitre haltère', muscles: ['biceps'], equipement: 'halteres'),
  ),
  SynonymeExercice(['Cable Curl'], sur: 'curl-poulie-basse'),
  SynonymeExercice(['Cable Hammer Curl'], sur: 'curl-marteau-a-la-corde'),
  SynonymeExercice(
    ['Cable Standing Reverse Grip Curl'],
    perso: ModelePerso('Curl inversé à la poulie', muscles: ['biceps', 'avantBras'], equipement: 'poulie'),
  ),
  SynonymeExercice(['Reverse Curl'], sur: 'curl-inverse'),
  SynonymeExercice(['Wrist Curl'], proches: ['curl-poignets', 'curl-poignets-haltere']),
  SynonymeExercice(['One Arm Wrist Curl'], sur: 'curl-poignets-haltere'),
  SynonymeExercice(
    ['Reverse Wrist Curl', 'Revers Wrist Curl'],
    proches: ['curl-poignets-inverse-haltere'],
    perso: ModelePerso('Curl poignets inversé à la barre', muscles: ['avantBras'], equipement: 'barre'),
  ),
  SynonymeExercice(['One Arm Reverse Wrist Curl', 'One Arm Revers Wrist Curl'], sur: 'curl-poignets-inverse-haltere'),

  // Triceps
  SynonymeExercice(['Triceps Pushdown', 'Cable Pushdown'], sur: 'extension-triceps-poulie-haute'),
  SynonymeExercice(['Cable Standing One Arm Tricep Pushdown'], sur: 'single-arm-tricep-pushdown'),
  SynonymeExercice(['Barbell Lying Triceps Extension Skull Crusher'], sur: 'barre-au-front'),
  SynonymeExercice(
    ['Barbell Incline Triceps Extension Skull Crusher'],
    proches: ['barre-au-front'],
    perso: ModelePerso('Barre au front sur banc incliné', muscles: ['triceps'], equipement: 'barre'),
  ),
  SynonymeExercice(
    ['Incline Triceps Extension'],
    perso: ModelePerso('Extension triceps sur banc incliné', muscles: ['triceps']),
  ),
  SynonymeExercice(
    ['High Pulley Overhead Tricep Extension'],
    perso: ModelePerso('Extension triceps au-dessus de la tête à la poulie', muscles: ['triceps'], equipement: 'poulie'),
  ),
  SynonymeExercice(['Assisted Triceps Dip'], sur: 'assisted-dips'),
  SynonymeExercice(['Weighted Tricep Dips'], sur: 'dips-lestes'),
  SynonymeExercice(
    ['Lever Seated Dip'],
    perso: ModelePerso('Dips assis à la machine', muscles: ['triceps', 'pectoraux'], equipement: 'machine'),
  ),
  SynonymeExercice(
    ['Impossible Dips'],
    perso: ModelePerso('Dips impossibles', muscles: ['triceps', 'pectoraux'], equipement: 'poids du corps'),
  ),

  // Jambes
  SynonymeExercice(['Sled 45° Leg Wide Press'], sur: 'wide-stance-leg-press'),
  SynonymeExercice(['Lever Leg Extension'], sur: 'leg-extension'),
  SynonymeExercice(['Lever Lying Leg Curl'], sur: 'leg-curl-allonge'),
  SynonymeExercice(['Lever Seated Leg Curl'], sur: 'leg-curl-assis'),
  SynonymeExercice(['Lever Seated Calf Raise'], sur: 'mollets-assis-machine'),
  SynonymeExercice(
    ['Lever Seated Calf Press'],
    perso: ModelePerso('Mollets à la presse', muscles: ['mollets'], equipement: 'machine'),
  ),
  SynonymeExercice(['Dumbbell Walking Lunges'], sur: 'fentes-marchees'),
  SynonymeExercice(['Full Squat'], proches: ['squat', 'squat-au-poids-du-corps']),
  SynonymeExercice(
    ['High Knee Squat'],
    perso: ModelePerso('Squat avec montée de genou', muscles: ['quadriceps', 'fessiers'], equipement: 'poids du corps'),
  ),

  // Abdominaux
  SynonymeExercice(['Crunch'], sur: 'crunch'),
  SynonymeExercice(['Alternate Oblique Crunch'], sur: 'crunch-croise'),
  SynonymeExercice(['Lever Total Abdominal Crunch'], sur: 'crunch-machine'),
  SynonymeExercice(
    ['Frog Crunch'],
    perso: ModelePerso('Crunch grenouille', muscles: ['abdominaux'], equipement: 'poids du corps'),
  ),
  SynonymeExercice(['Captains Chair Straight Leg Raise'], sur: 'releves-de-jambes-a-la-chaise-romaine'),
  SynonymeExercice(
    ['Leg Raise Hip Lift with Head up'],
    proches: ['releves-de-jambes-allonge', 'crunch-inverse'],
    perso: ModelePerso('Relevés de jambes avec relevé de bassin', muscles: ['abdominaux'], equipement: 'poids du corps'),
  ),
  SynonymeExercice(['Lying Scissors Cross', 'Lying Scissors Cross (male)'], sur: 'scissor-kicks'),
  SynonymeExercice(['Front Plank'], sur: 'gainage'),
  SynonymeExercice(['Mountain Climber'], sur: 'mountain-climbers'),
  SynonymeExercice(['Boat Stretch'], proches: ['boat-pose']),

  // Cardio
  SynonymeExercice(['Walking', 'Walking on Treadmill'], sur: 'walking'),
  SynonymeExercice(['Walking on Incline Treadmill'], sur: 'marche-inclinee-sur-tapis'),
  SynonymeExercice(['Walk Elliptical Cross Trainer', 'Elliptical Machine Walk'], sur: 'velo-elliptique'),
  SynonymeExercice(['Bicycle Recline Walk'], sur: 'velo-d-appartement'),
  SynonymeExercice(['Jumping Jack'], sur: 'jumping-jacks'),
  SynonymeExercice(['Butt Kicks'], sur: 'heel-flicks'),
  SynonymeExercice(['High Knee Skips'], sur: 'high-knees'),
];
