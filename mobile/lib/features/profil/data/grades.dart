import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Pictogramme plein d'un écusson (tracés dans `widgets/ecusson.dart`). Les
/// trois derniers servent aux tuiles du profil.
enum PictoGrade { cible, aube, lune, epee, flamme, fiole, cartes, trophee, chrono, regle, appareil, haltere }

/// Un grade : une habitude ou un exploit compté sur toutes les séances, avec
/// des paliers. Chaque palier atteint fait monter le grade d'un niveau.
/// Rangés dans l'ordre de l'arc-en-ciel, du rouge au rose.
enum Grade {
  semaineParfaite(
    'Semaine parfaite',
    'Semaines où ton objectif de séances est atteint',
    'semaine',
    [1, 3, 5, 10, 15, 20, 30, 40, 50, 75],
    0xFFFF3347,
    PictoGrade.cible,
  ),
  leveTot(
    'Lève-tôt',
    'Séances commencées avant 7 h du matin',
    'séance',
    [1, 5, 10, 25, 50, 75, 100, 150, 200, 300],
    0xFFFF8419,
    PictoGrade.aube,
  ),
  serie(
    'Série',
    'Ta plus longue suite de semaines avec au moins une séance',
    'semaine',
    [2, 4, 8, 12, 15, 20, 26, 39, 52, 104],
    0xFFFFBE0B,
    PictoGrade.flamme,
  ),
  weekEnd(
    'Guerrier du week-end',
    'Séances faites un samedi ou un dimanche',
    'séance',
    [1, 5, 10, 25, 50, 75, 100, 150, 200, 300],
    0xFF2FCF55,
    PictoGrade.epee,
  ),
  collectionneur(
    'Collectionneur de routines',
    'Routines dans ta bibliothèque',
    'routine',
    [1, 3, 5, 10, 25],
    0xFF0FC9AE,
    PictoGrade.cartes,
  ),
  explorateur(
    'Explorateur d\'exercices',
    'Exercices différents déjà faits',
    'exercice',
    [5, 10, 25, 50, 75, 100, 150, 200, 300, 400],
    0xFF1FA8FF,
    PictoGrade.fiole,
  ),
  marathon(
    'Marathon',
    'Séances de deux heures ou plus',
    'séance',
    [1, 5, 10, 25, 50],
    0xFF3F66FF,
    PictoGrade.chrono,
  ),
  noctambule(
    'Noctambule',
    'Séances terminées après 23 h',
    'séance',
    [1, 5, 10, 25, 50, 75, 100, 150, 200, 300],
    0xFF8B55FF,
    PictoGrade.lune,
  ),
  records(
    'Chasseur de records',
    'Exercices où tu tiens un record de charge',
    'record',
    [1, 5, 10, 25, 50, 75, 100, 150, 200, 300],
    0xFFFF48B0,
    PictoGrade.trophee,
  );

  const Grade(this.nom, this.description, this.unite, this.paliers, this.couleur, this.picto);

  final String nom;
  final String description;

  /// Ce qui est compté, au singulier.
  final String unite;
  final List<int> paliers;

  /// Couleur de l'écusson (ARGB).
  final int couleur;
  final PictoGrade picto;
}

/// Où en est un compteur face à ses paliers.
class Avancee {
  const Avancee(this.valeur, this.paliers);
  final int valeur;
  final List<int> paliers;

  /// Nombre de paliers atteints.
  int get niveau => paliers.where((p) => valeur >= p).length;
  bool get gagne => niveau > 0;
  bool get auMax => niveau == paliers.length;

  /// Dernier palier atteint, null si aucun.
  int? get palier => gagne ? paliers[niveau - 1] : null;
  int? get prochain => auMax ? null : paliers[niveau];

  /// Part du chemin faite entre le palier atteint et le suivant (0 à 1).
  double get part {
    final p = prochain;
    if (p == null) return 1;
    final depart = palier ?? 0;
    return ((valeur - depart) / (p - depart)).clamp(0.0, 1.0);
  }
}

/// Les grades et les étapes d'un historique de séances.
class Grades {
  Grades._(this.valeurs, this.seances);

  final Map<Grade, int> valeurs;

  /// Séances terminées : le compteur des étapes importantes.
  final int seances;

  /// Couleurs des grades, dans l'ordre : les étapes les reprennent tour à tour.
  static final arcEnCiel = [for (final g in Grade.values) g.couleur];

  /// Paliers des étapes importantes, en nombre de séances.
  static const etapes = [1, 10, 25, 50, 100, 150, 200, 250, 300, 350, 400, 500, 600, 750, 1000, 1250, 1500, 2000];

  Avancee de(Grade g) => Avancee(valeurs[g] ?? 0, g.paliers);

  Avancee get etape => Avancee(seances, etapes);

  int get gagnes => Grade.values.where((g) => de(g).gagne).length;

  /// Les grades à montrer sur le profil : les plus hauts niveaux d'abord.
  List<Grade> vitrine([int n = 3]) {
    final l = Grade.values.where((g) => de(g).gagne).toList()
      ..sort((a, b) {
        final d = de(b).niveau.compareTo(de(a).niveau);
        return d != 0 ? d : a.index.compareTo(b.index);
      });
    return l.take(n).toList();
  }

  /// [objectifSemaine] : séances visées par semaine (profil). [nbRecords] vient
  /// des statistiques de carrière, déjà calculées pour le profil.
  static Grades from(
    List<WorkoutSession> toutes, {
    required int nbRoutines,
    required int nbRecords,
    int objectifSemaine = 4,
    int premierJour = DateTime.monday,
  }) {
    final sessions = toutes.where((s) => !s.enCours).toList();
    var tot = 0, tard = 0, weekEnd = 0, longues = 0;
    final exercices = <String>{};
    final parSemaine = <DateTime, int>{};
    for (final s in sessions) {
      if (s.debut.hour >= 4 && s.debut.hour < 7) tot++;
      final fin = s.fin!;
      // Une durée invraisemblable (séance oubliée ouverte) ne compte pas.
      final duree = fin.difference(s.debut);
      final vraie = duree.inHours < 12;
      if (vraie && (fin.hour >= 23 || fin.hour < 4)) tard++;
      if (vraie && duree.inMinutes >= 120) longues++;
      if (s.debut.weekday >= DateTime.saturday) weekEnd++;
      for (final e in s.exercices) {
        if (e.seriesFaites.isNotEmpty) exercices.add(e.exerciseId);
      }
      final sem = Dates.debutSemaine(s.debut, premierJour: premierJour);
      parSemaine[sem] = (parSemaine[sem] ?? 0) + 1;
    }
    final cible = objectifSemaine.clamp(1, 7);
    final parfaites = parSemaine.values.where((n) => n >= cible).length;

    // Plus longue suite de semaines qui se suivent.
    final semaines = parSemaine.keys.toList()..sort();
    var meilleure = 0, courante = 0;
    DateTime? precedente;
    for (final s in semaines) {
      // Autour d'un changement d'heure, sept jours font 167 ou 169 heures.
      final suit = precedente != null && (s.difference(precedente).inHours - 168).abs() <= 2;
      courante = suit ? courante + 1 : 1;
      if (courante > meilleure) meilleure = courante;
      precedente = s;
    }

    return Grades._({
      Grade.semaineParfaite: parfaites,
      Grade.leveTot: tot,
      Grade.noctambule: tard,
      Grade.weekEnd: weekEnd,
      Grade.serie: meilleure,
      Grade.explorateur: exercices.length,
      Grade.collectionneur: nbRoutines,
      Grade.records: nbRecords,
      Grade.marathon: longues,
    }, sessions.length);
  }
}
