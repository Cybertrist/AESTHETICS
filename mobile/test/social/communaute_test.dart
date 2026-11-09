import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/aujourdhui/pages/notifications_page.dart';
import 'package:aesthetic/features/aujourdhui/widgets/accueil.dart';
import 'package:aesthetic/features/profil/data/photo_profil.dart';
import 'package:aesthetic/features/profil/pages/profil_page.dart';
import 'package:aesthetic/features/profil/pages/reglages_page.dart';
import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:aesthetic/features/social/routes.dart';
import 'package:aesthetic/features/social/widgets/reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../aujourdhui/banc.dart' show donnees, polices;

/// La communauté en aperçu : chaque écran se dessine sans erreur, et les
/// gestes changent bien l'état en mémoire.
void main() {
  final cle = GlobalKey();

  Future<void> capture(WidgetTester t, String nom) async {
    if (!Platform.environment.containsKey('RENDU')) return;
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cle));
    final img = await t.runAsync(() => ro.toImage(pixelRatio: 1.5));
    final octets = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    (File('build/rendus/social/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
  }

  Future<(SocialRepo, GoRouter, AppData)> monter(WidgetTester t, String chemin, {Size taille = const Size(400, 1600), bool demo = false}) async {
    t.view.physicalSize = taille;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Les vraies polices : avec la police de test, plus large, tout déborderait.
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: demo)))!;
    final social = SocialRepo();
    final router = GoRouter(initialLocation: chemin, routes: [
      ...socialRoutes(),
      GoRoute(path: '/aujourdhui/notifications', builder: (context, state) => const NotificationsPage()),
      GoRoute(path: '/seance/resume/:id', builder: (context, state) => const Scaffold(body: Text('bilan de ma séance'))),
      GoRoute(path: '/profil', builder: (context, state) => const ProfilPage()),
      GoRoute(path: '/reglages', builder: (context, state) => const ReglagesPage()),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(RepaintBoundary(
      key: cle,
      child: MultiProvider(
        providers: [
          Provider<Store>.value(value: data.store),
          ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
          ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
          ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
          ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
          ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
          ChangeNotifierProvider<SocialRepo>.value(value: social),
        ],
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.dark(const Color(0xFFFF5A5F)), routerConfig: router),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await t.pump(const Duration(milliseconds: 300));
    }
    return (social, router, data);
  }

  group('le dépôt', () {
    test('demandes, bravos, invitations, coach', () {
      final r = SocialRepo();
      expect(r.enAttente, 2);
      r.accepter('tom');
      expect(r.estAmi('tom'), isTrue);
      expect(r.enAttente, 1);
      r.refuser('sarah');
      expect(r.enAttente, 0);
      expect(r.ami('sarah'), isNotNull, reason: 'refusée, elle reste une personne qu’on peut ajouter');
      final p = r.fil.first;
      final avant = r.bravos(p);
      r.basculerBravo(p.id);
      expect(r.bravos(p), avant + 1);
      r.basculerBravo(p.id);
      expect(r.bravos(p), avant);
      r.inviter('hugo');
      expect(r.demandeEnvoyee('hugo'), isTrue);
      expect(r.envoyees.single.id, 'hugo');
      r.annulerInvitation('hugo');
      expect(r.lien('hugo'), Lien.aucun);
      r.quitterCoach();
      expect(r.aUnCoach, isFalse);
    });

    test('chacun n’a qu’un lien, et les exemples couvrent les trois accès', () {
      final r = SocialRepo();
      final tous = {...r.amis, ...r.demandes, ...r.suggestions};
      expect(tous.length, r.amis.length + r.demandes.length + r.suggestions.length);
      for (final groupe in [r.amis, r.suggestions]) {
        expect({for (final a in groupe) a.acces}, AccesProfil.values.toSet(), reason: 'un ouvert, un réservé, un privé');
      }
      expect({for (final a in tous) a.pseudo}.length, tous.length, reason: 'pseudos uniques');
    });

    test('un profil se montre selon son accès et mon lien', () {
      final r = SocialRepo();
      expect(r.ouvert(r.ami('lea')!), isTrue);
      expect(r.ouvert(r.ami('malo')!), isTrue, reason: 'réservé aux amis, et j’en suis');
      expect(r.ouvert(r.ami('yann')!), isFalse, reason: 'privé, même pour un ami');
      expect(r.ouvert(r.ami('hugo')!), isTrue, reason: 'ouvert à tous');
      expect(r.ouvert(r.ami('clara')!), isFalse);
      expect(r.ouvert(r.ami('sarah')!), isFalse);
      r.accepter('sarah');
      expect(r.ouvert(r.ami('sarah')!), isTrue, reason: 'amie, son profil s’ouvre');
    });

    test('le fil : mes amis seulement, du plus récent au plus ancien', () {
      final r = SocialRepo(maintenant: DateTime(2026, 10, 10, 18));
      expect(r.fil.every((p) => r.estAmi(p.amiId)), isTrue);
      expect(r.fil.any((p) => p.amiId == 'hugo'), isFalse);
      for (var i = 1; i < r.fil.length; i++) {
        expect(r.fil[i].date.isAfter(r.fil[i - 1].date), isFalse);
      }
      final avant = r.fil.length;
      r.retirer('lea');
      expect(r.fil.any((p) => p.amiId == 'lea'), isFalse, reason: 'retirée, ses séances quittent le fil');
      expect(r.fil.length, lessThan(avant));
      expect(r.ami('lea'), isNotNull, reason: 'son profil reste lisible');
      r.accepter('tom');
      expect(r.fil.any((p) => p.amiId == 'tom'), isTrue);
    });

    test('chercher : amis compris, sans accents ni « @ »', () {
      final r = SocialRepo();
      expect(r.chercher(''), isEmpty);
      expect(r.chercher('cla').single.prenom, 'Clara');
      expect(r.chercher('lea').single.prenom, 'Léa');
      expect(r.chercher('@ines.fit').single.prenom, 'Inès');
      expect(r.chercher('zzz'), isEmpty);
      r.bloquer('clara');
      expect(r.chercher('cla'), isEmpty);
      expect(r.bloques.single.id, 'clara');
      r.debloquer('clara');
      expect(r.lien('clara'), Lien.aucun);
    });

    test('le calendrier d’un ami contient ses séances publiées', () {
      final n = DateTime(2026, 10, 10, 18);
      final r = SocialRepo(maintenant: n);
      expect(r.joursDe(r.ami('lea')!), contains(DateTime(2026, 10, 10)));
    });
  });

  group('le profil', () {
    test('les champs du profil public font l’aller-retour et gardent les anciens fichiers lisibles', () {
      final p = UserProfile(id: 'u', prenom: 'Tristan', creeLe: DateTime(2026, 1, 1));
      expect(p.acces, AccesProfil.amis);
      expect(p.montre, UserProfile.montreParDefaut);
      expect(p.toJson().containsKey('montre'), isFalse);
      final q = p.copyWith(pseudo: 'tristan.jcr', ville: 'Brest', salle: 'Basic-Fit', acces: AccesProfil.tous, montre: {});
      final r = UserProfile.fromJson(q.toJson());
      expect((r.pseudo, r.ville, r.salle, r.acces), ('tristan.jcr', 'Brest', 'Basic-Fit', AccesProfil.tous));
      expect(r.montre, isEmpty, reason: 'ne rien montrer est un choix, pas un oubli');
      // Une liste écrite avant les derniers réglages : ils restent montrés.
      final ancien = UserProfile.fromJson({...p.toJson(), 'montre': ['serie', 'badges']});
      expect(ancien.montre, {Visible.serie, Visible.badges, ...Visible.recents});
    });

    test('retirer la photo ou repasser par les questions ne perd ni la phrase ni le profil public', () {
      final p = UserProfile(id: 'u', prenom: 'Tristan', creeLe: DateTime(2026, 1, 1), photo: 'x.jpg', phrase: 'Un pas après l’autre.', pouces: true, pseudo: 'tj', acces: AccesProfil.tous);
      final sans = sansPhoto(p);
      expect(sans.photo, isNull);
      expect((sans.phrase, sans.pouces, sans.pseudo, sans.acces), (p.phrase, true, 'tj', AccesProfil.tous));
      final neuf = UserProfile(id: 'u', prenom: 'Tristan J.', creeLe: p.creeLe).gardant(p);
      expect((neuf.prenom, neuf.phrase, neuf.pouces, neuf.pseudo, neuf.acces), ('Tristan J.', p.phrase, true, 'tj', AccesProfil.tous));
    });
  });

  testWidgets('ajouter des amis : trois façons d’en trouver, ni suggestions ni demandes', (t) async {
    final (social, _, _) = await monter(t, SocialPaths.racine);
    expect(find.text('APERÇU'), findsOneWidget);
    for (final x in ['Chercher par nom', 'Partager mon lien', 'Trouver dans mes contacts']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    for (final x in ['Mes amis', 'Mon profil public']) {
      expect(find.text(x), findsNothing, reason: '$x est sur l’onglet Profil');
    }
    expect(find.text('Mon coach'), findsNothing, reason: 'le coach n’est pas dans les amis');
    expect(find.text('Accepter'), findsNothing, reason: 'les demandes sont dans les notifications');
    expect(find.text('Ajouter'), findsNothing, reason: 'les suggestions sont dans les contacts');
    expect(find.text('Suggestions d\'amis'), findsNothing);
    await capture(t, 'ajouter');
    // Les suggestions sont derrière « Trouver dans mes contacts ».
    await t.tap(find.text('Trouver dans mes contacts'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Personnes à ajouter'), findsOneWidget);
    await t.tap(find.text('Ajouter').first);
    await t.pump(const Duration(milliseconds: 300));
    expect(social.demandeEnvoyee(social.suggestions.first.id), isTrue);
    expect(find.text('Envoyée'), findsOneWidget);
    // Toucher « Envoyée » annule la demande, sans ouvrir le profil.
    await t.tap(find.text('Envoyée'));
    await t.pump(const Duration(milliseconds: 300));
    expect(social.envoyees, isEmpty);
    expect(find.text('Personnes à ajouter'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('onglet Profil : séances et amis en une ligne sous le nom ; modifier et voir mon profil dessous', (t) async {
    final (_, _, data) = await monter(t, '/profil', taille: const Size(400, 860), demo: true);
    final seances = data.sessions.sessions.where((s) => !s.enCours).length;
    expect(find.bySemanticsLabel('4 amis'), findsOneWidget);
    expect(find.bySemanticsLabel('$seances séances'), findsOneWidget);
    expect(find.text('Prendre du muscle'), findsNothing, reason: 'l’objectif n’est plus sur le profil');
    expect(find.textContaining('par semaine'), findsNothing);
    expect(find.text('Mon profil public'), findsOneWidget);
    await t.runAsync(() => data.profile.update((p) => p.copyWith(prenom: 'Tristan JONCOUR', phrase: 'La douleur est temporaire, mais la fierté dure toute une vie. We’re all gonna make it, brah.')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsNothing);
    await capture(t, 'onglet-profil');
    await t.tap(find.bySemanticsLabel('4 amis'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Amis'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('modifier mon profil : photo, prénom, pseudo, phrase, ville, salle ; rien sur ce que je montre', (t) async {
    final (_, _, data) = await monter(t, '/profil', taille: const Size(400, 1400));
    await t.tap(find.text('Modifier le profil'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (final x in ['Prénom', 'Pseudo', 'Ta phrase', 'Ville', 'Ma salle']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    for (final x in ['Qui voit mon profil', 'Mes charges', 'Instagram']) {
      expect(find.text(x), findsNothing, reason: x);
    }
    await capture(t, 'modifier-profil');
    await t.enterText(find.byType(TextField).at(1), 'Tristan JCR!');
    await t.enterText(find.byType(TextField).at(2), 'La régularité avant tout.');
    await t.enterText(find.byType(TextField).at(3), 'Brest');
    await t.enterText(find.byType(TextField).at(0), '');
    await t.pump(const Duration(milliseconds: 700));
    final p = data.profile.profile!;
    expect((p.pseudo, p.phrase, p.ville), ('tristanjcr', 'La régularité avant tout.', 'Brest'));
    expect(p.prenom, 'Tristan', reason: 'un prénom effacé ne s’enregistre pas');
    expect(t.takeException(), isNull);
  });

  testWidgets('réglages : mon profil, mon objectif, ce que je montre', (t) async {
    await monter(t, '/reglages', taille: const Size(400, 1100));
    expect(find.text('PROFIL'), findsOneWidget);
    for (final x in ['Modifier mon profil', 'Mon objectif', 'Ce que je montre']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await capture(t, 'reglages-appli');
    await t.tap(find.text('Ce que je montre'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Qui voit mon profil'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('les demandes d’amis sont dans la cloche de l’accueil', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(polices);
    final data = AppData(Store.memory());
    final social = SocialRepo();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: EnTeteAccueil(maintenant: DateTime(2026, 10, 7, 9)))))),
      GoRoute(path: '/aujourdhui/notifications', builder: (context, state) => const NotificationsPage()),
      ...socialRoutes(),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(RepaintBoundary(
      key: cle,
      child: MultiProvider(
        providers: [
          Provider<Store>.value(value: data.store),
          ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
          ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
          ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
          ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
          ChangeNotifierProvider<SocialRepo>.value(value: social),
        ],
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.dark(const Color(0xFFFF5A5F)), routerConfig: router),
      ),
    ));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.bySemanticsLabel('Notifications, du nouveau'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Accepter'), findsNWidgets(2));
    await capture(t, 'cloche');
    await t.tap(find.text('Accepter').first);
    await t.pump(const Duration(milliseconds: 300));
    expect(social.estAmi('tom'), isTrue);
    expect(find.text('Accepter'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('notifications : demandes, nouvelles des amis et mes records, rangés par date', (t) async {
    final (social, router, _) = await monter(t, '/aujourdhui/notifications', taille: const Size(400, 1500), demo: true);
    expect(find.text("Demandes d'amis"), findsOneWidget);
    expect(find.text('Accepter'), findsNWidgets(2));
    expect(find.textContaining('ont réagi à ta séance'), findsOneWidget);
    expect(find.textContaining('a commenté ta séance'), findsOneWidget);
    expect(find.textContaining('a battu un record'), findsWidgets);
    expect(t.takeException(), isNull);
    await capture(t, 'notifications');
    // Les filtres du haut ne gardent qu'un type de nouvelle.
    await t.tap(find.text('Commentaires'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('a commenté ta séance'), findsOneWidget);
    expect(find.textContaining('ont réagi à ta séance'), findsNothing);
    expect(find.text('Accepter'), findsNothing);
    await t.tap(find.text('Amis'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Accepter'), findsNWidgets(2));
    expect(find.textContaining('a accepté ta demande'), findsOneWidget);
    expect(find.textContaining('a battu un record'), findsNothing);
    await capture(t, 'notifications-amis');
    await t.tap(find.text('Toutes'));
    await t.pump(const Duration(milliseconds: 300));
    // Retirer un ami retire ses nouvelles.
    social.retirer('ines');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('a commenté ta séance'), findsNothing);
    // Un record d'ami ouvre sa séance et ses commentaires.
    await t.tap(find.textContaining('a battu un record').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(router.state.uri.path, startsWith('/communaute/seance/'));
    expect(t.takeException(), isNull);
  });

  testWidgets('notifications sans rien : un écran vide qui le dit', (t) async {
    final (social, _, _) = await monter(t, '/aujourdhui/notifications', taille: const Size(400, 800));
    for (final a in [...social.amis]) {
      social.retirer(a.id);
    }
    for (final a in [...social.demandes]) {
      social.refuser(a.id);
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Rien de nouveau'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, 'notifications-vide');
  });

  testWidgets('commenter une séance : mon commentaire s’ajoute, se compte et se retire', (t) async {
    final (social, _, _) = await monter(t, SocialPaths.publication('p1'), taille: const Size(400, 1300));
    expect(find.text('Les trois chiffres, enfin. Bravo.'), findsOneWidget);
    expect(find.text('Commentaires · 2'), findsOneWidget);
    await capture(t, 'commentaires');
    await t.enterText(find.byType(TextField), '  Bien joué !  ');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Envoyer le commentaire'));
    await t.pump(const Duration(milliseconds: 400));
    expect(social.nbCommentaires('p1'), 3);
    expect(find.text('Bien joué !'), findsOneWidget);
    expect(find.text('Commentaires · 3'), findsOneWidget);
    await t.tap(find.text('Supprimer'));
    await t.pump(const Duration(milliseconds: 300));
    expect(social.nbCommentaires('p1'), 2);
    // Un texte vide n'envoie rien.
    social.commenter('p1', '   ');
    expect(social.nbCommentaires('p1'), 2);
    // Les commentaires d'une personne bloquée disparaissent.
    social.bloquer('malo');
    expect(social.nbCommentaires('p1'), 1);
    expect(t.takeException(), isNull);
  });

  // Chaque profil d'exemple : ce qu'on y voit, ce qu'on n'y voit pas.
  for (final (id, vus, caches) in [
    ('lea', ['Meilleures barres', 'Badges', 'Dernières séances', 'Exercices fétiches', 'Volume'], ['Profil privé', 'Soulevé depuis le début']),
    ('malo', ['Meilleures barres', 'Malo ne montre pas ses charges.', 'Dernières séances'], ['Volume']),
    ('ines', ['Dernières séances', 'Exercices fétiches'], ['Badges', 'Meilleures barres', 'Volume']),
    ('yann', ['Profil privé', 'Ami'], ['Dernières séances', 'Badges', 'Reprise après blessure.']),
    ('hugo', ['Ajouter en ami', 'Meilleures barres', 'Dernières séances', 'Badges'], ['Profil réservé aux amis']),
    ('clara', ['Ajouter en ami', 'Profil réservé aux amis'], ['Dernières séances', 'Course le matin, salle le soir.']),
    ('nolan', ['Ajouter en ami', 'Profil privé'], ['Dernières séances']),
    ('tom', ['Accepter', 'Refuser', 'Dernières séances', 'Volume'], ['Meilleures barres']),
    ('sarah', ['Accepter', 'Profil réservé aux amis'], ['Dernières séances']),
  ]) {
    testWidgets('profil de $id : ce qu’il montre et ce qu’il garde', (t) async {
      await monter(t, SocialPaths.ami(id), taille: const Size(400, 3200));
      for (final x in vus) {
        expect(find.textContaining(x), findsWidgets, reason: 'attendu : $x');
      }
      for (final x in caches) {
        expect(find.textContaining(x), findsNothing, reason: 'caché : $x');
      }
      expect(t.takeException(), isNull);
      await capture(t, 'profil-$id');
    });
  }

  testWidgets('réagir à une séance : un appui donne un cœur, un appui long ouvre les cinq réactions', (t) async {
    final (social, _, _) = await monter(t, SocialPaths.ami('lea'), taille: const Size(400, 3200));
    final bouton = find.byType(BoutonReaction).first;
    expect(social.reaction('p1'), isNull);
    expect(find.descendant(of: bouton, matching: find.text('6')), findsOneWidget);
    // Un appui : le cœur, et le compteur monte.
    await t.tap(bouton);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    await capture(t, 'reaction-coeur');
    await t.pump(const Duration(milliseconds: 700));
    expect(social.reaction('p1'), Reaction.coeur);
    expect(find.descendant(of: bouton, matching: find.text('7')), findsOneWidget);
    // Un second appui la reprend.
    await t.tap(bouton);
    await t.pump(const Duration(milliseconds: 100));
    expect(social.reaction('p1'), isNull);
    // Un appui long : les cinq réactions, on en choisit une.
    await t.longPress(bouton);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (final r in Reaction.values) {
      expect(find.bySemanticsLabel(r.nom), findsOneWidget, reason: r.nom);
    }
    await capture(t, 'reaction-choix');
    await t.tap(find.bySemanticsLabel('En feu'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    expect(social.reaction('p1'), Reaction.feu);
    expect(find.bySemanticsLabel('Costaud'), findsNothing, reason: 'le choix se referme');
    expect(t.takeException(), isNull);
  });

  testWidgets('accepter une demande ouvre le profil réservé ; retirer un ami le referme sans l’effacer', (t) async {
    final (social, _, _) = await monter(t, SocialPaths.ami('sarah'), taille: const Size(400, 3200));
    await t.tap(find.text('Accepter'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Dernières séances'), findsOneWidget);
    expect(find.text('Ami'), findsOneWidget);
    await t.tap(find.text('Ami'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Retirer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(social.estAmi('sarah'), isFalse);
    expect(find.text('Ce profil n\'existe plus.'), findsNothing);
    expect(find.text('Ajouter en ami'), findsOneWidget);
    expect(find.text('Profil réservé aux amis'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('mon profil public : mes vraies données, vues par un ami puis par un inconnu', (t) async {
    final (_, _, data) = await monter(t, SocialPaths.monProfil, taille: const Size(400, 3400), demo: true);
    await t.runAsync(() => data.profile.update((p) => p.copyWith(pseudo: 'tristan.jcr', ville: 'Brest', salle: 'Basic-Fit Brest', phrase: 'La régularité avant tout.', montre: Visible.values.toSet())));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Tristan'), findsWidgets);
    expect(find.text('@tristan.jcr'), findsOneWidget);
    for (final x in ['Dernières séances', 'Badges', 'Meilleures barres', 'Exercices fétiches', 'Brest · Basic-Fit Brest']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await capture(t, 'moi-ami');
    // Réservé aux amis par défaut : un inconnu ne voit que la photo et le prénom.
    await t.tap(find.text('Vu par un inconnu'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Profil réservé aux amis'), findsOneWidget);
    expect(find.text('Dernières séances'), findsNothing);
    expect(find.text('La régularité avant tout.'), findsNothing);
    await capture(t, 'moi-inconnu');
    // Ouvert à tous, sans les charges : l'inconnu voit les séances, pas les kilos.
    await t.runAsync(() => data.profile.update((p) => p.copyWith(acces: AccesProfil.tous, montre: {Visible.seances, Visible.records})));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Dernières séances'), findsOneWidget);
    expect(find.text('Volume'), findsNothing);
    expect(find.text('Badges'), findsNothing);
    expect(find.text('Tristan ne montre pas ses charges.'), findsOneWidget);
    // Ni chiffres sous le nom, ni heures, ni objectif, ni niveau : rien n'est coché.
    for (final x in ['À la salle', 'Objectif', 'Niveau']) {
      expect(find.text(x), findsNothing, reason: x);
    }
    expect(find.textContaining('semaines d\'affilée'), findsNothing, reason: 'la série se lit sur le calendrier');
    expect(t.takeException(), isNull);
  });

  testWidgets('ce que je montre : les réglages s’enregistrent dans le profil', (t) async {
    final (_, _, data) = await monter(t, SocialPaths.confidentialite, taille: const Size(400, 2200));
    for (final x in ['Qui voit mon profil', 'Tout le monde', 'Mes amis', 'Personne', 'Mes charges', 'Ma ville et ma salle']) {
      expect(find.text(x), findsWidgets, reason: x);
    }
    expect(find.byType(TextField), findsNothing, reason: 'ce que j’écris sur mon profil est sur une autre page');
    await capture(t, 'reglages');
    await t.tap(find.text('Tout le monde'));
    await t.pump(const Duration(milliseconds: 300));
    expect(data.profile.profile!.acces, AccesProfil.tous);
    for (final x in ['Mon nombre de séances', 'Mon nombre d\'amis', 'Mes heures à la salle', 'Mon objectif', 'Mon niveau']) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await t.tap(find.byType(Switch).at(VisibleTexte.ordre.indexOf(Visible.charges)));
    await t.pump(const Duration(milliseconds: 300));
    expect(data.profile.profile!.montre, contains(Visible.charges));
    await t.tap(find.byType(Switch).at(VisibleTexte.ordre.indexOf(Visible.objectif)));
    await t.pump(const Duration(milliseconds: 300));
    expect(data.profile.profile!.montre, isNot(contains(Visible.objectif)));
    // Privé : les interrupteurs se grisent.
    await t.tap(find.text('Personne'));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    expect(t.takeException(), isNull);
  });

  for (final (nom, chemin, attendu) in [
    ('rechercher des amis', SocialPaths.ajouter, 'Rechercher des amis'),
    ('mes contacts', SocialPaths.contacts, 'Personnes à ajouter'),
    ('mes amis', SocialPaths.amis, 'Amis'),
    ('mon lien d’ami', SocialPaths.lien, 'Copier le lien'),
    ('mon coach', SocialPaths.coach, 'Ses programmes pour toi'),
    ('espace coach', SocialPaths.espaceCoach, 'Mes élèves'),
    ('un élève', SocialPaths.eleve('e3'), 'Son programme'),
  ]) {
    testWidgets('$nom : la page se dessine sans erreur ni débordement', (t) async {
      await monter(t, chemin);
      expect(find.text(attendu), findsWidgets);
      expect(t.takeException(), isNull);
      await capture(t, nom.replaceAll(' ', '-').replaceAll('’', '-'));
    });
  }

  for (final largeur in [320.0, 360.0]) {
    testWidgets('écran étroit ($largeur) : profils et réglages sans débordement', (t) async {
      for (final chemin in [SocialPaths.ami('lea'), SocialPaths.ami('clara'), SocialPaths.confidentialite, SocialPaths.modifierProfil, SocialPaths.monProfil, SocialPaths.amis, SocialPaths.contacts, '/profil']) {
        await monter(t, chemin, taille: Size(largeur, 3200));
        expect(t.takeException(), isNull, reason: chemin);
      }
    });
  }
}
