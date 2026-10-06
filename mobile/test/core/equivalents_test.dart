import 'dart:convert';

import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/ui/objet_3d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('equivalentPour', () {
    test('les paliers de la maquette tombent sur un objet juste', () {
      final chats = [for (var g = 0; g < 30; g++) equivalentPour(320, graine: g)].firstWhere((e) => e.asset == Objets3D.chat);
      expect(chats.asset, Objets3D.chat);
      expect(chats.etiquette, '× 80');
      expect(chats.phrase, contains('80 chats'));
      expect(chats.fort, '80 chats');

      expect(equivalentPour(3621).asset, Objets3D.tracteur);
      expect(equivalentPour(3621).etiquette, '× 1');
      expect(equivalentPour(3621).phrase, startsWith('Un tracteur'));
      expect(equivalentPour(4997).asset, Objets3D.soucoupe);
      expect(equivalentPour(4997).phrase, startsWith('Une soucoupe volante'));
      expect([Objets3D.moai, Objets3D.bus], contains(equivalentPour(11000).asset));
    });

    test('la même graine redonne la même carte, les graines varient', () {
      final a = equivalentPour(6480, graine: 3);
      final b = equivalentPour(6480, graine: 3);
      expect(a.asset, b.asset);
      expect(a.phrase, b.phrase);
      final objets = {for (var g = 0; g < 30; g++) equivalentPour(6480, graine: g).asset};
      expect(objets.length, greaterThan(4));
      final phrases = {for (var g = 0; g < 60; g++) equivalentPour(2100, graine: g).phrase};
      expect(phrases.length, greaterThan(6));
    });

    test('le multiple reste lisible, sauf burger et baguette', () {
      for (final kg in [12.0, 80.0, 320.0, 640.0, 1508.0, 2100.0, 6480.0, 14792.0, 66291.0, 250000.0, 900000.0]) {
        for (var g = 0; g < 24; g++) {
          final e = equivalentPour(kg, graine: g);
          expect(e.phrase, isNotEmpty);
          expect(e.phrase.contains('*'), isFalse, reason: e.phrase);
          expect(e.phrase.contains('{'), isFalse, reason: e.phrase);
          if (e.fort.isNotEmpty) expect(e.phrase, contains(e.fort));
          final absurde = e.asset == Objets3D.burger || e.asset == Objets3D.baguette;
          if (!absurde) expect(e.multiple, inInclusiveRange(1, 100), reason: '$kg kg, graine $g : $e');
        }
      }
    });

    test('une graine sur six sort un nombre absurde', () {
      final e = equivalentPour(1000, graine: 5);
      expect(e.asset, Objets3D.burger);
      expect(e.etiquette, '× 4 000');
      expect(e.phrase, contains('4 000 burgers'));
      expect(equivalentPour(66291, graine: 11, mois: true).phrase, 'C\'est comme soulever\n265 164 baguettes !');
    });

    test('bilan du mois : phrases de la maquette', () {
      Equivalent trouve(String asset) =>
          [for (var g = 0; g < 60; g++) equivalentPour(66291, graine: g, mois: true)].firstWhere((e) => e.asset == asset);
      expect(trouve(Objets3D.baleine).phrase, 'C\'est comme soulever\n2,2 baleines à bosse !');
      expect(trouve(Objets3D.elephant).phrase, 'C\'est comme soulever\n11 éléphants !');
      expect(trouve(Objets3D.tRex).phrase, 'C\'est comme soulever\n8 tyrannosaures !');
      expect(trouve(Objets3D.fusee).phrase, 'C\'est comme soulever\n2,5 fusées à vide !');
      expect(trouve(Objets3D.bus).phrase, 'C\'est comme soulever\n6 bus !');
      expect(trouve(Objets3D.avion).phrase, 'C\'est comme soulever\n1,6 avion de ligne !');
      expect(trouve(Objets3D.vache).phrase, 'C\'est comme soulever\nun troupeau de 95 vaches !');
      final liberte = trouve(Objets3D.statueLiberte);
      expect(liberte.etiquette, '29 %');
      expect(liberte.pourcentage, isTrue);
      expect(liberte.phrase, 'Tu as soulevé 29 %\nde la statue de la Liberté !');
      expect(liberte.morceaux, ('Tu as soulevé ', '29 %', '\nde la statue de la Liberté !'));
    });

    test('cas limites : rien, presque rien, énorme', () {
      expect(equivalentPour(0).etiquette, '× 0');
      expect(equivalentPour(double.nan).multiple, 0);
      expect(equivalentPour(1).phrase, isNotEmpty);
      final geant = equivalentPour(60000000);
      expect(geant.asset, Objets3D.statueLiberte);
      expect(geant.multiple, 267);
    });

    test('aucun tiret long ni moyen dans les phrases', () {
      for (final o in objetsEquivalents) {
        for (final p in [...o.un, ...o.plusieurs, o.mois]) {
          expect(p.contains(String.fromCharCode(0x2014)) || p.contains(String.fromCharCode(0x2013)), isFalse);
        }
      }
    });
  });

  group('modèle de séance', () {
    test('douze types de série, anciens noms relus', () {
      expect(SetType.values.length, 12);
      expect(SetType.ordrePanneau.toSet(), SetType.values.toSet());
      expect(SetType.ordrePanneau.map((t) => t.lettre).toList(), ['#', 'É', 'X', 'DG', 'G', 'D', 'N', 'P', 'M', 'F', 'T', 'B']);
      for (final nom in ['echauffement', 'normale', 'degressive', 'echec']) {
        expect(WorkoutSet.fromJson({'id': 'a', 'type': nom}).type.name, nom);
      }
      expect(WorkoutSet.fromJson({'id': 'a', 'type': 'inconnu'}).type, SetType.normale);
      expect(WorkoutSet.fromJson({'id': 'a'}).type, SetType.normale);
      final s = WorkoutSet.fromJson(jsonDecode(jsonEncode(const WorkoutSet(id: 'a', type: SetType.myoReps).toJson())) as Map<String, dynamic>);
      expect(s.type, SetType.myoReps);
      expect(SetType.echauffement.counts, isFalse);
      expect(SetType.topSet.counts, isTrue);
      expect(SetType.normale.short, isEmpty);
    });

    test('médias et note : aller-retour JSON, anciens fichiers lisibles', () {
      final ancien = WorkoutSession.fromJson({'id': 's', 'nom': 'Push', 'debut': '2026-10-02T08:00:00.000'});
      expect(ancien.medias, isEmpty);
      expect(ancien.toJson().containsKey('medias'), isFalse);

      final s = ancien.copyWith(
        medias: const [SessionMedia(chemin: '/a.jpg'), SessionMedia(chemin: '/b.mp4', video: true, dureeSec: 12)],
        exercices: const [SessionExercise(id: 'e', exerciseId: 'x', notes: 'Coudes serrés')],
      );
      final relu = WorkoutSession.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(relu.medias, s.medias);
      expect(relu.medias[1].video, isTrue);
      expect(relu.medias[1].dureeSec, 12);
      expect(relu.medias[0].video, isFalse);
      expect(relu.exercices.single.note, 'Coudes serrés');
    });
  });
}
