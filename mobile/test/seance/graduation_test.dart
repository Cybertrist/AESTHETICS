import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/logic/progression.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les charges qui existent vraiment : piles en livres d'une salle Basic-Fit
/// (machines Matrix), disques, haltères, kettlebells ; la déduction d'après
/// l'historique, et la charge d'après proposée en fin de séance et par les
/// programmes. Les chiffres viennent de l'historique de Tristan.
void main() {
  // Le catalogue se lit dans les fichiers de l'appli.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('les plaques en livres', () {
    test('les kilos écrits sur les plaques', () {
      expect([for (final lb in [5, 10, 15, 20, 25, 30]) Graduation.etiquetteLb(lb.toDouble())], [2.3, 4.5, 6.8, 9.0, 11.3, 13.5]);
      expect([for (final lb in [40, 50, 60, 70, 80, 90, 100, 110, 120]) Graduation.etiquetteLb(lb.toDouble())], [18.0, 23.0, 27.0, 32.0, 36.0, 41.0, 45.0, 50.0, 54.0]);
      expect([for (final lb in [100, 115, 130, 145, 160, 175]) Graduation.etiquetteLb(lb.toDouble())], [45.0, 52.0, 59.0, 66.0, 73.0, 79.0]);
      expect([Graduation.etiquetteAppoint(2.5), Graduation.etiquetteAppoint(5)], [1.1, 2.3]);
    });

    test('pile de 15 lb : avec l’appoint de 5 lb, 45 → 47,3 ; sans, 45 → 52', () {
      const avec = Graduation.pile(pas: 15, depart: 70, appoints: [5]);
      const sans = Graduation.pile(pas: 15, depart: 70);
      expect(avec.suivante(45), 47.3);
      expect(avec.suivante(47.3), 52);
      expect(avec.suivante(45, appoint: false), 52, reason: 'un vrai cran de pile');
      expect(sans.suivante(45), 52);
      expect(sans.suivante(52), 59);
      expect(avec.precedente(52), 47.3);
      expect(sans.precedente(52), 45);
      // Une charge un peu à côté retombe sur la plaque.
      expect(avec.arrondir(47.5), 47.3);
      expect(sans.arrondir(50), 52);
      expect(sans.suivante(45.4), 52, reason: 'à la tolérance près, 45,4 est la plaque de 100 lb');
      expect(sans.libelleMachine(59), '130 lb');
      expect(avec.libelleMachine(47.3), '105 lb (100 + 5)');
      expect(sans.libelleMachine(30), isNull);
      expect(avec.description, 'Pile de 15 lb, appoint de 5 lb');
    });

    test('pile de 10 lb : 41 → 45, et 41 + 1,1 avec l’appoint de 2,5 lb', () {
      const g = Graduation.pile(pas: 10, depart: 10);
      expect(g.suivante(41), 45);
      expect(g.suivante(18), 23);
      expect(g.precedente(41), 36);
      const appoint = Graduation.pile(pas: 10, depart: 10, appoints: [2.5]);
      expect(appoint.suivante(41), 42.1);
      expect(appoint.libelleMachine(42.1), '92,5 lb (90 + 2,5)');
      expect(appoint.grandSaut(41), 45, reason: 'aux jambes, un cran de pile sans appoint');
    });

    test('pile de 5 lb : 2,3 → 4,5 → 6,8', () {
      const g = Graduation.pile(pas: 5, depart: 5);
      expect(g.suivante(2.3), 4.5);
      expect(g.suivante(4.5), 6.8);
      expect(g.suivante(11.3), 13.5);
      expect(g.precedente(2.3), 2.3, reason: 'rien sous la plus légère');
      expect(g.arrondir(13.6), 13.5);
    });

    test('pile en kilos', () {
      const g = Graduation.pile(unite: UniteCharges.kg, pas: 5, depart: 5);
      expect(g.suivante(40), 45);
      expect(g.precedente(40), 35);
      expect(g.libelleMachine(40), isNull);
      expect(g.description, 'Pile de 5 kg');
    });
  });

  test('disques : par paires de 1,25 kg, la barre et le chariot à part', () {
    const barre = Graduation.disques(base: 20);
    expect(barre.suivante(60), 62.5);
    expect(barre.precedente(60), 57.5);
    expect(barre.arrondir(61), 60);
    expect(barre.grandSaut(60), 65);
    const presse = Graduation.disques(base: Graduation.chariotPresse, chariot: true);
    expect(presse.grandSaut(80), 85);
    expect(presse.grandSaut(120), 130);
    expect(presse.avecBase(120), 195.7);
    expect(presse.description, 'Disques de 2,5 en 2,5 kg, chariot de 75,7 kg');
  });

  test('haltères, kettlebells et pas fixe', () {
    const h = Graduation.halteres();
    expect([for (final kg in [3.0, 9.0, 10.0, 12.0, 16.0, 22.0]) h.suivante(kg)], [4.0, 10.0, 12.0, 14.0, 18.0, 24.0]);
    expect([for (final kg in [12.0, 10.0, 2.0]) h.precedente(kg)], [10.0, 9.0, 1.0]);
    expect([for (final kg in [7.4, 10.4, 11.2, 14.4, 17.1]) h.arrondir(kg)], [7.0, 10.0, 12.0, 14.0, 18.0]);
    const k = Graduation.kettlebell();
    expect(k.suivante(16), 20);
    expect(k.precedente(16), 14);
    expect(k.arrondir(17), 16);
    const l = Graduation.libre(pas: 2.5);
    expect(l.suivante(30), 32.5);
    expect(l.precedente(30), 27.5);
    expect(l.grandSaut(30), 35);
  });

  test('une graduation se relit telle quelle', () {
    for (final g in const [
      Graduation.pile(pas: 15, depart: 70, appoints: [2.5, 5]),
      Graduation.pile(unite: UniteCharges.kg, pas: 5, depart: 5),
      Graduation.disques(base: 75.7, chariot: true),
      Graduation.halteres(),
      Graduation.kettlebell(),
      Graduation.libre(pas: 1.25),
    ]) {
      expect(Graduation.fromJson(g.toJson()), g);
    }
  });

  group('la déduction', () {
    test('pec deck : pile de 15 lb, appoint de 5 lb', () {
      final g = Graduations.deduire([45, 52, 59, 66, 73, 79, 47.3, 54.3, 45, 52])!;
      expect(g.sorte, SorteCharges.pile);
      expect(g.unite, UniteCharges.lb);
      expect(g.pas, 15);
      expect(g.appoints, [5.0]);
      expect(g.suivante(45), 47.3);
      expect(g.suivante(45, appoint: false), 52);
    });

    test('tirage vertical : pile de 15 lb, de 70 à 145 lb', () {
      final g = Graduations.deduire([32, 39, 45, 52, 59, 66])!;
      expect(g.pas, 15);
      expect(g.appoints, isEmpty);
      expect(g.suivante(32), 39);
      expect(g.libelleMachine(32), '70 lb');
    });

    test('développé épaules machine : pile de 10 lb, appoint de 2,5 lb, et le 80 kg d’une autre salle ignoré', () {
      final charges = <double>[18, 23, 27, 32, 36, 41, 45, 50, 54, 18, 23, 41, 42.1, 80];
      expect(Graduations.retenues(charges), [18.0, 23, 27, 32, 36, 41, 42.1, 45, 50, 54]);
      final g = Graduations.deduire(charges)!;
      expect((g.unite, g.pas), (UniteCharges.lb, 10.0));
      expect(g.appoints, [2.5]);
      expect(g.suivante(41, appoint: false), 45);
    });

    test('pile de 10 lb dont on n’a fait que des charges paires : pas une pile de 20', () {
      final g = Graduations.deduire([18, 23, 27, 32, 36, 41, 45, 50, 54])!;
      expect(g.pas, 10);
    });

    test('élévations latérales à la poulie : pile de 5 lb', () {
      final g = Graduations.deduire([2.3, 4.5, 6.8, 9, 11.3, 13.5])!;
      expect((g.unite, g.pas), (UniteCharges.lb, 5.0));
      expect(g.suivante(2.3), 4.5);
    });

    test('des kilos ronds ne sont pas une pile en livres', () {
      expect(Graduations.deduire([60, 62.5, 65, 67.5, 70]), isNull, reason: 'une barre');
      expect(Graduations.deduire([12.5, 13.75, 15, 16.25, 17.5]), isNull, reason: 'une poulie au pas de 1,25 kg, hors machine');
      final machine = Graduations.deduire([30, 35, 40, 45, 50], machine: true)!;
      expect((machine.unite, machine.pas), (UniteCharges.kg, 5.0));
      expect(Graduations.deduire([45, 52]), isNull, reason: 'trop peu de charges');
    });

    test('sans historique, le matériel décide', () async {
      final data = AppData(Store.memory());
      await data.exercises.load();
      Graduation g(String id) => Graduations.pour(data.exercises.byId(id), const []).graduation;
      expect(g('pec-deck'), const Graduation.pile(pas: 10, depart: 10));
      expect(g('tirage-vertical'), const Graduation.pile(pas: 10, depart: 10));
      expect(g('presse-a-cuisses'), const Graduation.disques(base: 75.7, chariot: true));
      expect(g('developpe-couche'), const Graduation.disques(base: 20));
      expect(g('curl-marteau').sorte, SorteCharges.halteres);
      expect(Graduations.pour(data.exercises.byId('pec-deck'), const []).origine, OrigineCharges.materiel);
    });
  });

  group('la charge d’après', () {
    var n = 0;
    WorkoutSession seance(String exo, DateTime debut, List<(double, int)> series) => WorkoutSession(
          id: 's${n++}',
          nom: 'Séance',
          debut: debut,
          fin: debut.add(const Duration(hours: 1)),
          exercices: [
            SessionExercise(id: 'e${n++}', exerciseId: exo, series: [
              for (final (p, r) in series) WorkoutSet(id: 'w${n++}', poids: p, reps: r, fait: true),
            ]),
          ],
        );
    DateTime jour(int j) => DateTime(2026, 9, j, 18);

    late AppData data;
    setUp(() async {
      data = AppData(Store.memory());
      await data.exercises.load();
    });

    test('pec deck : 52 kg après 45 kg, pas 47,5, avec la valeur de la machine', () async {
      final avant = [
        seance('pec-deck', jour(1), [(32, 12), (32, 12)]),
        seance('pec-deck', jour(4), [(39, 10), (39, 10)]),
        seance('pec-deck', jour(8), [(45, 8), (45, 8), (45, 8)]),
      ];
      await data.sessions.addAll(avant);
      expect(data.charges.resume('pec-deck'), 'Pile de 15 lb · déduit de tes séances');
      final s = seance('pec-deck', jour(11), [(45, 14), (45, 14), (45, 14)]);
      final p = Surcharge.calculer(s, exos: data.exercises, avant: avant, graduation: data.charges.graduation).single;
      expect(p.poids, 52);
      expect(p.titre, '52 kg × 8 · 115 lb');
      expect(p.raison, contains('monte à 52 kg · 115 lb'));
      // Sans graduation, l'ancien pas fixe.
      expect(Surcharge.calculer(s, exos: data.exercises, avant: avant).single.poids, 47.5);
    });

    test('leg curl : aux jambes, un cran de pile, sans l’appoint', () async {
      final avant = [
        seance('leg-curl-allonge', jour(1), [(32, 10), (32, 10)]),
        seance('leg-curl-allonge', jour(3), [(36, 10), (36, 10)]),
        seance('leg-curl-allonge', jour(5), [(42.1, 6)]),
        seance('leg-curl-allonge', jour(8), [(41, 8), (41, 8), (41, 8)]),
      ];
      await data.sessions.addAll(avant);
      expect(data.charges.graduation('leg-curl-allonge').appoints, [2.5]);
      final s = seance('leg-curl-allonge', jour(11), [(41, 12), (41, 12), (41, 12)]);
      final p = Surcharge.calculer(s, exos: data.exercises, avant: avant, graduation: data.charges.graduation).single;
      expect(p.poids, 45);
      expect(p.titre, '45 kg × 8 · 100 lb');
    });

    test('presse : 10 kg de plus au-delà de 100 kg, et le total avec le chariot', () async {
      final avant = [
        seance('presse-a-cuisses', jour(1), [(100, 10)]),
        seance('presse-a-cuisses', jour(4), [(110, 10)]),
        seance('presse-a-cuisses', jour(8), [(120, 8), (120, 8)]),
      ];
      await data.sessions.addAll(avant);
      expect(data.charges.graduation('presse-a-cuisses').chariot, isTrue);
      final s = seance('presse-a-cuisses', jour(11), [(120, 12), (120, 12)]);
      final p = Surcharge.calculer(s, exos: data.exercises, avant: avant, graduation: data.charges.graduation).single;
      expect(p.poids, 130);
      expect(p.raison, contains('130 kg de disques, 205,7 kg avec le chariot'));
    });

    test('programme : la charge monte d’une plaque de pile', () async {
      final routine = Routine(id: 'r', nom: 'Pecs', creeLe: DateTime(2026), exercices: const [
        RoutineExercise(id: 'a', exerciseId: 'pec-deck', series: [PlannedSet(poids: 45, reps: 10), PlannedSet(poids: 45, reps: 10)]),
      ]);
      await data.sessions.addAll([
        seance('pec-deck', jour(1), [(32, 10), (32, 10)]),
        seance('pec-deck', jour(4), [(39, 10), (39, 10)]),
        seance('pec-deck', jour(8), [(45, 10), (45, 10)]),
      ]);
      final r = appliquerProgression(
        routine: routine,
        plan: const ProgramPlan(programId: 'p', incrementKg: 2.5),
        semaine: 0,
        sessions: data.sessions,
        lookup: data.exercises.byId,
        graduation: data.charges.graduation,
      );
      expect([for (final p in r.routine.exercices.single.series) p.poids], [52.0, 52.0], reason: 'de 100 à 115 lb, pas 47,5 kg');
      expect(r.ajustements.single.texte, contains('plaque suivante de la pile'));
      // Une semaine de décharge : 90 % de 45 kg retombent sur une plaque.
      final decharge = appliquerProgression(
        routine: routine,
        plan: const ProgramPlan(programId: 'p', progression: ProgressionType.aucune, dechargeToutesLes: 1),
        semaine: 0,
        sessions: data.sessions,
        lookup: data.exercises.byId,
        graduation: data.charges.graduation,
      );
      expect(decharge.routine.exercices.single.series.first.poids, 39);
    });
  });

  test('le réglage de la fiche l’emporte sur la déduction, et survit à un rechargement', () async {
    final data = AppData(Store.memory());
    await data.loadAll();
    var n = 0;
    await data.sessions.addAll([
      for (final (j, kg) in [(1, 32.0), (4, 39.0), (8, 45.0)])
        WorkoutSession(id: 's${n++}', nom: 'Pecs', debut: DateTime(2026, 9, j), exercices: [
          SessionExercise(id: 'e${n++}', exerciseId: 'pec-deck', series: [WorkoutSet(id: 'w${n++}', poids: kg, reps: 10, fait: true)]),
        ]),
    ]);
    expect(data.charges.pour('pec-deck').origine, OrigineCharges.deduite);
    expect(data.charges.graduation('pec-deck').suivante(45), 52);

    const regle = Graduation.pile(pas: 15, depart: 70, appoints: [5]);
    await data.charges.regler('pec-deck', regle);
    expect(data.charges.pour('pec-deck').origine, OrigineCharges.reglage);
    expect(data.charges.graduation('pec-deck').suivante(45), 47.3);
    expect(data.charges.resume('pec-deck'), 'Pile de 15 lb, appoint de 5 lb · réglé à la main');

    final relu = AppData(data.store);
    await relu.loadAll();
    expect(relu.charges.reglage('pec-deck'), regle);
    expect(relu.charges.graduation('pec-deck').suivante(45), 47.3);

    await relu.charges.revenirALaDeduction('pec-deck');
    expect(relu.charges.pour('pec-deck').origine, OrigineCharges.deduite);
    final encore = AppData(data.store);
    await encore.loadAll();
    expect(encore.charges.reglage('pec-deck'), isNull);
  });
}
