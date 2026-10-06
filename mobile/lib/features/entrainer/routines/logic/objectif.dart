import '../../../../core/logic/logic.dart';

/// Objectif d'un programme. Le modèle garde un texte libre
/// (`Program.objectif`) : on y écrit le libellé, et un ancien texte est
/// rapproché du choix le plus proche.
enum ObjectifProgramme {
  muscle('Prise de muscle'),
  force('Devenir plus fort'),
  seche('Sèche'),
  fondamentaux('Fondamentaux'),
  condition('Condition physique'),
  sport('Sport');

  const ObjectifProgramme(this.label);
  final String label;

  /// Le choix qui correspond à un texte enregistré, s'il y en a un.
  static ObjectifProgramme? depuis(String? texte) {
    if (texte == null || texte.trim().isEmpty) return null;
    final t = TextSearch.normalize(texte);
    for (final o in values) {
      if (TextSearch.normalize(o.label) == t) return o;
    }
    bool a(String mot) => t.contains(mot);
    if (a('seche') || a('perte') || a('affut')) return seche;
    if (a('muscle') || a('masse') || a('hypertroph') || a('volume')) return muscle;
    if (a('force') || a('fort')) return force;
    if (a('decouv') || a('base') || a('fondament')) return fondamentaux;
    if (a('forme') || a('condition') || a('tonus') || a('cardio') || a('endurance')) return condition;
    if (a('sport') || a('athlet')) return sport;
    return null;
  }
}
