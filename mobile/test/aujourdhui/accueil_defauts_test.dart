// Défauts cherchés sur l'accueil (écran 01) : bords de mois et d'année,
// changement d'heure, semaine réglable, cloche, cartes de séance, menu et
// suppression, état vide, Fold ouvert.
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/aujourdhui/logic/accueil.dart';
import 'package:aesthetic/features/aujourdhui/logic/resume_jour.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/aujourdhui/widgets/accueil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'banc.dart';

var _n = 0;
String _id() => 'd${_n++}';

SessionExercise _ex(String id, int series, double poids, int reps) => SessionExercise(
      id: _id(),
      exerciseId: id,
      series: [for (var i = 0; i < series; i++) WorkoutSet(id: _id(), poids: poids, reps: reps, fait: true)],
    );

WorkoutSession _seance(
  String id,
  DateTime debut, {
  String nom = 'Séance',
  int minutes = 60,
  List<SessionExercise> exercices = const [],
  List<SessionMedia> medias = const [],
  TypeSeance type = TypeSeance.musculation,
}) =>
    WorkoutSession(
      id: id,
      nom: nom,
      debut: debut,
      fin: debut.add(Duration(minutes: minutes)),
      exercices: exercices,
      medias: medias,
      type: type,
    );

Future<AppData> _donnees(List<WorkoutSession> seances, {int objectif = 3, int premierJour = DateTime.monday}) async {
  final data = AppData(Store.memory(), demo: false);
  await data.loadAll();
  await data.profile.save(UserProfile(
    id: 'u',
    prenom: 'Tristan',
    creeLe: DateTime(2026, 1, 1),
    poidsKg: 77,
    tailleCm: 181,
    joursParSemaine: objectif,
  ));
  if (premierJour != DateTime.monday) await data.settings.update((s) => s.copyWith(premierJourSemaine: premierJour));
  await data.sessions.addAll(seances);
  return data;
}

Future<void> _pomper(WidgetTester t) async {
  // Les écritures du stockage se terminent dans la vraie boucle d'événements.
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// Le texte de la ligne de chiffres de « Cette semaine ».
String _ligneSemaine(WidgetTester t) {
  final carte = find.byType(CarteCetteSemaine);
  final textes = t.widgetList<RichText>(find.descendant(of: carte, matching: find.byType(RichText)));
  return textes.map((r) => r.text.toPlainText()).firstWhere((s) => s.contains(' / '));
}

void main() {
  setUpAll(() async {
    preparerAssets();
    await initializeDateFormatting('fr_FR');
  });

  group('résumé mensuel', () {
    WorkoutSession le(DateTime d) => _seance(_id(), d);

    test('du 1er au 3 seulement, jusqu\'à la dernière seconde du 3', () {
      final s = [le(DateTime(2026, 9, 12, 18))];
      expect(moisDuResume(DateTime(2026, 10, 1, 0, 0, 0), s), DateTime(2026, 9));
      expect(moisDuResume(DateTime(2026, 10, 3, 23, 59, 59), s), DateTime(2026, 9));
      expect(moisDuResume(DateTime(2026, 10, 4, 0, 0, 0), s), isNull);
      expect(moisDuResume(DateTime(2026, 9, 30, 23, 59), s), isNull);
      expect(moisDuResume(DateTime(2026, 10, 31), s), isNull);
    });

    test('bords du mois : la dernière minute compte, la première du mois suivant non', () {
      expect(moisDuResume(DateTime(2026, 10, 2), [le(DateTime(2026, 9, 30, 23, 59))]), DateTime(2026, 9));
      expect(moisDuResume(DateTime(2026, 10, 2), [le(DateTime(2026, 9, 1))]), DateTime(2026, 9));
      expect(moisDuResume(DateTime(2026, 10, 2), [le(DateTime(2026, 10, 1))]), isNull);
      expect(moisDuResume(DateTime(2026, 10, 2), [le(DateTime(2026, 8, 31, 23, 59))]), isNull);
    });

    test('bord d\'année et février', () {
      final dec = [le(DateTime(2026, 12, 31, 23, 30))];
      expect(moisDuResume(DateTime(2027, 1, 1), dec), DateTime(2026, 12));
      expect(libelleMois(moisDuResume(DateTime(2027, 1, 3), dec)!), 'décembre 2026');
      expect(moisDuResume(DateTime(2027, 1, 4), dec), isNull);
      // Une séance de janvier de l'année d'avant ne compte pas pour décembre.
      expect(moisDuResume(DateTime(2027, 1, 2), [le(DateTime(2026, 1, 15))]), isNull);
      // Année bissextile.
      expect(moisDuResume(DateTime(2028, 3, 1), [le(DateTime(2028, 2, 29, 20))]), DateTime(2028, 2));
      final n = nouveautes(sessions: dec, now: DateTime(2027, 1, 2), objectif: 3);
      expect(n.where((x) => x.cible == CibleNouveaute.bilanMois).single.id, '2026-12');
    });

    test('un mois sans séance ne propose rien, même avec des séances plus anciennes', () {
      final s = [le(DateTime(2026, 8, 20)), le(DateTime(2026, 10, 1, 8))];
      expect(moisDuResume(DateTime(2026, 10, 2), s), isNull);
      expect(nouveautes(sessions: s, now: DateTime(2026, 10, 2), objectif: 9).where((x) => x.cible == CibleNouveaute.bilanMois), isEmpty);
    });
  });

  group('semaine', () {
    test('la semaine garde ses sept jours à minuit autour du changement d\'heure', () {
      for (final premier in [DateTime.monday, DateTime.saturday, DateTime.sunday]) {
        for (var j = 0; j < 400; j++) {
          final d = DateTime(2026, 1, 1 + j, 15);
          final debut = Dates.debutSemaine(d, premierJour: premier);
          expect(debut.hour, 0, reason: 'début de semaine de $d (premier jour $premier) : $debut');
          expect(debut.weekday, premier, reason: 'début de semaine de $d : $debut');
          final jours = Dates.joursSemaine(d, premierJour: premier);
          expect(jours.any((x) => Dates.memeJour(x, d)), isTrue, reason: 'la semaine de $d ne contient pas ce jour');
        }
      }
    });

    test('une séance du dimanche soir du changement d\'heure reste dans sa semaine', () async {
      // Dimanche 25 octobre 2026 : jour de 25 heures en Europe.
      final data = await _donnees([_seance('a', DateTime(2026, 10, 25, 23, 30))]);
      final r = ResumeSemaine.pour(data.sessions, DateTime(2026, 10, 23, 12));
      expect(r.nbSeances, 1);
      final n = nouveautes(sessions: data.sessions.sessions, now: DateTime(2026, 10, 25, 23, 50), objectif: 1);
      expect(n.where((x) => x.cible == CibleNouveaute.semaine), hasLength(1));
    });

    test('une séance du lundi à minuit et demi ne compte pas dans la semaine d\'avant', () async {
      // Dimanche 29 mars 2026 : jour de 23 heures en Europe.
      final data = await _donnees([_seance('a', DateTime(2026, 3, 30, 0, 30))]);
      expect(ResumeSemaine.pour(data.sessions, DateTime(2026, 3, 27, 12)).nbSeances, 0);
      expect(ResumeSemaine.pour(data.sessions, DateTime(2026, 3, 30, 12)).nbSeances, 1);
      final n = nouveautes(sessions: data.sessions.sessions, now: DateTime(2026, 3, 29, 12), objectif: 1);
      expect(n.where((x) => x.cible == CibleNouveaute.semaine), isEmpty);
    });

    testWidgets('ligne de chiffres : objectif, durée, volume', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 9, 28, 18), minutes: 61, exercices: [_ex('x', 3, 100, 10)]),
            _seance('b', DateTime(2026, 9, 30, 18), minutes: 44, exercices: [_ex('x', 1, 50, 10)]),
            // Dimanche d'avant : hors de la semaine.
            _seance('c', DateTime(2026, 9, 27, 23, 59), minutes: 30, exercices: [_ex('x', 1, 50, 10)]),
          ], objectif: 5)))!;
      await rendreAccueil(t, data, 'defauts-semaine', const Size(390, 1500), DateTime(2026, 10, 2, 12));
      expect(_ligneSemaine(t), '2 / 5 séances  ·  1 h 45  ·  3 500 kg');
    });

    testWidgets('semaine qui commence le dimanche : le dimanche d\'avant en fait partie', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 9, 28, 18)),
            _seance('c', DateTime(2026, 9, 27, 9)),
          ], objectif: 1, premierJour: DateTime.sunday)))!;
      await rendreAccueil(t, data, 'defauts-semaine-dimanche', const Size(390, 1500), DateTime(2026, 10, 2, 12));
      expect(_ligneSemaine(t), startsWith('2 / 1 séance  ·'));
      final initiales = t
          .widgetList<Text>(find.descendant(of: find.byType(CarteCetteSemaine), matching: find.byType(Text)))
          .map((x) => x.data)
          .where((x) => x != null && x.length == 1 && 'LMJVSD'.contains(x))
          .join();
      expect(initiales, 'DLMMJVS');
    });

    testWidgets('sans objectif ni séance : pas de durée ni de volume', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([], objectif: 0)))!;
      await rendreAccueil(t, data, 'defauts-semaine-vide', const Size(390, 900), DateTime(2026, 10, 2, 12));
      expect(_ligneSemaine(t), '0 / 0 séance');
    });

    testWidgets('deux séances le même jour : la pastille montre la première, comme le calendrier', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('matin', DateTime(2026, 9, 29, 8), exercices: [_ex('x', 3, 100, 10)]),
            _seance('soir', DateTime(2026, 9, 29, 19), type: TypeSeance.cardio, nom: 'Footing'),
          ])))!;
      await rendreAccueil(t, data, 'defauts-deux-seances', const Size(390, 1500), DateTime(2026, 10, 2, 12));
      final semantique = t.ensureSemantics();
      expect(find.bySemanticsLabel('29, Musculation'), findsOneWidget);
      semantique.dispose();
    });
  });

  group('flamme', () {
    test('série de semaines : la semaine en cours vide ne casse rien, un trou si', () async {
      final now = DateTime(2026, 10, 2, 12);
      final data = await _donnees([
        _seance('a', DateTime(2026, 9, 24, 18)),
        _seance('b', DateTime(2026, 9, 14, 18)),
        _seance('c', DateTime(2026, 8, 31, 18)),
      ]);
      // Semaines du 21 et du 14 septembre ; celle du 7 est vide.
      expect(data.sessions.streakWeeks(now: now), 2);
      await data.sessions.save(_seance('d', DateTime(2026, 10, 1, 7)));
      expect(data.sessions.streakWeeks(now: now), 3);
      await data.sessions.delete('a');
      expect(data.sessions.streakWeeks(now: now), 1);
    });

    test('série à cheval sur le changement d\'année et d\'heure', () async {
      final data = await _donnees([
        for (var i = 0; i < 30; i++) _seance(_id(), DateTime(2027, 1, 6 - 7 * i, 18)),
      ]);
      expect(data.sessions.streakWeeks(now: DateTime(2027, 1, 8)), 30);
    });

    testWidgets('libellé et couleur de la flamme à zéro et à une semaine', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance('a', DateTime(2026, 10, 1, 18))])))!;
      await rendreAccueil(t, data, 'defauts-flamme-1', const Size(390, 900), DateTime(2026, 10, 2, 12));
      final semantique = t.ensureSemantics();
      expect(find.bySemanticsLabel('Série de 1 semaine'), findsOneWidget);
      semantique.dispose();
    });
  });

  group('cloche', () {
    final now = DateTime(2026, 10, 2, 12);

    test('ce qui compte comme nouveau', () async {
      final store = Store.memory();
      final cloche = ClocheRepo(store);
      await cloche.pret;
      final liste = nouveautes(
        sessions: [
          _seance('a', DateTime(2026, 9, 10, 18), exercices: [_ex('x', 1, 50, 10)]),
          _seance('b', DateTime(2026, 9, 29, 18), exercices: [_ex('x', 1, 60, 10)]),
          _seance('c', DateTime(2026, 10, 1, 18), exercices: [_ex('x', 1, 55, 10)]),
        ],
        now: now,
        objectif: 2,
      );
      // Résumé de septembre, record du 29, objectif atteint le 1er octobre.
      expect(liste.map((n) => n.cible), [CibleNouveaute.semaine, CibleNouveaute.bilanMois, CibleNouveaute.seance]);
      expect(cloche.aDuNouveau(liste), isTrue);
      await cloche.marquerVu(DateTime(2026, 9, 30, 9));
      // Le record du 29 est vu, le résumé (1er octobre) et l'objectif non.
      expect(liste.where(cloche.estNouvelle).map((n) => n.cible), [CibleNouveaute.semaine, CibleNouveaute.bilanMois]);
      await cloche.marquerVu(now);
      expect(cloche.aDuNouveau(liste), isFalse);
      expect(cloche.aDuNouveau(const []), isFalse);
    });

    test('un record de plus de quatorze jours n\'est plus listé', () {
      final liste = nouveautes(
        sessions: [
          _seance('a', DateTime(2026, 8, 1, 18), exercices: [_ex('x', 1, 50, 10)]),
          _seance('b', DateTime(2026, 9, 17, 18), exercices: [_ex('x', 1, 60, 10)]),
        ],
        now: now,
        objectif: 3,
      );
      expect(liste.where((n) => n.cible == CibleNouveaute.seance), isEmpty);
    });

    test('la date d\'ouverture survit au redémarrage', () async {
      final store = Store.memory();
      final a = ClocheRepo(store);
      await a.pret;
      await a.marquerVu(now);
      final b = ClocheRepo(store);
      await b.pret;
      expect(b.vuLe, now);
    });

    test('ouvrir la cloche avant la fin du chargement ne perd pas l\'ouverture', () async {
      final store = Store.memory();
      await store.write(ClocheRepo.fichier, {'vuLe': DateTime(2026, 9, 1).toIso8601String()});
      final cloche = ClocheRepo(store);
      final pret = cloche.pret;
      final vu = cloche.marquerVu(now);
      await pret;
      await vu;
      expect(cloche.vuLe, now);
      final relu = ClocheRepo(store);
      await relu.pret;
      expect(relu.vuLe, now);
    });

    test('un fichier abîmé ne bloque pas la cloche', () async {
      final store = Store.memory();
      await store.write(ClocheRepo.fichier, {'vuLe': 'pas une date'});
      final cloche = ClocheRepo(store);
      await cloche.pret;
      expect(cloche.charge, isTrue);
      expect(cloche.vuLe, isNull);
    });

    testWidgets('le point s\'éteint à l\'ouverture et reste éteint', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 9, 10, 18), exercices: [_ex('x', 1, 50, 10)]),
            _seance('b', DateTime(2026, 10, 1, 18), nom: 'Dos très long ' * 6, exercices: [_ex('x', 1, 60, 10)]),
          ], objectif: 1)))!;
      await rendreAccueil(t, data, 'defauts-cloche-avant', const Size(360, 900), now);
      final semantique = t.ensureSemantics();
      expect(find.bySemanticsLabel('Notifications, du nouveau'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Notifications, du nouveau'));
      await _pomper(t);
      expect(t.takeException(), isNull);
      expect(find.text('Ton résumé de septembre 2026 est prêt'), findsOneWidget);
      expect(find.text('Un record battu'), findsOneWidget);
      expect(find.text('Objectif de la semaine atteint'), findsOneWidget);
      expect(find.text('1 / 1 séance'), findsOneWidget);
      await t.runAsync(() => rendreCapture(t, 'defauts-cloche-panneau'));
      await t.tapAt(const Offset(180, 40));
      await _pomper(t);
      expect(find.bySemanticsLabel('Notifications, du nouveau'), findsNothing);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      // Relance de l'appli sur le même stockage.
      await rendreAccueil(t, data, 'defauts-cloche-apres', const Size(360, 900), now);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      // Un nouveau record rallume le point.
      await t.runAsync(() => data.sessions.save(_seance('c', DateTime(2026, 10, 2, 13), exercices: [_ex('x', 1, 70, 10)])));
      await rendreAccueil(t, data, 'defauts-cloche-rallumee', const Size(360, 900), DateTime(2026, 10, 2, 15));
      expect(find.bySemanticsLabel('Notifications, du nouveau'), findsOneWidget);
      semantique.dispose();
    });

    testWidgets('cloche sans rien : message, pas de point', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([])))!;
      await rendreAccueil(t, data, 'defauts-cloche-vide', const Size(360, 900), now);
      await t.tap(find.bySemanticsLabel('Notifications'));
      await _pomper(t);
      expect(find.textContaining('Rien de nouveau'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('cartes de séance', () {
    final now = DateTime(2026, 10, 2, 12);

    testWidgets('trente médias sur un écran étroit : les points tiennent dans la carte', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 10, 1, 18), medias: [
              for (var i = 0; i < 30; i++) SessionMedia(chemin: 'absente/$i.jpg'),
            ]),
          ])))!;
      await rendreAccueil(t, data, 'defauts-trente-medias', const Size(320, 900), now);
      expect(find.text('Photo · 1 / 30'), findsOneWidget);
    });

    testWidgets('un seul média, fichier disparu, vidéo sans durée', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 10, 1, 18), medias: const [SessionMedia(chemin: 'absente/seule.jpg')]),
            _seance('b', DateTime(2026, 9, 30, 18), medias: const [SessionMedia(chemin: '')]),
            _seance('c', DateTime(2026, 9, 29, 18), medias: const [
              SessionMedia(chemin: 'absente/v.mp4', video: true),
              SessionMedia(chemin: 'absente/v2.mp4', video: true, dureeSec: 3725),
            ]),
          ])))!;
      await rendreAccueil(t, data, 'defauts-medias', const Size(360, 1500), now);
      expect(find.text('Photo'), findsNWidgets(2));
      expect(find.text('Vidéo'), findsOneWidget);
    });

    testWidgets('cas limites : sans exercice, nom vide ou énorme, un seul exercice, exercice supprimé, volumes énormes', (t) async {
      await t.runAsync(polices);
      final connu = (await t.runAsync(() async => (await _donnees([])).exercises.catalogue.first.id))!;
      final data = (await t.runAsync(() => _donnees([
            _seance('vide', DateTime(2026, 10, 1, 18), nom: '', minutes: 0),
            _seance('long', DateTime(2025, 12, 31, 23, 59),
                nom: 'Pectoraux épaules triceps abdominaux mollets et tout le reste du corps',
                minutes: 60 * 27 + 5,
                exercices: [_ex(connu, 12, 987654, 99), _ex('inconnu', 1, 20, 5)]),
            _seance('un', DateTime(2026, 9, 30, 18), exercices: [_ex(connu, 3, 20, 5)]),
            _seance('a-faire', DateTime(2026, 9, 29, 18), exercices: [
              SessionExercise(id: _id(), exerciseId: connu, series: [WorkoutSet(id: _id(), poids: 20, reps: 5)]),
            ]),
          ])))!;
      for (final l in [320.0, 360.0, 700.0]) {
        await rendreAccueil(t, data, 'defauts-limites-${l.toInt()}', Size(l, 1700), now);
      }
      expect(find.textContaining('Exercice supprimé', findRichText: true), findsOneWidget);
      // Une séance sans nom garde un titre.
      expect(find.text('SÉANCE'), findsNWidgets(3));
      // L'année s'affiche quand ce n'est pas la nôtre.
      expect(find.text('31 décembre 2025 · 23:59'), findsOneWidget);
    });

    testWidgets('plus de trois exercices : « et 1 autre exercice » au singulier', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            _seance('a', DateTime(2026, 10, 1, 18), exercices: [for (var i = 0; i < 4; i++) _ex('e$i', 2, 20, 5)]),
            _seance('b', DateTime(2026, 9, 30, 18), exercices: [for (var i = 0; i < 12; i++) _ex('f$i', 2, 20, 5)]),
          ])))!;
      await rendreAccueil(t, data, 'defauts-plus-de-trois', const Size(360, 1500), now);
      expect(find.text('et 1 autre exercice'), findsOneWidget);
      expect(find.text('et 9 autres exercices'), findsOneWidget);
    });

    testWidgets('cinq cartes au plus, dans l\'ordre, et le lien Historique', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([
            for (var i = 0; i < 8; i++) _seance('s$i', DateTime(2026, 10, 1, 18).subtract(Duration(days: i)), nom: 'Séance $i'),
          ])))!;
      await rendreAccueil(t, data, 'defauts-cinq', const Size(390, 2000), now);
      expect(t.widgetList<CarteSeance>(find.byType(CarteSeance)).map((c) => c.session.id), ['s0', 's1', 's2', 's3', 's4']);
      expect(find.text('Historique'), findsOneWidget);
    });
  });

  group('menu et suppression', () {
    final now = DateTime(2026, 10, 2, 12);

    Future<AppData> jeu() => _donnees([
          _seance('a', DateTime(2026, 9, 10, 18), nom: 'Première', exercices: [_ex('x', 1, 50, 10)]),
          _seance('b', DateTime(2026, 9, 29, 18), nom: 'Record', exercices: [_ex('x', 1, 60, 10)]),
          _seance('c', DateTime(2026, 10, 1, 18), nom: 'Dernière', exercices: [_ex('x', 1, 55, 10)]),
        ]);

    test('les records se recalculent quand une séance disparaît', () async {
      final data = await jeu();
      expect(recordsParSeance(data.sessions.sessions), {'b': 1});
      await data.sessions.delete('b');
      // Sans la séance à 60 kg, celle à 55 kg devient le record.
      expect(recordsParSeance(data.sessions.sessions), {'c': 1});
      await data.sessions.delete('a');
      // Plus d'historique avant : une première fois n'est pas un record.
      expect(recordsParSeance(data.sessions.sessions), isEmpty);
    });

    testWidgets('annuler garde la séance, confirmer la supprime pour de bon', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(jeu))!;
      await rendreAccueil(t, data, 'defauts-suppression-avant', const Size(390, 1500), now);
      CarteSeance carte(String id) => t.widgetList<CarteSeance>(find.byType(CarteSeance)).firstWhere((c) => c.session.id == id);
      expect(carte('b').records, 1);
      expect(carte('c').records, 0);

      Future<void> ouvrirSuppression() async {
        final menu = find.descendant(
          of: find.byWidgetPredicate((w) => w is CarteSeance && w.session.id == 'b'),
          matching: find.byTooltip('Plus d\'actions'),
        );
        await t.tap(menu);
        await _pomper(t);
        expect(find.text('Voir le bilan de la séance'), findsOneWidget);
        expect(find.text('Refaire cette séance'), findsOneWidget);
        expect(find.text('Modifier la séance'), findsOneWidget);
        await t.tap(find.text('Supprimer la séance'));
        await _pomper(t);
        expect(find.text('Supprimer cette séance ?'), findsOneWidget);
      }

      await ouvrirSuppression();
      await t.runAsync(() => rendreCapture(t, 'defauts-suppression-confirmation'));
      await t.tap(find.text('Annuler'));
      await _pomper(t);
      expect(data.sessions.byId('b'), isNotNull);
      expect(find.text('RECORD'), findsOneWidget);

      await ouvrirSuppression();
      await t.tap(find.text('Supprimer'));
      await _pomper(t);
      expect(t.takeException(), isNull);
      expect(data.sessions.byId('b'), isNull);
      expect(find.text('RECORD'), findsNothing);
      expect(find.text('Séance supprimée.'), findsOneWidget);
      expect(carte('c').records, 1);
      // Relu depuis le stockage : elle n'y est plus.
      final relu = AppData(data.store, demo: false);
      await t.runAsync(relu.loadAll);
      expect(relu.sessions.sessions.map((s) => s.id), ['c', 'a']);
    });

    testWidgets('supprimer la dernière séance ramène l\'état vide', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance('a', DateTime(2026, 10, 1, 18), nom: 'Seule')])))!;
      await rendreAccueil(t, data, 'defauts-derniere', const Size(390, 900), now);
      await t.tap(find.byTooltip('Plus d\'actions'));
      await _pomper(t);
      await t.tap(find.text('Supprimer la séance'));
      await _pomper(t);
      await t.tap(find.text('Supprimer'));
      await _pomper(t);
      expect(t.takeException(), isNull);
      expect(find.text('Aucune séance pour l\'instant'), findsOneWidget);
      expect(find.text('Historique'), findsNothing);
      final semantique = t.ensureSemantics();
      expect(find.bySemanticsLabel('Série de 0 semaine'), findsOneWidget);
      semantique.dispose();
    });
  });

  group('horloge, état vide, Fold', () {
    testWidgets('au retour dans l\'appli, la carte bleue suit la date', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance('a', DateTime(2026, 9, 12, 18))])))!;
      var heure = DateTime(2026, 10, 3, 23, 50);
      await rendreAccueil(t, data, 'defauts-horloge', const Size(390, 900), heure, page: AujourdhuiPage(horloge: () => heure));
      expect(find.text('Résumé mensuel'), findsOneWidget);
      heure = DateTime(2026, 10, 4, 8);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pomper(t);
      expect(find.text('Résumé mensuel'), findsNothing);
    });

    testWidgets('état vide en 320, 360 et Fold ouvert', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([])))!;
      for (final l in [320.0, 360.0, 700.0, 884.0]) {
        await rendreAccueil(t, data, 'defauts-vide-${l.toInt()}', Size(l, 900), DateTime(2026, 10, 2, 12));
        expect(find.text('Choisir une séance'), findsOneWidget);
        expect(find.text('Historique'), findsNothing);
      }
    });

    testWidgets('bascule en deux colonnes à 700 de large, pas avant', (t) async {
      await t.runAsync(polices);
      final data = (await t.runAsync(() => _donnees([_seance('a', DateTime(2026, 9, 12, 18))])))!;
      double gauche(Finder f) => t.getTopLeft(f).dx;
      await rendreAccueil(t, data, 'defauts-699', const Size(699, 900), DateTime(2026, 10, 2, 12));
      expect(gauche(find.text('Dernières séances')), lessThan(120));
      expect(t.getTopLeft(find.text('Dernières séances')).dy, greaterThan(t.getTopLeft(find.text('Cette semaine')).dy));
      await rendreAccueil(t, data, 'defauts-700', const Size(700, 900), DateTime(2026, 10, 2, 12));
      expect(gauche(find.text('Dernières séances')), greaterThan(350));
      expect(t.getTopLeft(find.text('Dernières séances')).dy, lessThan(t.getTopLeft(find.text('Cette semaine')).dy));
    });
  });
}
