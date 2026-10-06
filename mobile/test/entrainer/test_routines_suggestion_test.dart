import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/entrainer/routines/logic/suggestion.dart';
import 'package:aesthetic/features/entrainer/routines/logic/vignettes.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _seance(String? routine, DateTime debut, {bool finie = true}) => WorkoutSession(
      id: '$routine-${debut.microsecondsSinceEpoch}',
      nom: routine ?? 'Libre',
      routineId: routine,
      debut: debut,
      fin: finie ? debut.add(const Duration(hours: 1)) : null,
    );

List<WorkoutSession> _habitude(String routine, DateTime jour, List<int> semaines, {int heure = 18, int minute = 0}) =>
    [for (final k in semaines) _seance(routine, DateTime(jour.year, jour.month, jour.day - 7 * k, heure, minute))];

/// Bords de la règle de suggestion, en plus de `entrainer_logique_test.dart`.
void main() {
  group('suggestion : bords du calendrier', () {
    test('passage à l\'heure d\'hiver (25 octobre 2026) : les huit vendredis restent des vendredis', () {
      final vendredi = DateTime(2026, 10, 30, 8);
      for (final (h, m) in [(0, 5), (2, 30), (23, 55)]) {
        final s = suggererRoutine(maintenant: vendredi, seances: _habitude('a', vendredi, [1, 2, 3, 4, 5, 6], heure: h, minute: m));
        expect(s?.fois, 6, reason: 'séances à $h h $m');
      }
      // Minuit pile et 23 h 59 aujourd'hui : même réponse.
      final habitude = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: DateTime(2026, 10, 30), seances: habitude)?.fois, 6);
      expect(suggererRoutine(maintenant: DateTime(2026, 10, 30, 23, 59, 59), seances: habitude)?.fois, 6);
    });

    test('passage à l\'heure d\'été (29 mars 2026)', () {
      final vendredi = DateTime(2026, 4, 3, 7);
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('a', vendredi, [1, 2, 3, 4, 5, 6], heure: 0, minute: 1))?.fois, 6);
      // Le dimanche du changement lui-même, à 3 h (2 h n'existe pas).
      final dimanche = DateTime(2026, 3, 29, 3);
      expect(suggererRoutine(maintenant: dimanche, seances: _habitude('a', dimanche, [1, 2, 3, 4, 5, 6, 7, 8], heure: 2, minute: 30))?.fois, 8);
    });

    test('à cheval sur deux années et sur un 29 février', () {
      final jeudi = DateTime(2027, 1, 7, 12);
      final s = suggererRoutine(maintenant: jeudi, seances: _habitude('a', jeudi, [1, 2, 3, 4, 5, 6]))!;
      expect(s.jour, DateTime.thursday);
      expect(s.derniere, DateTime(2026, 12, 31, 18));
      expect(raisonSuggestion(s), 'Tu as fait cette séance 6 des 8 derniers jeudis. Dernière fois : le 31 décembre.');
      final bissextile = DateTime(2028, 3, 7, 12);
      expect(suggererRoutine(maintenant: bissextile, seances: _habitude('a', bissextile, [1, 2, 3, 4, 5, 6]))?.fois, 6);
    });

    test('le premier jour de la semaine (lundi ou dimanche) ne change rien : seul le jour compte', () {
      final dimanche = DateTime(2026, 10, 4, 10);
      expect(suggererRoutine(maintenant: dimanche, seances: _habitude('a', dimanche, [1, 2, 3, 4, 5, 6]))?.jour, DateTime.sunday);
      final lundi = DateTime(2026, 10, 5, 10);
      expect(suggererRoutine(maintenant: lundi, seances: _habitude('a', lundi, [1, 2, 3, 4, 5, 6]))?.jour, DateTime.monday);
      expect(suggererRoutine(maintenant: lundi, seances: _habitude('a', dimanche, [1, 2, 3, 4, 5, 6])), isNull, reason: 'la veille ne compte pas');
    });
  });

  group('suggestion : bords des données', () {
    final vendredi = DateTime(2026, 10, 2, 9, 30);

    test('historique trop court : cinq semaines parfaites ne suffisent pas, six oui', () {
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('a', vendredi, [1, 2, 3, 4, 5])), isNull);
      expect(suggererRoutine(maintenant: vendredi, seances: _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]))?.fois, 6);
    });

    test('séance en cours aujourd\'hui : déjà commencée, rien n\'est proposé', () {
      final habitude = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...habitude, _seance('a', DateTime(2026, 10, 2, 9), finie: false)]), isNull);
      // Une séance en cours restée ouverte depuis la veille ne bloque pas.
      expect(suggererRoutine(maintenant: vendredi, seances: [...habitude, _seance('a', DateTime(2026, 10, 1, 22), finie: false)])?.routineId, 'a');
    });

    test('une autre routine faite aujourd\'hui ne bloque pas celle du jour', () {
      final habitude = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...habitude, _seance('b', DateTime(2026, 10, 2, 7))])?.routineId, 'a');
    });

    test('deux routines à égalité parfaite : choix stable, quel que soit l\'ordre des séances', () {
      final a = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]);
      final b = _habitude('b', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...b])!.routineId, 'a');
      expect(suggererRoutine(maintenant: vendredi, seances: [...b, ...a])!.routineId, 'a');
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...b].reversed)!.routineId, 'a');
    });

    test('la routine la plus régulière a été supprimée : la suivante est proposée', () {
      final a = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6, 7, 8]);
      final b = _habitude('b', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...b], routinesConnues: {'b'})!.routineId, 'b');
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...b], routinesConnues: const {}), isNull);
    });

    test('la première déjà faite aujourd\'hui : la seconde est proposée', () {
      final a = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6, 7, 8]);
      final b = _habitude('b', vendredi, [1, 2, 3, 4, 5, 6]);
      expect(suggererRoutine(maintenant: vendredi, seances: [...a, ...b, _seance('a', DateTime(2026, 10, 2, 7))])!.routineId, 'b');
    });

    test('séances datées dans le futur (horloge déréglée) : ignorées', () {
      final habitude = _habitude('a', vendredi, [1, 2, 3, 4, 5, 6]);
      final s = suggererRoutine(maintenant: vendredi, seances: [...habitude, _seance('a', DateTime(2026, 10, 9, 18))])!;
      expect(s.fois, 6);
      expect(s.derniere, DateTime(2026, 9, 25, 18));
    });

    test('séances lues en temps universel : comptées au jour local', () {
      // 18 h locales, mais gardées en UTC (import, sauvegarde d'un autre fuseau).
      final utc = [for (final s in _habitude('a', vendredi, [1, 2, 3, 4, 5, 6], heure: 0, minute: 30)) _seance('a', s.debut.toUtc())];
      expect(utc.first.debut.isUtc, isTrue);
      expect(suggererRoutine(maintenant: vendredi, seances: utc)?.fois, 6, reason: '0 h 30 le vendredi est la veille en UTC');
    });
  });

  group('dernière fois', () {
    test('autour du changement d\'heure et du nouvel an', () {
      expect(derniereFois(DateTime(2026, 10, 24, 23, 30), maintenant: DateTime(2026, 10, 25, 0, 30)), 'Hier');
      expect(derniereFois(DateTime(2026, 10, 24, 12), maintenant: DateTime(2026, 10, 26, 0, 5)), 'Avant-hier');
      expect(derniereFois(DateTime(2026, 3, 28, 23, 59), maintenant: DateTime(2026, 3, 29, 3)), 'Hier');
      expect(derniereFois(DateTime(2026, 12, 31, 23), maintenant: DateTime(2027, 1, 1, 1)), 'Hier');
      expect(derniereFois(DateTime(2026, 12, 20), maintenant: DateTime(2027, 1, 3)), '20 décembre 2026');
      expect(derniereFois(DateTime(2026, 10, 3), maintenant: DateTime(2026, 10, 2)), 'Aujourd\'hui', reason: 'date future : pas de « il y a -1 jour »');
    });
  });

  group('« Une autre »', () {
    test('tient jusqu\'au lendemain, y compris après relecture du store', () async {
      final store = Store.memory();
      final prefs = RoutinePrefs.of(store);
      await prefs.load();
      final soir = DateTime(2026, 10, 2, 23, 59);
      await prefs.ecarterSuggestion(soir);
      expect(prefs.suggestionEcartee(DateTime(2026, 10, 2, 0, 0)), isTrue);
      expect(prefs.suggestionEcartee(DateTime(2026, 10, 3, 0, 0)), isFalse);
      expect(prefs.suggestionEcartee(DateTime(2027, 10, 2)), isFalse);
      expect(prefs.suggestionEcartee(DateTime(2026, 1, 2)), isFalse);
      expect(await store.read(RoutinePrefs.fichierSuggestion), {'ecartee': '2026-10-2'});
    });

    test('oublier une routine retire sa vignette et son favori, pas ceux des autres', () async {
      final store = Store.memory();
      final prefs = RoutinePrefs.of(store);
      await prefs.choisirJour('a', 3);
      await prefs.choisirJour('b', 4);
      await prefs.basculerFavori('a');
      await prefs.basculerFavori('b');
      await prefs.oublier('a');
      expect(prefs.vignetteDe('a'), isNull);
      expect(prefs.estFavori('a'), isFalse);
      expect(prefs.vignetteDe('b')?.jour, 4);
      expect(prefs.favoris, {'b'});
      expect(await store.read(RoutinePrefs.fichierFavoris), ['b']);
    });
  });
}
