import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/inscription/data/draft.dart';
import 'package:aesthetic/features/inscription/data/program_generator.dart';
import 'package:aesthetic/features/inscription/inscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profil({
  Objectif objectif = Objectif.prendreDuMuscle,
  Niveau niveau = Niveau.intermediaire,
  int jours = 4,
  int duree = 60,
  Set<Materiel> materiel = const {Materiel.salleComplete},
}) =>
    UserProfile(
      id: 'moi',
      prenom: 'Test',
      objectif: objectif,
      niveau: niveau,
      joursParSemaine: jours,
      dureeSeanceMin: duree,
      materiel: materiel,
      poidsKg: 77,
      tailleCm: 181,
      creeLe: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le brouillon survit à un aller-retour JSON', () {
    final d = Draft(
      prenom: 'Tristan',
      sexe: Sexe.homme,
      naissance: DateTime(1999, 5, 12),
      tailleCm: 181,
      uniteTaille: UniteTaille.ftIn,
      poidsKg: 77.4,
      poidsCibleKg: 80,
      unitePoids: UnitePoids.lb,
      objectif: Objectif.force,
      niveau: Niveau.avance,
      activite: NiveauActivite.actif,
      jours: {1, 3, 5, 6},
      dureeSeanceMin: 75,
      materielPreset: MaterielPreset.maison,
      materiel: {Materiel.halteres, Materiel.barreTraction},
      muscles: {Muscle.grandDorsal, Muscle.deltoidesLateraux},
      nutritionAuto: false,
      objectifsNutrition: const NutritionGoals(kcal: 2900, proteinesG: 170),
      rappels: true,
      heureRappel: '07:30',
      etape: 9,
    );
    final r = Draft.fromJson(d.toJson());
    expect(r.toJson(), d.toJson());
    final p = r.toProfile();
    expect(p.joursParSemaine, 4);
    expect(p.objectifsNutrition?.kcal, 2900);
    expect(r.toExtras().musclesPrioritaires, {Muscle.grandDorsal, Muscle.deltoidesLateraux});
  });

  test('les étapes obligatoires bloquent tant qu\'elles sont vides', () async {
    final c = InscriptionController(Store.memory());
    await c.load();
    expect(c.valide(Etape.prenom), isFalse);
    expect(c.valide(Etape.muscles), isTrue);
    c.set((d) => d.prenom = 'Léa');
    expect(c.valide(Etape.prenom), isTrue);
    expect(c.premiereIncomplete, Etape.sexe);
    c.set((d) => d.naissance = DateTime(DateTime.now().year - 8));
    expect(c.valide(Etape.naissance), isFalse);
    await c.sauver();
    final c2 = InscriptionController(c.store);
    await c2.load();
    expect(c2.draft.prenom, 'Léa');
    c.dispose();
    c2.dispose();
  });

  group('programme conseillé', () {
    late ExerciseRepo repo;
    setUpAll(() async {
      final data = AppData(Store.memory());
      await data.loadAll();
      repo = data.exercises;
    });

    for (final jours in [1, 2, 3, 4, 5, 6]) {
      for (final mat in [
        {Materiel.salleComplete},
        MaterielPreset.halteres.materiel,
        MaterielPreset.maison.materiel,
        {Materiel.poidsDuCorps},
      ]) {
        test('$jours jours, ${mat.map((m) => m.name).join('+')}', () {
          final p = _profil(jours: jours, materiel: mat);
          final gen = ProgramGenerator(repo);
          for (final f in ProgramGenerator.formulesPour(jours)) {
            final pr = gen.generer(p, {}, formule: f);
            expect(pr.seances, isNotEmpty);
            for (final s in pr.seances) {
              expect(s.exercices.length, greaterThanOrEqualTo(3), reason: '${f.name} ${s.nom}');
              final ids = s.exercices.map((e) => e.exerciseId).toList();
              expect(ids.toSet().length, ids.length, reason: 'doublon dans ${s.nom}');
              for (final e in s.exercices) {
                final x = repo.byId(e.exerciseId);
                expect(x, isNotNull, reason: e.exerciseId);
                expect(ProgramGenerator.disponible(x!, mat), isTrue, reason: '${x.id} sans le matériel');
                expect(e.series, isNotEmpty);
              }
            }
          }
        });
      }
    }

    test('les muscles prioritaires sont travaillés et reçoivent une série de plus', () {
      final p = _profil(jours: 3, niveau: Niveau.debutant);
      final gen = ProgramGenerator(repo);
      final prio = {Muscle.mollets, Muscle.avantBras};
      final pr = gen.generer(p, prio);
      final muscles = {for (final s in pr.seances) ...s.muscles(repo)};
      expect(muscles.containsAll(prio), isTrue);
      expect(pr.raisons.any((r) => r.contains('mollets')), isTrue);
    });

    test('la force donne des séries courtes et des repos longs', () {
      final pr = ProgramGenerator(repo).generer(_profil(objectif: Objectif.force), {});
      final premier = pr.seances.first.exercices.first;
      expect(premier.series.first.reps, 3);
      expect(premier.reposSec, 180);
    });
  });
}
