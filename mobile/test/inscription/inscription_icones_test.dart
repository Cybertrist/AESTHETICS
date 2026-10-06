import 'dart:convert';
import 'dart:io';

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/inscription/data/draft.dart';
import 'package:aesthetic/features/inscription/inscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

Draft _brouillon(int etape) => Draft(
      prenom: 'Tristan',
      sexe: Sexe.homme,
      naissance: DateTime(1999, 5, 12),
      tailleCm: 181,
      poidsKg: 77,
      objectif: Objectif.prendreDuMuscle,
      niveau: Niveau.intermediaire,
      activite: NiveauActivite.modere,
      jours: {1, 2, 4, 5},
      materielPreset: MaterielPreset.salle,
      materiel: {Materiel.salleComplete},
      muscles: {Muscle.pectoraux, Muscle.deltoidesLateraux},
      etape: etape,
    );

/// Design validé : les icônes de début de ligne sont blanches (ou grises quand
/// elles sont éteintes) dans un rond gris, jamais teintées.
int _verifierIcones(WidgetTester t, String page) {
  final halos = find.byType(IconHalo).evaluate().toList();
  for (final e in halos) {
    final halo = e.widget as IconHalo;
    final c = e.colors;
    expect(halo.color, isNull, reason: '$page : IconHalo ${halo.icon} coloré');
    final icones = find.descendant(of: find.byWidget(halo), matching: find.byType(Icon));
    for (final i in t.widgetList<Icon>(icones)) {
      expect([c.text, c.text3], contains(i.color), reason: '$page : icône ${i.icon} teintée');
    }
  }
  return halos.length;
}

void main() {
  testWidgets('Inscription : aucune icône à halo coloré', (t) async {
    // Assets lus sur le disque ; le catalogue d'aliments facultatif peut manquer.
    t.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (msg) async {
      final cle = Uri.decodeFull(utf8.decode(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes)));
      final f = File('build/unit_test_assets/$cle');
      if (f.existsSync()) return ByteData.sublistView(f.readAsBytesSync());
      if (cle.endsWith('.json')) return ByteData.sublistView(Uint8List.fromList(utf8.encode('[]')));
      return null;
    });
    await t.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          await BodyImageRepository.load(v, f);
        }
      }
    });
    addTearDown(t.view.reset);
    t.view.physicalSize = const Size(380, 1800);
    t.view.devicePixelRatio = 1;
    final data = AppData(Store.memory());
    await t.runAsync(data.loadAll);
    await t.pumpWidget(AestheticApp(data: data, accent: AccentController()));
    await _attendre(t);
    expect(find.text('Commencer'), findsOneWidget);

    var vus = _verifierIcones(t, 'bienvenue');
    GoRouter routeur() => GoRouter.of(t.element(find.byType(Scaffold).first));

    for (final e in Etape.parcours) {
      routeur().go('/bienvenue');
      await _attendre(t);
      await t.runAsync(() => data.store.write(Draft.collection, _brouillon(e.index).toJson()));
      routeur().push('/bienvenue/profil');
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _attendre(t);
      expect(t.takeException(), isNull, reason: e.name);
      vus += _verifierIcones(t, e.name);
    }

    await t.tap(find.text('Créer mon profil'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await _attendre(t);
    expect(data.profile.hasProfile, isTrue);
    vus += _verifierIcones(t, 'programme');
    routeur().go('/bienvenue/modifier');
    await _attendre(t);
    vus += _verifierIcones(t, 'modifier');
    expect(vus, greaterThan(15), reason: 'le test doit réellement croiser des icônes');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
