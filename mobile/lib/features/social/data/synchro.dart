import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../aujourdhui/logic/accueil.dart' show recordsParSeance;
import 'modeles.dart';
import 'moi.dart';
import 'source.dart';
import 'source_firestore.dart';

/// Ce qui relie mes données du téléphone à la communauté sur le serveur.
///
/// - Le compte et l'interrupteur des Réglages décident si la source écoute :
///   communauté coupée ou personne de connecté, plus rien ne tourne.
/// - Mon profil (carte et détails) part quelques secondes après un
///   changement, filtré par ce que je montre.
/// - Une séance terminée part dans le fil de mes amis, une seule fois ; une
///   séance effacée sur le téléphone le quitte.
class SynchroSociale {
  SynchroSociale(this.data, this.source, {Stream<String?>? comptes, this.delai = const Duration(seconds: 8), DateTime Function()? horloge})
      : _horloge = horloge ?? DateTime.now {
    _comptes = comptes?.listen((uid) {
      _uid = uid;
      _accorder();
    });
    data.settings.addListener(_accorder);
    for (final r in _suivis) {
      r.addListener(_planifier);
    }
    source.addListener(_surSource);
    _accorder();
  }

  final AppData data;
  final SourceFirestore source;

  /// Calme attendu après un changement avant d'envoyer.
  final Duration delai;
  final DateTime Function() _horloge;

  /// Une séance terminée depuis plus longtemps ne part plus dans le fil.
  static const recente = Duration(hours: 24);

  StreamSubscription<String?>? _comptes;
  String? _uid;
  Timer? _minuteur;
  Future<void>? _envoi;
  bool _encore = false;
  Object? _etatSource;

  List<ChangeNotifier> get _suivis => [data.profile, data.sessions, data.routines];

  /// Je peux définir le compte à la main (tests, ou avant le premier
  /// événement de connexion).
  set uid(String? v) {
    _uid = v;
    _accorder();
  }

  bool get _actif => _uid != null && data.settings.settings.communaute;

  void _accorder() {
    source.changerCompte(_actif ? _uid : null);
    if (_actif) _planifier();
  }

  /// La source a bougé : seuls comptent mes amis (leur nombre est publié) et
  /// l'arrivée du fil (on sait alors ce qui est déjà publié).
  void _surSource() {
    final etat = (source.moi, source.avec(Lien.ami).length, source.filLu, source.etatPseudo);
    if (etat == _etatSource) return;
    _etatSource = etat;
    _planifier();
  }

  void _planifier() {
    if (!_actif) return;
    _minuteur?.cancel();
    _minuteur = Timer(delai, () => unawaited(publier()));
  }

  /// Envoie tout de suite ce qui a changé. Deux appels rapprochés ne font
  /// qu'un envoi à la fois, suivi d'un second si besoin.
  Future<void> publier() {
    if (_envoi != null) {
      _encore = true;
      return _envoi!;
    }
    return _envoi = _publier().whenComplete(() {
      _envoi = null;
      if (_encore) {
        _encore = false;
        _planifier();
      }
    });
  }

  Future<void> _publier() async {
    if (!_actif || source.moi == null) return;
    final p = data.profile.profile;
    if (p == null) return;
    try {
      // Sans pseudo, personne ne peut me trouver : on en prend un libre,
      // tiré du prénom, que je peux changer dans mon profil.
      if (p.pseudo.trim().isEmpty) {
        final libre = await _pseudoLibre(p.prenom);
        if (libre != null && data.profile.profile?.pseudo.trim().isEmpty == true) {
          await data.profile.update((x) => x.copyWith(pseudo: libre));
        }
        return;
      }
      final toutes = data.sessions.sessions;
      final moi = MoiPublic.calculer(
        p,
        toutes,
        nbRoutines: data.routines.routines.length,
        premierJour: data.settings.settings.premierJourSemaine,
        nbAmis: source.avec(Lien.ami).length,
      );
      final etat = await source.publierProfil(MonProfilPublic(personne: moi.personne, vignette: await _vignette(p.photo), jours: moi.jours));
      if (etat != EtatPseudo.ok || !source.filLu) return;

      final finies = toutes.where((s) => !s.enCours).toList();
      final publiees = source.seancesPubliees;
      final limite = _horloge().subtract(recente);
      final records = recordsParSeance(finies);
      for (final s in finies) {
        if (publiees.contains(s.id) || (s.fin ?? s.debut).isBefore(limite)) continue;
        await source.publierSeance(MoiPublic.publicationDe(s, records: records[s.id] ?? 0));
      }
      // Une séance effacée du téléphone quitte le fil. Un téléphone vide
      // (données pas encore reprises) n'efface rien.
      if (finies.isNotEmpty) {
        final ici = {for (final s in toutes) s.id};
        for (final id in publiees) {
          if (!ici.contains(id)) await source.retirerSeance(id);
        }
      }
    } catch (e) {
      debugPrint('Communauté : envoi impossible ($e)');
    }
  }

  /// Un pseudo libre tiré de [prenom] : « tristan », sinon « tristan.42 ».
  Future<String?> _pseudoLibre(String prenom) async {
    var base = aPlat(prenom).replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if (base.length < 3) base = 'athlete';
    if (base.length > 18) base = base.substring(0, 18);
    final hasard = Random();
    for (var i = 0; i < 6; i++) {
      final essai = i == 0 ? base : '$base.${10 + hasard.nextInt(990)}';
      if (await source.pseudoLibre(essai)) return essai;
    }
    return null;
  }

  /// Ma photo réduite à 96 px de large, en PNG base64 : faute de Cloud
  /// Storage, elle vit dans ma carte (40 000 signes au plus). Recalculée
  /// seulement quand la photo change.
  Future<String?> _vignette(String? chemin) async {
    if (chemin == null) return null;
    final f = File(chemin);
    if (!f.existsSync()) return null;
    final cle = '$chemin|${f.lengthSync()}|${f.lastModifiedSync().toIso8601String()}';
    if (cle == _cleVignette) return _vignetteTexte;
    String? texte;
    for (final largeur in const [96, 64]) {
      final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: largeur);
      final image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      if (png == null) break;
      final t = base64Encode(png.buffer.asUint8List());
      if (t.length <= 40000) {
        texte = t;
        break;
      }
    }
    _cleVignette = cle;
    return _vignetteTexte = texte;
  }

  String? _cleVignette, _vignetteTexte;

  void dispose() {
    _minuteur?.cancel();
    _comptes?.cancel();
    data.settings.removeListener(_accorder);
    for (final r in _suivis) {
      r.removeListener(_planifier);
    }
    source.removeListener(_surSource);
  }
}
