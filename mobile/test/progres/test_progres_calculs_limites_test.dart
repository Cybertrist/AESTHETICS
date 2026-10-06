// Calculs de l'onglet Progrès, recoupés à la main sur de petits jeux de
// données : périodes comparées au même point, semaines ISO, série de
// semaines, records, temps, calendrier, récupération.
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/sante/recuperation/recup_calcul.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(
  String id,
  DateTime d,
  String exo,
  List<(double, int)> sets, {
  int minutes = 60,
  TypeSeance type = TypeSeance.musculation,
  bool enCours = false,
}) =>
    WorkoutSession(
      id: id,
      nom: 'Séance $id',
      debut: d,
      fin: enCours ? null : d.add(Duration(minutes: minutes)),
      type: type,
      exercices: [
        SessionExercise(
          id: 'e$id',
          exerciseId: exo,
          series: [
            for (var i = 0; i < sets.length; i++)
              WorkoutSet(id: '$id$i', poids: sets[i].$1 <= 0 ? null : sets[i].$1, reps: sets[i].$2, fait: true),
          ],
        ),
      ],
    );

const _exercices = {
  'dc': Exercise(id: 'dc', nom: 'Développé couché', musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.deltoidesAnterieurs, Muscle.triceps]),
  'squat': Exercise(id: 'squat', nom: 'Squat', musclesPrincipaux: [Muscle.quadriceps], musclesSecondaires: [Muscle.fessiers]),
  'tirage': Exercise(id: 'tirage', nom: 'Tirage', musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
  'pompes': Exercise(id: 'pompes', nom: 'Pompes', musclesPrincipaux: [Muscle.pectoraux]),
  'curl': Exercise(id: 'curl', nom: 'Curl', musclesPrincipaux: [Muscle.biceps]),
  // Tout le corps sauf les bras.
  'tout': Exercise(id: 'tout', nom: 'Tout sauf les bras', musclesPrincipaux: [
    Muscle.pectoraux,
    Muscle.deltoidesAnterieurs,
    Muscle.deltoidesLateraux,
    Muscle.deltoidesPosterieurs,
    Muscle.trapezes,
    Muscle.grandDorsal,
    Muscle.rhomboides,
    Muscle.lombaires,
    Muscle.abdominaux,
    Muscle.obliques,
    Muscle.fessiers,
    Muscle.quadriceps,
    Muscle.ischios,
    Muscle.adducteurs,
    Muscle.mollets,
  ]),
};

Exercise? _exo(String id) => _exercices[id];

void main() {
  group('début de semaine', () {
    test('lundi par défaut, y compris autour du 1er janvier', () {
      expect(Dates.debutSemaine(DateTime(2027, 1, 1, 15)), DateTime(2026, 12, 28));
      expect(Dates.debutSemaine(DateTime(2026, 12, 28)), DateTime(2026, 12, 28));
      expect(Dates.debutSemaine(DateTime(2027, 1, 3, 23, 59)), DateTime(2026, 12, 28));
      expect(Dates.debutSemaine(DateTime(2027, 1, 4)), DateTime(2027, 1, 4));
    });

    test('semaine qui commence le dimanche : minuit pile, même après un changement d\'heure', () {
      // Dimanche 29 mars 2026 : passage à l'heure d'été en France.
      expect(Dates.debutSemaine(DateTime(2026, 3, 30, 10), premierJour: DateTime.sunday), DateTime(2026, 3, 29));
      expect(Dates.debutSemaine(DateTime(2026, 4, 4, 10), premierJour: DateTime.sunday), DateTime(2026, 3, 29));
      // Dimanche 25 octobre 2026 : retour à l'heure d'hiver.
      expect(Dates.debutSemaine(DateTime(2026, 10, 26, 10), premierJour: DateTime.sunday), DateTime(2026, 10, 25));
      expect(Dates.debutSemaine(DateTime(2026, 10, 31), premierJour: DateTime.sunday), DateTime(2026, 10, 25));
      // Samedi.
      expect(Dates.debutSemaine(DateTime(2026, 3, 31), premierJour: DateTime.saturday), DateTime(2026, 3, 28));
    });

    test('série de semaines qui commencent le dimanche, à cheval sur le changement d\'heure', () {
      final dates = [DateTime(2026, 3, 22, 18), DateTime(2026, 3, 30, 18)];
      expect(Dates.semainesConsecutives(dates, now: DateTime(2026, 3, 31, 12), premierJour: DateTime.sunday), 2);
    });
  });

  group('période en cours comparée au même point', () {
    test('semaine : par jours entiers, pas à l\'heure près', () {
      // Même lundi, une heure plus tôt cette semaine : les deux séances se comparent.
      final sessions = [
        _s('T1', DateTime(2026, 9, 28, 16, 30), 'dc', [(110, 10)]),
        _s('T0', DateTime(2026, 9, 21, 18), 'dc', [(100, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 9, 28, 17, 45));
      expect(r.volume, 1100);
      expect(r.volumeAvant, 1000);
      expect(r.ecart, 10);
    });

    test('semaine : le reste de la semaine passée ne compte pas', () {
      final sessions = [
        _s('T1', DateTime(2026, 9, 28, 17), 'dc', [(100, 10)]),
        _s('T0', DateTime(2026, 9, 21, 18), 'dc', [(100, 10)]),
        _s('M0', DateTime(2026, 9, 22, 0, 0), 'dc', [(100, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 9, 28, 23, 59));
      expect(r.volumeAvant, 1000);
      expect(r.ecart, isNull, reason: 'écart nul : rien à afficher');
    });

    test('mois : le 2 contre les deux premiers jours du mois d\'avant', () {
      final sessions = [
        _s('O', DateTime(2026, 10, 1, 18), 'dc', [(100, 10)]),
        _s('S2', DateTime(2026, 9, 2, 20), 'dc', [(50, 10)]),
        _s('S3', DateTime(2026, 9, 3, 0, 0), 'dc', [(70, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: DateTime(2026, 10, 2, 8));
      expect(r.volume, 1000);
      expect(r.volumeAvant, 500);
      expect(r.ecart, 100);
    });

    test('mois : le 31 mars contre février entier, sans déborder sur mars', () {
      final sessions = [
        _s('M', DateTime(2026, 3, 30, 18), 'dc', [(100, 10)]),
        _s('M1', DateTime(2026, 3, 1, 9), 'dc', [(100, 10)]),
        _s('F', DateTime(2026, 2, 28, 23), 'dc', [(80, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: DateTime(2026, 3, 31, 12));
      expect(r.debut, DateTime(2026, 3));
      expect(r.fin, DateTime(2026, 4));
      expect(r.volume, 2000);
      expect(r.volumeAvant, 800);
      expect(r.ecart, 150);
    });

    test('mois : janvier se compare à décembre de l\'année d\'avant', () {
      final sessions = [
        _s('J', DateTime(2027, 1, 2, 18), 'dc', [(100, 10)]),
        _s('D', DateTime(2026, 12, 1, 18), 'dc', [(80, 10)]),
        _s('D2', DateTime(2026, 12, 31, 18), 'dc', [(80, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: DateTime(2027, 1, 3, 12));
      expect(r.debut, DateTime(2027, 1));
      expect(r.fin, DateTime(2027, 2));
      expect(r.volumeAvant, 800);
      expect(r.ecart, 25);
    });

    test('année : même jour de l\'année d\'avant, année bissextile comprise', () {
      final sessions = [
        _s('C', DateTime(2028, 2, 20, 18), 'dc', [(60, 10)]),
        _s('A', DateTime(2027, 3, 2, 8), 'dc', [(100, 10)]),
        _s('B', DateTime(2027, 2, 10, 18), 'dc', [(50, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.annee, sessions, _exo, now: DateTime(2028, 3, 1, 12));
      expect(r.debut, DateTime(2028));
      expect(r.fin, DateTime(2029));
      expect(r.volume, 600);
      // Le 2 mars 2027 est après le 1er mars : il ne compte pas.
      expect(r.volumeAvant, 500);
      expect(r.ecart, 20);
    });

    test('année : le 29 février se compare au 28', () {
      final sessions = [
        _s('C', DateTime(2028, 2, 29, 9), 'dc', [(60, 10)]),
        _s('A', DateTime(2027, 3, 1, 10), 'dc', [(100, 10)]),
        _s('B', DateTime(2027, 2, 28, 20), 'dc', [(50, 10)]),
      ];
      final r = Calculs.resume(PeriodeProgres.annee, sessions, _exo, now: DateTime(2028, 2, 29, 12));
      expect(r.volumeAvant, 500);
    });
  });

  group('écarts', () {
    test('base nulle ou négative, écart nul, arrondis', () {
      expect(Calculs.ecart(0, 0), isNull);
      expect(Calculs.ecart(500, 0), isNull);
      expect(Calculs.ecart(500, -3), isNull);
      expect(Calculs.ecart(0, 500), -100);
      expect(Calculs.ecart(100.4, 100), isNull);
      expect(Calculs.ecart(99.6, 100), isNull);
      expect(Calculs.ecart(100.6, 100), 1);
      expect(Calculs.ecart(300, 100), 200);
      expect(Calculs.signe(-100), '-100 %');
      expect(Calculs.signe(200), '+200 %');
    });

    test('aucune séance : zéro partout, aucun écart, aucune division par zéro', () {
      for (final p in PeriodeProgres.values) {
        final r = Calculs.resume(p, const [], _exo, now: DateTime(2026, 10, 2, 12));
        expect(r.volume, 0);
        expect(r.volumeAvant, 0);
        expect(r.ecart, isNull);
        expect(r.seances, 0);
        expect(r.duree, Duration.zero);
        expect(r.records, 0);
        expect(r.groupes, isEmpty);
        expect(r.intensites, isEmpty);
      }
      expect(Calculs.contreMeilleureSemaine(DateTime(2026, 10, 2), const [], _exo), isEmpty);
      expect(Calculs.volumesParSemaine(const [], now: DateTime(2026, 10, 2)).every((b) => b.volume == 0), isTrue);
    });

    test('séances au poids du corps : volume nul, mais le corps s\'allume', () {
      final sessions = [_s('P', DateTime(2026, 10, 1, 18), 'pompes', [(0, 20), (0, 15)])];
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 10, 2, 12));
      expect(r.volume, 0);
      expect(r.seances, 1);
      expect(r.groupes, isEmpty);
      expect(r.intensites[Muscle.pectoraux], 1.0);
    });
  });

  group('numéro de semaine ISO', () {
    test('autour du 1er janvier', () {
      expect(Calculs.numeroSemaine(DateTime(2018, 12, 31)), 1);
      expect(Calculs.numeroSemaine(DateTime(2020, 12, 31)), 53);
      expect(Calculs.numeroSemaine(DateTime(2021, 1, 3, 23, 59)), 53);
      expect(Calculs.numeroSemaine(DateTime(2021, 1, 4)), 1);
      expect(Calculs.numeroSemaine(DateTime(2023, 1, 1)), 52);
      expect(Calculs.numeroSemaine(DateTime(2026, 12, 28)), 53);
      expect(Calculs.numeroSemaine(DateTime(2026, 12, 31)), 53);
      expect(Calculs.numeroSemaine(DateTime(2027, 1, 3)), 53);
      expect(Calculs.numeroSemaine(DateTime(2027, 1, 4)), 1);
      expect(Calculs.numeroSemaine(DateTime(2025, 12, 29)), 1);
      expect(Calculs.numeroSemaine(DateTime(2024, 12, 29)), 52);
    });

    test('jours de changement d\'heure', () {
      expect(Calculs.numeroSemaine(DateTime(2026, 3, 29, 12)), 13);
      expect(Calculs.numeroSemaine(DateTime(2026, 3, 30)), 14);
      expect(Calculs.numeroSemaine(DateTime(2026, 10, 25, 23)), 43);
      expect(Calculs.numeroSemaine(DateTime(2026, 10, 26)), 44);
    });

    test('les barres passent de S52 à S53 puis S1', () {
      final sessions = [
        _s('a', DateTime(2026, 12, 31, 23, 30), 'dc', [(100, 10)]),
        _s('b', DateTime(2027, 1, 4, 0, 0), 'dc', [(50, 10)]),
      ];
      final v = Calculs.volumesParSemaine(sessions, n: 3, now: DateTime(2027, 1, 6));
      expect(v.map((b) => b.label).toList(), ['S52', 'S53', 'S1']);
      expect(v.map((b) => b.debut).toList(), [DateTime(2026, 12, 21), DateTime(2026, 12, 28), DateTime(2027, 1, 4)]);
      expect(v.map((b) => b.volume).toList(), [0, 1000, 500]);
    });
  });

  group('volumes par mois et par année', () {
    final sessions = [
      _s('j', DateTime(2027, 1, 1, 0, 0), 'dc', [(100, 10)]),
      _s('d', DateTime(2026, 12, 31, 23, 59), 'dc', [(50, 10)]),
      _s('f', DateTime(2026, 2, 28, 12), 'dc', [(20, 10)]),
    ];

    test('douze mois à cheval sur deux années', () {
      final v = Calculs.volumesParMois(DateTime(2027, 1), sessions);
      expect(v.first.debut, DateTime(2026, 2));
      expect(v.first.label, 'févr.');
      expect(v.first.volume, 200);
      expect(v[10].volume, 500);
      expect(v.last.debut, DateTime(2027, 1));
      expect(v.last.volume, 1000);
      expect(v.fold(0.0, (a, b) => a + b.volume), 1700);
    });

    test('une séance commencée avant minuit reste dans son mois et son année', () {
      final a26 = Calculs.resume(PeriodeProgres.annee, sessions, _exo, now: DateTime(2026, 12, 31, 23, 59, 59));
      expect(a26.volume, 700);
      expect(a26.seances, 2);
      final a27 = Calculs.resume(PeriodeProgres.annee, sessions, _exo, now: DateTime(2027, 1, 1, 0, 30));
      expect(a27.volume, 1000);
      expect(a27.seances, 1);
      // Au 1er janvier, l'année d'avant s'arrête au 1er janvier aussi.
      expect(a27.volumeAvant, 0);
    });
  });

  group('semaines d\'un mois', () {
    test('la somme des barres est le volume du mois', () {
      final sessions = [
        _s('o', DateTime(2026, 10, 1, 18), 'dc', [(100, 10)]),
        _s('s', DateTime(2026, 9, 30, 18), 'dc', [(70, 10)]),
        _s('s1', DateTime(2026, 9, 1, 18), 'dc', [(30, 10)]),
        _s('a', DateTime(2026, 8, 31, 18), 'dc', [(20, 10)]),
      ];
      final v = Calculs.semainesDuMois(DateTime(2026, 9), sessions, now: DateTime(2026, 10, 2));
      expect(v.map((b) => b.label).toList(), ['S36', 'S37', 'S38', 'S39', 'S40']);
      expect(v.map((b) => b.volume).toList(), [300, 0, 0, 0, 700]);
      expect(v.fold(0.0, (a, b) => a + b.volume), Calculs.volumeDe(Calculs.entre(sessions, DateTime(2026, 9), DateTime(2026, 10))));
    });

    test('février de 28 jours qui commence un lundi : quatre barres', () {
      final v = Calculs.semainesDuMois(DateTime(2021, 2), const [], now: DateTime(2026, 10, 2));
      expect(v.map((b) => b.label).toList(), ['S5', 'S6', 'S7', 'S8']);
    });

    test('mois qui commence un dimanche : six barres', () {
      final v = Calculs.semainesDuMois(DateTime(2026, 3), const [], now: DateTime(2026, 10, 2));
      expect(v.map((b) => b.label).toList(), ['S9', 'S10', 'S11', 'S12', 'S13', 'S14']);
      expect(v.first.debut, DateTime(2026, 2, 23));
    });

    test('janvier 2027 : S53 puis S1', () {
      final v = Calculs.semainesDuMois(DateTime(2027, 1), const [], now: DateTime(2027, 1, 6));
      expect(v.map((b) => b.label).toList(), ['S53', 'S1', 'S2', 'S3', 'S4']);
      expect(v.map((b) => b.courante).toList(), [false, true, false, false, false]);
    });
  });

  group('série de semaines', () {
    DateTime j(int mois, int jour) => DateTime(2026, mois, jour, 18);

    test('semaine en cours sans séance : la série tient', () {
      final s = [_s('a', j(9, 14), 'dc', [(1, 1)]), _s('b', j(9, 23), 'dc', [(1, 1)])];
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 9, 28, 8)), 2);
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 10, 4, 23)), 2);
      // Une semaine entière sans rien : elle est retombée.
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 10, 5, 0)), 0);
    });

    test('un trou d\'une semaine remet à zéro', () {
      final s = [
        _s('a', j(9, 1), 'dc', [(1, 1)]),
        _s('b', j(9, 8), 'dc', [(1, 1)]),
        _s('c', j(9, 22), 'dc', [(1, 1)]),
        _s('d', j(9, 29), 'dc', [(1, 1)]),
      ];
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 10, 2)), 2);
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 9, 13)), 2);
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 9, 20)), 2);
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 9, 21)), 0);
    });

    test('plusieurs séances la même semaine comptent pour une', () {
      final s = [for (var d = 21; d <= 27; d++) _s('$d', j(9, d), 'dc', [(1, 1)])];
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 9, 27, 23)), 1);
    });

    test('ni les séances en cours ni celles du futur ne comptent', () {
      final s = [
        _s('futur', j(10, 20), 'dc', [(1, 1)]),
        _s('ouverte', j(9, 29), 'dc', [(1, 1)], enCours: true),
        _s('a', j(9, 22), 'dc', [(1, 1)]),
      ];
      expect(Calculs.serieSemaines(s, a: DateTime(2026, 10, 2)), 1);
      expect(Calculs.serieSemaines(const [], a: DateTime(2026, 10, 2)), 0);
    });

    test('la série traverse le 1er janvier et les changements d\'heure', () {
      final s = [
        _s('a', DateTime(2026, 12, 20, 9), 'dc', [(1, 1)]),
        _s('b', DateTime(2026, 12, 21, 9), 'dc', [(1, 1)]),
        _s('c', DateTime(2027, 1, 3, 23, 30), 'dc', [(1, 1)]),
        _s('d', DateTime(2027, 1, 4, 0, 0), 'dc', [(1, 1)]),
      ];
      expect(Calculs.serieSemaines(s, a: DateTime(2027, 1, 4, 12)), 4);
      final h = [
        _s('a', DateTime(2026, 10, 18, 9), 'dc', [(1, 1)]),
        _s('b', DateTime(2026, 10, 25, 23, 30), 'dc', [(1, 1)]),
        _s('c', DateTime(2026, 10, 26, 0, 30), 'dc', [(1, 1)]),
      ];
      expect(Calculs.serieSemaines(h, a: DateTime(2026, 10, 27)), 3);
      final e = [
        _s('a', DateTime(2026, 3, 22, 9), 'dc', [(1, 1)]),
        _s('b', DateTime(2026, 3, 29, 3, 30), 'dc', [(1, 1)]),
        _s('c', DateTime(2026, 3, 30, 0, 30), 'dc', [(1, 1)]),
      ];
      expect(Calculs.serieSemaines(e, a: DateTime(2026, 3, 31)), 3);
    });
  });

  group('records', () {
    final sessions = [
      WorkoutSession(
        id: 'ouverte',
        nom: 'En cours',
        debut: DateTime(2026, 9, 16, 18),
        exercices: const [
          SessionExercise(id: 'x', exerciseId: 'dc', series: [WorkoutSet(id: 'x1', poids: 300, reps: 5, fait: true)]),
        ],
      ),
      WorkoutSession(
        id: 'R3',
        nom: 'R3',
        debut: DateTime(2026, 9, 15, 18),
        fin: DateTime(2026, 9, 15, 19),
        exercices: const [
          SessionExercise(id: 'r3a', exerciseId: 'dc', series: [
            // L'échauffement ne compte pas, la série non faite non plus.
            WorkoutSet(id: 'r3w', type: SetType.echauffement, poids: 200, reps: 5, fait: true),
            WorkoutSet(id: 'r3n', poids: 250, reps: 5),
            WorkoutSet(id: 'r3s', poids: 82.5, reps: 10, fait: true),
          ]),
          // Le même exercice une seconde fois dans la séance.
          SessionExercise(id: 'r3b', exerciseId: 'dc', series: [WorkoutSet(id: 'r3t', poids: 85, reps: 10, fait: true)]),
          SessionExercise(id: 'r3c', exerciseId: 'pompes', series: [WorkoutSet(id: 'r3p', reps: 20, fait: true)]),
        ],
      ),
      WorkoutSession(
        id: 'R2',
        nom: 'R2',
        debut: DateTime(2026, 9, 8, 18),
        fin: DateTime(2026, 9, 8, 19),
        exercices: const [
          SessionExercise(id: 'r2a', exerciseId: 'dc', series: [WorkoutSet(id: 'r2s', poids: 80, reps: 10, fait: true)]),
          SessionExercise(id: 'r2c', exerciseId: 'pompes', series: [WorkoutSet(id: 'r2p', reps: 20, fait: true)]),
        ],
      ),
      WorkoutSession(
        id: 'R1',
        nom: 'R1',
        debut: DateTime(2026, 9, 1, 18),
        fin: DateTime(2026, 9, 1, 19),
        exercices: const [
          SessionExercise(id: 'r1a', exerciseId: 'dc', series: [WorkoutSet(id: 'r1s', poids: 80, reps: 10, fait: true)]),
          SessionExercise(id: 'r1c', exerciseId: 'pompes', series: [WorkoutSet(id: 'r1p', reps: 15, fait: true)]),
        ],
      ),
    ];

    test('la première fois et l\'égalité ne sont pas des records', () {
      final r = Calculs.records(sessions);
      expect(r.map((x) => '${x.session.id}/${x.exerciseId}').toList(), ['R2/pompes', 'R3/dc']);
      // La meilleure des deux séries du jour : 85 kg.
      expect(r.last.serie.poids, 85);
      expect(Calculs.serieTexte(r.last.serie), '85 kg × 10');
      expect(Calculs.serieTexte(r.first.serie), '20 rép.');
      expect(r.every((x) => x.valeur > x.avant), isTrue);
    });

    test('nombre de records par période : un par exercice', () {
      final mois = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: DateTime(2026, 9, 20, 12));
      expect(mois.records, 2);
      final semaine = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 9, 20, 12));
      expect(semaine.records, 1);
      final octobre = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: DateTime(2026, 10, 2, 12));
      expect(octobre.records, 0);
      expect(Calculs.exercicesAvecRecord(sessions), 2);
      expect(Calculs.exercicesAvecRecord(const []), 0);
    });

    test('la séance en cours ne compte ni dans le volume ni dans les séances', () {
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 9, 20, 12));
      expect(r.seances, 1);
      expect(r.volume, 82.5 * 10 + 85 * 10);
    });
  });

  group('temps d\'entraînement', () {
    test('séance oubliée ouverte bornée à six heures, fin avant le début ignorée', () {
      final sessions = [
        _s('longue', DateTime(2026, 9, 29, 8), 'dc', [(1, 1)], minutes: 600),
        _s('normale', DateTime(2026, 9, 30, 8), 'dc', [(1, 1)], minutes: 72),
        _s('fausse', DateTime(2026, 10, 1, 8), 'dc', [(1, 1)], minutes: -30),
        _s('ouverte', DateTime(2026, 10, 2, 8), 'dc', [(1, 1)], enCours: true),
      ];
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: DateTime(2026, 10, 2, 12));
      expect(r.seances, 3);
      expect(r.duree, const Duration(hours: 7, minutes: 12));
      expect(Fmt.duree(r.duree), '7 h 12');
    });
  });

  group('calendrier', () {
    test('deux séances le même jour : la première donne le type', () {
      final t = Calculs.typesParJour([
        _s('soir', DateTime(2026, 9, 30, 19), 'dc', [(1, 1)]),
        _s('matin', DateTime(2026, 9, 30, 7), 'dc', const [], type: TypeSeance.cardio),
      ]);
      expect(t.length, 1);
      expect(t[DateTime(2026, 9, 30)], TypeSeance.cardio);
    });

    test('séance à cheval sur minuit : le jour, le mois et l\'année de son début', () {
      final nuit = _s('nuit', DateTime(2026, 12, 31, 23, 30), 'dc', [(100, 10)], minutes: 90);
      final t = Calculs.typesParJour([nuit]);
      expect(t.keys.toList(), [DateTime(2026, 12, 31)]);
      expect(Calculs.entre([nuit], DateTime(2026, 12), DateTime(2027, 1)).length, 1);
      expect(Calculs.entre([nuit], DateTime(2027, 1), DateTime(2027, 2)), isEmpty);
    });

    test('mois lus dans une adresse', () {
      expect(Calculs.lireMois('2026-9'), DateTime(2026, 9));
      expect(Calculs.lireMois('2026-00'), isNull);
      expect(Calculs.lireMois('2026-09-01'), isNull);
      expect(Calculs.lireMois(''), isNull);
      expect(Calculs.lireMois('abc-de'), isNull);
      expect(Calculs.cleMois(DateTime(2027, 1, 31)), '2027-01');
    });
  });

  group('récupération', () {
    final now = DateTime(2026, 10, 2, 12);

    test('formule : trois séries finies il y a douze heures', () {
      // Fin de séance à minuit, 12 h avant.
      final s = [_s('a', DateTime(2026, 10, 1, 23), 'dc', [(80, 10), (80, 10), (80, 10)])];
      final e = Recup.etats(s, _exo, now: now);
      // Pectoraux (60 h) : 3 × (1 - 12/60) / 6 = 0,4 de fatigue.
      expect(e[Muscle.pectoraux]!.pourcentage, 60);
      // Secondaires (48 h), à moitié : 3 × 0,5 × (1 - 12/48) / 6 = 0,1875.
      expect(e[Muscle.triceps]!.pourcentage, 81);
      expect(e[Muscle.deltoidesAnterieurs]!.pourcentage, 81);
      expect(e[Muscle.quadriceps]!.pourcentage, 100);
      // (60 + 81 + 81 + 15 × 100) / 18 = 95,7.
      expect(Recup.global(e), 96);
      final v = Recup.vignettes(e);
      expect(v[1].$1, 'Épaules');
      expect(v[1].$2.muscle, Muscle.deltoidesAnterieurs);
      expect(v[1].$2.pourcentage, 81);
    });

    test('toujours entre 0 et 100', () {
      final lourd = [
        _s('a', DateTime(2026, 10, 2, 10), 'dc', [for (var i = 0; i < 40; i++) (80.0, 10)]),
        _s('b', DateTime(2026, 10, 2, 8), 'dc', [for (var i = 0; i < 40; i++) (80.0, 10)]),
      ];
      final e = Recup.etats(lourd, _exo, now: now);
      expect(e[Muscle.pectoraux]!.pourcentage, 0);
      expect(e.values.every((x) => x.pourcentage >= 0 && x.pourcentage <= 100), isTrue);
      expect(Recup.global(e), inInclusiveRange(0, 100));
    });

    test('muscles jamais travaillés, séances trop vieilles, en cours ou datées du futur : 100', () {
      final s = [
        _s('vieille', DateTime(2026, 9, 28, 10), 'dc', [(80, 10), (80, 10)]),
        _s('futur', DateTime(2026, 10, 3, 10), 'squat', [(80, 10), (80, 10)]),
        _s('ouverte', DateTime(2026, 10, 2, 11), 'tirage', [(80, 10), (80, 10)], enCours: true),
      ];
      final e = Recup.etats(s, _exo, now: now);
      expect(e.values.every((x) => x.pourcentage == 100 && x.pret), isTrue);
      expect(Recup.global(e), 100);
    });

    test('tri du moins au plus récupéré, filtre prêts et en récupération', () {
      final s = [
        _s('a', DateTime(2026, 10, 1, 23), 'dc', [(80, 10), (80, 10), (80, 10)]),
        _s('b', DateTime(2026, 10, 1, 8), 'squat', [(80, 10)]),
      ];
      final e = Recup.etats(s, _exo, now: now);
      final t = Recup.tries(e);
      expect(t.length, 18);
      for (var i = 1; i < t.length; i++) {
        expect(t[i].pourcentage, greaterThanOrEqualTo(t[i - 1].pourcentage));
      }
      // À égalité (81 %), l'ordre de l'enum : épaules avant, puis triceps.
      expect(t.take(3).map((x) => x.muscle).toList(), [Muscle.pectoraux, Muscle.deltoidesAnterieurs, Muscle.triceps]);
      final prets = t.where((x) => x.pret).length;
      expect(prets + t.where((x) => !x.pret).length, 18);
      // Quadriceps : 1 × (1 - 27/72) / 6 = 0,104, soit 90 % : prêt, au seuil.
      expect(e[Muscle.quadriceps]!.pourcentage, 90);
      expect(e[Muscle.quadriceps]!.pret, isTrue);
      expect(prets, 15);
    });

    test('conseil du jour : jamais un groupe dont le muscle affiché est à plat', () {
      // Biceps vidés, tout le reste du corps fatigué, triceps et avant-bras frais.
      final s = [
        _s('a', DateTime(2026, 10, 2, 10), 'curl', [for (var i = 0; i < 12; i++) (20.0, 10)]),
        _s('b', DateTime(2026, 10, 2, 10), 'tout', [for (var i = 0; i < 4; i++) (20.0, 10)]),
      ];
      final e = Recup.etats(s, _exo, now: now);
      expect(e[Muscle.biceps]!.pourcentage, 0);
      expect(e[Muscle.quadriceps]!.pourcentage, inInclusiveRange(30, 40));
      final c = Recup.conseil(e, s, _exo);
      expect(c.groupe, isNot(MuscleRegion.bras), reason: Recup.phrase(c));
      expect(c.pourcentage, e[c.phare]!.pourcentage);
      expect(c.pourcentage, greaterThan(0));
    });

    test('conseil : le chiffre annoncé est celui de la vignette', () {
      final s = [
        _s('a', DateTime(2026, 10, 1, 23), 'dc', [(80, 10), (80, 10), (80, 10)]),
        _s('b', DateTime(2026, 10, 1, 23), 'squat', [(80, 10), (80, 10), (80, 10)]),
        _s('c', DateTime(2026, 9, 30, 23), 'tirage', [(80, 10)]),
      ];
      final e = Recup.etats(s, _exo, now: now);
      final c = Recup.conseil(e, s, _exo);
      expect(c.pourcentage, e[c.phare]!.pourcentage);
      // Aucun groupe n'a un muscle phare mieux récupéré que le groupe conseillé
      // si tous ses muscles sont prêts.
      expect(e.values.where((x) => x.muscle.region == c.groupe).every((x) => x.pret), isTrue);
    });

    test('sans aucune séance : tout est prêt, un conseil quand même', () {
      final e = Recup.etats(const [], _exo, now: now);
      expect(e.length, 18);
      expect(Recup.global(e), 100);
      expect(Recup.global(const {}), 100);
      final c = Recup.conseil(e, const [], _exo);
      expect(c.pourcentage, 100);
      expect(Recup.phrase(c), endsWith('à 100 %'));
      expect(Recup.tries(e).first.muscle, Muscle.pectoraux);
    });
  });
}
