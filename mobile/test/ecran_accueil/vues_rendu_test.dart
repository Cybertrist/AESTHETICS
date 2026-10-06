import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/features/ecran_accueil/vues.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../aujourdhui/banc.dart';

/// Les six widgets de l'écran d'accueil du téléphone, dessinés avec les
/// données de la démo : build/rendus/ecran_accueil/planche.png.
void main() {
  testWidgets('les six widgets se dessinent sans erreur ni débordement', (t) async {
    await t.runAsync(polices);
    final data = (await t.runAsync(() => donnees(demo: true)))!;
    t.view.physicalSize = const Size(800, 1300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cadre = GlobalKey();
    final cles = {for (final w in WidgetEcran.values) w: GlobalKey()};
    // Le dernier samedi : une semaine de la démo déjà bien remplie (un lundi,
    // la semaine en cours serait vide et les widgets ne montreraient rien).
    final maintenant = DateTime.now();
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day - (maintenant.weekday + 1) % 7, 20);
    await t.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Store>.value(value: data.store),
          ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
          ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
          ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
          ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
          ChangeNotifierProvider<ProgramRepo>.value(value: data.programs),
          ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(const Color(0xFFFF5A5F)),
          home: RepaintBoundary(
            key: cadre,
            child: ColoredBox(
              color: const Color(0xFF3B3A44),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [for (final w in WidgetEcran.values) RepaintBoundary(key: cles[w], child: vueEcran(w, jour))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 16; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
    for (final w in WidgetEcran.values) {
      expect(cheminEcran(t.element(find.byType(VueLancer)), w, jour), startsWith('/'));
    }
    final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cadre));
    final img = await t.runAsync(() => ro.toImage(pixelRatio: 1.5));
    final octets = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    (File('build/rendus/ecran_accueil/planche.png')..parent.createSync(recursive: true)).writeAsBytesSync(octets!.buffer.asUint8List());
    // Chaque widget seul : ce sont les aperçus du sélecteur de widgets d'Android
    // (à recopier dans android/app/src/main/res/drawable-nodpi/widget_apercu_<cle>.png).
    for (final w in WidgetEcran.values) {
      final r = t.renderObject<RenderRepaintBoundary>(find.byKey(cles[w]!));
      final image = await t.runAsync(() => r.toImage(pixelRatio: 3));
      final png = await t.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File('build/rendus/ecran_accueil/${w.cle}.png').writeAsBytesSync(png!.buffer.asUint8List());
    }

    // Le widget record en mouvement, pour le README : toutes les images de
    // l'animation de son exercice, en pleine définition (sur le téléphone,
    // l'atelier n'en garde que douze, limite de mémoire d'Android oblige).
    final media = dernierRecord(t.element(find.byType(VueLancer))).media;
    if (media != null && media.endsWith('.webp') && File(media).existsSync()) {
      final codec = (await t.runAsync(() => ui.instantiateImageCodec(File(media).readAsBytesSync())))!;
      final n = codec.frameCount;
      var k = 0;
      for (var i = 0; i < n; i++) {
        final trame = (await t.runAsync(codec.getNextFrame))!.image;
        final cle = GlobalKey();
        await t.pumpWidget(
          MultiProvider(
            providers: [
              Provider<Store>.value(value: data.store),
              ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
              ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
              ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
              ChangeNotifierProvider<RoutineRepo>.value(value: data.routines),
              ChangeNotifierProvider<ProgramRepo>.value(value: data.programs),
              ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark(const Color(0xFFFF5A5F)),
              home: Center(child: RepaintBoundary(key: cle, child: vueEcran(WidgetEcran.recordLarge, jour, image: trame))),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 50));
        final r = t.renderObject<RenderRepaintBoundary>(find.byKey(cle));
        final image = await t.runAsync(() => r.toImage(pixelRatio: 3));
        final png = await t.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('build/rendus/ecran_accueil/recordl-a${(k++).toString().padLeft(2, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      expect(k, n);
      expect(t.takeException(), isNull);
    }
  });
}
