import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils.dart';

/// La ligne « Charges » de la fiche : ce que l'appli a déduit des séances,
/// le panneau qui le règle à la main, et le retour à la déduction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  final n = DateTime.now();

  testWidgets('pec deck : pile de 15 lb déduite, réglée à la main, puis rendue à la déduction', (t) async {
    await t.runAsync(chargerPolices);
    final data = (await t.runAsync(donneesVides))!;
    await t.runAsync(() => data.sessions.addAll([
          for (final (j, kg) in [(9, 32.0), (6, 39.0), (3, 45.0)])
            WorkoutSession(
              id: 's$j',
              nom: 'Pecs',
              debut: DateTime(n.year, n.month, n.day - j, 18),
              fin: DateTime(n.year, n.month, n.day - j, 19),
              exercices: [
                SessionExercise(id: 'e$j', exerciseId: 'pec-deck', series: [WorkoutSet(id: 'w$j', poids: kg, reps: 10, fait: true)]),
              ],
            ),
        ]));
    await lancer(t, data, '/entrainer?onglet=exercices', taille: const Size(380, 1800));
    await t.enterText(find.byType(TextField).first, 'pec deck');
    await attendre(t, 3);
    await t.tap(find.byType(CarteExercice).first);
    await attendre(t, 5);
    expect(find.byType(ExerciseDetailPage), findsOneWidget);
    expect(find.text('Charges'), findsOneWidget);
    expect(find.text('Pile de 15 lb · déduit de tes séances'), findsOneWidget);

    // Le panneau : la pile retenue, et la charge d'après.
    await t.tap(find.text('Charges'));
    await attendre(t, 2);
    expect(find.text('Après 45 kg · 100 lb, la charge d’après : 52 kg · 115 lb.'), findsOneWidget);
    expect(find.text('Revenir à la déduction'), findsNothing);
    // Une plaque d'appoint de 5 lb, et l'on enregistre.
    await t.tap(find.text('Écrite 2,3 kg'));
    await t.pump();
    expect(find.text('Après 45 kg · 100 lb, la charge d’après : 47,3 kg · 105 lb (100 + 5).'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await attendre(t, 2);
    expect(find.text('Pile de 15 lb, appoint de 5 lb · réglé à la main'), findsOneWidget);
    expect(data.charges.graduation('pec-deck').suivante(45), 47.3);

    // Revenir à la déduction oublie le réglage.
    await t.tap(find.text('Charges'));
    await attendre(t, 2);
    await t.tap(find.text('Revenir à la déduction'));
    await attendre(t, 2);
    expect(find.text('Pile de 15 lb · déduit de tes séances'), findsOneWidget);
    expect(data.charges.pour('pec-deck').origine, OrigineCharges.deduite);
  });
}
