import 'package:aesthetic/features/social/data/social_repo.dart';
import 'package:aesthetic/features/social/data/source_firestore.dart';
import 'package:aesthetic/features/social/data/synchro.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../aujourdhui/banc.dart' show donnees;

/// Ce qui part de mon téléphone : le compte et l'interrupteur décident si
/// la source écoute, mon profil et mes séances terminées partent seuls.
void main() {
  test('profil, pseudo tiré du prénom, séance terminée publiée puis effacée, communauté coupée', () async {
    final data = await donnees(demo: true);
    final base = FakeFirebaseFirestore();
    final source = SourceFirestore(base);
    // Les envois sont appelés à la main : le minuteur ne part jamais.
    final synchro = SynchroSociale(data, source, delai: const Duration(hours: 1));
    addTearDown(() {
      synchro.dispose();
      source.dispose();
    });
    Future<void> attendre() => pumpEventQueue(times: 40);

    // Connecté mais communauté coupée : rien n'écoute.
    synchro.uid = 'moi';
    expect(source.moi, isNull);
    await data.settings.update((s) => s.copyWith(communaute: true));
    expect(source.moi, 'moi');

    // Sans pseudo, un pseudo libre est pris dans le prénom.
    await data.profile.update((p) => p.copyWith(pseudo: ''));
    await synchro.publier();
    final pseudo = data.profile.profile!.pseudo;
    expect(pseudo, isNotEmpty);
    expect(SourceFirestore.pseudoPermis.hasMatch(pseudo), isTrue);

    // Une séance qui vient de finir.
    final finie = data.sessions.sessions.firstWhere((s) => !s.enCours);
    final n = DateTime.now();
    await data.sessions.save(finie.copyWith(debut: n.subtract(const Duration(minutes: 70)), fin: n.subtract(const Duration(minutes: 5))));
    await attendre();
    await synchro.publier();
    await attendre();
    // Le profil est en ligne ; au tour suivant (le fil est lu), la séance part.
    expect((await base.doc('profils/moi').get()).data()?['pseudoMin'], pseudo);
    expect((await base.doc('pseudos/$pseudo').get()).data(), {'uid': 'moi'});
    await synchro.publier();
    await attendre();
    final pub = await base.doc('publications/moi_${finie.id}').get();
    expect(pub.exists, isTrue);
    expect(pub.data()!['visiblePar'], ['moi']);
    expect(source.seancesPubliees, contains(finie.id));
    // Les plus anciennes ne repartent pas dans le fil.
    expect((await base.collection('publications').get()).docs, hasLength(1));

    // Effacée sur le téléphone, elle quitte le fil.
    await data.sessions.delete(finie.id);
    await attendre();
    await synchro.publier();
    await attendre();
    expect((await base.doc('publications/moi_${finie.id}').get()).exists, isFalse);

    // Communauté coupée, ou déconnexion : les écoutes s'arrêtent.
    await data.settings.update((s) => s.copyWith(communaute: false));
    expect(source.moi, isNull);
    await data.settings.update((s) => s.copyWith(communaute: true));
    expect(source.moi, 'moi');
    synchro.uid = null;
    expect(source.moi, isNull);
    expect(SocialRepo(source: SourceFirestore(base)).aConnecter, isTrue);
  });
}
