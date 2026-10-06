import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';
import 'activite_journal.dart';

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

  Future<List<HealthDataPoint>> _lire(List<HealthDataType> types, DateTime debut, DateTime fin) async {
    try {
      return await _h.getHealthDataFromTypes(types: types, startTime: debut, endTime: fin);
    } catch (_) {
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

  Future<int> _poids(HealthRepo repo, DateTime debut, DateTime fin) async {
    final points = await _lire([HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE], debut, fin);
    final existantes = repo.measurements;
    final out = <BodyMeasurement>[];
    for (final p in points) {
      final v = _num(p);
      if (v <= 0) continue;
      final date = p.dateFrom.toLocal();
      final poids = p.type == HealthDataType.WEIGHT;
      final id = 'hc-${poids ? 'p' : 'mg'}-${p.uuid}';
      // Déjà saisie à la main ce jour-là avec la même valeur : on n'ajoute rien.
      final doublon = existantes.any((m) =>
          m.id != id &&
          m.source != 'health connect' &&
          Dates.memeJour(m.date, date) &&
          (poids ? (m.poidsKg != null && (m.poidsKg! - v).abs() < 0.15) : (m.masseGrassePct != null && (m.masseGrassePct! - v).abs() < 0.3)));
      if (doublon) continue;
      out.add(BodyMeasurement(
        id: id,
        date: date,
        poidsKg: poids ? v : null,
        // Certaines balances donnent une fraction (0,15) plutôt qu'un pourcentage.
        masseGrassePct: poids ? null : (v <= 1 ? v * 100 : v),
        source: 'health connect',
      ));
    }
    if (out.isNotEmpty) await repo.addMeasurementsAll(out);
    return out.where((m) => m.poidsKg != null).length;
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
