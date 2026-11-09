import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../profil/data/grades.dart';
import 'modeles.dart';
import 'source.dart';

/// Ce que je publie de moi : ma carte, mes détails, et de quoi régler mes
/// séances déjà publiées (accès, ce que je montre).
class MonProfilPublic {
  const MonProfilPublic({required this.personne, this.vignette, this.jours = const {}});

  /// Moi, décrit comme une personne de la communauté (`MoiPublic`).
  final Ami personne;

  /// Ma photo réduite, en base64 (≤ 40 000 signes), ou null.
  final String? vignette;

  /// Mes jours d'entraînement.
  final Set<DateTime> jours;
}

/// Une séance du fil telle que le serveur la garde : ce qu'il faut pour la
/// montrer, et pour réécrire la mienne quand mes amis changent.
class _Brute {
  const _Brute(this.p, this.auteur, this.visiblePar, {required this.volume});
  final Publication p;
  final String auteur;
  final List<String> visiblePar;

  /// Le volume est écrit dans le document.
  final bool volume;
}

/// La vraie communauté, sur Firestore (le contrat est dans
/// serveur/CONCEPTION.md, les droits dans serveur/firestore.rules).
///
/// Connectée ([changerCompte]), elle écoute en temps réel mes amis, mes
/// demandes reçues et envoyées, mes blocages et le fil ; pour mes séances
/// récentes et les premières du fil, leurs réactions et leurs commentaires.
/// Tout se coupe à la déconnexion. Les profils des autres sont lus une fois
/// et gardés en mémoire ; une page ouverte sur quelqu'un ([voir]) les relit.
///
/// Les gestes écrivent tout de suite dans l'état en mémoire puis sur le
/// serveur : Firestore garde l'écriture en file sans réseau, et l'écoute
/// remet l'état d'accord avec le serveur dès qu'il répond.
class SourceFirestore extends SourceSociale {
  SourceFirestore(this.base, {this.store, DateTime Function()? horloge}) : _horloge = horloge ?? DateTime.now;

  final FirebaseFirestore base;

  /// Où retenir, d'un lancement à l'autre, à qui j'ai envoyé une demande :
  /// c'est ce qui dit qu'un nouvel ami a accepté la mienne.
  final Store? store;
  final DateTime Function() _horloge;

  /// Le fil et les notifications remontent jusque-là.
  static const fenetre = Duration(days: 30);

  /// Séances lues dans le fil, et séances des autres dont on écoute les
  /// réactions et les commentaires.
  static const maxFil = 100, maxEcoutees = 40;

  /// Le pseudo tel que les règles l'acceptent.
  static final pseudoPermis = RegExp(r'^[a-z0-9._]{3,24}$');

  static const _fichier = 'social_demandes';
  static const _gris = 0xFF4A4F5A;

  String? _moi;
  final List<StreamSubscription<Object?>> _ecoutes = [];
  final Map<String, List<StreamSubscription<Object?>>> _ecoutesPub = {};

  final Map<String, Ami> _personnes = {};
  final Map<String, Future<void>> _enLecture = {};
  final Map<String, DateTime> _relu = {}, _communsLus = {};
  final Map<String, DateTime> _amis = {};
  final Map<String, DateTime> _recues = {};
  final Map<String, DateTime> _envoyees = {};
  final Set<String> _bloques = {};

  /// Le fil : mes séances, et celles de mes amis lues par paquets de 30
  /// (`auteur in`, la limite de Firestore). Un inconnu qui met mon uid dans
  /// `visiblePar` n'y entre pas : les règles ne peuvent pas relire 500
  /// amitiés, c'est la requête qui ne prend que mes amis.
  List<_Brute> _fil = const [], _miennes = const [];
  final Map<String, StreamSubscription<Object?>> _ecoutesAmis = {};
  final Map<String, List<_Brute>> _desAmis = {};

  /// Les séances d'un paquet qui vient de changer, montrées le temps que le
  /// nouveau paquet réponde.
  List<_Brute> _provisoire = const [];
  final Map<String, Map<String, (Reaction, DateTime)>> _reactions = {};
  final Map<String, List<Commentaire>> _commentaires = {};

  /// Ceux à qui j'ai envoyé une demande, même partie depuis.
  final Set<String> _demandesVues = {};

  /// Mes amis au dernier lancement (fichier [_fichier]) : un ami parti
  /// pendant que l'appli dormait sort aussi de mes vieilles séances. Null
  /// tant que le fichier n'est pas lu ; vide s'il n'y en avait pas.
  Set<String>? _amisRetenus;
  bool _memoireLue = false, _premierAccord = false;
  bool _amisLus = false, _filLu = false;

  String _recherche = '';
  List<String> _trouves = const [];

  // Ce que j'ai publié de moi.
  EtatPseudo _etatPseudo = EtatPseudo.inconnu;
  String? _signature;
  AccesProfil? _acces;
  Set<Visible> _montre = const {};

  @override
  bool get apercu => false;

  @override
  String? get moi => _moi;

  @override
  EtatPseudo get etatPseudo => _etatPseudo;

  /// Le fil est arrivé une première fois : on sait ce que j'ai déjà publié.
  bool get filLu => _filLu;

  /// Mes séances publiées ces 30 derniers jours, par identifiant de séance.
  Set<String> get seancesPubliees => {
        for (final b in _miennes)
          if (b.p.seanceId != null) b.p.seanceId!,
      };

  CollectionReference<Map<String, dynamic>> get _profils => base.collection('profils');
  CollectionReference<Map<String, dynamic>> get _pseudos => base.collection('pseudos');
  CollectionReference<Map<String, dynamic>> get _demandes => base.collection('demandes');
  CollectionReference<Map<String, dynamic>> get _publications => base.collection('publications');
  CollectionReference<Map<String, dynamic>> _liste(String racine, String uid) => base.collection(racine).doc(uid).collection('liste');
  DocumentReference<Map<String, dynamic>> _details(String uid) => _profils.doc(uid).collection('details').doc('public');
  DocumentReference<Map<String, dynamic>> _demande(String de, String vers) => _demandes.doc('${de}_$vers');

  static Object get _maintenantServeur => FieldValue.serverTimestamp();

  /// Une date du serveur ; celle d'une écriture pas encore confirmée n'a pas
  /// de valeur : c'est maintenant.
  DateTime _date(Object? v) => v is Timestamp ? v.toDate() : _horloge();

  // ---------------------------------------------------------------- compte

  /// La personne connectée change (null : déconnectée). Les écoutes de
  /// l'ancien compte s'arrêtent et l'état repart de zéro.
  void changerCompte(String? uid) {
    if (uid == _moi) return;
    _arreter();
    _moi = uid;
    if (uid != null) _ecouter(uid);
    notifyListeners();
  }

  void _ecouter(String uid) {
    void erreur(Object e) => debugPrint('Communauté : écoute refusée ($e)');
    unawaited(_lireMemoire(uid));
    _ecoutes.addAll([
      _liste('amis', uid).snapshots().listen((s) => _surAmis(uid, s), onError: erreur),
      _demandes.where('vers', isEqualTo: uid).snapshots().listen((s) => _surDemandes(uid, s, recues: true), onError: erreur),
      _demandes.where('de', isEqualTo: uid).snapshots().listen((s) => _surDemandes(uid, s, recues: false), onError: erreur),
      _liste('blocages', uid).snapshots().listen((s) => _surBlocages(uid, s), onError: erreur),
      _publications
          .where('auteur', isEqualTo: uid)
          .where('date', isGreaterThan: Timestamp.fromDate(_horloge().subtract(fenetre)))
          .orderBy('date', descending: true)
          .limit(maxFil)
          .snapshots()
          .listen((s) => _surMiennes(uid, s), onError: erreur),
    ]);
  }

  /// Les séances de mes amis, un paquet de 30 par écoute. Rien ne change
  /// tant que mes amis restent les mêmes ; un paquet qui change est relancé,
  /// ses séances restent affichées jusqu'à la réponse.
  void _suivreAmis(String uid) {
    final ids = _amis.keys.toList()..sort();
    final paquets = <String, List<String>>{};
    for (var i = 0; i < ids.length; i += 30) {
      final p = ids.skip(i).take(30).toList();
      paquets[p.join(',')] = p;
    }
    if (setEquals(paquets.keys.toSet(), _ecoutesAmis.keys.toSet())) return;
    final amis = ids.toSet();
    final gardees = <_Brute>[];
    for (final cle in _ecoutesAmis.keys.toList()) {
      if (paquets.containsKey(cle)) continue;
      unawaited(_ecoutesAmis.remove(cle)!.cancel());
      gardees.addAll((_desAmis.remove(cle) ?? const <_Brute>[]).where((b) => amis.contains(b.auteur)));
    }
    _provisoire = [..._provisoire.where((b) => amis.contains(b.auteur)), ...gardees];
    void erreur(Object e) => debugPrint('Communauté : fil refusé ($e)');
    for (final MapEntry(key: cle, value: paquet) in paquets.entries) {
      _ecoutesAmis[cle] ??= _publications
          .where('auteur', whereIn: paquet)
          .where('visiblePar', arrayContains: uid)
          .where('date', isGreaterThan: Timestamp.fromDate(_horloge().subtract(fenetre)))
          .orderBy('date', descending: true)
          .limit(maxFil)
          .snapshots()
          .listen((s) => _surPaquet(uid, cle, s), onError: erreur);
    }
    _composerFil(uid);
  }

  void _arreter() {
    for (final e in [..._ecoutes, ..._ecoutesAmis.values, for (final l in _ecoutesPub.values) ...l]) {
      e.cancel();
    }
    _ecoutes.clear();
    _ecoutesAmis.clear();
    _desAmis.clear();
    _ecoutesPub.clear();
    _personnes.clear();
    _enLecture.clear();
    _relu.clear();
    _communsLus.clear();
    _amis.clear();
    _recues.clear();
    _envoyees.clear();
    _bloques.clear();
    _fil = _miennes = _provisoire = const [];
    _reactions.clear();
    _commentaires.clear();
    _demandesVues.clear();
    _amisRetenus = null;
    _memoireLue = _premierAccord = false;
    _amisLus = _filLu = false;
    _recherche = '';
    _trouves = const [];
    _etatPseudo = EtatPseudo.inconnu;
    _signature = null;
    _acces = null;
    _montre = const {};
  }

  @override
  void dispose() {
    _arreter();
    super.dispose();
  }

  /// Le pseudo que ma carte porte sur le serveur, relu à chaque fois : un
  /// autre téléphone a pu le changer. Lève une erreur si la lecture échoue
  /// (sans réseau, on ne sait pas quel pseudo rendre).
  Future<String?> _lireMaCarte(String uid) async {
    final d = await _profils.doc(uid).get();
    return d.data()?['pseudoMin'] as String?;
  }

  Future<void> _lireMemoire(String uid) async {
    Set<String>? amis;
    try {
      final j = await store?.readObject(_fichier);
      final ids = j?[uid];
      if (ids is List && _moi == uid) {
        _demandesVues.addAll(ids.whereType<String>());
        notifyListeners();
      }
      final a = j?['amis.$uid'];
      if (a is List) amis = a.whereType<String>().toSet();
    } catch (_) {}
    if (_moi != uid) return;
    _amisRetenus = amis;
    _memoireLue = true;
    _accorderAuDemarrage(uid);
  }

  /// Ce que je retiens d'un lancement à l'autre : à qui j'ai demandé, et
  /// mes amis.
  void _retenirDemandes() {
    final uid = _moi, s = store;
    if (uid == null || s == null || !_memoireLue) return;
    unawaited(s.write(_fichier, {
      uid: _demandesVues.toList()..sort(),
      if (_amisLus) 'amis.$uid': _amis.keys.toList()..sort(),
    }).catchError((_) {}));
  }

  /// Une fois au démarrage, mes amis et la mémoire lus : ceux partis depuis
  /// le dernier lancement sortent de toutes mes séances. Sans mémoire
  /// (premier lancement sur ce téléphone), toutes mes séances sont revues.
  void _accorderAuDemarrage(String uid) {
    if (_premierAccord || !_memoireLue || !_amisLus || uid != _moi) return;
    _premierAccord = true;
    final retenus = _amisRetenus;
    if (retenus == null) {
      unawaited(_balayer());
    } else {
      for (final id in retenus.difference(_amis.keys.toSet())) {
        unawaited(_balayer(parti: id));
      }
    }
    _retenirDemandes();
  }

  // --------------------------------------------------------------- écoutes

  void _surAmis(String uid, QuerySnapshot<Map<String, dynamic>> s) {
    if (uid != _moi) return;
    final avant = _amis.keys.toSet();
    _amis
      ..clear()
      ..addAll({for (final d in s.docs) d.id: _date(d.data()['depuis'])});
    final premiere = !_amisLus;
    _amisLus = true;
    // Un nouvel ami : son profil réservé aux amis s'ouvre, on le relit.
    for (final id in _amis.keys) {
      if (!avant.contains(id)) unawaited(_charger(id, force: true));
    }
    // Un ami parti (retiré, bloqué, d'un côté ou de l'autre) : il sort de
    // toutes mes séances, pas seulement des récentes. Une amitié défaite
    // n'a plus de demande acceptée à annoncer.
    if (!premiere) {
      final partis = avant.difference(_amis.keys.toSet());
      for (final id in partis) {
        unawaited(_balayer(parti: id));
      }
      if (_demandesVues.any(partis.contains)) _demandesVues.removeAll(partis);
    }
    _retenirDemandes();
    _accorderAuDemarrage(uid);
    _suivreAmis(uid);
    _accorderMesSeances();
    notifyListeners();
  }

  void _surDemandes(String uid, QuerySnapshot<Map<String, dynamic>> s, {required bool recues}) {
    if (uid != _moi) return;
    final cible = recues ? _recues : _envoyees;
    cible
      ..clear()
      ..addAll({for (final d in s.docs) '${d.data()[recues ? 'de' : 'vers']}': _date(d.data()['date'])});
    for (final id in cible.keys) {
      unawaited(_charger(id));
    }
    if (!recues && !_demandesVues.containsAll(cible.keys)) {
      _demandesVues.addAll(cible.keys);
      _retenirDemandes();
    }
    notifyListeners();
  }

  void _surBlocages(String uid, QuerySnapshot<Map<String, dynamic>> s) {
    if (uid != _moi) return;
    _bloques
      ..clear()
      ..addAll(s.docs.map((d) => d.id));
    for (final id in _bloques) {
      unawaited(_charger(id, details: false));
    }
    notifyListeners();
  }

  void _surMiennes(String uid, QuerySnapshot<Map<String, dynamic>> s) {
    if (uid != _moi) return;
    _miennes = [
      for (final d in s.docs) ?_brute(d.id, d.data()),
    ];
    _filLu = true;
    _composerFil(uid);
    _accorderMesSeances();
  }

  void _surPaquet(String uid, String cle, QuerySnapshot<Map<String, dynamic>> s) {
    if (uid != _moi || !_ecoutesAmis.containsKey(cle)) return;
    _desAmis[cle] = [
      for (final d in s.docs) ?_brute(d.id, d.data()),
    ];
    // Tous les paquets ont répondu : le provisoire n'a plus lieu d'être.
    if (_ecoutesAmis.keys.every(_desAmis.containsKey)) _provisoire = const [];
    _composerFil(uid);
  }

  /// Mes séances et celles de mes amis, la plus récente d'abord ; puis les
  /// réactions et commentaires suivis.
  void _composerFil(String uid) {
    final vues = <String>{};
    _fil = [
      for (final b in [..._miennes, for (final l in _desAmis.values) ...l, ..._provisoire])
        if (vues.add(b.p.id)) b,
    ]..sort((a, b) => b.p.date.compareTo(a.p.date));
    for (final b in _fil) {
      if (b.auteur != uid) unawaited(_charger(b.auteur));
    }
    // Les réactions et commentaires : de toutes mes séances, et des
    // premières séances des autres.
    final suivies = {
      for (final b in _fil)
        if (b.auteur == uid) b.p.id,
      ..._fil.where((b) => b.auteur != uid).take(maxEcoutees).map((b) => b.p.id),
    };
    for (final id in _ecoutesPub.keys.toList()) {
      if (!suivies.contains(id)) {
        for (final e in _ecoutesPub.remove(id)!) {
          e.cancel();
        }
        _reactions.remove(id);
        _commentaires.remove(id);
      }
    }
    for (final id in suivies) {
      _ecoutesPub[id] ??= _suivre(uid, id);
    }
    notifyListeners();
  }

  List<StreamSubscription<Object?>> _suivre(String uid, String id) {
    void erreur(Object e) => debugPrint('Communauté : séance $id illisible ($e)');
    final doc = _publications.doc(id);
    return [
      doc.collection('reactions').snapshots().listen((s) {
        if (uid != _moi) return;
        _reactions[id] = {
          for (final d in s.docs)
            if (Reaction.values.asNameMap()[d.data()['type']] case final r?) d.id: (r, _date(d.data()['date'])),
        };
        for (final qui in _reactions[id]!.keys) {
          if (qui != uid) unawaited(_charger(qui));
        }
        notifyListeners();
      }, onError: erreur),
      doc.collection('commentaires').snapshots().listen((s) {
        if (uid != _moi) return;
        _commentaires[id] = [
          for (final d in s.docs)
            if (d.data()['auteur'] case final String auteur)
              Commentaire(id: d.id, publicationId: id, amiId: auteur == uid ? null : auteur, texte: '${d.data()['texte'] ?? ''}', date: _date(d.data()['date'])),
        ];
        for (final c in _commentaires[id]!) {
          if (!c.mien) unawaited(_charger(c.amiId!));
        }
        notifyListeners();
      }, onError: erreur),
    ];
  }

  _Brute? _brute(String id, Map<String, dynamic> j) {
    final auteur = j['auteur'];
    if (auteur is! String) return null;
    final records = j['records'];
    return _Brute(
      Publication(
        id: id,
        amiId: auteur,
        titre: '${j['titre'] ?? 'Séance'}',
        date: _date(j['date']),
        duree: Duration(seconds: (j['dureeSec'] as num?)?.toInt() ?? 0),
        volumeKg: (j['volumeKg'] as num?)?.toDouble() ?? 0,
        series: (j['series'] as num?)?.toInt() ?? 0,
        exercices: [for (final e in (j['exercices'] as List?) ?? const []) '$e'],
        records: records is num ? records.toInt() : (records is List ? records.length : 0),
        note: j['note'] as String?,
        seanceId: j['seanceId'] as String?,
      ),
      auteur,
      [for (final v in (j['visiblePar'] as List?) ?? const []) '$v'],
      volume: j.containsKey('volumeKg'),
    );
  }

  // --------------------------------------------------------------- profils

  /// Lit la carte (et, si permis, les détails) d'une personne. Une seule
  /// lecture à la fois par personne ; déjà en mémoire, rien n'est relu sans
  /// [force].
  Future<void> _charger(String id, {bool details = true, bool force = false}) {
    if (id == _moi) return Future.value();
    if (!force && _personnes.containsKey(id)) return Future.value();
    // Le rappel ne rend rien : rendre le futur retiré le ferait s'attendre lui-même.
    return _enLecture[id] ??= _lire(id, details: details).whenComplete(() {
      _enLecture.remove(id);
    });
  }

  Future<void> _lire(String id, {required bool details}) async {
    final uid = _moi;
    try {
      final carte = await _profils.doc(id).get();
      Map<String, dynamic>? det;
      if (details && carte.exists) {
        try {
          det = (await _details(id).get()).data();
        } catch (_) {
          // Réservé à ses amis, ou privé : on n'en voit que la carte.
        }
      }
      if (uid != _moi) return;
      final ancien = _personnes[id];
      _personnes[id] = carte.exists
          ? _ami(id, carte.data()!, det, enCommun: ancien?.enCommun ?? const [])
          // Sans carte (compte effacé) : une pastille grise, sans nom.
          : ancien ?? Ami(id: id, prenom: '', pseudo: '', couleur: _gris, acces: AccesProfil.personne, montre: const {});
      _relu[id] = _horloge();
      notifyListeners();
    } catch (e) {
      debugPrint('Communauté : profil $id illisible ($e)');
    }
  }

  Ami _ami(String id, Map<String, dynamic> carte, Map<String, dynamic>? det, {List<String> enCommun = const []}) {
    final d = det ?? const <String, dynamic>{};
    final aujourdhui = _seulJour(_horloge());
    Uint8List? vignette;
    final photo = carte['photo'];
    if (photo is String && photo.isNotEmpty) {
      try {
        vignette = base64Decode(photo);
      } catch (_) {}
    }
    // Rien n'est cru sur parole : un nombre infini ou d'un autre type ne
    // rend pas tout le profil illisible.
    int? nombre(Object? v) => v is num && v.isFinite ? v.toInt() : null;
    String? texte(String cle) => d[cle] is String && (d[cle] as String).trim().isNotEmpty ? d[cle] as String : null;
    int entier(String cle) => nombre(d[cle]) ?? 0;
    final grades = Grade.values.asNameMap(), visibles = Visible.values.asNameMap();
    return Ami(
      id: id,
      prenom: '${carte['prenom'] ?? ''}'.trim(),
      pseudo: '${carte['pseudo'] ?? ''}',
      couleur: nombre(carte['couleur']) ?? _gris,
      vignette: vignette,
      phrase: texte('phrase'),
      ville: texte('ville'),
      salle: texte('salle'),
      depuis: nombre(d['depuis']),
      acces: switch (carte['acces']) {
        'tous' => AccesProfil.tous,
        'prive' => AccesProfil.personne,
        _ => AccesProfil.amis,
      },
      montre: {for (final v in d['montre'] is List ? d['montre'] as List : const []) ?visibles['$v']},
      serieSemaines: entier('serieSemaines'),
      seances: entier('seances'),
      heures: entier('heures'),
      objectif: texte('objectif'),
      niveau: texte('niveau'),
      // Les jours sont écrits en jours depuis 1970 : ils ne vieillissent pas.
      jours: [
        for (final j in d['jours'] is List ? d['jours'] as List : const [])
          if (nombre(j) case final n? when n.abs() < 1000000) aujourdhui.difference(_jour(n)).inDays,
      ],
      records: [
        for (final r in d['records'] is List ? d['records'] as List : const [])
          if (r is Map && r['exercice'] is String) RecordAmi(r['exercice'] as String, r['kg'] is num && (r['kg'] as num).isFinite ? (r['kg'] as num).toDouble() : 0, nombre(r['reps']) ?? 1),
      ],
      badges: {
        for (final MapEntry(:key, :value) in (d['badges'] is Map ? d['badges'] as Map : const {}).entries)
          if ((grades[key], nombre(value)) case (final g?, final v?)) g: v,
      },
      fetiches: [for (final f in d['fetiches'] is List ? d['fetiches'] as List : const []) '$f'],
      amis: entier('nbAmis'),
      enCommun: enCommun,
    );
  }

  static DateTime _seulJour(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _jour(int n) {
    final u = DateTime.utc(1970).add(Duration(days: n));
    return DateTime(u.year, u.month, u.day);
  }

  static int _numeroJour(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1970)).inDays;

  @override
  void voir(String id) {
    if (id == _moi || _moi == null) return;
    // Le profil et nos amis en commun : relus au plus une fois par minute.
    bool vieux(DateTime? d) => d == null || _horloge().difference(d) > const Duration(minutes: 1);
    final profil = vieux(_relu[id]), communs = vieux(_communsLus[id]);
    if (!profil && !communs) return;
    unawaited((profil ? _charger(id, force: true) : Future<void>.value()).then((_) => communs ? _lireEnCommun(id) : null));
  }

  /// Nos amis en commun : sa liste est lisible par ses amis, sauf s'il est privé.
  Future<void> _lireEnCommun(String id) async {
    final a = _personnes[id];
    if (a == null || !_amis.containsKey(id) || a.acces == AccesProfil.personne) return;
    try {
      final s = await _liste('amis', id).get();
      _communsLus[id] = _horloge();
      final communs = [
        for (final d in s.docs)
          if (d.id != _moi && _amis.containsKey(d.id)) d.id,
      ];
      final b = _personnes[id];
      if (b == null) return;
      _personnes[id] = _avecEnCommun(b, communs);
      for (final c in communs) {
        unawaited(_charger(c));
      }
      notifyListeners();
    } catch (_) {}
  }

  static Ami _avecEnCommun(Ami a, List<String> enCommun) => Ami(
        id: a.id,
        prenom: a.prenom,
        pseudo: a.pseudo,
        couleur: a.couleur,
        photo: a.photo,
        vignette: a.vignette,
        phrase: a.phrase,
        ville: a.ville,
        salle: a.salle,
        depuis: a.depuis,
        acces: a.acces,
        montre: a.montre,
        serieSemaines: a.serieSemaines,
        seances: a.seances,
        heures: a.heures,
        objectif: a.objectif,
        niveau: a.niveau,
        jours: a.jours,
        records: a.records,
        badges: a.badges,
        fetiches: a.fetiches,
        amis: a.amis,
        enCommun: enCommun,
      );

  // ---------------------------------------------------------------- lectures

  @override
  Lien lien(String id) {
    if (_bloques.contains(id)) return Lien.bloque;
    if (_amis.containsKey(id)) return Lien.ami;
    if (_recues.containsKey(id)) return Lien.demandeRecue;
    if (_envoyees.containsKey(id)) return Lien.demandeEnvoyee;
    return Lien.aucun;
  }

  @override
  Ami? ami(String id) => _personnes[id];

  @override
  List<Ami> avec(Lien l) {
    List<String> recents(Map<String, DateTime> m) => (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
    final ids = switch (l) {
      Lien.ami => _amis.keys.toList(),
      Lien.demandeRecue => recents(_recues),
      Lien.demandeEnvoyee => recents(_envoyees),
      Lien.bloque => _bloques.toList(),
      Lien.aucun => const <String>[],
    };
    final gens = [
      for (final id in ids)
        if (lien(id) == l) ?_personnes[id],
    ];
    if (l == Lien.ami || l == Lien.bloque) gens.sort((a, b) => aPlat(a.prenom).compareTo(aPlat(b.prenom)));
    return gens;
  }

  /// Le répertoire du téléphone n'est pas encore lu : pas de suggestions.
  @override
  List<Ami> get suggestions => const [];

  /// Les séances de mes amis seulement : la requête ne prend qu'eux, et un
  /// ami bloqué ou retiré à l'instant sort aussitôt.
  @override
  List<Publication> get publications => [
        for (final b in _fil)
          if (b.auteur != _moi && _amis.containsKey(b.auteur) && !_bloques.contains(b.auteur)) b.p,
      ];

  @override
  Publication? publication(String id) => _fil.where((b) => b.p.id == id).firstOrNull?.p;

  @override
  Set<DateTime> joursDe(Ami a) {
    final n = _seulJour(_horloge());
    return {
      for (final j in a.jours) DateTime(n.year, n.month, n.day - j),
      for (final b in _fil)
        if (b.auteur == a.id) _seulJour(b.p.date),
    };
  }

  @override
  Reaction? reaction(String publicationId) => _reactions[publicationId]?[_moi]?.$1;

  @override
  int bravos(Publication p) => _reactions[p.id]?.length ?? 0;

  @override
  List<Commentaire> commentaires(String publicationId) => _commentaires[publicationId] ?? const [];

  /// Calculées dans l'appli (pas de Cloud Functions) : les réactions et les
  /// commentaires reçus sur mes séances des 30 derniers jours, les amis qui
  /// ont accepté ma demande, les records de mes amis.
  @override
  List<Activite> activites({String? maSeance, String? nomSeance, DateTime? finSeance}) {
    final uid = _moi;
    if (uid == null) return const [];
    final limite = _horloge().subtract(fenetre);
    final out = <Activite>[];
    for (final b in _miennes) {
      final p = b.p;
      final recues = [
        for (final MapEntry(:key, :value) in (_reactions[p.id] ?? const <String, (Reaction, DateTime)>{}).entries)
          // Une personne bloquée sort de la ligne, pas les autres.
          if (key != uid && !_bloques.contains(key)) (key, value.$1, value.$2),
      ]..sort((a, b) => b.$3.compareTo(a.$3));
      if (recues.isNotEmpty) {
        out.add(Activite(
          type: TypeActivite.reaction,
          amis: [for (final r in recues) r.$1],
          date: recues.first.$3,
          seanceId: p.seanceId,
          publicationId: p.id,
          reaction: recues.first.$2,
          texte: p.titre,
        ));
      }
      for (final c in commentaires(p.id)) {
        if (!c.mien && !_bloques.contains(c.amiId)) out.add(Activite(type: TypeActivite.commentaire, amis: [c.amiId!], date: c.date, seanceId: p.seanceId, publicationId: p.id, texte: c.texte));
      }
    }
    for (final MapEntry(key: id, value: depuis) in _amis.entries) {
      if (_demandesVues.contains(id) && depuis.isAfter(limite)) out.add(Activite(type: TypeActivite.accepte, amis: [id], date: depuis));
    }
    for (final b in _fil) {
      if (b.auteur != uid && _amis.containsKey(b.auteur) && !_bloques.contains(b.auteur) && b.p.records > 0) {
        out.add(Activite(type: TypeActivite.record, amis: [b.auteur], date: b.p.date, publicationId: b.p.id, texte: b.p.titre));
      }
    }
    return out..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Les pseudos qui commencent par [texte]. La recherche part au serveur
  /// quand le texte change ; la réponse arrive par [notifyListeners].
  @override
  List<Ami> chercher(String texte) {
    final t = texte.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    if (t.isEmpty || _moi == null) return const [];
    if (t != _recherche) {
      _recherche = t;
      unawaited(_chercher(t));
    }
    return [
      for (final id in _trouves)
        if (id != _moi && lien(id) != Lien.bloque) ?_personnes[id],
    ];
  }

  Future<void> _chercher(String t) async {
    try {
      final s = await _profils.where('pseudoMin', isGreaterThanOrEqualTo: t).where('pseudoMin', isLessThan: '$t').orderBy('pseudoMin').limit(20).get();
      if (t != _recherche) return;
      for (final d in s.docs) {
        // Une carte suffit à la liste ; une personne déjà lue garde ses détails.
        _personnes.putIfAbsent(d.id, () => _ami(d.id, d.data(), null));
      }
      _trouves = [for (final d in s.docs) d.id];
      notifyListeners();
    } catch (e) {
      debugPrint('Communauté : recherche impossible ($e)');
    }
  }

  @override
  Future<String?> trouverPseudo(String pseudo) async {
    final t = aPlat(pseudo);
    if (_moi == null || !pseudoPermis.hasMatch(t)) return null;
    try {
      final d = await _pseudos.doc(t).get();
      final uid = d.data()?['uid'];
      if (uid is! String) return null;
      await _charger(uid);
      return uid;
    } catch (_) {
      return null;
    }
  }

  /// Ce pseudo est-il libre (ou déjà à moi) ?
  Future<bool> pseudoLibre(String pseudo) async {
    final t = pseudo.trim().toLowerCase();
    if (!pseudoPermis.hasMatch(t)) return false;
    final uid = (await _pseudos.doc(t).get()).data()?['uid'];
    return uid == null || uid == _moi;
  }

  // ------------------------------------------------------------------ gestes

  /// Une écriture refusée (règles, réseau coupé trop longtemps) : l'écoute
  /// remet l'état d'accord avec le serveur ; ici, on le note seulement.
  Future<void> _ecrire(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('Communauté : écriture refusée ($e)');
    }
  }

  @override
  Future<void> reagir(String publicationId, Reaction? r) async {
    final uid = _moi;
    if (uid == null) return;
    final m = _reactions[publicationId] ??= {};
    if (r == null) {
      m.remove(uid);
    } else {
      m[uid] = (r, _horloge());
    }
    notifyListeners();
    final doc = _publications.doc(publicationId).collection('reactions').doc(uid);
    await _ecrire(() => r == null ? doc.delete() : doc.set({'type': r.name, 'date': _maintenantServeur}));
  }

  @override
  Future<void> commenter(String publicationId, String texte, {DateTime? maintenant}) async {
    final uid = _moi;
    if (uid == null) return;
    final t = texte.length > 500 ? texte.substring(0, 500) : texte;
    await _ecrire(() => _publications.doc(publicationId).collection('commentaires').add({'auteur': uid, 'texte': t, 'date': _maintenantServeur}));
  }

  @override
  Future<void> retirerCommentaire(String id) async {
    for (final MapEntry(key: pub, value: liste) in _commentaires.entries) {
      final c = liste.where((c) => c.id == id).firstOrNull;
      if (c == null) continue;
      // Le mien, ou un commentaire sous ma séance.
      if (!c.mien && _fil.where((b) => b.p.id == pub).firstOrNull?.auteur != _moi) return;
      _commentaires[pub] = [...liste]..remove(c);
      notifyListeners();
      await _ecrire(() => _publications.doc(pub).collection('commentaires').doc(id).delete());
      return;
    }
  }

  @override
  Future<void> inviter(String id) async {
    final uid = _moi;
    if (uid == null || id == uid) return;
    _envoyees[id] = _horloge();
    _demandesVues.add(id);
    _retenirDemandes();
    unawaited(_charger(id));
    notifyListeners();
    await _ecrire(() => _demande(uid, id).set({'de': uid, 'vers': id, 'date': _maintenantServeur}));
  }

  /// En un lot : les deux sens de l'amitié, et les deux demandes effacées,
  /// la sienne et la mienne s'il y en a une, sans se fier à ce que l'écoute
  /// a déjà vu (les règles exigent qu'aucune ne survive : sinon elle
  /// servirait à se refaire ami seul après un retrait ; effacer une demande
  /// absente est permis).
  @override
  Future<void> accepter(String id) async {
    final uid = _moi;
    if (uid == null) return;
    final lot = base.batch()
      ..set(_liste('amis', uid).doc(id), {'depuis': _maintenantServeur})
      ..set(_liste('amis', id).doc(uid), {'depuis': _maintenantServeur})
      ..delete(_demande(id, uid))
      ..delete(_demande(uid, id));
    _recues.remove(id);
    _envoyees.remove(id);
    // C'est moi qui accepte : pas de « a accepté ta demande » à annoncer,
    // même s'il me restait une ancienne demande vers lui.
    if (_demandesVues.remove(id)) _retenirDemandes();
    _amis[id] = _horloge();
    _suivreAmis(uid);
    notifyListeners();
    await _ecrire(lot.commit);
    unawaited(_charger(id, force: true));
  }

  @override
  Future<void> refuser(String id) async {
    final uid = _moi;
    if (uid == null) return;
    _recues.remove(id);
    notifyListeners();
    await _ecrire(() => _demande(id, uid).delete());
  }

  @override
  Future<void> annulerInvitation(String id) async {
    final uid = _moi;
    if (uid == null) return;
    _envoyees.remove(id);
    _demandesVues.remove(id);
    _retenirDemandes();
    notifyListeners();
    await _ecrire(() => _demande(uid, id).delete());
  }

  @override
  Future<void> retirer(String id) async {
    final uid = _moi;
    if (uid == null) return;
    _amis.remove(id);
    if (_demandesVues.remove(id)) _retenirDemandes();
    _suivreAmis(uid);
    _accorderMesSeances();
    notifyListeners();
    final lot = base.batch()
      ..delete(_liste('amis', uid).doc(id))
      ..delete(_liste('amis', id).doc(uid));
    await _ecrire(lot.commit);
    // Il sort de toutes mes séances, les vieilles comprises.
    await _balayer(parti: id);
  }

  /// Bloquer retire aussi l'amitié et les demandes, dans les deux sens.
  @override
  Future<void> bloquer(String id) async {
    final uid = _moi;
    if (uid == null || id == uid) return;
    _bloques.add(id);
    _amis.remove(id);
    _recues.remove(id);
    _envoyees.remove(id);
    if (_demandesVues.remove(id)) _retenirDemandes();
    _suivreAmis(uid);
    _accorderMesSeances();
    unawaited(_charger(id, details: false));
    notifyListeners();
    final lot = base.batch()
      ..set(_liste('blocages', uid).doc(id), {'date': _maintenantServeur})
      ..delete(_liste('amis', uid).doc(id))
      ..delete(_liste('amis', id).doc(uid))
      ..delete(_demande(uid, id))
      ..delete(_demande(id, uid));
    await _ecrire(lot.commit);
    // Il sort de toutes mes séances, les vieilles comprises (les règles lui
    // refusent déjà d'y réagir ou d'y commenter).
    await _balayer(parti: id);
  }

  @override
  Future<void> debloquer(String id) async {
    final uid = _moi;
    if (uid == null) return;
    _bloques.remove(id);
    notifyListeners();
    await _ecrire(() => _liste('blocages', uid).doc(id).delete());
  }

  // ------------------------------------------------------------ ce que je publie

  /// Publie ma carte et mes détails, seulement ce que `montre` autorise
  /// (et presque rien pour un profil privé). Le pseudo est réservé dans le
  /// même lot ; l'ancien est rendu. Rien ne part si rien n'a changé.
  Future<EtatPseudo> publierProfil(MonProfilPublic m) async {
    final uid = _moi;
    if (uid == null) return _etatPseudo;
    final a = m.personne;
    final ouvertes = _acces != null && _seancesOuvertes;
    _acces = a.acces;
    _montre = a.montre;
    // Je viens de fermer mes séances (privé, ou séances cachées) : toutes,
    // pas seulement les récentes, ne restent qu'à moi.
    if (ouvertes && !_seancesOuvertes) unawaited(_balayer());
    final min = a.pseudo.trim().toLowerCase();
    if (!pseudoPermis.hasMatch(min)) {
      _poserPseudo(EtatPseudo.invalide);
      _accorderMesSeances();
      return _etatPseudo;
    }
    final carte = <String, Object?>{
      'pseudo': min,
      'pseudoMin': min,
      'prenom': _coupe(a.prenom.trim(), 40),
      'couleur': a.couleur,
      if (m.vignette != null && m.vignette!.length <= 40000) 'photo': m.vignette,
      'acces': switch (a.acces) {
        AccesProfil.tous => 'tous',
        AccesProfil.amis => 'amis',
        AccesProfil.personne => 'prive',
      },
    };
    final details = detailsPublies(a, m.jours, maintenant: _horloge());
    final signature = jsonEncode([carte, details]);
    if (signature == _signature && _etatPseudo == EtatPseudo.ok) {
      _accorderMesSeances();
      return _etatPseudo;
    }
    try {
      // Ma carte relue à chaque fois : un autre téléphone a pu changer de
      // pseudo, et les règles exigent de rendre celui qu'elle porte vraiment.
      final ancien = await _lireMaCarte(uid);
      final proprio = (await _pseudos.doc(min).get()).data()?['uid'];
      if (uid != _moi) return _etatPseudo;
      if (proprio != null && proprio != uid) {
        _poserPseudo(EtatPseudo.pris);
        return _etatPseudo;
      }
      final lot = base.batch();
      if (proprio == null) lot.set(_pseudos.doc(min), {'uid': uid});
      lot.set(_profils.doc(uid), {...carte, 'majLe': _maintenantServeur});
      if (ancien != null && ancien != min) lot.delete(_pseudos.doc(ancien));
      lot.set(_details(uid), {...details, 'majLe': _maintenantServeur});
      await lot.commit();
      _signature = signature;
      _poserPseudo(EtatPseudo.ok);
    } on FirebaseException catch (e) {
      // Refusé : « pris » seulement si le pseudo est bien à un autre (pris
      // entre la lecture et l'écriture) ; sinon on ne sait pas, on retentera.
      debugPrint('Communauté : profil refusé ($e)');
      var etat = EtatPseudo.inconnu;
      if (e.code == 'permission-denied') {
        try {
          final proprio = (await _pseudos.doc(min).get()).data()?['uid'];
          if (proprio != null && proprio != uid) etat = EtatPseudo.pris;
        } catch (_) {}
      }
      _signature = null;
      _poserPseudo(etat);
    } catch (e) {
      debugPrint('Communauté : profil non publié ($e)');
    }
    _accorderMesSeances();
    return _etatPseudo;
  }

  void _poserPseudo(EtatPseudo e) {
    if (_etatPseudo == e) return;
    _etatPseudo = e;
    notifyListeners();
  }

  /// Coupe à [max] unités UTF-16 (ce que comptent les règles), sans couper
  /// un emoji en deux.
  static String _coupe(String s, int max) {
    if (s.length <= max) return s;
    var n = max;
    final u = s.codeUnitAt(n - 1);
    if (u >= 0xD800 && u <= 0xDBFF) n--;
    return s.substring(0, n);
  }

  /// Mes détails tels qu'ils partent : seulement ce que [Ami.montre]
  /// autorise. Un profil privé n'envoie que la liste vide de ce qu'il montre.
  static Map<String, Object?> detailsPublies(Ami a, Set<DateTime> jours, {required DateTime maintenant}) {
    final v = a.montre;
    if (a.acces == AccesProfil.personne) return {'montre': const <String>[]};
    String? texte(String? s, int max) => s == null || s.trim().isEmpty ? null : _coupe(s.trim(), max);
    final derniers = jours.where((j) => !j.isAfter(maintenant)).toList()..sort((x, y) => y.compareTo(x));
    return {
      'phrase': ?texte(a.phrase, 160),
      if (v.contains(Visible.lieu)) ...{
        'ville': ?texte(a.ville, 60),
        'salle': ?texte(a.salle, 60),
      },
      if (a.depuis case final an? when an >= 1900 && an <= 3000) 'depuis': an,
      'montre': [
        for (final x in Visible.values)
          if (v.contains(x)) x.name,
      ],
      if (v.contains(Visible.nbSeances)) 'seances': a.seances,
      if (v.contains(Visible.heures)) 'heures': a.heures.clamp(0, 1000000),
      if (v.contains(Visible.serie)) ...{
        'serieSemaines': a.serieSemaines,
        // Les règles en gardent sept : les plus récents.
        'jours': [for (final j in derniers.take(7)) _numeroJour(j)],
      },
      if (v.contains(Visible.objectif)) 'objectif': ?texte(a.objectif, 60),
      if (v.contains(Visible.niveau)) 'niveau': ?texte(a.niveau, 40),
      if (v.contains(Visible.records))
        'records': [
          // Les règles en gardent quatre, ceux que le profil montre.
          for (final r in a.records.take(4))
            if (r.kg.isFinite && r.kg >= 0 && r.kg <= 2000) {'exercice': _coupe(r.exerciceId, 100), 'kg': r.kg, 'reps': r.reps.clamp(0, 1000)},
        ],
      if (v.contains(Visible.badges)) 'badges': {for (final MapEntry(:key, :value) in a.badges.entries.take(20)) key.name: value},
      if (v.contains(Visible.seances)) 'fetiches': [for (final f in a.fetiches.take(10)) _coupe(f, 100)],
      if (v.contains(Visible.nbAmis)) 'nbAmis': a.amis,
    };
  }

  bool get _seancesOuvertes => _acces != AccesProfil.personne && _montre.contains(Visible.seances);

  /// Ceux qui verront mes séances : moi et mes amis, ou moi seul si je les
  /// cache ou si mon profil est privé.
  List<String> _visiblePar() {
    final uid = _moi!;
    if (!_seancesOuvertes) return [uid];
    return [uid, ...(_amis.keys.toList()..sort()).take(499)];
  }

  /// L'identifiant d'une séance publiée : la même séance n'est publiée qu'une fois.
  /// Les règles exigent `{auteur}_{seanceId}` (les « / » en « _ ») : personne
  /// d'autre ne peut le prendre.
  String _idPublication(String seanceId) => '${_moi}_${_coupe(seanceId, 100).replaceAll('/', '_')}';

  /// Publie une séance terminée dans le fil de mes amis. Rien si je cache
  /// mes séances, si mon profil est privé, ou si ma carte n'est pas en ligne
  /// (les règles relisent mon accès dans la carte). Le volume ne part pas
  /// si je cache mes charges.
  Future<void> publierSeance(Publication p) async {
    final uid = _moi, seanceId = p.seanceId ?? p.id;
    if (uid == null || _etatPseudo != EtatPseudo.ok || _acces == null || !_seancesOuvertes) return;
    final titre = p.titre.trim().isEmpty ? 'Séance' : _coupe(p.titre.trim(), 80);
    await _ecrire(() => _publications.doc(_idPublication(seanceId)).set({
          'auteur': uid,
          'seanceId': _coupe(seanceId, 100),
          'titre': titre,
          'date': Timestamp.fromDate(p.date),
          'dureeSec': p.duree.inSeconds.clamp(0, 86400),
          if (_montre.contains(Visible.charges) && p.volumeKg > 0) 'volumeKg': p.volumeKg,
          'series': p.series.clamp(0, 1000),
          'exercices': [for (final e in p.exercices.take(6)) _coupe(e, 100)],
          'records': p.records.clamp(0, 1000),
          if (p.note != null && p.note!.trim().isNotEmpty) 'note': _coupe(p.note!.trim(), 280),
          'visiblePar': _visiblePar(),
          'majLe': _maintenantServeur,
        }));
  }

  /// Une séance effacée sur le téléphone quitte le fil, avec ses réactions
  /// et ses commentaires (Firestore n'efface pas ce qui est dessous, et
  /// rien d'autre ne le ferait sans Cloud Functions).
  Future<void> retirerSeance(String seanceId) async {
    if (_moi == null) return;
    final doc = _publications.doc(_idPublication(seanceId));
    await _ecrire(() async {
      for (final sous in ['reactions', 'commentaires']) {
        final s = await doc.collection(sous).get();
        // Par lots de 50 : les règles évaluent 1 000 expressions par requête.
        for (var i = 0; i < s.docs.length; i += 50) {
          final lot = base.batch();
          for (final d in s.docs.skip(i).take(50)) {
            lot.delete(d.reference);
          }
          await lot.commit();
        }
      }
      await doc.delete();
    });
  }

  /// Mes séances des 30 derniers jours suivent mes amis et mes réglages :
  /// `visiblePar` réécrit quand mes amis changent, le volume retiré si je
  /// cache mes charges. Une écriture par séance : un lot de plusieurs
  /// séances dépasserait ce que les règles évaluent par requête.
  void _accorderMesSeances() {
    final uid = _moi;
    if (uid == null || !_amisLus || !_filLu || _acces == null) return;
    final voulu = _visiblePar();
    for (final b in _miennes) {
      final maj = <String, Object?>{
        if (!setEquals(b.visiblePar.toSet(), voulu.toSet())) 'visiblePar': voulu,
        if (b.volume && !_montre.contains(Visible.charges)) 'volumeKg': FieldValue.delete(),
      };
      if (maj.isEmpty) continue;
      // L'écoute de mes séances voit l'écriture aussitôt : l'accord suivant n'a plus rien à faire.
      unawaited(_ecrire(() => _publications.doc(b.p.id).update({...maj, 'majLe': _maintenantServeur})));
    }
  }

  /// Toutes mes séances, les vieilles comprises, ne gardent dans
  /// `visiblePar` que moi et mes amis : celui qui est [parti] (retiré,
  /// bloqué) n'y lit plus rien. Sans [parti], toutes sont revues (premier
  /// lancement sur ce téléphone, séances fermées).
  Future<void> _balayer({String? parti}) async {
    final uid = _moi;
    if (uid == null || !_amisLus) return;
    try {
      var q = _publications.where('auteur', isEqualTo: uid);
      if (parti != null) q = q.where('visiblePar', arrayContains: parti);
      final s = await q.get();
      if (uid != _moi) return;
      final permis = _visiblePar().toSet();
      for (final d in s.docs) {
        final vp = [for (final v in (d.data()['visiblePar'] as List?) ?? const []) '$v'];
        final garde = [for (final v in vp) if (permis.contains(v)) v];
        if (!garde.contains(uid)) garde.insert(0, uid);
        if (setEquals(garde.toSet(), vp.toSet())) continue;
        await _ecrire(() => d.reference.update({'visiblePar': garde, 'majLe': _maintenantServeur}));
      }
    } catch (e) {
      debugPrint('Communauté : séances non revues ($e)');
    }
  }
}
