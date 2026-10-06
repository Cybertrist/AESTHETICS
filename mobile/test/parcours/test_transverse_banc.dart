import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_images.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Banc des tests transverses : l'appli entière (vrai routeur, démo, vraies
/// polices), le bouton retour du téléphone, l'adresse courante, les captures.

Future<void> _police(String famille, List<String> fichiers) async {
  final l = FontLoader(famille);
  for (final f in fichiers) {
    final file = File(f);
    if (file.existsSync()) l.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> chargerPolices() async {
  await initializeDateFormatting('fr_FR');
  await _police('Figtree', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Figtree-$w.ttf']);
  await _police('Montserrat', [for (final w in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Montserrat-$w.ttf']);
  await _police('MaterialIcons', ['C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

final cleCapture = GlobalKey();

class Banc {
  Banc(this.t, this.data);

  final WidgetTester t;
  final AppData data;

  /// Nombre de fois où l'appli a demandé à se fermer (retour sans rien à
  /// dépiler).
  int sorties = 0;

  /// Monte l'appli. [profil] faux : aucun profil (premier lancement).
  static Future<Banc> monter(WidgetTester t, {Size taille = const Size(412, 915), bool profil = true, bool corps = false}) async {
    t.view.physicalSize = taille;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(ReposMinuteur.instance.reinitialiser);
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await chargerPolices();
      await data.loadAll();
      if (profil) await DemoData.seed(data);
      if (corps) {
        for (final f in BodyFraming.values) {
          for (final v in BodyView.values) {
            await BodyImageRepository.load(v, f).timeout(const Duration(seconds: 3)).then<void>((_) {}, onError: (_) {});
          }
        }
      }
    });
    final b = Banc(t, data);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (appel) async {
      if (appel.method == 'SystemNavigator.pop') b.sorties++;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.pumpWidget(RepaintBoundary(key: cleCapture, child: AestheticApp(data: data, accent: AccentController())));
    await b.pose();
    return b;
  }

  Future<void> pose([int tours = 3]) async {
    for (var i = 0; i < tours; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 450));
    }
  }

  GoRouter get routeur => GoRouter.of(rootNavigatorKey.currentContext!);

  /// L'adresse de la page du dessus, y compris poussée par `push`.
  String get lieu {
    String de(RouteMatchList liste) {
      if (liste.matches.isEmpty) return liste.uri.toString();
      RouteMatchBase dernier = liste.matches.last;
      while (dernier is ShellRouteMatch) {
        dernier = dernier.matches.last;
      }
      return dernier is ImperativeRouteMatch ? de(dernier.matches) : liste.uri.toString();
    }

    return de(routeur.routerDelegate.currentConfiguration);
  }

  Finder get barre => find.byWidgetPredicate((w) => w is AppBottomNav || w is AppNavRail);

  Future<void> onglet(String nom) async {
    await t.tap(find.descendant(of: barre, matching: find.text(nom)));
    await pose();
  }

  /// L'onglet allumé dans la barre ; « (hors onglets) » si la coquille n'est
  /// plus dans la pile.
  String get ongletActif {
    final coquilles = find.byType(StatefulNavigationShell).evaluate();
    if (coquilles.isEmpty) return '(hors onglets)';
    return AppTab.visibles[(coquilles.first.widget as StatefulNavigationShell).currentIndex].label;
  }

  Future<void> aller(String chemin) async {
    routeur.go(chemin);
    await pose();
  }

  Future<void> pousser(String chemin) async {
    routeur.push(chemin);
    await pose();
  }

  /// Le bouton retour du téléphone.
  Future<void> retourSysteme() async {
    await t.binding.handlePopRoute();
    await pose();
  }

  Future<void> capture(String nom) async {
    await t.runAsync(() async {
      final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cleCapture));
      final img = await ro.toImage(pixelRatio: t.view.physicalSize.width >= 700 ? 1 : 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      (File('build/rendus/transverse/$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// À appeler en fin de test : démonte l'appli et laisse finir les minuteurs.
  Future<void> fin() async {
    ReposMinuteur.instance.reinitialiser();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }
}
