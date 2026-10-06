import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/chrono.dart';
import 'package:aesthetic/features/seance/logic/lancement.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:aesthetic/features/seance/pages/lanceur_page.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'test_saisie_outils.dart';

/// Lancer une séance : double appui, séance déjà en cours, barre réduite,
/// abandon, reprise après fermeture de l'appli.
void main() {
  testWidgets('deux appuis sur « Commencer la séance » ne lancent qu\'une séance, sans question', (t) async {
    final d = await monter(t, depart: '/');
    final push = d.routines.routines.firstWhere((r) => r.nom == 'Push');
    routeurDe(t).push(SeancePaths.apercu(push.id));
    await attendre(t, tours: 6);

    final bouton = find.text('Commencer la séance');
    await t.tap(bouton);
    await t.tap(bouton, warnIfMissed: false);
    await t.pump();
    if (bouton.evaluate().isNotEmpty) await t.tap(bouton, warnIfMissed: false);
    await attendre(t);

    expect(find.text('Une séance est déjà en cours'), findsNothing, reason: 'le second appui ne doit pas proposer d\'abandonner la séance tout juste lancée');
    expect(d.sessions.active?.routineId, push.id);
    expect(find.byType(LanceurPage), findsNothing);
    expect(find.byType(SeancePage), findsOneWidget, reason: 'un seul écran de séance empilé');
    expect(find.text('Terminer'), findsOneWidget);

    // Réduire ramène à l'accueil du banc, pas à un second écran de séance.
    await t.tap(find.bySemanticsLabel('Réduire la séance'));
    await attendre(t, tours: 2);
    expect(find.byType(SeancePage), findsNothing);
    expect(find.text('Entraînement en cours'), findsOneWidget);
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('une séance déjà en cours : la garder ne perd rien, la remplacer demande confirmation', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    final premiere = d.sessions.active!.id;
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    await t.tap(find.bySemanticsLabel('Réduire la séance'));
    await attendre(t, tours: 2);

    final pull = d.routines.routines.firstWhere((r) => r.nom == 'Pull');
    routeurDe(t).push(SeancePaths.routine(pull.id));
    await attendre(t, tours: 3);
    expect(find.text('Une séance est déjà en cours'), findsOneWidget);
    await t.tap(find.text('Garder l\'actuelle'));
    await attendre(t);
    expect(d.sessions.active!.id, premiere);
    expect(seriesDe(d).where((s) => s.fait).length, 1);
    expect(ReposMinuteur.instance.actif, isTrue, reason: 'garder la séance ne coupe pas son repos');

    // Cette fois on la remplace : une seule séance active, la nouvelle.
    await t.tap(find.bySemanticsLabel('Réduire la séance'));
    await attendre(t, tours: 2);
    PauseSeance.instance.mettreEnPause(d.sessions.active!, store: d.store);
    routeurDe(t).push(SeancePaths.routine(pull.id));
    await attendre(t, tours: 3);
    await t.tap(find.text('Abandonner et démarrer'));
    await attendre(t);
    expect(d.sessions.active!.id, isNot(premiere));
    expect(d.sessions.active!.routineId, pull.id);
    expect(d.sessions.sessions.where((s) => s.id == premiere), isEmpty, reason: 'la séance abandonnée ne va pas dans l\'historique');
    expect(ReposMinuteur.instance.actif, isFalse);
    expect(PauseSeance.instance.enPause(d.sessions.active), isFalse);
    expect(find.text('Durée'), findsOneWidget, reason: 'la nouvelle séance ne démarre pas en pause');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('abandonner depuis le menu « Plus » : confirmation, annulation sans perte, puis plus rien', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);

    await toucherPlus(t);
    await attendre(t, tours: 2);
    await t.tap(find.text('Abandonner la séance'));
    await attendre(t, tours: 2);
    expect(find.text('Abandonner la séance ?'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await attendre(t, tours: 2);
    expect(d.sessions.hasActive, isTrue);
    expect(seriesDe(d).first.fait, isTrue);
    expect(ReposMinuteur.instance.actif, isTrue);

    final avant = d.sessions.sessions.length;
    await toucherPlus(t);
    await attendre(t, tours: 2);
    await t.tap(find.text('Abandonner la séance'));
    await attendre(t, tours: 2);
    await t.tap(find.text('Abandonner'));
    await attendre(t, tours: 3);
    expect(d.sessions.hasActive, isFalse);
    expect(d.sessions.sessions.length, avant);
    expect(ReposMinuteur.instance.actif, isFalse);
    expect(find.text('Terminer'), findsNothing);
    final relu = await relire(t, d.store);
    expect(relu.active, isNull, reason: 'rien ne revient au redémarrage');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('au redémarrage, la séance en cours revient dans la barre avec ses séries', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    final id = d.sessions.active!.id;
    await demonter(t);

    // L'appli est relancée : nouveaux dépôts sur le même stockage.
    ReposMinuteur.instance.reinitialiser();
    PauseSeance.instance.reinitialiser();
    final d2 = await tourner(t, () async {
      final x = AppData(d.store);
      await Future.wait([x.profile.load(), x.settings.load(), x.exercises.load(), x.routines.load(), x.programs.load(), x.sessions.load(), x.health.load()]);
      return x;
    }());
    await monter(t, depart: '/', data: d2);
    expect(d2.sessions.active?.id, id);
    expect(find.text('Entraînement en cours'), findsOneWidget);
    await t.tap(find.text('Reprendre'));
    await attendre(t);
    expect(find.bySemanticsLabel('Décocher la série'), findsOneWidget);
    expect(d2.sessions.active!.exercices.single.series.first.fait, isTrue);
    expect(find.text('Repos'), findsOneWidget, reason: 'le minuteur de repos ne survit pas à la fermeture (affichage neutre)');
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  test('refaire une séance passée : mêmes charges, rien de coché, une seule séance active', () async {
    final repo = SessionRepo(Store.memory());
    await repo.load();
    final t0 = DateTime(2026, 9, 30, 18);
    final passee = WorkoutSession(id: 'p', nom: 'Push', debut: t0, fin: t0.add(const Duration(hours: 1)), exercices: [
      SessionExercise(id: 'e', exerciseId: 'x', series: [
        WorkoutSet(id: 's', poids: 80, reps: 8, fait: true, faitLe: t0, tempsReposSec: 120, rpe: 9),
      ]),
    ]);
    await repo.save(passee);
    await repo.startEmpty();
    final a = await Lancement.refaire(repo, passee);
    expect(repo.active!.id, a.id);
    expect(a.id, isNot('p'));
    expect(a.enCours, isTrue);
    final serie = a.exercices.single.series.single;
    expect(serie.fait, isFalse);
    expect(serie.faitLe, isNull);
    expect(serie.tempsReposSec, isNull);
    expect(serie.poids, 80);
    expect(serie.reps, 8);
    expect(repo.sessions.single.id, 'p', reason: 'la séance passée reste intacte dans l\'historique');
    expect(repo.sessions.single.exercices.single.series.single.fait, isTrue);
  });
}
