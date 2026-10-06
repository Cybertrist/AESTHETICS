import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime debut, String? routine, double poids) => WorkoutSession(
      id: id,
      nom: 'S',
      debut: debut,
      fin: debut.add(const Duration(hours: 1)),
      routineId: routine,
      exercices: [
        SessionExercise(id: '$id-e', exerciseId: 'squat', series: [WorkoutSet(id: 'a', poids: poids, reps: 5, fait: true)]),
      ],
    );

void main() {
  notifSeanceTests();
  reperesTests();
  test('réglages de séance : valeurs par défaut, aller-retour JSON, musique retirable', () {
    const d = AppSettings();
    expect((d.volumeMinuteur, d.forceVibration, d.effortRir, d.precedentMemeRoutine), (2, 1, false, false));
    expect((d.supersetAuto, d.alerteRecord, d.notifSeance, d.musique), (true, true, true, null));
    final m = d.copyWith(volumeMinuteur: 0, forceVibration: 2, effortRir: true, precedentMemeRoutine: true, supersetAuto: false, alerteRecord: false, notifSeance: false, musique: 'spotify');
    final r = AppSettings.fromJson(m.toJson());
    expect((r.volumeMinuteur, r.forceVibration, r.effortRir, r.precedentMemeRoutine), (0, 2, true, true));
    expect((r.supersetAuto, r.alerteRecord, r.notifSeance, r.musique), (false, false, false, 'spotify'));
    expect(r.copyWith(sansMusique: true).musique, isNull);
    // Un fichier d'avant ces réglages garde les valeurs par défaut.
    expect(AppSettings.fromJson(const {}).supersetAuto, isTrue);
    expect(AppSettings.fromJson(const {'volumeMinuteur': 9}).volumeMinuteur, 2);
  });

  test('vibration : trois forces, de la plus brève à la plus longue', () {
    int duree(int f) => ReposMinuteur.motifVibration(f).fold(0, (a, b) => a + b);
    expect(duree(0), lessThan(duree(1)));
    expect(duree(1), lessThan(duree(2)));
    expect(ReposMinuteur.motifVibration(7), ReposMinuteur.motifVibration(2));
    // La force joue aussi sur la puissance du vibreur et sur les tics du decompte.
    expect([for (final f in [0, 1, 2]) ReposMinuteur.amplitudeVibration(f)], [80, 170, 255]);
    expect(ReposMinuteur.dureeTic(0), lessThan(ReposMinuteur.dureeTic(2)));
    // Un seul coup a la fin : une attente nulle, puis la vibration.
    expect(ReposMinuteur.motifVibration(2).length, 2);
  });

  test('valeurs précédentes : même routine d\'abord, sinon la dernière fois tout court', () async {
    final repo = SessionRepo(Store.memory());
    await repo.load();
    await repo.save(_s('a', DateTime(2026, 9, 1), 'push', 80));
    await repo.save(_s('b', DateTime(2026, 9, 8), 'jambes', 100));
    expect(repo.lastFor('squat')!.series.first.poids, 100);
    expect(repo.lastFor('squat', routineId: 'push')!.series.first.poids, 80);
    expect(repo.lastFor('squat', routineId: 'inconnue')!.series.first.poids, 100);
  });
}

void notifSeanceTests() {
  test('notification de séance : l\'exercice et la série à faire, puis « tout est fait »', () {
    WorkoutSession s(List<bool> faits) => WorkoutSession(
          id: 's',
          nom: 'Push',
          debut: DateTime(2026, 10, 3, 18),
          exercices: [
            SessionExercise(id: 'e1', exerciseId: 'rowing', series: [
              for (final (i, f) in faits.indexed) WorkoutSet(id: 'x$i', poids: 50, reps: 12, fait: f),
            ]),
          ],
        );
    String nom(String id) => 'Rowing barre';
    expect(ReposMinuteur.texteNotifSeance(s([false, false, false]), nom, UnitePoids.kg), ('Rowing barre', 'Série 1/3 · 50 kg × 12'));
    expect(ReposMinuteur.texteNotifSeance(s([true, false, false]), nom, UnitePoids.kg).$2, startsWith('Série 2/3'));
    expect(ReposMinuteur.texteNotifSeance(s([true, true, true]), nom, UnitePoids.kg), ('Séance en cours', 'Toutes les séries sont faites'));
    expect(ReposMinuteur.serieAFaire(s([true, false, false]))!.set.id, 'x1');
    expect(ReposMinuteur.serieAFaire(null), isNull);
  });
}

void reperesTests() {
  test('record en séance : charge, répétitions à cette charge, 1RM estimé ; rien sans historique', () {
    WorkoutSession s(String id, double poids, int reps) => WorkoutSession(
          id: id,
          nom: 'S',
          debut: DateTime(2026, 9, 1),
          fin: DateTime(2026, 9, 1, 1),
          exercices: [
            SessionExercise(id: '$id-e', exerciseId: 'dc', series: [WorkoutSet(id: 'a', poids: poids, reps: reps, fait: true)]),
          ],
        );
    final r = ReperesRecord.de('dc', [s('a', 30, 5), s('b', 28, 11), s('c', 14, 12)]);
    WorkoutSet x(double p, int n, {SetType type = SetType.normale}) => WorkoutSet(id: 'x', poids: p, reps: n, type: type, fait: true);
    expect(r.poidsMax, 30);
    expect(r.repsA(30), 5);
    expect(r.repsA(28), 11);
    // 30 kg × 8 : jamais autant de répétitions à 30 kg.
    expect(r.recordDe(x(30, 8)), 'répétitions à cette charge');
    expect(r.recordDe(x(32, 1)), 'charge maximale');
    expect(r.recordDe(x(30, 5)), isNull);
    expect(r.recordDe(x(28, 8)), isNull);
    expect(r.recordDe(x(20, 11)), isNull, reason: '11 répétitions déjà faites à 28 kg, plus lourd');
    expect(r.recordDe(x(32, 3, type: SetType.echauffement)), isNull);
    expect(ReperesRecord.de('dc', const []).recordDe(x(100, 10)), isNull);
  });
}
