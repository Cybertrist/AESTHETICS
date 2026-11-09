import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:aesthetic/features/social/data/source_firestore.dart';
import 'package:aesthetic/features/social/data/synchro.dart';
import 'package:aesthetic/features/social/routes.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../aujourdhui/banc.dart' show donnees, polices;

/// Le parcours dans l'appli, vu par l'équipe de test : plusieurs personnes
/// sur une même base simulée, chacune avec sa source (et parfois sa
/// synchro et ses données de téléphone). On vérifie les notifications
/// calculées, les compteurs d'amis, `visiblePar` réécrit quand les amis
/// changent, ce qui part à la fin d'une séance selon ce que je montre, la
/// déconnexion, la communauté coupée et le mode démo.
void main() {
  const tout = {...UserProfile.montreParDefaut, Visible.charges, Visible.lieu};

  late FakeFirebaseFirestore base;
  final aFermer = <void Function()>[];

  setUp(() => base = FakeFirebaseFirestore());
  tearDown(() {
    for (final f in aFermer.reversed) {
      f();
    }
    aFermer.clear();
  });

  /// Les écoutes livrent leurs changements au tour suivant.
  Future<void> attendre() => pumpEventQueue(times: 40);

  Future<Map<String, dynamic>?> lire(String chemin) async => (await base.doc(chemin).get()).data();

  Ami profil(String prenom, String pseudo, {AccesProfil acces = AccesProfil.amis, Set<Visible> montre = tout, int amis = 0}) => Ami(
        id: 'moi',
        prenom: prenom,
        pseudo: pseudo,
        couleur: 0xFF2E7D4F,
        acces: acces,
        montre: montre,
        seances: 10,
        amis: amis,
      );

  /// Une personne connectée sur son téléphone, profil publié à la main.
  Future<(SocialRepo, SourceFirestore)> personne(String uid, String prenom, {AccesProfil acces = AccesProfil.amis, Set<Visible> montre = tout, Store? store}) async {
    final source = SourceFirestore(base, store: store);
    final repo = SocialRepo(source: source);
    aFermer.add(repo.dispose);
    source.changerCompte(uid);
    await source.publierProfil(MonProfilPublic(personne: profil(prenom, _pseudo(prenom), acces: acces, montre: montre)));
    await attendre();
    return (repo, source);
  }

  Publication seance(String id, {String titre = 'Jambes', double volume = 5000, int records = 0}) => Publication(
        id: id,
        amiId: 'moi',
        titre: titre,
        date: DateTime.now().subtract(const Duration(hours: 1)),
        duree: const Duration(minutes: 50),
        volumeKg: volume,
        series: 12,
        exercices: const ['squat'],
        records: records,
        seanceId: id,
      );

  /// Deux personnes deviennent amies : [de] demande, [vers] accepte.
  Future<void> amis(SocialRepo de, String idVers, SocialRepo vers, String idDe) async {
    await de.inviter(idVers);
    await attendre();
    await vers.accepter(idDe);
    await attendre();
  }

  /// Un téléphone avec ses données (séances d'exemple), sa source et sa
  /// synchro ; les envois sont appelés à la main.
  Future<(AppData, SourceFirestore, SocialRepo, SynchroSociale)> telephone(String uid, String prenom, {Set<Visible>? montre, AccesProfil acces = AccesProfil.amis}) async {
    final data = await donnees(demo: true);
    await data.profile.update((p) => p.copyWith(prenom: prenom, pseudo: _pseudo(prenom), montre: montre ?? tout, acces: acces));
    await data.settings.update((s) => s.copyWith(communaute: true));
    // La séance du jour de la démo, finie le soir, partirait à la connexion :
    // reculée de deux jours, seules les séances finies par le test partent.
    final n = DateTime.now();
    for (final s in [...data.sessions.sessions]) {
      if (!s.enCours && n.difference(s.fin ?? s.debut) < const Duration(hours: 30)) {
        await data.sessions.save(s.copyWith(debut: s.debut.subtract(const Duration(days: 2)), fin: s.fin?.subtract(const Duration(days: 2))));
      }
    }
    final source = SourceFirestore(base);
    final repo = SocialRepo(source: source);
    final synchro = SynchroSociale(data, source, delai: const Duration(hours: 1));
    aFermer.add(() {
      synchro.dispose();
      repo.dispose();
    });
    synchro.uid = uid;
    await attendre();
    await synchro.publier();
    await attendre();
    return (data, source, repo, synchro);
  }

  /// Une séance d'exemple qui vient de finir.
  Future<WorkoutSession> finirSeance(AppData data, {String? sauf}) async {
    // Une séance avec des charges, pour que le volume compte.
    final s = data.sessions.sessions.firstWhere((s) => !s.enCours && s.volume > 0 && s.id != sauf);
    final n = DateTime.now();
    await data.sessions.save(s.copyWith(debut: n.subtract(const Duration(minutes: 70)), fin: n.subtract(Duration(minutes: sauf == null ? 5 : 3))));
    await attendre();
    return s;
  }

  // ------------------------------------------------------------ notifications

  test('« a accepté ta demande » ne vaut que pour la demande que j’ai envoyée, pas pour une ancienne refusée', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');

    // Bob demande Alice, qui refuse.
    await rb.inviter('alice');
    await attendre();
    await ra.refuser('bob');
    await attendre();
    expect(rb.lien('alice'), Lien.aucun);
    expect(rb.activites(), isEmpty);

    // Plus tard, c'est Alice qui demande, et Bob accepte : c'est Bob qui a
    // accepté, il ne doit pas lire « Alice a accepté ta demande ».
    await amis(ra, 'bob', rb, 'alice');
    expect(rb.estAmi('alice'), isTrue);
    expect(ra.activites().where((a) => a.type == TypeActivite.accepte).single.amis, ['bob'], reason: 'Alice, elle, a bien vu sa demande acceptée');
    expect(rb.activites().where((a) => a.type == TypeActivite.accepte), isEmpty, reason: 'Bob a accepté lui-même : pas de « a accepté ta demande »');
  });

  test('« a accepté ta demande » ne revient pas quand on redevient amis à l’initiative de l’autre', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    await amis(rb, 'alice', ra, 'bob');
    expect(rb.activites().where((a) => a.type == TypeActivite.accepte).single.amis, ['alice']);
    // Alice retire Bob, puis lui redemande ; Bob accepte.
    await ra.retirer('bob');
    await attendre();
    await amis(ra, 'bob', rb, 'alice');
    expect(rb.activites().where((a) => a.type == TypeActivite.accepte), isEmpty, reason: 'la nouvelle amitié vient de la demande d’Alice, acceptée par Bob');
  });

  test('« a accepté ta demande » survit au redémarrage de l’appli (fichier social_demandes)', () async {
    final store = Store.memory();
    await personne('alice', 'Alice');
    await personne('chloe', 'Chloé');
    final (rb, bob) = await personne('bob', 'Bob', store: store);
    final ra = SocialRepo(source: SourceFirestore(base)..changerCompte('alice'));
    aFermer.add(ra.dispose);
    final rc = SocialRepo(source: SourceFirestore(base)..changerCompte('chloe'));
    aFermer.add(rc.dispose);
    await attendre();
    await rb.inviter('alice');
    await rb.inviter('chloe');
    await attendre();
    await ra.accepter('bob');
    await attendre();
    expect(rb.activites().where((a) => a.type == TypeActivite.accepte).single.amis, ['alice']);

    // Bob relance l'appli deux fois : la demande acceptée par Alice reste
    // une nouvelle, même si l'écoute des demandes répond avant le fichier.
    for (var i = 0; i < 2; i++) {
      final relance = SocialRepo(source: SourceFirestore(base, store: store));
      aFermer.add(relance.dispose);
      (relance.source as SourceFirestore).changerCompte('bob');
      await attendre();
      expect(relance.activites().where((a) => a.type == TypeActivite.accepte).map((a) => a.amis.single), ['alice'], reason: 'relance ${i + 1}');
      relance.dispose();
      aFermer.remove(relance.dispose);
    }
    expect(bob.moi, 'bob');
  });

  test('notifications : réactions groupées, commentaires, records d’amis ; rien de moi-même ni d’une personne bloquée', () async {
    final (ra, alice) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    final (rc, chloe) = await personne('chloe', 'Chloé');
    await amis(rb, 'alice', ra, 'bob');
    await amis(rc, 'alice', ra, 'chloe');

    await alice.publierSeance(seance('a1'));
    await chloe.publierSeance(seance('c1', records: 2));
    await attendre();
    // Je réagis à ma propre séance et la commente : pas de notification.
    await ra.reagir('alice_a1', Reaction.feu);
    await ra.commenter('alice_a1', 'Pas mal moi');
    await rb.reagir('alice_a1', Reaction.coeur);
    await rc.reagir('alice_a1', Reaction.bravo);
    await rc.commenter('alice_a1', 'Bravo !');
    await rb.commenter('alice_a1', 'Costaud');
    await attendre();
    final notes = ra.activites();
    expect(notes.where((a) => a.type == TypeActivite.reaction).single.amis.toSet(), {'bob', 'chloe'});
    expect(notes.where((a) => a.type == TypeActivite.commentaire).map((a) => a.amis.single).toSet(), {'bob', 'chloe'});
    expect(notes.where((a) => a.type == TypeActivite.record).single.publicationId, 'chloe_c1');
    expect(ra.bravos(ra.publication('alice_a1')!), 3, reason: 'ma réaction comptée parmi les bravos');

    // Alice bloque Chloé : ses réactions, commentaires et records ne
    // remontent plus.
    await ra.bloquer('chloe');
    await attendre();
    final apres = ra.activites();
    expect(apres.expand((a) => a.amis), isNot(contains('chloe')));
    // La réaction de Bob reste : seule celle de Chloé doit partir de la
    // ligne groupée, pas la ligne entière.
    expect(apres.where((a) => a.type == TypeActivite.reaction).single.amis, ['bob']);
    expect(ra.commentairesDe('alice_a1').map((c) => c.amiId).toSet(), {null, 'bob'});
  });

  // ------------------------------------------------------------ compteurs

  test('compteurs d’amis : le nombre publié suit les amis gagnés, retirés, bloqués', () async {
    final (alice, _, ra, sa) = await telephone('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    final (rc, _) = await personne('chloe', 'Chloé');
    expect((await lire('profils/alice/details/public'))!['nbAmis'], 0);

    await amis(rb, 'alice', ra, 'bob');
    await amis(rc, 'alice', ra, 'chloe');
    expect(ra.amis.length, 2);
    await sa.publier();
    await attendre();
    expect((await lire('profils/alice/details/public'))!['nbAmis'], 2);
    // Bob, relançant l'appli, ouvre le profil d'Alice : il y lit deux amis.
    // (Sans relance, le profil n'est relu qu'une fois par minute.)
    final relu = SocialRepo(source: SourceFirestore(base)..changerCompte('bob'));
    aFermer.add(relu.dispose);
    await attendre();
    relu.voir('alice');
    await attendre();
    expect(relu.ami('alice')!.amis, 2);

    await rb.retirer('alice');
    await attendre();
    expect(ra.amis.length, 1, reason: 'retiré par l’autre, je le vois aussi');
    await sa.publier();
    await attendre();
    expect((await lire('profils/alice/details/public'))!['nbAmis'], 1);
    await ra.bloquer('chloe');
    await attendre();
    await sa.publier();
    await attendre();
    expect((await lire('profils/alice/details/public'))!['nbAmis'], 0);
    expect(alice.profile.profile!.pseudo, 'alice');
  });

  // ------------------------------------------------------- visiblePar réécrit

  test('visiblePar suit mes amis : nouvel ami ajouté, séances cachées puis remontrées', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, bob) = await personne('bob', 'Bob');
    final (rc, _) = await personne('chloe', 'Chloé');
    await amis(rb, 'alice', ra, 'bob');
    await bob.publierSeance(seance('s1'));
    await attendre();
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List).toSet(), {'bob', 'alice'});
    expect(rc.fil, isEmpty);

    // Chloé devient amie de Bob après coup : la séance d'hier lui arrive.
    await amis(rc, 'bob', rb, 'chloe');
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List).toSet(), {'bob', 'alice', 'chloe'});
    expect(rc.fil.map((p) => p.id), ['bob_s1']);

    // Bob cache ses séances : elles ne sont plus visibles que de lui.
    await bob.publierProfil(MonProfilPublic(personne: profil('Bob', 'bob', montre: {Visible.serie})));
    await attendre();
    expect((await lire('publications/bob_s1'))!['visiblePar'], ['bob']);
    expect(ra.fil, isEmpty);
    expect(rc.fil, isEmpty);
    // Il les remontre : ses amis les retrouvent.
    await bob.publierProfil(MonProfilPublic(personne: profil('Bob', 'bob')));
    await attendre();
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List).toSet(), {'bob', 'alice', 'chloe'});
    expect(ra.fil.map((p) => p.id), ['bob_s1']);
    // Une personne bloquée par Bob perd la séance, l'autre la garde.
    await rb.bloquer('alice');
    await attendre();
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List).toSet(), {'bob', 'chloe'});
    expect(ra.source.publications, isEmpty);
  });

  // --------------------------------------- publication à la fin d'une séance

  test('fin de séance : publiée avec ou sans volume selon les charges, rien si séances cachées ou profil privé', () async {
    final (rl, _) = await personne('lea', 'Léa');

    // Bob montre ses séances mais cache ses charges.
    final (db, sb, rb, synB) = await telephone('bob', 'Bob', montre: {Visible.seances, Visible.serie});
    await amis(rl, 'bob', rb, 'lea');
    final s1 = await finirSeance(db);
    await synB.publier();
    await attendre();
    final pub = await lire('publications/bob_${s1.id}');
    expect(pub, isNotNull, reason: 'la séance qui vient de finir part');
    expect(pub!.containsKey('volumeKg'), isFalse, reason: 'charges cachées : pas de volume');
    expect((pub['visiblePar'] as List).toSet(), {'bob', 'lea'});
    expect(rl.fil.single.volumeKg, 0);
    expect(sb.seancesPubliees, contains(s1.id));
    // Il montre ses charges : la séance suivante part avec son volume.
    await db.profile.update((p) => p.copyWith(montre: tout));
    final s2 = await finirSeance(db, sauf: s1.id);
    await synB.publier();
    await attendre();
    expect((await lire('publications/bob_${s2.id}'))!['volumeKg'], greaterThan(0));

    // Chloé cache ses séances : rien ne part.
    final (dc, _, _, synC) = await telephone('chloe', 'Chloé', montre: {Visible.serie, Visible.charges});
    final c1 = await finirSeance(dc);
    await synC.publier();
    await attendre();
    expect(await lire('publications/chloe_${c1.id}'), isNull);
    expect(await lire('profils/chloe'), isNotNull, reason: 'sa carte part quand même');

    // David est privé : rien ne part.
    final (dd, _, _, synD) = await telephone('david', 'David', acces: AccesProfil.personne);
    final d1 = await finirSeance(dd);
    await synD.publier();
    await attendre();
    expect(await lire('publications/david_${d1.id}'), isNull);
    expect((await lire('profils/david'))!['acces'], 'prive');
  });

  // ---------------------------------------------------------- déconnexion

  test('se déconnecter coupe les écoutes : plus rien n’arrive, plus rien ne part ; un autre compte ne voit rien de l’ancien', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (da, sa, rmoi, syn) = await telephone('moi', 'Tristan');
    await amis(ra, 'moi', rmoi, 'alice');
    expect(rmoi.amis.single.id, 'alice');

    var nouvelles = 0;
    void compter() => nouvelles++;
    sa.addListener(compter);
    addTearDown(() => sa.removeListener(compter));
    syn.uid = null;
    expect(sa.moi, isNull);
    expect(rmoi.aConnecter, isTrue);
    nouvelles = 0;

    // Alice publie et me demande des choses : je n'en entends rien.
    final (_, alice) = (ra, ra.source as SourceFirestore);
    await alice.publierSeance(seance('a9'));
    await attendre();
    expect(nouvelles, 0, reason: 'plus aucune écoute ne prévient le dépôt');
    expect(rmoi.fil, isEmpty);
    expect(rmoi.amis, isEmpty);

    // Une séance finie hors connexion ne part pas.
    final s = await finirSeance(da);
    await syn.publier();
    await attendre();
    expect(await lire('publications/moi_${s.id}'), isNull);

    // Un autre compte sur le même téléphone : rien de l'ancien.
    await personne('zoe', 'Zoé');
    sa.changerCompte('zoe');
    await attendre();
    expect(rmoi.amis, isEmpty);
    expect(rmoi.fil, isEmpty);
    expect(rmoi.activites(), isEmpty);
    expect(sa.seancesPubliees, isEmpty);
  });

  // ------------------------------------------------------- communauté coupée

  test('communauté coupée dans les Réglages : rien n’écoute, rien ne part, et tout revient en la rallumant', () async {
    final (rl, _) = await personne('lea', 'Léa');
    final (db, sb, rb, syn) = await telephone('bob', 'Bob');
    await amis(rl, 'bob', rb, 'lea');
    await db.settings.update((s) => s.copyWith(communaute: false));
    expect(sb.moi, isNull);
    final s1 = await finirSeance(db);
    await syn.publier();
    await attendre();
    expect(await lire('publications/bob_${s1.id}'), isNull, reason: 'coupée : la séance ne part pas');
    // Mon profil n'est pas republié non plus.
    final avant = await lire('profils/bob');
    await db.profile.update((p) => p.copyWith(prenom: 'Robert'));
    await syn.publier();
    await attendre();
    expect((await lire('profils/bob'))!['prenom'], avant!['prenom']);

    // Rallumée : la séance récente part, et mes amis sont là.
    await db.settings.update((s) => s.copyWith(communaute: true));
    await attendre();
    await syn.publier();
    await attendre();
    await syn.publier();
    await attendre();
    expect(rb.amis.single.id, 'lea');
    expect((await lire('profils/bob'))!['prenom'], 'Robert');
    expect(await lire('publications/bob_${s1.id}'), isNotNull);
    expect(rl.fil.single.seanceId, s1.id);
  });

  // ------------------------------------------------------------- mode démo

  test('mode démo intact : les personnes d’exemple, sans compte ni serveur', () async {
    final repo = SocialRepo();
    addTearDown(repo.dispose);
    expect(repo.apercu, isTrue);
    expect(repo.aConnecter, isFalse, reason: 'la démo ne demande pas de se connecter');
    expect(repo.amis, isNotEmpty);
    expect(repo.fil, isNotEmpty);
    expect(repo.chercher('a'), isNotEmpty);
    final id = repo.amis.first.id;
    await repo.retirer(id);
    expect(repo.estAmi(id), isFalse);
    expect((await base.collection('profils').get()).docs, isEmpty, reason: 'rien ne touche une base');
  });

  // ---------------------------------------------------------------- écrans

  testWidgets('mon lien d’ami : avec un pseudo pris par un autre, le code ne doit pas mener chez lui', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: false)))!;
    // Alice a le pseudo « alice » ; sur mon téléphone, j'ai tapé le même.
    await t.runAsync(() async {
      final alice = SourceFirestore(base)..changerCompte('alice');
      await alice.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice')));
      alice.dispose();
      await data.profile.update((p) => p.copyWith(pseudo: 'alice'));
    });
    final source = SourceFirestore(base)..changerCompte('moi');
    final social = SocialRepo(source: source);
    addTearDown(social.dispose);
    await t.runAsync(() => source.publierProfil(MonProfilPublic(personne: profil('Tristan', 'alice'))));
    expect(social.etatPseudo, EtatPseudo.pris);

    final router = GoRouter(initialLocation: SocialPaths.lien, routes: [...socialRoutes()]);
    addTearDown(router.dispose);
    await t.pumpWidget(MultiProvider(
      providers: [
        Provider<Store>.value(value: data.store),
        ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
        ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
        ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
        ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
        ChangeNotifierProvider<SocialRepo?>.value(value: social),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(const Color(0xFFFF5A5F)), routerConfig: router),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('déjà pris'), findsOneWidget);
    final qr = t.widgetList<QrImageView>(find.byType(QrImageView));
    // Celui qui scanne ce code enverrait sa demande à Alice, pas à moi.
    expect(qr, isEmpty, reason: 'le code QR porte « ${SocialRepo.lienAmi('alice')} », le pseudo d’Alice');
  });
}

/// Le pseudo tiré du prénom, sans accents (les règles n'en veulent pas).
String _pseudo(String prenom) => prenom.toLowerCase().replaceAll('é', 'e').replaceAll('ï', 'i');
