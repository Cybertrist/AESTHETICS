import 'package:aesthetic/features/import/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalogue_test_data.dart';

void main() {
  final m = ExerciseMatcher(catalogueTest);
  Rapprochement r(String n) => m.rapprocher(n);

  test('normalisation : casse, accents, ponctuation, pluriels, synonymes', () {
    expect(cleNom('Pull-Ups'), 'pullup');
    expect(cleNom('DB Curls'), 'dumbbell curl');
    expect(cleNom('Développé couché à la barre'), 'bench press barbell');
    expect(cleNom('Soulevé de terre roumain'), 'deadlift romanian');
    expect(cleNom('Lever Seated Row'), 'machine seated row');
    expect(cleNom('Triceps'), 'triceps');
  });

  test('exact par le nom anglais, un alias ou le nom français', () {
    expect(r('barbell bench press').statut, StatutRapprochement.exact);
    expect(r('Bench Press (Barbell)').exerciceId, 'developpe-couche-barre');
    expect(r('Développé couché barre').exerciceId, 'developpe-couche-barre');
    expect(r('TRACTIONS').exerciceId, 'tractions');
    expect(r('Pull-ups').exerciceId, 'tractions');
  });

  test('mots dans un autre ordre : accepté sans question', () {
    final x = r('Incline Dumbbell Bench Press');
    expect(x.statut, StatutRapprochement.automatique);
    expect(x.exerciceId, 'developpe-incline-halteres');
  });

  test('faute de frappe corrigée par les synonymes', () {
    expect(r('Dumbell Bench Press').exerciceId, 'developpe-couche-halteres');
  });

  test('matériel différent : jamais accepté seul', () {
    final x = r('Smith Machine Bench Press');
    expect(x.statut, isNot(StatutRapprochement.automatique));
    expect(x.statut, isNot(StatutRapprochement.exact));
  });

  test('variante proche : ambigu, bon candidat en tête', () {
    final x = r('Lever Narrow Grip Seated Row');
    expect(x.statut, StatutRapprochement.ambigu);
    expect(x.choisi, isNull);
    expect(x.candidats.first.entree.id, 'rowing-assis-machine');
    expect(x.aConfirmer, isTrue);
  });

  test('inconnu sous le seuil', () {
    final x = r('Lancer de tronc d\'arbre');
    expect(x.statut, StatutRapprochement.inconnu);
    expect(x.choisi, isNull);
  });

  test('mémoire des choix', () {
    final x = m.rapprocher('Mon curl maison', memoire: {cleNom('Mon curl maison'): 'curl-barre'});
    expect(x.statut, StatutRapprochement.manuel);
    expect(x.exerciceId, 'curl-barre');
    final y = m.rapprocher('Mon curl maison', memoire: {cleNom('mon CURL maison'): ''});
    expect(y.statut, StatutRapprochement.nouveau);
  });

  test('recherche libre pour le choix manuel', () {
    final res = m.rechercher('curl');
    expect(res, isNotEmpty);
    expect(res.every((c) => c.entree.id.startsWith('curl')), isTrue);
  });

  test('scores bornés et symétriques en pratique', () {
    final a = ExerciseMatcher.scoreNoms('Barbell Curl', 'Dumbbell Biceps Curl');
    final b = ExerciseMatcher.scoreNoms('Dumbbell Biceps Curl', 'Barbell Curl');
    expect(a, closeTo(b, 0.05));
    expect(a, lessThan(ExerciseMatcher.seuilAuto));
    expect(ExerciseMatcher.scoreNoms('Squat', 'Squat'), 1);
  });

  test('catalogue de 1500 noms : rapide', () {
    final gros = [
      ...catalogueTest,
      for (var i = 0; i < 1500; i++)
        CatalogueEntry(id: 'x$i', nom: 'Exercice $i', nomEn: 'Cable Variation Number $i Press'),
    ];
    final mm = ExerciseMatcher(gros);
    final chrono = Stopwatch()..start();
    for (var i = 0; i < 150; i++) {
      mm.rapprocher('Cable Variation Numbr ${i * 7} Press Wide');
    }
    expect(chrono.elapsedMilliseconds, lessThan(5000));
  });
}
