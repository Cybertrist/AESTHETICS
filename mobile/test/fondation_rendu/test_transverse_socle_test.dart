import 'dart:io';
import 'dart:math' as math;

import 'package:aesthetic/core/theme/theme.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Socle transverse : contraste des gris, barre et rail aux tailles limites,
/// avatar, vignette d'exercice décodée à sa taille.

/// Rapport de contraste WCAG 2 entre deux couleurs opaques.
double contraste(Color a, Color b) {
  double lum(Color c) {
    double canal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> _figtree() async {
  final l = FontLoader('Figtree');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    l.addFont(File('assets/fonts/Figtree-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

Widget _appli(Widget child, {double texte = 1}) => MaterialApp(
      theme: AppTheme.dark(AccentChoice.corail.color),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(texte)),
          child: child,
        ),
      ),
    );

void main() {
  group('contraste', () {
    test('le texte secondaire (#8E8E93) passe 4,5 sur le fond, la carte et la surface', () {
      for (final (nom, fond) in [('fond', AppTokens.bg), ('carte', AppTokens.surface), ('surface2', AppTokens.surface2)]) {
        final r = contraste(AppTokens.text2, fond);
        // ignore: avoid_print
        print('text2 sur $nom : ${r.toStringAsFixed(2)}');
        expect(r, greaterThanOrEqualTo(4.5), reason: nom);
      }
    });

    test('le texte tertiaire (#7E7E84) passe 4,5 sur le fond et sur une carte', () {
      final surNoir = contraste(AppTokens.text3, AppTokens.bg);
      final surCarte = contraste(AppTokens.text3, AppTokens.surface);
      final surSurface = contraste(AppTokens.text3, AppTokens.surface2);
      // ignore: avoid_print
      print('text3 sur fond : ${surNoir.toStringAsFixed(2)}, carte : ${surCarte.toStringAsFixed(2)}, surface2 : ${surSurface.toStringAsFixed(2)}');
      expect(surNoir, greaterThanOrEqualTo(4.5));
      expect(surCarte, greaterThanOrEqualTo(4.5));
      // Il reste en retrait du texte secondaire.
      expect(surCarte, lessThan(contraste(AppTokens.text2, AppTokens.surface)));
    });

    test('les couleurs fonctionnelles restent lisibles sur une carte', () {
      for (final (nom, c) in [
        ('minuteur', AppTokens.minuteur),
        ('foretClair', AppTokens.foretClair),
        ('success', AppTokens.success),
        ('error', AppTokens.error),
        ('orange', AppTokens.orange),
      ]) {
        expect(contraste(c, AppTokens.surface), greaterThanOrEqualTo(4.5), reason: nom);
      }
      // Le vert forêt est une couleur de fond de coche : en texte sur carte, il est trop sombre.
      // ignore: avoid_print
      print('foret sur carte : ${contraste(AppTokens.foret, AppTokens.surface).toStringAsFixed(2)}, blanc sur foret : ${contraste(AppTokens.text, AppTokens.foret).toStringAsFixed(2)}');
      expect(contraste(AppTokens.bouton, AppTokens.onBouton), greaterThan(15));
    });
  });

  group('barre des onglets', () {
    testWidgets('quatre cibles d\'au moins 48 points, sans débordement, de 320 de large au texte à 1,3', (t) async {
      await t.runAsync(_figtree);
      for (final (largeur, texte) in [(320.0, 1.0), (320.0, 1.3), (360.0, 1.3), (412.0, 1.0)]) {
        t.view.physicalSize = Size(largeur, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_appli(Scaffold(bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {})), texte: texte));
        expect(t.takeException(), isNull, reason: '$largeur, texte $texte');
        for (final tab in AppTab.visibles) {
          final taille = t.getSize(find.bySemanticsLabel(tab.label));
          expect(taille.width, greaterThanOrEqualTo(48), reason: '${tab.label} en $largeur');
          expect(taille.height, greaterThanOrEqualTo(48), reason: '${tab.label} en $largeur');
        }
      }
    });

    testWidgets('le rail tient dans 300 de haut (paysage) et garde des cibles de 44', (t) async {
      await t.runAsync(_figtree);
      t.view.physicalSize = const Size(900, 300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var touche = -1;
      var avatar = 0;
      await t.pumpWidget(_appli(Scaffold(
        body: Row(children: [AppNavRail(currentIndex: 1, onTap: (i) => touche = i, onAvatarTap: () => avatar++), const Spacer()]),
      )));
      expect(t.takeException(), isNull);
      final profil = find.bySemanticsLabel('Profil');
      expect(profil, findsNWidgets(2), reason: 'l\'avatar et l\'onglet');
      for (final e in profil.evaluate()) {
        final s = e.size!;
        expect(s.width, greaterThanOrEqualTo(44));
        expect(s.height, greaterThanOrEqualTo(44));
      }
      await t.tap(profil.first);
      expect(avatar, 1);
      await t.tap(find.bySemanticsLabel('Accueil'));
      expect(touche, 0);
    });
  });

  group('composants', () {
    testWidgets('le sélecteur segmenté offre 46 de haut à l\'appui et ne coupe pas ses libellés', (t) async {
      await t.runAsync(_figtree);
      t.view.physicalSize = const Size(320, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var choisi = 'a';
      await t.pumpWidget(_appli(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(22),
            child: SelecteurSegmente<String>(
              segments: const [('a', 'Programmes'), ('b', 'Routines'), ('c', 'Exercices')],
              value: 'a',
              onChanged: (v) => choisi = v,
            ),
          ),
        ),
        texte: 1.3,
      ));
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(SelecteurSegmente<String>)).height, 46);
      // Un appui dans la marge du bac, sous le segment, compte.
      final bac = t.getRect(find.byType(SelecteurSegmente<String>));
      await t.tapAt(Offset(bac.center.dx, bac.bottom - 2));
      expect(choisi, 'b');
      // Le libellé rétrécit au lieu d'être coupé par des points de suspension.
      for (final p in t.renderObjectList<RenderParagraph>(find.descendant(of: find.byType(SelecteurSegmente<String>), matching: find.byType(RichText)))) {
        expect(p.didExceedMaxLines, isFalse);
      }
    });

    testWidgets('l\'avatar sans photo est gris, initiale blanche (pas de disque corail)', (t) async {
      await t.pumpWidget(_appli(const Center(child: UserAvatar(size: 40, name: 'tristan'))));
      final boite = t.widget<Container>(find.descendant(of: find.byType(UserAvatar), matching: find.byType(Container)));
      expect((boite.decoration! as BoxDecoration).color, AppTokens.surface2);
      expect(t.widget<Text>(find.text('T')).style!.color, AppTokens.text);
    });

    testWidgets('la vignette d\'exercice décode l\'image à sa taille d\'affichage', (t) async {
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_appli(const Center(
        child: ExerciseThumbnail(image: AssetImage('assets/exercises/poses/absente.webp'), width: 48, height: 72),
      )));
      final image = t.widget<Image>(find.byType(Image)).image;
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, 144, reason: '48 points à 3 pixels par point, et non 720');
      t.takeException();
    });
  });
}
