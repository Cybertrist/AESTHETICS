// Rapprochement des noms d'exercices du fichier avec le catalogue.
// Table de synonymes vérifiée d'abord, puis normalisation, synonymes FR et
// EN, familles de mouvement, matériel, similarité par mots puis par lettres,
// confirmation manuelle des cas ambigus.

import 'dart:math' as math;

import 'csv_table.dart';
import 'exercise_synonyms.dart';
import 'import_models.dart';

/// Ce que le rapprochement a besoin de connaître d'un exercice du catalogue.
class CatalogueEntry {
  const CatalogueEntry({
    required this.id,
    required this.nom,
    this.nomEn,
    this.alias = const [],
    this.equipement,
  });

  final String id;
  final String nom;
  final String? nomEn;
  final List<String> alias;
  final String? equipement;

  /// Depuis un objet de `assets/data/exercises.json`.
  factory CatalogueEntry.fromJson(Map<String, dynamic> j) => CatalogueEntry(
        id: '${j['id']}',
        nom: j['nom'] as String? ?? '',
        nomEn: j['nomEn'] as String?,
        alias: [for (final a in (j['alias'] as List? ?? const [])) '$a'],
        equipement: j['equipement'] as String?,
      );

  List<String> get tousLesNoms => [nom, ?nomEn, ...alias];
}

enum StatutRapprochement {
  /// Nom identique après normalisation.
  exact,

  /// Très proche et sans concurrent sérieux, ou connu de la table de
  /// synonymes : accepté sans question.
  automatique,

  /// Choisi ou confirmé par l'utilisateur.
  manuel,

  /// Un ou plusieurs candidats plausibles : à confirmer.
  ambigu,

  /// Rien d'assez proche : à choisir à la main ou à créer.
  inconnu,

  /// Exercice personnel à créer (choix de l'utilisateur, ou nom que la table
  /// de synonymes sait absent du catalogue).
  nouveau,
}

class Candidat {
  const Candidat(this.entree, this.score, this.nomCompare, {this.deTable = false});
  final CatalogueEntry entree;

  /// Similarité entre 0 et 1.
  final double score;

  /// Le nom du catalogue (FR, EN ou alias) qui a donné ce score.
  final String nomCompare;

  /// Vrai si le candidat vient de la table de synonymes : le score n'est
  /// alors pas une mesure de ressemblance.
  final bool deTable;
}

class Rapprochement {
  Rapprochement({
    required this.nomSource,
    required this.statut,
    this.candidats = const [],
    this.choisi,
    this.modele,
  });

  final String nomSource;
  StatutRapprochement statut;

  /// Meilleurs candidats, du plus proche au moins proche.
  final List<Candidat> candidats;

  /// Exercice retenu (exact, automatique ou manuel).
  CatalogueEntry? choisi;

  /// Exercice personnel conseillé par la table de synonymes quand le
  /// catalogue n'a pas d'équivalent exact.
  final ModelePerso? modele;

  /// Nombre de séries et de séances où le nom apparaît (rempli par l'analyse).
  int series = 0;
  int seances = 0;

  String? get exerciceId => choisi?.id;

  bool get aConfirmer =>
      statut == StatutRapprochement.ambigu || statut == StatutRapprochement.inconnu;

  double get meilleurScore => candidats.isEmpty ? 0 : candidats.first.score;

  /// Suggestion assez fiable pour être acceptée en lot : très proche du nom
  /// du fichier et nettement devant la suivante. Les voisins proposés par la
  /// table de synonymes demandent toujours un choix.
  bool get suggestionSure =>
      statut == StatutRapprochement.ambigu &&
      candidats.isNotEmpty &&
      !candidats.first.deTable &&
      candidats.first.score >= ExerciseMatcher.seuilSur &&
      (candidats.length < 2 ||
          candidats.first.score - candidats[1].score >= ExerciseMatcher.ecartSur);
}

/// Mots retirés avant comparaison.
const _motsVides = {
  'the', 'a', 'an', 'of', 'with', 'on', 'in', 'to', 'and', 'for', 'using',
  'de', 'du', 'des', 'la', 'le', 'les', 'l', 'd', 'au', 'aux', 'en', 'avec',
  'sur', 'et', 'un', 'une', 'par',
};

/// Expressions ramenées à une forme unique (appliquées avant le découpage).
const _expressions = <String, String>{
  // anglais
  'pull ups': 'pullup', 'pull up': 'pullup', 'chin ups': 'chinup', 'chin up': 'chinup',
  'push ups': 'pushup', 'push up': 'pushup', 'press ups': 'pushup', 'press up': 'pushup',
  'sit ups': 'situp', 'sit up': 'situp', 'pull downs': 'pulldown', 'pull down': 'pulldown',
  'lat pull': 'lat pulldown', 'step ups': 'stepup', 'step up': 'stepup',
  'dead lift': 'deadlift', 'skull crushers': 'skullcrusher', 'skull crusher': 'skullcrusher',
  'face pulls': 'facepull', 'face pull': 'facepull', 'good mornings': 'goodmorning',
  'good morning': 'goodmorning', 't bar': 'tbar', 'trap bar': 'trapbar', 'hex bar': 'trapbar',
  'e z': 'ez', 'ez bar': 'ez', 'ez curl bar': 'ez', 'ez barbell': 'ez', 'body weight': 'bodyweight',
  'military press': 'overhead press', 'shoulder press': 'overhead press',
  'rdl': 'romanian deadlift', 'ohp': 'overhead press', 'sldl': 'stiff leg deadlift',
  'stiff legged': 'stiff leg', 'flat bench': 'bench', 'hip thrusts': 'hip thrust',
  'smith machine': 'smith', 'rear delt': 'rear', 'rear deltoid': 'rear', 'pec deck': 'pec deck fly',
  'high pulley': 'cable', 'low pulley': 'cable',
  // français
  'souleve de terre': 'deadlift', 'souleves de terre': 'deadlift',
  'developpe couche': 'bench press', 'developpe militaire': 'overhead press',
  'developpe epaules': 'overhead press', 'developpe': 'press',
  'tirage vertical': 'lat pulldown', 'tirage horizontal': 'seated row',
  'tirage menton': 'upright row', 'rowing': 'row', 'tractions': 'pullup', 'traction': 'pullup',
  'pompes': 'pushup', 'pompe': 'pushup', 'fentes': 'lunge', 'fente': 'lunge',
  'elevations laterales': 'lateral raise', 'elevation laterale': 'lateral raise',
  'elevations frontales': 'front raise', 'elevation frontale': 'front raise',
  'oiseau': 'reverse fly', 'ecartes': 'fly', 'ecarte': 'fly', 'curl marteau': 'hammer curl',
  'presse a cuisses': 'leg press', 'presse a cuisse': 'leg press',
  'leg extension': 'leg extension', 'leg curl': 'leg curl', 'gainage': 'plank',
  'relevés de jambes': 'leg raise', 'releves de jambes': 'leg raise',
  'releves de genoux': 'knee raise', 'releve de genoux': 'knee raise',
  'extensions lombaires': 'back extension', 'extension lombaire': 'back extension',
  'mollets': 'calf raise', 'haussements d epaules': 'shrug', 'haussement d epaules': 'shrug',
  'barre au front': 'skullcrusher', 'squat bulgare': 'bulgarian split squat',
  'poulie haute': 'high cable', 'poulie basse': 'low cable', 'soulevé': 'deadlift',
};

/// Mots isolés ramenés à une forme unique.
const _mots = <String, String>{
  'db': 'dumbbell', 'dumbbells': 'dumbbell', 'dumbell': 'dumbbell', 'haltere': 'dumbbell',
  'halteres': 'dumbbell', 'bb': 'barbell', 'barre': 'barbell', 'kb': 'kettlebell',
  'kettlebells': 'kettlebell', 'lever': 'machine', 'guidee': 'machine', 'cables': 'cable',
  'poulie': 'cable', 'poulies': 'cable', 'pulley': 'cable', 'inclined': 'incline',
  'incline': 'incline', 'declined': 'decline', 'assis': 'seated', 'debout': 'standing',
  'couche': 'lying', 'flyes': 'fly', 'flye': 'fly', 'flys': 'fly', 'flies': 'fly',
  'butterfly': 'fly', 'crossover': 'fly', 'crunches': 'crunch',
  'presses': 'press', 'raises': 'raise', 'curls': 'curl', 'rows': 'row', 'dips': 'dip',
  'squats': 'squat', 'lunges': 'lunge', 'shrugs': 'shrug', 'deadlifts': 'deadlift',
  'extensions': 'extension', 'pullups': 'pullup', 'chinups': 'chinup', 'pushups': 'pushup',
  'pulldowns': 'pulldown', 'kickbacks': 'kickback', 'thrusts': 'thrust',
  'hyperextensions': 'hyperextension', 'walking': 'walk', 'marche': 'walk',
  'unilateral': 'single', 'unilaterale': 'single', 'one': 'single', 'arm': 'arm',
  'bras': 'arm', 'jambe': 'leg', 'jambes': 'leg', 'cuisses': 'leg', 'epaules': 'shoulder',
  'pectoraux': 'chest', 'poitrine': 'chest', 'dos': 'back', 'marteau': 'hammer',
  'tricep': 'triceps', 'bicep': 'biceps', 'poignet': 'wrist', 'poignets': 'wrist',
  'prise': 'grip', 'serree': 'close', 'large': 'wide', 'inverse': 'reverse',
  'elastique': 'band', 'bande': 'band', 'banded': 'band', 'assisted': 'assisted',
  'assistee': 'assisted', 'assistees': 'assisted', 'assiste': 'assisted', 'assistes': 'assisted',
  'weighted': 'weighted', 'lestee': 'weighted', 'leste': 'weighted', 'lestes': 'weighted',
  'lestees': 'weighted', 'suspender': 'suspension', 'trx': 'suspension',
  'pdc': 'bodyweight', 'kilo': 'kg', 'roumain': 'romanian', 'bulgare': 'bulgarian',
};

/// Mots qui désignent un matériel : deux matériels différents ne se
/// confondent jamais sans confirmation.
const _materiels = {
  'dumbbell', 'barbell', 'kettlebell', 'machine', 'cable', 'smith', 'band', 'ez',
  'trapbar', 'tbar', 'bodyweight', 'plate', 'suspension', 'landmine',
};

/// Matériel du catalogue (champ `equipement`) ramené aux mêmes mots.
const _materielDuChamp = <String, String>{
  'barre': 'barbell', 'halteres': 'dumbbell', 'smith': 'smith', 'machine': 'machine',
  'poulie': 'cable', 'poids du corps': 'bodyweight', 'disque': 'plate', 'elastique': 'band',
  'kettlebell': 'kettlebell', 'barre ez': 'ez', 'cardio': 'cardio',
};

/// Mots qui nomment le mouvement.
const _mouvements = {
  'row', 'press', 'fly', 'curl', 'pulldown', 'pushdown', 'pullup', 'chinup', 'dip', 'raise',
  'extension', 'hyperextension', 'squat', 'lunge', 'deadlift', 'shrug', 'crunch', 'situp',
  'plank', 'pushup', 'kickback', 'thrust', 'pullover', 'skullcrusher', 'facepull',
  'goodmorning', 'stepup', 'twist', 'bridge', 'rollout', 'carry', 'swing', 'clean', 'snatch',
  'abduction', 'adduction', 'rotation', 'stretch', 'walk',
};

/// Mots de position : ils pèsent peu, car des exercices sans rapport les
/// partagent (« seated »).
const _positions = {'seated', 'standing', 'lying', 'kneeling', 'bent', 'over'};

/// Mots presque vides de sens pour comparer deux exercices.
const _bruit = {
  'grip', 'bar', 'arm', 'two', 'hand', 'body', 'v', 'head', 'up', 'male', 'female', 'version',
  'degree', 'bench', 'total',
};

/// Parties du corps : le mouvement les sous-entend le plus souvent.
const _corps = {
  'biceps', 'triceps', 'chest', 'back', 'shoulder', 'lat', 'delt', 'abs', 'abdominal', 'glute',
};

/// Poids d'un mot dans la comparaison : le mouvement et le matériel comptent
/// plus que la position.
double _poidsMot(String m) {
  if (_mouvements.contains(m)) return 2;
  if (_materiels.contains(m)) return 1.5;
  if (_positions.contains(m)) return 0.4;
  if (_bruit.contains(m)) return 0.3;
  if (_corps.contains(m)) return 0.6;
  return 1;
}

bool _distinctif(String m) =>
    !_mouvements.contains(m) &&
    !_materiels.contains(m) &&
    !_positions.contains(m) &&
    !_bruit.contains(m) &&
    !_corps.contains(m) &&
    m != 'assisted' &&
    m != 'weighted';

/// Familles de mouvement d'un nom. « Leg curl » et curl des biceps ne sont
/// pas la même famille, « reverse fly » et « fly » non plus.
Set<String> _familles(Set<String> s) {
  bool a(String m) => s.contains(m);
  final r = <String>{};
  if (a('row')) r.add(a('upright') ? 'row:menton' : 'row');
  if (a('press')) {
    if (a('leg')) {
      r.add('press:jambes');
    } else if (a('calf')) {
      r.add('mollets');
    } else if (a('overhead') || a('shoulder') || a('arnold')) {
      r.add('press:epaules');
    } else if (a('bench') || a('chest') || a('floor') || a('incline') || a('decline')) {
      r.add('press:pectoraux');
    } else {
      r.add('press:haut');
    }
  }
  if (a('curl')) {
    if (a('leg') || a('nordic') || a('hamstring')) {
      r.add('curl:jambes');
    } else if (a('wrist')) {
      r.add('curl:poignets');
    } else {
      r.add('curl');
    }
  }
  if (a('extension') || a('hyperextension') || a('skullcrusher')) {
    if (a('leg')) {
      r.add('extension:jambes');
    } else if (a('back') || a('hyperextension') || a('lumbar')) {
      r.add('extension:dos');
    } else if (a('hip')) {
      r.add('extension:hanche');
    } else {
      r.add('extension:triceps');
    }
  }
  if (a('raise')) {
    if (a('calf')) {
      r.add('mollets');
    } else if (a('leg') || a('knee') || a('hip')) {
      r.add('raise:jambes');
    } else if (a('rear')) {
      r.add('fly:arriere');
    } else if (a('lateral')) {
      r.add('raise:lateral');
    } else if (a('front')) {
      r.add('raise:frontal');
    } else if (a('y')) {
      r.add('raise:y');
    } else {
      r.add('raise');
    }
  }
  if (a('fly')) r.add(a('reverse') || a('rear') ? 'fly:arriere' : 'fly');
  if (a('pulldown')) r.add(a('straight') ? 'pulldown:tendu' : 'pulldown');
  if (a('pullup') || a('chinup')) r.add('pullup');
  if (a('crunch') || a('situp')) r.add('crunch');
  if (a('kickback')) r.add(a('glute') || a('hip') ? 'kickback:fessier' : 'kickback');
  for (final m in const [
    'pushdown', 'dip', 'squat', 'lunge', 'deadlift', 'shrug', 'plank', 'pushup', 'thrust',
    'pullover', 'facepull', 'goodmorning', 'stepup', 'twist', 'bridge', 'rollout', 'carry',
    'swing', 'clean', 'snatch', 'abduction', 'adduction', 'rotation', 'stretch',
  ]) {
    if (a(m)) r.add(m);
  }
  // « Walking Lunge » est une fente, pas une marche.
  if (a('walk') && r.isEmpty) r.add('walk');
  return r;
}

bool _famillesCompatibles(Set<String> a, Set<String> b) {
  for (final x in a) {
    for (final y in b) {
      if (x == y) return true;
      if (x.startsWith('press:') && y.startsWith('press:')) {
        final autre = x == 'press:haut' ? y : (y == 'press:haut' ? x : null);
        if (autre == 'press:epaules' || autre == 'press:pectoraux') return true;
      }
      if (x.startsWith('raise') && y.startsWith('raise') && (x == 'raise' || y == 'raise')) {
        return true;
      }
    }
  }
  return false;
}

/// Mots conservés tels quels malgré leur « s » final.
const _garderS = {
  'biceps', 'triceps', 'abs', 'glutes', 'press', 'cross', 'lats', 'hips', 'pectoraux',
  'dos', 'bras', 'assis', 'gainage',
};

/// Nom ramené à des mots canoniques (minuscules, sans accents ni ponctuation).
List<String> motsCanoniques(String nom) {
  var t = sansAccents(nom.toLowerCase());
  t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  t = ' $t ';
  for (final e in _expressionsTriees) {
    t = t.replaceAll(' ${e.key} ', ' ${e.value} ');
  }
  final mots = <String>[];
  for (var m in t.split(' ')) {
    if (m.isEmpty || _motsVides.contains(m)) continue;
    m = _mots[m] ?? m;
    if (m.length > 4 && m.endsWith('s') && !m.endsWith('ss') && !_garderS.contains(m)) {
      m = m.substring(0, m.length - 1);
    }
    // une expression a pu produire plusieurs mots
    mots.addAll(m.split(' '));
  }
  return mots;
}

final _expressionsTriees = (_expressions.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length)))
    .map((e) => MapEntry(sansAccents(e.key), e.value))
    .toList();

/// Clé de mémoire des choix : nom normalisé.
String cleNom(String nom) => motsCanoniques(nom).join(' ');

/// Clé insensible à l'ordre des mots (table de synonymes).
String _cleTriee(String nom) => (motsCanoniques(nom)..sort()).join(' ');

class _Nom {
  _Nom(this.entree, this.texte)
      : mots = motsCanoniques(texte),
        joint = motsCanoniques(texte).join(' ');
  final CatalogueEntry entree;
  final String texte;
  final List<String> mots;
  final String joint;
  late final Set<String> ensemble = mots.toSet();
  late final String cleTriee = (mots.toList()..sort()).join(' ');
  late final Set<String> familles = _familles(ensemble);
  late final Set<String> distinctifs = ensemble.where(_distinctif).toSet();
  late final double poids = ensemble.fold(0.0, (t, m) => t + _poidsMot(m));

  /// Matériel cité, sans les mots qu'un matériel plus précis rend faux :
  /// une machine Smith n'est pas « une machine », une barre EZ pas « une barre ».
  late final Set<String> materiels = () {
    final m = ensemble.intersection(_materiels);
    if (m.contains('smith')) m.remove('machine');
    if (m.contains('ez') || m.contains('trapbar') || m.contains('tbar') || m.contains('landmine')) {
      m.remove('barbell');
    }
    return m;
  }();
}

/// Ce que tous les noms d'un exercice disent de lui.
class _Fiche {
  final familles = <String>{};
  String? materiel;
}

class ExerciseMatcher {
  /// [synonymes] : table consultée avant tout calcul (vide pour s'en passer).
  ExerciseMatcher(List<CatalogueEntry> catalogue, {List<SynonymeExercice> synonymes = synonymesExercices}) {
    for (final e in catalogue) {
      final fiche = _fiches.putIfAbsent(e.id, _Fiche.new)
        ..materiel = _materielDuChamp[sansAccents((e.equipement ?? '').toLowerCase().trim())];
      for (final n in e.tousLesNoms) {
        if (n.trim().isEmpty) continue;
        final nom = _Nom(e, n);
        if (nom.mots.isEmpty) continue;
        _noms.add(nom);
        _exacts.putIfAbsent(nom.joint, () => nom);
        _tries.putIfAbsent(nom.cleTriee, () => nom);
        fiche.familles.addAll(nom.familles);
      }
      _parId[e.id] = e;
    }
    for (final s in synonymes) {
      for (final n in s.noms) {
        _table.putIfAbsent(_cleTriee(n), () => s);
      }
    }
  }

  final _noms = <_Nom>[];
  final _exacts = <String, _Nom>{};
  final _tries = <String, _Nom>{};
  final _parId = <String, CatalogueEntry>{};
  final _fiches = <String, _Fiche>{};
  final _table = <String, SynonymeExercice>{};

  /// Seuil au-dessus duquel un candidat unique est accepté sans question.
  static const seuilAuto = 0.9;

  /// Écart minimal avec le deuxième candidat pour accepter sans question.
  static const ecartAuto = 0.05;

  /// Seuil d'une suggestion sûre, celle que « Tout accepter » prend.
  static const seuilSur = 0.85;

  /// Écart minimal avec la suggestion suivante pour qu'elle soit sûre.
  static const ecartSur = 0.05;

  /// Seuil de confiance sous lequel on ne propose rien : le nom est « à choisir ».
  static const seuilCandidat = 0.6;

  CatalogueEntry? parId(String id) => _parId[id];

  /// Entrée de la table de synonymes pour ce nom, s'il y en a une.
  SynonymeExercice? synonyme(String nomSource) => _table[_cleTriee(nomSource)];

  /// Rapproche un nom. [memoire] associe une clé de nom ([cleNom]) à un
  /// identifiant du catalogue déjà choisi ; la valeur vide veut dire
  /// « exercice personnel ».
  Rapprochement rapprocher(String nomSource, {Map<String, String> memoire = const {}}) {
    final cle = cleNom(nomSource);
    final syn = cle.isEmpty ? null : synonyme(nomSource);
    final choix = memoire[cle];
    if (choix != null) {
      if (choix.isEmpty) {
        return Rapprochement(
            nomSource: nomSource, statut: StatutRapprochement.nouveau, modele: syn?.perso);
      }
      final e = _parId[choix];
      if (e != null) {
        return Rapprochement(
          nomSource: nomSource,
          statut: StatutRapprochement.manuel,
          candidats: [Candidat(e, 1, e.nom)],
          choisi: e,
          modele: syn?.perso,
        );
      }
    }
    if (cle.isEmpty) {
      return Rapprochement(nomSource: nomSource, statut: StatutRapprochement.inconnu);
    }

    // 1. Table de synonymes : correspondance certaine, ou voisins à confirmer.
    if (syn != null) {
      final sur = syn.sur == null ? null : _parId[syn.sur];
      if (sur != null) {
        return Rapprochement(
          nomSource: nomSource,
          statut: StatutRapprochement.automatique,
          candidats: [Candidat(sur, 1, sur.nom, deTable: true)],
          choisi: sur,
          modele: syn.perso,
        );
      }
      final proches = [
        for (final id in syn.proches)
          if (_parId[id] != null) _parId[id]!,
      ];
      if (syn.sur == null && proches.isNotEmpty) {
        return Rapprochement(
          nomSource: nomSource,
          statut: StatutRapprochement.ambigu,
          candidats: [
            for (var i = 0; i < proches.length; i++)
              Candidat(proches[i], math.max(seuilCandidat, 0.8 - 0.05 * i), proches[i].nom, deTable: true),
          ],
          modele: syn.perso,
        );
      }
    }

    // 2. Nom identique dans le catalogue.
    final exact = _exacts[cle];
    if (exact != null) {
      return Rapprochement(
        nomSource: nomSource,
        statut: StatutRapprochement.exact,
        candidats: [Candidat(exact.entree, 1, exact.texte)],
        choisi: exact.entree,
      );
    }

    // 3. La table sait que le catalogue n'a pas cet exercice.
    if (syn != null && syn.ids.isEmpty && syn.perso != null) {
      return Rapprochement(
          nomSource: nomSource, statut: StatutRapprochement.nouveau, modele: syn.perso);
    }

    // 4. Ressemblance.
    final source = _Nom(const CatalogueEntry(id: '', nom: ''), nomSource);
    final candidats = _candidats(source, plancher: seuilCandidat);
    if (candidats.isEmpty) {
      return Rapprochement(
          nomSource: nomSource, statut: StatutRapprochement.inconnu, modele: syn?.perso);
    }
    final premier = candidats.first;
    final second = candidats.length > 1 ? candidats[1].score : 0.0;
    final auto = premier.score >= seuilAuto && premier.score - second >= ecartAuto;
    return Rapprochement(
      nomSource: nomSource,
      statut: auto ? StatutRapprochement.automatique : StatutRapprochement.ambigu,
      candidats: candidats,
      choisi: auto ? premier.entree : null,
      modele: syn?.perso,
    );
  }

  /// Recherche libre pour l'écran de choix manuel.
  List<Candidat> rechercher(String texte, {int max = 20}) {
    final source = _Nom(const CatalogueEntry(id: '', nom: ''), texte);
    if (source.mots.isEmpty) return const [];
    return _candidats(source, max: max, plancher: 0.2, strict: false);
  }

  /// [strict] écarte les exercices d'une autre famille de mouvement : un
  /// rowing n'est jamais proposé pour un écarté.
  List<Candidat> _candidats(_Nom source, {int max = 5, double plancher = 0.3, bool strict = true}) {
    // Premier tri rapide par mots communs, puis score complet sur les meilleurs.
    final tri = _tries[source.cleTriee];
    final prefiltre = <(_Nom, double)>[];
    for (final n in _noms) {
      if (strict && !_memeFamille(source, n)) continue;
      final d = _dice(source.ensemble, n.ensemble);
      if (d > 0) prefiltre.add((n, d));
    }
    prefiltre.sort((a, b) => b.$2.compareTo(a.$2));

    final meilleurs = <String, Candidat>{};
    void noter(_Nom n, double s) {
      final ancien = meilleurs[n.entree.id];
      if (ancien == null || s > ancien.score) {
        meilleurs[n.entree.id] = Candidat(n.entree, s, n.texte);
      }
    }

    if (tri != null) noter(tri, 0.97);
    for (final (n, _) in prefiltre.take(60)) {
      noter(n, _score(source, n, materielFiche: _fiches[n.entree.id]?.materiel));
    }
    final liste = meilleurs.values.where((c) => c.score >= plancher).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return liste.take(max).toList();
  }

  /// Faux si le nom du fichier et l'exercice nomment deux mouvements
  /// différents (rowing contre écarté, curl contre extension).
  bool _memeFamille(_Nom source, _Nom n) {
    if (source.familles.isEmpty) return true;
    if (n.familles.isNotEmpty) return _famillesCompatibles(source.familles, n.familles);
    final fiche = _fiches[n.entree.id];
    if (fiche == null || fiche.familles.isEmpty) return true;
    return _famillesCompatibles(source.familles, fiche.familles);
  }

  /// Similarité entre deux noms, de 0 à 1.
  static double scoreNoms(String a, String b) {
    const vide = CatalogueEntry(id: '', nom: '');
    return _score(_Nom(vide, a), _Nom(vide, b));
  }

  static double _score(_Nom a, _Nom b, {String? materielFiche}) {
    if (a.joint == b.joint) return 1;
    if (a.cleTriee == b.cleTriee) return 0.97;
    final (mots, communs) = _dicePondere(a, b);
    final lettres = 1 - _levenshtein(a.joint, b.joint) / math.max(a.joint.length, b.joint.length);
    var s = 0.8 * mots + 0.2 * lettres;

    // Deux mouvements différents : très loin, quel que soit le reste.
    if (a.familles.isNotEmpty && b.familles.isNotEmpty && !_famillesCompatibles(a.familles, b.familles)) {
      s *= 0.4;
    }

    // Matériel : celui du nom, sinon celui de la fiche du catalogue.
    final ma = a.materiels;
    final mb = b.materiels.isNotEmpty ? b.materiels : {?materielFiche};
    final cardio = materielFiche == 'cardio' && a.familles.isNotEmpty && !a.familles.contains('walk');
    if (cardio || (ma.isNotEmpty && mb.isNotEmpty && ma.intersection(mb).isEmpty)) {
      // Un rowing à la machine n'est pas le rameur, une barre n'est pas un haltère.
      s *= 0.6;
    } else if (ma.isEmpty != b.materiels.isEmpty) {
      s *= 0.93;
    }

    // Assisté ou lesté d'un seul côté : ce n'est pas le même exercice.
    if (a.ensemble.contains('assisted') != b.ensemble.contains('assisted')) s *= 0.75;
    if (a.ensemble.contains('weighted') != b.ensemble.contains('weighted')) s *= 0.85;

    // Chacun a un mot propre que l'autre n'a pas (« boat » contre « cat ») :
    // partager le mouvement ne suffit pas.
    final resteA = a.distinctifs.difference(communs);
    final resteB = b.distinctifs.difference(communs);
    final aucunCommun = a.distinctifs.intersection(communs).isEmpty;
    if (resteA.isNotEmpty && resteB.isNotEmpty) {
      s *= aucunCommun ? 0.7 : 0.85;
    } else if (resteA.isNotEmpty && aucunCommun && !communs.containsAll(b.ensemble)) {
      s *= 0.8;
    }
    // Un mot propre sans équivalent en face : jamais une suggestion sûre.
    if (resteA.isNotEmpty || resteB.isNotEmpty) s = math.min(s, seuilSur - 0.01);
    return s.clamp(0, 0.96).toDouble();
  }
}

double _dice(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final commun = a.intersection(b).length;
  return 2 * commun / (a.length + b.length);
}

/// Dice sur les mots, pondéré (mouvement et matériel d'abord), en tolérant
/// une faute de frappe dans les mots longs. Renvoie aussi les mots communs
/// (dans leurs deux écritures).
(double, Set<String>) _dicePondere(_Nom a, _Nom b) {
  if (a.ensemble.isEmpty || b.ensemble.isEmpty) return (0, const {});
  final restants = b.ensemble.toList();
  final communs = <String>{};
  var commun = 0.0;
  for (final m in a.ensemble) {
    var trouve = -1;
    var facteur = 0.0;
    for (var i = 0; i < restants.length; i++) {
      final r = restants[i];
      if (r == m) {
        trouve = i;
        facteur = 1;
        break;
      }
      if (m.length >= 5 && r.length >= 5 && _levenshtein(m, r) <= 1) {
        trouve = i;
        facteur = 0.85;
      }
    }
    if (trouve >= 0) {
      final r = restants.removeAt(trouve);
      commun += facteur * (_poidsMot(m) + _poidsMot(r));
      communs
        ..add(m)
        ..add(r);
    }
  }
  return (commun / (a.poids + b.poids), communs);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prec = List<int>.generate(b.length + 1, (i) => i);
  var cour = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cour[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cout = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cour[j] = math.min(math.min(cour[j - 1] + 1, prec[j] + 1), prec[j - 1] + cout);
    }
    final t = prec;
    prec = cour;
    cour = t;
  }
  return prec[b.length];
}

/// Rapproche tous les exercices des séances et renseigne `exerciceId`.
/// Renvoie un rapprochement par nom distinct (clé : [cleNom]).
Map<String, Rapprochement> rapprocherSeances(
  List<ImportedSession> seances,
  ExerciseMatcher matcher, {
  Map<String, String> memoire = const {},
}) {
  final res = <String, Rapprochement>{};
  for (final s in seances) {
    final vus = <String>{};
    for (final e in s.exercices) {
      final cle = cleNom(e.nomSource);
      final r = res.putIfAbsent(cle, () => matcher.rapprocher(e.nomSource, memoire: memoire));
      r.series += e.series.length;
      if (vus.add(cle)) r.seances++;
      e.exerciceId = r.exerciceId;
    }
  }
  return res;
}
