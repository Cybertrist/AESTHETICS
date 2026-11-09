import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/env.dart';

/// L'accès au serveur Firebase, commun au compte et à la communauté.
///
/// Démarré une fois par `main`. Dans les tests, en démo ou si le démarrage
/// échoue (pas de configuration pour cette plateforme), il reste éteint :
/// [auth] et [base] rendent null et l'appli marche comme avant, tout en local.
abstract final class ServeurFirebase {
  static bool _pret = false;

  /// Vrai quand Firebase a démarré.
  static bool get pret => _pret;

  /// La connexion, ou null sans serveur.
  static FirebaseAuth? get auth => _pret ? FirebaseAuth.instance : null;

  /// La base Firestore, ou null sans serveur.
  static FirebaseFirestore? get base => _pret ? FirebaseFirestore.instance : null;

  /// L'uid de la personne connectée, ou null.
  static String? get uid => auth?.currentUser?.uid;

  /// Démarre Firebase si cette construction y a droit. Ne lève jamais :
  /// sans réseau, Firebase démarre quand même et attend le réseau.
  static Future<bool> demarrer() async {
    if (_pret) return true;
    if (Env.demo || kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return false;
    // La configuration n'existe que pour Android (google-services.json).
    if (!Platform.isAndroid) return false;
    try {
      // Les clés sont lues dans google-services.json par le plugin Gradle.
      await Firebase.initializeApp();
      if (Env.emulateur.isNotEmpty) {
        await FirebaseAuth.instance.useAuthEmulator(Env.emulateur, Env.portAuth);
        FirebaseFirestore.instance.useFirestoreEmulator(Env.emulateur, Env.portFirestore);
      }
      _pret = true;
    } catch (e) {
      debugPrint('Firebase n\'a pas démarré : $e');
      _pret = false;
    }
    return _pret;
  }
}
