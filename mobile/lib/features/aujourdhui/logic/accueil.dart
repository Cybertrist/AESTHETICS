import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'resume_jour.dart';

/// Mois dont le résumé s'affiche sur l'accueil : le mois précédent, du 1er
/// au 3 du mois seulement et s'il compte au moins une séance. Sinon null.
DateTime? moisDuResume(DateTime now, List<WorkoutSession> sessions) {
  if (now.day > 3) return null;
  final mois = DateTime(now.year, now.month - 1);
  final fin = DateTime(now.year, now.month);
  final actif = sessions.any((s) => !s.debut.isBefore(mois) && s.debut.isBefore(fin));
  return actif ? mois : null;
}

/// « septembre 2026 ».
String libelleMois(DateTime mois) => DateFormat('MMMM y', 'fr_FR').format(mois);

/// « 30 septembre · 00:37 » ; l'année s'ajoute quand ce n'est pas la nôtre.
String dateSeance(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final jour = DateFormat(d.year == n.year ? 'd MMMM' : 'd MMMM y', 'fr_FR').format(d);
  return '$jour · ${Fmt.heure(d)}';
}

/// Nom affiché d'une séance : « Séance » quand elle n'en a pas.
String nomSeance(WorkoutSession s) => s.nom.trim().isEmpty ? 'Séance' : s.nom.trim();

/// « 0:24 » pour une vidéo.
String dureeVideo(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

/// Nombre de records battus par séance : tous, le même nombre que le bilan
/// de la séance.
Map<String, int> recordsParSeance(List<WorkoutSession> sessions) {
  final out = <String, int>{};
  for (final r in historiqueRecords(sessions)) {
    out[r.session.id] = (out[r.session.id] ?? 0) + 1;
  }
  return out;
}

/// Ce qu'une nouveauté ouvre.
enum CibleNouveaute { bilanMois, seance, semaine }

/// Une ligne du panneau de la cloche.
class Nouveaute {
  const Nouveaute({required this.date, required this.titre, required this.detail, required this.cible, this.id});

  final DateTime date;
  final String titre;
  final String detail;
  final CibleNouveaute cible;

  /// Séance ou mois (« 2026-9 ») concerné.
  final String? id;
}

/// Nouveautés tirées des données : résumé du mois écoulé, records des deux
/// dernières semaines, objectif de la semaine atteint. La plus récente d'abord.
List<Nouveaute> nouveautes({
  required List<WorkoutSession> sessions,
  required DateTime now,
  required int objectif,
  int premierJour = DateTime.monday,
}) {
  final out = <Nouveaute>[];
  final moisPrec = DateTime(now.year, now.month - 1);
  final debutMois = DateTime(now.year, now.month);
  if (sessions.any((s) => !s.debut.isBefore(moisPrec) && s.debut.isBefore(debutMois))) {
    out.add(Nouveaute(
      date: debutMois,
      titre: 'Ton résumé de ${libelleMois(moisPrec)} est prêt',
      detail: 'Séances, volume, records et muscles du mois',
      cible: CibleNouveaute.bilanMois,
      id: '${moisPrec.year}-${moisPrec.month}',
    ));
  }
  final records = recordsParSeance(sessions);
  final limite = now.subtract(const Duration(days: 14));
  for (final s in sessions) {
    final n = records[s.id] ?? 0;
    final quand = s.fin ?? s.debut;
    if (n == 0 || quand.isBefore(limite)) continue;
    out.add(Nouveaute(
      date: quand,
      titre: n == 1 ? 'Un record battu' : '$n records battus',
      detail: '${nomSeance(s)} · ${dateSeance(s.debut, now: now)}',
      cible: CibleNouveaute.seance,
      id: s.id,
    ));
  }
  final debut = Dates.debutSemaine(now, premierJour: premierJour);
  final finSemaine = DateTime(debut.year, debut.month, debut.day + 7);
  final semaine = sessions.where((s) => !s.debut.isBefore(debut) && s.debut.isBefore(finSemaine)).toList()
    ..sort((a, b) => a.debut.compareTo(b.debut));
  if (objectif > 0 && semaine.length >= objectif) {
    final s = semaine[objectif - 1];
    out.add(Nouveaute(
      date: s.fin ?? s.debut,
      titre: 'Objectif de la semaine atteint',
      detail: '${semaine.length} / $objectif ${objectif >= 2 ? 'séances' : 'séance'}',
      cible: CibleNouveaute.semaine,
    ));
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Retient quand la cloche a été ouverte pour la dernière fois (petit fichier
/// du module, `aujourdhui_cloche`).
class ClocheRepo extends ChangeNotifier {
  ClocheRepo(this.store);

  final Store store;
  static const fichier = 'aujourdhui_cloche';
  static final _instances = Expando<ClocheRepo>();

  /// Une instance par stockage, chargée au premier appel.
  static ClocheRepo pour(Store store) => _instances[store] ??= (ClocheRepo(store)..pret);

  late final Future<void> pret = _charger();

  DateTime? _vuLe;
  bool _charge = false;
  bool _marque = false;

  bool get charge => _charge;
  DateTime? get vuLe => _vuLe;

  Future<void> _charger() async {
    try {
      final j = await store.readObject(fichier);
      final v = j?['vuLe'];
      // Une ouverture faite pendant la lecture l'emporte sur le fichier.
      if (!_marque) _vuLe = v is String ? DateTime.tryParse(v) : null;
    } catch (_) {
      if (!_marque) _vuLe = null;
    }
    _charge = true;
    notifyListeners();
  }

  /// Vrai s'il y a une nouveauté plus récente que la dernière ouverture.
  bool aDuNouveau(List<Nouveaute> liste) =>
      _charge && liste.any((n) => _vuLe == null || n.date.isAfter(_vuLe!));

  bool estNouvelle(Nouveaute n) => _vuLe == null || n.date.isAfter(_vuLe!);

  Future<void> marquerVu(DateTime now) async {
    _vuLe = now;
    _marque = true;
    notifyListeners();
    await store.write(fichier, {'vuLe': now.toIso8601String()});
  }
}
