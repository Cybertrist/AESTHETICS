import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/exercise_notes.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/logic/fusion.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/widgets/exercise_media.dart' show mediaNetworkEnabled;
import 'package:aesthetic/features/import/data/import_journal.dart';
import 'package:aesthetic/features/import/logic/exercise_matcher.dart' show cleNom;
import 'package:aesthetic/features/progres/logic/objectifs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'outils.dart';

/// Fusion d'un exercice perso avec l'exercice du catalogue qui l'a rejoint :
/// rien de son historique ne se perd, il disparaît ensuite.
const _cible = 'kettlebell-curl';

WorkoutSet _s(String id, double kg, int reps) => WorkoutSet(id: id, poids: kg, reps: reps, fait: true);

WorkoutSession _seance(String id, DateTime d, List<SessionExercise> exercices) =>
    WorkoutSession(id: id, nom: 'Bras', debut: d, fin: d.add(const Duration(hours: 1)), exercices: exercices);

RoutineExercise _re(String id, String exerciseId) =>
    RoutineExercise(id: id, exerciseId: exerciseId, series: const [PlannedSet(reps: 10), PlannedSet(reps: 10)]);

/// Un perso « Curl à la kettlebell » avec deux séances, une routine, un
/// programme, un favori, une note, un objectif et une correspondance d'import.
Future<(AppData, Exercise)> _donnees() async {
  final data = await donneesVides();
  final perso = await data.exercises.addCustom(const Exercise(
    id: '',
    nom: 'Curl à la kettlebell',
    musclesPrincipaux: [Muscle.biceps],
    equipement: 'kettlebell',
    notes: 'Prise neutre, coude collé.',
  ));
  await data.sessions.addAll([
    _seance('s1', DateTime(2026, 9, 1), [
      SessionExercise(id: 'a', exerciseId: perso.id, series: [_s('a1', 16, 10), _s('a2', 16, 9)]),
    ]),
    // Les deux exercices dans la même séance : toutes les séries restent.
    _seance('s2', DateTime(2026, 10, 1), [
      SessionExercise(id: 'b', exerciseId: _cible, series: [_s('b1', 12, 12)]),
      SessionExercise(id: 'c', exerciseId: 'squat', series: [_s('c1', 100, 5)]),
      SessionExercise(id: 'd', exerciseId: perso.id, series: [_s('d1', 20, 8), _s('d2', 20, 7), _s('d3', 18, 8)]),
    ]),
    _seance('s3', DateTime(2026, 10, 5), [
      SessionExercise(id: 'e', exerciseId: 'squat', series: [_s('e1', 100, 5)]),
    ]),
  ]);
  await data.routines.saveAll([
    Routine(id: 'r1', nom: 'BRAS', creeLe: DateTime(2026), exercices: [_re('x1', perso.id), _re('x2', 'curl-halteres'), _re('x3', _cible)]),
    Routine(id: 'r2', nom: 'JAMBES', creeLe: DateTime(2026), exercices: [_re('y1', 'squat')]),
  ]);
  await data.programs.save(Program(id: 'p1', nom: 'Bras 8 semaines', routineIds: const ['r1', 'r2'], actif: true, creeLe: DateTime(2026)));
  await data.exercises.toggleFavori(perso.id);
  final notes = ExerciseNotes.of(data.store);
  await notes.pret;
  await notes.set(perso.id, 'Siège au cran 3.');
  final objectifs = await ObjectifsRepo.ensure(data.store);
  await objectifs.ajouter(ObjectifPerso(id: 'o1', type: TypeObjectif.charge, cible: 24, depart: 16, exerciseId: perso.id, creeLe: DateTime(2026, 9)));
  await ImportJournal.ecrireCorrespondances(data.store, {cleNom('KB curl'): perso.id, cleNom('Squat barre'): 'squat'});
  return (data, perso);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaNetworkEnabled = false;
  setUpAll(() => initializeDateFormatting('fr_FR'));
  setUp(ObjectifsRepo.reset);

  test('la fusion déplace séances, routines, programme, favori, note, objectif, import, puis supprime le perso', () async {
    final (data, perso) = await _donnees();
    final avant = data.sessions.bestsFor(perso.id);

    final bilan = await FusionExercices.bilanDe(data, perso.id);
    expect(bilan.resume, '2 séances, 1 routine, 1 objectif');
    expect(bilan.favori, isTrue);
    expect(bilan.note, isTrue);

    await FusionExercices.appliquer(data, de: perso.id, vers: _cible);

    // Le perso a disparu, rien ne le cite plus.
    expect(data.exercises.byId(perso.id), isNull);
    expect(data.exercises.perso, isEmpty);
    expect(data.sessions.historyFor(perso.id), isEmpty);
    expect(data.routines.routines.expand((r) => r.exercices).map((e) => e.exerciseId), isNot(contains(perso.id)));

    // Séances : les deux du perso, plus celle du catalogue (mêlées, c'est voulu).
    expect(data.sessions.historyFor(_cible).map((h) => h.session.id), ['s2', 's2', 's1']);
    expect(data.sessions.byId('s3')!.exercices.single.exerciseId, 'squat');
    final apres = data.sessions.bestsFor(_cible);
    // Records recalculés depuis les séances : celui du perso (20 kg) passe au catalogue.
    expect(avant.poidsMax!.valeur, 20);
    expect(apres.poidsMax!.valeur, 20);
    expect(apres.poidsMax!.sessionId, 's2');

    // Routine : l'entrée prend la place du perso, la routine garde ses trois lignes.
    final r1 = data.routines.byId('r1')!;
    expect(r1.exercices.map((e) => e.id), ['x1', 'x2', 'x3']);
    expect(r1.exercices.map((e) => e.exerciseId), [_cible, 'curl-halteres', _cible]);
    expect(r1.exercices.first.series, hasLength(2));

    // Programme : il cite ses routines, qui portent maintenant l'exercice du catalogue.
    final prog = data.programs.byId('p1')!;
    expect(prog.routineIds, ['r1', 'r2']);
    expect(data.routines.byId(prog.prochaineRoutineId!)!.exercices.first.exerciseId, _cible);

    // Favori, note (avec le texte de la fiche perso), objectif, mémoire de l'import.
    expect(data.exercises.isFavori(_cible), isTrue);
    expect(data.exercises.favoris, isNot(contains(perso.id)));
    final notes = ExerciseNotes.of(data.store);
    expect(notes.noteOf(perso.id), isNull);
    expect(notes.noteOf(_cible), 'Siège au cran 3.\n\nPrise neutre, coude collé.');
    expect(ObjectifsRepo.maybeInstance!.liste.single.exerciseId, _cible);
    final memoire = await ImportJournal.lireCorrespondances(data.store);
    expect(memoire[cleNom('KB curl')], _cible);
    expect(memoire[cleNom('Squat barre')], 'squat');

    // Tout est écrit : un rechargement retrouve le même état.
    final relu = AppData(data.store);
    await Future.wait([relu.exercises.load(), relu.sessions.load(), relu.routines.load()]);
    expect(relu.exercises.byId(perso.id), isNull);
    expect(relu.sessions.historyFor(_cible), hasLength(3));
    expect(relu.routines.byId('r1')!.exercices.first.exerciseId, _cible);
  });

  test('une séance qui contenait les deux exercices garde toutes ses séries, dans l\'ordre', () async {
    final (data, perso) = await _donnees();
    final avant = data.sessions.byId('s2')!;
    final series = avant.exercices.fold(0, (n, e) => n + e.series.length);

    await FusionExercices.appliquer(data, de: perso.id, vers: _cible);

    final s2 = data.sessions.byId('s2')!;
    expect(s2.exercices.map((e) => e.id), ['b', 'c', 'd']);
    expect(s2.exercices.map((e) => e.exerciseId), [_cible, 'squat', _cible]);
    expect(s2.exercices.fold(0, (n, e) => n + e.series.length), series);
    expect(s2.exercices.last.series.map((s) => s.id), ['d1', 'd2', 'd3']);
    expect(s2.volume, avant.volume);
  });

  test('la séance en cours suit aussi', () async {
    final (data, perso) = await _donnees();
    await data.sessions.startEmpty();
    await data.sessions.addExerciseToActive(perso.id);
    expect((await FusionExercices.bilanDe(data, perso.id)).seanceEnCours, isTrue);

    await FusionExercices.appliquer(data, de: perso.id, vers: _cible);

    expect(data.sessions.active!.exercices.single.exerciseId, _cible);
    final relu = SessionRepo(data.store);
    await relu.load();
    expect(relu.active!.exercices.single.exerciseId, _cible);
  });

  test('fusion refusée : cible inexistante, perso vers perso, catalogue vers catalogue, soi-même', () async {
    final (data, perso) = await _donnees();
    final autre = await data.exercises.addCustom(const Exercise(id: '', nom: 'Autre perso'));
    Future<void> essai(String de, String vers) =>
        expectLater(FusionExercices.appliquer(data, de: de, vers: vers), throwsA(isA<FusionImpossible>()));

    await essai(perso.id, 'exercice-qui-n-existe-pas');
    await essai(perso.id, autre.id);
    await essai('squat', _cible);
    await essai(perso.id, perso.id);
    await essai('perso-inconnu', _cible);

    // Rien n'a bougé.
    expect(data.exercises.byId(perso.id), isNotNull);
    expect(data.sessions.historyFor(perso.id), hasLength(2));
    expect(data.routines.byId('r1')!.exercices.first.exerciseId, perso.id);
    expect(data.exercises.isFavori(perso.id), isTrue);
  });

  group('remplacements sans dépôt', () {
    test('ne rendent que ce qui change', () {
      final s = _seance('s', DateTime(2026), [SessionExercise(id: 'a', exerciseId: 'squat')]);
      expect(FusionExercices.seance(s, 'perso-x', _cible), isNull);
      expect(FusionExercices.seances([s], 'perso-x', _cible), isEmpty);
      expect(FusionExercices.routines([Routine(id: 'r', nom: 'R', creeLe: DateTime(2026), exercices: [_re('a', 'squat')])], 'perso-x', _cible), isEmpty);
    });

    test('notes : celle du catalogue d\'abord, sans doublon', () {
      expect(FusionExercices.notes({'p': 'A', 'c': 'B'}, 'p', 'c'), {'c': 'B\n\nA'});
      expect(FusionExercices.notes({'p': 'A'}, 'p', 'c', notesPerso: 'A'), {'c': 'A'});
      expect(FusionExercices.notes({'z': 'Z'}, 'p', 'c'), {'z': 'Z'});
    });

    test('mémoire de l\'import : le nom qui créait le perso mène au catalogue', () {
      final m = FusionExercices.correspondances({cleNom('Curl à la kettlebell'): '', cleNom('Autre'): ''}, 'p', 'c', nomPerso: 'Curl à la kettlebell');
      expect(m[cleNom('Curl à la kettlebell')], 'c');
      expect(m[cleNom('Autre')], '');
    });

    test('message de confirmation', () {
      const b = BilanFusion(seances: 23, routines: 3);
      expect(b.resume, '23 séances, 3 routines');
      final m = messageFusion(b, perso: 'Curl KB', catalogue: 'Curl kettlebell');
      expect(m, contains('23 séances, 3 routines'));
      expect(m, contains('« Curl KB » disparaîtra'));
      expect(messageFusion(const BilanFusion(), perso: 'Curl KB', catalogue: 'Curl kettlebell'), contains('aucune séance'));
    });
  });

  test('équivalent sûr dans le catalogue, jamais pour une variante ni un nom inconnu', () async {
    final data = await donneesVides();
    final catalogue = data.exercises.catalogue;
    expect(EquivalentsCatalogue.sur(catalogue, const Exercise(id: 'perso-1', nom: 'Curl à la kettlebell', perso: true)), _cible);
    expect(EquivalentsCatalogue.sur(catalogue, const Exercise(id: 'perso-2', nom: 'Squat', perso: true)), 'squat');
    expect(EquivalentsCatalogue.sur(catalogue, const Exercise(id: 'perso-3', nom: 'Squat (perso)', perso: true, source: 'copie:squat')), isNull);
    expect(EquivalentsCatalogue.sur(catalogue, const Exercise(id: 'perso-4', nom: 'Mon truc du mardi', perso: true)), isNull);
    expect(EquivalentsCatalogue.proches(catalogue, const Exercise(id: 'perso-1', nom: 'Curl à la kettlebell', perso: true)).first, _cible);
  });

  testWidgets('fiche d\'un perso : fusion par le menu, puis la fiche du catalogue', (t) async {
    await t.runAsync(chargerPolices);
    final (data, perso) = (await t.runAsync(_donnees))!;
    await lancer(t, data, '/entrainer/exercices/${perso.id}');
    await t.tap(find.bySemanticsLabel('Plus d’actions'));
    await attendre(t, 2);
    await t.tap(find.text('Fusionner avec un exercice du catalogue'));
    await attendre(t, 3);
    // Le sélecteur : catalogue seul, le plus proche en tête.
    expect(find.text('Fusionner avec…'), findsOneWidget);
    expect(find.text('Curl à la kettlebell'), findsNothing);
    expect(find.text('Curl kettlebell'), findsWidgets);
    await t.tap(find.text('Curl kettlebell').first);
    await attendre(t, 2);
    expect(find.text('Fusionner avec « Curl kettlebell » ?'), findsOneWidget);
    expect(find.textContaining('2 séances, 1 routine, 1 objectif'), findsOneWidget);
    expect(find.textContaining('disparaîtra de tes exercices'), findsOneWidget);
    await t.tap(find.text('Fusionner'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await attendre(t, 3);
    expect(data.exercises.byId(perso.id), isNull);
    expect(find.text('Exercice introuvable'), findsNothing);
    expect(find.text('Curl kettlebell'), findsWidgets);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('bibliothèque : la ligne « existe maintenant dans le catalogue » mène à la confirmation', (t) async {
    await t.runAsync(chargerPolices);
    final (data, perso) = (await t.runAsync(_donnees))!;
    await lancer(t, data, '/entrainer/exercices?onglet=perso');
    final ligne = find.textContaining('existe maintenant dans le catalogue', findRichText: true);
    expect(ligne, findsOneWidget);
    await capturer(t, 'bibliotheque', 'suggestion-fusion');
    await t.tap(ligne);
    await attendre(t, 2);
    expect(find.text('Fusionner avec « Curl kettlebell » ?'), findsOneWidget);
    // Annuler ne touche à rien : pas de fusion sans accord.
    await t.tap(find.text('Annuler'));
    await attendre(t, 2);
    expect(data.exercises.byId(perso.id), isNotNull);
    expect(data.sessions.historyFor(perso.id), hasLength(2));
    await t.pump(const Duration(seconds: 5));
  });
}
