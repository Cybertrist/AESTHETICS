import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/logic/logic.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/features/progres/logic/bilan_mois.dart';
import 'package:aesthetic/features/progres/logic/tableau.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../aujourdhui/banc.dart';

/// Le résumé mensuel et le résumé annuel en mouvement, pour le README : les
/// dix pages de la démo, chacune filmée pendant qu'elle se construit, à
/// vingt images par seconde. Les images vont dans build/rendus/bilan/film/,
/// avec la liste que `docs/tools/bilan.sh` donne à ffmpeg.
///
/// Ne tourne que sur demande : `FILM=1 flutter test test/progres/bilan_film_test.dart`.
void main() {
  // La date des captures du README : septembre 2026 est le dernier mois fini.
  final maintenant = DateTime(2026, 10, 4, 20);
  const ecran = Size(360, 760);
  const bord = 8.0;
  const pas = Duration(milliseconds: 50);

  /// Une page tient l'écran 2,8 s : 1,5 s pour se construire, puis la pause.
  const imagesParPage = 56;
  const imagesFilmees = 34;

  Future<void> filmer(WidgetTester t, String nom, {int? annee}) async {
    await t.runAsync(polices);
    final data = AppData(Store.memory(), demo: true);
    await t.runAsync(() async {
      await data.loadAll();
      await DemoData.seed(data, now: maintenant);
      for (final v in BodyView.values) {
        for (final f in BodyFraming.values) {
          await BodyImageRepository.load(v, f);
        }
      }
    });
    t.view.physicalSize = Size(ecran.width + 2 * bord, ecran.height + 2 * bord);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cadre = GlobalKey();
    final accent = AccentController();

    Widget appli(Key cle) => RepaintBoundary(
          key: cadre,
          // Le téléphone : un bord sombre, des coins ronds, rien autour.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: const EdgeInsets.all(bord),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(44),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF34353B), Color(0xFF101114), Color(0xFF222327)],
                ),
                border: Border.all(color: const Color(0xFF3A3A3F)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: MultiProvider(
                  providers: [
                    Provider<AppData>.value(value: data),
                    Provider<Store>.value(value: data.store),
                    ChangeNotifierProvider<AccentController>.value(value: accent),
                    ChangeNotifierProvider<ProfileRepo>.value(value: data.profile),
                    ChangeNotifierProvider<SettingsRepo>.value(value: data.settings),
                    ChangeNotifierProvider<ExerciseRepo>.value(value: data.exercises),
                    ChangeNotifierProvider<SessionRepo>.value(value: data.sessions),
                    ChangeNotifierProvider<HealthRepo>.value(value: data.health),
                  ],
                  child: MaterialApp(
                    key: cle,
                    debugShowCheckedModeBanner: false,
                    theme: accent.theme,
                    locale: const Locale('fr', 'FR'),
                    supportedLocales: const [Locale('fr', 'FR')],
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: ecran, padding: const EdgeInsets.only(top: 14)),
                      child: child!,
                    ),
                    home: BilanStoryPage(mois: DateTime(2026, 9), annee: annee, maintenant: maintenant),
                  ),
                ),
              ),
            ),
          ),
        );

    Future<void> avancer() => t.tapAt(Offset(bord + ecran.width - 40, bord + ecran.height / 2));

    Future<void> laisserDecoder() async {
      for (var i = 0; i < 5; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await t.pump(const Duration(milliseconds: 400));
      }
    }

    // Un premier passage décode toutes les images (objets, vignettes, corps),
    // pour qu'aucune n'arrive en retard dans le film.
    await t.pumpWidget(appli(const ValueKey('repetition')));
    await laisserDecoder();
    for (var p = 1; p < PageBilan.values.length; p++) {
      await avancer();
      await laisserDecoder();
    }
    expect(t.takeException(), isNull);

    final dossier = Directory('build/rendus/bilan/film')..createSync(recursive: true);
    final liste = StringBuffer();
    var k = 0;
    Future<void> image({required int tenue}) async {
      final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(cadre));
      final fichier = '$nom-${(k++).toString().padLeft(4, '0')}.png';
      await t.runAsync(() async {
        final img = await ro.toImage(pixelRatio: 2);
        final octets = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        File('${dossier.path}/$fichier').writeAsBytesSync(octets!.buffer.asUint8List());
      });
      liste
        ..writeln("file '$fichier'")
        ..writeln('duration ${(tenue * pas.inMilliseconds / 1000).toStringAsFixed(2)}');
    }

    await t.pumpWidget(appli(const ValueKey('film')));
    await t.pump();
    for (var p = 0; p < PageBilan.values.length; p++) {
      if (p > 0) {
        await avancer();
        await t.pump();
      }
      for (var i = 0; i < imagesFilmees; i++) {
        final derniere = i == imagesFilmees - 1;
        await image(tenue: derniere ? imagesParPage - imagesFilmees + 1 : 1);
        await t.pump(pas);
      }
    }
    // Le format de liste de ffmpeg ignore la durée de la dernière entrée si
    // elle n'est pas répétée.
    liste.writeln("file '$nom-${(k - 1).toString().padLeft(4, '0')}.png'");
    File('${dossier.path}/$nom.txt').writeAsStringSync(liste.toString());
    expect(t.takeException(), isNull);
    expect(k, PageBilan.values.length * imagesFilmees);
  }

  final demande = Platform.environment['FILM'] != null;

  // Les chiffres de ces deux résumés, pour le schéma du README
  // (docs/tools/schemas/resume.js), qui redessine les mêmes pages.
  test('chiffres des résumés de la démo', () async {
    final data = AppData(Store.memory(), demo: true);
    await data.loadAll();
    await DemoData.seed(data, now: maintenant);
    final exos = data.exercises;
    Map<String, Object?> lire(BilanMois b, int graine) {
      final eq = equivalentPour(b.volume, graine: graine, mois: true);
      return {
        'seances': [for (final s in b.seances) {'nom': s.nom, 'minutes': s.duree.inMinutes, 'volume': s.volume.round()}],
        'nbSeances': b.nbSeances,
        'minutes': b.dureeTotale.inMinutes,
        'volume': b.volume.round(),
        'ecartSeances': b.ecartSeances,
        'ecartVolume': b.ecartVolume,
        'jours': [for (final (i, j) in b.regularite.last.jours.indexed) if (j) i + 1],
        'volumes': [for (final v in b.volumes) v.volume.round()],
        'serie': b.serieSemaines,
        'toile': [for (final a in b.toile) {'muscle': a.muscle.name, 'mois': a.mois, 'avant': a.avant}],
        'nbRecords': b.nbRecords,
        'records': [for (final r in b.records) {'id': r.exerciseId, 'nom': exos.nameOf(r.exerciseId), 'serie': Calculs.serieTexte(r.serie)}],
        'favoris': [for (final f in b.favoris) {'id': f.exerciseId, 'nom': exos.nameOf(f.exerciseId), 'series': f.series}],
        'objet': {'nom': eq.nom, 'etiquette': eq.etiquette, 'image': eq.asset.split('/').last},
      };
    }

    final mois = DateTime(2026, 9);
    final sortie = {
      'mois': lire(BilanMois.calculer(mois, data.sessions.sessions, exos.byId, now: maintenant), mois.year * 12 + mois.month),
      'annee': lire(BilanMois.calculerAnnee(2026, data.sessions.sessions, exos.byId, now: maintenant), 2026),
    };
    final texte = const JsonEncoder.withIndent(' ').convert(sortie);
    File('../docs/tools/schemas/resume.demo.json').writeAsStringSync('$texte\n');
  }, skip: !demande);
  testWidgets('film du résumé mensuel de la démo', (t) => filmer(t, 'mensuel'), skip: !demande, timeout: const Timeout(Duration(minutes: 10)));
  testWidgets('film du résumé annuel de la démo', (t) => filmer(t, 'annuel', annee: 2026), skip: !demande, timeout: const Timeout(Duration(minutes: 10)));
}
