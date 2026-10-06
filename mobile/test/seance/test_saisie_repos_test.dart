import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/chrono.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'test_saisie_outils.dart';

/// Minuteur de repos, pause de la séance et chronomètre libre.
void main() {
  final m = ReposMinuteur.instance;


  testWidgets('le repos suit l\'heure du téléphone, pas un compteur', (t) async {
    addTearDown(m.reinitialiser);
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    m.demarrer(120, son: false, vibration: false);
    expect(m.actif, isTrue);
    expect(m.restant, const Duration(seconds: 120));
    expect(m.progression, 0);

    // 45 s passent sans qu'aucun battement n'ait eu lieu (appli endormie).
    maintenant = maintenant.add(const Duration(seconds: 45));
    expect(m.restant, const Duration(seconds: 75));
    expect(m.progression, closeTo(45 / 120, 1e-9));

    // Le battement suivant constate la fin dès que l'heure est passée.
    maintenant = maintenant.add(const Duration(seconds: 80));
    expect(m.restant, Duration.zero);
    await t.pump(const Duration(milliseconds: 300));
    expect(m.actif, isFalse);
    expect(m.progression, 0);
  });

  testWidgets('−10 et +10 : jamais sous zéro, et le total suit', (t) async {
    addTearDown(m.reinitialiser);
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    m.demarrer(25, son: false, vibration: false);
    m.ajuster(10);
    expect(m.total, 35);
    expect(m.restant, const Duration(seconds: 35));
    m.ajuster(-10);
    m.ajuster(-10);
    expect(m.total, 15);
    expect(m.restant, const Duration(seconds: 15));
    maintenant = maintenant.add(const Duration(seconds: 8));
    expect(m.restant, const Duration(seconds: 7));
    // Il reste 7 s : −10 termine le repos, sans durée négative ni alerte.
    var alertes = 0;
    m.surAlerte = () => alertes++;
    m.ajuster(-10);
    expect(m.actif, isFalse);
    expect(m.restant, Duration.zero);
    expect(m.progression, 0);
    await t.pump(const Duration(milliseconds: 300));
    expect(alertes, 0);
    // Sans repos en cours, les boutons ne font rien.
    m.ajuster(10);
    expect(m.actif, isFalse);
    m.demarrer(0);
    m.demarrer(-5);
    expect(m.actif, isFalse);
  });

  testWidgets('fin du repos au premier plan : une alerte, une seule', (t) async {
    addTearDown(m.reinitialiser);
    var alertes = 0;
    m.surAlerte = () => alertes++;
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    m.demarrer(30);
    maintenant = maintenant.add(const Duration(seconds: 30));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(m.actif, isFalse);
    expect(alertes, 1);
    final n = alertes;
    await t.pump(const Duration(seconds: 2));
    expect(alertes, n, reason: 'le battement est arrêté, rien ne resonne');
  });

  testWidgets('retour dans l\'appli longtemps après la fin du repos : pas de sonnerie en retard', (t) async {
    addTearDown(m.reinitialiser);
    var alertes = 0;
    m.surAlerte = () => alertes++;
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    m.notificationsPretes = true;
    m.demarrer(60);
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    // L'appli dort dix minutes : la notification programmée a prévenu à 1:00.
    maintenant = maintenant.add(const Duration(minutes: 10));
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 300));
    expect(m.actif, isFalse);
    expect(alertes, 0, reason: 'le repos est fini depuis neuf minutes');

    // Revenu juste à la fin : là, l'appli prévient elle-même.
    m.demarrer(60);
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    maintenant = maintenant.add(const Duration(seconds: 61));
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 300));
    expect(m.actif, isFalse);
    expect(alertes, 1);
  });

  testWidgets('repos fini pendant que l\'appli est en arrière-plan : le repos noté ne dépasse pas sa durée', (t) async {
    addTearDown(m.reinitialiser);
    final repo = SessionRepo(Store.memory());
    await tourner(t, repo.load());
    await tourner(t, repo.startEmpty());
    await tourner(t, repo.addExerciseToActive('x'));
    final se = repo.active!.exercices.single;
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    m.demarrer(90, son: false, vibration: false, repo: repo, seId: se.id, setId: se.series.first.id);
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    maintenant = maintenant.add(const Duration(minutes: 12));
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 300));
    expect(repo.active!.exercices.single.series.first.tempsReposSec, 90);
  });

  testWidgets('deux repos lancés coup sur coup : le premier est noté, un seul battement tourne', (t) async {
    addTearDown(m.reinitialiser);
    final repo = SessionRepo(Store.memory());
    await tourner(t, repo.load());
    await tourner(t, repo.startEmpty());
    await tourner(t, repo.addExerciseToActive('x'));
    final se = repo.active!.exercices.single;
    var maintenant = DateTime(2026, 10, 2, 18);
    m.horloge = () => maintenant;
    var notifs = 0;
    void ecoute() => notifs++;
    m.addListener(ecoute);
    addTearDown(() => m.removeListener(ecoute));

    m.demarrer(120, son: false, vibration: false, repo: repo, seId: se.id, setId: se.series[0].id);
    maintenant = maintenant.add(const Duration(seconds: 20));
    m.demarrer(60, son: false, vibration: false, repo: repo, seId: se.id, setId: se.series[1].id);
    await t.pump();
    expect(m.total, 60);
    expect(m.restant, const Duration(seconds: 60));
    expect(repo.active!.exercices.single.series[0].tempsReposSec, 20);
    expect(repo.active!.exercices.single.series[1].tempsReposSec, isNull);

    // Un seul battement : quatre tops par seconde, pas huit.
    notifs = 0;
    await t.pump(const Duration(seconds: 1));
    expect(notifs, inInclusiveRange(3, 5));

    // « Arrêter » note le second et libère le battement.
    maintenant = maintenant.add(const Duration(seconds: 33));
    m.passer();
    await t.pump();
    expect(repo.active!.exercices.single.series[1].tempsReposSec, 33);
    notifs = 0;
    await t.pump(const Duration(seconds: 2));
    expect(notifs, 0, reason: 'plus aucun battement après l\'arrêt');
  });

  testWidgets('dévalider la série qui a lancé le repos l\'arrête ; celui d\'une autre série continue', (t) async {
    addTearDown(m.reinitialiser);
    m.demarrer(120, son: false, vibration: false, seId: 'e', setId: 'a');
    m.annulerPour('b');
    expect(m.actif, isTrue);
    m.annulerPour('a');
    expect(m.actif, isFalse);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('quitter l\'écran de séance et celui du repos ne laisse aucun battement inutile', (t) async {
    final d = await monter(t, depart: '/');
    await seanceFourchette(t, d);
    await ouvrirSeance(t);
    routeurDe(t).push(SeancePaths.repos);
    await attendre(t, tours: 2);
    await t.tap(find.text('Chronomètre'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Démarrer'));
    await t.pump(const Duration(milliseconds: 600));
    final ch = ChronoLibre.instance;
    expect(ch.enMarche, isTrue);
    expect(ch.bat, isTrue);

    // On referme le repos : le chronomètre court toujours, mais ne bat plus.
    await t.tap(find.bySemanticsLabel('Fermer'));
    await attendre(t, tours: 2);
    expect(ch.enMarche, isTrue);
    expect(ch.bat, isFalse, reason: 'aucun écran ne l\'affiche');
    expect(find.byType(SeancePage), findsOneWidget);

    // Séance abandonnée puis nouvelle séance : le chronomètre repart de zéro.
    await t.runAsync(() => d.sessions.discardActive());
    await attendre(t, tours: 2);
    await seanceLibre(t, d, [jamaisFait(d).id]);
    routeurDe(t).go('/seance/repos');
    await attendre(t, tours: 2);
    await t.tap(find.text('Chronomètre'));
    await t.pump(const Duration(milliseconds: 300));
    expect(ch.enMarche, isFalse);
    expect(find.text('00:00'), findsOneWidget);
    expect(t.takeException(), isNull);
    await demonter(t);
    // Rien ne doit rester programmé une fois l'appli démontée (le test échouerait sinon).
  });

  testWidgets('pause : chrono figé, « en pause », repos coupé, durée non comptée à la reprise', (t) async {
    final d = await monter(t, depart: '/');
    PauseSeance.instance.reinitialiser();
    await seanceFourchette(t, d);
    final t0 = DateTime.now().subtract(const Duration(minutes: 20));
    await t.runAsync(() => d.sessions.updateActive(d.sessions.active!.copyWith(debut: t0)));
    await ouvrirSeance(t);
    await t.tap(find.bySemanticsLabel('Valider la série').first);
    await attendre(t, tours: 2);
    expect(m.actif, isTrue);

    await toucherPlus(t);
    await attendre(t, tours: 2);
    await t.tap(find.text('Mettre la séance en pause'));
    await attendre(t, tours: 2);
    final p = PauseSeance.instance;
    expect(p.enPause(d.sessions.active), isTrue);
    expect(find.text('En pause'), findsOneWidget);
    expect(m.actif, isFalse, reason: 'le repos ne tourne pas pendant la pause');
    final fige = p.ecoule(d.sessions.active!);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await t.pump(const Duration(seconds: 2));
    expect(p.ecoule(d.sessions.active!), fige);

    await toucherPlus(t);
    await attendre(t, tours: 2);
    expect(find.text('Reprendre la séance'), findsOneWidget);
    await t.tap(find.text('Reprendre la séance'));
    await attendre(t, tours: 2);
    expect(p.enPause(d.sessions.active), isFalse);
    expect(find.text('Durée'), findsOneWidget);
    expect(d.sessions.active!.debut.isAfter(t0.add(const Duration(seconds: 1))), isTrue, reason: 'le début est décalé de la durée de la pause');
    final apres = p.ecoule(d.sessions.active!);
    expect((apres - fige).inMilliseconds.abs(), lessThan(1500), reason: 'la pause ne compte pas dans la durée');
    expect(seriesDe(d).first.fait, isTrue);
    expect(t.takeException(), isNull);
    await demonter(t);
  });

  testWidgets('appli fermée pendant une pause : au retour la séance est toujours en pause et ce temps ne compte pas', (t) async {
    final store = Store.memory();
    final repo = SessionRepo(store);
    await tourner(t, repo.load());
    await tourner(t, repo.startEmpty());
    final t0 = DateTime(2026, 10, 2, 18);
    await tourner(t, repo.updateActive(repo.active!.copyWith(debut: t0)));
    final p = PauseSeance.instance..reinitialiser();
    addTearDown(p.reinitialiser);

    p.mettreEnPause(repo.active!, maintenant: t0.add(const Duration(minutes: 30)), store: store);
    await t.pump();

    // L'appli est tuée : la mémoire est vide, un nouveau dépôt relit le disque.
    p.reinitialiser();
    final relu = SessionRepo(store);
    await tourner(t, relu.load());
    expect(p.enPause(relu.active), isFalse);
    await tourner(t, p.charger(relu));
    expect(p.enPause(relu.active), isTrue, reason: 'la pause est retrouvée sur disque');
    expect(p.ecoule(relu.active!, maintenant: t0.add(const Duration(hours: 3))), const Duration(minutes: 30));

    await tourner(t, p.reprendre(relu, maintenant: t0.add(const Duration(hours: 3))));
    expect(relu.active!.debut, t0.add(const Duration(hours: 2, minutes: 30)));
    expect(p.ecoule(relu.active!, maintenant: t0.add(const Duration(hours: 3, minutes: 5))), const Duration(minutes: 35));

    // La pause reprise n'est plus sur le disque.
    p.reinitialiser();
    await tourner(t, p.charger(relu));
    expect(p.enPause(relu.active), isFalse);
  });

  testWidgets('une pause laissée par une autre séance, ou une séance abandonnée, ne fige rien', (t) async {
    final store = Store.memory();
    final repo = SessionRepo(store);
    await tourner(t, repo.load());
    await tourner(t, repo.startEmpty());
    final p = PauseSeance.instance..reinitialiser();
    addTearDown(p.reinitialiser);
    p.mettreEnPause(repo.active!, store: store);
    await t.pump();

    // Abandon par un autre écran, qui ne connaît pas la pause, puis nouvelle séance.
    await tourner(t, repo.discardActive());
    await tourner(t, repo.startEmpty());
    expect(p.enPause(repo.active), isFalse);
    p.reinitialiser();
    await tourner(t, p.charger(repo));
    expect(p.enPause(repo.active), isFalse);
    expect(await tourner(t, store.readObject('seance_pause')), isNull, reason: 'le fichier périmé est effacé');

    // « Oublier » efface aussi le fichier.
    p.mettreEnPause(repo.active!, store: store);
    await t.pump();
    p.oublier();
    await t.pump();
    expect(await tourner(t, store.readObject('seance_pause')), isNull);
    expect(p.enPause(repo.active), isFalse);
  });

  test('repos après une série : zéro quand l\'exercice est « sans minuteur »', () {
    const se = SessionExercise(id: 'e', exerciseId: 'x', reposSec: 0);
    expect(reposApresSerie(se, const WorkoutSet(id: 's')), 0);
    expect(reposApresSerie(const SessionExercise(id: 'e', exerciseId: 'x', reposSec: -30), const WorkoutSet(id: 's')), 0);
    expect(reposApresSerie(const SessionExercise(id: 'e', exerciseId: 'x', reposSec: 45), const WorkoutSet(id: 's', type: SetType.echauffement)), 45);
  });
}
