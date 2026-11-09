import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../logic/services.dart';

/// La connexion par un compte Google, tenue par Firebase Auth.
///
/// Le choix du compte passe par le sélecteur du téléphone (google_sign_in).
/// Si le projet Firebase n'a pas encore d'identifiant OAuth pour l'appli
/// (google-services.json sans `oauth_client`), on retombe sur la page de
/// connexion Google ouverte par Firebase lui-même.
class ConnexionFirebase implements ServiceConnexion {
  ConnexionFirebase(this.auth, {GoogleSignIn? google}) : _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth auth;
  final GoogleSignIn _google;
  Future<void>? _initialisation;

  /// google_sign_in demande une initialisation, une seule fois.
  Future<void> _initialiser() => _initialisation ??= _google.initialize();

  @override
  Utilisateur? get actuel => versUtilisateur(auth.currentUser);

  /// L'utilisateur Firebase vu par l'appli.
  static Utilisateur? versUtilisateur(User? u) =>
      u == null ? null : Utilisateur(uid: u.uid, nom: u.displayName, email: u.email, photo: u.photoURL);

  @override
  Future<Utilisateur?> connecterGoogle() async {
    UserCredential? r;
    try {
      await _initialiser();
      final compte = await _google.authenticate();
      final jeton = compte.authentication.idToken;
      if (jeton == null) throw StateError('Google n\'a pas rendu de jeton.');
      r = await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: jeton));
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        // Fenêtre refermée : pas une erreur.
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          r = await _parFirebase();
        default:
          rethrow;
      }
    }
    return versUtilisateur(r?.user);
  }

  /// La page de connexion Google de Firebase, quand le sélecteur du
  /// téléphone n'est pas configuré. Null si la personne la referme.
  Future<UserCredential?> _parFirebase() async {
    try {
      return await auth.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code.contains('cancel')) return null;
      rethrow;
    }
  }

  @override
  Future<void> deconnecter() async {
    await auth.signOut();
    // Oublier aussi le compte choisi : la prochaine connexion redemande lequel.
    try {
      await _initialiser();
      await _google.signOut();
    } catch (_) {}
  }
}
