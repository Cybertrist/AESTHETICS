import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/sante/common/sante_calculs.dart';
import 'package:aesthetic/features/sante/routes.dart';
import 'package:aesthetic/features/sante/services/activite_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Petite appli limitée aux routes Santé.
Widget _harnais(AppData d, String depart) {
  final router = GoRouter(initialLocation: depart, routes: santeRoutes());
  return MultiProvider(
    providers: [
      Provider<Store>.value(value: d.store),
      ChangeNotifierProvider<ProfileRepo>.value(value: d.profile),
      ChangeNotifierProvider<SettingsRepo>.value(value: d.settings),
      ChangeNotifierProvider<ExerciseRepo>.value(value: d.exercises),
      ChangeNotifierProvider<SessionRepo>.value(value: d.sessions),
      ChangeNotifierProvider<HealthRepo>.value(value: d.health),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark(AccentChoice.values.first.color),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
  });

  group('calculs', () {
    test('moyenne mobile sur 7 jours glissants', () {
      final d0 = DateTime(2026, 9, 1);
      final pts = [for (var i = 0; i < 10; i++) (date: d0.add(Duration(days: i)), v: i.toDouble())];
      final m = SanteCalc.moyenneMobile(pts);
      expect(m.first.v, 0);
      expect(m[6].v, 3); // moyenne de 0 à 6
      expect(m[9].v, 6); // moyenne de 3 à 9
      expect(SanteCalc.variation(m), 6);
    });

    test('heures moyennes autour de minuit', () {
      final a = DateTime(2026, 9, 1, 23, 30);
      final b = DateTime(2026, 9, 3, 0, 30);
      expect(SanteCalc.heureMoyenne([a, b]), '00:00');
      expect(SanteCalc.parseHeure('08:05'), (8, 5));
      expect(SanteCalc.parseHeure('25:00'), isNull);
    });

    test('série de prises consécutives', () {
      final now = DateTime(2026, 9, 30, 10);
      final pris = {DateTime(2026, 9, 28), DateTime(2026, 9, 29)};
      // Pas encore pris aujourd'hui : la série d'hier compte.
      expect(SanteCalc.serie((d) => pris.contains(d), now: now), 2);
    });

    test('mensurations : moyenne gauche et droite', () {
      final m = BodyMeasurement(id: 'a', date: DateTime(2026, 9, 1), tours: const {TourCorps.brasGauche: 36, TourCorps.brasDroit: 37});
      expect(GroupeTour.bras.valeur(m), 36.5);
      expect(GroupeTour.taille.valeur(m), isNull);
      expect(ecart(DateTime(2026, 1, 1), DateTime(2026, 1, 13)), '12 j');
    });

    test('récupération : un muscle travaillé hier n\'est pas prêt', () {
      final ex = Exercise.fromJson({
        'id': 'dc',
        'nom': 'Développé couché',
        'musclesPrincipaux': ['pectoraux'],
        'musclesSecondaires': ['triceps'],
        'equipement': 'barre',
        'categorie': 'pectoraux',
      });
      final now = DateTime(2026, 9, 30, 12);
      final s = WorkoutSession(
        id: 's',
        nom: 'Push',
        debut: now.subtract(const Duration(hours: 13)),
        fin: now.subtract(const Duration(hours: 12)),
        exercices: [
          SessionExercise(id: 'e', exerciseId: 'dc', series: [
            for (var i = 0; i < 6; i++) WorkoutSet(id: '$i', poids: 80, reps: 8, fait: true),
          ]),
        ],
      );
      final r = RecupCalc.calculer([s], (id) => id == 'dc' ? ex : null, now: now);
      expect(r[Muscle.pectoraux]!.pret, isFalse);
      expect(r[Muscle.pectoraux]!.heuresAvantPret, greaterThan(0));
      expect(r[Muscle.pectoraux]!.series7j, 6);
      expect(r[Muscle.triceps]!.series7j, 3);
      expect(r[Muscle.quadriceps]!.pret, isTrue);
      expect(r[Muscle.pectoraux]!.derniere?.id, 's');
    });
  });

  test('journal d\'activité : enregistrement et relecture', () async {
    final store = Store.memory();
    final j = ActiviteJournal.of(store);
    await j.charger();
    await j.enregistrer([JourActivite(jour: DateTime(2026, 9, 29), pas: 8000, fcRepos: 55)]);
    await j.reglerObjectifs(pas: 12000);
    final k = ActiviteJournal.of(store);
    await k.charger();
    expect(k.jour(DateTime(2026, 9, 29, 15))?.pas, 8000);
    expect(k.objectifPas, 12000);
  });

  testWidgets('noter une nuit l\'enregistre', (t) async {
    final d = AppData(Store.memory());
    await t.runAsync(() => Future.wait([d.health.load(), d.settings.load(), d.profile.load(), d.sessions.load()]));
    await t.pumpWidget(_harnais(d, '/sante/sommeil/ajouter'));
    await t.pumpAndSettle();
    expect(find.text('Noter une nuit'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(d.health.sleep, hasLength(1));
    expect(d.health.sleep.first.duree.inMinutes, greaterThan(0));
  });

  testWidgets('complément : ajout depuis un modèle puis case du jour', (t) async {
    final d = AppData(Store.memory());
    await t.runAsync(() => Future.wait([d.health.load(), d.settings.load(), d.profile.load(), d.sessions.load()]));
    await t.pumpWidget(_harnais(d, '/sante/complements'));
    await t.pumpAndSettle();
    expect(find.text('Aucun complément suivi'), findsOneWidget);
    await t.tap(find.text('Créatine'));
    await t.pumpAndSettle();
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(d.health.supplements.single.nom, 'Créatine');
    await t.tap(find.text('Créatine'));
    await t.pumpAndSettle();
    expect(d.health.takenOn(d.health.supplements.single.id, DateTime.now()), isTrue);
  });

  testWidgets('états vides du corps et de l\'activité', (t) async {
    final d = AppData(Store.memory());
    await t.runAsync(() => Future.wait([d.health.load(), d.settings.load(), d.profile.load(), d.sessions.load()]));
    await t.pumpWidget(_harnais(d, '/sante/corps'));
    await t.pumpAndSettle();
    expect(find.text('Rien de mesuré pour l\'instant'), findsOneWidget);
    await t.pumpWidget(_harnais(d, '/sante/activite'));
    await t.pumpAndSettle();
    expect(find.text('Reliez Health Connect'), findsOneWidget);
  });
}
