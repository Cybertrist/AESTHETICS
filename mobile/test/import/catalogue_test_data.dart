import 'package:aesthetic/features/import/logic/logic.dart';

/// Petit catalogue de test, à la forme de `assets/data/exercises.json`.
final catalogueTest = [
  for (final j in <Map<String, dynamic>>[
    {'id': 'developpe-couche-barre', 'nom': 'Développé couché à la barre', 'nomEn': 'Barbell Bench Press', 'alias': ['Bench Press (Barbell)', 'Bench Press'], 'equipement': 'barre'},
    {'id': 'developpe-couche-halteres', 'nom': 'Développé couché aux haltères', 'nomEn': 'Dumbbell Bench Press', 'alias': [], 'equipement': 'halteres'},
    {'id': 'developpe-incline-halteres', 'nom': 'Développé incliné aux haltères', 'nomEn': 'Dumbbell Incline Bench Press', 'alias': ['Incline Bench Press (Dumbbell)']},
    {'id': 'extension-triceps-poulie', 'nom': 'Extension des triceps à la poulie', 'nomEn': 'Cable Pushdown', 'alias': ['Triceps Pushdown (Cable)', 'Triceps Rope Pushdown']},
    {'id': 'gainage', 'nom': 'Gainage', 'nomEn': 'Front Plank', 'alias': ['Plank']},
    {'id': 'rowing-assis-machine', 'nom': 'Rowing assis à la machine', 'nomEn': 'Lever Seated Row', 'alias': ['Seated Row (Machine)']},
    {'id': 'tractions', 'nom': 'Tractions', 'nomEn': 'Pull-up', 'alias': ['Pull Up']},
    {'id': 'tractions-assistees', 'nom': 'Tractions assistées', 'nomEn': 'Assisted Pull-up', 'alias': ['Pull Up (Assisted)']},
    {'id': 'traction-supination', 'nom': 'Tractions en supination', 'nomEn': 'Chin-up', 'alias': ['Chin Up']},
    {'id': 'curl-incline-halteres', 'nom': 'Curl incliné aux haltères', 'nomEn': 'Dumbbell Incline Curl', 'alias': []},
    {'id': 'curl-barre', 'nom': 'Curl à la barre', 'nomEn': 'Barbell Curl', 'alias': []},
    {'id': 'curl-halteres', 'nom': 'Curl aux haltères', 'nomEn': 'Dumbbell Biceps Curl', 'alias': ['Bicep Curl (Dumbbell)']},
    {'id': 'squat-barre', 'nom': 'Squat à la barre', 'nomEn': 'Barbell Full Squat', 'alias': ['Squat (Barbell)', 'Back Squat']},
    {'id': 'souleve-de-terre-roumain', 'nom': 'Soulevé de terre roumain', 'nomEn': 'Barbell Romanian Deadlift', 'alias': ['RDL']},
    {'id': 'souleve-de-terre', 'nom': 'Soulevé de terre', 'nomEn': 'Barbell Deadlift', 'alias': ['Deadlift (Barbell)', 'Deadlift']},
    {'id': 'tirage-vertical', 'nom': 'Tirage vertical', 'nomEn': 'Cable Lat Pulldown', 'alias': ['Lat Pulldown (Cable)', 'Lat Pulldown']},
    {'id': 'elevations-laterales', 'nom': 'Élévations latérales aux haltères', 'nomEn': 'Dumbbell Lateral Raise', 'alias': ['Lateral Raise (Dumbbell)']},
    {'id': 'ecarte-poulie', 'nom': 'Écarté à la poulie vis-à-vis', 'nomEn': 'Cable Crossover', 'alias': ['Cable Fly']},
    {'id': 'rowing-haltere', 'nom': "Rowing unilatéral à l'haltère", 'nomEn': 'Dumbbell One Arm Row', 'alias': ['Dumbbell Row']},
  ])
    CatalogueEntry.fromJson(j),
];
