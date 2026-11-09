import 'package:aesthetic/features/compte/data/copies_firebase.dart';
import 'package:aesthetic/features/compte/logic/copie_serveur.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ResumeCopie _resume(int morceaux, {int seances = 3}) =>
    ResumeCopie(date: DateTime(2026, 11, 9, 18), seances: seances, routines: 2, morceaux: morceaux, octets: 1234, prenom: 'Tristan');

void main() {
  test('une copie envoyée se relit à l\'identique, et seul son compte la voit', () async {
    final base = FakeFirebaseFirestore();
    final copies = CopiesFirebase(base);
    expect(await copies.resume('u1'), isNull);

    final json = '{"donnees":{"seances":[${List.filled(400, '{"nom":"Push"}').join(',')}]}}';
    final morceaux = CopieServeur.decouper(json, taille: 8);
    expect(morceaux.length, greaterThan(CopiesFirebase.parLot), reason: 'plusieurs lots');
    await copies.envoyer('u1', _resume(morceaux.length), morceaux);

    final r = await copies.resume('u1');
    expect(r!.morceaux, morceaux.length);
    expect(r.prenom, 'Tristan');
    expect(CopieServeur.recoller(await copies.lire('u1', r)), json);
    expect(await copies.resume('u2'), isNull);

    // La forme des documents suit serveur/CONCEPTION.md.
    final doc = await base.collection('copies').doc('u1').get();
    expect(doc.data()!.keys.toSet(), {'date', 'seances', 'routines', 'morceaux', 'octets', 'prenom'});
    final m0 = await base.doc('copies/u1/morceaux/0').get();
    expect(m0.data()!.keys, ['texte']);
  });

  test('une copie plus courte efface les morceaux en trop', () async {
    final base = FakeFirebaseFirestore();
    final copies = CopiesFirebase(base);
    await copies.envoyer('u1', _resume(5), ['a', 'b', 'c', 'd', 'e']);
    await copies.envoyer('u1', _resume(2), ['x', 'y']);
    final restants = await base.collection('copies/u1/morceaux').get();
    expect(restants.docs.map((d) => d.id).toSet(), {'0', '1'});
    expect(await copies.lire('u1', (await copies.resume('u1'))!), ['x', 'y']);
  });

  test('un morceau manquant rend la copie illisible', () async {
    final base = FakeFirebaseFirestore();
    final copies = CopiesFirebase(base);
    await copies.envoyer('u1', _resume(3), ['a', 'b', 'c']);
    await base.doc('copies/u1/morceaux/1').delete();
    expect(() => copies.lire('u1', _resume(3)), throwsFormatException);
  });
}
