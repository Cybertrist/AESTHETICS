import 'dart:convert';

import '../../../core/models/models.dart';

/// Séparateur des fichiers CSV exportés.
enum SeparateurCsv {
  virgule('Virgule', ',', 'Pour la plupart des applis et Google Sheets'),
  pointVirgule('Point-virgule', ';', 'Pour Excel en français');

  const SeparateurCsv(this.label, this.caractere, this.description);
  final String label;
  final String caractere;
  final String description;
}

/// Jeux de données exportables.
enum JeuExport {
  seances('Séances', 'Une ligne par série, relisible par l\'import'),
  exercicesPerso('Exercices personnels', 'Nom, matériel et muscles'),
  mesures('Mesures corporelles', 'Poids, masse grasse et tours'),
  sommeil('Sommeil', 'Coucher, lever et phases'),
  nutrition('Journal alimentaire', 'Aliments, quantités et macros'),
  eau('Hydratation', 'Verres et bouteilles notés');

  const JeuExport(this.label, this.description);
  final String label;
  final String description;
}

/// Écriture CSV (RFC 4180) : guillemets seulement quand il le faut.
class CsvEcrivain {
  CsvEcrivain(this.sep);
  final SeparateurCsv sep;
  final _b = StringBuffer();

  /// Nombre décimal selon le séparateur (virgule décimale avec « ; »).
  String nombre(num? v, {int decimales = 2}) {
    if (v == null) return '';
    var t = v is int || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(decimales);
    if (t.contains('.')) t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return sep == SeparateurCsv.pointVirgule ? t.replaceAll('.', ',') : t;
  }

  void ligne(List<Object?> champs) {
    _b.writeln(champs.map(_champ).join(sep.caractere));
  }

  String _champ(Object? v) {
    if (v == null) return '';
    final s = v is num ? nombre(v) : '$v';
    if (s.contains(sep.caractere) || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Texte final, avec l'indicateur UTF-8 pour qu'Excel lise les accents.
  List<int> octets() => [0xEF, 0xBB, 0xBF, ...utf8.encode(_b.toString())];

  @override
  String toString() => _b.toString();
}

String _date(DateTime d) =>
    '${d.year}-${_deux(d.month)}-${_deux(d.day)} ${_deux(d.hour)}:${_deux(d.minute)}';
String _jour(DateTime d) => '${d.year}-${_deux(d.month)}-${_deux(d.day)}';
String _deux(int v) => v.toString().padLeft(2, '0');
String _chrono(Duration d) => '${d.inHours}:${_deux(d.inMinutes % 60)}:${_deux(d.inSeconds % 60)}';

String _type(SetType t) => switch (t) {
      SetType.echauffement => 'Échauffement',
      SetType.normale => 'Normale',
      SetType.degressive => 'Dégressive',
      SetType.echec => 'Échec',
      _ => t.label,
    };

abstract final class Exporteurs {
  /// En-têtes des séances : reconnus tels quels par l'import de tableau.
  static const enTetesSeances = [
    'Date', 'Séance', 'Durée de la séance', 'Exercice', 'Série', 'Type de série',
    'Charge (kg)', 'Répétitions', 'Durée de la série', 'Distance (m)', 'RPE', 'Notes', 'Notes de séance',
  ];

  /// Séances en CSV, une ligne par série, de la plus ancienne à la plus récente.
  static List<int> seancesCsv(List<WorkoutSession> seances, String Function(String id) nomDe, SeparateurCsv sep,
      {UnitePoids unite = UnitePoids.kg}) {
    final w = CsvEcrivain(sep);
    final entetes = [...enTetesSeances];
    if (unite == UnitePoids.lb) entetes[6] = 'Charge (lb)';
    w.ligne(entetes);
    final triees = [...seances]..sort((a, b) => a.debut.compareTo(b.debut));
    for (final s in triees) {
      for (final e in s.exercices) {
        var n = 0;
        for (final set in e.series) {
          if (!set.fait) continue;
          n++;
          final poids = set.poids == null ? null : (unite == UnitePoids.lb ? set.poids! / 0.45359237 : set.poids);
          w.ligne([
            _date(s.debut),
            s.nom,
            s.fin == null ? null : _chrono(s.duree),
            nomDe(e.exerciseId),
            n,
            _type(set.type),
            poids == null ? null : double.parse(poids.toStringAsFixed(2)),
            set.reps,
            set.dureeSec,
            set.distanceM,
            set.rpe,
            n == 1 ? e.notes : null,
            s.notes,
          ]);
        }
      }
    }
    return w.octets();
  }

  /// Séances en JSON, avec le nom de chaque exercice à côté de son identifiant.
  static List<int> seancesJson(List<WorkoutSession> seances, String Function(String id) nomDe,
      {List<Exercise> exercicesPerso = const []}) {
    final triees = [...seances]..sort((a, b) => a.debut.compareTo(b.debut));
    final data = {
      'application': 'aesthetic',
      'type': 'seances',
      'version': 1,
      'date': DateTime.now().toIso8601String(),
      'unite': 'kg',
      'seances': [
        for (final s in triees)
          {
            ...s.toJson(),
            'exercices': [
              for (final e in s.exercices) {'nom': nomDe(e.exerciseId), ...e.toJson()},
            ],
          },
      ],
      if (exercicesPerso.isNotEmpty) 'exercicesPerso': [for (final e in exercicesPerso) e.toJson()],
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  }

  static List<int> exercicesPersoCsv(List<Exercise> list, SeparateurCsv sep) {
    final w = CsvEcrivain(sep)
      ..ligne(['Nom', 'Matériel', 'Muscles principaux', 'Muscles secondaires', 'Suivi', 'Créé le', 'Notes']);
    for (final e in list) {
      w.ligne([
        e.nom,
        e.equipementLabel,
        e.musclesPrincipaux.map((m) => m.label).join(', '),
        e.musclesSecondaires.map((m) => m.label).join(', '),
        e.suivi.label,
        e.creeLe == null ? null : _jour(e.creeLe!),
        e.notes,
      ]);
    }
    return w.octets();
  }

  static List<int> mesuresCsv(List<BodyMeasurement> list, SeparateurCsv sep) {
    final tours = TourCorps.values;
    final w = CsvEcrivain(sep)
      ..ligne(['Date', 'Poids (kg)', 'Masse grasse (%)', 'Masse musculaire (kg)', for (final t in tours) '${t.label} (cm)']);
    final triees = [...list]..sort((a, b) => a.date.compareTo(b.date));
    for (final m in triees) {
      w.ligne([_date(m.date), m.poidsKg, m.masseGrassePct, m.masseMusculaireKg, for (final t in tours) m.tours[t]]);
    }
    return w.octets();
  }

  static List<int> sommeilCsv(List<SleepEntry> list, SeparateurCsv sep) {
    final w = CsvEcrivain(sep)
      ..ligne(['Coucher', 'Lever', 'Durée (min)', 'Qualité', 'Profond (min)', 'Léger (min)', 'Paradoxal (min)', 'Éveil (min)', 'Notes']);
    final triees = [...list]..sort((a, b) => a.coucher.compareTo(b.coucher));
    for (final s in triees) {
      w.ligne([
        _date(s.coucher),
        _date(s.lever),
        s.lever.difference(s.coucher).inMinutes,
        s.qualite,
        s.profondMin,
        s.legerMin,
        s.paradoxalMin,
        s.eveilMin,
        s.notes,
      ]);
    }
    return w.octets();
  }

  static List<int> nutritionCsv(List<FoodEntry> list, SeparateurCsv sep) {
    final w = CsvEcrivain(sep)
      ..ligne(['Date', 'Repas', 'Aliment', 'Quantité (g)', 'Calories (kcal)', 'Protéines (g)', 'Glucides (g)', 'Lipides (g)', 'Fibres (g)', 'Sucres (g)', 'Sel (g)']);
    final triees = [...list]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in triees) {
      final m = e.macros;
      w.ligne([_date(e.date), e.repas.label, e.nom, e.quantiteG, m.kcal, m.proteines, m.glucides, m.lipides, m.fibres, m.sucres, m.sel]);
    }
    return w.octets();
  }

  static List<int> eauCsv(List<WaterLog> list, SeparateurCsv sep) {
    final w = CsvEcrivain(sep)..ligne(['Date', 'Quantité (ml)']);
    final triees = [...list]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in triees) {
      w.ligne([_date(e.date), e.ml]);
    }
    return w.octets();
  }

  /// Nom de fichier daté : `aesthetic-seances-2026-09-30.csv`.
  static String nomFichier(String base, String extension, [DateTime? d]) =>
      'aesthetic-$base-${_jour(d ?? DateTime.now())}.$extension';
}
