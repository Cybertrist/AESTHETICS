import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import 'exif.dart';

/// Un fichier rendu par le sélecteur : son chemin et son nom d'origine.
typedef FichierPhoto = ({String chemin, String nom});

/// Ce qui va chercher les photos (appareil ou galerie). Séparé pour être
/// remplacé dans les tests.
abstract final class SelecteurPhotos {
  /// Plusieurs photos de la galerie, telles quelles : ni redimensionnement
  /// ni recompression, qui retireraient la date de prise de vue.
  static Future<List<FichierPhoto>> Function() galerie = _galerie;

  /// Une photo prise sur le moment.
  static Future<FichierPhoto?> Function() appareil = _appareil;

  static Future<List<FichierPhoto>> _galerie() async {
    final l = await ImagePicker().pickMultiImage();
    return [for (final x in l) (chemin: x.path, nom: x.name)];
  }

  static Future<FichierPhoto?> _appareil() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 2400, imageQuality: 88);
    return x == null ? null : (chemin: x.path, nom: x.name);
  }

  static void reinitialiser() {
    galerie = _galerie;
    appareil = _appareil;
  }
}

/// D'où vient la date d'une photo à ajouter.
enum OrigineDate {
  photo('date lue dans la photo'),
  nom('date lue dans le nom du fichier'),
  choisie('date choisie'),
  aucune('');

  const OrigineDate(this.mention);
  final String mention;
}

/// Une photo choisie dans la galerie, avant son enregistrement.
class PhotoAAjouter {
  PhotoAAjouter({required this.chemin, required this.nom, required this.vue, this.date, this.origine = OrigineDate.aucune});

  final String chemin;
  final String nom;
  PhotoVue vue;
  DateTime? date;
  OrigineDate origine;
}

/// Les photos choisies dans la galerie : la date trouvée pour chacune, son
/// angle, et ce qu'il manque avant de pouvoir les ajouter.
class ImportPhotos {
  ImportPhotos(this.photos);

  final List<PhotoAAjouter> photos;

  /// Premier jour proposé par le calendrier.
  static final premierJour = DateTime(DatePhoto.anneeMin);

  /// L'en-tête d'un JPEG suffit pour y lire sa date.
  static const _tete = 256 * 1024;

  /// Lit la date de chaque fichier : dans la photo, sinon dans son nom.
  static Future<ImportPhotos> lire(List<FichierPhoto> fichiers, {required PhotoVue vue, DateTime? maintenant}) async {
    final out = <PhotoAAjouter>[];
    for (final f in fichiers) {
      var date = DatePhoto.exif(await _octets(f.chemin), maintenant: maintenant);
      var origine = OrigineDate.photo;
      if (date == null) {
        date = DatePhoto.duNom(f.nom, maintenant: maintenant);
        origine = date == null ? OrigineDate.aucune : OrigineDate.nom;
      }
      out.add(PhotoAAjouter(chemin: f.chemin, nom: f.nom, vue: vue, date: date, origine: origine));
    }
    return ImportPhotos(out);
  }

  static Future<Uint8List> _octets(String chemin) async {
    try {
      final f = File(chemin);
      final acces = await f.open();
      try {
        final debut = await acces.read(_tete);
        final jpeg = debut.length > 2 && debut[0] == 0xFF && debut[1] == 0xD8;
        // Les autres formats rangent leurs métadonnées n'importe où.
        return jpeg || debut.length < _tete ? debut : await f.readAsBytes();
      } finally {
        await acces.close();
      }
    } catch (_) {
      return Uint8List(0);
    }
  }

  int get sansDate => photos.where((p) => p.date == null).length;

  /// Toutes les photos ont une date : on peut les ajouter.
  bool get pret => photos.isNotEmpty && sansDate == 0;

  /// Les photos n'ont pas toutes le même angle.
  bool get anglesDifferents => photos.any((p) => p.vue != photos.first.vue);

  /// Donne le [jour] choisi dans le calendrier à une photo. Rend faux, sans
  /// rien changer, si le jour est dans le futur.
  bool fixerDate(PhotoAAjouter p, DateTime jour, {DateTime? maintenant}) {
    final d = dateAuJour(p.date, jour, maintenant: maintenant);
    if (d == null) return false;
    if (p.date != d) {
      p.date = d;
      p.origine = OrigineDate.choisie;
    }
    return true;
  }

  void fixerVue(PhotoAAjouter p, PhotoVue vue) => p.vue = vue;

  void appliquerATous(PhotoVue vue) {
    for (final p in photos) {
      p.vue = vue;
    }
  }

  void retirer(PhotoAAjouter p) => photos.remove(p);

  /// Copie les photos dans le dossier de l'appli, à leur date de prise de
  /// vue. Le poids n'est pas noté : c'est la pesée la plus proche de la
  /// date qui s'affichera. Ne fait rien tant qu'une date manque.
  Future<List<ProgressPhoto>> enregistrer(HealthRepo sante) async {
    if (!pret) return const [];
    final out = <ProgressPhoto>[];
    for (final p in [...photos]) {
      out.add(await sante.addPhoto(p.chemin, date: p.date, vue: p.vue));
      photos.remove(p);
    }
    return out;
  }
}

/// La date d'une photo déplacée au [jour] choisi dans le calendrier : elle
/// garde son heure si elle en avait une, sinon midi. Null si le jour est
/// dans le futur.
DateTime? dateAuJour(DateTime? ancienne, DateTime jour, {DateTime? maintenant}) {
  final now = maintenant ?? DateTime.now();
  if (DateTime(jour.year, jour.month, jour.day).isAfter(now)) return null;
  if (ancienne != null && ancienne.year == jour.year && ancienne.month == jour.month && ancienne.day == jour.day) return ancienne;
  final d = DateTime(jour.year, jour.month, jour.day, ancienne?.hour ?? 12, ancienne?.minute ?? 0, ancienne?.second ?? 0);
  // Aujourd'hui, mais plus tard que maintenant : maintenant.
  return d.isAfter(now) ? now : d;
}

/// Change la date d'une photo enregistrée. Le poids noté à la prise de vue
/// ne vaut plus : la pesée la plus proche de la nouvelle date le remplace.
/// Rend faux si le jour est dans le futur.
Future<bool> changerDatePhoto(HealthRepo sante, ProgressPhoto p, DateTime jour, {DateTime? maintenant}) async {
  final d = dateAuJour(p.date, jour, maintenant: maintenant);
  if (d == null) return false;
  if (d == p.date) return true;
  await sante.savePhoto(ProgressPhoto(id: p.id, date: d, chemin: p.chemin, vue: p.vue, note: p.note));
  return true;
}

/// Change l'angle d'une photo enregistrée.
Future<void> changerVuePhoto(HealthRepo sante, ProgressPhoto p, PhotoVue vue) async {
  if (vue == p.vue) return;
  await sante.savePhoto(ProgressPhoto(id: p.id, date: p.date, chemin: p.chemin, vue: vue, poidsKg: p.poidsKg, note: p.note));
}
