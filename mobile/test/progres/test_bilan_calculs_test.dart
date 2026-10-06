import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/progres/logic/bilan_mois.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/ui/bilan/pages.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_bilan_banc.dart';

final _exos = {
  for (final e in exercicesBanc) e.id: e,
  for (var i = 0; i < 60; i++) 'x$i': Exercise(id: 'x$i', nom: 'Exercice ${i.toString().padLeft(2, '0')}', musclesPrincipaux: const [Muscle.pectoraux]),
};

Exercise? _exo(String id) => _exos[id];

BilanMois _bilan(DateTime mois, List<WorkoutSession> s, DateTime now) => BilanMois.calculer(mois, s, _exo, now: now);

/// Calculs du bilan du mois, recoupés à la main.
void main() {
  final octobre = DateTime(2026, 10, 2, 12);

  group('mois sans rien, première séance, premier mois', () {
    test('aucune séance du tout : tout à zéro, rien ne casse', () {
      final b = _bilan(DateTime(2026, 9), const [], octobre);
      expect(b.vide, isTrue);
      expect(b.nbSeances, 0);
      expect(b.volume, 0);
      expect(b.dureeTotale, Duration.zero);
      expect(b.ecartSeances, isNull);
      expect(b.ecartVolume, isNull);
      expect(b.serieSemaines, 0);
      expect(b.nbRecords, 0);
      expect(b.favoris, isEmpty);
      expect(b.regularite.length, 9);
      expect(b.regularite.every((m) => m.jours.every((j) => !j)), isTrue);
      expect(b.volumes.length, 12);
      expect(b.volumes.every((v) => v.volume == 0), isTrue);
      expect(b.toile.every((a) => a.mois == 0 && a.avant == 0), isTrue);
    });

    test('une seule séance, premier mois d\'utilisation : pas d\'écart, pas de record, toile sans mois d\'avant', () {
      final s = [seance(DateTime(2026, 9, 14, 18), 'dc', [(60, 10), (60, 8)], minutes: 49)];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbSeances, 1);
      expect(b.volume, 60 * 10 + 60 * 8);
      expect(b.dureeTotale, const Duration(minutes: 49));
      expect(b.ecartSeances, isNull);
      expect(b.ecartVolume, isNull);
      // La première fois d'un exercice n'est pas un record.
      expect(b.nbRecords, 0);
      expect(b.favoris.single, (exerciseId: 'dc', series: 2));
      expect(b.toile.every((a) => a.avant == 0), isTrue);
      expect(b.toile.firstWhere((a) => a.muscle == Muscle.pectoraux).mois, 1.0);
      // Triceps en secondaire : la moitié.
      expect(b.toile.firstWhere((a) => a.muscle == Muscle.triceps).mois, 0.5);
      expect(b.avantVide, isTrue);
      // Une séance le lundi 14 : la semaine du 14 compte, celle du 28 (sans séance) ne casse pas mais ne compte pas.
      expect(b.serieSemaines, 0);
    });

    test('le mois d\'avant vide mais un historique plus ancien : pas d\'écart', () {
      final s = [
        seance(DateTime(2026, 9, 14, 18), 'dc', [(60, 10)]),
        seance(DateTime(2026, 7, 14, 18), 'dc', [(50, 10)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.ecartSeances, isNull);
      expect(b.ecartVolume, isNull);
      expect(b.nbRecords, 1);
      expect(b.avantVide, isTrue);
    });
  });

  group('totaux et écarts', () {
    test('quarante séances : toutes listées dans l\'ordre, totaux exacts', () {
      // Deux par jour sur vingt jours, données dans le désordre.
      final s = [
        for (var j = 1; j <= 20; j++) ...[
          seance(DateTime(2026, 9, j, 19), 'squat', [(100, 5)], nom: 'Soir $j', minutes: 61),
          seance(DateTime(2026, 9, j, 7), 'dc', [(50, 10), (50, 10)], nom: 'Matin $j', minutes: 30),
        ],
      ]..shuffle();
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbSeances, 40);
      expect(b.seances.first.nom, 'Matin 1');
      expect(b.seances[1].nom, 'Soir 1');
      expect(b.seances.last.nom, 'Soir 20');
      expect(b.volume, 20 * (500 + 1000));
      expect(b.dureeTotale, const Duration(minutes: 20 * 91));
      expect(b.seances.fold(0.0, (a, x) => a + x.volume), b.volume);
      expect(b.seances.fold(Duration.zero, (a, x) => a + x.duree), b.dureeTotale);
      // 30 h 20 : trente heures pleines.
      expect(b.heures, 30);
    });

    test('écarts : 14 séances contre 28, volume divisé par deux, arrondis', () {
      final s = [
        for (var j = 1; j <= 14; j++) seance(DateTime(2026, 9, j, 18), 'dc', [(50, 10)]),
        for (var j = 1; j <= 28; j++) seance(DateTime(2026, 8, j, 18), 'dc', [(51, 10)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.ecartSeances, -50);
      // 7 000 contre 14 280 : -50,98 %.
      expect(b.ecartVolume, -51);
    });

    test('écarts : hausse énorme, écart nul, mois d\'avant sans charge', () {
      final hausse = _bilan(
        DateTime(2026, 9),
        [
          for (var j = 1; j <= 20; j++) seance(DateTime(2026, 9, j, 18), 'dc', [(100, 10)]),
          seance(DateTime(2026, 8, 3, 18), 'dc', [(10, 10)]),
        ],
        octobre,
      );
      expect(hausse.ecartSeances, 1900);
      expect(hausse.ecartVolume, 19900);

      final egal = _bilan(
        DateTime(2026, 9),
        [seance(DateTime(2026, 9, 3, 18), 'dc', [(50, 10)]), seance(DateTime(2026, 8, 3, 18), 'dc', [(50, 10)])],
        octobre,
      );
      expect(egal.ecartSeances, isNull);
      expect(egal.ecartVolume, isNull);

      // Août au poids du corps : des séances mais aucun volume.
      final corps = _bilan(
        DateTime(2026, 9),
        [seance(DateTime(2026, 9, 3, 18), 'dc', [(50, 10)]), seance(DateTime(2026, 8, 3, 18), 'tractions', [(0, 10)])],
        octobre,
      );
      expect(corps.ecartSeances, isNull);
      expect(corps.ecartVolume, isNull);
      expect(corps.avantVide, isFalse);
    });

    test('bords du mois : minuit le 1er compte, minuit le 1er suivant non ; janvier se compare à décembre', () {
      final s = [
        seance(DateTime(2026, 1, 1), 'dc', [(50, 10)], nom: 'Minuit'),
        seance(DateTime(2026, 1, 31, 23, 30), 'dc', [(50, 10)], nom: 'Fin'),
        seance(DateTime(2026, 2, 1), 'dc', [(50, 10)], nom: 'Février'),
        seance(DateTime(2025, 12, 31, 23, 59), 'dc', [(40, 10)], nom: 'Décembre'),
      ];
      final b = _bilan(DateTime(2026, 1), s, octobre);
      expect(b.seances.map((x) => x.nom).toList(), ['Minuit', 'Fin']);
      expect(b.ecartSeances, 100);
      expect(b.ecartVolume, 150);
      // La séance de 23 h 30 allume le 31, pas le 1er février.
      expect(b.regularite.last.jours.last, isTrue);
      expect(b.regularite.last.jours.first, isTrue);
      expect(b.regularite[7].mois, DateTime(2025, 12));
      expect(b.regularite[7].jours.last, isTrue);
    });

    test('une séance encore ouverte ne compte nulle part', () {
      final s = [
        seance(DateTime(2026, 9, 3, 18), 'dc', [(50, 10)]),
        seance(DateTime(2026, 9, 5, 18), 'dc', [(500, 10)], enCours: true),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbSeances, 1);
      expect(b.volume, 500);
      expect(b.regularite.last.jours[4], isFalse);
      expect(b.nbRecords, 0);
    });

    test('une séance oubliée ouverte trois jours ne pèse pas plus de six heures', () {
      final s = [seance(DateTime(2026, 9, 3, 18), 'dc', [(50, 10)], minutes: 3 * 24 * 60)];
      expect(_bilan(DateTime(2026, 9), s, octobre).dureeTotale, const Duration(hours: 6));
    });

    test('heures : pleines, jamais arrondies au-dessus (22 h 51 fait 22 heures)', () {
      final s = [
        for (var j = 1; j <= 13; j++) seance(DateTime(2026, 9, j, 18), 'dc', [(50, 10)], minutes: 100),
        seance(DateTime(2026, 9, 20, 18), 'dc', [(50, 10)], minutes: 71),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.dureeTotale, const Duration(hours: 22, minutes: 51));
      expect(b.heures, 22);
    });

    test('volume énorme : pas de perte, format lisible', () {
      final s = [for (var j = 1; j <= 30; j++) seance(DateTime(2026, 9, j, 18), 'squat', [(500, 100), (500, 100), (500, 100)])];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.volume, 4500000);
    });
  });

  group('régularité', () {
    test('neuf mois à cheval sur deux années, février bissextile, premier jour de semaine', () {
      final b = _bilan(DateTime(2024, 3), [seance(DateTime(2024, 2, 29, 12), 'dc', [(50, 10)])], DateTime(2024, 4, 2));
      expect(b.regularite.map((m) => (m.mois.year, m.mois.month)).toList(), [
        (2023, 7), (2023, 8), (2023, 9), (2023, 10), (2023, 11), (2023, 12), (2024, 1), (2024, 2), (2024, 3),
      ]);
      expect(b.regularite.map((m) => m.jours.length).toList(), [31, 31, 30, 31, 30, 31, 31, 29, 31]);
      // Premier jour : samedi, mardi, vendredi, dimanche, mercredi, vendredi, lundi, jeudi, vendredi.
      expect(b.regularite.map((m) => m.decalage).toList(), [5, 1, 4, 6, 2, 4, 0, 3, 4]);
      final fevrier = b.regularite[7];
      expect(fevrier.jours.last, isTrue);
      expect(fevrier.jours.where((x) => x).length, 1);
      // Aucun mois ne dépasse six lignes de sept cases.
      for (final m in b.regularite) {
        expect(m.decalage + m.jours.length, lessThanOrEqualTo(42));
      }
    });

    test('février de quatre lignes pile (2027 : 28 jours, commence un lundi)', () {
      final m = BilanMois.casesDe(DateTime(2027, 2), {DateTime(2027, 2, 28)});
      expect(m.decalage, 0);
      expect(m.jours.length, 28);
      expect(m.jours.last, isTrue);
    });

    test('changement d\'heure : chaque jour de mars et d\'octobre a sa case', () {
      final s = [
        seance(DateTime(2026, 3, 29, 1, 30), 'dc', [(50, 10)]),
        seance(DateTime(2026, 3, 29, 23, 30), 'dc', [(50, 10)]),
        seance(DateTime(2026, 10, 25, 2, 30), 'dc', [(50, 10)]),
        seance(DateTime(2026, 10, 26, 0, 10), 'dc', [(50, 10)]),
      ];
      final b = _bilan(DateTime(2026, 10), s, DateTime(2026, 11, 3));
      final mars = b.regularite.firstWhere((m) => m.mois == DateTime(2026, 3));
      expect([for (var i = 0; i < mars.jours.length; i++) if (mars.jours[i]) i + 1], [29]);
      final oct = b.regularite.last;
      expect(oct.jours.length, 31);
      expect([for (var i = 0; i < oct.jours.length; i++) if (oct.jours[i]) i + 1], [25, 26]);
    });

    test('deux séances le même jour : une seule case', () {
      final s = [seance(DateTime(2026, 9, 3, 7), 'dc', [(50, 10)]), seance(DateTime(2026, 9, 3, 19), 'dc', [(50, 10)])];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.regularite.last.jours.where((x) => x).length, 1);
      expect(b.nbSeances, 2);
    });
  });

  group('douze mois de volume', () {
    test('du mois d\'il y a onze mois au mois du bilan, à cheval sur l\'année', () {
      final s = [
        seance(DateTime(2026, 2, 10, 18), 'dc', [(50, 10)]),
        seance(DateTime(2025, 3, 1), 'dc', [(40, 10)]),
        seance(DateTime(2025, 2, 28, 23), 'dc', [(999, 10)]),
        seance(DateTime(2025, 12, 31, 23, 59), 'dc', [(30, 10)]),
        seance(DateTime(2026, 3, 1), 'dc', [(999, 10)]),
      ];
      final b = _bilan(DateTime(2026, 2), s, octobre);
      expect(b.volumes.first.debut, DateTime(2025, 3));
      expect(b.volumes.last.debut, DateTime(2026, 2));
      expect(b.volumes.map((v) => v.volume).toList(), [400, 0, 0, 0, 0, 0, 0, 0, 0, 300, 0, 500]);
      expect(b.volumes.where((v) => v.courante).single.debut, DateTime(2026, 2));
      expect(b.volumes.map((v) => v.label).toList(), ['mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.', 'janv.', 'févr.']);
    });
  });

  group('série de semaines', () {
    // Septembre 2026 finit un mercredi : la dernière semaine va du lundi 28 au dimanche 4 octobre.
    List<WorkoutSession> lundis(int n, DateTime dernier) => [
          for (var i = 0; i < n; i++) seance(DateTime(dernier.year, dernier.month, dernier.day - 7 * i, 18), 'dc', [(50, 10)]),
        ];

    test('comptée au dernier jour du mois : les séances d\'après ne comptent pas', () {
      final s = [
        ...lundis(5, DateTime(2026, 9, 21)),
        // Jeudi 1er octobre : même semaine que le 30 septembre, mais hors du mois.
        seance(DateTime(2026, 10, 1, 18), 'dc', [(50, 10)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      // La semaine du 28 n'a pas de séance avant le 1er : elle ne casse pas la série, sans compter.
      expect(b.serieSemaines, 5);
      // Vue depuis octobre, la semaine du 28 compte.
      expect(_bilan(DateTime(2026, 10), s, octobre).serieSemaines, 6);
    });

    test('une séance le dernier jour du mois compte, même tard le soir', () {
      final s = [...lundis(3, DateTime(2026, 9, 21)), seance(DateTime(2026, 9, 30, 23, 50), 'dc', [(50, 10)])];
      expect(_bilan(DateTime(2026, 9), s, octobre).serieSemaines, 4);
    });

    test('un trou de deux semaines remet à zéro', () {
      final s = [...lundis(4, DateTime(2026, 9, 7))];
      expect(_bilan(DateTime(2026, 9), s, octobre).serieSemaines, 0);
    });

    test('à cheval sur le nouvel an et sur les changements d\'heure', () {
      // Trente lundis de suite jusqu'au 28 décembre 2026 (passe par le 25 octobre).
      final s = lundis(30, DateTime(2026, 12, 28));
      expect(_bilan(DateTime(2026, 12), s, DateTime(2027, 1, 5)).serieSemaines, 30);
      // En janvier 2027, vu le 5 : la semaine du 4 est en cours, sans séance.
      expect(_bilan(DateTime(2027, 1), s, DateTime(2027, 1, 5)).serieSemaines, 30);
      // Tout le mois de mars 2026 (changement d'heure le 29).
      final t = lundis(10, DateTime(2026, 3, 30));
      expect(_bilan(DateTime(2026, 3), t, DateTime(2026, 4, 20)).serieSemaines, 10);
    });

    test('mois en cours : comptée aujourd\'hui, pas à la fin du mois', () {
      final s = lundis(3, DateTime(2026, 9, 28));
      expect(_bilan(DateTime(2026, 10), s, octobre).serieSemaines, 3);
    });
  });

  group('toile des muscles', () {
    test('échelle commune aux deux mois, épaules au faisceau le plus travaillé', () {
      final s = [
        // Septembre : 4 séries de pectoraux, 2 d'élévations latérales.
        seance(DateTime(2026, 9, 3, 18), 'dc', [(50, 10), (50, 10), (50, 10), (50, 10)]),
        seance(DateTime(2026, 9, 4, 18), 'lat', [(8, 12), (8, 12)]),
        // Août : 8 séries de squat.
        seance(DateTime(2026, 8, 3, 18), 'squat', [for (var i = 0; i < 8; i++) (100, 5)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      double m(Muscle x) => b.toile.firstWhere((a) => a.muscle == x).mois;
      double av(Muscle x) => b.toile.firstWhere((a) => a.muscle == x).avant;
      expect(b.toile.map((a) => a.muscle).toList(), BilanMois.axes);
      // Le plus grand des deux mois : 8 séries de quadriceps en août.
      expect(av(Muscle.quadriceps), 1.0);
      expect(av(Muscle.ischios), 0.5);
      expect(m(Muscle.pectoraux), 0.5);
      expect(m(Muscle.triceps), 0.25);
      // Épaules : antérieur 2 (secondaire du développé), latéral 2 : le plus grand, pas la somme.
      expect(m(Muscle.deltoidesLateraux), 0.25);
      expect(m(Muscle.trapezes), 0.125);
      expect(m(Muscle.quadriceps), 0);
      for (final a in b.toile) {
        expect(a.mois, inInclusiveRange(0, 1));
        expect(a.avant, inInclusiveRange(0, 1));
      }
    });

    test('les échauffements et les séries non faites ne comptent pas', () {
      final s = WorkoutSession(
        id: 'w',
        nom: 'W',
        debut: DateTime(2026, 9, 3, 18),
        fin: DateTime(2026, 9, 3, 19),
        exercices: const [
          SessionExercise(id: 'e', exerciseId: 'dc', series: [
            WorkoutSet(id: '1', type: SetType.echauffement, poids: 20, reps: 10, fait: true),
            WorkoutSet(id: '2', poids: 50, reps: 10, fait: true),
            WorkoutSet(id: '3', poids: 50, reps: 10),
          ]),
        ],
      );
      final b = _bilan(DateTime(2026, 9), [s], octobre);
      expect(b.favoris.single.series, 1);
      expect(b.volume, 500);
    });
  });

  group('records', () {
    test('vingt records : vingt comptés, cinq montrés, les plus fortes progressions d\'abord', () {
      final s = [
        for (var i = 0; i < 20; i++) ...[
          seance(DateTime(2026, 8, 1 + i, 18), 'x$i', [(100, 5)]),
          // Progression de 1 kg (x0) à 20 kg (x19).
          seance(DateTime(2026, 9, 1 + i, 18), 'x$i', [(101.0 + i, 5)]),
        ],
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbRecords, 20);
      expect(b.records.map((r) => r.exerciseId).toList(), ['x19', 'x18', 'x17', 'x16', 'x15']);
      expect(b.records.first.serie.poids, 120);
    });

    test('record battu deux fois dans le mois : un seul, la dernière série, progression depuis avant le mois', () {
      final s = [
        seance(DateTime(2026, 8, 3, 18), 'dc', [(50, 10)]),
        seance(DateTime(2026, 9, 3, 18), 'dc', [(55, 10)]),
        seance(DateTime(2026, 9, 10, 18), 'dc', [(60, 10)]),
        seance(DateTime(2026, 8, 3, 19), 'squat', [(100, 5)]),
        seance(DateTime(2026, 9, 4, 18), 'squat', [(115, 5)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbRecords, 2);
      // Développé : +20 % ; squat : +15 %.
      expect(b.records.map((r) => r.exerciseId).toList(), ['dc', 'squat']);
      expect(b.records.first.serie.poids, 60);
    });

    test('progressions égales : ordre stable (par nom), quel que soit l\'ordre des séances', () {
      List<WorkoutSession> jeu() => [
            for (var i = 0; i < 40; i++) ...[
              seance(DateTime(2026, 8, 1, 6 + (i % 12)), 'x$i', [(100, 5)]),
              seance(DateTime(2026, 9, 1 + (i % 28), 6 + (i % 12)), 'x$i', [(110, 5)]),
            ],
          ];
      final a = _bilan(DateTime(2026, 9), jeu(), octobre);
      final b = _bilan(DateTime(2026, 9), jeu().reversed.toList(), octobre);
      expect(a.nbRecords, 40);
      expect(a.records.map((r) => r.exerciseId).toList(), ['x0', 'x1', 'x2', 'x3', 'x4']);
      expect(b.records.map((r) => r.exerciseId).toList(), a.records.map((r) => r.exerciseId).toList());
    });

    test('au poids du corps : un record de répétitions, affiché en répétitions', () {
      final s = [
        seance(DateTime(2026, 8, 3, 18), 'tractions', [(0, 8)]),
        seance(DateTime(2026, 9, 3, 18), 'tractions', [(0, 12)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbRecords, 1);
      expect(Calculs.serieTexte(b.records.single.serie), '12 rép.');
    });

    test('passer du poids du corps au lesté ne passe pas devant une vraie progression', () {
      final s = [
        // Tractions : 8 répétitions sans charge, puis lestées de 5 kg.
        seance(DateTime(2026, 8, 3, 18), 'tractions', [(0, 8)]),
        seance(DateTime(2026, 9, 3, 18), 'tractions', [(5, 5)]),
        // Squat : de 100 à 140 kg, +40 %.
        seance(DateTime(2026, 8, 4, 18), 'squat', [(100, 5)]),
        seance(DateTime(2026, 9, 4, 18), 'squat', [(140, 5)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.nbRecords, 2);
      expect(b.records.first.exerciseId, 'squat');
    });

    test('un record du mois suivant ou du mois d\'avant ne compte pas', () {
      final s = [
        seance(DateTime(2026, 7, 3, 18), 'dc', [(50, 10)]),
        seance(DateTime(2026, 8, 31, 23, 59), 'dc', [(55, 10)]),
        seance(DateTime(2026, 9, 15, 18), 'dc', [(55, 10)]),
        seance(DateTime(2026, 10, 1), 'dc', [(60, 10)]),
      ];
      expect(_bilan(DateTime(2026, 9), s, octobre).nbRecords, 0);
    });
  });

  group('exercices favoris', () {
    test('les cinq plus pratiqués, en séries', () {
      final s = [
        seance(DateTime(2026, 9, 1, 18), 'dc', [for (var i = 0; i < 6; i++) (50, 10)]),
        seance(DateTime(2026, 9, 2, 18), 'squat', [for (var i = 0; i < 5; i++) (50, 10)]),
        seance(DateTime(2026, 9, 3, 18), 'tirage', [for (var i = 0; i < 4; i++) (50, 10)]),
        seance(DateTime(2026, 9, 4, 18), 'curl', [for (var i = 0; i < 3; i++) (50, 10)]),
        seance(DateTime(2026, 9, 5, 18), 'crunch', [for (var i = 0; i < 2; i++) (0, 10)]),
        seance(DateTime(2026, 9, 6, 18), 'lat', [(8, 10)]),
        seance(DateTime(2026, 9, 7, 18), 'dc', [(50, 10)]),
        seance(DateTime(2026, 8, 7, 18), 'lat', [for (var i = 0; i < 30; i++) (8, 10)]),
      ];
      final b = _bilan(DateTime(2026, 9), s, octobre);
      expect(b.favoris.map((f) => (f.exerciseId, f.series)).toList(), [('dc', 7), ('squat', 5), ('tirage', 4), ('curl', 3), ('crunch', 2)]);
    });

    test('égalités : ordre stable (par nom), quel que soit l\'ordre des séances', () {
      List<WorkoutSession> jeu() => [
            for (var i = 0; i < 40; i++) seance(DateTime(2026, 9, 1 + (i % 28), 6 + (i % 12)), 'x$i', [(50, 10), (50, 10), (50, 10)]),
          ];
      final a = _bilan(DateTime(2026, 9), jeu(), octobre);
      final b = _bilan(DateTime(2026, 9), jeu().reversed.toList(), octobre);
      final c = _bilan(DateTime(2026, 9), jeu()..shuffle(), octobre);
      expect(a.favoris.map((f) => f.exerciseId).toList(), ['x0', 'x1', 'x2', 'x3', 'x4']);
      expect(b.favoris, a.favoris);
      expect(c.favoris, a.favoris);
    });
  });

  group('textes', () {
    test('« de septembre », « d\'avril », « d\'août », « d\'octobre »', () {
      expect(deMois(DateTime(2026, 9)), 'de septembre');
      expect(deMois(DateTime(2026, 4)), 'd\'avril');
      expect(deMois(DateTime(2026, 8)), 'd\'août');
      expect(deMois(DateTime(2026, 10)), 'd\'octobre');
      expect(deMois(DateTime(2026, 1)), 'de janvier');
    });

    test('lecture du paramètre mois : rien d\'invalide ne passe, rien ne lève', () {
      expect(Calculs.lireMois('2026-09'), DateTime(2026, 9));
      expect(Calculs.lireMois('2026-9'), DateTime(2026, 9));
      for (final x in [null, '', 'abc', '2026', '2026-13', '2026-00', '2026-09-01', '-5-3', '2026-', '-09', '2026-1.5', '999999999-01', '0-01']) {
        expect(() => Calculs.lireMois(x), returnsNormally, reason: '$x');
      }
      for (final x in ['abc', '2026-13', '2026-00', '2026-09-01', '999999999-01']) {
        expect(Calculs.lireMois(x), isNull, reason: x);
      }
    });
  });
}
