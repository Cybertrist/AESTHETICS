import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';

/// D'où vient le nombre de pas d'un jour.
enum SourcePas { saisie, sante }

/// Pas quotidiens : saisis à la main ou lus dans Health Connect.
/// Petite collection du module (`aujourdhui_pas`) : objectif, saisies, et
/// dernier relevé de Health Connect pour l'affichage hors ligne.
class PasRepo extends ChangeNotifier {
  PasRepo(this.store);

  final Store store;
  static const fichier = 'aujourdhui_pas';
  static final _instances = Expando<PasRepo>();

  /// Une instance par stockage, chargée au premier appel.
  static PasRepo pour(Store store) => _instances[store] ??= (PasRepo(store)..pret);

  /// Chargement du fichier, lancé une seule fois.
  late final Future<void> pret = load();

  final Map<String, int> _saisies = {};
  final Map<String, int> _sante = {};
  int _objectif = 10000;
  bool _charge = false;
  bool _synchro = false;
  String? _erreur;
  DateTime? _derniereSynchro;

  int get objectif => _objectif;
  bool get charge => _charge;

  /// Synchronisation Health Connect en cours.
  bool get synchronisation => _synchro;
  String? get erreur => _erreur;
  DateTime? get derniereSynchro => _derniereSynchro;

  static String cle(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    try {
      final j = await store.readObject(fichier);
      if (j != null) {
        _objectif = (j['objectif'] as num?)?.toInt() ?? 10000;
        _saisies
          ..clear()
          ..addAll(_map(j['saisies']));
        _sante
          ..clear()
          ..addAll(_map(j['sante']));
        final s = j['derniereSynchro'];
        _derniereSynchro = s is String ? DateTime.tryParse(s) : null;
      }
    } catch (_) {
      _erreur = 'Impossible de lire tes pas enregistrés.';
    }
    _charge = true;
    notifyListeners();
  }

  static Map<String, int> _map(Object? o) => o is Map ? {for (final e in o.entries) '${e.key}': (e.value as num).toInt()} : {};

  Future<void> _save() => store.write(fichier, {
        'objectif': _objectif,
        'saisies': _saisies,
        'sante': _sante,
        'derniereSynchro': _derniereSynchro?.toIso8601String(),
      });

  /// Pas du jour : la saisie l'emporte sur Health Connect.
  int? pas(DateTime jour) => _saisies[cle(jour)] ?? _sante[cle(jour)];

  SourcePas? source(DateTime jour) {
    if (_saisies.containsKey(cle(jour))) return SourcePas.saisie;
    if (_sante.containsKey(cle(jour))) return SourcePas.sante;
    return null;
  }

  /// Les [n] derniers jours, du plus ancien à [jusqua].
  List<({DateTime jour, int? pas})> derniersJours(int n, {DateTime? jusqua}) {
    final fin = Dates.jour(jusqua ?? DateTime.now());
    return [
      for (var i = n - 1; i >= 0; i--)
        (jour: DateTime(fin.year, fin.month, fin.day - i), pas: pas(DateTime(fin.year, fin.month, fin.day - i))),
    ];
  }

  bool get aDesDonnees => _saisies.isNotEmpty || _sante.isNotEmpty;

  Future<void> saisir(DateTime jour, int pas) async {
    _saisies[cle(jour)] = pas.clamp(0, 200000);
    notifyListeners();
    await _save();
  }

  /// Retire la saisie du jour (Health Connect reprend la main s'il a une valeur).
  Future<void> effacerSaisie(DateTime jour) async {
    _saisies.remove(cle(jour));
    notifyListeners();
    await _save();
  }

  Future<void> definirObjectif(int pas) async {
    _objectif = pas.clamp(1000, 100000);
    notifyListeners();
    await _save();
  }

  /// Demande l'accès aux pas dans Health Connect puis synchronise.
  Future<bool> connecter() async {
    _erreur = null;
    try {
      final h = Health();
      await h.configure();
      if (!await h.isHealthConnectAvailable()) {
        _erreur = 'Health Connect n\'est pas disponible sur ce téléphone.';
        notifyListeners();
        return false;
      }
      final ok = await h.requestAuthorization([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]);
      if (!ok) {
        _erreur = 'Accès aux pas refusé. Tu peux l\'autoriser dans Health Connect.';
        notifyListeners();
        return false;
      }
      return await synchroniser();
    } catch (_) {
      _erreur = 'Health Connect n\'a pas répondu.';
      notifyListeners();
      return false;
    }
  }

  /// Relit les [jours] derniers jours dans Health Connect.
  Future<bool> synchroniser({int jours = 7}) async {
    if (_synchro) return false;
    _synchro = true;
    _erreur = null;
    notifyListeners();
    try {
      final h = Health();
      await h.configure();
      final now = DateTime.now();
      for (var i = 0; i < jours; i++) {
        final debut = DateTime(now.year, now.month, now.day - i);
        final fin = i == 0 ? now : DateTime(now.year, now.month, now.day - i + 1);
        final n = await h.getTotalStepsInInterval(debut, fin);
        if (n != null) _sante[cle(debut)] = n;
      }
      _derniereSynchro = now;
      await _save();
      return true;
    } catch (_) {
      _erreur = 'Impossible de lire les pas dans Health Connect.';
      return false;
    } finally {
      _synchro = false;
      notifyListeners();
    }
  }

  /// Synchronise si la dernière lecture date de plus de [age].
  Future<void> synchroniserSiAncien({Duration age = const Duration(minutes: 15)}) async {
    final d = _derniereSynchro;
    if (d != null && DateTime.now().difference(d) < age) return;
    await synchroniser();
  }
}
