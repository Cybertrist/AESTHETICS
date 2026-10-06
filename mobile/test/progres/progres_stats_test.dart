import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/progres/logic/progres_stats.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime d, String exo, List<(double, int)> sets, {int minutes = 60}) => WorkoutSession(
      id: id,
      nom: 'Séance $id',
      debut: d,
      fin: d.add(Duration(minutes: minutes)),
      exercices: [
        SessionExercise(
          id: 'e$id',
          exerciseId: exo,
          series: [
            for (var i = 0; i < sets.length; i++) WorkoutSet(id: '$id$i', poids: sets[i].$1, reps: sets[i].$2, fait: true),
          ],
        ),
      ],
    );

Exercise _ex(String id, List<Muscle> p, [List<Muscle> s = const []]) =>
    Exercise(id: id, nom: id, musclesPrincipaux: p, musclesSecondaires: s, equipement: 'barre', categorie: 'pectoraux');

void main() {
  final now = DateTime(2026, 9, 30, 12);
  // Récentes d'abord, comme SessionRepo.sessions.
  final sessions = [
    _s('3', DateTime(2026, 9, 29, 18), 'dc', [(80, 8), (80, 7), (80, 6)]),
    _s('2', DateTime(2026, 9, 22, 18), 'dc', [(77.5, 8), (77.5, 8)]),
    _s('1', DateTime(2026, 8, 3, 18), 'dc', [(70, 8), (70, 8)], minutes: 50),
  ];

  test('intervalle et résumé sur 4 semaines', () {
    final i = ProgresStats.intervalle(ProgresPeriode.semaines4, sessions, now: now);
    expect(i.debut, DateTime(2026, 9, 7));
    expect(i.fin, DateTime(2026, 10, 1));
    final r = ProgresStats.resume(ProgresStats.dans(sessions, i), semaines: i.semaines);
    expect(r.seances, 2);
    expect(r.series, 5);
    expect(r.volume, 80 * 21 + 77.5 * 16);
    expect(r.duree, const Duration(minutes: 120));
    expect(r.joursActifs, 2);
  });

  test('paquets par semaine', () {
    final i = ProgresStats.intervalle(ProgresPeriode.semaines4, sessions, now: now);
    final p = ProgresStats.paquets(ProgresStats.dans(sessions, i), i, parSemaine: true);
    expect(p.length, 4);
    expect(p.map((x) => x.seances).toList(), [0, 0, 1, 1]);
  });

  test('records et progression du 1RM', () {
    final r = ProgresStats.records(sessions).single;
    expect(r.nbSeances, 3);
    expect(r.premiereFois, DateTime(2026, 8, 3, 18));
    expect(r.gain, greaterThan(0));
    expect(r.bests.poidsMax!.valeur, 80);
    final prog = ProgresStats.progression('dc', sessions);
    expect(prog.first.poidsMax, 70);
    expect(prog.last.poidsMax, 80);
  });

  test('records battus sur une période', () {
    final sept = ProgresStats.recordsBattus(sessions, Intervalle(DateTime(2026, 9), DateTime(2026, 10)));
    expect(sept.where((r) => r.record.type == RecordType.poidsMax).length, 2);
  });

  test('séries par muscle et statut', () {
    final ex = {'dc': _ex('dc', [Muscle.pectoraux], [Muscle.triceps])};
    final m = ProgresStats.seriesParMuscle(sessions.take(1), (id) => ex[id]);
    expect(m[Muscle.pectoraux], 3);
    expect(m[Muscle.triceps], 1.5);
    expect(ProgresStats.statut(3), StatutMuscle.neglige);
    expect(ProgresStats.statut(12), StatutMuscle.cible);
    expect(ProgresStats.statut(25), StatutMuscle.auDessus);
    final i = ProgresStats.intensites(m);
    expect(i[Muscle.pectoraux]!, inInclusiveRange(0.2, 1));
  });

  test('niveaux du calendrier et plus longue série', () {
    final niveau = ProgresStats.niveaux([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(niveau(0), 0);
    expect(niveau(1), 1);
    expect(niveau(8), 4);
    expect(ProgresStats.plusLongueSerie(sessions.map((s) => s.debut)), 2);
  });

  test('variations', () {
    expect(ProgresStats.pct(ProgresStats.variation(12, 10)), '+20 %');
    expect(ProgresStats.pct(ProgresStats.variation(10, 0)), 'nouveau');
    expect(ProgresStats.pct(ProgresStats.variation(10, 10)), 'stable');
  });
}
