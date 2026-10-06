// Détection du format et parseurs. Chaque parseur transforme une CsvTable en
// séances intermédiaires (une ligne du fichier = une série).

import 'csv_table.dart';
import 'import_models.dart';
import 'value_parsers.dart';

/// Résultat de la détection.
class Detection {
  const Detection(this.format, this.confiance, {this.colonnes});
  final ImportFormat? format;

  /// 0 : pas un historique d'entraînement, 1 : certain.
  final double confiance;

  /// Colonnes devinées pour un tableau quelconque.
  final ColumnMapping? colonnes;

  bool get reconnu => format != null;
}

/// Reconnaît le format d'après les en-têtes.
Detection detecterFormat(CsvTable table) {
  bool a(String n) => table.contient(n);

  if (a('exercise_title') && (a('start_time') || a('title'))) {
    var c = 0.8;
    if (a('set_type')) c += 0.1;
    if (a('weight_kg') || a('weight_lbs')) c += 0.1;
    return Detection(ImportFormat.snakeCase, c.clamp(0, 1).toDouble());
  }
  if (a('exercise name') && a('set order')) {
    var c = 0.8;
    if (a('workout name')) c += 0.1;
    if (a('workout #') || a('seconds')) c += 0.1;
    return Detection(ImportFormat.ordreSeries, c.clamp(0, 1).toDouble());
  }
  if (a('exercise') && a('date') && (a('set type') || a('superset id'))) {
    var c = 0.6;
    if (a('superset id')) c += 0.15;
    if (a('set type')) c += 0.15;
    if (a('title') && a('duration')) c += 0.1;
    return Detection(ImportFormat.legacy, c.clamp(0, 1).toDouble());
  }
  final m = ColumnMapping.deviner(table.enTetes);
  if (m.estUtilisable) {
    final c = 0.4 + (m.poids != null ? 0.15 : 0) + (m.reps != null ? 0.15 : 0);
    return Detection(ImportFormat.generique, c, colonnes: m);
  }
  return const Detection(null, 0);
}

/// Lit une table avec le parseur du format donné.
ParseResult parserTable(
  CsvTable table,
  ImportFormat format, {
  ImportOptions options = const ImportOptions(),
  ColumnMapping? colonnes,
}) {
  switch (format) {
    case ImportFormat.legacy:
      return LegacyCsvFormat(options).parser(table);
    case ImportFormat.ordreSeries:
      return OrdreSeriesCsvFormat(options).parser(table);
    case ImportFormat.snakeCase:
      return SnakeCaseCsvFormat(options).parser(table);
    case ImportFormat.generique:
      return GenericCsvFormat(
        options,
        colonnes ?? ColumnMapping.deviner(table.enTetes),
      ).parser(table);
  }
}

// ---------------------------------------------------------------------------
// Assemblage commun

class _Assembleur {
  _Assembleur(this.options);
  final ImportOptions options;
  final _seances = <String, ImportedSession>{};
  final _clesVues = <String>{};
  final messages = <ImportMessage>[];
  int seriesVides = 0;

  void ajouter({
    required String cle,
    required String titre,
    required DateTime debut,
    Duration? duree,
    String? notesSeance,
    required String exercice,
    String? superset,
    String? notesExercice,
    required ImportedSet serie,
  }) {
    _clesVues.add(cle);
    if (options.ignorerSeriesVides && serie.vide) {
      seriesVides++;
      return;
    }
    final s = _seances.putIfAbsent(
      cle,
      () => ImportedSession(titre: titre.trim().isEmpty ? 'Séance' : titre.trim(), debut: debut),
    );
    s.duree ??= (duree != null && duree > Duration.zero) ? duree : null;
    if (s.notes == null && notesSeance != null && notesSeance.trim().isNotEmpty) {
      s.notes = notesSeance.trim();
    }
    final nom = exercice.trim();
    final cleNom = nom.toLowerCase();
    ImportedExercise? bloc;
    if (s.exercices.isNotEmpty && s.exercices.last.nomSource.toLowerCase() == cleNom) {
      bloc = s.exercices.last;
    } else if (superset != null && superset.isNotEmpty) {
      // Dans un superset, les lignes alternent : on rejoint le bloc existant.
      for (final e in s.exercices) {
        if (e.supersetGroupe == superset && e.nomSource.toLowerCase() == cleNom) {
          bloc = e;
          break;
        }
      }
    }
    if (bloc == null) {
      bloc = ImportedExercise(
        nomSource: nom,
        supersetGroupe: (superset == null || superset.isEmpty) ? null : superset,
      );
      s.exercices.add(bloc);
    }
    if (bloc.notes == null && notesExercice != null && notesExercice.trim().isNotEmpty) {
      bloc.notes = notesExercice.trim();
    }
    serie.index = bloc.series.length + 1;
    bloc.series.add(serie);
  }

  ParseResult resultat(ImportFormat format, int lignes) {
    final seances = _seances.values.where((s) => s.exercices.isNotEmpty).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    if (seriesVides > 0) {
      // Séances dont aucune série n'a de valeur : elles disparaissent avec elles.
      final perdues = _clesVues.length - _seances.length;
      final dont = perdues == 0
          ? ''
          : ', dont ${perdues > 1 ? '$perdues séances entières' : 'une séance entière'}';
      messages.add(ImportMessage(
        '$seriesVides série${seriesVides > 1 ? 's' : ''} sans charge, répétitions, durée ni distance '
        '${seriesVides > 1 ? 'ont été ignorées' : 'a été ignorée'}$dont.',
        gravite: Gravite.info,
      ));
    }
    var douteuses = 0;
    for (final s in seances) {
      if (s.dureeInvraisemblable) {
        s.duree = null;
        douteuses++;
      }
    }
    if (douteuses > 0) {
      messages.add(ImportMessage(
        '${douteuses > 1 ? '$douteuses séances ont' : 'Une séance a'} une durée invraisemblable '
        '(chronomètre oublié ou arrêté trop tôt) : elle est estimée à partir des séries.',
        gravite: Gravite.info,
      ));
    }
    if (seances.isEmpty) {
      messages.add(const ImportMessage('Aucune séance trouvée dans ce fichier.',
          gravite: Gravite.erreur));
    }
    return ParseResult(format: format, seances: seances, lignesLues: lignes, messages: messages);
  }
}

double? _enKg(double? v, UniteCharge u) =>
    v == null ? null : (u == UniteCharge.lb ? v * livreEnKg : v);

UniteCharge _uniteDepuisTexte(String? s, UniteCharge defaut) {
  if (s == null) return defaut;
  final t = s.toLowerCase();
  if (RegExp(r'\blbs?\b|pound|livre').hasMatch(t)) return UniteCharge.lb;
  if (RegExp(r'\bkgs?\b|kilo').hasMatch(t)) return UniteCharge.kg;
  return defaut;
}

/// Distance en mètres selon l'unité lue dans un en-tête ou une cellule.
double? _distanceM(double? v, String? unite, {String defaut = 'km'}) {
  if (v == null) return null;
  var u = (unite ?? '').toLowerCase().replaceAll('distance', '').trim();
  if (u.isEmpty) u = defaut;
  if (u.contains('mi')) return v * 1609.344;
  if (u.contains('km') || u.contains('kilom')) return v * 1000;
  if (u.contains('ft') || u.contains('feet')) return v * 0.3048;
  if (u.contains('yd') || u.contains('yard')) return v * 0.9144;
  if (RegExp(r'\bm\b|meter|metre|mètre').hasMatch(u)) return v;
  return v * 1000;
}

String? _enTete(CsvTable t, bool Function(String) test) {
  for (final e in t.enTetes) {
    if (test(CsvTable.normaliserEnTete(e))) return e;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Format A : ` Title,Date,Duration,Exercise,"Superset id",Weight,Reps,Distance,Time,"Set Type"`

class LegacyCsvFormat {
  LegacyCsvFormat(this.options);
  final ImportOptions options;

  ParseResult parser(CsvTable t) {
    final asm = _Assembleur(options);
    final colPoids = _enTete(t, (h) => h.startsWith('weight'));
    final unite = _uniteDepuisTexte(colPoids, options.uniteParDefaut);
    final colDist = _enTete(t, (h) => h.startsWith('distance'));
    final typesInconnus = <String>{};

    for (final r in t.lignes) {
      final dateTxt = r.get(['date', 'start date', 'workout date']);
      final exo = r.get(['exercise', 'exercise name']);
      if (exo == null) {
        asm.messages.add(ImportMessage('exercice manquant, ligne ignorée.', ligne: r.ligne));
        continue;
      }
      final debut = lireDate(dateTxt);
      if (debut == null) {
        asm.messages.add(ImportMessage('date illisible « ${dateTxt ?? ''} », ligne ignorée.',
            ligne: r.ligne));
        continue;
      }
      final brutType = r.get(['set type', 'type']);
      var type = lireTypeSerie(brutType);
      if (type == null) {
        typesInconnus.add(brutType!);
        type = SetKind.normale;
      }
      final titre = r.get(['title', 'workout', 'workout name']) ?? 'Séance';
      asm.ajouter(
        cle: '${dateTxt!}|$titre',
        titre: titre,
        debut: debut,
        duree: _duree(lireDureeSec(r.get(['duration', 'workout duration']))),
        notesSeance: r.get(['workout notes', 'description']),
        exercice: exo,
        superset: r.get(['superset id', 'superset']),
        notesExercice: r.get(['notes', 'exercise notes']),
        serie: ImportedSet(
          index: 0,
          type: type,
          poidsKg: _enKg(lireNombre(colPoids == null ? null : r.get([colPoids])), unite),
          reps: lireEntier(r.get(['reps', 'repetitions'])),
          dureeSec: lireDureeSec(r.get(['time', 'set time'])),
          distanceM: _distanceM(lireNombre(colDist == null ? null : r.get([colDist])), colDist),
          rpe: lireNombre(r.get(['rpe'])),
          rir: lireNombre(r.get(['rir'])),
          ligne: r.ligne,
        ),
      );
    }
    for (final ty in typesInconnus) {
      asm.messages.add(ImportMessage('type de série inconnu « $ty », lu comme série normale.'));
    }
    return asm.resultat(ImportFormat.legacy, t.lignes.length);
  }
}

// ---------------------------------------------------------------------------
// Format B : `Workout #;Date;Workout Name;Duration (sec);Exercise Name;Set Order;
// Weight (kg);Reps;RPE;Distance (meters);Seconds;Notes;Workout Notes`
// et sa variante ancienne (`Duration` en « 1h 5m », `Weight Unit`, `Distance Unit`).

class OrdreSeriesCsvFormat {
  OrdreSeriesCsvFormat(this.options);
  final ImportOptions options;

  ParseResult parser(CsvTable t) {
    final asm = _Assembleur(options);
    final colPoids = _enTete(t, (h) => h.startsWith('weight') && !h.contains('unit'));
    final uniteColonne = _uniteDepuisTexte(colPoids, options.uniteParDefaut);
    final colDist = _enTete(t, (h) => h.startsWith('distance') && !h.contains('unit'));
    final colDuree = _enTete(t, (h) => h.startsWith('duration'));
    final dureeEnSec = colDuree != null && colDuree.toLowerCase().contains('sec');
    var repos = 0;

    for (final r in t.lignes) {
      final ordre = r.get(['set order'])?.trim() ?? '';
      if (ordre.toLowerCase().contains('rest')) {
        repos++;
        continue;
      }
      final exo = r.get(['exercise name']);
      final dateTxt = r.get(['date']);
      if (exo == null) {
        asm.messages.add(ImportMessage('exercice manquant, ligne ignorée.', ligne: r.ligne));
        continue;
      }
      final debut = lireDate(dateTxt);
      if (debut == null) {
        asm.messages.add(ImportMessage('date illisible « ${dateTxt ?? ''} », ligne ignorée.',
            ligne: r.ligne));
        continue;
      }
      SetKind type;
      if (ordre.isEmpty || int.tryParse(ordre) != null) {
        type = SetKind.normale;
      } else {
        type = lireTypeSerie(ordre) ?? SetKind.normale;
      }
      final unite = _uniteDepuisTexte(r.get(['weight unit']), uniteColonne);
      final titre = r.get(['workout name']) ?? 'Séance';
      final numero = r.get(['workout #']);
      final dureeTxt = colDuree == null ? null : r.get([colDuree]);
      asm.ajouter(
        cle: numero != null ? '#$numero' : '${dateTxt!}|$titre',
        titre: titre,
        debut: debut,
        duree: _duree(dureeEnSec ? lireEntier(dureeTxt) : lireDureeSec(dureeTxt)),
        notesSeance: r.get(['workout notes']),
        exercice: exo,
        notesExercice: r.get(['notes']),
        serie: ImportedSet(
          index: 0,
          type: type,
          poidsKg: _enKg(lireNombre(colPoids == null ? null : r.get([colPoids])), unite),
          reps: lireEntier(r.get(['reps'])),
          dureeSec: lireEntier(r.get(['seconds'])),
          distanceM: _distanceM(
            lireNombre(colDist == null ? null : r.get([colDist])),
            r.get(['distance unit']) ?? colDist,
            defaut: 'm',
          ),
          rpe: lireNombre(r.get(['rpe'])),
          ligne: r.ligne,
        ),
      );
    }
    if (repos > 0) {
      asm.messages.add(ImportMessage(
          '$repos ligne${repos > 1 ? 's' : ''} de minuteur de repos ignorée${repos > 1 ? 's' : ''}.',
          gravite: Gravite.info));
    }
    return asm.resultat(ImportFormat.ordreSeries, t.lignes.length);
  }
}

// ---------------------------------------------------------------------------
// Format C : `title,start_time,end_time,description,exercise_title,superset_id,
// exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe`

class SnakeCaseCsvFormat {
  SnakeCaseCsvFormat(this.options);
  final ImportOptions options;

  ParseResult parser(CsvTable t) {
    final asm = _Assembleur(options);
    final enLivres = t.contient('weight_lbs') && !t.contient('weight_kg');
    final distMiles = t.contient('distance_miles') && !t.contient('distance_km');

    for (final r in t.lignes) {
      final exo = r.get(['exercise_title']);
      final debutTxt = r.get(['start_time']);
      if (exo == null) {
        asm.messages.add(ImportMessage('exercice manquant, ligne ignorée.', ligne: r.ligne));
        continue;
      }
      final debut = lireDate(debutTxt);
      if (debut == null) {
        asm.messages.add(ImportMessage('date illisible « ${debutTxt ?? ''} », ligne ignorée.',
            ligne: r.ligne));
        continue;
      }
      final fin = lireDate(r.get(['end_time']));
      final titre = r.get(['title']) ?? 'Séance';
      final poids = enLivres
          ? _enKg(lireNombre(r.get(['weight_lbs'])), UniteCharge.lb)
          : lireNombre(r.get(['weight_kg']));
      final dist = distMiles
          ? _distanceM(lireNombre(r.get(['distance_miles'])), 'mi')
          : _distanceM(lireNombre(r.get(['distance_km'])), 'km');
      final dureeSerie = lireEntier(r.get(['duration_seconds']));
      asm.ajouter(
        cle: '${debutTxt!}|$titre',
        titre: titre,
        debut: debut,
        duree: fin?.difference(debut),
        notesSeance: r.get(['description']),
        exercice: exo,
        superset: r.get(['superset_id']),
        notesExercice: r.get(['exercise_notes']),
        serie: ImportedSet(
          index: 0,
          type: lireTypeSerie(r.get(['set_type'])) ?? SetKind.normale,
          poidsKg: poids,
          reps: lireEntier(r.get(['reps'])),
          dureeSec: dureeSerie == 0 ? null : dureeSerie,
          distanceM: dist == 0 ? null : dist,
          rpe: lireNombre(r.get(['rpe'])),
          ligne: r.ligne,
        ),
      );
    }
    return asm.resultat(ImportFormat.snakeCase, t.lignes.length);
  }
}

// ---------------------------------------------------------------------------
// Tableau quelconque

/// Champs qu'on peut associer à une colonne.
enum ChampImport {
  date('Date', true),
  seance('Nom de la séance', false),
  exercice('Exercice', true),
  poids('Charge', false),
  unite('Unité de charge', false),
  reps('Répétitions', false),
  typeSerie('Type de série', false),
  dureeSeance('Durée de la séance', false),
  dureeSerie('Durée de la série', false),
  distance('Distance', false),
  rpe('RPE', false),
  rir('RIR', false),
  notes('Notes', false),
  notesSeance('Notes de séance', false);

  const ChampImport(this.libelle, this.obligatoire);
  final String libelle;
  final bool obligatoire;
}

/// Association champ vers index de colonne, devinée ou choisie à la main.
class ColumnMapping {
  ColumnMapping([Map<ChampImport, int>? m]) : colonnes = m ?? {};

  final Map<ChampImport, int> colonnes;

  /// Unité imposée pour la colonne de charge (sinon lue dans l'en-tête).
  UniteCharge? uniteCharge;

  /// Dates à mois d'abord (`07/13/2026`). Null : déterminé sur les données.
  bool? moisDabord;

  int? get poids => colonnes[ChampImport.poids];
  int? get reps => colonnes[ChampImport.reps];

  bool get estUtilisable =>
      colonnes.containsKey(ChampImport.date) &&
      colonnes.containsKey(ChampImport.exercice) &&
      (colonnes.containsKey(ChampImport.poids) ||
          colonnes.containsKey(ChampImport.reps) ||
          colonnes.containsKey(ChampImport.dureeSerie) ||
          colonnes.containsKey(ChampImport.distance));

  /// Champs obligatoires sans colonne.
  List<ChampImport> get manquants =>
      [for (final c in ChampImport.values) if (c.obligatoire && !colonnes.containsKey(c)) c];

  static const _synonymes = <ChampImport, List<String>>{
    ChampImport.date: [
      'date', 'jour', 'date de la seance', 'start_time', 'start time', 'start date',
      'started at', 'datetime', 'timestamp', 'workout date', 'debut', 'horodatage',
    ],
    ChampImport.seance: [
      'seance', 'nom de la seance', 'titre', 'title', 'workout', 'workout name',
      'workout title', 'session', 'routine', 'programme', 'entrainement',
    ],
    ChampImport.exercice: [
      'exercice', 'exercise', 'exercise name', 'exercise_title', 'exercise title',
      'nom de l exercice', 'mouvement', 'movement', 'lift', 'name', 'nom',
    ],
    ChampImport.poids: [
      'poids', 'charge', 'weight', 'load', 'kg', 'lbs', 'lb', 'weight kg', 'weight_kg',
      'weight (kg)', 'weight (lbs)', 'weight_lbs', 'poids (kg)', 'charge (kg)', 'masse',
    ],
    ChampImport.unite: ['unite', 'unit', 'weight unit', 'unite de poids', 'unite de charge'],
    ChampImport.reps: [
      'reps', 'rep', 'repetitions', 'repetition', 'reps count', 'nb reps', 'nombre de repetitions',
    ],
    ChampImport.typeSerie: [
      'set type', 'set_type', 'type', 'type de serie', 'set order', 'serie', 'set',
      'set number', 'set_index',
    ],
    ChampImport.dureeSeance: [
      'duration', 'duree', 'duree de la seance', 'workout duration', 'duration (sec)',
    ],
    ChampImport.dureeSerie: [
      'seconds', 'time', 'duree de la serie', 'duration_seconds', 'secondes', 'temps', 'set time',
    ],
    ChampImport.distance: ['distance', 'distance (m)', 'distance (km)', 'distance_km', 'km'],
    ChampImport.rpe: ['rpe', 'effort', 'difficulte'],
    ChampImport.rir: ['rir', 'reps in reserve', 'reps en reserve'],
    ChampImport.notes: ['notes', 'note', 'exercise notes', 'exercise_notes', 'commentaire', 'remarque'],
    ChampImport.notesSeance: [
      'workout notes', 'notes de seance', 'description', 'session notes', 'commentaire de seance',
    ],
  };

  /// Devine les colonnes d'après les en-têtes (FR ou EN).
  factory ColumnMapping.deviner(List<String> enTetes) {
    final m = ColumnMapping();
    final norm = [for (final e in enTetes) CsvTable.normaliserEnTete(e)];
    final pris = <int>{};
    // Correspondances exactes d'abord, puis préfixes.
    for (final passe in [0, 1]) {
      for (final champ in ChampImport.values) {
        if (m.colonnes.containsKey(champ)) continue;
        for (final syn in _synonymes[champ]!) {
          final i = _chercher(norm, syn, pris, passe == 1);
          if (i != null) {
            m.colonnes[champ] = i;
            pris.add(i);
            break;
          }
        }
      }
    }
    return m;
  }

  static int? _chercher(List<String> norm, String syn, Set<int> pris, bool prefixe) {
    for (var i = 0; i < norm.length; i++) {
      if (pris.contains(i)) continue;
      final h = norm[i];
      if (h == syn) return i;
      if (prefixe && syn.length >= 4 && (h.startsWith('$syn ') || h.startsWith('$syn('))) {
        return i;
      }
    }
    return null;
  }
}

class GenericCsvFormat {
  GenericCsvFormat(this.options, this.mapping);
  final ImportOptions options;
  final ColumnMapping mapping;

  ParseResult parser(CsvTable t) {
    final asm = _Assembleur(options);
    int? c(ChampImport ch) => mapping.colonnes[ch];
    if (!mapping.estUtilisable) {
      asm.messages.add(ImportMessage(
        'Colonnes à associer : ${[for (final m in mapping.manquants) m.libelle].join(', ')}'
        '${mapping.manquants.isEmpty ? 'une charge, des répétitions, une durée ou une distance' : ''}.',
        gravite: Gravite.erreur,
      ));
      return ParseResult(
          format: ImportFormat.generique, seances: const [], lignesLues: t.lignes.length,
          messages: asm.messages);
    }
    final enTetePoids = c(ChampImport.poids) == null ? null : t.enTetes[c(ChampImport.poids)!];
    final uniteColonne = mapping.uniteCharge ?? _uniteDepuisTexte(enTetePoids, options.uniteParDefaut);
    final enTeteDist = c(ChampImport.distance) == null ? null : t.enTetes[c(ChampImport.distance)!];
    final moisDabord = mapping.moisDabord ??
        detecterMoisDabord([for (final r in t.lignes) r.at(c(ChampImport.date))]);

    for (final r in t.lignes) {
      final exo = r.at(c(ChampImport.exercice));
      final dateTxt = r.at(c(ChampImport.date));
      if (exo == null) {
        asm.messages.add(ImportMessage('exercice manquant, ligne ignorée.', ligne: r.ligne));
        continue;
      }
      final debut = lireDate(dateTxt, moisDabord: moisDabord);
      if (debut == null) {
        asm.messages.add(ImportMessage('date illisible « ${dateTxt ?? ''} », ligne ignorée.',
            ligne: r.ligne));
        continue;
      }
      final brutType = r.at(c(ChampImport.typeSerie));
      final type = (brutType == null || int.tryParse(brutType) != null)
          ? SetKind.normale
          : (lireTypeSerie(brutType) ?? SetKind.normale);
      final unite = _uniteDepuisTexte(r.at(c(ChampImport.unite)), uniteColonne);
      final titre = r.at(c(ChampImport.seance)) ?? 'Séance';
      asm.ajouter(
        cle: '$dateTxt|$titre',
        titre: titre,
        debut: debut,
        duree: _duree(lireDureeSec(r.at(c(ChampImport.dureeSeance)))),
        notesSeance: r.at(c(ChampImport.notesSeance)),
        exercice: exo,
        notesExercice: r.at(c(ChampImport.notes)),
        serie: ImportedSet(
          index: 0,
          type: type,
          poidsKg: _enKg(lireNombre(r.at(c(ChampImport.poids))), unite),
          reps: lireEntier(r.at(c(ChampImport.reps))),
          dureeSec: lireDureeSec(r.at(c(ChampImport.dureeSerie))),
          distanceM: _distanceM(lireNombre(r.at(c(ChampImport.distance))), enTeteDist, defaut: 'm'),
          rpe: lireNombre(r.at(c(ChampImport.rpe))),
          rir: lireNombre(r.at(c(ChampImport.rir))),
          ligne: r.ligne,
        ),
      );
    }
    return asm.resultat(ImportFormat.generique, t.lignes.length);
  }
}

/// Vrai si les dates `aa/bb/cccc` du fichier sont à mois d'abord.
bool detecterMoisDabord(Iterable<String?> valeurs) {
  final re = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-]\d{2,4}');
  for (final v in valeurs) {
    if (v == null) continue;
    final m = re.firstMatch(v.trim());
    if (m == null) continue;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    if (a > 12) return false;
    if (b > 12) return true;
  }
  return false;
}

Duration? _duree(int? sec) => sec == null || sec <= 0 ? null : Duration(seconds: sec);
