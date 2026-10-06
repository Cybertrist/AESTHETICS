import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/entrainer/commun/corps_colore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils.dart';

/// Rendus de contrôle de la zone Exercices : états limites et largeurs
/// extrêmes. Images dans build/rendus/exercices/.
const _echantillon = [
  'developpe-couche', 'developpe-incline', 'pompes', 'dips-pectoraux', 'pull-over-haltere',
  'tractions', 'tirage-vertical', 'rowing-barre', 'souleve-de-terre', 'shrugs-barre',
  'developpe-militaire', 'elevations-laterales', 'oiseau', 'face-pull', 'rowing-menton-halteres',
  'curl-barre', 'curl-marteau', 'barre-au-front', 'extension-triceps-poulie-haute', 'curl-poignets',
  'squat', 'presse-a-cuisses', 'leg-extension', 'leg-curl-assis', 'souleve-de-terre-roumain',
  'hip-thrust', 'abducteurs-machine', 'adducteurs-machine', 'mollets-debout-machine', 'crunch',
  'gainage-lateral', 'russian-twist', 'extensions-lombaires', 'etirement-lateral-du-cou', 'burpees',
];

WorkoutSession seanceDe(String id, DateTime debut, String exercice, List<WorkoutSet> series, {String nom = 'Séance'}) => WorkoutSession(
      id: id,
      nom: nom,
      debut: debut,
      fin: debut.add(const Duration(minutes: 50)),
      exercices: [SessionExercise(id: 'e-$id', exerciseId: exercice, series: series)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final n = DateTime.now();
  DateTime jour(int avant, [int h = 18]) => DateTime(n.year, n.month, n.day - avant, h, 5);

  for (final (nomPlanche, ids, colonnes, hauteur) in [('muscles-echantillon', _echantillon, 7, 210.0), ('muscles-zoom', ['crunch', 'adducteurs-machine', 'abducteurs-machine', 'elevations-laterales'], 4, 600.0)]) {
  testWidgets('planche des muscles ciblés : $nomPlanche', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await t.runAsync(prechargerCorps);
    final exos = [for (final id in ids) data.exercises.byId(id)];
    expect(exos.where((e) => e == null), isEmpty, reason: 'identifiants de l\'échantillon');
    t.view.physicalSize = Size(1400, colonnes == 7 ? 1470 : 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(RepaintBoundary(
      key: cleCapture,
      child: MaterialApp(
        theme: AccentController().theme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: GridView.count(
            crossAxisCount: colonnes,
            childAspectRatio: colonnes == 7 ? 200 / 294 : 350 / 700,
            children: [
              for (final e in exos)
                Column(
                  children: [
                    Text(e!.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    CorpsFaceDos(
                      hauteur: hauteur,
                      ecart: 6,
                      couleurs: {
                        for (final m in e.musclesSecondaires)
                          if (!e.musclesPrincipaux.contains(m)) m: Teinte.secondaire,
                        for (final m in e.musclesPrincipaux) m: Teinte.principal,
                      },
                    ),
                    Text('P ${e.musclesPrincipaux.map((m) => m.name).join(',')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.redAccent)),
                    Text('S ${e.musclesSecondaires.map((m) => m.name).join(',')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.lightBlueAccent)),
                  ],
                ),
            ],
          ),
        ),
      ),
    ));
    await attendre(t, 8);
    await capturer(t, 'exercices', nomPlanche);
  });
  }

  Future<AppData> donneesLimites(WidgetTester t) async {
    final data = (await t.runAsync(donneesVides))!;
    WorkoutSet s(String id, double? kg, int? reps, {SetType type = SetType.normale, int? duree}) =>
        WorkoutSet(id: id, type: type, poids: kg, reps: reps, dureeSec: duree, fait: true);
    await t.runAsync(() => data.sessions.addAll([
          // Une seule séance : un échauffement plus lourd en répétitions, une série.
          seanceDe('a', jour(2), 'developpe-couche', [s('a0', 40, 20, type: SetType.echauffement), s('a1', 60, 5)],
              nom: 'Séance au nom très long pour voir comment la ligne se coupe proprement'),
          // Poids du corps, sans lest.
          seanceDe('b', jour(3), 'tractions', [s('b1', null, 12), s('b2', 0, 9)]),
          seanceDe('c', jour(10), 'tractions', [s('c1', 10, 5), s('c2', null, 8)]),
          // Durée.
          seanceDe('d', jour(1), 'gainage', [s('d1', null, null, duree: 95), s('d2', null, null, duree: 60)]),
          // Valeurs énormes, nom d'exercice très long.
          seanceDe('e', jour(4), 'one-arm-single-leg-kettlebell-romanian-deadlift', [for (var i = 0; i < 12; i++) s('e$i', 1250.5, 100)]),
        ]));
    return data;
  }

  for (final (nom, taille) in [('360', const Size(360, 780)), ('412', const Size(412, 900)), ('large', const Size(884, 1000))]) {
    testWidgets('états limites de la fiche en $nom', (t) async {
      await t.runAsync(chargerPolices);
      final data = await donneesLimites(t);
      final long = data.exercises.all.firstWhere((e) => e.nom.startsWith('Soulevé de terre roumain unijambiste à un bras avec kettlebell'));
      await lancer(t, data, '/entrainer/exercices/developpe-couche?onglet=historique', taille: taille);
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-une-seance-historique');
      routeur(t).go('/entrainer/exercices/developpe-couche?onglet=progres');
      await attendre(t, 4);
      await capturer(t, 'exercices', '$nom-une-seance-progres');
      routeur(t).go('/entrainer/exercices/developpe-couche?onglet=records');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-une-seance-records');
      routeur(t).go('/entrainer/exercices/tractions?onglet=historique');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-poids-du-corps-historique');
      routeur(t).go('/entrainer/exercices/tractions?onglet=records');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-poids-du-corps-records');
      routeur(t).go('/entrainer/exercices/tractions?onglet=progres');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-poids-du-corps-progres');
      routeur(t).go('/entrainer/exercices/gainage?onglet=historique');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-duree-historique');
      routeur(t).go('/entrainer/exercices/gainage?onglet=records');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-duree-records');
      routeur(t).go('/entrainer/exercices/gainage');
      await attendre(t, 4);
      await capturer(t, 'exercices', '$nom-duree-a-propos');
      routeur(t).go('/entrainer/exercices/${long.id}?onglet=records');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-enorme-records');
      routeur(t).go('/entrainer/exercices/${long.id}/records');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-enorme-historique-records');
      routeur(t).go('/entrainer/exercices/${long.id}?onglet=progres');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-enorme-progres');
      routeur(t).go('/entrainer/exercices/${long.id}?onglet=historique');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-enorme-historique');
      routeur(t).go('/entrainer/exercices/squat?onglet=progres');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-jamais-fait-progres');
      routeur(t).go('/entrainer/muscles?muscle=deltoidesPosterieurs');
      await attendre(t, 5);
      await capturer(t, 'exercices', '$nom-muscles');
      routeur(t).go('/entrainer?onglet=exercices');
      await attendre(t, 5);
      await capturer(t, 'exercices', '$nom-grille');
      await t.enterText(find.byType(TextField).first, 'zzz introuvable avec un texte vraiment très long pour la mise en page');
      await attendre(t, 3);
      await capturer(t, 'exercices', '$nom-aucun-resultat');
      expect(t.takeException(), isNull);
    });
  }
}
