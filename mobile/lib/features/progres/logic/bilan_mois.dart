import 'dart:math' as math;

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'tableau.dart';

/// Une ligne de la page « toutes les séances ».
typedef LigneSeanceMois = ({String nom, Duration duree, double volume});

/// Un mois de la page « régularité » : les cases vides avant le 1er (la
/// semaine commence le lundi), puis un booléen par jour.
typedef MoisRegularite = ({DateTime mois, int decalage, List<bool> jours});

/// Un axe de la toile des muscles : la valeur du mois et celle du mois
/// d'avant, de 0 à 1 (1 = le plus grand nombre de séries des deux mois).
typedef AxeToile = ({Muscle muscle, double mois, double avant});

/// Record du mois : l'exercice et sa meilleure série.
typedef RecordMois = ({String exerciseId, WorkoutSet serie});

/// Exercice favori du mois.
typedef FavoriMois = ({String exerciseId, int series});

/// Tout ce que racontent les dix pages du bilan d'un mois, ou d'une année
/// entière ([annuel]).
class BilanMois {
  const BilanMois({
    required this.mois,
    required this.seances,
    required this.dureeTotale,
    required this.volume,
    required this.ecartSeances,
    required this.ecartVolume,
    required this.regularite,
    required this.volumes,
    required this.serieSemaines,
    required this.toile,
    required this.nbRecords,
    required this.records,
    required this.favoris,
    required this.parGroupe,
    this.avantVide = false,
    this.annuel = false,
    this.nombreSeances,
  });

  /// Premier jour du mois (le 1er janvier pour une année).
  final DateTime mois;

  /// Bilan d'une année entière : comparé à l'année d'avant.
  final bool annuel;

  /// Nombre de séances quand [seances] ne les liste pas une à une.
  final int? nombreSeances;

  /// Les séances du mois, dans l'ordre ; pour une année, une ligne par mois.
  final List<LigneSeanceMois> seances;
  final Duration dureeTotale;
  final double volume;

  /// Écarts en pour cent contre le mois d'avant (null : rien à afficher).
  final int? ecartSeances;
  final int? ecartVolume;

  /// Neuf mois de cases, le mois du bilan en dernier.
  final List<MoisRegularite> regularite;

  /// Douze mois de volume, le mois du bilan en dernier.
  final List<BarreVolume> volumes;

  /// Semaines d'affilée avec une séance, comptées à la fin du mois.
  final int serieSemaines;
  final List<AxeToile> toile;

  /// Nombre d'exercices dont le record est tombé dans le mois.
  final int nbRecords;

  /// Les cinq plus belles progressions.
  final List<RecordMois> records;

  /// Les cinq exercices les plus pratiqués.
  final List<FavoriMois> favoris;
  final List<PartGroupe> parGroupe;

  /// Aucune séance le mois d'avant : rien à quoi comparer.
  final bool avantVide;

  int get nbSeances => nombreSeances ?? seances.length;
  bool get vide => nbSeances == 0;

  // Les mots de la période, pour les dix pages.
  DateTime get _avant => DateTime(mois.year, mois.month - 1);

  /// « SEPTEMBRE\n2026 », « ANNÉE\n2026 ».
  String get titre => annuel ? 'ANNÉE\n${mois.year}' : '${Calculs.moisNom(mois).toUpperCase()}\n${mois.year}';

  /// « en septembre », « en 2026 ».
  String get enPeriode => annuel ? 'en ${mois.year}' : 'en ${Calculs.moisNom(mois)}';

  /// « par rapport à août », « par rapport à 2025 ».
  String get contreAvant => annuel ? 'par rapport à ${mois.year - 1}' : 'par rapport à ${Calculs.moisNom(_avant)}';

  /// « ce mois », « cette année ».
  String get cettePeriode => annuel ? 'cette année' : 'ce mois';

  /// « du mois dernier », « de l'an dernier ».
  String get duDernier => annuel ? 'de l\'an dernier' : 'du mois dernier';

  /// « Septembre » et « Août », ou « 2026 » et « 2025 ».
  String get nomPeriode => annuel ? '${mois.year}' : Calculs.moisCap(mois);
  String get nomAvant => annuel ? '${mois.year - 1}' : Calculs.moisCap(_avant);

  /// « de septembre », « d'août », « de 2026 ».
  String get dePeriode {
    if (annuel) return 'de ${mois.year}';
    final nom = Calculs.moisNom(mois);
    return nom.startsWith('a') || nom.startsWith('o') ? 'd\'$nom' : 'de $nom';
  }

  /// Heures d'entraînement pleines (22 h 51 : 22 heures, comme le total de
  /// la page des séances).
  int get heures => dureeTotale.inHours;

  /// Axes de la toile, dans l'ordre de la maquette.
  static const axes = [
    Muscle.pectoraux,
    Muscle.deltoidesLateraux,
    Muscle.triceps,
    Muscle.grandDorsal,
    Muscle.biceps,
    Muscle.abdominaux,
    Muscle.quadriceps,
    Muscle.ischios,
    Muscle.trapezes,
  ];

  /// Séries d'un axe : les trois faisceaux pour les épaules.
  static double _series(Map<Muscle, double> s, Muscle m) {
    if (m != Muscle.deltoidesLateraux) return s[m] ?? 0;
    return [Muscle.deltoidesAnterieurs, Muscle.deltoidesLateraux, Muscle.deltoidesPosterieurs].map((x) => s[x] ?? 0).fold(0.0, math.max);
  }

  /// Cases d'un mois pour la page « régularité ».
  static MoisRegularite casesDe(DateTime mois, Set<DateTime> joursActifs) {
    final nb = DateTime(mois.year, mois.month + 1, 0).day;
    return (
      mois: DateTime(mois.year, mois.month),
      decalage: DateTime(mois.year, mois.month).weekday - 1,
      jours: [for (var j = 1; j <= nb; j++) joursActifs.contains(DateTime(mois.year, mois.month, j))],
    );
  }

  /// Calcule le bilan du mois de [mois]. [now] borne la série de semaines
  /// quand le mois est en cours.
  static BilanMois calculer(
    DateTime mois,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
  }) =>
      _calculer(DateTime(mois.year, mois.month), DateTime(mois.year, mois.month + 1), DateTime(mois.year, mois.month - 1), sessions, lookup, now: now, annuel: false);

  /// Calcule le bilan de l'année [annee], comparée à l'année d'avant (aux
  /// mêmes dates si l'année est en cours).
  static BilanMois calculerAnnee(
    int annee,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
  }) =>
      _calculer(DateTime(annee), DateTime(annee + 1), DateTime(annee - 1), sessions, lookup, now: now, annuel: true);

  static BilanMois _calculer(
    DateTime debut,
    DateTime fin,
    DateTime debutAvant,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
    required bool annuel,
  }) {
    final n = now ?? DateTime.now();
    final dans = Calculs.entre(sessions, debut, fin).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    // Une année en cours se compare aux mêmes mois de l'année d'avant.
    final enCours = !n.isBefore(debut) && n.isBefore(fin);
    final finAvant = annuel && enCours ? Calculs.memePoint(PeriodeProgres.annee, debut, debutAvant, n) : debut;
    final avant = Calculs.entre(sessions, debutAvant, finAvant).toList();
    final volume = Calculs.volumeDe(dans);

    final actifs = {for (final s in sessions) if (!s.enCours) Dates.jour(s.debut)};

    final sMois = Strength.setsParMuscle(dans, lookup);
    final sAvant = Strength.setsParMuscle(avant, lookup);
    final max = [for (final m in axes) ...[_series(sMois, m), _series(sAvant, m)]].fold(0.0, math.max);

    // Records du mois : par exercice, la dernière série record, classés par
    // progression sur le record d'avant.
    final parExo = <String, RecordBattu>{};
    final base = <String, double>{};
    for (final r in Calculs.records(sessions)) {
      if (r.session.debut.isBefore(debut) || !r.session.debut.isBefore(fin)) continue;
      base.putIfAbsent(r.exerciseId, () => r.avant);
      parExo[r.exerciseId] = r;
    }
    String nom(String id) => (lookup(id)?.nom ?? id).toLowerCase();
    // À égalité, l'ordre des noms : le classement ne dépend pas de l'ordre
    // des séances en mémoire.
    int parNom(String a, String b) {
      final c = nom(a).compareTo(nom(b));
      return c != 0 ? c : a.compareTo(b);
    }

    // Passer des répétitions sans charge (valeur sous 1) à une charge n'est
    // pas une progression mesurable : ces records passent après les autres.
    double progression(RecordBattu r) {
      final b = base[r.exerciseId]!;
      return b < 1 && r.valeur >= 1 ? 0 : r.valeur / b - 1;
    }

    final recs = parExo.values.toList()
      ..sort((a, b) {
        final c = progression(b).compareTo(progression(a));
        return c != 0 ? c : parNom(a.exerciseId, b.exerciseId);
      });

    final series = <String, int>{};
    for (final s in dans) {
      for (final e in s.exercices) {
        final k = compterSeries(e.seriesFaites.map((x) => x.type));
        if (k > 0) series[e.exerciseId] = (series[e.exerciseId] ?? 0) + k;
      }
    }
    final favoris = [for (final e in series.entries) (exerciseId: e.key, series: e.value)]
      ..sort((a, b) {
        final c = b.series.compareTo(a.series);
        return c != 0 ? c : parNom(a.exerciseId, b.exerciseId);
      });

    final dernierJour = DateTime(fin.year, fin.month, fin.day - 1);
    // Pour une année, une ligne par mois où l'on s'est entraîné.
    final parMois = <LigneSeanceMois>[
      for (var m = 1; m <= 12; m++)
        () {
          final duMois = dans.where((s) => s.debut.month == m).toList();
          return (
            nom: duMois.isEmpty ? '' : '${Calculs.moisCap(DateTime(debut.year, m))} · ${Fmt.pluriel(duMois.length, 'séance')}',
            duree: duMois.fold(Duration.zero, (a, s) => a + Calculs.dureeDe(s)),
            volume: Calculs.volumeDe(duMois),
          );
        }(),
    ].where((l) => l.nom.isNotEmpty).toList();
    return BilanMois(
      mois: debut,
      annuel: annuel,
      nombreSeances: dans.length,
      seances: annuel ? parMois : [for (final s in dans) (nom: s.nom, duree: Calculs.dureeDe(s), volume: s.volume)],
      dureeTotale: dans.fold(Duration.zero, (a, s) => a + Calculs.dureeDe(s)),
      volume: volume,
      ecartSeances: Calculs.ecart(dans.length, avant.length),
      ecartVolume: Calculs.ecart(volume, Calculs.volumeDe(avant)),
      regularite: annuel
          ? [for (var m = 1; m <= 12; m++) casesDe(DateTime(debut.year, m), actifs)]
          : [for (var i = 8; i >= 0; i--) casesDe(DateTime(debut.year, debut.month - i), actifs)],
      volumes: Calculs.volumesParMois(annuel ? DateTime(debut.year, 12) : debut, sessions),
      // Pour une année, sa plus longue série de semaines.
      serieSemaines: annuel ? Calculs.meilleureSerie(sessions, debut, fin) : Calculs.serieSemaines(sessions, a: n.isBefore(dernierJour) ? n : dernierJour),
      toile: [
        for (final m in axes)
          (
            muscle: m,
            mois: max <= 0 ? 0.0 : _series(sMois, m) / max,
            avant: max <= 0 ? 0.0 : _series(sAvant, m) / max,
          ),
      ],
      nbRecords: recs.length,
      records: [for (final r in recs.take(5)) (exerciseId: r.exerciseId, serie: r.serie)],
      favoris: favoris.take(5).toList(),
      parGroupe: Calculs.parGroupe(dans, lookup),
      avantVide: avant.isEmpty,
    );
  }
}
