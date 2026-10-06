import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/app/navigation.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_images.dart';
import 'package:aesthetic/core/ui/ui.dart';
import 'package:aesthetic/features/aujourdhui/pages/aujourdhui_page.dart';
import 'package:aesthetic/features/aujourdhui/widgets/accueil.dart';
import 'package:aesthetic/features/entrainer/accueil/entrainer_page.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/bibliotheque.dart';
import 'package:aesthetic/features/entrainer/bibliotheque/pages/exercise_browser.dart';
import 'package:aesthetic/features/entrainer/commun/elements.dart';
import 'package:aesthetic/features/entrainer/routines/pages/programme_page.dart';
import 'package:aesthetic/features/entrainer/routines/routines.dart';
import 'package:aesthetic/features/profil/mensurations/mensurations_page.dart';
import 'package:aesthetic/features/profil/mensurations/mesure_page.dart';
import 'package:aesthetic/features/profil/mensurations/saisie_page.dart';
import 'package:aesthetic/features/profil/pages/profil_page.dart';
import 'package:aesthetic/features/profil/pages/reglages_page.dart';
import 'package:aesthetic/features/profil/photos/photos_page.dart';
import 'package:aesthetic/features/progres/ui/bilan/bilan_story_page.dart';
import 'package:aesthetic/features/progres/ui/calendrier_page.dart';
import 'package:aesthetic/features/progres/ui/progres_page.dart';
import 'package:aesthetic/features/sante/recuperation/recuperation_page.dart';
import 'package:aesthetic/features/sante/recuperation/tous_muscles_page.dart';
import 'package:aesthetic/features/seance/logic/repos_minuteur.dart';
import 'package:aesthetic/features/seance/pages/apercu_page.dart';
import 'package:aesthetic/features/seance/pages/equivalent_page.dart';
import 'package:aesthetic/features/seance/pages/remplacer_page.dart';
import 'package:aesthetic/features/seance/pages/resume_page.dart';
import 'package:aesthetic/features/seance/pages/seance_page.dart';
import 'package:aesthetic/features/seance/pages/terminer_page.dart';
import 'package:aesthetic/features/aujourdhui/pages/serie_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Parcours de bout en bout : l'appli entière, le vrai routeur, les données
/// de la démo et les vraies polices. Chaque étape vérifie qu'aucune
/// exception n'a été levée (débordement, route inconnue) ; le parcours est
/// joué en 412 puis en 360 de large, puis sur le Fold ouvert (700, 840 et 1000
/// de large), en paysage (915 sur 412) et avec le texte du système agrandi
/// (1,3 et 1,6).
///
/// Chaque écran traversé est aussi photographié et audité : textes coupés,
/// cibles tactiles sous 44 points, boutons sans libellé. Le relevé est écrit
/// dans `build/rendus/parcours/rapport-<config>.txt` (il n'échoue pas le test).
///
/// Il traverse tous les modules : s'il casse sans changement ici, regarder
/// l'étape nommée dans le message.

Future<void> _police(String famille, List<String> fichiers) async {
  final l = FontLoader(famille);
  for (final f in fichiers) {
    final file = File(f);
    if (file.existsSync()) l.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> _polices() async {
  await initializeDateFormatting('fr_FR');
  await _police('Figtree', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Figtree-$w.ttf']);
  await _police('Montserrat', [for (final w in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Montserrat-$w.ttf']);
  await _police('MaterialIcons', ['C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

Future<void> _corps() async {
  Future<void> essayer(Future<Object?> f) => f.timeout(const Duration(seconds: 3)).then<void>((_) {}, onError: (_) {});
  for (final f in BodyFraming.values) {
    for (final v in BodyView.values) {
      await essayer(BodyImageRepository.load(v, f));
    }
  }
}

final _cleCapture = GlobalKey();

class _Parcours {
  _Parcours(this.t, this.config);

  final WidgetTester t;

  /// « 412x915 », « 412x915-t130 » : préfixe des images et du rapport.
  final String config;
  final problemes = <String>[];
  String _etape = 'montage';
  int _numero = 0;

  // Relevés de l'audit, sans doublon d'un écran à l'autre.
  final _coupes = <String, String>{};
  final _petites = <String, String>{};
  final _muettes = <String, String>{};

  /// Toute erreur de Flutter (débordement, exception d'un geste) est notée
  /// avec l'étape et le fichier du widget fautif.
  void erreur(FlutterErrorDetails d) {
    final texte = d.toString();
    final resume = d.exceptionAsString().split('\n').first;
    final ou = RegExp(r'([A-Za-z_]+):file:///\S*?/(lib/\S+?\.dart:\d+)').firstMatch(texte);
    final p = '[$_etape] $resume${ou == null ? '' : ' (${ou.group(1)} ${ou.group(2)})'}';
    if (!problemes.contains(p)) problemes.add(p);
  }

  /// Photographie l'écran et relève textes coupés, petites cibles et boutons
  /// sans libellé.
  Future<void> ecran(String nom) async {
    _numero++;
    await capture('${_numero.toString().padLeft(2, '0')}-$nom');
    final vue = Offset.zero & (t.view.physicalSize / t.view.devicePixelRatio);
    for (final e in find.byType(RichText).hitTestable().evaluate()) {
      final rp = e.renderObject;
      if (rp is! RenderParagraph || !rp.hasSize) continue;
      if (rp.maxLines == null && rp.softWrap && rp.overflow == TextOverflow.clip) continue;
      if (!vue.overlaps(rp.localToGlobal(Offset.zero) & rp.size)) continue;
      final tp = TextPainter(
        text: rp.text,
        textDirection: rp.textDirection,
        textScaler: rp.textScaler,
        maxLines: rp.maxLines ?? (rp.softWrap ? null : 1),
        strutStyle: rp.strutStyle,
      )..layout(maxWidth: rp.softWrap ? rp.size.width + 0.5 : double.infinity);
      final coupe = rp.softWrap ? tp.didExceedMaxLines : tp.width > rp.size.width + 0.5;
      tp.dispose();
      if (coupe) _coupes.putIfAbsent(rp.text.toPlainText().replaceAll('\n', ' '), () => nom);
    }
    final cibles = await iOSTapTargetGuideline.evaluate(t);
    for (final l in (cibles.reason ?? '').split('\n')) {
      final m = RegExp(r'but found Size\(([\d.]+), ([\d.]+)\)').firstMatch(l);
      if (m == null) continue;
      final label = RegExp(r'(?:label|tooltip|value): "([^"]*)"').firstMatch(l)?.group(1) ?? RegExp(r'Rect\.fromLTRB\([^)]*\)').firstMatch(l)?.group(0) ?? '?';
      _petites.putIfAbsent('$label : ${m.group(1)} x ${m.group(2)}', () => nom);
    }
    final muets = await labeledTapTargetGuideline.evaluate(t);
    for (final l in (muets.reason ?? '').split('\n')) {
      final m = RegExp(r'Rect\.fromLTRB\([^)]*\)').firstMatch(l);
      if (m != null && l.contains('semantic label')) _muettes.putIfAbsent('$nom ${m.group(0)}', () => nom);
    }
  }

  void _rapport() {
    final b = StringBuffer('Parcours $config\n\n');
    void bloc(String titre, Map<String, String> m) {
      b.writeln('$titre : ${m.length}');
      for (final e in m.entries) {
        b.writeln('  [${e.value}] ${e.key}');
      }
      b.writeln();
    }

    b.writeln('Erreurs : ${problemes.length}');
    problemes.forEach(b.writeln);
    b.writeln();
    bloc('Textes coupés', _coupes);
    bloc('Cibles tactiles sous 44 points', _petites);
    bloc('Zones touchables sans libellé', _muettes);
    (File('build/rendus/parcours/rapport-$config.txt')..parent.createSync(recursive: true)).writeAsStringSync(b.toString());
  }

  Future<void> pose([int tours = 3]) async {
    for (var i = 0; i < tours; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await t.pump(const Duration(milliseconds: 450));
    }
  }

  GoRouter get routeur => GoRouter.of(rootNavigatorKey.currentContext!);

  /// L'adresse de la page du dessus, y compris poussée dans un onglet.
  String get lieu {
    final conf = routeur.routerDelegate.currentConfiguration;
    String de(RouteMatchList liste) {
      RouteMatchBase dernier = liste.matches.last;
      while (dernier is ShellRouteMatch) {
        dernier = dernier.matches.last;
      }
      return dernier is ImperativeRouteMatch ? de(dernier.matches) : liste.uri.toString();
    }

    return de(conf);
  }

  /// Relève les exceptions de l'étape en cours, puis passe à la suivante.
  void etape(String nom) {
    _releve();
    _etape = nom;
  }

  void _releve() {
    Object? e;
    while ((e = t.takeException()) != null) {
      problemes.add('[$_etape] ${e.toString().split('\n').take(2).join(' ')}');
    }
    if (find.textContaining('Page Not Found').evaluate().isNotEmpty) {
      problemes.add('[$_etape] route inconnue : $lieu');
    }
  }

  void attendu(bool ok, String quoi) {
    if (!ok) problemes.add('[$_etape] attendu : $quoi (lieu : $lieu)');
  }

  void present(Finder f, String quoi) => attendu(f.evaluate().isNotEmpty, quoi);

  /// Touche [f] après l'avoir amené à l'écran ; note le manque sinon.
  Future<bool> toucher(Finder f, String quoi, {Finder? defilant}) async {
    // Liste paresseuse : on cherche vers la fin, puis vers le début.
    for (final pas in const [240.0, -240.0]) {
      if (f.evaluate().isNotEmpty || defilant == null || defilant.evaluate().isEmpty) break;
      try {
        await t.scrollUntilVisible(f, pas, scrollable: defilant.first, maxScrolls: 40);
      } catch (_) {}
      // La liste finit sa course : un appui pendant l'élan ne ferait que l'arrêter.
      await pose();
    }
    if (f.evaluate().isEmpty) {
      problemes.add('[$_etape] introuvable : $quoi (lieu : $lieu)');
      return false;
    }
    // Au milieu de la liste : ni sous un en-tête, ni sous la barre du bas.
    if (Scrollable.maybeOf(t.element(f.first)) != null) {
      await Scrollable.ensureVisible(t.element(f.first), alignment: 0.5);
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(f.first, warnIfMissed: false);
    await pose();
    return true;
  }

  /// Image de l'écran dans `build/rendus/parcours/`, pour relire la démo.
  Future<void> capture(String nom) async {
    await t.runAsync(() async {
      final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_cleCapture));
      final img = await ro.toImage(pixelRatio: t.view.physicalSize.width >= 700 ? 1 : 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      (File('build/rendus/parcours/$config-$nom.png')..parent.createSync(recursive: true)).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Finder defilantDe(Type page) => find.descendant(of: find.byType(page), matching: find.byType(Scrollable));

  /// La rangée défilante des puces (la plus proche d'une puce affichée).
  Finder get rangeePuces {
    final puces = find.byType(PuceAction);
    return puces.evaluate().isEmpty ? puces : find.ancestor(of: puces.first, matching: find.byType(Scrollable));
  }

  Future<void> retour() async {
    routeur.pop();
    await pose();
  }

  /// La barre du bas, ou le rail latéral sur écran large.
  Finder get barre => find.byWidgetPredicate((w) => w is AppBottomNav || w is AppNavRail);

  Future<void> onglet(String nom) => toucher(find.descendant(of: barre, matching: find.text(nom)), 'onglet $nom');

  /// [connus] : fichiers dont un débordement est un défaut déjà signalé à son
  /// module (texte agrandi) ; il est noté au rapport sans échouer le test.
  void fin({List<String> connus = const []}) {
    _releve();
    _rapport();
    bool connu(String p) => p.contains('overflowed') && connus.any(p.contains);
    final nouveaux = problemes.where((p) => !connu(p)).toList();
    expect(nouveaux, isEmpty, reason: '\n${nouveaux.join('\n')}');
  }
}

/// Débordements du texte agrandi déjà signalés à leur module (chemin du
/// fichier fautif) : notés au rapport sans échouer. Vide depuis que SÉANCE,
/// ENTRAÎNER et PROFIL ont corrigé les leurs ; un nouveau débordement fait donc
/// échouer le test.
const _debordementsTexteAgrandi = <String>[];

Future<void> _jouer(WidgetTester t, Size taille, {double texte = 1}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = texte;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final semantique = t.ensureSemantics();
  final p = _Parcours(t, '${taille.width.round()}x${taille.height.round()}${texte == 1 ? '' : '-t${(texte * 100).round()}'}');
  final ancienne = FlutterError.onError;
  FlutterError.onError = p.erreur;
  addTearDown(() => FlutterError.onError = ancienne);
  addTearDown(ReposMinuteur.instance.reinitialiser);
  final data = AppData(Store.memory(), demo: true);
  await t.runAsync(() async {
    await _polices();
    await data.loadAll();
    await DemoData.seed(data);
    await _corps();
  });
  await t.pumpWidget(RepaintBoundary(key: _cleCapture, child: AestheticApp(data: data, accent: AccentController())));
  await p.pose();
  final maintenant = DateTime.now();

  // 1. Les quatre onglets.
  p.etape('onglets');
  p.present(find.byType(AujourdhuiPage), 'accueil au démarrage');
  await p.onglet('Entraînement');
  p.present(find.byType(EntrainerPage), 'page Entraîner');
  await p.ecran('entrainer');
  await p.onglet('Progrès');
  p.present(find.byType(ProgresPage), 'page Progrès');
  await p.ecran('progres');
  await p.onglet('Profil');
  p.present(find.byType(ProfilPage), 'page Profil');
  await p.ecran('profil');
  await p.onglet('Accueil');
  p.present(find.byType(AujourdhuiPage), 'retour à l\'accueil');
  await p.ecran('accueil');

  // 2. Accueil : la carte bleue (du 1er au 3 du mois), le bilan du mois.
  p.etape('accueil, carte bleue et bilan du mois');
  final carte = find.descendant(of: find.byType(AujourdhuiPage), matching: find.byType(CarteResumeMensuel));
  if (maintenant.day <= 3) {
    await p.toucher(carte, 'carte « Résumé mensuel »');
  } else {
    // Passé le 3, l'accueil ne la montre plus : même route, ouverte à la main.
    p.attendu(carte.evaluate().isEmpty, 'pas de carte bleue après le 3 du mois');
    final avant = DateTime(maintenant.year, maintenant.month - 1);
    p.routeur.push('/progres/bilan?mois=${avant.year}-${avant.month}');
    await p.pose();
  }
  p.present(find.byType(BilanStoryPage), 'bilan du mois');
  await p.ecran('bilan-1');
  p.attendu(find.byType(AppBottomNav).hitTestable().evaluate().isEmpty, 'bilan en plein écran');
  for (var i = 2; i <= 5; i++) {
    await t.tapAt(Offset(taille.width * 0.8, taille.height * 0.5));
    await p.pose(2);
    p.present(find.bySemanticsLabel('Page $i sur 10'), 'page $i du bilan');
    await p.ecran('bilan-$i');
    p.etape('bilan du mois, page $i');
  }
  await p.toucher(find.byTooltip('Fermer le bilan'), 'croix du bilan');
  p.attendu(p.lieu == '/', 'la croix rend la main à l\'accueil');

  // La flamme ouvre la page « série de semaines ».
  p.etape('accueil, flamme');
  await p.toucher(find.descendant(of: find.byType(EnTeteAccueil), matching: find.byType(InkWell)), 'flamme', defilant: p.defilantDe(AujourdhuiPage));
  p.attendu(p.lieu == '/aujourdhui/serie', 'page de la série ouverte par la flamme');
  p.present(find.byType(SeriePage), 'page de la série');
  // En paysage, le titre du calendrier est sous le pli : la liste ne le
  // construit qu'en défilant.
  p.present(find.text('Calendrier de la série', skipOffstage: false), 'calendrier de la série');
  await p.ecran('serie');
  await p.toucher(find.bySemanticsLabel('Retour'), 'retour de la série');
  p.attendu(p.lieu == '/', 'retour à l\'accueil après la flamme');

  // « Voir plus » : le bilan de la semaine, dans l'onglet Progrès.
  p.etape('accueil, voir plus');
  await p.toucher(find.text('Voir plus'), '« Voir plus »');
  p.attendu(p.lieu == '/progres/semaine', 'bilan de la semaine');
  await p.ecran('semaine');
  await p.onglet('Accueil');

  // 3. Accueil : une séance passée.
  p.etape('accueil, séance passée');
  await p.toucher(find.byType(CarteSeance), 'carte de séance', defilant: p.defilantDe(AujourdhuiPage));
  p.attendu(p.lieu.startsWith('/seance/resume/'), 'bilan de la séance passée');
  p.present(find.byType(ResumePage), 'page du bilan de séance');
  await p.ecran('seance-passee');
  await p.toucher(find.text('Fermer'), 'bouton Fermer du bilan');
  p.attendu(p.lieu == '/', 'retour à l\'accueil');

  // 4. Entraîner : programme, routine, séance complète.
  p.etape('entraîner, programmes');
  await p.onglet('Entraînement');
  // La démo fait la même routine ce jour de la semaine : elle est proposée.
  await p.toucher(find.descendant(of: find.byType(SelecteurSegmente<VoletEntrainer>), matching: find.text('Routines')), 'volet Routines');
  p.present(find.text('Commencer'), 'suggestion de la routine du jour');
  await p.ecran('routines');
  await p.toucher(find.descendant(of: find.byType(SelecteurSegmente<VoletEntrainer>), matching: find.text('Programmes')), 'volet Programmes');
  await p.ecran('programmes');
  final programme = data.programs.programs.first;
  final faitesAvant = programme.seancesFaites;
  await p.toucher(find.text(programme.nom), 'programme de la démo');
  p.present(find.byType(ProgrammePage), 'page du programme');
  await p.ecran('programme');
  p.etape('entraîner, programme vers routine');
  await p.toucher(find.byType(LigneRoutine), 'routine du programme', defilant: p.defilantDe(ProgrammePage));
  p.present(find.byType(ApercuPage), '« Lancer la séance »');
  await p.ecran('apercu');
  p.attendu(p.lieu.contains('programme=${programme.id}'), 'aperçu lancé depuis le programme');
  p.etape('lancer la séance');
  await p.toucher(find.text('Commencer la séance'), '« Commencer la séance »');
  p.present(find.byType(SeancePage), 'saisie des séries');
  await p.ecran('seance');
  p.attendu(data.sessions.active?.programId == programme.id, 'séance rattachée au programme');

  // La fiche depuis l'image, puis « Remplacer » : l'écran de la séance.
  p.etape('séance, fiche et remplacer');
  await p.toucher(find.bySemanticsLabel('Ouvrir la fiche de l\'exercice'), 'image de l\'exercice');
  p.present(find.byType(ExerciseDetailPage), 'fiche ouverte depuis la séance');
  await p.ecran('fiche-depuis-seance');
  // En paysage, les raccourcis sont sous l'image : on fait défiler la fiche.
  final fiche = find.descendant(
    of: find.byType(ExerciseDetailPage),
    matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
  );
  for (var i = 0; i < 6 && find.byType(PuceAction).hitTestable().evaluate().isEmpty && fiche.evaluate().isNotEmpty; i++) {
    await t.drag(fiche.first, const Offset(0, -160), warnIfMissed: false);
    await p.pose(1);
  }
  await p.toucher(find.widgetWithText(PuceAction, 'Remplacer'), 'raccourci Remplacer de la fiche', defilant: p.rangeePuces);
  p.present(find.byType(RemplacerPage), '« Remplacer un exercice »');
  await p.ecran('remplacer');
  p.attendu(find.byType(ExerciseDetailPage).evaluate().isEmpty, 'fiche refermée');
  Navigator.of(appNavigatorKey.currentContext!).pop();
  await p.pose();
  p.present(find.byType(SeancePage), 'retour à la saisie');

  p.etape('séance, valider une série');
  p.attendu(!ReposMinuteur.instance.actif, 'pas de repos avant la première série');
  await p.toucher(find.bySemanticsLabel('Valider la série'), 'coche de la série');
  p.attendu(ReposMinuteur.instance.actif, 'le repos démarre');
  // La première est un échauffement (hors volume) : une série de travail aussi.
  await p.toucher(find.bySemanticsLabel('Valider la série'), 'coche de la deuxième série');
  p.attendu(data.sessions.active!.exercices.any((e) => e.seriesFaites.isNotEmpty), 'série validée');
  await p.ecran('seance-series-validees');

  p.etape('séance, terminer');
  await p.toucher(find.text('Terminer'), 'bouton Terminer');
  p.present(find.byType(TerminerPage), '« Terminer la séance »');
  await p.ecran('terminer');
  await p.toucher(find.text('Enregistrer'), 'bouton Enregistrer', defilant: p.defilantDe(TerminerPage));
  p.attendu(data.sessions.active == null, 'séance close');
  final faite = data.sessions.sessions.first;
  p.attendu(data.programs.byId(programme.id)!.seancesFaites == faitesAvant + 1, 'programme avancé d\'une séance');

  p.etape('carte « équivalent »');
  p.present(find.byType(EquivalentPage), 'carte de fin de séance');
  await p.ecran('equivalent');
  p.attendu(p.lieu == '/seance/equivalent/${faite.id}', 'route de la carte');
  await p.toucher(find.bySemanticsLabel('Fermer'), 'croix de la carte');
  p.etape('bilan de séance');
  p.present(find.byType(ResumePage), 'bilan de séance');
  await p.ecran('bilan-seance');
  p.attendu(p.lieu.startsWith('/seance/resume/${faite.id}'), 'route du bilan');
  await p.toucher(find.text('Fermer'), 'bouton Fermer du bilan', defilant: p.defilantDe(ResumePage));
  p.attendu(p.lieu == '/', 'retour à l\'accueil après la séance');

  // 5. Entraîner : bibliothèque, fiche et ses onglets.
  p.etape('entraîner, exercices');
  await p.onglet('Entraînement');
  await p.toucher(find.descendant(of: find.byType(SelecteurSegmente<VoletEntrainer>), matching: find.text('Exercices')), 'volet Exercices');
  await p.ecran('exercices');
  // L'explorateur de muscles (la puce « Muscles » a été retirée : on y
  // vient par la récupération).
  p.etape('entraîner, explorateur de muscles');
  p.routeur.go('/entrainer/muscles');
  await p.pose();
  p.present(find.byType(MusclesPage), 'explorateur de muscles');
  await p.ecran('muscles');
  p.attendu(p.lieu.startsWith('/entrainer/muscles'), 'route de l\'explorateur');
  p.routeur.go('/entrainer?onglet=exercices');
  await p.pose();

  // 6. Entraîner : une fiche et ses onglets.
  p.etape('entraîner, fiche');
  // En paysage, les cartes sont sous les raccourcis : on fait défiler la liste.
  await p.toucher(find.byType(CarteExercice), 'carte d\'exercice', defilant: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)));
  p.present(find.byType(ExerciseDetailView), 'fiche d\'exercice');
  await p.ecran('fiche');
  for (final nom in ['Historique', 'Progrès', 'Records', 'À propos']) {
    p.etape('fiche, onglet $nom');
    await p.toucher(find.descendant(of: find.byType(ExerciseDetailView), matching: find.text(nom)), 'onglet $nom');
    await p.ecran('fiche-${nom.toLowerCase().replaceAll(' ', '-')}');
  }
  Navigator.of(appNavigatorKey.currentContext!).pop();
  await p.pose();

  // 7. Progrès : calendrier, récupération, tous les muscles, un muscle.
  p.etape('progrès, calendrier');
  await p.onglet('Progrès');
  // Le calendrier est sur la vue Mois.
  await p.toucher(find.descendant(of: find.byType(ProgresPage), matching: find.text('Mois')), 'période Mois');
  await p.toucher(find.text('Détail'), 'lien Détail du calendrier', defilant: p.defilantDe(ProgresPage));
  p.present(find.byType(CalendrierPage), 'calendrier');
  await p.ecran('calendrier');
  await p.retour();
  p.etape('progrès, récupération');
  await p.toucher(find.descendant(of: find.byType(ProgresPage), matching: find.text('Récupération')), 'tuile Récupération', defilant: p.defilantDe(ProgresPage));
  p.present(find.byType(RecuperationPage), 'récupération');
  await p.ecran('recuperation');
  await p.toucher(find.text('Tout afficher'), '« Tout afficher »', defilant: p.defilantDe(RecuperationPage));
  p.etape('progrès, tous les muscles');
  p.present(find.byType(TousLesMusclesPage), 'tous les muscles');
  await p.ecran('tous-les-muscles');
  await p.toucher(find.byType(VignetteMuscle), 'vignette d\'un muscle');
  p.etape('progrès, un muscle');
  p.present(find.byType(MusclesPage), 'explorateur ouvert sur le muscle');
  await p.ecran('un-muscle');
  p.attendu(p.lieu.startsWith('/entrainer/muscles?muscle='), 'route du muscle');

  // 8. Progrès : mensurations, une mesure, modifier une saisie.
  p.etape('progrès, mensurations');
  // On revient à la page d'entrée de l'onglet, où sont les tuiles.
  p.routeur.go('/progres');
  await p.pose();
  await p.toucher(find.descendant(of: find.byType(ProgresPage), matching: find.text('Mensurations')), 'tuile Mensurations', defilant: p.defilantDe(ProgresPage));
  p.present(find.byType(MensurationsPage), 'mensurations');
  await p.ecran('mensurations');
  p.attendu(p.lieu == '/profil/mensurations', 'route des mensurations');
  p.etape('profil, une mesure');
  await p.toucher(find.descendant(of: find.byType(CorpsMesures), matching: find.text('Poitrine')), 'étiquette Poitrine');
  p.present(find.byType(MesurePage), 'page d\'une mesure');
  await p.ecran('mesure');
  p.etape('profil, modifier une saisie');
  await p.toucher(find.bySemanticsLabel(RegExp(r'^Modifier la mesure du ')), 'crayon d\'une saisie', defilant: p.defilantDe(MesurePage));
  p.present(find.byType(SaisiePage), 'saisie à modifier');
  await p.ecran('saisie');
  final toursAvant = data.health.measurements.map((m) => m.tours[TourCorps.poitrine]).whereType<double>().toList();
  await p.toucher(find.bySemanticsLabel('Augmenter Poitrine'), '« + » de la poitrine', defilant: p.defilantDe(SaisiePage));
  await p.toucher(find.text('Enregistrer'), 'bouton Enregistrer');
  final toursApres = data.health.measurements.map((m) => m.tours[TourCorps.poitrine]).whereType<double>().toList();
  p.attendu(toursApres.fold(0.0, (a, b) => a + b) == toursAvant.fold(0.0, (a, b) => a + b) + 0.5, 'un demi-centimètre de plus');
  p.attendu(find.byType(SaisiePage).evaluate().isEmpty, 'saisie refermée');
  p.present(find.byType(MesurePage), 'retour à la mesure');
  await p.retour();
  await p.retour();
  p.present(find.byType(ProgresPage), 'retour à Progrès');

  // 9. Progrès : photos.
  p.etape('progrès, photos');
  await p.toucher(find.descendant(of: find.byType(ProgresPage), matching: find.text('Photos')), 'tuile Photos', defilant: p.defilantDe(ProgresPage));
  p.present(find.byType(PhotosPage), 'photos');
  p.present(find.byType(VignettePhoto), 'photos de la démo');
  await p.ecran('photos');
  await p.retour();

  // 10. Profil : réglages.
  p.etape('profil, réglages');
  await p.onglet('Profil');
  await p.toucher(find.descendant(of: find.byType(ProfilPage), matching: find.byTooltip('Réglages')), 'roue des réglages', defilant: p.defilantDe(ProfilPage));
  p.present(find.byType(ReglagesPage), 'réglages');
  await p.ecran('reglages');
  p.attendu(p.lieu == '/reglages', 'route des réglages');
  await p.retour();
  p.present(find.byType(ProfilPage), 'retour au profil');

  p.etape('fin');
  ReposMinuteur.instance.reinitialiser();
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
  semantique.dispose();
  FlutterError.onError = ancienne;
  p.fin(connus: texte == 1 ? const [] : _debordementsTexteAgrandi);
}

void main() {
  testWidgets('parcours de bout en bout, 412 de large', (t) => _jouer(t, const Size(412, 915)));
  testWidgets('parcours de bout en bout, 360 de large', (t) => _jouer(t, const Size(360, 780)));

  // Le Fold ouvert : entre deux seuils (700), au seuil du rail (840), au-delà.
  testWidgets('parcours, Fold ouvert, 700 de large', (t) => _jouer(t, const Size(700, 900)));
  testWidgets('parcours, Fold ouvert, 840 de large', (t) => _jouer(t, const Size(840, 900)));
  testWidgets('parcours, 1000 de large', (t) => _jouer(t, const Size(1000, 800)));
  testWidgets('parcours, paysage, 915 sur 412', (t) => _jouer(t, const Size(915, 412)));

  // Le réglage système de taille du texte. L'appli le plafonne à 1,3
  // (AestheticApp.texteMax) : à 1,6 on vérifie donc le rendu plafonné. Les
  // relevés sans plafond sont dans build/rendus/transverse/texte-160-sans-plafond/.
  testWidgets('parcours, texte à 1,3 en 412', (t) => _jouer(t, const Size(412, 915), texte: 1.3));
  testWidgets('parcours, texte à 1,3 en 360', (t) => _jouer(t, const Size(360, 780), texte: 1.3));
  testWidgets('parcours, texte à 1,6 (plafonné) en 412', (t) => _jouer(t, const Size(412, 915), texte: 1.6));
  testWidgets('parcours, texte à 1,6 (plafonné) en 360', (t) => _jouer(t, const Size(360, 780), texte: 1.6));

  // La variante démo doit tout montrer, quel que soit le jour où on l'ouvre.
  testWidgets('la démo montre cardio, médias, suggestion, mensurations et photos', (t) async {
    for (var j = 0; j < 7; j++) {
      final maintenant = DateTime(2026, 10, 2 + j, 9);
      final data = AppData(Store.memory(), demo: true);
      await t.runAsync(() async {
        await data.loadAll();
        await DemoData.seed(data, now: maintenant);
      });
      final seances = data.sessions.sessions;
      final jour = 'démo ouverte un jour ${maintenant.weekday}';
      expect(seances.where((s) => s.type != TypeSeance.musculation).length, greaterThanOrEqualTo(8), reason: jour);
      final semaine = seances.where((s) => maintenant.difference(s.debut).inDays < 14);
      expect(semaine.any((s) => s.type != TypeSeance.musculation), isTrue, reason: '$jour : un cœur dans les deux dernières semaines');
      expect(seances.where((s) => s.medias.isNotEmpty).length, 3, reason: jour);
      expect(seances.expand((s) => s.medias).where((m) => !m.video).every((m) => File(m.chemin).existsSync()), isTrue, reason: jour);
      final suggestion = suggererRoutine(maintenant: maintenant, seances: seances, routinesConnues: {for (final r in data.routines.routines) r.id});
      expect(suggestion, isNotNull, reason: '$jour : une routine à proposer');
      expect(seances.any((s) => DateUtils.isSameDay(s.debut, maintenant)), isFalse, reason: '$jour : la séance du jour reste à faire');
      final tours = data.health.measurements.where((m) => m.tours.isNotEmpty).toList();
      expect(tours.length, inInclusiveRange(12, 14), reason: jour);
      expect(tours.every((m) => m.tours.length == 12 && m.tours.values.every((v) => v * 2 == (v * 2).roundToDouble())), isTrue, reason: '$jour : huit zones, au demi-centimètre');
      expect(data.health.photos.length, 9, reason: jour);
      expect(data.health.photos.every((p) => File(p.chemin).existsSync()), isTrue, reason: jour);
    }
  });
}
