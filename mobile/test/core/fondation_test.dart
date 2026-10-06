import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('1RM et échauffement', () {
    expect(Strength.oneRepMax(100, 1), 100);
    expect(Strength.epley(100, 10), closeTo(133.3, 0.1));
    expect(Strength.oneRepMax(100, 5), closeTo(114.3, 0.5));
    final w = Strength.echauffement(100);
    expect(w.first.poids, 20);
    expect(w.every((s) => s.poids < 100), isTrue);
  });

  test('Muscle.tryParse tolérant', () {
    expect(Muscle.tryParse('grandDorsal'), Muscle.grandDorsal);
    expect(Muscle.tryParse('Ischio-jambiers'), Muscle.ischios);
    expect(Muscle.tryParse('lats'), Muscle.grandDorsal);
    expect(Muscle.tryParse('inconnu'), isNull);
  });

  test('Mifflin-St Jeor', () {
    final bmr = NutritionCalc.metabolismeDeBase(sexe: Sexe.homme, poidsKg: 80, tailleCm: 180, age: 30);
    expect(bmr, 1780);
  });

  test('Format français', () {
    expect(Fmt.n(12450), '12 450');
    expect(Fmt.n(77.25, decimals: 1), '77,3');
    expect(Fmt.chrono(const Duration(minutes: 3, seconds: 5)), '03:05');
    expect(Fmt.repos(90), '1:30');
  });

  test('Store, séance active et démo', () async {
    final data = AppData(Store.memory(), demo: true);
    await data.loadAll();
    expect(data.profile.hasProfile, isFalse);

    await DemoData.seed(data, now: DateTime(2026, 9, 29, 20));
    expect(data.profile.profile!.prenom, 'Tristan');
    expect(data.sessions.sessions.length, greaterThan(80));
    expect(data.routines.routines.length, 3);
    expect(data.programs.active, isNotNull);
    expect(data.health.sleep.length, greaterThan(150));
    expect(data.nutrition.totalsFor(DateTime(2026, 9, 28)).kcal, greaterThan(1500));

    // Rechargement depuis le stockage : rien ne se perd.
    final again = AppData(data.store);
    await again.loadAll();
    expect(again.sessions.sessions.length, data.sessions.sessions.length);
    expect(again.profile.profile!.objectifsNutrition, isNotNull);

    // Séance depuis une routine, une série cochée, fin.
    final push = again.routines.routines.first;
    final s = await again.sessions.startFromRoutine(push);
    expect(s.exercices.first.series.last.poids, isNotNull);
    final ex = s.exercices.first;
    await again.sessions.toggleSetDone(ex.id, ex.series.last.id);
    final res = await again.sessions.finishActive(ressenti: 4);
    expect(res!.session.exercices.length, 1);
    expect(again.sessions.hasActive, isFalse);

    // Sauvegarde et restauration.
    final backup = await again.exportBackup();
    final other = AppData(Store.memory());
    await other.importBackup(backup);
    expect(other.sessions.sessions.length, again.sessions.sessions.length);

    final fatigue = Recovery.fatigue(again.sessions.sessions, again.exercises.byId, now: DateTime(2026, 9, 29, 21));
    expect(fatigue.isNotEmpty, isTrue);
  });
}
