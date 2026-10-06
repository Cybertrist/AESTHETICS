// Rapport d'import : ce que l'utilisateur voit avant de valider.

import 'exercise_matcher.dart';
import 'import_models.dart';

/// Meilleures performances d'un exercice dans le fichier.
class RecordExercice {
  RecordExercice(this.cle, this.nom, this.exerciceId);

  /// Identifiant du catalogue, ou nom du fichier si non reconnu.
  final String cle;
  final String nom;
  final String? exerciceId;

  double chargeMax = 0;
  int repsALaChargeMax = 0;
  DateTime? dateChargeMax;

  /// 1RM estimé (Epley) sur les séries de 1 à 12 répétitions.
  double unRmEstime = 0;
  DateTime? dateUnRm;

  int repsMax = 0;
  double chargeAuxRepsMax = 0;

  /// Plus gros volume (charge x reps) cumulé en une séance.
  double volumeSeanceMax = 0;

  int seances = 0;
  int series = 0;
  DateTime? premiereFois;
  DateTime? derniereFois;
}

/// Estimation Epley, bornée aux séries de 1 à 12 répétitions.
double estimerUnRm(double charge, int reps) {
  if (charge <= 0 || reps <= 0 || reps > 12) return 0;
  if (reps == 1) return charge;
  return charge * (1 + reps / 30);
}

class ImportReport {
  ImportReport._();

  late final ImportFormat format;
  int lignesLues = 0;
  int seances = 0;
  int seancesDoublons = 0;

  /// Séries comptées (hors échauffement).
  int series = 0;
  int seriesEchauffement = 0;
  int exercicesDistincts = 0;
  DateTime? debut;
  DateTime? fin;
  double volumeTotalKg = 0;
  Duration dureeTotale = Duration.zero;

  /// Séances par mois, clé `aaaa-mm`, dans l'ordre chronologique.
  final Map<String, int> seancesParMois = {};

  /// Records par exercice, les plus pratiqués d'abord.
  final List<RecordExercice> records = [];

  final List<Rapprochement> reconnus = [];
  final List<Rapprochement> aConfirmer = [];
  final List<Rapprochement> nouveaux = [];
  final List<ImportMessage> messages = [];

  int get nomsReconnus => reconnus.length;
  bool get pret => aConfirmer.isEmpty && seances > 0;

  /// Calcule le rapport. Les séances marquées doublon ne comptent pas.
  factory ImportReport.calculer(
    ParseResult parse,
    Map<String, Rapprochement> rapprochements,
  ) {
    final r = ImportReport._()
      ..format = parse.format
      ..lignesLues = parse.lignesLues;
    r.messages.addAll(parse.messages);
    final parCle = <String, RecordExercice>{};

    for (final s in parse.seances) {
      if (s.doublon) {
        r.seancesDoublons++;
        continue;
      }
      r.seances++;
      r.debut = r.debut == null || s.debut.isBefore(r.debut!) ? s.debut : r.debut;
      r.fin = r.fin == null || s.debut.isAfter(r.fin!) ? s.debut : r.fin;
      r.dureeTotale += s.dureeRetenue;
      final mois = '${s.debut.year}-${s.debut.month.toString().padLeft(2, '0')}';
      r.seancesParMois[mois] = (r.seancesParMois[mois] ?? 0) + 1;

      final vusDansSeance = <String>{};
      final volumeSeance = <String, double>{};
      for (final e in s.exercices) {
        final rap = rapprochements[cleNom(e.nomSource)];
        final id = e.exerciceId;
        final cle = id ?? 'nom:${cleNom(e.nomSource)}';
        final rec = parCle.putIfAbsent(
          cle,
          () => RecordExercice(cle, rap?.choisi?.nom ?? e.nomSource, id),
        );
        if (vusDansSeance.add(cle)) {
          rec.seances++;
          rec.premiereFois ??= s.debut;
          rec.derniereFois = s.debut;
        }
        for (final set in e.series) {
          if (!set.type.compte) {
            r.seriesEchauffement++;
            continue;
          }
          r.series++;
          rec.series++;
          final charge = set.poidsKg ?? 0;
          final reps = set.reps ?? 0;
          r.volumeTotalKg += set.volume;
          volumeSeance[cle] = (volumeSeance[cle] ?? 0) + set.volume;
          if (charge > rec.chargeMax ||
              (charge == rec.chargeMax && charge > 0 && reps > rec.repsALaChargeMax)) {
            rec.chargeMax = charge;
            rec.repsALaChargeMax = reps;
            rec.dateChargeMax = s.debut;
          }
          final unRm = estimerUnRm(charge, reps);
          if (unRm > rec.unRmEstime) {
            rec.unRmEstime = unRm;
            rec.dateUnRm = s.debut;
          }
          if (reps > rec.repsMax || (reps == rec.repsMax && charge > rec.chargeAuxRepsMax)) {
            rec.repsMax = reps;
            rec.chargeAuxRepsMax = charge;
          }
        }
      }
      volumeSeance.forEach((cle, v) {
        final rec = parCle[cle]!;
        if (v > rec.volumeSeanceMax) rec.volumeSeanceMax = v;
      });
    }

    r.records.addAll(parCle.values.where((x) => x.series > 0));
    r.records.sort((a, b) => b.seances.compareTo(a.seances));
    r.exercicesDistincts = r.records.length;

    for (final rap in rapprochements.values) {
      switch (rap.statut) {
        case StatutRapprochement.exact:
        case StatutRapprochement.automatique:
        case StatutRapprochement.manuel:
          r.reconnus.add(rap);
        case StatutRapprochement.ambigu:
        case StatutRapprochement.inconnu:
          r.aConfirmer.add(rap);
        case StatutRapprochement.nouveau:
          r.nouveaux.add(rap);
      }
    }
    // Les plus fréquents d'abord : ce sont ceux qui comptent le plus.
    r.aConfirmer.sort((a, b) => b.series.compareTo(a.series));
    r.reconnus.sort((a, b) => b.series.compareTo(a.series));
    return r;
  }
}
