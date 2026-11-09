import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/copie_serveur.dart';
import '../logic/services.dart';

/// Les copies des données dans Firestore (voir serveur/CONCEPTION.md) :
/// le résumé dans `copies/{uid}`, le texte dans `copies/{uid}/morceaux/{n}`
/// sous la clé `texte`, n allant de 0 au nombre de morceaux moins un.
class CopiesFirebase implements ServiceCopies {
  CopiesFirebase(this.base, {this.attente = const Duration(minutes: 2)});

  final FirebaseFirestore base;

  /// Au-delà, un envoi est tenu pour raté (réseau trop faible) : Firestore
  /// le garde en file et le finira seul, et l'appli le retentera.
  final Duration attente;

  /// Morceaux écrits par lot : sous les 10 Mo d'une requête.
  static const parLot = 8;

  static const collection = 'copies';
  static const sousCollection = 'morceaux';

  DocumentReference<Map<String, dynamic>> _doc(String uid) => base.collection(collection).doc(uid);
  DocumentReference<Map<String, dynamic>> _morceau(String uid, int n) => _doc(uid).collection(sousCollection).doc('$n');

  /// Toujours lu sur le serveur : le cache du téléphone pourrait dater, et
  /// une lecture qui échoue dit tout de suite qu'il n'y a pas de réseau.
  static const _serveur = GetOptions(source: Source.server);

  @override
  Future<ResumeCopie?> resume(String uid) async {
    final doc = await _doc(uid).get(_serveur);
    return doc.exists ? ResumeCopie.fromJson(doc.data()) : null;
  }

  @override
  Future<void> envoyer(String uid, ResumeCopie resume, List<String> morceaux) async {
    // L'ancien résumé dit combien de morceaux effacer après. Le lire d'abord
    // vérifie aussi le réseau : sans lui, rien n'est mis en file.
    final ancien = await this.resume(uid);
    // Les morceaux d'abord, le résumé ensuite : tant qu'il n'est pas écrit,
    // l'ancien résumé reste valable ou la relecture voit la copie abîmée.
    for (var i = 0; i < morceaux.length; i += parLot) {
      final lot = base.batch();
      for (var n = i; n < morceaux.length && n < i + parLot; n++) {
        lot.set(_morceau(uid, n), {'texte': morceaux[n]});
      }
      await lot.commit().timeout(attente);
    }
    final fin = base.batch()..set(_doc(uid), resume.toJson());
    for (var n = morceaux.length; n < (ancien?.morceaux ?? 0); n++) {
      fin.delete(_morceau(uid, n));
    }
    await fin.commit().timeout(attente);
  }

  @override
  Future<List<String>> lire(String uid, ResumeCopie resume) async {
    final docs = await Future.wait([for (var n = 0; n < resume.morceaux; n++) _morceau(uid, n).get(_serveur)]);
    return [
      for (final d in docs) _texte(d.data()),
    ];
  }

  /// Un morceau manquant ou abîmé rend toute la copie illisible.
  static String _texte(Map<String, dynamic>? j) {
    final texte = j?['texte'];
    if (texte is! String) throw const FormatException('La copie du serveur est incomplète ou abîmée.');
    return texte;
  }
}
