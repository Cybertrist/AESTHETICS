import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Mise en pause de la séance en cours : le chrono se fige, et à la reprise
/// le début de la séance est décalé d'autant pour que la durée ne compte que
/// le temps passé à s'entraîner.
///
/// La pause est gardée sur disque (fichier `seance_pause`) : si l'appli est
/// fermée pendant une pause, [charger] la retrouve au retour et le temps
/// passé appli fermée n'est pas compté.
class PauseSeance extends ChangeNotifier {
  PauseSeance._();

  static final instance = PauseSeance._();

  static const _fichier = 'seance_pause';

  DateTime? _depuis;
  String? _sessionId;
  Store? _store;

  bool enPause(WorkoutSession? s) => s != null && _depuis != null && _sessionId == s.id;

  /// Temps d'entraînement écoulé, figé pendant une pause.
  Duration ecoule(WorkoutSession s, {DateTime? maintenant}) {
    final fin = enPause(s) ? _depuis! : (maintenant ?? DateTime.now());
    final d = fin.difference(s.debut);
    return d.isNegative ? Duration.zero : d;
  }

  /// Relit la pause laissée sur disque (appli fermée en pleine pause). Une
  /// pause qui ne concerne pas la séance en cours est oubliée.
  Future<void> charger(SessionRepo repo) async {
    _store = repo.store;
    if (_depuis != null) return;
    Map<String, dynamic>? j;
    try {
      j = await repo.store.readObject(_fichier);
    } catch (_) {
      j = null;
    }
    if (j == null || _depuis != null) return;
    final id = j['sessionId'];
    final depuis = DateTime.tryParse('${j['depuis']}');
    final active = repo.active;
    // Sans séance (ou dépôt pas encore chargé), on ne touche à rien.
    if (active == null) return;
    if (id != active.id || depuis == null) {
      unawaited(_effacer());
      return;
    }
    _sessionId = active.id;
    // Une date dans le futur (horloge reculée) ne doit pas figer un temps faux.
    final maintenant = DateTime.now();
    _depuis = depuis.isAfter(maintenant) ? maintenant : depuis;
    notifyListeners();
  }

  /// [store] : où garder la pause pour la retrouver après une fermeture.
  void mettreEnPause(WorkoutSession s, {DateTime? maintenant, Store? store}) {
    if (enPause(s)) return;
    if (store != null) _store = store;
    _depuis = maintenant ?? DateTime.now();
    _sessionId = s.id;
    unawaited(_store?.write(_fichier, {'sessionId': s.id, 'depuis': _depuis!.toIso8601String()}));
    notifyListeners();
  }

  /// Reprend : décale le début de la séance de la durée de la pause.
  Future<void> reprendre(SessionRepo repo, {DateTime? maintenant}) async {
    final s = repo.active;
    final depuis = _depuis;
    final concerne = enPause(s);
    _depuis = null;
    _sessionId = null;
    _store ??= repo.store;
    if (concerne && s != null && depuis != null) {
      final pause = (maintenant ?? DateTime.now()).difference(depuis);
      if (!pause.isNegative) await repo.updateActive(s.copyWith(debut: s.debut.add(pause)));
    }
    await _effacer();
    notifyListeners();
  }

  /// Oublie la pause (séance abandonnée ou enregistrée).
  void oublier() {
    unawaited(_effacer());
    if (_depuis == null) return;
    _depuis = null;
    _sessionId = null;
    notifyListeners();
  }

  Future<void> _effacer() async {
    try {
      await _store?.delete(_fichier);
    } catch (_) {
      // Fichier déjà absent ou stockage indisponible : rien à faire.
    }
  }

  /// Pour les tests : l'appli vient d'être relancée, la mémoire est vide.
  @visibleForTesting
  void reinitialiser() {
    _depuis = null;
    _sessionId = null;
    _store = null;
  }
}

/// Chronomètre libre de l'écran de repos (onglet « Chronomètre ») : il compte
/// vers le haut et continue quand on quitte l'écran, parce qu'il compare des
/// heures. Son battement ne tourne que tant qu'un écran l'affiche, et il
/// repart de zéro avec chaque nouvelle séance.
class ChronoLibre extends ChangeNotifier {
  ChronoLibre._();

  static final instance = ChronoLibre._();

  DateTime? _depart;
  Duration _cumul = Duration.zero;
  Timer? _tick;
  String? _sessionId;

  bool get enMarche => _depart != null;

  /// Vrai tant que le battement d'affichage tourne (un écran écoute).
  @visibleForTesting
  bool get bat => _tick != null;

  Duration get ecoule => _cumul + (_depart == null ? Duration.zero : DateTime.now().difference(_depart!));

  /// Rattache le chronomètre à la séance [sessionId] : celui d'une séance
  /// précédente, oublié en marche, est remis à zéro.
  void pourSeance(String? sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    if (_depart == null && _cumul == Duration.zero) return;
    _depart = null;
    _cumul = Duration.zero;
    _battre();
  }

  void _battre() {
    final voulu = enMarche && hasListeners;
    if (voulu && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
    } else if (!voulu && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _battre();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _battre();
  }

  void demarrer() {
    if (enMarche) return;
    _depart = DateTime.now();
    _battre();
    notifyListeners();
  }

  void arreter() {
    if (!enMarche) return;
    _cumul = ecoule;
    _depart = null;
    _battre();
    notifyListeners();
  }

  void remettreAZero() {
    _depart = null;
    _cumul = Duration.zero;
    _battre();
    notifyListeners();
  }
}
