import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import 'copie_serveur.dart';
import 'services.dart';

/// Où en est la copie sur le serveur.
enum EtatCopie {
  /// Pas de compte, ou rien encore envoyé.
  aucune,
  enCours,
  aJour,

  /// Le dernier envoi n'a pas abouti (pas de réseau) : il sera retenté.
  enAttente,
}

/// Les deux copies quand le téléphone et le serveur ont chacun des données
/// et qu'on ne sait pas laquelle garder : c'est à la personne de choisir.
class ChoixCopie {
  const ChoixCopie({required this.telephone, required this.serveur});
  final ResumeCopie telephone;
  final ResumeCopie serveur;
}

/// Le compte et la copie des données sur le serveur.
///
/// L'appli reste la même sans compte : tout vit sur le téléphone. Avec un
/// compte, chaque changement part sur le serveur quelques secondes plus
/// tard, et un téléphone neuf retrouve tout à la connexion. Le serveur ne
/// fusionne rien : il garde une copie entière, la dernière envoyée.
class CompteRepo extends ChangeNotifier {
  CompteRepo(this.data, {this.connexion, this.copies, this.delai = const Duration(seconds: 20), DateTime Function()? horloge})
      : _horloge = horloge ?? DateTime.now {
    _utilisateur = connexion?.actuel;
  }

  final AppData data;

  /// Null quand le serveur n'est pas configuré dans cette construction.
  final ServiceConnexion? connexion;
  final ServiceCopies? copies;

  /// Attente entre un changement et son envoi : une séance modifie les
  /// données à chaque série cochée, on n'envoie pas à chaque fois.
  final Duration delai;
  final DateTime Function() _horloge;

  static const _fichier = 'compte';

  Utilisateur? _utilisateur;
  EtatCopie _etat = EtatCopie.aucune;
  DateTime? _dernierEnvoi;
  String? _erreur;
  ChoixCopie? _choix;

  /// Le téléphone et le serveur ont été comparés pour ce compte (gardé dans
  /// le fichier [_fichier]) : sans cela, rien ne part. Un choix laissé en
  /// plan, un réseau coupé pendant la connexion ou une appli tuée au mauvais
  /// moment ne laissent donc jamais écraser la copie du serveur.
  bool _accorde = false;
  Future<void>? _accord;
  Timer? _minuteur;
  bool _aEnvoyer = false;
  Future<void>? _envoi;

  /// Vrai si cette construction sait parler à un serveur.
  bool get disponible => connexion != null && copies != null;
  Utilisateur? get utilisateur => _utilisateur;
  bool get connecte => _utilisateur != null;
  EtatCopie get etat => _etat;
  DateTime? get dernierEnvoi => _dernierEnvoi;

  /// Message de la dernière erreur, en clair, ou null.
  String? get erreur => _erreur;

  /// Le choix à faire entre le téléphone et le serveur, ou null.
  ChoixCopie? get choix => _choix;

  /// À appeler une fois au démarrage, après le chargement des données.
  Future<void> charger() async {
    final j = await data.store.readObject(_fichier);
    final uid = j?['uid'];
    _dernierEnvoi = DateTime.tryParse('${j?['dernierEnvoi']}');
    // La copie locale ne vaut que pour le compte qui l'a envoyée.
    _accorde = _utilisateur != null && uid == _utilisateur!.uid;
    if (!_accorde) _dernierEnvoi = null;
    _etat = _utilisateur != null && _dernierEnvoi != null ? EtatCopie.aJour : EtatCopie.aucune;
    data.store.ecouteurs.add(_surEcriture);
    notifyListeners();
  }

  void _surEcriture(String nom) {
    if (!connecte || _choix != null || CopieServeur.horsCopie.contains(nom)) return;
    noterChangement();
  }

  /// Un changement vient d'être écrit : il partira après [delai] de calme.
  void noterChangement() {
    if (!disponible || !connecte) return;
    _aEnvoyer = true;
    _minuteur?.cancel();
    _minuteur = Timer(delai, () => unawaited(envoyer()));
  }

  /// Ouvre la connexion Google, puis met le téléphone et le serveur d'accord.
  /// Rend false si la personne a refermé la fenêtre ou si rien n'a abouti.
  Future<bool> connecter() async {
    if (!disponible) return false;
    _erreur = null;
    try {
      final u = await connexion!.connecterGoogle();
      if (u == null) return false;
      _utilisateur = u;
      _dernierEnvoi = null;
      _accorde = false;
      notifyListeners();
      await _accorder();
      return true;
    } catch (e) {
      // Le compte reste connecté, mais les copies ne sont pas comparées :
      // rien ne part avant que la comparaison ait abouti (au prochain
      // changement, au retour dans l'appli).
      _erreur = 'La connexion n\'a pas abouti. Vérifie ta connexion à Internet et réessaie.';
      notifyListeners();
      return false;
    }
  }

  /// Vrai quand le téléphone et le serveur restent à comparer pour ce
  /// compte : la prochaine tentative d'envoi les compare d'abord.
  bool get aComparer => connecte && !_accorde;

  /// Compare de nouveau, une seule fois à la fois ; une erreur réseau est
  /// notée, et l'essai suivant recommencera.
  Future<void> _reaccorder() => _accord ??= () async {
        _erreur = null;
        try {
          await _accorder();
        } catch (_) {
          _etat = EtatCopie.enAttente;
          _erreur = 'Pas encore comparé avec le serveur : réessaie quand le réseau revient.';
          notifyListeners();
        }
      }()
          .whenComplete(() => _accord = null);

  /// Après une connexion : envoyer, reprendre, ou demander.
  Future<void> _accorder() async {
    final uid = _utilisateur!.uid;
    final serveur = await copies!.resume(uid);
    final json = await _exporter();
    final telephone = CopieServeur.resumer(json, morceaux: 0, date: _horloge());
    if (serveur == null || serveur.vide) {
      // Rien sur le serveur : le téléphone fait foi.
      _accorde = true;
      await envoyer();
    } else if (telephone.vide) {
      // Téléphone neuf : on reprend la copie du compte.
      await reprendreServeur();
    } else {
      // Des données des deux côtés : rien n'est écrasé sans un choix.
      _choix = ChoixCopie(telephone: telephone, serveur: serveur);
      notifyListeners();
    }
  }

  Future<String> _exporter() async {
    final j = jsonDecode(await data.exportBackup()) as Map<String, dynamic>;
    final donnees = Map<String, dynamic>.from(j['donnees'] as Map)..removeWhere((k, _) => CopieServeur.horsCopie.contains(k));
    return jsonEncode({...j, 'donnees': donnees});
  }

  /// Garder les données de ce téléphone : elles remplacent la copie du serveur.
  Future<void> garderTelephone() async {
    if (_choix == null) return;
    _choix = null;
    _accorde = true;
    notifyListeners();
    await envoyer();
  }

  /// Reprendre la copie du serveur : elle remplace les données du téléphone.
  Future<void> reprendreServeur() async {
    if (!disponible || !connecte) return;
    final uid = _utilisateur!.uid;
    _etat = EtatCopie.enCours;
    _erreur = null;
    notifyListeners();
    try {
      final resume = await copies!.resume(uid);
      if (resume == null) throw const FormatException('Aucune copie sur le serveur.');
      final json = CopieServeur.recoller(await copies!.lire(uid, resume));
      await data.importBackup(json);
      _choix = null;
      _accorde = true;
      _dernierEnvoi = resume.date;
      _aEnvoyer = false;
      _minuteur?.cancel();
      await _noter();
      _etat = EtatCopie.aJour;
    } on FormatException catch (e) {
      _etat = EtatCopie.enAttente;
      _erreur = e.message;
    } catch (_) {
      _etat = EtatCopie.enAttente;
      _erreur = 'La copie du serveur n\'a pas pu être lue. Vérifie ta connexion à Internet.';
    }
    notifyListeners();
  }

  /// Envoie les données du téléphone sur le serveur, tout de suite. Deux
  /// demandes rapprochées ne font qu'un envoi à la fois.
  Future<void> envoyer() {
    final enCours = _envoi;
    if (enCours != null) {
      _aEnvoyer = true;
      return enCours;
    }
    return _envoi = _envoyer().whenComplete(() => _envoi = null);
  }

  Future<void> _envoyer() async {
    if (!disponible || !connecte || _choix != null) return;
    // Jamais comparés : on compare d'abord (envoyer, reprendre ou demander).
    if (!_accorde) return _reaccorder();
    final uid = _utilisateur!.uid;
    _minuteur?.cancel();
    _aEnvoyer = false;
    _etat = EtatCopie.enCours;
    _erreur = null;
    notifyListeners();
    try {
      final json = await _exporter();
      final morceaux = CopieServeur.decouper(json);
      if (morceaux.length > CopieServeur.maxMorceaux) throw const FormatException('Tes données sont trop grosses pour la copie du serveur.');
      final resume = CopieServeur.resumer(json, morceaux: morceaux.length, date: _horloge());
      await copies!.envoyer(uid, resume, morceaux);
      _dernierEnvoi = resume.date;
      await _noter();
      _etat = EtatCopie.aJour;
    } on FormatException catch (e) {
      _etat = EtatCopie.enAttente;
      _erreur = e.message;
    } catch (_) {
      // Pas de réseau à la salle : les données restent sur le téléphone et
      // l'envoi sera retenté au prochain changement ou au prochain lancement.
      _etat = EtatCopie.enAttente;
      _aEnvoyer = true;
      _erreur = 'Pas encore envoyé : l\'envoi reprendra dès que le réseau revient.';
    }
    notifyListeners();
    // Un changement arrivé pendant l'envoi repart après le délai.
    if (_aEnvoyer && _etat == EtatCopie.aJour) noterChangement();
  }

  /// Vrai quand un envoi attend (changement récent ou envoi raté).
  bool get envoiEnAttente => _aEnvoyer;

  Future<void> _noter() => data.store.write(_fichier, {
        'uid': _utilisateur?.uid,
        if (_dernierEnvoi != null) 'dernierEnvoi': _dernierEnvoi!.toIso8601String(),
      });

  /// Se déconnecter laisse les données sur le téléphone et la copie sur le
  /// serveur ; seul l'envoi s'arrête.
  Future<void> deconnecter() async {
    _minuteur?.cancel();
    try {
      await connexion?.deconnecter();
    } catch (_) {}
    _utilisateur = null;
    _dernierEnvoi = null;
    _choix = null;
    _accorde = false;
    _aEnvoyer = false;
    _etat = EtatCopie.aucune;
    _erreur = null;
    await data.store.delete(_fichier);
    notifyListeners();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    data.store.ecouteurs.remove(_surEcriture);
    super.dispose();
  }
}
