import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aesthetic/app/app.dart';
import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/core/theme/accent_controller.dart';
import 'package:aesthetic/core/ui/body/body_map.dart';
import 'package:aesthetic/features/import/data/fichiers.dart';
import 'package:aesthetic/features/import/data/import_flow.dart';
import 'package:aesthetic/features/inscription/data/draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Premier lancement de bout en bout, comme sur le téléphone : stockage vide,
/// vrai routeur, inscription étape par étape au doigt, import d'un CSV depuis
/// l'étape « Historique », création du profil, puis les séances importées sur
/// l'accueil, dans Progrès et dans le calendrier.
///
/// Images dans build/rendus/donnees/ (toujours écrites : le parcours est court).

class _FauxFichiers extends Fichiers {
  const _FauxFichiers(this.nom, this.octets);
  final String nom;
  final Uint8List octets;

  @override
  Future<FichierLu?> choisir() async => (nom: nom, octets: octets);
}

Future<void> _police(String famille, List<String> fichiers) async {
  final l = FontLoader(famille);
  for (final f in fichiers) {
    final file = File(f);
    if (file.existsSync()) l.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await l.load();
}

final _k = GlobalKey();

String _jour(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Le fichier d'essai du format A, ramené à ces derniers jours pour que ses
/// séances tombent dans la semaine et le mois affichés.
({Uint8List octets, List<DateTime> jours}) _fichierRecent() {
  final now = DateTime.now();
  final j = [for (final n in [4, 2, 1]) DateTime(now.year, now.month, now.day).subtract(Duration(days: n))];
  final csv = File('test/fixtures/format_a.csv')
      .readAsStringSync()
      .replaceAll('2026-03-18', _jour(j[0]))
      .replaceAll('2026-03-20', _jour(j[1]))
      .replaceAll('2026-03-22', _jour(j[2]));
  return (octets: Uint8List.fromList(utf8.encode(csv)), jours: j);
}

void main() {
  for (final (largeur, hauteur, nom) in [(360.0, 780.0, '360'), (412.0, 915.0, '412'), (840.0, 900.0, '840')]) {
    testWidgets('premier lancement, inscription, import, accueil ($nom de large)', (t) async {
      t.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (msg) async {
        final cle = Uri.decodeFull(utf8.decode(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes)));
        final f = File('build/unit_test_assets/$cle');
        if (f.existsSync()) return ByteData.sublistView(f.readAsBytesSync());
        if (cle.endsWith('.json')) return ByteData.sublistView(Uint8List.fromList(utf8.encode('[]')));
        return null;
      });
      await t.runAsync(() async {
        await initializeDateFormatting('fr_FR');
        await _police('Figtree', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Figtree-$w.ttf']);
        await _police('Montserrat', [for (final w in ['SemiBold', 'Bold', 'ExtraBold', 'Black']) 'assets/fonts/Montserrat-$w.ttf']);
        await _police('MaterialIcons', ['C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
        for (final v in BodyView.values) {
          for (final f in BodyFraming.values) {
            await BodyImageRepository.load(v, f).timeout(const Duration(seconds: 3)).then<void>((_) {}, onError: (_) {});
          }
        }
      });
      t.view.physicalSize = Size(largeur, hauteur);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final fichier = _fichierRecent();
      final anciens = Fichiers.courant;
      Fichiers.courant = _FauxFichiers('mon-export.csv', fichier.octets);
      ImportFlow.enIsolat = false;
      addTearDown(() {
        Fichiers.courant = anciens;
        ImportFlow.enIsolat = true;
      });

      final erreurs = <String>[];
      var etapeCourante = 'montage';
      void verifier() {
        final e = t.takeException();
        if (e != null) erreurs.add('$e');
        if (erreurs.isNotEmpty) {
          final copie = [...erreurs];
          erreurs.clear();
          fail('[$etapeCourante] ${copie.join(' | ')}');
        }
      }

      Future<void> pomper([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await t.pump(const Duration(milliseconds: 250));
        }
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump(const Duration(milliseconds: 250));
      }

      var numero = 0;
      Future<void> image(String n) async {
        etapeCourante = n;
        verifier();
        numero++;
        await t.runAsync(() async {
          final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_k));
          final img = await ro.toImage(pixelRatio: 1);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          (File('build/rendus/donnees/$nom-${numero.toString().padLeft(2, '0')}-$n.png')..parent.createSync(recursive: true))
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      Future<void> toucher(String texte) async {
        final f = find.text(texte);
        expect(f, findsWidgets, reason: '[$etapeCourante] « $texte » introuvable');
        await t.ensureVisible(f.first);
        await t.pump();
        await t.tap(f.first);
        await pomper();
      }

      GoRouter routeur() => GoRouter.of(t.element(find.byType(Scaffold).first));
      String lieu() => routeur().routerDelegate.currentConfiguration.last.matchedLocation;

      // Stockage vide : l'appli s'ouvre sur l'inscription.
      final data = AppData(Store.memory());
      await t.runAsync(data.loadAll);
      expect(data.exercises.catalogue, isNotEmpty, reason: 'catalogue d\'exercices absent du banc');
      await t.pumpWidget(RepaintBoundary(key: _k, child: AestheticApp(data: data, accent: AccentController())));
      await pomper();
      expect(lieu(), '/bienvenue');
      await image('bienvenue');
      await toucher('Commencer');
      expect(lieu(), '/bienvenue/profil');

      Future<void> etape(int n, String capture, {String? choisir, Future<void> Function()? agir, String suite = 'Continuer'}) async {
        etapeCourante = 'étape $n ($capture)';
        expect(find.text('Étape $n sur 13'), findsOneWidget, reason: '[$etapeCourante] mauvaise étape');
        if (agir != null) await agir();
        if (choisir != null) await toucher(choisir);
        await image('etape-${n.toString().padLeft(2, '0')}-$capture');
        // Certaines étapes avancent seules après un choix.
        if (find.text('Étape $n sur 13').evaluate().isNotEmpty) await toucher(suite);
        verifier();
      }

      await etape(1, 'prenom', agir: () async {
        // Sans prénom, on ne peut pas continuer.
        await toucher('Continuer');
        expect(find.text('Étape 1 sur 13'), findsOneWidget);
        await t.enterText(find.byType(TextField).first, 'Tristan');
        await pomper(2);
      });
      await etape(2, 'sexe', choisir: 'Homme');
      await etape(3, 'naissance');
      await etape(4, 'taille');
      await etape(5, 'poids');
      await etape(6, 'objectif', choisir: 'Prendre du muscle');
      await etape(7, 'niveau', choisir: 'Intermédiaire');
      // Musculation seule : ni le quotidien ni la nutrition ne sont demandés.
      await etape(8, 'frequence');
      await etape(9, 'materiel', choisir: 'Salle complète');
      await etape(10, 'muscles');

      // Étape 11 : l'historique. On part importer, le brouillon doit survivre.
      etapeCourante = 'étape 11 (historique)';
      expect(find.text('Étape 11 sur 13'), findsOneWidget);
      await image('etape-11-historique');
      await toucher('Choisir un fichier');
      expect(lieu(), startsWith('/import'));
      await image('import-accueil');
      await toucher('Mon ancienne appli');
      await image('import-fichier');
      await toucher('Parcourir');
      etapeCourante = 'aperçu';
      expect(lieu(), '/import/apercu', reason: ImportFlow.instance.erreur);
      await image('import-apercu');
      final flow = ImportFlow.instance;
      expect(flow.rapport!.seances, 3);
      final seriesDuFichier = flow.preview!.aImporter.fold<int>(0, (n, s) => n + s.nombreSeries);
      final aConfirmer = flow.rapport!.aConfirmer.length;
      await toucher(aConfirmer > 0 ? 'Vérifier ${aConfirmer == 1 ? '1 exercice' : '$aConfirmer exercices'}' : 'Continuer');
      etapeCourante = 'exercices';
      if (lieu() == '/import/exercices') {
        await image('import-exercices');
        for (final l in ['Tout accepter', 'Accepter les suggestions']) {
          if (find.text(l).evaluate().isNotEmpty) await toucher(l);
        }
        if (find.text('Créer les inconnus').evaluate().isNotEmpty) {
          await toucher('Créer les inconnus');
          await image('import-creer-inconnus');
          // Confirmation : le bouton de la boîte de dialogue.
          final boutons = find.descendant(of: find.byType(Dialog), matching: find.byType(InkWell));
          if (boutons.evaluate().isNotEmpty) {
            await t.tap(boutons.last);
            await pomper();
          }
        }
        // « Tout accepter » ne prend que les suggestions sûres : les autres se
        // confirment une par une (ici, la première proposée pour chaque nom).
        if (flow.rapport!.aConfirmer.isNotEmpty) {
          flow.accepterSuggestions(toutes: true);
          await pomper();
        }
        expect(flow.rapport!.aConfirmer, isEmpty, reason: 'il reste des noms à confirmer après les deux boutons');
        await image('import-exercices-prets');
        await toucher('Continuer');
      }
      etapeCourante = 'options';
      expect(lieu(), '/import/options');
      await image('import-options');
      await toucher('Importer 3 séances');
      await pomper(12);
      etapeCourante = 'résumé';
      expect(lieu(), '/import/resume', reason: flow.erreurImport);
      await image('import-resume');
      expect(data.sessions.sessions, hasLength(3));
      expect(data.sessions.sessions.expand((s) => s.exercices).expand((e) => e.series).length, seriesDuFichier);
      await toucher('Continuer');

      // Retour dans l'inscription, à la même étape, avec les réponses gardées.
      etapeCourante = 'retour à l\'inscription';
      expect(lieu(), '/bienvenue/profil');
      expect(find.text('Étape 11 sur 13'), findsOneWidget, reason: 'le parcours n\'a pas repris à l\'étape Historique');
      expect(find.textContaining('3 séances dans ton historique'), findsOneWidget);
      await image('etape-11-historique-importe');
      final brouillon = Draft.fromJson((await data.store.readObject(Draft.collection))!);
      expect(brouillon.prenom, 'Tristan');
      expect(brouillon.sexe, Sexe.homme);
      expect(brouillon.objectif, Objectif.prendreDuMuscle);
      await toucher('Continuer');
      await etape(12, 'autorisations', suite: 'Passer');
      etapeCourante = 'récapitulatif';
      expect(find.text('Étape 13 sur 13'), findsOneWidget);
      expect(find.textContaining('Tristan'), findsWidgets);
      await image('etape-13-recapitulatif');
      await toucher('Créer mon profil');
      await pomper(8);

      etapeCourante = 'programme conseillé';
      expect(data.profile.hasProfile, isTrue);
      expect(data.profile.profile!.prenom, 'Tristan');
      expect(await data.store.readObject(Draft.collection), isNull, reason: 'le brouillon doit disparaître une fois le profil créé');
      expect(lieu(), startsWith('/bienvenue/programme'));
      await image('programme');
      await toucher('Plus tard');

      // L'accueil, avec les séances importées.
      etapeCourante = 'accueil';
      expect(lieu(), '/');
      await pomper(8);
      await image('accueil');
      final noms = data.sessions.sessions.map((s) => s.nom).toList();
      expect(noms, ['Jambes', 'Tirage B', 'Poussée A, lourde']);
      bool visible(String nom) =>
          find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toLowerCase().contains(nom.toLowerCase())).evaluate().isNotEmpty ||
          find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().toLowerCase().contains(nom.toLowerCase())).evaluate().isNotEmpty;
      expect(visible('Jambes'), isTrue, reason: 'la dernière séance importée n\'apparaît pas sur l\'accueil');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await pomper(3);
      await image('accueil-bas');
      expect(visible('Tirage B') || visible('Jambes'), isTrue);

      // Progrès.
      etapeCourante = 'progrès';
      await toucher('Progrès');
      expect(lieu(), '/progres');
      await pomper(6);
      await image('progres');

      // Calendrier : chaque jour du fichier porte sa séance.
      etapeCourante = 'calendrier';
      routeur().push('/progres/calendrier');
      await pomper(8);
      await image('calendrier');
      for (final j in fichier.jours) {
        expect(data.sessions.sessionsOn(j), hasLength(1), reason: 'pas de séance le ${_jour(j)}');
      }
      final nomDuJour = data.sessions.sessionsOn(fichier.jours.last).single.nom;
      final chiffre = find.text('${fichier.jours.last.day}');
      if (chiffre.evaluate().isNotEmpty && find.text(nomDuJour).evaluate().isEmpty) {
        await t.tap(chiffre.first, warnIfMissed: false);
        await pomper(4);
        await image('calendrier-jour');
      }
      verifier();

      // Relance de l'appli sur le même stockage : tout est encore là.
      etapeCourante = 'relance';
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
      final relance = AppData(data.store);
      await t.runAsync(relance.loadAll);
      expect(relance.profile.profile!.prenom, 'Tristan');
      expect(relance.sessions.sessions, hasLength(3));
      expect(relance.sessions.sessions.every((s) => s.source == 'import'), isTrue);
      expect(relance.health.latestWeight, isNotNull, reason: 'la première pesée vient du profil');
    });
  }
}
