import 'dart:math' as math;

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Période affichée par les courbes du module.
enum Periode {
  semaine('7 j', 7),
  mois('1 mois', 30),
  trimestre('3 mois', 90),
  annee('1 an', 365);

  const Periode(this.label, this.jours);
  final String label;
  final int jours;

  DateTime debut([DateTime? now]) => Dates.jour(now ?? DateTime.now()).subtract(Duration(days: jours - 1));

  static List<(Periode, String)> get segments => [for (final p in values) (p, p.label)];
}

/// Point daté d'une courbe.
typedef Point = ({DateTime date, double v});

abstract final class SanteCalc {
  /// Moyenne mobile sur [jours] jours glissants (et non sur n points),
  /// pour ne pas écraser les semaines où l'on se pèse peu.
  static List<Point> moyenneMobile(List<Point> pts, {int jours = 7}) {
    final out = <Point>[];
    for (var i = 0; i < pts.length; i++) {
      final from = pts[i].date.subtract(Duration(days: jours - 1));
      var somme = 0.0;
      var n = 0;
      for (var j = i; j >= 0 && !pts[j].date.isBefore(Dates.jour(from)); j--) {
        somme += pts[j].v;
        n++;
      }
      out.add((date: pts[i].date, v: somme / n));
    }
    return out;
  }

  /// Variation entre la première et la dernière valeur de la moyenne.
  static double? variation(List<Point> pts) => pts.length < 2 ? null : pts.last.v - pts.first.v;

  /// Qualité ressentie d'une nuit, en mots.
  static String qualite(int? q) => switch (q) {
        1 => 'Très mauvaise',
        2 => 'Mauvaise',
        3 => 'Correcte',
        4 => 'Bonne',
        5 => 'Excellente',
        _ => 'Non notée',
      };

  /// Durée en minutes d'une nuit, sans les éveils quand ils sont connus.
  static int minutesDormies(SleepEntry s) => math.max(0, s.duree.inMinutes - (s.eveilMin ?? 0));

  /// Régularité : écart moyen, en minutes, de l'heure de coucher.
  static int? ecartCoucher(List<SleepEntry> nuits) {
    if (nuits.length < 3) return null;
    // Minutes depuis 18 h pour que 23 h 30 et 0 h 30 soient voisines.
    final m = [for (final n in nuits) ((n.coucher.hour * 60 + n.coucher.minute) - 18 * 60 + 1440) % 1440];
    final moy = m.reduce((a, b) => a + b) / m.length;
    final ecart = m.map((x) => (x - moy).abs()).reduce((a, b) => a + b) / m.length;
    return ecart.round();
  }

  /// Heure moyenne (coucher ou lever) au format « 23:40 ».
  static String? heureMoyenne(List<DateTime> heures, {bool coucher = true}) {
    if (heures.isEmpty) return null;
    final base = coucher ? 18 * 60 : 0;
    final m = [for (final h in heures) ((h.hour * 60 + h.minute) - base + 1440) % 1440];
    final moy = (m.reduce((a, b) => a + b) / m.length).round();
    final t = (moy + base) % 1440;
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Heures « 08:00 » en (heure, minute).
  static (int, int)? parseHeure(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  static String heureTexte(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Jours consécutifs de prise d'un complément, jusqu'à aujourd'hui (ou hier).
  static int serie(bool Function(DateTime jour) pris, {DateTime? now}) {
    var d = Dates.jour(now ?? DateTime.now());
    if (!pris(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (pris(d) && n < 3650) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }
}

/// Récupération détaillée d'un muscle.
class RecupMuscle {
  const RecupMuscle({
    required this.muscle,
    required this.fatigue,
    required this.heuresAvantPret,
    required this.derniere,
    required this.series7j,
    required this.volume7j,
    required this.exercices7j,
    required this.seances7j,
  });

  final Muscle muscle;
  final double fatigue;

  /// 0 si déjà prêt (récupéré à 80 % ou plus).
  final int heuresAvantPret;

  /// Dernière séance qui l'a fait travailler (principal ou secondaire).
  final WorkoutSession? derniere;

  /// Séries effectives sur 7 jours (secondaires comptées pour moitié).
  final double series7j;
  final double volume7j;

  /// Exercice vers nombre de séries sur 7 jours.
  final Map<String, int> exercices7j;
  final int seances7j;

  int get pourcentage => ((1 - fatigue) * 100).round();
  bool get pret => fatigue <= 0.2;
}

abstract final class RecupCalc {
  /// Calcule l'état de chaque muscle à partir des séances.
  static Map<Muscle, RecupMuscle> calculer(
    List<WorkoutSession> sessions,
    Exercise? Function(String id) lookup, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final recentes = sessions.where((s) => t.difference(s.fin ?? s.debut).inHours <= 100 && !s.enCours).toList();
    final fatigue = Recovery.fatigue(recentes, lookup, now: t);

    // Heure à laquelle chaque muscle repasse sous 20 % de fatigue.
    final attente = <Muscle, int>{};
    final aSuivre = {for (final m in Muscle.values) if ((fatigue[m] ?? 0) > 0.2) m};
    for (var h = 1; h <= 100 && aSuivre.isNotEmpty; h++) {
      final f = Recovery.fatigue(recentes, lookup, now: t.add(Duration(hours: h)));
      for (final m in [...aSuivre]) {
        if ((f[m] ?? 0) <= 0.2) {
          attente[m] = h;
          aSuivre.remove(m);
        }
      }
    }

    final debut7 = t.subtract(const Duration(days: 7));
    final series = <Muscle, double>{};
    final volume = <Muscle, double>{};
    final exos = <Muscle, Map<String, int>>{};
    final seances = <Muscle, Set<String>>{};
    final derniere = <Muscle, WorkoutSession>{};

    // Les séances sont triées de la plus récente à la plus ancienne.
    final triees = [...sessions.where((s) => !s.enCours)]..sort((a, b) => b.debut.compareTo(a.debut));
    for (final s in triees) {
      final dans7 = s.debut.isAfter(debut7);
      for (final e in s.exercices) {
        final ex = lookup(e.exerciseId);
        if (ex == null) continue;
        final faites = e.seriesFaites.where((x) => x.type.counts).toList();
        if (faites.isEmpty) continue;
        for (final m in ex.tousMuscles) {
          derniere.putIfAbsent(m, () => s);
          if (!dans7) continue;
          final poids = ex.musclesPrincipaux.contains(m) ? 1.0 : 0.5;
          series[m] = (series[m] ?? 0) + faites.length * poids;
          volume[m] = (volume[m] ?? 0) + faites.fold<double>(0, (a, x) => a + x.volume) * poids;
          (exos[m] ??= {})[e.exerciseId] = (exos[m]![e.exerciseId] ?? 0) + faites.length;
          (seances[m] ??= {}).add(s.id);
        }
      }
      if (!dans7 && derniere.length == Muscle.values.length) break;
    }

    return {
      for (final m in Muscle.values)
        m: RecupMuscle(
          muscle: m,
          fatigue: fatigue[m] ?? 0,
          heuresAvantPret: attente[m] ?? 0,
          derniere: derniere[m],
          series7j: series[m] ?? 0,
          volume7j: volume[m] ?? 0,
          exercices7j: exos[m] ?? const {},
          seances7j: seances[m]?.length ?? 0,
        ),
    };
  }

  /// « Prêt », « Prêt dans 5 h », « Prêt demain vers 14 h ».
  static String pretDans(int heures, {DateTime? now}) {
    if (heures <= 0) return 'Prêt';
    if (heures < 24) return 'Prêt dans $heures h';
    final quand = (now ?? DateTime.now()).add(Duration(hours: heures));
    final jours = Dates.jour(quand).difference(Dates.jour(now ?? DateTime.now())).inDays;
    final jour = jours == 1 ? 'demain' : (jours == 2 ? 'après-demain' : Fmt.jour(quand));
    return 'Prêt $jour vers ${quand.hour} h';
  }
}

/// Mensurations regroupées (gauche et droite ensemble).
enum GroupeTour {
  bras('Tour de bras', [TourCorps.brasGauche, TourCorps.brasDroit]),
  poitrine('Poitrine', [TourCorps.poitrine]),
  taille('Taille', [TourCorps.taille]),
  hanches('Hanches', [TourCorps.hanches]),
  cuisses('Cuisses', [TourCorps.cuisseGauche, TourCorps.cuisseDroite]),
  mollets('Mollets', [TourCorps.molletGauche, TourCorps.molletDroit]),
  cou('Cou', [TourCorps.cou]),
  epaules('Épaules', [TourCorps.epaules]),
  avantBras('Avant-bras', [TourCorps.avantBrasGauche, TourCorps.avantBrasDroit]);

  const GroupeTour(this.label, this.tours);
  final String label;
  final List<TourCorps> tours;

  bool get deuxCotes => tours.length == 2;

  /// Pour la taille et les hanches, baisser est en général le but.
  bool get baisserEstBien => this == taille || this == hanches;

  /// Où placer le mètre ruban.
  String get conseil => switch (this) {
        bras => 'Bras contracté, à l\'endroit le plus épais du biceps.',
        poitrine => 'Sous les aisselles, sur la pointe des pectoraux, en expirant.',
        taille => 'Au nombril, ventre relâché, en fin d\'expiration.',
        hanches => 'À l\'endroit le plus large des fessiers, pieds joints.',
        cuisses => 'À mi-chemin entre l\'aine et le genou, jambe relâchée.',
        mollets => 'À l\'endroit le plus épais, debout, poids réparti.',
        cou => 'Juste sous la pomme d\'Adam, regard droit.',
        epaules => 'Autour des deltoïdes, bras le long du corps.',
        avantBras => 'Poing serré, à l\'endroit le plus épais.',
      };

  /// Valeur d'une mesure pour ce groupe (moyenne des côtés présents).
  double? valeur(BodyMeasurement m) {
    final v = [for (final t in tours) ?m.tours[t]];
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  /// Série du plus ancien au plus récent.
  List<Point> serie(List<BodyMeasurement> mesures, {DateTime? depuis}) => [
        for (final m in mesures.reversed)
          if (valeur(m) != null && (depuis == null || !m.date.isBefore(depuis))) (date: m.date, v: valeur(m)!),
      ];
}

/// Écart lisible entre deux dates : « 12 j », « 3 mois », « 1 an ».
String ecart(DateTime a, DateTime b) {
  final j = b.difference(a).inDays.abs();
  if (j < 60) return '$j j';
  if (j < 365) return '${(j / 30.4).round()} mois';
  final ans = (j / 365).round();
  return ans <= 1 ? '1 an' : '$ans ans';
}
