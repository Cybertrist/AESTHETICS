import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/accueil/entrainer_page.dart';
import 'package:aesthetic/features/entrainer/accueil/volet_programmes.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_detail_page.dart' show FicheTab;
import 'package:aesthetic/features/entrainer/commun/palette.dart';
import 'package:aesthetic/features/entrainer/routines/logic/idees.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_plan.dart';
import 'package:aesthetic/features/entrainer/routines/logic/program_templates.dart';
import 'package:aesthetic/features/entrainer/routines/logic/suggestion.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:aesthetic/features/entrainer/routines/pages/programme_page.dart';
import 'package:aesthetic/features/entrainer/routines/widgets/ligne_routine.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _seance(String routine, DateTime jour) => WorkoutSession(
      id: '$routine-${jour.toIso8601String()}',
      nom: routine,
      routineId: routine,
      debut: jour,
      fin: jour.add(const Duration(hours: 1)),
    );

/// Séances d'une routine faites [semaines] semaines avant [jour], à 18 h.
List<WorkoutSession> _habitude(String routine, DateTime jour, List<int> semaines) =>
    [for (final k in semaines) _seance(routine, DateTime(jour.year, jour.month, jour.day - 7 * k, 18))];

void main() {
  // Vendredi 2 octobre 2026, le jour de la maquette.
  final vendredi = DateTime(2026, 10, 2, 9, 30);

  group('rang dans le cycle du programme', () {
    const cycle = ['haut', 'bas', 'haut2', 'bas2'];
    final debut = DateTime(2026, 9, 28);

    test('rien de fait : la première routine', () {
      expect(rangDansCycle(cycle, const []), 0);
      expect(rangDansCycle(const [], [_seance('haut', vendredi)]), 0);
    });

    test('une séance faite puis supprimée ne décale pas le cycle', () {
      final faite = _seance('haut', DateTime(2026, 10, 4, 18));
      expect(rangDansCycle(cycle, [faite], depuis: debut), 1);
      expect(rangDansCycle(cycle, const [], depuis: debut), 0);
    });

    test('le cycle suit les séances, et repart au début après la dernière', () {
      final seances = [
        _seance('haut', DateTime(2026, 9, 28, 18)),
        _seance('bas', DateTime(2026, 9, 29, 18)),
        _seance('haut2', DateTime(2026, 10, 1, 18)),
      ];
      expect(rangDansCycle(cycle, seances, depuis: debut), 3);
      expect(rangDansCycle(cycle, [...seances, _seance('bas2', DateTime(2026, 10, 2, 18))], depuis: debut), 0);
    });

    test('une routine deux fois dans le cycle est suivie à son tour', () {
      const double = ['haut', 'bas', 'haut', 'bas'];
      final seances = [
        _seance('haut', DateTime(2026, 9, 28, 18)),
        _seance('bas', DateTime(2026, 9, 29, 18)),
        _seance('haut', DateTime(2026, 10, 1, 18)),
      ];
      expect(rangDansCycle(double, seances, depuis: debut), 3);
    });

    test('les séances d’avant le programme, en cours ou hors cycle ne comptent pas', () {
      final seances = [
        _seance('haut', DateTime(2026, 9, 20, 18)),
        _seance('autre', DateTime(2026, 9, 29, 18)),
        WorkoutSession(id: 'x', nom: 'haut', routineId: 'haut', debut: DateTime(2026, 9, 30, 18)),
      ];
      expect(rangDansCycle(cycle, seances, depuis: debut), 0);
    });
  });

  group('suggestion de routine : six fois sur les huit dernières semaines', () {
    test('six vendredis sur huit : proposée, avec la raison écrite', () {
      final s = suggererRoutine(maintenant: vendredi, seances: _habitude('epaules', vendredi, [1, 2, 4, 5, 6, 8]))!;
      expect(s.routineId, 'epaules');
      expect(s.fois, 6);
      expect(s.sur, 8);
      expect(s.jour, DateTime.friday);
      expect(s.derniere, DateTime(2026, 9, 25, 18));
      expect(titreSuggestion(s.jour), 'Suggéré pour ce vendredi');
      expect(raisonSuggestion(s), 'Tu as fait cette séance 6 des 8 derniers vendredis. Dernière fois : le 25 septembre.');
    });

    test('cinq sur huit : rien, l\'appli n\'est pas sûre', () {
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('epaules', vendredi, [1, 2, 4, 5, 6])), isNull);
    });

    test('huit sur huit, et les semaines plus anciennes ne comptent pas', () {
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('epaules', vendredi, [1, 2, 3, 4, 5, 6, 7, 8]))!.fois, 8);
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('epaules', vendredi, [1, 2, 3, 9, 10, 11, 12])), isNull);
    });

    test('un autre jour de la semaine ne compte pas', () {
      final jeudis = [for (final k in [1, 2, 3, 4, 5, 6, 7, 8]) _seance('epaules', DateTime(2026, 10, 1 - 7 * k, 18))];
      expect(suggererRoutine(maintenant: vendredi, seances: jeudis), isNull);
      final jeudi = DateTime(2026, 10, 8, 10);
      expect(suggererRoutine(maintenant: jeudi, seances: jeudis)?.fois, 7, reason: 'le 1er octobre et six jeudis avant, dans les huit semaines');
    });

    test('deux séances le même jour ne comptent qu\'une fois', () {
      final seances = [
        ..._habitude('epaules', vendredi, [1, 2, 3, 4, 5]),
        _seance('epaules', DateTime(2026, 9, 25, 7)),
        _seance('epaules', DateTime(2026, 9, 18, 7)),
      ];
      expect(suggererRoutine(maintenant: vendredi, seances: seances), isNull);
    });

    test('déjà faite aujourd\'hui, supprimée ou séance sans routine : rien', () {
      final habitude = _habitude('epaules', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...habitude, _seance('epaules', DateTime(2026, 10, 2, 7))]), isNull);
      expect(suggererRoutine(maintenant: vendredi, seances: habitude, routinesConnues: {'jambes'}), isNull);
      expect(suggererRoutine(maintenant: vendredi, seances: habitude, routinesConnues: {'epaules'}), isNotNull);
      final libres = [
        for (final k in [1, 2, 3, 4, 5, 6, 7, 8])
          WorkoutSession(id: 'l$k', nom: 'Libre', debut: DateTime(2026, 10, 2 - 7 * k, 18), fin: DateTime(2026, 10, 2 - 7 * k, 19)),
      ];
      expect(suggererRoutine(maintenant: vendredi, seances: libres), isNull);
      expect(suggererRoutine(maintenant: vendredi, seances: const []), isNull);
    });

    test('deux routines sûres : la plus régulière, puis la plus récente', () {
      final a = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6, 7]);
      final b = _habitude('b', vendredi, [2, 3, 4, 5, 6, 7]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...b, ...a])!.routineId, 'a');
      final c = [for (final k in [1, 2, 3, 4, 5, 6, 7]) _seance('c', DateTime(2026, 10, 2 - 7 * k, 20))];
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...c])!.routineId, 'c', reason: 'à égalité, la dernière faite');
    });

    test('la dernière fois compte tous les jours, pas seulement ce jour-là', () {
      final seances = [..._habitude('epaules', vendredi, [1, 2, 3, 4, 5, 6]), _seance('epaules', DateTime(2026, 9, 29, 12))];
      final s = suggererRoutine(maintenant: vendredi, seances: seances)!;
      expect(s.derniere, DateTime(2026, 9, 29, 12));
      expect(raisonSuggestion(s), endsWith('Dernière fois : le 29 septembre.'));
    });

    test('seuil et fenêtre réglables', () {
      final seances = _habitude('epaules', vendredi, [1, 2, 3]);
      expect(suggererRoutine(maintenant: vendredi, seances: seances, semaines: 4, seuil: 3)!.sur, 4);
    });
  });

  test('dernière fois, en clair', () {
    final n = DateTime(2026, 10, 2, 9);
    expect(derniereFois(DateTime(2026, 10, 2, 7), maintenant: n), 'Aujourd\'hui');
    expect(derniereFois(DateTime(2026, 10, 1, 23), maintenant: n), 'Hier');
    expect(derniereFois(DateTime(2026, 9, 30, 8), maintenant: n), 'Avant-hier');
    expect(derniereFois(DateTime(2026, 9, 29, 20), maintenant: n), 'Il y a 3 jours');
    expect(derniereFois(DateTime(2026, 9, 16), maintenant: n), '16 septembre');
    expect(derniereFois(DateTime(2026, 9, 1), maintenant: n), '1er septembre');
    expect(derniereFois(DateTime(2025, 12, 24), maintenant: n), '24 décembre 2025');
  });

  group('vignettes et favoris des routines', () {
    test('carte de jour par défaut selon le rang, puis le choix', () {
      expect([for (var i = 0; i < 9; i++) jourDeVignette(null, i)], [1, 2, 3, 4, 5, 6, 7, 1, 2]);
      expect(jourDeVignette(const VignetteRoutine(jour: 6), 0), 6);
      expect(PaletteEntrainer.jours, hasLength(7));
      expect(joursAbreges, ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']);
    });

    test('gardés dans le store et relus', () async {
      final store = Store.memory();
      final prefs = RoutinePrefs.of(store);
      await prefs.load();
      expect(prefs.favoris, isEmpty);
      await prefs.basculerFavori('r1');
      await prefs.basculerFavori('r2');
      await prefs.basculerFavori('r2');
      await prefs.choisirJour('r1', 5);
      await prefs.choisirPhoto('r3', '/photos/a.jpg');
      expect(prefs.estFavori('r1'), isTrue);
      expect(prefs.estFavori('r2'), isFalse);
      expect(await store.read(RoutinePrefs.fichierFavoris), ['r1']);
      final relu = (await store.readList(RoutinePrefs.fichierVignettes)).map(VignetteRoutine.fromJson).toList();
      expect(relu.first!.jour, 5);
      expect(relu.last!.photo, '/photos/a.jpg');
      await prefs.copier('r1', 'r1-copie');
      expect(prefs.vignetteDe('r1-copie')!.jour, 5);
      await prefs.oublier('r1');
      expect(prefs.vignetteDe('r1'), isNull);
      expect(prefs.favoris, isEmpty);
      // Retirer la photo d'une routine : elle reprend sa carte de jour, le
      // fichier ne la mentionne plus.
      // « Aucune image » : ni photo ni jour, et le choix est relu tel quel.
      await prefs.choisirSansImage('r4');
      expect(prefs.vignetteDe('r4')!.sans, isTrue);
      final sans = (await store.readList(RoutinePrefs.fichierVignettes)).firstWhere((j) => j['id'] == 'r4');
      expect(VignetteRoutine.fromJson(sans)!.sans, isTrue);
      await prefs.retirerVignette('r3');
      expect(prefs.vignetteDe('r3'), isNull);
      expect((await store.readList(RoutinePrefs.fichierVignettes)).any((j) => j['id'] == 'r3'), isFalse);
    });

    test('« Une autre » écarte la suggestion pour la journée seulement', () async {
      final prefs = RoutinePrefs.of(Store.memory());
      expect(prefs.suggestionEcartee(DateTime(2026, 10, 2)), isFalse);
      await prefs.ecarterSuggestion(DateTime(2026, 10, 2, 9));
      expect(prefs.suggestionEcartee(DateTime(2026, 10, 2, 22)), isTrue);
      expect(prefs.suggestionEcartee(DateTime(2026, 10, 9)), isFalse);
    });

    test('lecture tolérante', () {
      expect(VignetteRoutine.fromJson({'id': 'x', 'jour': 9}), isNull);
      expect(VignetteRoutine.fromJson({'id': 'x'}), isNull);
    });
  });

  group('programmes', () {
    Program p(String id, List<String> routines, {bool actif = false, int mois = 1}) =>
        Program(id: id, nom: id, routineIds: routines, actif: actif, creeLe: DateTime(2026, mois));

    test('sigle et couverture', () {
      expect(sigleProgramme('DT COACH Tristan V3'), 'V3');
      expect(sigleProgramme('DTCOACH Tristan V2'), 'V2');
      expect(sigleProgramme('Bloc 4'), 'V4');
      expect(sigleProgramme('Push Pull Legs, 12 semaines'), 'PPL');
      expect(sigleProgramme('Full body 3 jours'), 'FB');
      expect(sigleProgramme('Haut/Bas 4 jours'), 'HB', reason: 'le rythme ne fait pas partie du sigle');
      expect(couvertureProgramme('Haut/Bas 4 jours'), (haut: 'HAUT/BAS', gros: 'HB'));
      expect(couvertureProgramme('Full body 3 jours'), (haut: 'FULL BODY', gros: 'FB'));
      expect(sigleProgramme('Force'), 'FO');
      expect(sigleProgramme(''), '?');
      expect(couvertureProgramme('DT COACH Tristan V3'), (haut: 'DT COACH', gros: '3'));
      expect(couvertureProgramme('Push Pull Legs, 12 semaines'), (haut: 'PUSH PULL', gros: 'PPL'));
    });

    test('ordre de la bibliothèque : par nom, la dernière version en tête', () {
      Program n(String nom, {bool actif = false}) => Program(id: nom, nom: nom, actif: actif, creeLe: DateTime(2026));
      final tries = programmesTries([n('MARCHES'), n('DT COACH V3', actif: true), n('dt coach V10'), n('DT COACH V1'), n('Épaules'), n('DT COACH V2')]);
      // Le programme en cours ne passe plus devant : seul le nom compte.
      // Dans une même famille, la dernière version en tête.
      expect(tries.map((x) => x.nom), ['dt coach V10', 'DT COACH V3', 'DT COACH V2', 'DT COACH V1', 'Épaules', 'MARCHES']);
    });

    test('déplacer une routine dans un autre programme', () {
      final liste = [p('a', ['r1', 'r2']), p('b', ['r3']), p('c', ['r1'])];
      final change = deplacerRoutine(liste, 'r1', 'b');
      expect({for (final x in change) x.id: x.routineIds}, {
        'a': ['r2'],
        'b': ['r3', 'r1'],
        'c': <String>[],
      });
      expect(deplacerRoutine(liste, 'r3', 'b'), isEmpty, reason: 'déjà dans ce programme');
    });

    test('routines d\'un programme : sans doublon, sans routine supprimée', () async {
      final repo = RoutineRepo(Store.memory());
      await repo.load();
      await repo.saveAll([Routine(id: 'r1', nom: 'A', creeLe: DateTime(2026)), Routine(id: 'r2', nom: 'B', creeLe: DateTime(2026))]);
      final prog = p('x', ['r1', 'r2', 'r1', 'disparue']);
      expect(routinesDuProgramme(prog, repo).map((r) => r.id), ['r1', 'r2']);
      expect(nbRoutines(prog, repo), 2);
    });
  });

  group('idées de programmes', () {
    test('chaque modèle a sa couverture, et inversement', () {
      expect(ideesProgrammes.map((i) => i.modeleId).toSet(), modelesProgrammes.map((m) => m.id).toSet());
      for (final i in ideesProgrammes) {
        expect(i.auPersonnage || i.poses.isNotEmpty, isTrue, reason: i.modeleId);
        expect(ideeParModele(i.modeleId), same(i));
      }
      expect(ideeParModele(null), isNull);
    });

    test('les classiques : toujours les trois mêmes', () {
      final c = ideesClassiques();
      expect(c.map((i) => i.idee.gros), ['Full body', 'PPL', 'Haut / Bas']);
      expect(c.first.detail, '3 jours par semaine · Intermédiaire');
      expect(c[1].detail, '6 jours · Avancé');
    });

    test('recommandé pour toi : le rythme du programme en cours d\'abord', () {
      final profil = UserProfile(id: 'u', prenom: 'T', creeLe: DateTime(2026), joursParSemaine: 3, niveau: Niveau.intermediaire);
      final actif = Program(id: 'p', nom: 'P', joursParSemaine: 5, actif: true, creeLe: DateTime(2026));
      final r = ideesRecommandees(profil: profil, actif: actif);
      expect(r.first.idee.modeleId, 'split-5j');
      expect(r.first.detail, '5 jours · Proche de ton programme actuel');
      expect(r, hasLength(nbRecommandees));
      expect(r.take(3).every((i) => i.idee.modele.joursParSemaine == 5), isTrue);
      expect(r.any((i) => i.idee.classique), isFalse);
    });

    test('sans matériel : la maison passe en tête', () {
      final profil = UserProfile(id: 'u', prenom: 'T', creeLe: DateTime(2026), joursParSemaine: 5, materiel: const {Materiel.poidsDuCorps});
      final r = ideesRecommandees(profil: profil);
      expect(r.first.idee.rayon.sansMateriel, isTrue);
      expect(r.first.detail, contains('Sans matériel'));
      expect(ideesRecommandees().length, nbRecommandees, reason: 'sans profil, la rangée reste pleine');
      for (final ra in Rayon.values) {
        expect(ideesDuRayon(ra), isNotEmpty, reason: ra.label);
      }
    });

    test('recherche', () {
      List<String> q(String s) => [for (final i in ideesProgrammes) if (ideeCorrespond(i, s)) i.modeleId];
      expect(q(''), hasLength(ideesProgrammes.length));
      expect(q('maison'), containsAll(['maison-3j', 'maison-5j', 'defi-pompes']));
      expect(q('yoga'), ['yoga-debutant-3j', 'yoga-4j']);
      expect(q('5x5'), ['cinq-par-cinq']);
      expect(q('debutant'), containsAll(['debutant-3j', 'maison-3j', 'cinq-par-cinq']));
      expect(q('zzz'), isEmpty);
    });

    test('ajouter une idée à la bibliothèque, sans toucher au programme en cours', () async {
      final data = AppData(Store.memory());
      await data.loadAll();
      final plans = ProgramPlanRepo.of(data.store);
      Future<Program> ajouter(String id, {required bool suivre}) => creerProgrammeDepuisModele(
            modele: modeleParId(id)!,
            exercices: data.exercises,
            routines: data.routines,
            programmes: data.programs,
            plans: plans,
            activer: suivre,
          );
      final split = await ajouter('split-5j', suivre: true);
      expect(split.actif, isTrue);
      expect(split.routineIds, hasLength(5));
      expect(data.routines.routines.map((r) => r.nom), ['Pectoraux', 'Dos', 'Épaules', 'Jambes', 'Bras']);
      final maison = await ajouter('maison-3j', suivre: false);
      expect(maison.actif, isFalse);
      expect(data.programs.active!.id, split.id);
      expect(plans.planFor(maison.id).modeleId, 'maison-3j');
      // Sans matériel : que du poids du corps.
      for (final id in maison.routineIds) {
        for (final e in data.routines.byId(id)!.exercices) {
          expect(data.exercises.byId(e.exerciseId)!.equipement, 'poids du corps', reason: e.exerciseId);
        }
      }
      expect(data.programs.programs, hasLength(2));
    });
  });

  test('adresses : volets et onglets de la fiche', () {
    expect(VoletEntrainer.parse(null), VoletEntrainer.programmes);
    expect(VoletEntrainer.parse('routines'), VoletEntrainer.routines);
    expect(VoletEntrainer.parse('seances'), VoletEntrainer.routines, reason: 'ancien nom');
    expect(VoletEntrainer.parse('exercices'), VoletEntrainer.exercices);
    expect(FicheTab.values.map((t) => t.label), ['À propos', 'Historique', 'Progrès', 'Records']);
    expect(FicheTab.parse('records'), FicheTab.records);
    expect(FicheTab.parse('graphiques'), FicheTab.progres, reason: 'ancien nom');
    expect(FicheTab.parse('muscles'), FicheTab.apropos);
  });
}
