import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/env.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/features/inscription/data/draft.dart';
import 'package:aesthetic/features/inscription/inscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _k = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
  final img = await ro.toImage(pixelRatio: 1.5);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  (File('build/rendus/inscription/$name.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _attendre(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
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

/// Rendu hors écran du parcours d'inscription : captures dans build/rendus/inscription/.
void main() {
  Future<void> preparer(WidgetTester t, Size taille) async {
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
      await _font('Figtree', ['assets/fonts/Roboto-Regular.ttf', 'assets/fonts/Roboto-Medium.ttf', 'assets/fonts/Roboto-Bold.ttf']);
      final icons = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          await BodyImageRepository.load(v, f);
        }
      }
    });
    t.view.physicalSize = taille;
    t.view.devicePixelRatio = 1;
  }

  for (final (taille, dossier) in const [(Size(360, 780), ''), (Size(412, 915), '412/')]) {
  testWidgets('parcours, écran étroit de ${taille.width.toInt()}', (t) async {
    await preparer(t, taille);
    final data = AppData(Store.memory());
    await t.runAsync(data.loadAll);
    await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: AccentController())));
    await _attendre(t);
    expect(find.text('Commencer'), findsOneWidget);
    // Musculation seule : l'accueil ne promet que ce qui existe.
    expect(Env.muscuSeule, isTrue);
    expect(Etape.parcours, hasLength(13));
    for (final texte in ['Tes séances', 'Tes programmes', 'Tes progrès', 'Deux minutes, 12 questions.']) {
      expect(find.text(texte), findsOneWidget, reason: texte);
    }
    for (final texte in ['Tes repas', 'Ta récupération', 'Ton coach']) {
      expect(find.text(texte), findsNothing, reason: texte);
    }
    expect(find.byType(IconHalo), findsNothing, reason: 'icônes blanches, sans pastille');
    await t.runAsync(() => _shot(t, '${dossier}00-bienvenue'));

    for (final e in Etape.parcours) {
      final ctx = t.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).go('/bienvenue');
      await _attendre(t);
      await t.runAsync(() => data.store.write(Draft.collection, _brouillon(e.index).toJson()));
      GoRouter.of(t.element(find.byType(Scaffold).first)).push('/bienvenue/profil');
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _attendre(t);
      await _attendre(t);
      expect(t.takeException(), isNull, reason: e.name);
      expect(find.text('Étape ${e.rang + 1} sur 13'), findsOneWidget, reason: e.name);
      await t.runAsync(() => _shot(t, '$dossier${(e.rang + 1).toString().padLeft(2, '0')}-${e.slug}'));
    }

    // Fin du parcours : création du profil puis programme conseillé.
    await t.tap(find.text('Créer mon profil'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await _attendre(t);
    await _attendre(t);
    expect(data.profile.hasProfile, isTrue);
    await t.runAsync(() => _shot(t, '${dossier}20-programme'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).push('/bienvenue/programme/seance/0');
    await _attendre(t);
    await t.runAsync(() => _shot(t, '${dossier}21-seance'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).push('/bienvenue/programme/seance/0/exercice/0');
    await _attendre(t);
    await t.runAsync(() => _shot(t, '${dossier}22-remplacer'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).go('/bienvenue/modifier');
    await _attendre(t);
    await t.runAsync(() => _shot(t, '${dossier}23-modifier'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).push('/bienvenue/modifier/poids');
    await _attendre(t);
    await t.runAsync(() => _shot(t, '${dossier}24-modifier-poids'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
  }

  testWidgets('parcours, Fold ouvert', (t) async {
    await preparer(t, const Size(900, 760));
    final data = AppData(Store.memory());
    await t.runAsync(data.loadAll);
    await t.runAsync(() => data.store.write(Draft.collection, _brouillon(Etape.muscles.index).toJson()));
    await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: AccentController())));
    await _attendre(t);
    await t.runAsync(() => _shot(t, 'large-00-bienvenue'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).push('/bienvenue/profil');
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await _attendre(t);
    await _attendre(t);
    await t.runAsync(() => _shot(t, 'large-11-muscles'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
