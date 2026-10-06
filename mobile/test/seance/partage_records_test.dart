import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/seance/logic/analyse.dart';
import 'package:aesthetic/features/seance/logic/partage.dart';
import 'package:aesthetic/features/seance/pages/partager_page.dart';
import 'package:aesthetic/features/seance/routes.dart';
import 'package:aesthetic/features/seance/widgets/cartes_partage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banc.dart';
import 'banc_partage.dart';

/// L'habillage de la page de partage autour d'une carte seule.
Widget _page(Widget carte, {int nombre = 6, int actif = 1}) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22.5, 12.5, 22.5, 12.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BoutonRond(icone: Icons.close_rounded, label: 'Fermer', onTap: () {}),
                  BoutonRond(icone: Icons.add_rounded, label: 'Choisir une photo', onTap: () {}),
                ],
              ),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(22.5, 5, 22.5, 0), child: carte)),
            Padding(padding: const EdgeInsets.only(top: 15, bottom: 2.5), child: PointsPagination(nombre: nombre, actif: actif)),
            const SizedBox(height: 92.5),
          ],
        ),
      ),
    );

const _liste = [
  RecordPartage(nom: 'Développé couché', type: 'Charge maximale', valeur: '102,5 kg × 5', gain: '+2,5 kg'),
  RecordPartage(nom: 'Développé incliné aux haltères', type: '1RM estimé', valeur: '48 kg', gain: '+1,2 kg'),
  RecordPartage(nom: 'Dips', type: 'Répétitions maximales', valeur: '14 répétitions', gain: '+2 répétitions'),
  RecordPartage(nom: 'Écarté à la poulie vis-à-vis haute', type: 'Meilleure série (volume)', valeur: '22,5 kg × 15'),
  RecordPartage(nom: 'Extension triceps à la corde', type: 'Charge maximale', valeur: '35 kg × 10', gain: '+2,5 kg'),
  RecordPartage(nom: 'Élévations latérales', type: 'Charge maximale', valeur: '14 kg × 12', gain: '+1 kg'),
  RecordPartage(nom: 'Pompes', type: 'Répétitions maximales', valeur: '40 répétitions', gain: '+4 répétitions'),
  RecordPartage(nom: 'Développé militaire', type: 'Charge maximale', valeur: '60 kg × 6', gain: '+2,5 kg'),
];

/// Deux séances sur le même exercice : la seconde bat (ou non) la première.
Future<WorkoutSession> _deuxSeances(AppData d, {required double puis}) async {
  final ex = d.exercises.all.firstWhere((e) => e.suivi == ExerciseTracking.poidsReps);
  final maintenant = DateTime.now();
  WorkoutSession seance(String id, DateTime debut, double poids) => WorkoutSession(
        id: id,
        nom: 'Push',
        debut: debut,
        fin: debut.add(const Duration(hours: 1)),
        exercices: [
          SessionExercise(id: 'e$id', exerciseId: ex.id, series: [WorkoutSet(id: 'a$id', poids: poids, reps: 8, fait: true)]),
        ],
      );
  await d.sessions.save(seance('rec-1', maintenant.subtract(const Duration(hours: 5)), 900));
  final s = seance('rec-2', maintenant.subtract(const Duration(hours: 2)), puis);
  await d.sessions.save(s);
  return s;
}

void main() {
  test('ordre des cartes : les records suivent le résumé, seulement s\'il y en a', () {
    expect(PartagerPage.ordre(records: false), [
      CartePartage.resume,
      CartePartage.equivalent,
      CartePartage.detail,
      CartePartage.serie,
      CartePartage.autocollant,
    ]);
    expect(PartagerPage.ordre(records: false).length, PartagerPage.nombre);
    final avec = PartagerPage.ordre(records: true);
    expect(avec.length, PartagerPage.nombre + 1);
    expect(avec[0], CartePartage.resume);
    expect(avec[1], CartePartage.records);
    expect(avec.last, CartePartage.autocollant);
  });

  test('records de la carte : ceux du bilan, avec le gain sur l\'ancien record', () async {
    final d = AppData(Store.memory());
    await d.exercises.load();
    final s = await _deuxSeances(d, puis: 902.5);
    final bilan = BilanSeance.calculer(s, d.sessions, d.exercises);
    final records = recordsPartage(bilan, d.exercises, UnitePoids.kg);
    expect(records.length, bilan.recordsPrincipaux.length);
    expect(records.single.nom, d.exercises.nameOf(s.exercices.single.exerciseId));
    expect(records.single.type, 'Charge maximale');
    expect(records.single.valeur, texteRecord(bilan.recordsPrincipaux.single, UnitePoids.kg));
    expect(records.single.valeur, contains('× 8'));
    expect(records.single.gain, '+2,5 kg');

    // Même charge : aucun record, donc rien à montrer.
    final d2 = AppData(Store.memory());
    await d2.exercises.load();
    final egale = await _deuxSeances(d2, puis: 900);
    expect(recordsPartage(BilanSeance.calculer(egale, d2.sessions, d2.exercises), d2.exercises, UnitePoids.kg), isEmpty);
  });

  testWidgets('séance sans record : pas de carte des records', (t) async {
    final d = await monter(t, depart: '/');
    final s = (await t.runAsync(() => _deuxSeances(d, puis: 900)))!;
    await precharger(t, [for (final o in objetsEquivalents) o.asset]);
    routeurDe(t).go(SeancePaths.partager(s.id));
    await attendre(t, tours: 8);
    final etat = t.state<PartagerPageState>(find.byType(PartagerPage));
    expect(etat.nombreCartes, 5);
    expect(find.byType(CarteResume), findsOneWidget);
    for (var i = 1; i < etat.nombreCartes; i++) {
      expect(find.byType(CarteRecords), findsNothing, reason: 'carte $i');
      await t.drag(find.byType(PageView), const Offset(-330, 0));
      await attendre(t, tours: 5);
    }
    expect(find.byType(CarteRecords), findsNothing);
    expect(find.byType(CarteAutocollant), findsOneWidget);
    expect(t.takeException(), isNull);

    // L'adresse de la carte des records retombe sur la dernière carte.
    routeurDe(t).go('/');
    await attendre(t, tours: 2);
    routeurDe(t).go(SeancePaths.partager(s.id, carte: CartePartage.records.index));
    await attendre(t, tours: 6);
    expect(find.byType(CarteRecords), findsNothing);
    expect(find.byType(CarteAutocollant), findsOneWidget);
    await demonter(t);
  });

  testWidgets('séance avec record : la carte suit le résumé et sort en image', (t) async {
    final d = await monter(t, depart: '/');
    final s = (await t.runAsync(() => _deuxSeances(d, puis: 902.5)))!;
    await precharger(t, [for (final o in objetsEquivalents) o.asset]);
    routeurDe(t).go(SeancePaths.partager(s.id));
    await attendre(t, tours: 8);
    final etat = t.state<PartagerPageState>(find.byType(PartagerPage));
    expect(etat.nombreCartes, 6);
    expect(find.byType(CarteResume), findsOneWidget);

    await t.drag(find.byType(PageView), const Offset(-330, 0));
    await attendre(t, tours: 5);
    expect(find.byType(CarteRecords), findsOneWidget);
    expect(find.text('NOUVEAU RECORD'), findsOneWidget);
    expect(find.text('+2,5 kg sur mon ancien record'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, 'partager-records-demo');
    final png = (await t.runAsync(() => capturerCarte(etat.cleCourante, pixelRatio: 2)))!;
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(png.length, greaterThan(1000));

    await t.drag(find.byType(PageView), const Offset(-330, 0));
    await attendre(t, tours: 5);
    expect(find.byType(CarteEquivalent), findsOneWidget);

    // Les adresses d'avant mènent aux mêmes cartes ; les records ont la leur.
    for (final (carte, type) in [(1, CarteEquivalent), (3, CarteSerie), (4, CarteAutocollant), (5, CarteRecords)]) {
      routeurDe(t).go('/');
      await attendre(t, tours: 2);
      routeurDe(t).go(SeancePaths.partager(s.id, carte: carte));
      await attendre(t, tours: 6);
      expect(find.byType(type), findsOneWidget, reason: 'carte=$carte');
    }
    await demonter(t);
  });

  // Téléphone, petit téléphone, Fold ouvert.
  for (final taille in const [Size(412, 915), Size(360, 780), Size(884, 1100)]) {
    final l = taille.width.toInt();

    testWidgets('rendu : carte des records en $l de large', (t) async {
      await preparerPartage(t);
      t.view.physicalSize = taille;
      for (final (nom, records) in [
        ('un', _liste.sublist(0, 1)),
        ('un-premier', const [RecordPartage(nom: 'Écarté à la poulie vis-à-vis haute, un bras à la fois', type: 'Meilleure série (volume)', valeur: '1 022,5 kg × 15')]),
        ('deux', _liste.sublist(0, 2)),
        ('cinq', _liste.sublist(0, 5)),
        ('huit', _liste),
      ]) {
        await poserPartage(t, _page(CarteRecords(records: records)));
        expect(t.takeException(), isNull, reason: '$nom, $l');
        // Rien ne sort du cadre de la carte.
        final cadre = t.getRect(find.byType(CarteRecords));
        expect(t.getRect(find.byType(MarquePartage)).bottom, lessThanOrEqualTo(cadre.bottom));
        for (final e in find.descendant(of: find.byType(CarteRecords), matching: find.byType(Text)).evaluate()) {
          final r = t.getRect(find.byWidget(e.widget));
          expect(r.left, greaterThanOrEqualTo(cadre.left), reason: '$nom, $l : ${(e.widget as Text).data}');
          expect(r.right, lessThanOrEqualTo(cadre.right), reason: '$nom, $l : ${(e.widget as Text).data}');
        }
        if (records.length == 1) {
          expect(find.text('NOUVEAU RECORD'), findsOneWidget);
        } else {
          expect(find.text('${records.length}'), findsOneWidget);
          expect(find.text('records battus'), findsOneWidget);
        }
        // Sur le Fold ouvert, les lignes gardent une largeur de téléphone.
        if (records.length > 1 && l < 500) {
          // Les lignes gardent leur taille : la liste est bornée à ce qui tient
          // dans la carte plutôt que rétrécie.
          final ligne = t.getRect(find.ancestor(of: find.text(records.first.valeur), matching: find.byType(Container)).first);
          expect(ligne.width, greaterThanOrEqualTo((cadre.width - 40) * 0.9), reason: '$nom, $l : lignes rétrécies');
        }
        if (nom == 'deux') expect(find.textContaining('autre'), findsNothing);
        if (nom == 'cinq' && l == 412) expect(find.textContaining('autre'), findsNothing);
        if (nom == 'huit') {
          expect(find.textContaining('autres'), findsOneWidget);
          if (l == 412) {
            // Quatre lignes, puis le décompte du reste.
            expect(find.text('+ 4 autres'), findsOneWidget);
            expect(find.text(_liste[3].valeur), findsOneWidget);
            expect(find.text(_liste[4].valeur), findsNothing);
          }
        }
        await capturePartage(t, 'partager-records-$l-$nom');
      }
    });
  }
}
