import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'coach_snapshot.dart';

/// Chiffres d'une semaine, pour le bilan du dimanche.
class WeekReport {
  WeekReport._({
    required this.debut,
    required this.sessions,
    required this.precedentes,
    required this.records,
    required this.seriesParMuscle,
    required this.nutrition,
    required this.joursNutrition,
    required this.sommeil,
    required this.nuits,
    required this.poidsDebut,
    required this.poidsFin,
    required this.objectifSeances,
    required this.objectifProteines,
    required this.objectifKcal,
    required this.unite,
  });

  final DateTime debut;
  DateTime get fin => debut.add(const Duration(days: 6));
  final List<WorkoutSession> sessions;
  final List<WorkoutSession> precedentes;
  final List<PersonalRecord> records;
  final Map<Muscle, double> seriesParMuscle;
  final Macros? nutrition;
  final int joursNutrition;
  final Duration? sommeil;
  final int nuits;
  final double? poidsDebut;
  final double? poidsFin;
  final int objectifSeances;
  final double objectifProteines;
  final double objectifKcal;
  final UnitePoids unite;

  /// Clé de cache (lundi de la semaine).
  String get cle => cleSemaine(debut);

  static String cleSemaine(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double get volume => sessions.fold(0.0, (a, s) => a + s.volume);
  double get volumePrecedent => precedentes.fold(0.0, (a, s) => a + s.volume);
  int get series => sessions.fold(0, (a, s) => a + s.nbSeriesFaites);
  Duration get duree => sessions.fold(Duration.zero, (a, s) => a + s.duree);
  bool get vide => sessions.isEmpty && joursNutrition == 0 && nuits == 0;
  double? get variationPoids => poidsDebut == null || poidsFin == null ? null : poidsFin! - poidsDebut!;

  /// Variation du volume par rapport à la semaine précédente (0,1 = plus 10 %).
  double? get variationVolume => volumePrecedent <= 0 ? null : (volume - volumePrecedent) / volumePrecedent;

  bool enCours(DateTime now) => !Dates.jour(now).isAfter(fin);

  static WeekReport build(CoachSnapshot s, DateTime jourDansLaSemaine) {
    final debut = Dates.debutSemaine(jourDansLaSemaine, premierJour: s.premierJour);
    final finExcl = debut.add(const Duration(days: 7));
    bool dans(DateTime d) => !d.isBefore(debut) && d.isBefore(finExcl);
    final sessions = s.sessions.where((x) => dans(x.debut)).toList();
    final precDebut = debut.subtract(const Duration(days: 7));
    final precedentes = s.sessions.where((x) => !x.debut.isBefore(precDebut) && x.debut.isBefore(debut)).toList();

    // Records battus : chaque séance comparée à tout ce qui la précède.
    final chrono = s.sessions.reversed.toList();
    final records = <PersonalRecord>[];
    for (var i = 0; i < chrono.length; i++) {
      if (!dans(chrono[i].debut)) continue;
      records.addAll(Strength.newRecords(chrono[i], chrono.sublist(0, i)));
    }

    final jours = [for (var i = 0; i < 7; i++) debut.add(Duration(days: i))]
        .where((d) => !d.isAfter(s.today))
        .map(s.nutritionDu)
        .where((j) => j.renseigne)
        .toList();
    Macros? moy;
    if (jours.isNotEmpty) {
      final t = jours.fold(Macros.zero, (a, j) => a + j.macros);
      moy = t.scale(1 / jours.length);
    }

    final nuits = s.health.sleep.where((n) => dans(n.lever)).toList();
    final sommeil = nuits.isEmpty
        ? null
        : Duration(minutes: (nuits.fold(0, (a, n) => a + n.duree.inMinutes) / nuits.length).round());

    final pesees = s.health.weightSeries(since: debut).where((p) => p.date.isBefore(finExcl)).toList();

    return WeekReport._(
      debut: debut,
      sessions: sessions,
      precedentes: precedentes,
      records: records,
      seriesParMuscle: Strength.setsParMuscle(sessions, s.lookup),
      nutrition: moy,
      joursNutrition: jours.length,
      sommeil: sommeil,
      nuits: nuits.length,
      poidsDebut: pesees.isEmpty ? null : pesees.first.kg,
      poidsFin: pesees.length < 2 ? null : pesees.last.kg,
      objectifSeances: s.objectifSemaine,
      objectifProteines: s.objectifs.proteinesG,
      objectifKcal: s.objectifs.kcal,
      unite: s.unite,
    );
  }

  /// Résumé chiffré, envoyé au coach pour rédiger le bilan.
  String donnees(ExerciseName nom) {
    final b = StringBuffer();
    b.writeln('Semaine du ${Fmt.date(debut)} au ${Fmt.date(fin)}.');
    b.writeln('Séances : ${sessions.length} sur $objectifSeances prévues, durée totale ${Fmt.duree(duree)}, '
        '$series séries, volume ${Fmt.volume(volume, unite)}'
        '${variationVolume == null ? '' : ' (${variationVolume! >= 0 ? 'plus' : 'moins'} ${Fmt.n(variationVolume!.abs() * 100, decimals: 0)} % par rapport à la semaine précédente)'}.');
    for (final x in sessions.reversed) {
      b.writeln('- ${Fmt.jourCap(x.debut)} : ${x.nom}, ${Fmt.duree(x.duree)}, ${x.nbSeriesFaites} séries.');
    }
    if (records.isNotEmpty) {
      b.writeln('Records battus :');
      for (final r in records.take(10)) {
        b.writeln('- ${nom(r.exerciseId)} : ${r.type.label} ${_valeurRecord(r)}');
      }
    }
    final muscles = seriesParMuscle.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
    if (muscles.isNotEmpty) {
      b.writeln('Séries par muscle : ${muscles.map((e) => '${e.key.label} ${Fmt.n(e.value, decimals: 1)}').join(', ')}.');
    }
    if (nutrition != null) {
      b.writeln('Nutrition (moyenne sur $joursNutrition jours renseignés) : ${Fmt.kcal(nutrition!.kcal)} pour ${Fmt.kcal(objectifKcal)} visées, '
          '${Fmt.n(nutrition!.proteines, decimals: 0)} g de protéines pour ${Fmt.n(objectifProteines, decimals: 0)} g visés.');
    } else {
      b.writeln('Nutrition : aucun repas enregistré.');
    }
    b.writeln(sommeil == null ? 'Sommeil : aucune nuit enregistrée.' : 'Sommeil : ${Fmt.sommeil(sommeil!)} en moyenne sur $nuits nuits.');
    if (variationPoids != null) {
      b.writeln('Poids : ${Fmt.poids(poidsDebut, unite)} puis ${Fmt.poids(poidsFin, unite)}.');
    }
    return b.toString();
  }

  String _valeurRecord(PersonalRecord r) => switch (r.type) {
        RecordType.repsMax => Fmt.pluriel(r.valeur, 'répétition'),
        RecordType.volumeSerie || RecordType.volumeSeance => Fmt.volume(r.valeur, unite),
        _ => Fmt.poids(r.valeur, unite),
      };

  String valeurRecord(PersonalRecord r) => _valeurRecord(r);

  /// Bilan rédigé sur le téléphone, sans service en ligne.
  String texteHorsLigne() {
    if (vide) return 'Rien d\'enregistré cette semaine. Une séance, un repas ou une nuit suffisent pour que je puisse faire le point.';
    final b = StringBuffer();
    final n = sessions.length;
    if (n == 0) {
      b.writeln('Pas de séance cette semaine. Le repos a du bon, mais ne laisse pas la pause s\'installer : une séance courte en début de semaine prochaine relancera la machine.');
    } else if (n >= objectifSeances) {
      b.writeln('**Objectif tenu** : ${Fmt.pluriel(n, 'séance')} pour $objectifSeances prévues. ');
    } else {
      b.writeln('**${Fmt.pluriel(n, 'séance')}** sur $objectifSeances prévues. La semaine prochaine, bloque tes créneaux à l\'avance.');
    }
    if (n > 0 && variationVolume != null) {
      final v = variationVolume!;
      b.writeln();
      b.writeln(v >= 0.05
          ? 'Volume en hausse de ${Fmt.n(v * 100, decimals: 0)} % : tu en fais plus, veille à bien récupérer.'
          : v <= -0.05
              ? 'Volume en baisse de ${Fmt.n(v.abs() * 100, decimals: 0)} % par rapport à la semaine précédente.'
              : 'Volume stable par rapport à la semaine précédente.');
    }
    if (records.isNotEmpty) {
      b.writeln();
      b.writeln('**${Fmt.pluriel(records.length, 'record')}** battu${records.length > 1 ? 's' : ''} : la progression est là.');
    }
    if (nutrition != null) {
      final ratio = nutrition!.proteines / objectifProteines;
      b.writeln();
      b.writeln(ratio >= 0.9
          ? 'Protéines bien tenues (${Fmt.n(nutrition!.proteines, decimals: 0)} g par jour en moyenne).'
          : 'Protéines un peu justes : ${Fmt.n(nutrition!.proteines, decimals: 0)} g par jour pour ${Fmt.n(objectifProteines, decimals: 0)} g visés.');
    }
    if (sommeil != null) {
      b.writeln();
      b.writeln(sommeil!.inMinutes >= 420
          ? 'Sommeil solide : ${Fmt.sommeil(sommeil!)} par nuit.'
          : 'Sommeil court (${Fmt.sommeil(sommeil!)} par nuit) : c\'est le premier levier pour mieux récupérer.');
    }
    return b.toString().trim();
  }
}

typedef ExerciseName = String Function(String id);
