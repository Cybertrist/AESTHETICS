import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/models.dart';

/// Ce qui va chercher une photo ou une vidéo (appareil ou galerie). Séparé
/// pour être remplacé dans les tests.
abstract class SelecteurMedias {
  Future<List<String>> photos(ImageSource source);
  Future<String?> video(ImageSource source);
}

class _SelecteurAppareil implements SelecteurMedias {
  final _picker = ImagePicker();

  @override
  Future<List<String>> photos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final l = await _picker.pickMultiImage(imageQuality: 88, maxWidth: 2400);
      return [for (final x in l) x.path];
    }
    final x = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 2400);
    return [?x?.path];
  }

  @override
  Future<String?> video(ImageSource source) async {
    final x = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 3));
    return x?.path;
  }
}

/// Photos et vidéos d'une séance : choix, copie dans le dossier de l'appli
/// (le fichier rendu par le sélecteur vit dans un cache qui peut être vidé),
/// durée des vidéos.
abstract final class MediasSeance {
  static SelecteurMedias selecteur = _SelecteurAppareil();

  /// Dossier où les médias sont gardés ; remplaçable dans les tests.
  static Future<Directory> Function() dossier = _dossierAppli;

  /// Lit la durée d'une vidéo ; remplaçable dans les tests.
  static Future<int?> Function(String chemin) dureeVideo = _dureeVideo;

  static Future<Directory> _dossierAppli() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'medias_seances'));
  }

  static Future<int?> _dureeVideo(String chemin) async {
    final ctrl = VideoPlayerController.file(File(chemin));
    try {
      await ctrl.initialize();
      final d = ctrl.value.duration;
      return d == Duration.zero ? null : d.inSeconds;
    } catch (_) {
      return null;
    } finally {
      await ctrl.dispose();
    }
  }

  /// Fait choisir des photos ou une vidéo. Rend une liste vide si
  /// l'utilisateur annule ou si la source n'est pas disponible.
  static Future<List<SessionMedia>> choisir({required ImageSource source, required bool video}) async {
    final List<String> chemins;
    try {
      if (video) {
        final v = await selecteur.video(source);
        chemins = [?v];
      } else {
        chemins = await selecteur.photos(source);
      }
    } catch (_) {
      return const [];
    }
    final out = <SessionMedia>[];
    for (final c in chemins) {
      final garde = await _garder(c);
      out.add(SessionMedia(chemin: garde, video: video, dureeSec: video ? await _duree(garde) : null));
    }
    return out;
  }

  static Future<int?> _duree(String chemin) async {
    try {
      return await dureeVideo(chemin);
    } catch (_) {
      return null;
    }
  }

  /// Copie le fichier dans le dossier de l'appli ; en cas d'échec, garde le
  /// chemin d'origine.
  static Future<String> _garder(String chemin) async {
    try {
      final d = await dossier();
      if (!d.existsSync()) d.createSync(recursive: true);
      final nom = '${DateTime.now().microsecondsSinceEpoch}${p.extension(chemin)}';
      final copie = await File(chemin).copy(p.join(d.path, nom));
      return copie.path;
    } catch (_) {
      return chemin;
    }
  }

  /// Supprime le fichier d'un média retiré (sans bruit s'il n'existe plus).
  static Future<void> supprimer(SessionMedia m) async {
    try {
      final f = File(m.chemin);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
