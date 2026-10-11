import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';
import 'activite_journal.dart';
import 'corps_hc.dart';

/// État de la liaison avec Health Connect.
enum EtatHc {
  indisponible('Indisponible sur cet appareil'),
  aInstaller('Health Connect n\'est pas installé'),
  aMettreAJour('Health Connect doit être mis à jour'),
  nonAutorise('Pas encore autorisé'),
  refuse('Accès refusé'),
  connecte('Connecté');

  const EtatHc(this.label);
  final String label;

  bool get pret => this == connecte;
}

/// Une famille de données lue dans Health Connect.
enum DonneeHc {
  sommeil('Sommeil', 'Durée, heures et phases des nuits', [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
  ]),
  poids('Poids et masse grasse', 'Pesées de votre balance connectée', [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ]),
  pas('Pas', 'Nombre de pas de chaque jour', [HealthDataType.STEPS]),
  calories('Calories brûlées', 'Dépense active et totale', [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ]),
  coeur('Fréquence cardiaque', 'Au repos et moyenne de la journée', [
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
  ]);

  const DonneeHc(this.label, this.detail, this.types);
  final String label;
  final String detail;
  final List<HealthDataType> types;
}

/// Bilan d'une synchronisation.
class BilanSynchro {
  BilanSynchro();
  int nuits = 0;
  int pesees = 0;
  int jours = 0;
  final List<String> manquantes = [];

  String get resume {
    final parts = <String>[
      if (nuits > 0) '$nuits ${nuits > 1 ? 'nuits' : 'nuit'}',
      if (pesees > 0) '$pesees ${pesees > 1 ? 'pesées' : 'pesée'}',
      if (jours > 0) '$jours ${jours > 1 ? 'jours' : 'jour'} d\'activité',
    ];
    return parts.isEmpty ? 'Rien de nouveau' : '${parts.join(', ')} à jour';
  }
}

/// Accès à Health Connect (paquet health). Tout passe par ici pour que les
/// écrans n'aient pas à connaître le paquet.
class HealthConnectService {
  HealthConnectService._();
  static final instance = HealthConnectService._();

  final Health _h = Health();
  bool _configure = false;

  static List<HealthDataType> get tousLesTypes => [for (final d in DonneeHc.values) ...d.types];

  bool get _android => !kIsWeb && Platform.isAndroid;

  Future<void> _init() async {
    if (_configure) return;
    await _h.configure();
    _configure = true;
  }

  /// État actuel, sans rien demander.
  Future<EtatHc> etat({int refus = 0}) async {
    if (!_android) return EtatHc.indisponible;
    try {
      await _init();
      final s = await _h.getHealthConnectSdkStatus();
      if (s == HealthConnectSdkStatus.sdkUnavailable || s == null) return EtatHc.aInstaller;
      if (s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) return EtatHc.aMettreAJour;
      final ok = await _h.hasPermissions(tousLesTypes, permissions: [for (final _ in tousLesTypes) HealthDataAccess.READ]);
      if (ok == true) return EtatHc.connecte;
      // Au moins une famille accordée : on considère la liaison faite.
      if ((await accordees()).isNotEmpty) return EtatHc.connecte;
      return refus > 0 ? EtatHc.refuse : EtatHc.nonAutorise;
    } catch (_) {
      return EtatHc.indisponible;
    }
  }

  /// Familles de données accordées.
  Future<Set<DonneeHc>> accordees() async {
    if (!_android) return {};
    await _init();
    final out = <DonneeHc>{};
    for (final d in DonneeHc.values) {
      try {
        final ok = await _h.hasPermissions(d.types, permissions: [for (final _ in d.types) HealthDataAccess.READ]);
        if (ok == true) out.add(d);
      } catch (_) {}
    }
    return out;
  }

  /// Ouvre la fenêtre d'autorisation de Health Connect.
  Future<bool> demanderAcces() async {
    if (!_android) return false;
    await _init();
    final ok = await _h.requestAuthorization(tousLesTypes, permissions: [for (final _ in tousLesTypes) HealthDataAccess.READ]);
    // L'historique au-delà de 30 jours est une autorisation à part.
    try {
      if (ok && await _h.isHealthDataHistoryAvailable() && !await _h.isHealthDataHistoryAuthorized()) {
        await _h.requestHealthDataHistoryAuthorization();
      }
    } catch (_) {}
    return ok || (await accordees()).isNotEmpty;
  }

  Future<void> installer() async {
    if (!_android) return;
    await _init();
    await _h.installHealthConnect();
  }

  Future<void> revoquer() async {
    if (!_android) return;
    try {
      await _init();
      await _h.revokePermissions();
    } catch (_) {}
  }

  /// Relit les [jours] derniers jours et range tout dans les dépôts.
  Future<BilanSynchro> synchroniser(HealthRepo repo, ActiviteJournal journal, {int jours = 30}) async {
    final bilan = BilanSynchro();
    if (!_android) throw const HcErreur('Health Connect n\'existe que sur Android.');
    await _init();
    final fin = DateTime.now();
    final debut = Dates.jour(fin).subtract(Duration(days: jours - 1));
    journal.synchroEnCours = true;
    try {
      final permis = await accordees();
      bilan.manquantes.addAll(DonneeHc.values.where((d) => !permis.contains(d)).map((d) => d.label));
      if (permis.contains(DonneeHc.sommeil)) bilan.nuits = await _sommeil(repo, debut, fin);
      if (permis.contains(DonneeHc.poids)) bilan.pesees = await _poids(repo, debut, fin);
      bilan.jours = await _activite(journal, permis, debut, fin);
      await journal.enregistrer(const []);
      return bilan;
    } catch (e) {
      await journal.erreur('La lecture a échoué. Réessayez dans un instant.');
      throw HcErreur('La lecture dans Health Connect a échoué ($e).');
    } finally {
      journal.synchroEnCours = false;
    }
  }

  /// [strict] : une lecture qui échoue remonte l'erreur au lieu de rendre
  /// une liste vide.
  Future<List<HealthDataPoint>> _lire(List<HealthDataType> types, DateTime debut, DateTime fin, {bool strict = false}) async {
    try {
      return await _h.getHealthDataFromTypes(types: types, startTime: debut, endTime: fin);
    } catch (_) {
      if (strict) rethrow;
      return const [];
    }
  }

  static double _num(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : 0;
  }

  Future<int> _sommeil(HealthRepo repo, DateTime debut, DateTime fin) async {
    // Une nuit commence la veille : on remonte d'un jour.
    final from = debut.subtract(const Duration(days: 1));
    final sessions = await _lire([HealthDataType.SLEEP_SESSION], from, fin);
    if (sessions.isEmpty) return 0;
    final phases = await _lire(
      [HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_REM, HealthDataType.SLEEP_AWAKE],
      from,
      fin,
    );
    int minutes(HealthDataType t, DateTime a, DateTime b) => phases
        .where((p) => p.type == t && p.dateFrom.isBefore(b) && p.dateTo.isAfter(a))
        .fold(0, (s, p) => s + p.dateTo.difference(p.dateFrom).inMinutes);

    final existantes = repo.sleep;
    final nuits = <SleepEntry>[];
    for (final s in sessions) {
      if (s.dateTo.difference(s.dateFrom).inMinutes < 60) continue;
      final id = 'hc-${s.uuid}';
      final jour = Dates.jour(s.dateTo);
      // Une nuit saisie à la main le même jour reste prioritaire.
      if (existantes.any((n) => n.jour == jour && n.source != 'health connect' && n.id != id)) continue;
      final ancienne = existantes.firstWhereOrNull((n) => n.id == id);
      final profond = minutes(HealthDataType.SLEEP_DEEP, s.dateFrom, s.dateTo);
      final leger = minutes(HealthDataType.SLEEP_LIGHT, s.dateFrom, s.dateTo);
      final rem = minutes(HealthDataType.SLEEP_REM, s.dateFrom, s.dateTo);
      final eveil = minutes(HealthDataType.SLEEP_AWAKE, s.dateFrom, s.dateTo);
      final avecPhases = profond + leger + rem > 0;
      nuits.add(SleepEntry(
        id: id,
        coucher: s.dateFrom.toLocal(),
        lever: s.dateTo.toLocal(),
        qualite: ancienne?.qualite,
        notes: ancienne?.notes,
        profondMin: avecPhases ? profond : null,
        legerMin: avecPhases ? leger : null,
        paradoxalMin: avecPhases ? rem : null,
        eveilMin: avecPhases ? eveil : null,
        source: 'health connect',
      ));
    }
    if (nuits.isNotEmpty) await repo.addSleepAll(nuits);
    return nuits.length;
  }

  static const _corps = [HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE];

  /// Types du corps (poids, masse grasse) dont la lecture est accordée.
  Future<List<HealthDataType>> _corpsAccordes() async {
    final out = <HealthDataType>[];
    for (final t in _corps) {
      try {
        if (await _h.hasPermissions([t], permissions: [HealthDataAccess.READ]) == true) out.add(t);
      } catch (_) {}
    }
    return out;
  }

  /// Où en est la lecture du poids et de la masse grasse, sans rien demander.
  Future<EtatHc> etatCorps() async {
    if (!_android) return EtatHc.indisponible;
    try {
      await _init();
      final s = await _h.getHealthConnectSdkStatus();
      if (s == HealthConnectSdkStatus.sdkUnavailable || s == null) return EtatHc.aInstaller;
      if (s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) return EtatHc.aMettreAJour;
      return (await _corpsAccordes()).isEmpty ? EtatHc.nonAutorise : EtatHc.connecte;
    } catch (_) {
      return EtatHc.indisponible;
    }
  }

  /// Demande ce qui manque pour lire le poids et la masse grasse, rien
  /// d'autre : la lecture des deux, puis l'historique au-delà de 30 jours
  /// (une autorisation à part).
  Future<bool> demanderCorps() async {
    if (!_android) return false;
    await _init();
    if ((await _corpsAccordes()).length < _corps.length) {
      try {
        await _h.requestAuthorization(_corps, permissions: [for (final _ in _corps) HealthDataAccess.READ]);
      } catch (_) {}
    }
    final ok = (await _corpsAccordes()).isNotEmpty;
    try {
      if (ok && await _h.isHealthDataHistoryAvailable() && !await _h.isHealthDataHistoryAuthorized()) {
        await _h.requestHealthDataHistoryAuthorization();
      }
    } catch (_) {}
    return ok;
  }

  bool _corpsEnCours = false;

  /// Relit le poids et la masse grasse des [jours] derniers jours (tout
  /// l'historique avec null) et met les saisies à jour, sans rien demander :
  /// sans autorisation, rien ne se passe. Rend le nombre de jours mis à jour.
  Future<int> importerCorps(HealthRepo repo, {int? jours = 30}) async {
    if (!_android || _corpsEnCours) return 0;
    _corpsEnCours = true;
    try {
      await _init();
      if ((await _corpsAccordes()).isEmpty) return 0;
      final fin = DateTime.now();
      return await _poids(repo, jours == null ? DateTime(2000) : Dates.jour(fin).subtract(Duration(days: jours - 1)), fin);
    } catch (_) {
      return 0;
    } finally {
      _corpsEnCours = false;
    }
  }

  /// Ce que Health Connect accorde pour le corps, sans rien demander.
  Future<AccesCorps> accesCorps() async {
    if (!_android) return const (poids: false, gras: false, historique: false);
    try {
      await _init();
      final types = await _corpsAccordes();
      var historique = false;
      try {
        historique = await _h.isHealthDataHistoryAuthorized();
      } catch (_) {}
      return (poids: types.contains(HealthDataType.WEIGHT), gras: types.contains(HealthDataType.BODY_FAT_PERCENTAGE), historique: historique);
    } catch (_) {
      return const (poids: false, gras: false, historique: false);
    }
  }

  /// Mois vides de suite après lesquels on arrête de remonter.
  static const _moisVidesMax = 18;

  /// Relit tout ce que Health Connect garde du poids et de la masse grasse,
  /// mois par mois en remontant, et range chaque mois au fur et à mesure.
  /// [surAvancee] reçoit le total après chaque mois. S'arrête après
  /// [_moisVidesMax] mois vides de suite.
  Future<BilanCorps> importerToutCorps(HealthRepo repo, {void Function(BilanCorps bilan, DateTime mois)? surAvancee}) async {
    var bilan = const BilanCorps();
    if (!_android || _corpsEnCours) return bilan;
    _corpsEnCours = true;
    try {
      await _init();
      final accordes = await _corpsAccordes();
      if (accordes.isEmpty) return bilan;
      final maintenant = DateTime.now();
      var vides = 0;
      for (var i = 0; vides < _moisVidesMax && i < 12 * 30; i++) {
        final debut = DateTime(maintenant.year, maintenant.month - i);
        final fin = i == 0 ? maintenant : DateTime(maintenant.year, maintenant.month - i + 1);
        final releves = await _relevesCorps(debut, fin, accordes: accordes, strict: true);
        vides = releves.isEmpty ? vides + 1 : 0;
        if (releves.isNotEmpty) bilan = bilan.avec(releves, await _ranger(repo, releves));
        surAvancee?.call(bilan, debut);
      }
      return bilan;
    } finally {
      _corpsEnCours = false;
    }
  }

  Future<List<ReleveHc>> _relevesCorps(DateTime debut, DateTime fin, {List<HealthDataType> accordes = _corps, bool strict = false}) async {
    // Un type à la fois : l'un peut être accordé sans l'autre.
    final points = [for (final t in accordes) ...await _lire([t], debut, fin, strict: strict)];
    return [
      for (final p in points)
        (
          date: p.dateFrom.toLocal(),
          poidsKg: p.type == HealthDataType.WEIGHT ? _num(p) : null,
          grasPct: p.type == HealthDataType.BODY_FAT_PERCENTAGE ? _num(p) : null,
        ),
    ];
  }

  /// Range les pesées lues dans un fichier, comme celles de Health Connect.
  Future<BilanCorps> rangerPesees(HealthRepo repo, List<ReleveHc> releves) async =>
      releves.isEmpty ? const BilanCorps() : const BilanCorps().avec(releves, await _ranger(repo, releves));

  Future<int> _poids(HealthRepo repo, DateTime debut, DateTime fin) async => _ranger(repo, await _relevesCorps(debut, fin));

  /// Range des relevés dans les saisies ; rend le nombre de jours modifiés.
  Future<int> _ranger(HealthRepo repo, List<ReleveHc> releves) async {
    final fusion = CorpsHc.fusionner(repo.measurements, releves);
    for (final id in fusion.aRetirer) {
      await repo.deleteMeasurement(id);
    }
    if (fusion.aEcrire.isNotEmpty) await repo.addMeasurementsAll(fusion.aEcrire);
    return fusion.aEcrire.length;
  }

  Future<int> _activite(ActiviteJournal journal, Set<DonneeHc> permis, DateTime debut, DateTime fin) async {
    final cal = permis.contains(DonneeHc.calories)
        ? await _lire([HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.TOTAL_CALORIES_BURNED], debut, fin)
        : const <HealthDataPoint>[];
    final coeur = permis.contains(DonneeHc.coeur)
        ? await _lire([HealthDataType.RESTING_HEART_RATE, HealthDataType.HEART_RATE], debut, fin)
        : const <HealthDataPoint>[];
    final liste = <JourActivite>[];
    for (var d = Dates.jour(debut); !d.isAfter(fin); d = DateTime(d.year, d.month, d.day + 1)) {
      final lendemain = DateTime(d.year, d.month, d.day + 1);
      final fenetre = lendemain.isAfter(fin) ? fin : lendemain;
      int? pas;
      if (permis.contains(DonneeHc.pas)) {
        try {
          pas = await _h.getTotalStepsInInterval(d, fenetre);
        } catch (_) {}
      }
      bool dansLeJour(HealthDataPoint p) => !p.dateFrom.toLocal().isBefore(d) && p.dateFrom.toLocal().isBefore(lendemain);
      double? somme(HealthDataType t) {
        final l = cal.where((p) => p.type == t && dansLeJour(p));
        return l.isEmpty ? null : l.fold<double>(0, (s, p) => s + _num(p));
      }

      final repos = coeur.where((p) => p.type == HealthDataType.RESTING_HEART_RATE && dansLeJour(p)).sortedBy((p) => p.dateFrom).lastOrNull;
      final fc = coeur.where((p) => p.type == HealthDataType.HEART_RATE && dansLeJour(p)).map(_num).toList();
      final a = JourActivite(
        jour: d,
        pas: pas,
        kcalActives: somme(HealthDataType.ACTIVE_ENERGY_BURNED),
        kcalTotales: somme(HealthDataType.TOTAL_CALORIES_BURNED),
        fcRepos: repos == null ? null : _num(repos),
        fcMoyenne: fc.isEmpty ? null : fc.reduce((a, b) => a + b) / fc.length,
      );
      if (!a.vide) liste.add(a);
    }
    if (liste.isNotEmpty) await journal.enregistrer(liste);
    return liste.length;
  }
}

class HcErreur implements Exception {
  const HcErreur(this.message);
  final String message;
  @override
  String toString() => message;
}
