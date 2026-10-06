import 'dart:math' as math;

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Période choisie en haut de l'onglet Progrès.
enum PeriodeProgres {
  semaine('Semaine', 'vs sem. passée'),
  mois('Mois', 'vs mois passé'),
  annee('Année', 'vs an passé');

  const PeriodeProgres(this.label, this.contre);
  final String label;

  /// Suite de l'écart : « +12 % vs sem. passée ».
  final String contre;
}

/// Part d'un groupe musculaire dans un volume.
typedef PartGroupe = ({MuscleRegion groupe, double volume, double part});

/// Une barre d'un graphique de volume.
typedef BarreVolume = ({DateTime debut, String label, double volume, bool courante});

/// Progression d'un exercice sur une période : son 1RM estimé au début et
/// à son meilleur, et le gain en pour cent.
typedef Progression = ({String exerciseId, double de, double a, int pourcent});

/// Record battu : la meilleure série d'un exercice dépasse tout ce qui précède.
typedef RecordBattu = ({String exerciseId, WorkoutSession session, WorkoutSet serie, double valeur, double avant});

/// Chiffres de la grande carte et des trois tuiles pour une période.
class ResumePeriode {
  const ResumePeriode({
    required this.debut,
    required this.fin,
    required this.volume,
    required this.volumeAvant,
    required this.seances,
    required this.duree,
    required this.records,
    required this.groupes,
    required this.intensites,
  });

  /// Intervalle [debut, fin[ de la période entière.
  final DateTime debut;
  final DateTime fin;
  final double volume;

  /// Volume de la période d'avant, arrêté au même point (lundi à vendredi
  /// contre lundi à vendredi), pour comparer ce qui est comparable.
  final double volumeAvant;
  final int seances;
  final Duration duree;
  final int records;

  /// Groupes travaillés, du plus gros volume au plus petit.
  final List<PartGroupe> groupes;

  /// Muscles à allumer sur le personnage (1 plein, 0,55 en retrait).
  final Map<Muscle, double> intensites;

  /// Écart en pour cent contre la période d'avant ; null s'il n'y a rien à
  /// dire (pas de base, ou écart nul : on n'affiche jamais « 0 »).
  int? get ecart => Calculs.ecart(volume, volumeAvant);
}

/// Calculs purs de l'onglet Progrès (volumes, records, régularité).
abstract final class Calculs {
  /// Libellé court d'un groupe : « Pectoraux », « Dos », « Jambes »...
  static String groupe(MuscleRegion r) => r == MuscleRegion.poitrine ? 'Pectoraux' : r.label;

  static const moisLongs = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  static const moisCourts = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

  /// « septembre ».
  static String moisNom(DateTime d) => moisLongs[d.month - 1];

  /// « Septembre ».
  static String moisCap(DateTime d) => maj(moisNom(d));

  /// « Septembre 2026 ».
  static String moisAnnee(DateTime d) => '${moisCap(d)} ${d.year}';

  /// « sept. ».
  static String moisCourt(DateTime d) => moisCourts[d.month - 1];

  static String maj(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// « 2026-09 », pour les paramètres de route.
  static String cleMois(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Lit « 2026-09 » ; null si ce n'est pas un mois.
  static DateTime? lireMois(String? s) {
    final p = s?.split('-');
    if (p == null || p.length != 2) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (y == null || m == null || m < 1 || m > 12 || y < 1 || y > 9999) return null;
    return DateTime(y, m);
  }

  /// Numéro de semaine ISO (la semaine 1 contient le premier jeudi).
  static int numeroSemaine(DateTime d) {
    final j = Dates.jour(d);
    final jeudi = DateTime(j.year, j.month, j.day + 4 - j.weekday);
    final premier = DateTime(jeudi.year, 1, 1);
    return 1 + ((jeudi.difference(premier).inHours / 24).round() ~/ 7);
  }

  /// « 28 sept. au 4 oct. ».
  static String semaineLibelle(DateTime debut) {
    final fin = DateTime(debut.year, debut.month, debut.day + 6);
    if (debut.month == fin.month) return '${debut.day} au ${fin.day} ${moisCourt(fin)}';
    return '${debut.day} ${moisCourt(debut)} au ${fin.day} ${moisCourt(fin)}';
  }

  /// Écart arrondi en pour cent ; null sans base ou si l'écart est nul.
  static int? ecart(num actuel, num avant) {
    if (avant <= 0) return null;
    final e = ((actuel - avant) / avant * 100).round();
    return e == 0 ? null : e;
  }

  /// « +12 % » ou « -8 % » (signe moins simple).
  static String signe(int ecart) => '${ecart > 0 ? '+' : '-'}${ecart.abs()} %';

  /// Durée d'une séance, bornée (une séance oubliée ouverte ne compte pas
  /// pour une journée).
  static Duration dureeDe(WorkoutSession s) {
    final fin = s.fin;
    if (fin == null) return Duration.zero;
    return Duration(seconds: fin.difference(s.debut).inSeconds.clamp(0, 6 * 3600));
  }

  static Iterable<WorkoutSession> entre(Iterable<WorkoutSession> sessions, DateTime debut, DateTime fin) =>
      sessions.where((s) => !s.enCours && !s.debut.isBefore(debut) && s.debut.isBefore(fin));

  static double volumeDe(Iterable<WorkoutSession> sessions) => sessions.fold(0.0, (a, s) => a + s.volume);

  /// Début de la période qui contient [now], et début de la suivante.
  static (DateTime, DateTime) bornes(PeriodeProgres p, DateTime now, {int decalage = 0, int premierJour = DateTime.monday}) {
    switch (p) {
      case PeriodeProgres.semaine:
        final d = Dates.debutSemaine(now, premierJour: premierJour);
        final a = DateTime(d.year, d.month, d.day + 7 * decalage);
        return (a, DateTime(a.year, a.month, a.day + 7));
      case PeriodeProgres.mois:
        return (DateTime(now.year, now.month + decalage), DateTime(now.year, now.month + decalage + 1));
      case PeriodeProgres.annee:
        return (DateTime(now.year + decalage), DateTime(now.year + decalage + 1));
    }
  }

  /// Fin (exclue) de la tranche de la période d'avant qui se compare à la
  /// période en cours : le même nombre de jours entiers, aujourd'hui
  /// compris (lundi à vendredi contre lundi à vendredi, du 1er au 12 contre
  /// du 1er au 12). Par le calendrier, pas à l'heure près : une séance faite
  /// une heure plus tôt que la semaine passée se compare quand même, et ni
  /// le changement d'heure ni le 29 février ne décalent la borne. Jamais
  /// au-delà de [debut] : le 31 mars se compare à février entier.
  static DateTime memePoint(PeriodeProgres p, DateTime debut, DateTime debutAvant, DateTime now) {
    final DateTime f;
    switch (p) {
      case PeriodeProgres.semaine:
        final jours = (Dates.jour(now).difference(debut).inHours / 24).round() + 1;
        f = DateTime(debutAvant.year, debutAvant.month, debutAvant.day + jours);
      case PeriodeProgres.mois:
        f = DateTime(debutAvant.year, debutAvant.month, now.day + 1);
      case PeriodeProgres.annee:
        // Le 29 février se compare au 28.
        final j = now.month == 2 && now.day == 29 ? 28 : now.day;
        f = DateTime(debutAvant.year, now.month, j + 1);
    }
    return f.isAfter(debut) ? debut : f;
  }

  /// « S40 » : le numéro ISO de la semaine qui commence à [debut]. Pris au
  /// milieu de la semaine, pour rester juste quand elle commence un samedi
  /// ou un dimanche.
  static String etiquetteSemaine(DateTime debut) => 'S${numeroSemaine(DateTime(debut.year, debut.month, debut.day + 3))}';

  /// Volume par groupe : chaque exercice compte pour le groupe de son
  /// premier muscle principal, les parts font donc 100 %.
  static List<PartGroupe> parGroupe(Iterable<WorkoutSession> sessions, Exercise? Function(String) lookup) {
    final acc = <MuscleRegion, double>{};
    for (final s in sessions) {
      for (final e in s.exercices) {
        final m = lookup(e.exerciseId)?.musclesPrincipaux.firstOrNull;
        final v = e.volume;
        if (m == null || v <= 0) continue;
        acc[m.region] = (acc[m.region] ?? 0) + v;
      }
    }
    final total = acc.values.fold(0.0, (a, b) => a + b);
    final out = <PartGroupe>[
      for (final e in acc.entries) (groupe: e.key, volume: e.value, part: total <= 0 ? 0.0 : e.value / total),
    ]..sort((a, b) => b.volume.compareTo(a.volume));
    return out;
  }

  /// Muscles allumés selon leur volume : les plus travaillés en plein, les
  /// suivants en retrait, le reste éteint.
  static Map<Muscle, double> intensites(Iterable<WorkoutSession> sessions, Exercise? Function(String) lookup) {
    var v = Strength.volumeParMuscle(sessions, lookup);
    // Sans charge (poids du corps), on se rabat sur les séries.
    if (v.values.every((x) => x <= 0)) v = Strength.setsParMuscle(sessions, lookup);
    final max = v.values.fold(0.0, math.max);
    if (max <= 0) return const {};
    final tries = v.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    // Quatre muscles en plein au plus, quatre en retrait : au-delà, le
    // personnage s'allume en entier et ne dit plus rien.
    final out = <Muscle, double>{};
    var pleins = 0, retraits = 0;
    for (final e in tries) {
      final r = e.value / max;
      if (r >= 0.6 && pleins < 4) {
        out[e.key] = 1.0;
        pleins++;
      } else if (r >= 0.3 && retraits < 4) {
        out[e.key] = 0.55;
        retraits++;
      }
    }
    return out;
  }

  /// Chiffres de la période qui contient [now].
  static ResumePeriode resume(
    PeriodeProgres p,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
    List<RecordBattu>? recordsConnus,
    int premierJour = DateTime.monday,
  }) {
    final n = now ?? DateTime.now();
    final (debut, fin) = bornes(p, n, premierJour: premierJour);
    final (debutAvant, _) = bornes(p, n, decalage: -1, premierJour: premierJour);
    final dans = entre(sessions, debut, fin).toList();
    // Les mêmes jours de la période d'avant.
    final avant = entre(sessions, debutAvant, memePoint(p, debut, debutAvant, n));
    final rec = (recordsConnus ?? records(sessions)).where((r) => !r.session.debut.isBefore(debut) && r.session.debut.isBefore(fin));
    return ResumePeriode(
      debut: debut,
      fin: fin,
      volume: volumeDe(dans),
      volumeAvant: volumeDe(avant),
      seances: dans.length,
      duree: dans.fold(Duration.zero, (a, s) => a + dureeDe(s)),
      records: rec.map((r) => r.exerciseId).toSet().length,
      groupes: parGroupe(dans, lookup),
      intensites: intensites(dans, lookup),
    );
  }

  /// Chiffres de la semaine de [jour] (bilan de la semaine). Une semaine
  /// finie se compare à la semaine d'avant entière ; la semaine en cours
  /// (celle de [now]) aux mêmes jours de la semaine d'avant, comme la carte
  /// de l'onglet : sinon un lundi afficherait « -100 % ».
  static ResumePeriode semaine(
    DateTime jour,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
    int premierJour = DateTime.monday,
  }) {
    final debut = Dates.debutSemaine(jour, premierJour: premierJour);
    final fin = DateTime(debut.year, debut.month, debut.day + 7);
    final avant = DateTime(debut.year, debut.month, debut.day - 7);
    final dans = entre(sessions, debut, fin).toList();
    final enCours = now != null && !now.isBefore(debut) && now.isBefore(fin);
    final finAvant = enCours ? memePoint(PeriodeProgres.semaine, debut, avant, now) : debut;
    return ResumePeriode(
      debut: debut,
      fin: fin,
      volume: volumeDe(dans),
      volumeAvant: volumeDe(entre(sessions, avant, finAvant)),
      seances: dans.length,
      duree: dans.fold(Duration.zero, (a, s) => a + dureeDe(s)),
      records: 0,
      groupes: parGroupe(dans, lookup),
      intensites: intensites(dans, lookup),
    );
  }

  /// Volume de la semaine d'un groupe, rapporté à sa meilleure semaine des
  /// [semaines] dernières (100 = sa plus grosse semaine).
  static Map<MuscleRegion, int> contreMeilleureSemaine(
    DateTime jour,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    int semaines = 12,
    int premierJour = DateTime.monday,
  }) {
    final debut = Dates.debutSemaine(jour, premierJour: premierJour);
    final meilleur = <MuscleRegion, double>{};
    final courant = <MuscleRegion, double>{};
    for (var i = 0; i < semaines; i++) {
      final d = DateTime(debut.year, debut.month, debut.day - 7 * i);
      final f = DateTime(d.year, d.month, d.day + 7);
      for (final g in parGroupe(entre(sessions, d, f), lookup)) {
        if (i == 0) courant[g.groupe] = g.volume;
        meilleur[g.groupe] = math.max(meilleur[g.groupe] ?? 0, g.volume);
      }
    }
    return {
      for (final e in courant.entries)
        if ((meilleur[e.key] ?? 0) > 0) e.key: (e.value / meilleur[e.key]! * 100).round(),
    };
  }

  /// Les [n] dernières semaines, la plus ancienne d'abord (« S33 » à « S40 »).
  static List<BarreVolume> volumesParSemaine(List<WorkoutSession> sessions, {int n = 8, DateTime? now, int premierJour = DateTime.monday}) {
    final cette = Dates.debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final d = DateTime(cette.year, cette.month, cette.day - 7 * i);
          final f = DateTime(d.year, d.month, d.day + 7);
          return (debut: d, label: etiquetteSemaine(d), volume: volumeDe(entre(sessions, d, f)), courante: i == 0);
        }(),
    ];
  }

  /// Les semaines qui touchent un mois (quatre à six barres). Chaque barre
  /// ne compte que les jours du mois : leur somme est le volume du mois, et
  /// une semaine à cheval ne prête pas à septembre les séances d'octobre.
  static List<BarreVolume> semainesDuMois(DateTime mois, List<WorkoutSession> sessions, {DateTime? now, int premierJour = DateTime.monday}) {
    final cette = Dates.debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
    final debutMois = DateTime(mois.year, mois.month);
    final fin = DateTime(mois.year, mois.month + 1);
    final out = <BarreVolume>[];
    for (var d = Dates.debutSemaine(debutMois, premierJour: premierJour); d.isBefore(fin); d = DateTime(d.year, d.month, d.day + 7)) {
      final f = DateTime(d.year, d.month, d.day + 7);
      final de = d.isBefore(debutMois) ? debutMois : d;
      final a = f.isAfter(fin) ? fin : f;
      out.add((debut: d, label: etiquetteSemaine(d), volume: volumeDe(entre(sessions, de, a)), courante: d == cette));
    }
    return out;
  }

  /// Les [n] derniers mois jusqu'à [mois] compris, le plus ancien d'abord.
  static List<BarreVolume> volumesParMois(DateTime mois, List<WorkoutSession> sessions, {int n = 12}) => [
        for (var i = n - 1; i >= 0; i--)
          () {
            final d = DateTime(mois.year, mois.month - i);
            return (
              debut: d,
              label: moisCourt(d),
              volume: volumeDe(entre(sessions, d, DateTime(d.year, d.month + 1))),
              courante: i == 0,
            );
          }(),
      ];

  /// Tous les records battus, du plus ancien au plus récent, en un seul
  /// passage. Un record : la meilleure série d'un exercice (1RM estimé, ou
  /// répétitions sans charge) dépasse tout l'historique. La première fois
  /// d'un exercice n'est pas un record.
  static List<RecordBattu> records(List<WorkoutSession> sessions) {
    final chrono = sessions.where((s) => !s.enCours).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    final meilleur = <String, double>{};
    final out = <RecordBattu>[];
    for (final s in chrono) {
      final duJour = <String, (WorkoutSet, double)>{};
      for (final e in s.exercices) {
        for (final set in e.series) {
          if (!set.fait || !set.type.counts) continue;
          final v = valeurSerie(set);
          if (v <= 0) continue;
          final deja = duJour[e.exerciseId];
          if (deja == null || v > deja.$2) duJour[e.exerciseId] = (set, v);
        }
      }
      for (final e in duJour.entries) {
        final avant = meilleur[e.key];
        if (avant != null && e.value.$2 > avant + 1e-9) {
          out.add((exerciseId: e.key, session: s, serie: e.value.$1, valeur: e.value.$2, avant: avant));
        }
        if (avant == null || e.value.$2 > avant) meilleur[e.key] = e.value.$2;
      }
    }
    return out;
  }

  /// Valeur d'une série pour les records : 1RM estimé, sinon répétitions
  /// (ramenées sous le kilo pour ne jamais passer devant une charge).
  static double valeurSerie(WorkoutSet s) {
    final rm = Strength.setOneRm(s);
    if (rm > 0) return rm;
    return (s.reps ?? 0) / 1000;
  }

  /// Nombre d'exercices qui ont un record (au moins une série faite).
  static int exercicesAvecRecord(List<WorkoutSession> sessions) {
    final ids = <String>{};
    for (final s in sessions) {
      if (s.enCours) continue;
      for (final e in s.exercices) {
        if (e.series.any((x) => x.fait && x.type.counts && valeurSerie(x) > 0)) ids.add(e.exerciseId);
      }
    }
    return ids.length;
  }

  /// « 50 kg × 12 », ou « 15 rép. » sans charge.
  static String serieTexte(WorkoutSet s) {
    final p = s.poids ?? 0;
    final r = s.reps ?? 0;
    if (p <= 0) return '$r rép.';
    return '${Fmt.n(p)} kg × $r';
  }

  /// Type de séance de chaque jour (la première du jour l'emporte).
  static Map<DateTime, TypeSeance> typesParJour(Iterable<WorkoutSession> sessions) {
    final out = <DateTime, TypeSeance>{};
    final chrono = sessions.where((s) => !s.enCours).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    for (final s in chrono) {
      out.putIfAbsent(Dates.jour(s.debut), () => s.type);
    }
    return out;
  }

  /// Chiffres de la période qui contient [jour]. Une période finie se
  /// compare à la précédente entière ; la période en cours (celle de [now])
  /// aux mêmes jours de la précédente.
  static ResumePeriode resumeDe(
    PeriodeProgres p,
    DateTime jour,
    List<WorkoutSession> sessions,
    Exercise? Function(String) lookup, {
    DateTime? now,
    List<RecordBattu>? recordsConnus,
    int premierJour = DateTime.monday,
  }) {
    final n = now ?? DateTime.now();
    final (debut, fin) = bornes(p, jour, premierJour: premierJour);
    final (debutAvant, _) = bornes(p, jour, decalage: -1, premierJour: premierJour);
    final enCours = !n.isBefore(debut) && n.isBefore(fin);
    final dans = entre(sessions, debut, fin).toList();
    final avant = entre(sessions, debutAvant, enCours ? memePoint(p, debut, debutAvant, n) : debut);
    final rec = (recordsConnus ?? records(sessions)).where((r) => !r.session.debut.isBefore(debut) && r.session.debut.isBefore(fin));
    return ResumePeriode(
      debut: debut,
      fin: fin,
      volume: volumeDe(dans),
      volumeAvant: volumeDe(avant),
      seances: dans.length,
      duree: dans.fold(Duration.zero, (a, s) => a + dureeDe(s)),
      records: rec.map((r) => r.exerciseId).toSet().length,
      groupes: parGroupe(dans, lookup),
      intensites: intensites(dans, lookup),
    );
  }

  /// Les sept jours de la semaine qui commence à [debut] (« L » à « D »).
  static List<BarreVolume> volumesParJour(DateTime debut, List<WorkoutSession> sessions, {DateTime? now}) {
    final auj = Dates.jour(now ?? DateTime.now());
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = DateTime(debut.year, debut.month, debut.day + i);
          final f = DateTime(d.year, d.month, d.day + 1);
          return (debut: d, label: Dates.initiale(d), volume: volumeDe(entre(sessions, d, f)), courante: d == auj);
        }(),
    ];
  }

  /// Les douze mois de l'année [annee] (« J » à « D »).
  static List<BarreVolume> moisDeLAnnee(int annee, List<WorkoutSession> sessions, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return [
      for (var m = 1; m <= 12; m++)
        (
          debut: DateTime(annee, m),
          label: moisCourts[m - 1][0].toUpperCase(),
          volume: volumeDe(entre(sessions, DateTime(annee, m), DateTime(annee, m + 1))),
          courante: annee == n.year && m == n.month,
        ),
    ];
  }

  /// Semaines du mois qui ont leur séance, sur les semaines déjà commencées
  /// (« 3/4 »). Une semaine à cheval compte pour le mois où elle commence.
  static (int, int) semainesTenues(DateTime mois, List<WorkoutSession> sessions, {DateTime? now, int premierJour = DateTime.monday}) {
    final cette = Dates.debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
    final debutMois = DateTime(mois.year, mois.month);
    final fin = DateTime(mois.year, mois.month + 1);
    var tenues = 0, total = 0;
    for (var d = Dates.debutSemaine(debutMois, premierJour: premierJour); d.isBefore(fin); d = DateTime(d.year, d.month, d.day + 7)) {
      if (d.isBefore(debutMois) || d.isAfter(cette)) continue;
      total++;
      if (entre(sessions, d, DateTime(d.year, d.month, d.day + 7)).isNotEmpty) tenues++;
    }
    return (tenues, total);
  }

  /// Plus longue suite de semaines d'affilée avec une séance, parmi les
  /// semaines qui commencent dans [debut, fin[.
  static int meilleureSerie(Iterable<WorkoutSession> sessions, DateTime debut, DateTime fin, {int premierJour = DateTime.monday}) {
    final semaines = <DateTime>{
      for (final s in sessions)
        if (!s.enCours) Dates.debutSemaine(s.debut, premierJour: premierJour),
    }.where((d) => !d.isBefore(debut) && d.isBefore(fin)).toList()
      ..sort();
    var meilleure = 0, courante = 0;
    DateTime? avant;
    for (final d in semaines) {
      final suite = avant != null && d == DateTime(avant.year, avant.month, avant.day + 7);
      courante = suite ? courante + 1 : 1;
      if (courante > meilleure) meilleure = courante;
      avant = d;
    }
    return meilleure;
  }

  /// Les [n] exercices qui ont le plus progressé dans [sessions] : le 1RM
  /// estimé de la première séance contre le meilleur atteint ensuite. Il
  /// faut au moins trois séances de l'exercice et un départ d'au moins vingt
  /// kilos pour que le chiffre ait un sens (un lest passé de 3 à 15 kg ne
  /// fait pas « +400 % »).
  static List<Progression> progressions(Iterable<WorkoutSession> sessions, Exercise? Function(String) lookup, {int n = 3}) {
    final chrono = sessions.where((s) => !s.enCours).toList()..sort((a, b) => a.debut.compareTo(b.debut));
    final premier = <String, double>{};
    final meilleur = <String, double>{};
    final fois = <String, int>{};
    for (final s in chrono) {
      for (final e in s.exercices) {
        final rm = e.series.fold(0.0, (a, x) => math.max(a, Strength.setOneRm(x)));
        if (rm <= 0) continue;
        fois[e.exerciseId] = (fois[e.exerciseId] ?? 0) + 1;
        premier.putIfAbsent(e.exerciseId, () => rm);
        if (rm > (meilleur[e.exerciseId] ?? 0)) meilleur[e.exerciseId] = rm;
      }
    }
    final out = <Progression>[
      for (final id in premier.keys)
        if ((fois[id] ?? 0) >= 3 && premier[id]! >= 20 && lookup(id) != null && meilleur[id]! > premier[id]!)
          (exerciseId: id, de: premier[id]!, a: meilleur[id]!, pourcent: ((meilleur[id]! - premier[id]!) / premier[id]! * 100).round()),
    ]..sort((a, b) => b.pourcent.compareTo(a.pourcent));
    return out.where((g) => g.pourcent > 0).take(n).toList();
  }

  /// Semaines d'affilée avec au moins une séance, comptées à la date [a].
  static int serieSemaines(Iterable<WorkoutSession> sessions, {DateTime? a, int premierJour = DateTime.monday}) {
    final n = a ?? DateTime.now();
    final fin = DateTime(n.year, n.month, n.day + 1);
    return Dates.semainesConsecutives(
      sessions.where((s) => !s.enCours && s.debut.isBefore(fin)).map((s) => s.debut),
      now: n,
      premierJour: premierJour,
    );
  }
}
