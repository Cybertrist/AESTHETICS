import 'dart:convert';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/inscription/data/draft.dart';
import 'package:aesthetic/features/inscription/inscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brouillon complet : aller-retour exact', () {
    final d = Draft(
      prenom: 'Tristan',
      photo: 'p.jpg',
      sexe: Sexe.femme,
      naissance: DateTime(1999, 5, 12),
      tailleCm: 181,
      uniteTaille: UniteTaille.ftIn,
      poidsKg: 77.5,
      poidsCibleKg: 82,
      unitePoids: UnitePoids.lb,
      objectif: Objectif.secher,
      niveau: Niveau.avance,
      activite: NiveauActivite.actif,
      jours: {2, 4, 6, 7},
      dureeSeanceMin: 90,
      materielPreset: MaterielPreset.maison,
      materiel: {Materiel.halteres, Materiel.elastiques},
      muscles: {Muscle.pectoraux, Muscle.mollets},
      objectifsNutrition: const NutritionGoals(kcal: 2800),
      nutritionAuto: false,
      santeConnectee: true,
      rappels: true,
      heureRappel: '07:30',
      etape: 9,
    );
    final a = jsonEncode(d.toJson());
    expect(jsonEncode(Draft.fromJson(Map<String, dynamic>.from(jsonDecode(a) as Map)).toJson()), a);
  });

  test('brouillon abîmé ou d\'une autre version : le parcours repart sans erreur', () async {
    for (final contenu in <Object?>[
      {'etape': 99, 'prenom': 12, 'sexe': 'x', 'jours': 'lundi', 'objectifsNutrition': 'auto', 'tailleCm': 'NaN', 'materiel': [null, 3, 'banc']},
      {'etape': -4},
      [1, 2, 3],
      'texte',
    ]) {
      final store = Store.memory();
      await store.write(Draft.collection, contenu);
      final c = InscriptionController(store);
      await c.load();
      expect(c.loaded, isTrue);
      expect(c.index, inInclusiveRange(0, Etape.values.length - 1));
      expect(c.draft.tailleCm, isNull);
      c.dispose();
    }
  });

  test('une réponse donnée juste avant de quitter l\'écran est gardée', () async {
    final store = Store.memory();
    final c = InscriptionController(store);
    await c.load();
    c.set((d) => d.prenom = 'Tristan');
    c.suivant();
    // L'écran est détruit avant la fin du délai de sauvegarde.
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final relu = InscriptionController(store);
    await relu.load();
    expect(relu.draft.prenom, 'Tristan');
    expect(relu.etape, Etape.sexe);
    relu.dispose();
  });

  test('le profil créé efface le brouillon, même si une sauvegarde était en attente', () async {
    final data = AppData(Store.memory());
    final c = InscriptionController(data.store);
    await c.load();
    c.set((d) {
      d.prenom = 'Tristan';
      d.sexe = Sexe.homme;
      d.poidsKg = 77;
    });
    await c.enregistrer(profils: data.profile, reglages: data.settings, sante: data.health);
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(await data.store.readObject(Draft.collection), isNull);
    expect(data.profile.profile!.prenom, 'Tristan');
    expect(data.health.latestWeight, 77);
  });

  test('bornes de l\'âge : 13 ans aujourd\'hui accepté, la veille de ses 13 ans refusé', () async {
    final c = InscriptionController(Store.memory());
    await c.load();
    final now = DateTime.now();
    c.set((d) => d.naissance = DateTime(now.year - 13, now.month, now.day));
    expect(c.valide(Etape.naissance), isTrue);
    c.set((d) => d.naissance = DateTime(now.year - 13, now.month, now.day).add(const Duration(days: 1)));
    expect(c.valide(Etape.naissance), isFalse);
    c.set((d) => d.naissance = DateTime(now.year + 1));
    expect(c.valide(Etape.naissance), isFalse);
    c.dispose();
  });
}
