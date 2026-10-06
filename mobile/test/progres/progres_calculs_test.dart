import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/progres/logic/bilan_mois.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/progres_paths.dart';
import 'package:aesthetic/features/sante/recuperation/recup_calcul.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _s(String id, DateTime d, String exo, List<(double, int)> sets, {int minutes = 60, TypeSeance type = TypeSeance.musculation}) =>
    WorkoutSession(
      id: id,
      nom: 'Séance $id',
      debut: d,
      fin: d.add(Duration(minutes: minutes)),
      type: type,
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

const _exercices = {
  'dc': Exercise(id: 'dc', nom: 'Développé couché', musclesPrincipaux: [Muscle.pectoraux], musclesSecondaires: [Muscle.deltoidesAnterieurs, Muscle.triceps]),
  'squat': Exercise(id: 'squat', nom: 'Squat', musclesPrincipaux: [Muscle.quadriceps], musclesSecondaires: [Muscle.fessiers]),
  'tirage': Exercise(id: 'tirage', nom: 'Tirage', musclesPrincipaux: [Muscle.grandDorsal], musclesSecondaires: [Muscle.biceps]),
};

Exercise? _exo(String id) => _exercices[id];

void main() {
  // Vendredi 2 octobre 2026, midi.
  final now = DateTime(2026, 10, 2, 12);
  // Récentes d'abord, comme SessionRepo.sessions.
  final sessions = [
    _s('B', DateTime(2026, 10, 1, 18), 'squat', [(100, 5), (100, 5)]),
    _s('A', DateTime(2026, 9, 28, 18), 'dc', [(80, 10), (80, 10), (80, 10)]),
    _s('D', DateTime(2026, 9, 26, 10), 'tirage', [(60, 10), (60, 10)]),
    _s('C', DateTime(2026, 9, 22, 18), 'dc', [(75, 10), (75, 10)]),
    _s('E', DateTime(2026, 8, 10, 18), 'dc', [(70, 10), (70, 10)]),
    _s('F', DateTime(2026, 8, 3, 18), 'squat', [(90, 5)]),
  ];

  group('périodes', () {
    test('la semaine en cours, comparée à la semaine passée arrêtée au même point', () {
      final r = Calculs.resume(PeriodeProgres.semaine, sessions, _exo, now: now);
      expect(r.debut, DateTime(2026, 9, 28));
      expect(r.fin, DateTime(2026, 10, 5));
      expect(r.volume, 3400);
      expect(r.seances, 2);
      expect(r.duree, const Duration(hours: 2));
      // La séance D (samedi) tombe après le vendredi midi de la semaine passée.
      expect(r.volumeAvant, 1500);
      expect(r.ecart, 127);
      // Le développé couché et le squat ont battu leur record.
      expect(r.records, 2);
      expect(r.groupes.map((g) => Calculs.groupe(g.groupe)).toList(), ['Pectoraux', 'Jambes']);
      expect(r.groupes.first.part, closeTo(2400 / 3400, 1e-9));
      expect(r.groupes.fold(0.0, (a, g) => a + g.part), closeTo(1, 1e-9));
      expect(r.intensites[Muscle.pectoraux], 1.0);
    });

    test('le mois et l\'année', () {
      final m = Calculs.resume(PeriodeProgres.mois, sessions, _exo, now: now);
      expect(m.debut, DateTime(2026, 10));
      expect(m.volume, 1000);
      expect(m.seances, 1);
      // Rien les deux premiers jours de septembre : pas d'écart à afficher.
      expect(m.volumeAvant, 0);
      expect(m.ecart, isNull);

      final a = Calculs.resume(PeriodeProgres.annee, sessions, _exo, now: now);
      expect(a.debut, DateTime(2026));
      expect(a.seances, 6);
      expect(a.volume, 3400 + 1500 + 1200 + 1400 + 450);
      expect(a.records, 2);
    });

    test('un écart nul ou sans base ne s\'affiche pas', () {
      expect(Calculs.ecart(100, 0), isNull);
      expect(Calculs.ecart(100, 100), isNull);
      expect(Calculs.ecart(100.2, 100), isNull);
      expect(Calculs.ecart(112, 100), 12);
      expect(Calculs.ecart(50, 100), -50);
      expect(Calculs.signe(12), '+12 %');
      expect(Calculs.signe(-50), '-50 %');
    });

    test('bilan de la semaine : semaine entière contre semaine entière', () {
      final r = Calculs.semaine(now, sessions, _exo);
      expect(r.volume, 3400);
      expect(r.volumeAvant, 2700);
      expect(r.ecart, 26);
      expect(Calculs.semaineLibelle(r.debut), '28 sept. au 4 oct.');
      expect(Calculs.semaineLibelle(DateTime(2026, 9, 21)), '21 au 27 sept.');
      final forme = Calculs.contreMeilleureSemaine(now, sessions, _exo);
      expect(forme[MuscleRegion.poitrine], 100);
      // La semaine passée, les pectoraux étaient à 1 500 kg sur un record de 1 500.
      final avant = Calculs.contreMeilleureSemaine(DateTime(2026, 9, 22), sessions, _exo);
      expect(avant[MuscleRegion.poitrine], 100);
      expect(avant.containsKey(MuscleRegion.jambes), isFalse);
    });
  });

  group('volumes', () {
    test('par semaine, la semaine en cours en dernier', () {
      final v = Calculs.volumesParSemaine(sessions, n: 3, now: now);
      expect(v.map((b) => b.label).toList(), ['S38', 'S39', 'S40']);
      expect(v.map((b) => b.volume).toList(), [0, 2700, 3400]);
      expect(v.map((b) => b.courante).toList(), [false, false, true]);
    });

    test('numéro de semaine ISO', () {
      expect(Calculs.numeroSemaine(DateTime(2026, 10, 2)), 40);
      expect(Calculs.numeroSemaine(DateTime(2026, 1, 1)), 1);
      expect(Calculs.numeroSemaine(DateTime(2027, 1, 1)), 53);
      expect(Calculs.numeroSemaine(DateTime(2024, 12, 30)), 1);
    });

    test('les semaines d\'un mois', () {
      final v = Calculs.semainesDuMois(DateTime(2026, 9), sessions, now: now);
      expect(v.map((b) => b.label).toList(), ['S36', 'S37', 'S38', 'S39', 'S40']);
      // Seuls les jours du mois comptent : la séance du 1er octobre (1 000 kg) reste en octobre.
      expect(v.map((b) => b.volume).toList(), [0, 0, 0, 2700, 2400]);
      expect(v.last.courante, isTrue);
    });

    test('par mois sur douze mois', () {
      final v = Calculs.volumesParMois(DateTime(2026, 9), sessions);
      expect(v.length, 12);
      expect(v.first.debut, DateTime(2025, 10));
      expect(v.last.debut, DateTime(2026, 9));
      expect(v.last.volume, 5100);
      expect(v[10].volume, 1850);
      expect(v.last.courante, isTrue);
    });
  });

  group('records et série', () {
    test('un record dépasse tout l\'historique, la première fois ne compte pas', () {
      final r = Calculs.records(sessions);
      expect(r.map((x) => x.session.id).toList(), ['C', 'A', 'B']);
      expect(r.first.avant, lessThan(r.first.valeur));
      expect(Calculs.exercicesAvecRecord(sessions), 3);
      expect(Calculs.serieTexte(r[1].serie), '80 kg × 10');
      expect(Calculs.serieTexte(const WorkoutSet(id: 'x', reps: 15, fait: true)), '15 rép.');
    });

    test('série de semaines', () {
      expect(Calculs.serieSemaines(sessions, a: now), 2);
      // Fin août : la semaine du 24 est vide, la série est retombée.
      expect(Calculs.serieSemaines(sessions, a: DateTime(2026, 8, 31)), 0);
      expect(Calculs.serieSemaines(sessions, a: DateTime(2026, 8, 12)), 2);
      // La semaine en cours, encore vide, ne casse pas la série.
      expect(Calculs.serieSemaines(sessions.skip(1).toList(), a: DateTime(2026, 10, 6)), 2);
    });

    test('type de séance par jour', () {
      final t = Calculs.typesParJour([
        ...sessions,
        _s('G', DateTime(2026, 9, 30, 7), 'squat', const [], type: TypeSeance.cardio),
      ]);
      expect(t[DateTime(2026, 10, 1)], TypeSeance.musculation);
      expect(t[DateTime(2026, 9, 30)], TypeSeance.cardio);
      expect(t[DateTime(2026, 9, 29)], isNull);
    });
  });

  group('bilan du mois', () {
    final b = BilanMois.calculer(DateTime(2026, 9, 15), sessions, _exo, now: now);

    test('séances, volume et comparaison au mois d\'avant', () {
      expect(b.mois, DateTime(2026, 9));
      expect(b.seances.map((s) => s.nom).toList(), ['Séance C', 'Séance D', 'Séance A']);
      expect(b.volume, 5100);
      expect(b.dureeTotale, const Duration(hours: 3));
      expect(b.heures, 3);
      expect(b.ecartSeances, 50);
      expect(b.ecartVolume, 176);
    });

    test('régularité : neuf mois de cases', () {
      expect(b.regularite.length, 9);
      expect(b.regularite.first.mois, DateTime(2026, 1));
      final sept = b.regularite.last;
      expect(sept.mois, DateTime(2026, 9));
      // Le 1er septembre 2026 est un mardi : une case vide avant.
      expect(sept.decalage, 1);
      expect(sept.jours.length, 30);
      expect([for (var i = 0; i < 30; i++) if (sept.jours[i]) i + 1], [22, 26, 28]);
      final aout = b.regularite[7];
      expect(aout.decalage, 5);
      expect(aout.jours.where((x) => x).length, 2);
    });

    test('volume sur douze mois, série, records, favoris', () {
      expect(b.volumes.length, 12);
      expect(b.volumes.last.volume, 5100);
      expect(b.serieSemaines, 2);
      // Deux records du développé couché dans le mois : un seul exercice, sa meilleure série.
      expect(b.nbRecords, 1);
      expect(b.records.single.exerciseId, 'dc');
      expect(b.records.single.serie.poids, 80);
      expect(b.favoris.map((f) => (f.exerciseId, f.series)).toList(), [('dc', 5), ('tirage', 2)]);
    });

    test('toile : le mois contre le mois d\'avant', () {
      expect(b.toile.length, 9);
      final pecs = b.toile.firstWhere((a) => a.muscle == Muscle.pectoraux);
      expect(pecs.mois, 1.0);
      expect(pecs.avant, closeTo(0.4, 1e-9));
      final quadri = b.toile.firstWhere((a) => a.muscle == Muscle.quadriceps);
      expect(quadri.mois, 0);
      expect(quadri.avant, closeTo(0.2, 1e-9));
      // Épaules : le faisceau le plus travaillé (ici l'antérieur, en secondaire).
      final epaules = b.toile.firstWhere((a) => a.muscle == Muscle.deltoidesLateraux);
      expect(epaules.mois, closeTo(0.5, 1e-9));
    });

    test('un mois vide ne casse rien', () {
      final v = BilanMois.calculer(DateTime(2026, 3), sessions, _exo, now: now);
      expect(v.vide, isTrue);
      expect(v.volume, 0);
      expect(v.ecartVolume, isNull);
      expect(v.ecartSeances, isNull);
      expect(v.toile.every((a) => a.mois == 0 && a.avant == 0), isTrue);
      expect(v.records, isEmpty);
    });
  });

  group('récupération', () {
    final etats = Recup.etats(sessions, _exo, now: now);

    test('dix-huit groupes, pourcentages et seuil', () {
      expect(etats.length, 18);
      expect(etats.containsKey(Muscle.cou), isFalse);
      // Squat de la veille : 2 séries, 17 h plus tôt, récupération en 72 h.
      expect(etats[Muscle.quadriceps]!.pourcentage, 75);
      expect(etats[Muscle.quadriceps]!.pret, isFalse);
      expect(etats[Muscle.fessiers]!.pourcentage, 87);
      // Développé couché de lundi : récupéré.
      expect(etats[Muscle.pectoraux]!.pourcentage, 100);
      expect(etats[Muscle.pectoraux]!.pret, isTrue);
      expect(Recup.global(etats), 98);
    });

    test('du moins au plus récupéré, et les six vignettes', () {
      final t = Recup.tries(etats);
      expect(t.first.muscle, Muscle.quadriceps);
      expect(t[1].muscle, Muscle.fessiers);
      expect(t.last.pourcentage, 100);
      final v = Recup.vignettes(etats);
      expect(v.map((x) => x.$1).toList(), ['Pectoraux', 'Épaules', 'Triceps', 'Grand dorsal', 'Biceps', 'Quadriceps']);
      expect(v.last.$2.pourcentage, 75);
    });

    test('conseil du jour : le groupe le mieux récupéré, le plus anciennement travaillé', () {
      final c = Recup.conseil(etats, sessions, _exo);
      expect(c.groupe, MuscleRegion.epaules);
      expect(Recup.phrase(c), 'Épaules récupérées à 100 %');
      expect(Recup.pretPour(c.groupe), 'Prêt pour les épaules');
      // Sans aucune séance : tout est prêt.
      final vide = Recup.etats(const [], _exo, now: now);
      expect(Recup.global(vide), 100);
      expect(Recup.conseil(vide, const [], _exo).pourcentage, 100);
    });

    test('chaque muscle suivi a un cadrage qui le montre', () {
      expect(Recup.cadrage(Muscle.pectoraux).$1.label, 'face');
      expect(Recup.cadrage(Muscle.ischios).$1.label, 'dos');
      expect(Recup.label(Muscle.deltoidesPosterieurs), 'Épaules arrière');
    });
  });

  test('chemins exposés aux autres modules', () {
    expect(ProgresPaths.bilan(DateTime(2026, 9)), '/progres/bilan?mois=2026-09');
    expect(ProgresPaths.bilan(), '/progres/bilan');
    expect(ProgresPaths.calendrier(DateTime(2026, 10, 2)), '/progres/calendrier?jour=2026-10-02');
    expect(Calculs.lireMois('2026-09'), DateTime(2026, 9));
    expect(Calculs.lireMois('2026-13'), isNull);
    expect(Calculs.lireMois(null), isNull);
  });
}
