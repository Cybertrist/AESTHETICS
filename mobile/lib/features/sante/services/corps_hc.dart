import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';

/// Une valeur de la balance lue dans Health Connect : un poids ou un taux
/// de gras, à une date.
typedef ReleveHc = ({DateTime date, double? poidsKg, double? grasPct});

/// Ce qu'une lecture de Health Connect change dans les saisies.
typedef FusionCorps = ({List<BodyMeasurement> aEcrire, List<String> aRetirer});

/// Ce que Health Connect laisse lire du corps. Sans [historique], il ne
/// donne que les 30 jours qui précèdent la première autorisation.
typedef AccesCorps = ({bool poids, bool gras, bool historique});

/// Total d'une lecture de tout l'historique.
class BilanCorps {
  const BilanCorps({this.valeurs = 0, this.jours = 0, this.modifies = 0, this.premier, this.dernier});

  /// Pesées et taux de gras lus, un par un.
  final int valeurs;

  /// Jours portant au moins une valeur.
  final int jours;

  /// Jours dont la saisie a été créée ou changée.
  final int modifies;
  final DateTime? premier;
  final DateTime? dernier;

  /// Le total après un lot de relevés d'autres jours.
  BilanCorps avec(List<ReleveHc> releves, int modifies) {
    final dates = [for (final r in releves) r.date]..sort();
    return BilanCorps(
      valeurs: valeurs + releves.length,
      jours: jours + {for (final d in dates) Dates.jour(d)}.length,
      modifies: this.modifies + modifies,
      premier: premier == null || dates.first.isBefore(premier!) ? dates.first : premier,
      dernier: dernier == null || dates.last.isAfter(dernier!) ? dates.last : dernier,
    );
  }
}

/// Range les pesées de Health Connect dans les saisies, sans écran.
abstract final class CorpsHc {
  static const source = 'health connect';

  /// Identifiant de la saisie d'un jour venue de Health Connect.
  static String idDuJour(DateTime jour) =>
      'hc-${jour.year}-${jour.month.toString().padLeft(2, '0')}-${jour.day.toString().padLeft(2, '0')}';

  /// Anciennes pesées importées une par une (une saisie par valeur).
  static bool _ancienne(BodyMeasurement m) => m.id.startsWith('hc-p-') || m.id.startsWith('hc-mg-');

  static double _net(double v, int decimales) {
    final f = decimales == 2 ? 100 : 10;
    return (v * f).round() / f;
  }

  /// Une saisie par jour : la dernière pesée et le dernier taux de gras du
  /// jour. Une valeur saisie à la main ce jour-là est gardée, Health Connect
  /// ne remplit que ce qui manque ; une saisie venue de Health Connect suit
  /// ce que dit la balance. Rien n'est écrit quand rien ne change.
  static FusionCorps fusionner(Iterable<BodyMeasurement> existantes, Iterable<ReleveHc> releves) {
    final tries = [...releves]..sort((a, b) => a.date.compareTo(b.date));
    final parJour = <DateTime, ({DateTime date, double? poids, double? gras})>{};
    for (final r in tries) {
      final poids = r.poidsKg != null && r.poidsKg! > 0 ? _net(r.poidsKg!, 2) : null;
      // Certaines balances donnent une fraction (0,15) plutôt qu'un pourcentage.
      final gras = r.grasPct != null && r.grasPct! > 0 ? _net(r.grasPct! <= 1 ? r.grasPct! * 100 : r.grasPct!, 1) : null;
      if (poids == null && gras == null) continue;
      final jour = Dates.jour(r.date);
      final avant = parJour[jour];
      parJour[jour] = (date: r.date, poids: poids ?? avant?.poids, gras: gras ?? avant?.gras);
    }

    final aEcrire = <BodyMeasurement>[];
    final aRetirer = <String>[];
    for (final MapEntry(key: jour, value: hc) in parJour.entries) {
      final id = idDuJour(jour);
      final duJour = existantes.where((m) => Dates.memeJour(m.date, jour)).toList();
      aRetirer.addAll(duJour.where(_ancienne).map((m) => m.id));
      final saisies = duJour.where((m) => !_ancienne(m)).toList();
      final cible = saisies.where((m) => m.id == id).firstOrNull ?? saisies.firstOrNull;
      if (cible == null) {
        aEcrire.add(BodyMeasurement(id: id, date: hc.date, poidsKg: hc.poids, masseGrassePct: hc.gras, source: source));
        continue;
      }
      final balance = cible.source == source;
      final poids = balance ? hc.poids ?? cible.poidsKg : cible.poidsKg ?? hc.poids;
      final gras = balance ? hc.gras ?? cible.masseGrassePct : cible.masseGrassePct ?? hc.gras;
      if (poids != cible.poidsKg || gras != cible.masseGrassePct) aEcrire.add(cible.copyWith(poidsKg: poids, masseGrassePct: gras));
    }
    return (aEcrire: aEcrire, aRetirer: aRetirer);
  }
}
