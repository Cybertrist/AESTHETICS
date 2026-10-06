import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../core/data/data.dart';
import 'vues.dart';

/// Nom complet d'une classe Android de widget.
String classeAndroid(WidgetEcran w) => 'fr.cybertrist.aesthetic.${w.classe}';

/// « 20261005 » : la clé d'un jour, partagée avec le code Android.
String cleJour(DateTime j) => '${j.year}${j.month.toString().padLeft(2, '0')}${j.day.toString().padLeft(2, '0')}';

/// L'atelier des widgets de l'écran d'accueil du téléphone.
///
/// Il dessine chaque widget hors de l'écran avec les composants de l'appli,
/// le photographie, et confie la photo à Android. Sept jours sont préparés
/// d'avance : le téléphone montre la bonne image chaque jour, même si
/// l'appli n'est pas rouverte (routine du jour, jour entouré, semaine qui
/// change).
///
/// Les photos sont refaites à l'ouverture de l'appli, à son retour au
/// premier plan, et quand les séances, les routines ou le programme changent.
class AtelierEcranAccueil extends StatefulWidget {
  const AtelierEcranAccueil({super.key, required this.child});
  final Widget child;

  /// Nombre de jours préparés d'avance, aujourd'hui compris.
  static const jours = 7;

  /// Nombre d'images d'un widget animé (le personnage qui fait l'exercice).
  static const trames = 12;

  @override
  State<AtelierEcranAccueil> createState() => _AtelierEcranAccueilState();
}

class _AtelierEcranAccueilState extends State<AtelierEcranAccueil> with WidgetsBindingObserver {
  final _cles = {for (final w in WidgetEcran.values) w: GlobalKey()};
  Timer? _attente;
  String? _empreinte;
  bool _enCours = false;
  bool _aRefaire = false;

  /// Le jour en train d'être dessiné (null : rien hors écran).
  DateTime? _jour;

  /// L'image de l'animation en train d'être dessinée dans les widgets animés.
  ui.Image? _trame;
  final _ecoutes = <Listenable>[];

  /// Sans effet hors d'Android et pendant les tests automatiques.
  static bool get _actif => Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (!_actif) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ecoutes.addAll([context.read<SessionRepo>(), context.read<RoutineRepo>(), context.read<ProgramRepo>(), context.read<SettingsRepo>(), context.read<ProfileRepo>()]);
      for (final e in _ecoutes) {
        e.addListener(_prevoir);
      }
      _prevoir();
    });
  }

  @override
  void dispose() {
    _attente?.cancel();
    if (_actif) WidgetsBinding.instance.removeObserver(this);
    for (final e in _ecoutes) {
      e.removeListener(_prevoir);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _prevoir();
  }

  /// Regroupe les changements : on redessine quatre secondes après le dernier.
  void _prevoir() {
    _attente?.cancel();
    _attente = Timer(const Duration(seconds: 4), _refaire);
  }

  /// Ce dont dépendent les images : inutile de les refaire si rien n'a bougé
  /// (une série cochée pendant une séance ne change aucun widget).
  String _empreinteActuelle() {
    final s = context.read<SessionRepo>();
    final finies = s.sessions.where((x) => !x.enCours).toList();
    final p = context.read<ProgramRepo>().active;
    final r = context.read<RoutineRepo>().routines;
    final reglages = context.read<SettingsRepo>().settings;
    return [
      cleJour(DateTime.now()),
      finies.length,
      finies.isEmpty ? '' : finies.map((x) => x.debut.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b),
      p?.id,
      p?.prochainIndex,
      p?.routineIds.join(','),
      r.map((x) => '${x.id}:${x.nom}:${x.exercices.length}').join(','),
      reglages.premierJourSemaine,
      context.read<ProfileRepo>().profile?.joursParSemaine,
    ].join('|');
  }

  Future<void> _refaire() async {
    if (!mounted || !context.read<ProfileRepo>().hasProfile) return;
    if (_enCours) {
      _aRefaire = true;
      return;
    }
    final empreinte = _empreinteActuelle();
    if (empreinte == _empreinte) return;
    _enCours = true;
    try {
      final maintenant = DateTime.now();
      for (var i = 0; i < AtelierEcranAccueil.jours; i++) {
        if (!mounted) return;
        // Aujourd'hui garde l'heure (la récupération en dépend) ; les jours
        // suivants sont pris à midi.
        final jour = i == 0 ? maintenant : DateTime(maintenant.year, maintenant.month, maintenant.day + i, 12);
        setState(() => _jour = jour);
        // Le premier passage charge les images du personnage ; les suivants
        // les trouvent en mémoire.
        await Future<void>.delayed(Duration(milliseconds: i == 0 ? 1800 : 450));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final cle = cleJour(jour);
        final chemins = {for (final w in WidgetEcran.values) w: cheminEcran(context, w, jour)};
        for (final w in WidgetEcran.values.where((w) => !w.anime)) {
          final rendu = _cles[w]!.currentContext?.findRenderObject();
          if (rendu is! RenderRepaintBoundary) continue;
          final image = await rendu.toImage(pixelRatio: 3);
          final octets = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (octets == null || !mounted) continue;
          await HomeWidget.saveFile('${w.cle}_$cle', octets.buffer.asUint8List(), extension: 'png');
          await HomeWidget.saveWidgetData<String>('${w.cle}_lien_$cle', chemins[w]);
        }
        // Dès qu'aujourd'hui est prêt, le téléphone se met à jour.
        if (i == 0) await _prevenir();
      }
      await _animer(maintenant);
      await _prevenir();
      // Les images des jours passés ne servent plus : on les retire (le
      // fichier part avec sa clé).
      for (var i = 1; i <= 10; i++) {
        final passe = cleJour(DateTime(maintenant.year, maintenant.month, maintenant.day - i));
        for (final w in WidgetEcran.values.where((w) => !w.anime)) {
          await HomeWidget.saveWidgetData<String>('${w.cle}_$passe', null);
          await HomeWidget.saveWidgetData<String>('${w.cle}_lien_$passe', null);
        }
      }
      _empreinte = empreinte;
    } catch (_) {
      // Un widget qui ne se met pas à jour ne doit jamais gêner l'appli.
    } finally {
      _enCours = false;
      if (mounted) setState(() => _jour = null);
      if (_aRefaire) {
        _aRefaire = false;
        _prevoir();
      }
    }
  }

  /// Les images de l'exercice du dernier record, réparties sur toute son
  /// animation (une seule si l'exercice n'a qu'une pose).
  Future<List<ui.Image>> _tramesDuRecord() async {
    final media = dernierRecord(context).media;
    if (media == null) return const [];
    final octets = await rootBundle.load(media);
    final codec = await ui.instantiateImageCodec(octets.buffer.asUint8List(), targetWidth: 560);
    final n = codec.frameCount;
    final gardees = {for (var k = 0; k < AtelierEcranAccueil.trames; k++) (k * n / AtelierEcranAccueil.trames).floor()};
    final images = <ui.Image>[];
    for (var i = 0; i < n; i++) {
      final image = (await codec.getNextFrame()).image;
      gardees.contains(i) ? images.add(image) : image.dispose();
    }
    codec.dispose();
    return images;
  }

  /// Dessine les widgets animés, une photo par image de l'animation. Clés :
  /// `<cle>_a<k>` (image k), `<cle>_n` (nombre d'images), `<cle>_lien`.
  Future<void> _animer(DateTime maintenant) async {
    if (!mounted) return;
    final animes = WidgetEcran.values.where((w) => w.anime).toList();
    final chemins = {for (final w in animes) w: cheminEcran(context, w, maintenant)};
    final images = await _tramesDuRecord();
    final n = images.isEmpty ? 1 : images.length;
    try {
      for (var k = 0; k < n; k++) {
        if (!mounted) return;
        setState(() {
          _jour = maintenant;
          _trame = images.isEmpty ? null : images[k];
        });
        await Future<void>.delayed(Duration(milliseconds: k == 0 ? 400 : 60));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        for (final w in animes) {
          final rendu = _cles[w]!.currentContext?.findRenderObject();
          if (rendu is! RenderRepaintBoundary) continue;
          // Douze images par widget : une définition un peu plus basse que les
          // widgets fixes, pour rester sous la limite de mémoire d'Android.
          final image = await rendu.toImage(pixelRatio: w == WidgetEcran.record ? 2.5 : 1.9);
          final octets = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (octets == null) continue;
          await HomeWidget.saveFile('${w.cle}_a$k', octets.buffer.asUint8List(), extension: 'png');
        }
      }
      for (final w in animes) {
        await HomeWidget.saveWidgetData<int>('${w.cle}_n', n);
        await HomeWidget.saveWidgetData<String>('${w.cle}_lien', chemins[w]);
      }
    } finally {
      if (mounted) setState(() => _trame = null);
      for (final image in images) {
        image.dispose();
      }
    }
  }

  Future<void> _prevenir() async {
    for (final w in WidgetEcran.values) {
      await HomeWidget.updateWidget(qualifiedAndroidName: classeAndroid(w));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jour = _jour;
    if (jour == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        // Hors de l'écran, à gauche : dessiné, jamais vu ni touché.
        Positioned(
          left: -5000,
          top: 0,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // À la taille du dessin, quel que soit le réglage de texte du téléphone.
                for (final w in WidgetEcran.values)
                  RepaintBoundary(
                    key: _cles[w],
                    child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: vueEcran(w, jour, image: _trame)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// L'adresse de l'appli que demande un appui sur un widget
/// (`aesthetics://ouvrir?chemin=/progres/records`), ou null.
String? cheminDuLien(Uri? lien) {
  if (lien == null || lien.scheme != 'aesthetics') return null;
  final chemin = lien.queryParameters['chemin'];
  return chemin == null || !chemin.startsWith('/') ? null : chemin;
}
