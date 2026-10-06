import 'package:aesthetic/core/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// `equivalentPour` sur toute la plage utile (0 à 200 000 kg) : la phrase et
/// l'objet restent sensés quelle que soit la graine.

/// Poids passés en revue : chaque kilo jusqu'à 2 000, puis un sur 37.
Iterable<int> get _poids sync* {
  for (var kg = 0; kg < 200000; kg += kg < 2000 ? 1 : 37) {
    yield kg;
  }
  yield 200000;
}

const _graines = 36;

/// Espaces des milliers, quelle que soit leur nature.
final _espaces = RegExp('[\\s  ]');

ObjetEquivalent _objet(Equivalent e) => objetsEquivalents.firstWhere((o) => o.asset == e.asset);

/// Le chiffre de la pastille, sans le signe : « 2,5 », « 4 000 ».
String _chiffre(Equivalent e) => e.etiquette.substring(2);

/// Le nombre écrit sur la pastille (« × 2,5 » rend 2,5).
double? _valeur(Equivalent e) {
  if (!e.etiquette.startsWith('× ')) return null;
  return double.tryParse(_chiffre(e).replaceAll(_espaces, '').replaceAll(',', '.'));
}

void main() {
  test('toute la plage : deux lignes, aucun gabarit, pastille et phrase d\'accord', () {
    for (final kg in _poids) {
      for (var g = 0; g < _graines; g++) {
        for (final mois in [false, true]) {
          final e = equivalentPour(kg.toDouble(), graine: g, mois: mois);
          final ou = '$kg kg, graine $g, mois $mois : ${e.etiquette} « ${e.phrase.replaceAll('\n', ' / ')} »';
          expect(e.phrase.split('\n').length, 2, reason: ou);
          expect(e.phrase.contains(RegExp(r'[*{}]')), isFalse, reason: ou);
          expect(e.phrase.trim(), e.phrase, reason: ou);
          expect(e.phrase.contains('  '), isFalse, reason: ou);
          if (e.fort.isNotEmpty) expect(e.phrase, contains(e.fort), reason: ou);
          // Virgule française, jamais de « ,0 » ni de point décimal.
          expect(e.etiquette.contains('.'), isFalse, reason: ou);
          expect(e.etiquette.contains(',0'), isFalse, reason: ou);
          expect(RegExp(r'\d\.\d').hasMatch(e.phrase), isFalse, reason: ou);
          if (kg == 0) {
            expect(e.etiquette, '× 0', reason: ou);
            expect(e.phrase.contains(RegExp(r'\b0 ')), isFalse, reason: 'pas de « 0 chat » : $ou');
            continue;
          }
          expect(e.multiple, greaterThanOrEqualTo(1), reason: ou);
          if (e.pourcentage) {
            expect(e.multiple, inInclusiveRange(10, 93), reason: ou);
            expect(e.etiquette.replaceAll(_espaces, ' '), '${e.multiple.round()} %', reason: ou);
            expect(e.phrase.replaceAll(RegExp('[  ]'), ' '), contains('${e.multiple.round()} %'), reason: ou);
            continue;
          }
          final v = _valeur(e);
          expect(v, isNotNull, reason: ou);
          expect(v, closeTo(e.multiple, 0.001), reason: ou);
          final o = _objet(e);
          if (!o.absurde) expect(v, lessThan(100), reason: 'multiple illisible : $ou');
          // Le nombre de la pastille colle au poids : 8 % d'écart au plus.
          final vrai = kg / o.kg;
          expect((v! - vrai).abs() / vrai, lessThan(0.09), reason: 'pastille loin du vrai rapport ${vrai.toStringAsFixed(2)} : $ou');
          if (v == 1) {
            // Un seul : en toutes lettres, avec le bon article.
            expect(e.phrase.contains(RegExp(r'\b1 ')), isFalse, reason: ou);
            expect(e.phrase.toLowerCase(), contains(o.nom.toLowerCase()), reason: ou);
            expect(RegExp(r'\bune? toilettes').hasMatch(e.phrase.toLowerCase()), isFalse, reason: ou);
          } else if (v < 2) {
            // 1,6 avion : singulier.
            expect(e.phrase, contains('${_chiffre(e)} ${o.nom}'), reason: ou);
            if (o.nom != o.pluriel) expect(e.phrase.contains('${_chiffre(e)} ${o.pluriel}'), isFalse, reason: ou);
          } else {
            expect(e.phrase, contains('${_chiffre(e)} ${o.pluriel}'), reason: ou);
          }
          // Élisions et tournures impossibles.
          expect(RegExp(r'\bde une?\b', caseSensitive: false).hasMatch(e.phrase), isFalse, reason: 'élision : $ou');
          expect(RegExp(r'troupeau de (une?|1|2|[0-9]+,)\b').hasMatch(e.phrase), isFalse, reason: 'troupeau : $ou');
        }
      }
    }
  });

  test('un seul objet, bilan du mois : le bon article', () {
    Equivalent seul(String nom) {
      final o = objetsEquivalents.firstWhere((o) => o.nom == nom);
      return [for (var g = 0; g < 200; g++) equivalentPour(o.kg, graine: g, mois: true)].firstWhere((e) => e.asset == o.asset);
    }

    expect(seul('toilettes').phrase, 'C\'est comme soulever\ndes toilettes !');
    expect(seul('vache').phrase, 'C\'est comme soulever\nune vache !');
    expect(seul('tracteur').phrase, 'C\'est comme soulever\nun tracteur !');
    expect(seul('fusée').phrase, 'C\'est comme soulever\nune fusée à vide !');
    expect(seul('statue de la Liberté').phrase, 'C\'est comme soulever\nla statue de la Liberté !');
    expect(seul('statue de l\'île de Pâques').phrase, 'C\'est comme soulever\nune statue de l\'île de Pâques !');
    // Le troupeau commence à trois vaches.
    final vache = objetsEquivalents.firstWhere((o) => o.nom == 'vache');
    Equivalent vaches(double n, {bool mois = true}) =>
        [for (var g = 0; g < 400; g++) equivalentPour(vache.kg * n, graine: g, mois: mois)].firstWhere((e) => e.asset == vache.asset);
    expect(vaches(2).phrase, 'C\'est comme soulever\n2 vaches !');
    expect(vaches(2.5).phrase, 'C\'est comme soulever\n2,5 vaches !');
    expect(vaches(3).phrase, 'C\'est comme soulever\nun troupeau de 3 vaches !');
    expect(vaches(2, mois: false).phrase, isNot(contains('troupeau')));
    expect({for (var g = 0; g < 400; g++) equivalentPour(vache.kg * 40, graine: g).phrase}, contains('Un troupeau de 40 vaches.\nElles ont regardé passer la barre.'));
  });

  test('objets absurdes : seulement une graine sur six, ou faute d\'autre objet', () {
    for (final kg in _poids) {
      for (var g = 0; g < _graines; g++) {
        final e = equivalentPour(kg.toDouble(), graine: g);
        final absurde = kg > 0 && _objet(e).absurde;
        if (kg >= 50) {
          expect(absurde, g % 6 == 5, reason: '$kg kg, graine $g : $e');
        } else if (kg >= 4) {
          expect(absurde, isFalse, reason: 'sous 50 kg, pas de centaines de burgers : $kg kg, graine $g : $e');
        }
        if (absurde && kg < 4) expect(e.multiple, lessThanOrEqualTo(16), reason: '$kg kg : $e');
      }
    }
  });

  test('la graine fait varier l\'objet, la même graine redonne la même carte', () {
    for (final kg in _poids) {
      if (kg < 50) continue;
      final objets = <String>{};
      for (var g = 0; g < 60; g++) {
        final a = equivalentPour(kg.toDouble(), graine: g);
        final b = equivalentPour(kg.toDouble(), graine: g);
        expect((a.asset, a.etiquette, a.phrase, a.fort), (b.asset, b.etiquette, b.phrase, b.fort));
        // La carte de fin de séance et la carte de partage montrent le même objet.
        final m = equivalentPour(kg.toDouble(), graine: g, mois: true);
        expect((m.asset, m.etiquette), (a.asset, a.etiquette), reason: '$kg kg, graine $g');
        // Une graine négative vaut sa valeur absolue.
        expect(equivalentPour(kg.toDouble(), graine: -g).phrase, a.phrase);
        objets.add(a.asset);
      }
      expect(objets.length, greaterThanOrEqualTo(3), reason: '$kg kg : $objets');
    }
  });

  test('mesure : part des multiples à virgule', () {
    var total = 0, virgule = 0, sansEntier = 0;
    final parTranche = <String, (int, int)>{};
    for (final kg in _poids) {
      if (kg < 50) continue;
      var entier = false;
      for (var g = 0; g < 120; g++) {
        // Graines dispersées, comme la seconde du début d'une séance.
        final e = equivalentPour(kg.toDouble(), graine: g * 7919 + kg);
        final v = e.etiquette.contains(',');
        total++;
        if (v) virgule++;
        if (!v && !_objet(e).absurde) entier = true;
        final t = kg < 2000
            ? 'a. 50 à 2 000 kg'
            : kg < 10000
                ? 'b. 2 à 10 t'
                : kg < 50000
                    ? 'c. 10 à 50 t'
                    : 'd. 50 à 200 t';
        final (n, d) = parTranche[t] ?? (0, 0);
        parTranche[t] = (n + 1, d + (v ? 1 : 0));
      }
      if (!entier) sansEntier++;
    }
    final part = virgule / total;
    // ignore: avoid_print
    print('multiples à virgule : ${(part * 100).toStringAsFixed(1)} % des cartes ; poids sans aucun multiple entier : $sansEntier');
    for (final t in parTranche.keys.toList()..sort()) {
      final (n, d) = parTranche[t]!;
      // ignore: avoid_print
      print('  $t : ${(d * 100 / n).toStringAsFixed(1)} %');
    }
    // Dès 50 kg, il existe toujours un objet au multiple entier : écarter les
    // multiples à virgule ne laisserait jamais la carte sans objet.
    expect(sansEntier, 0);
    expect(part, lessThan(0.35));
  });
}
