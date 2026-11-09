import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:aesthetic/features/social/data/source_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les trous trouvés par l'équipe de test, bouchés côté appli : le fil ne
/// prend que mes amis, un ami parti sort de toutes mes séances, accepter
/// efface les deux demandes, une séance retirée part avec ce qu'il y a
/// dessous, un deuxième téléphone rend le bon pseudo.
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

  Future<void> attendre() => pumpEventQueue(times: 40);
  Future<Map<String, dynamic>?> lire(String chemin) async => (await base.doc(chemin).get()).data();

  Ami profil(String prenom, String pseudo) => Ami(id: 'moi', prenom: prenom, pseudo: pseudo, couleur: 0xFF2E7D4F, acces: AccesProfil.amis, montre: tout, seances: 10);

  Future<(SocialRepo, SourceFirestore)> personne(String uid, String prenom) async {
    final source = SourceFirestore(base);
    final repo = SocialRepo(source: source);
    aFermer.add(repo.dispose);
    source.changerCompte(uid);
    await source.publierProfil(MonProfilPublic(personne: profil(prenom, prenom.toLowerCase())));
    await attendre();
    return (repo, source);
  }

  Future<void> amis(SocialRepo de, String idVers, SocialRepo vers, String idDe) async {
    await de.inviter(idVers);
    await attendre();
    await vers.accepter(idDe);
    await attendre();
  }

  /// Une publication posée telle quelle en base (un autre téléphone, une vieille séance).
  Future<void> poser(String id, String auteur, List<String> visiblePar, {int jours = 0}) => base.doc('publications/$id').set({
        'auteur': auteur,
        'seanceId': id.substring(auteur.length + 1),
        'titre': 'Push',
        'date': Timestamp.fromDate(DateTime.now().subtract(Duration(days: jours, hours: 1))),
        'dureeSec': 3600,
        'series': 12,
        'exercices': ['squat'],
        'records': 0,
        'visiblePar': visiblePar,
        'majLe': Timestamp.now(),
      });

  test('le fil ne prend que mes amis : un inconnu qui me met dans visiblePar n’y entre pas', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    await amis(rb, 'alice', ra, 'bob');
    await poser('bob_s1', 'bob', ['bob', 'alice']);
    await poser('gael_spam', 'gael', ['gael', 'alice']);
    // Cent séances datées de demain : elles ne chassent pas celles de Bob.
    for (var i = 0; i < 100; i++) {
      await poser('gael_flot$i', 'gael', ['gael', 'alice'], jours: -1);
    }
    await attendre();
    expect(ra.fil.map((p) => p.id), ['bob_s1']);
  });

  test('un ami retiré sort de toutes mes séances, même de plus de 30 jours', () async {
    final (ra, _) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    await amis(rb, 'alice', ra, 'bob');
    await poser('alice_vieille', 'alice', ['alice', 'bob'], jours: 45);
    await ra.retirer('bob');
    await attendre();
    expect((await lire('publications/alice_vieille'))!['visiblePar'], ['alice']);
  });

  test('retiré par l’autre pendant que l’appli dort : au lancement suivant, il sort aussi des vieilles séances', () async {
    final sa = SourceFirestore(base)..changerCompte('alice');
    final ra = SocialRepo(source: sa);
    await sa.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice')));
    final (rb, _) = await personne('bob', 'Bob');
    await amis(rb, 'alice', ra, 'bob');
    await poser('alice_vieille', 'alice', ['alice', 'bob'], jours: 45);
    // L'appli d'alice est fermée quand bob la retire.
    ra.dispose();
    await rb.retirer('alice');
    await attendre();
    expect((await lire('publications/alice_vieille'))!['visiblePar'], ['alice', 'bob']);
    // Pas de mémoire sur ce téléphone : toutes les séances sont revues.
    await attendre();
    final source = SourceFirestore(base);
    aFermer.add(source.dispose);
    source.changerCompte('alice');
    await attendre();
    expect((await lire('publications/alice_vieille'))!['visiblePar'], ['alice']);
  });

  test('accepter efface aussi ma demande croisée, même pas encore vue par l’écoute', () async {
    final (ra, sa) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    await rb.inviter('alice');
    await attendre();
    // Ma demande vers Bob, envoyée d'un autre téléphone, arrive après.
    await base.doc('demandes/alice_bob').set({'de': 'alice', 'vers': 'bob', 'date': Timestamp.now()});
    await sa.accepter('bob');
    await attendre();
    expect(await lire('demandes/bob_alice'), isNull);
    expect(await lire('demandes/alice_bob'), isNull);
  });

  test('une séance retirée part avec ses réactions et ses commentaires', () async {
    final (ra, sa) = await personne('alice', 'Alice');
    final (rb, _) = await personne('bob', 'Bob');
    await amis(rb, 'alice', ra, 'bob');
    await poser('alice_s1', 'alice', ['alice', 'bob']);
    await attendre();
    await rb.reagir('alice_s1', Reaction.feu);
    await rb.commenter('alice_s1', 'Costaud');
    await attendre();
    await sa.retirerSeance('s1');
    expect(await lire('publications/alice_s1'), isNull);
    expect((await base.collection('publications/alice_s1/reactions').get()).docs, isEmpty);
    expect((await base.collection('publications/alice_s1/commentaires').get()).docs, isEmpty);
  });

  test('deux téléphones : le second rend le pseudo que la carte porte vraiment', () async {
    final (_, a) = await personne('alice', 'Alice');
    final b = SourceFirestore(base);
    aFermer.add(b.dispose);
    b.changerCompte('alice');
    await attendre();
    await a.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice.un')));
    await b.publierProfil(MonProfilPublic(personne: profil('Alice', 'alice.deux')));
    expect(b.etatPseudo, EtatPseudo.ok);
    final pseudos = {for (final d in (await base.collection('pseudos').get()).docs) d.id: d.data()['uid']};
    expect(pseudos, {'alice.deux': 'alice'});
  });
}
