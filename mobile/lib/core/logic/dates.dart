/// Outils de dates : jours, semaines, séries de semaines actives.
abstract final class Dates {
  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Début de la semaine contenant [d] (lundi par défaut).
  static DateTime debutSemaine(DateTime d, {int premierJour = DateTime.monday}) {
    final j = jour(d);
    final delta = (j.weekday - premierJour) % 7;
    // Par le calendrier, pas par tranches de 24 heures : sinon le début tombe
    // à 23 h ou à 1 h quand la semaine enjambe un changement d'heure.
    return DateTime(j.year, j.month, j.day - delta);
  }

  /// Début de la semaine suivante (minuit, quel que soit le changement d'heure).
  static DateTime finSemaine(DateTime d, {int premierJour = DateTime.monday}) {
    final s = debutSemaine(d, premierJour: premierJour);
    return DateTime(s.year, s.month, s.day + 7);
  }

  static DateTime debutMois(DateTime d) => DateTime(d.year, d.month);

  /// Les 7 jours de la semaine de [d].
  static List<DateTime> joursSemaine(DateTime d, {int premierJour = DateTime.monday}) {
    final s = debutSemaine(d, premierJour: premierJour);
    return [for (var i = 0; i < 7; i++) DateTime(s.year, s.month, s.day + i)];
  }

  /// Nombre de semaines consécutives (jusqu'à celle de [now]) avec au moins
  /// [minParSemaine] dates. La semaine en cours ne casse pas la série.
  static int semainesConsecutives(Iterable<DateTime> dates, {int minParSemaine = 1, DateTime? now, int premierJour = DateTime.monday}) {
    final parSemaine = <DateTime, int>{};
    for (final d in dates) {
      final s = debutSemaine(d, premierJour: premierJour);
      parSemaine[s] = (parSemaine[s] ?? 0) + 1;
    }
    var s = debutSemaine(now ?? DateTime.now(), premierJour: premierJour);
    var count = 0;
    if ((parSemaine[s] ?? 0) >= minParSemaine) count++;
    while (true) {
      s = DateTime(s.year, s.month, s.day - 7);
      if ((parSemaine[s] ?? 0) >= minParSemaine) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Initiale du jour : L M M J V S D.
  static const initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static String initiale(DateTime d) => initiales[d.weekday - 1];
}
