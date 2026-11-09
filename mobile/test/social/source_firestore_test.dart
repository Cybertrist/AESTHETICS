import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/profil/data/grades.dart';
import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:aesthetic/features/social/data/source_firestore.dart';
import 'package:aesthetic/features/social/routes.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../aujourdhui/banc.dart' show donnees, polices;

/// La vraie communauté, sur une base Firestore simulée que partagent
/// plusieurs personnes : chacune a sa source et son dépôt, comme sur son
/// téléphone. Les règles du serveur sont testées à part (serveur/tests) ;
/// ici, on vérifie ce que l'appli écrit, ce qu'elle lit, et que chacun ne
/// voit que ce qu'il doit.
void main() {
  const tout = {...UserProfile.montreParDefaut, Visible.charges, Visible.lieu};

  late FakeFirebaseFirestore base;
  final ouvertes = <SocialRepo>[];

  setUp(() => base = FakeFirebaseFirestore());
  tearDown(() {
    for (final r in ouvertes) {
      r.dispose();
    }
    ouvertes.clear();
  });

  /// Les écoutes livrent leurs changements au tour suivant.
  Future<void> attendre() => pumpEventQueue(times: 40);

  Ami profil(String prenom, String pseudo, {AccesProfil acces = AccesProfil.amis, Set<Visible> montre = tout}) => Ami(
        id: 'moi',
        prenom: prenom,
        pseudo: pseudo,
        couleur: 0xFF2E7D4F,
        phrase: 'Un pas après l’autre.',
        ville: 'Brest',
        salle: 'Basic-Fit Kergaradec',
        depuis: 2022,
        acces: acces,
        montre: montre,
        serieSemaines: 6,
        seances: 48,
        heures: 52,
        objectif: 'Gagner en force',
        niveau: 'Intermédiaire',
        records: const [RecordAmi('squat', 120, 3)],
        badges: const {Grade.serie: 6},
        fetiches: const ['squat', 'developpe-couche'],
        amis: 2,
      );

  /// Une personne connectée sur son téléphone, profil publié.
  Future<(SocialRepo, SourceFirestore)> personne(String uid, String prenom, {String? pseudo, AccesProfil acces = AccesProfil.amis, Set<Visible> montre = tout}) async {
    final source = SourceFirestore(base);
    final repo = SocialRepo(source: source);
    ouvertes.add(repo);
    source.changerCompte(uid);
    final jours = {for (var i = 0; i < 10; i++) DateTime.now().subtract(Duration(days: i * 2))};
    await source.publierProfil(MonProfilPublic(personne: profil(prenom, pseudo ?? prenom.toLowerCase(), acces: acces, montre: montre), jours: jours));
    await attendre();
    return (repo, source);
  }

  Publication seance(String id, {String titre = 'Jambes', double volume = 8420, int records = 0}) => Publication(
        id: id,
        amiId: 'moi',
        titre: titre,
        date: DateTime.now().subtract(const Duration(hours: 1)),
        duree: const Duration(minutes: 64),
        volumeKg: volume,
        series: 18,
        exercices: const ['squat', 'presse-a-cuisses', 'leg-extension', 'leg-curl', 'mollets', 'gainage', 'crunch'],
        records: records,
        seanceId: id,
      );

  Future<Map<String, dynamic>?> lire(String chemin) async => (await base.doc(chemin).get()).data();

  test('le profil publié : la carte, le pseudo réservé, les détails selon ce que je montre', () async {
    final (_, alice) = await personne('alice', 'Alice', pseudo: 'alice.b');
    expect(alice.etatPseudo, EtatPseudo.ok);
    expect(await lire('pseudos/alice.b'), {'uid': 'alice'});
    final carte = (await lire('profils/alice'))!;
    expect(carte.keys.toSet(), {'pseudo', 'pseudoMin', 'prenom', 'couleur', 'acces', 'majLe'});
    expect((carte['pseudoMin'], carte['acces']), ('alice.b', 'amis'));
    final details = (await lire('profils/alice/details/public'))!;
    expect(details['ville'], 'Brest');
    expect((details['jours'] as List).length, 7, reason: 'les règles en gardent sept');

    // Le pseudo d'un autre est refusé ; un pseudo trop court aussi.
    final (_, bob) = await personne('bob', 'Bob', pseudo: 'alice.b');
    expect(bob.etatPseudo, EtatPseudo.pris);
    expect(await lire('profils/bob'), isNull, reason: 'pas de carte sans pseudo à soi');
    await bob.publierProfil(MonProfilPublic(personne: profil('Bob', 'b')));
    expect(bob.etatPseudo, EtatPseudo.invalide);
    expect(await bob.pseudoLibre('alice.b'), isFalse);
    expect(await bob.pseudoLibre('bob.m'), isTrue);

    // Changer de pseudo rend l'ancien.
    await alice.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice.bzh')));
    expect(await lire('pseudos/alice.b'), isNull);
    expect(await lire('pseudos/alice.bzh'), {'uid': 'alice'});

    // Ce qui est caché ne part pas ; un profil privé n'envoie presque rien.
    final (_, chloe) = await personne('chloe', 'Chloé', pseudo: 'chloe', montre: {Visible.seances, Visible.serie});
    final dChloe = (await lire('profils/chloe/details/public'))!;
    for (final cache in ['ville', 'salle', 'records', 'badges', 'seances', 'heures', 'objectif', 'niveau', 'nbAmis']) {
      expect(dChloe.containsKey(cache), isFalse, reason: cache);
    }
    expect(dChloe['montre'], ['seances', 'serie']);
    expect(chloe.etatPseudo, EtatPseudo.ok);
    await personne('david', 'David', acces: AccesProfil.personne);
    expect((await lire('profils/david/details/public'))!.keys.toSet(), {'montre', 'majLe'});
    expect((await lire('profils/david'))!['acces'], 'prive');
  });

  test('six personnes : demandes, amitiés, fil, réactions, commentaires, notifications, retrait, blocage', () async {
    final (ra, alice) = await personne('alice', 'Alice');
    final (rb, bob) = await personne('bob', 'Bob');
    final (rc, chloe) = await personne('chloe', 'Chloé', pseudo: 'chloe');
    final (rd, _) = await personne('david', 'David', acces: AccesProfil.tous);
    final (re, _) = await personne('emma', 'Emma');
    final (rf, _) = await personne('farid', 'Farid');

    // La recherche par pseudo : préfixe, sans moi.
    rb.chercher('ali');
    await attendre();
    expect(rb.chercher('ali').map((a) => a.id), ['alice']);
    rb.chercher('bo');
    await attendre();
    expect(rb.chercher('bo'), isEmpty, reason: 'on ne se trouve pas soi-même');

    // Bob demande Alice : elle le voit, personne d'autre.
    await rb.inviter('alice');
    await attendre();
    expect(rb.lien('alice'), Lien.demandeEnvoyee);
    expect(rb.envoyees.single.prenom, 'Alice');
    expect(ra.demandes.single.id, 'bob');
    expect(ra.enAttente, 1);
    expect(rc.lien('bob'), Lien.aucun);
    expect(rc.demandes, isEmpty);
    expect(await lire('demandes/bob_alice'), containsPair('vers', 'alice'));

    // Alice accepte : les deux sens, la demande effacée, en un lot.
    await ra.accepter('bob');
    await attendre();
    expect(await lire('demandes/bob_alice'), isNull);
    expect(await lire('amis/alice/liste/bob'), isNotNull);
    expect(await lire('amis/bob/liste/alice'), isNotNull);
    expect(ra.estAmi('bob'), isTrue);
    expect(rb.estAmi('alice'), isTrue);
    expect(ra.enAttente, 0);
    expect(rc.estAmi('bob'), isFalse);
    // Bob est prévenu que sa demande est acceptée ; Alice, qui a accepté, non.
    expect(rb.activites().where((a) => a.type == TypeActivite.accepte).single.amis, ['alice']);
    expect(ra.activites().where((a) => a.type == TypeActivite.accepte), isEmpty);

    // Chloé ajoute Bob par son pseudo (code QR) : la demande part.
    expect(await rc.ajouterParPseudo('@Bob'), 'bob');
    await attendre();
    expect(rb.demandes.single.id, 'chloe');
    // Bob l'invite aussi : c'est accepter la sienne.
    await rb.inviter('chloe');
    await attendre();
    expect(rb.estAmi('chloe'), isTrue);
    expect(rc.estAmi('bob'), isTrue);

    // Bob termine une séance : elle part dans le fil de ses amis seulement.
    await bob.publierSeance(seance('s1', records: 1));
    await attendre();
    final doc = (await lire('publications/bob_s1'))!;
    expect((doc['visiblePar'] as List).toSet(), {'bob', 'alice', 'chloe'});
    expect((doc['exercices'] as List).length, 6, reason: 'six exercices au plus');
    expect(doc['volumeKg'], 8420);
    expect(ra.fil.single.titre, 'Jambes');
    expect(rc.fil.single.id, 'bob_s1');
    for (final r in [rd, re, rf]) {
      expect(r.fil, isEmpty);
    }
    expect(rb.fil, isEmpty, reason: 'mes séances ne sont pas dans mon fil');
    expect(rb.source.publications, isEmpty);
    expect(bob.seancesPubliees, {'s1'});
    // Publier deux fois la même séance ne la double pas.
    await bob.publierSeance(seance('s1', records: 1));
    await attendre();
    expect((await base.collection('publications').get()).docs.length, 1);
    // Le record de Bob arrive dans les nouvelles de ses amis.
    expect(ra.activites().where((a) => a.type == TypeActivite.record).single.publicationId, 'bob_s1');

    // Alice réagit, Chloé aussi ; Alice commente.
    await ra.reagir('bob_s1', Reaction.feu);
    await rc.reagir('bob_s1', Reaction.coeur);
    await ra.commenter('bob_s1', '  Belle séance !  ');
    await attendre();
    expect(ra.reaction('bob_s1'), Reaction.feu);
    expect(rb.reaction('bob_s1'), isNull);
    expect(rb.bravos(rb.publication('bob_s1')!), 2);
    expect(ra.commentairesDe('bob_s1').single.texte, 'Belle séance !');
    expect(ra.commentairesDe('bob_s1').single.mien, isTrue);
    expect(rb.commentairesDe('bob_s1').single.amiId, 'alice');
    expect(rc.nbCommentaires('bob_s1'), 1);
    // Les notifications de Bob : une ligne de réactions (la plus récente
    // d'abord), une ligne par commentaire, rattachées à sa séance.
    final notes = rb.activites();
    final reactions = notes.singleWhere((a) => a.type == TypeActivite.reaction);
    expect(reactions.amis.toSet(), {'alice', 'chloe'});
    expect(reactions.seanceId, 's1');
    final commentaire = notes.singleWhere((a) => a.type == TypeActivite.commentaire);
    expect(commentaire.amis, ['alice']);
    expect((commentaire.texte, commentaire.seanceId), ('Belle séance !', 's1'));
    // Reprendre sa réaction l'efface.
    await rc.reagir('bob_s1', null);
    await attendre();
    expect(rb.bravos(rb.publication('bob_s1')!), 1);
    // Bob retire le commentaire d'Alice sous sa séance.
    await rb.retirerCommentaire(rb.commentairesDe('bob_s1').single.id);
    await attendre();
    expect(ra.commentairesDe('bob_s1'), isEmpty);

    // Alice retire Bob : la séance de Bob quitte son fil (visiblePar réécrit).
    await ra.retirer('bob');
    await attendre();
    expect(rb.estAmi('alice'), isFalse);
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List).toSet(), {'bob', 'chloe'});
    expect(ra.fil, isEmpty);
    expect(ra.source.publications, isEmpty);
    expect(rc.fil.single.id, 'bob_s1');

    // Chloé bloque Bob : l'amitié et les demandes partent, Bob n'est prévenu
    // de rien et sa séance quitte le fil de Chloé.
    await rc.bloquer('bob');
    await attendre();
    expect(rc.lien('bob'), Lien.bloque);
    expect(rc.bloques.single.id, 'bob');
    expect(rb.lien('chloe'), Lien.aucun);
    expect(await lire('amis/bob/liste/chloe'), isNull);
    expect(await lire('blocages/chloe/liste/bob'), isNotNull);
    expect(((await lire('publications/bob_s1'))!['visiblePar'] as List), ['bob']);
    expect(rc.fil, isEmpty);
    rc.chercher('bo');
    await attendre();
    expect(rc.chercher('bob'), isEmpty, reason: 'une personne bloquée ne sort plus dans la recherche');
    await rc.debloquer('bob');
    await attendre();
    expect(rc.lien('bob'), Lien.aucun);

    // Annuler et refuser.
    await rd.inviter('emma');
    await attendre();
    expect(re.demandes.single.id, 'david');
    await rd.annulerInvitation('emma');
    await attendre();
    expect(re.demandes, isEmpty);
    await rf.inviter('emma');
    await attendre();
    await re.refuser('farid');
    await attendre();
    expect(rf.lien('emma'), Lien.aucun);
    expect(re.lien('farid'), Lien.aucun);
    expect((await base.collection('demandes').get()).docs, isEmpty);
  });

  test('ce que je cache ne part pas : séances, charges, profil privé', () async {
    final (ra, alice) = await personne('alice', 'Alice');
    final (rb, bob) = await personne('bob', 'Bob', montre: {Visible.seances});
    final (rc, chloe) = await personne('chloe', 'Chloé', pseudo: 'chloe', acces: AccesProfil.personne);
    final (rd, david) = await personne('david', 'David', montre: {Visible.serie});
    for (final r in [rb, rc, rd]) {
      await r.inviter('alice');
    }
    await attendre();
    for (final id in ['bob', 'chloe', 'david']) {
      await ra.accepter(id);
    }
    await attendre();
    expect(ra.amis.map((a) => a.id).toSet(), {'bob', 'chloe', 'david'});

    // Bob cache ses charges : sa séance part sans volume.
    await bob.publierSeance(seance('b1'));
    // Chloé est privée, David cache ses séances : rien ne part.
    await chloe.publierSeance(seance('c1'));
    await david.publierSeance(seance('d1'));
    await attendre();
    expect((await base.collection('publications').get()).docs.map((d) => d.id), ['bob_b1']);
    expect((await lire('publications/bob_b1'))!.containsKey('volumeKg'), isFalse);
    expect(ra.fil.single.volumeKg, 0);

    // Alice publie avec ses charges, puis les cache : le volume est retiré
    // de ses séances récentes.
    await alice.publierSeance(seance('a1'));
    await attendre();
    expect((await lire('publications/alice_a1'))!['volumeKg'], 8420);
    await alice.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice', montre: {Visible.seances})));
    await attendre();
    expect((await lire('publications/alice_a1'))!.containsKey('volumeKg'), isFalse);
    // Puis passe en privé : ses séances ne sont plus visibles que d'elle.
    await alice.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice', acces: AccesProfil.personne)));
    await attendre();
    expect((await lire('publications/alice_a1'))!['visiblePar'], ['alice']);
    expect(rb.fil, isEmpty);

    // Le profil de Chloé, privé : même son amie n'en voit que la carte.
    ra.voir('chloe');
    await attendre();
    final c = ra.ami('chloe')!;
    expect(ra.ouvert(c), isFalse);
    expect(c.prenom, 'Chloé');
    expect(c.ville, isNull);
    expect(c.seances, 0);
    // Celui de Bob, réservé aux amis et ouvert à Alice.
    expect(ra.ouvert(ra.ami('bob')!), isTrue);
  });

  test('les amis en commun et la carte d’une personne trouvée par son pseudo', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    final (rc, _) = await personne('chloe', 'Chloé', pseudo: 'chloe');
    await rb.inviter('alice');
    await rc.inviter('alice');
    await rc.inviter('bob');
    await attendre();
    await ra.accepter('bob');
    await ra.accepter('chloe');
    await rb.accepter('chloe');
    await attendre();
    ra.voir('bob');
    await attendre();
    expect(ra.ami('bob')!.enCommun, ['chloe']);
    expect(ra.joursDe(ra.ami('bob')!), isNotEmpty, reason: 'ses jours d’entraînement, relus en dates');
    expect(await ra.source.trouverPseudo('personne.ici'), isNull);
  });

  test('se déconnecter arrête les écoutes et vide tout', () async {
    final (ra, alice) = await personne('alice', 'Alice');
    final (rb, bob) = await personne('bob', 'Bob');
    await rb.inviter('alice');
    await attendre();
    await ra.accepter('bob');
    await bob.publierSeance(seance('s1'));
    await attendre();
    expect(ra.fil, hasLength(1));
    alice.changerCompte(null);
    expect(ra.aConnecter, isTrue);
    for (final vide in [ra.amis, ra.fil, ra.demandes, ra.activites()]) {
      expect(vide, isEmpty);
    }
    // Ce qui arrive après la déconnexion n'est plus écouté.
    await bob.publierSeance(seance('s2', titre: 'Dos'));
    await attendre();
    expect(ra.source.publications, isEmpty);
    // Reconnectée, elle retrouve tout.
    alice.changerCompte('alice');
    await attendre();
    expect(ra.amis.single.id, 'bob');
    expect(ra.fil.map((p) => p.titre).toSet(), {'Jambes', 'Dos'});
  });

  testWidgets('la communauté allumée sans compte invite à se connecter avec Google', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: false)))!;
    final social = SocialRepo(source: SourceFirestore(FakeFirebaseFirestore()));
    addTearDown(social.dispose);
    expect(social.aConnecter, isTrue);
    expect(social.apercu, isFalse);
    final router = GoRouter(initialLocation: SocialPaths.racine, routes: [
      ...socialRoutes(),
      GoRoute(path: '/reglages/compte', builder: (context, state) => const Scaffold(body: Text('section compte'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MultiProvider(
      providers: [
        Provider<Store>.value(value: data.store),
        ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
        ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
        ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
        ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
        ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
        ChangeNotifierProvider<SocialRepo>.value(value: social),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(const Color(0xFFFF5A5F)), routerConfig: router),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Connecte-toi avec Google pour retrouver tes amis'), findsOneWidget);
    expect(find.text('APERÇU'), findsNothing, reason: 'ce n’est plus un aperçu');
    expect(find.text('Chercher par nom'), findsNothing);
    await t.tap(find.text('Se connecter avec Google'));
    await t.pumpAndSettle();
    expect(find.text('section compte'), findsOneWidget);
  });
}
