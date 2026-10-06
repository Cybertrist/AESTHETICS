import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Fichier choisi par l'utilisateur.
typedef FichierLu = ({String nom, Uint8List octets});

/// Accès aux fichiers : choix, partage, enregistrement.
/// Les écrans passent par ici pour que les tests puissent le remplacer.
class Fichiers {
  const Fichiers();

  /// Instance utilisée par les écrans (remplaçable dans les tests).
  static Fichiers courant = const Fichiers();

  /// Ouvre le sélecteur. Tous les types sont proposés : sur Android, un
  /// filtre par extension grise souvent les CSV. L'extension est vérifiée
  /// ensuite par l'appelant. Null si l'utilisateur annule.
  Future<FichierLu?> choisir() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty) return null;
    final f = res.first;
    return (nom: f.name, octets: await f.readAsBytes());
  }

  /// Écrit un fichier temporaire (pour le partage).
  Future<File> ecrireTemporaire(String nom, List<int> octets) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$nom');
    await f.writeAsBytes(octets, flush: true);
    return f;
  }

  /// Ouvre le menu de partage d'Android. Vrai si l'utilisateur a partagé.
  Future<bool> partager(String nom, List<int> octets, String mime, {String? sujet}) async {
    final f = await ecrireTemporaire(nom, octets);
    final r = await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: mime, name: nom)],
      subject: sujet ?? nom,
      title: sujet ?? nom,
    ));
    return r.status != ShareResultStatus.dismissed;
  }

  /// Partage plusieurs fichiers d'un coup.
  Future<bool> partagerPlusieurs(List<({String nom, List<int> octets, String mime})> fichiers, {String? sujet}) async {
    final xs = <XFile>[];
    for (final f in fichiers) {
      final t = await ecrireTemporaire(f.nom, f.octets);
      xs.add(XFile(t.path, mimeType: f.mime, name: f.nom));
    }
    final r = await SharePlus.instance.share(ShareParams(files: xs, subject: sujet, title: sujet));
    return r.status != ShareResultStatus.dismissed;
  }

  /// Demande où enregistrer le fichier. Vrai si c'est fait, faux si annulé.
  Future<bool> enregistrer(String nom, List<int> octets, String mime) async {
    final uri = await FilePicker.saveFile(
      fileName: nom,
      bytes: Uint8List.fromList(octets),
      mimeType: mime,
      dialogTitle: 'Enregistrer $nom',
    );
    return uri != null;
  }
}

abstract final class Mime {
  static const csv = 'text/csv';
  static const json = 'application/json';
  static const zip = 'application/zip';
}

/// « 12 Ko », « 3,4 Mo ».
String tailleLisible(int octets) {
  if (octets < 1024) return '$octets o';
  if (octets < 1024 * 1024) return '${(octets / 1024).round()} Ko';
  return '${(octets / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
