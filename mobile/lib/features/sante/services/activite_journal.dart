import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/store.dart';
import '../../../core/env.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/json.dart';

/// Activité d'un jour, lue dans Health Connect.
class JourActivite {
  const JourActivite({required this.jour, this.pas, this.kcalActives, this.kcalTotales, this.fcRepos, this.fcMoyenne});

  final DateTime jour;
  final int? pas;
  final double? kcalActives;
  final double? kcalTotales;
  final double? fcRepos;
  final double? fcMoyenne;

  bool get vide => pas == null && kcalActives == null && kcalTotales == null && fcRepos == null && fcMoyenne == null;

  factory JourActivite.fromJson(Json j) => JourActivite(
        jour: Dates.jour(asDate(j['jour']) ?? DateTime.now()),
        pas: asInt(j['pas']),
        kcalActives: asDouble(j['kcalActives']),
        kcalTotales: asDouble(j['kcalTotales']),
        fcRepos: asDouble(j['fcRepos']),
        fcMoyenne: asDouble(j['fcMoyenne']),
      );

  Json toJson() => compact({
        'jour': dateOut(jour),
        'pas': pas,
        'kcalActives': kcalActives,
        'kcalTotales': kcalTotales,
        'fcRepos': fcRepos,
        'fcMoyenne': fcMoyenne,
      });
}

/// Journal d'activité et état de la connexion Health Connect, gardés dans
/// la collection « sante_activite » du Store (le noyau n'a pas de dépôt
/// pour l'activité).
class ActiviteJournal extends ChangeNotifier {
  ActiviteJournal._(this.store);

  static const collection = 'sante_activite';
  static final _instances = Expando<ActiviteJournal>();

  /// Un journal par Store (un en vrai, un en démo, un par test).
  static ActiviteJournal of(Store store) => _instances[store] ??= ActiviteJournal._(store)..charger();

  final Store store;
  final Map<DateTime, JourActivite> _jours = {};
  DateTime? derniereSynchro;
  String? derniereErreur;

  /// Nombre de refus de l'autorisation (Android ne redemande plus après deux).
  int refus = 0;

  /// Objectifs du module, réglables depuis les écrans Activité et Sommeil.
  int objectifPas = 10000;
  int objectifSommeilMin = 480;
  bool charge = false;
  bool _enCours = false;

  bool get synchroEnCours => _enCours;
  set synchroEnCours(bool v) {
    _enCours = v;
    notifyListeners();
  }

  Future<void> charger() async {
    final j = await store.readObject(collection);
    _jours.clear();
    if (j != null) {
      for (final e in (j['jours'] as List? ?? const [])) {
        if (e is Map) {
          final a = JourActivite.fromJson(Map<String, dynamic>.from(e));
          _jours[a.jour] = a;
        }
      }
      derniereSynchro = asDate(j['derniereSynchro']);
      derniereErreur = asString(j['derniereErreur']);
      refus = asInt(j['refus']) ?? 0;
      objectifPas = asInt(j['objectifPas']) ?? 10000;
      objectifSommeilMin = asInt(j['objectifSommeilMin']) ?? 480;
    }
    if (Env.demo && _jours.isEmpty) _demo();
    charge = true;
    notifyListeners();
  }

  Future<void> _ecrire() => store.write(collection, compact({
        'jours': [for (final a in jours) a.toJson()],
        'derniereSynchro': derniereSynchro == null ? null : dateOut(derniereSynchro!),
        'derniereErreur': derniereErreur,
        'refus': refus,
        'objectifPas': objectifPas,
        'objectifSommeilMin': objectifSommeilMin,
      }));

  Future<void> reglerObjectifs({int? pas, int? sommeilMin}) async {
    if (pas != null) objectifPas = pas;
    if (sommeilMin != null) objectifSommeilMin = sommeilMin;
    notifyListeners();
    await _ecrire();
  }

  Future<void> noterRefus({bool reset = false}) async {
    refus = reset ? 0 : refus + 1;
    notifyListeners();
    await _ecrire();
  }

  /// Variante démo : deux mois d'activité inventée, stable d'un lancement à l'autre.
  void _demo() {
    final r = math.Random(7);
    final today = Dates.jour(DateTime.now());
    for (var i = 0; i < 60; i++) {
      final d = today.subtract(Duration(days: i));
      final weekend = d.weekday >= 6;
      final pas = (weekend ? 5200 : 8600) + r.nextInt(5200) - (i == 0 ? 4000 : 0);
      final actives = pas * 0.042 + 180 + r.nextInt(160);
      _jours[d] = JourActivite(
        jour: d,
        pas: pas,
        kcalActives: actives.roundToDouble(),
        kcalTotales: (1780 + actives).roundToDouble(),
        fcRepos: (56 + r.nextInt(6) - i / 30).roundToDouble(),
        fcMoyenne: (72 + r.nextInt(9)).toDouble(),
      );
    }
    derniereSynchro = DateTime.now().subtract(const Duration(minutes: 12));
  }

  /// Jours connus, du plus récent au plus ancien.
  List<JourActivite> get jours => _jours.values.sorted((a, b) => b.jour.compareTo(a.jour));

  JourActivite? jour(DateTime d) => _jours[Dates.jour(d)];

  bool get vide => _jours.values.every((a) => a.vide);

  Future<void> enregistrer(List<JourActivite> liste, {DateTime? synchro}) async {
    for (final a in liste) {
      _jours[Dates.jour(a.jour)] = a;
    }
    derniereSynchro = synchro ?? DateTime.now();
    derniereErreur = null;
    notifyListeners();
    await _ecrire();
  }

  Future<void> erreur(String message) async {
    derniereErreur = message;
    notifyListeners();
    await _ecrire();
  }

  Future<void> effacer() async {
    _jours.clear();
    derniereSynchro = null;
    derniereErreur = null;
    notifyListeners();
    await store.delete(collection);
  }

  /// Moyenne d'une valeur sur les [n] derniers jours renseignés.
  double? moyenne(double? Function(JourActivite a) f, {int n = 7, DateTime? now}) {
    final from = Dates.jour(now ?? DateTime.now()).subtract(Duration(days: n - 1));
    final v = _jours.values.where((a) => !a.jour.isBefore(from)).map(f).whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }
}
