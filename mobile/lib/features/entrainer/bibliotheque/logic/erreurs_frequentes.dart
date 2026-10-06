import '../../../../core/logic/text_search.dart';
import '../../../../core/models/models.dart';

/// Erreurs fréquentes : règles par mouvement reconnu dans le nom, puis par
/// catégorie et par matériel. Le catalogue n'en fournit pas, elles sont
/// écrites ici une fois pour toutes.
abstract final class ErreursFrequentes {
  static const _parMouvement = <String, List<String>>{
    'squat': [
      'Genoux qui rentrent vers l\'intérieur à la remontée.',
      'Talons qui décollent : le poids doit rester sur tout le pied.',
      'Dos qui s\'arrondit en bas du mouvement.',
      'Descente trop haute, les cuisses loin de la parallèle.',
    ],
    'souleve de terre': [
      'Dos arrondi au départ : la colonne reste neutre, poitrine sortie.',
      'Barre qui s\'éloigne des jambes.',
      'Hanches qui montent avant les épaules.',
      'Hyperextension du dos en fin de mouvement.',
    ],
    'developpe couche': [
      'Coudes écartés à 90 degrés : garder environ 45 à 70 degrés.',
      'Fesses qui décollent du banc.',
      'Barre qui rebondit sur la poitrine.',
    ],
    'developpe militaire': [
      'Cambrure excessive du bas du dos.',
      'Barre qui passe devant le visage au lieu de monter droite.',
    ],
    'traction': [
      'Élan des jambes pour passer la barre.',
      'Amplitude incomplète : bras pas tendus en bas.',
      'Épaules qui montent vers les oreilles.',
    ],
    'rowing': [
      'Dos qui s\'arrondit ou buste qui se redresse pour tirer.',
      'Tirer avec les bras sans serrer les omoplates.',
    ],
    'curl': [
      'Balancer le buste pour monter la charge.',
      'Coudes qui avancent pendant la montée.',
      'Descente non contrôlée.',
    ],
    'fente': [
      'Genou avant qui dépasse largement et rentre vers l\'intérieur.',
      'Buste qui bascule vers l\'avant.',
    ],
    'dips': [
      'Descente trop profonde qui tire sur l\'avant des épaules.',
      'Épaules qui remontent vers les oreilles.',
    ],
    'hip thrust': [
      'Cambrer le bas du dos au lieu de serrer les fessiers.',
      'Menton levé : le regard suit le buste.',
    ],
    'elevation laterale': [
      'Monter les haltères au-dessus des épaules avec les trapèzes.',
      'Donner de l\'élan avec le buste.',
    ],
    'pompe': [
      'Bassin qui s\'affaisse ou qui monte.',
      'Amplitude partielle, poitrine loin du sol.',
    ],
  };

  static const _parCategorie = <String, List<String>>{
    'pectoraux': ['Omoplates relâchées : les serrer protège les épaules.', 'Amplitude réduite pour charger plus lourd.'],
    'dos': ['Tirer avec les bras plutôt qu\'avec les coudes.', 'Épaules qui remontent vers les oreilles.'],
    'epaules': ['Charge trop lourde qui force à tricher avec le dos.', 'Épaules haussées pendant le mouvement.'],
    'biceps': ['Élan du buste pour lancer la charge.', 'Coudes qui bougent pendant la montée.'],
    'triceps': ['Coudes qui s\'écartent.', 'Extension incomplète en fin de mouvement.'],
    'avantBras': ['Mouvement trop rapide, sans contrôle en descente.'],
    'jambes': ['Genoux qui rentrent vers l\'intérieur.', 'Amplitude trop courte.'],
    'ischios': ['Dos qui s\'arrondit.', 'Descente non contrôlée.'],
    'fessiers': ['Cambrer le bas du dos au lieu de contracter les fessiers.', 'Pas de pause en haut du mouvement.'],
    'mollets': ['Rebond en bas du mouvement.', 'Amplitude partielle, talons pas assez bas.'],
    'abdos': ['Tirer sur la nuque avec les mains.', 'Utiliser l\'élan plutôt que la contraction.', 'Bas du dos qui se creuse.'],
    'cardio': ['Partir trop vite et ne pas tenir l\'allure.', 'Négliger l\'échauffement.'],
    'completCorps': ['Sacrifier la technique quand la fatigue arrive.', 'Dos qui s\'arrondit sous la charge.'],
    'cou': ['Charge trop lourde ou mouvement brusque.'],
    'etirements': ['Forcer jusqu\'à la douleur.', 'Retenir sa respiration.', 'Donner des à-coups.'],
  };

  static const _parMateriel = <String, List<String>>{
    'barre': ['Prise asymétrique sur la barre.'],
    'halteres': ['Haltères qui dérivent : garder une trajectoire stable.'],
    'poulie': ['Laisser la charge remonter d\'un coup.'],
    'machine': ['Réglage du siège oublié : l\'axe doit être aligné avec l\'articulation.'],
    'kettlebell': ['Tirer avec les bras au lieu de pousser avec les hanches.'],
    'smith': ['Pieds mal placés par rapport au rail.'],
  };

  static const _general = [
    'Retenir sa respiration pendant tout l\'effort.',
    'Aller trop vite en phase de descente.',
  ];

  /// Mouvements dont le mot désigne aussi autre chose : le curl des
  /// ischios ou des poignets n'a pas les défauts du curl des biceps.
  static const _reserve = <String, Set<String>>{
    'curl': {'biceps'},
    'traction': {'dos', 'biceps'},
    'rowing': {'dos', 'biceps'},
    'pompe': {'pectoraux', 'triceps', 'epaules'},
  };

  static List<String> pour(Exercise e) {
    // Une espace devant : on reconnaît un mot entier ou son début
    // (« tractions »), jamais un morceau (« rétraction »).
    final nom = ' ${TextSearch.normalize('${e.nom} ${e.id.replaceAll('-', ' ')}')}';
    final out = <String>[];
    for (final entry in _parMouvement.entries) {
      final permis = _reserve[entry.key];
      if (permis != null && !permis.contains(e.categorie)) continue;
      if (nom.contains(' ${entry.key}')) {
        out.addAll(entry.value);
        break;
      }
    }
    if (out.isEmpty) out.addAll(_parCategorie[e.categorie] ?? const []);
    out.addAll(_parMateriel[e.equipement] ?? const []);
    if (out.length < 3) out.addAll(_general);
    return out.toSet().take(5).toList();
  }
}
