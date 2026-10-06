import 'dart:ui' show Color;

import '../ui/objet_3d.dart' show Objets3D;

/// Le poids soulevé comparé à un objet : carte de fin de séance, carte
/// « équivalent » du partage et écrans du bilan du mois.
class Equivalent {
  const Equivalent({
    required this.asset,
    required this.nom,
    required this.etiquette,
    required this.phrase,
    required this.couleur,
    required this.accent,
    this.fort = '',
    this.multiple = 0,
    this.pourcentage = false,
  });

  /// Image de l'objet (voir `Objets3D`).
  final String asset;

  /// Nom de l'objet au singulier, sans article : « chat », « baleine à bosse ».
  final String nom;

  /// Texte de la pastille blanche : « × 80 », « × 2,5 », « 29 % ».
  final String etiquette;

  /// Phrase complète, sur deux lignes (séparées par un saut de ligne).
  final String phrase;

  /// Couleur du haut du dégradé (qui descend vers le noir).
  final Color couleur;

  /// Couleur claire : halo de l'objet et passage mis en avant de la phrase.
  final Color accent;

  /// Passage de [phrase] à écrire dans la couleur [accent] (« 80 chats »).
  /// Vide si rien n'est à mettre en avant.
  final String fort;

  /// Nombre d'objets (ou le pourcentage si [pourcentage]).
  final double multiple;

  /// L'étiquette est un pourcentage de l'objet, pas un multiple.
  final bool pourcentage;

  /// La phrase découpée autour de [fort] : avant, mis en avant, après.
  (String, String, String) get morceaux {
    final i = fort.isEmpty ? -1 : phrase.indexOf(fort);
    if (i < 0) return (phrase, '', '');
    return (phrase.substring(0, i), fort, phrase.substring(i + fort.length));
  }

  @override
  String toString() => 'Equivalent($nom, $etiquette)';
}

/// Un objet de la table : son poids, son accord et ses phrases.
///
/// Dans les phrases, `{n}` est remplacé par le nombre et le nom accordé
/// (« 80 chats »), `{p}` par le pourcentage ; les astérisques encadrent le
/// passage mis en avant.
class ObjetEquivalent {
  const ObjetEquivalent({
    required this.asset,
    required this.kg,
    required this.nom,
    required this.pluriel,
    required this.couleur,
    required this.accent,
    required this.un,
    required this.plusieurs,
    this.feminin = false,
    this.absurde = false,
    this.pourcent = false,
    this.mois = 'C\'est comme soulever\n*{n}* !',
    this.nombreux = const [],
    this.moisNombreux,
  });

  final String asset;

  /// Poids de référence d'un exemplaire.
  final double kg;
  final String nom;
  final String pluriel;
  final bool feminin;
  final int couleur;
  final int accent;

  /// Phrases pour un seul exemplaire (le passage mis en avant y est écrit en
  /// toutes lettres : « Un tracteur »).
  final List<String> un;

  /// Phrases pour plusieurs exemplaires.
  final List<String> plusieurs;

  /// Objet minuscule (burger, baguette) : le multiple est énorme exprès.
  final bool absurde;

  /// Objet géant, exprimé en pourcentage tant qu'on n'en soulève pas un.
  final bool pourcent;

  /// Phrase du bilan du mois.
  final String mois;

  /// Phrases réservées aux grands nombres (un entier, trois au moins) :
  /// « un troupeau de 95 vaches » ne se dit ni d'une vache ni de 1,5.
  final List<String> nombreux;

  /// Phrase du bilan du mois pour un grand nombre ; à défaut, [mois].
  final String? moisNombreux;
}

/// Phrases neutres, pour un multiple à virgule sous 2 (« 1,6 avion de ligne »),
/// où les accords des phrases propres à l'objet ne tiennent plus.
const _neutres = [
  'C\'est comme soulever\n*{n}* !',
  '*{n}*, à la virgule près.\nOn a vérifié.',
];

/// La table, du plus léger au plus lourd. Couleurs propres à ces cartes
/// (dégradé de la couleur vers le noir), reprises de la maquette.
const List<ObjetEquivalent> objetsEquivalents = [
  ObjetEquivalent(
    asset: Objets3D.burger, kg: 0.25, nom: 'burger', pluriel: 'burgers', absurde: true,
    couleur: 0xFF7A1F2B, accent: 0xFFFFB3A8,
    un: ['*Un burger*, un seul.\nL\'échauffement, sans doute.'],
    plusieurs: [
      'Soit *{n}*.\nSans les frites.',
      '*{n}* soulevés.\nLa sauce n\'est pas comptée.',
      '*{n}*, un par un.\nLe cuisinier a rendu son tablier.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.baguette, kg: 0.25, nom: 'baguette', pluriel: 'baguettes', feminin: true, absurde: true,
    couleur: 0xFF7A4A1E, accent: 0xFFFFE2A8,
    un: ['*Une baguette*, une seule.\nPas trop cuite.'],
    plusieurs: [
      '*{n}* soulevées.\nLe boulanger veut te parler.',
      'Soit *{n}*.\nPas trop cuites, s\'il te plaît.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.chat, kg: 4, nom: 'chat', pluriel: 'chats',
    couleur: 0xFF7A4A1E, accent: 0xFFFFD9A8,
    un: ['*Un chat*, un seul.\nIl t\'a regardé faire, sans plus.'],
    plusieurs: [
      'Tu as soulevé *{n}*.\nAucun n\'était d\'accord.',
      '*{n}* portés à bout de bras.\nIls préféraient le canapé.',
      '*{n}*, tous vexés.\nIls s\'en souviendront.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.toilettes, kg: 30, nom: 'toilettes', pluriel: 'toilettes', feminin: true,
    couleur: 0xFF1F5D7A, accent: 0xFF9FE3FF,
    un: ['*Des toilettes* entières.\nPersonne ne sait pourquoi.'],
    plusieurs: [
      '*{n}* soulevées.\nPersonne ne sait pourquoi.',
      '*{n}*, lunette comprise.\nLe plombier est impressionné.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.canape, kg: 50, nom: 'canapé', pluriel: 'canapés',
    couleur: 0xFF4A3A78, accent: 0xFFC9B6FF,
    un: ['*Un canapé* soulevé.\nTu ne t\'es même pas assis dessus.'],
    plusieurs: [
      '*{n}* soulevés.\nTu ne t\'es assis sur aucun.',
      '*{n}*, coussins compris.\nLa télécommande reste introuvable.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.baignoire, kg: 150, nom: 'baignoire', pluriel: 'baignoires', feminin: true,
    couleur: 0xFF12406B, accent: 0xFF8FD3FF,
    un: ['*Une baignoire* en fonte.\nVide, on n\'est pas des bêtes.'],
    plusieurs: [
      '*{n}* en fonte.\nVides, on n\'est pas des bêtes.',
      '*{n}* soulevées.\nLe canard en plastique a survécu.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.gorille, kg: 160, nom: 'gorille', pluriel: 'gorilles',
    couleur: 0xFF3A3F4A, accent: 0xFFD6DDE8,
    un: ['*Un gorille* adulte.\nIl a préféré ne rien dire.'],
    plusieurs: [
      '*{n}* soulevés.\nIls ont trouvé ça moyen.',
      '*{n}* à bout de bras.\nAucun n\'a applaudi.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.moto, kg: 200, nom: 'moto', pluriel: 'motos', feminin: true,
    couleur: 0xFF5A1A1A, accent: 0xFFFF9A8A,
    un: ['*Une moto* entière.\nBéquille comprise.'],
    plusieurs: [
      '*{n}* soulevées.\nSans en démarrer une seule.',
      '*{n}*, plein fait.\nLe casque reste obligatoire.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.cheval, kg: 500, nom: 'cheval', pluriel: 'chevaux',
    couleur: 0xFF5A3A1C, accent: 0xFFF0C890,
    un: ['*Un cheval* entier.\nD\'habitude, c\'est lui qui porte.'],
    plusieurs: [
      '*{n}* soulevés.\nD\'habitude, ce sont eux qui portent.',
      '*{n}*, sans la selle.\nAucun n\'a henni.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.vache, kg: 700, nom: 'vache', pluriel: 'vaches', feminin: true,
    couleur: 0xFF2C6B34, accent: 0xFFD9FF7A,
    un: ['*Une vache* entière.\nElle a continué de brouter.'],
    plusieurs: [
      '*{n}* soulevées.\nLe lait a tourné.',
    ],
    nombreux: ['Un troupeau de *{n}*.\nElles ont regardé passer la barre.'],
    moisNombreux: 'C\'est comme soulever\nun troupeau de *{n}* !',
  ),
  ObjetEquivalent(
    asset: Objets3D.requin, kg: 1000, nom: 'requin', pluriel: 'requins',
    couleur: 0xFF0F3D5C, accent: 0xFF8FD3FF,
    un: ['*Un requin* blanc.\nIl n\'a pas souri.'],
    plusieurs: [
      '*{n}* soulevés.\nPar la queue, c\'est plus sûr.',
      '*{n}*, dents comprises.\nLa plage est rassurée.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.girafe, kg: 1200, nom: 'girafe', pluriel: 'girafes', feminin: true,
    couleur: 0xFF7A5A0C, accent: 0xFFFFD84D,
    un: ['*Une girafe* adulte.\nElle te regarde toujours de haut.'],
    plusieurs: [
      '*{n}* soulevées.\nLe plus dur, c\'est le cou.',
      '*{n}*, cous compris.\nElles te regardent toujours de haut.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.tracteur, kg: 3600, nom: 'tracteur', pluriel: 'tracteurs',
    couleur: 0xFF2C6B34, accent: 0xFFD9FF7A,
    un: ['*Un tracteur* entier.\nLe fermier te cherche encore.'],
    plusieurs: [
      '*{n}* soulevés.\nLe fermier te cherche encore.',
      '*{n}*, remorques non comprises.\nTout le village en parle.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.soucoupe, kg: 5000, nom: 'soucoupe volante', pluriel: 'soucoupes volantes', feminin: true,
    couleur: 0xFF1B1650, accent: 0xFFB6A8FF,
    un: ['*Une soucoupe volante*.\nPoids estimé, source : aucune.'],
    plusieurs: [
      '*{n}*.\nPoids estimé, source : aucune.',
      '*{n}*.\nLes pilotes demandent à rentrer.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.mammouth, kg: 6000, nom: 'mammouth', pluriel: 'mammouths',
    couleur: 0xFF6B3A14, accent: 0xFFFFCF99,
    un: ['*Un mammouth* laineux.\nIl n\'en reste plus, tu l\'as pris.'],
    plusieurs: [
      '*{n}* laineux.\nIl n\'en reste plus, tu les as pris.',
      '*{n}* soulevés.\nLa préhistoire te remercie.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.elephant, kg: 6000, nom: 'éléphant', pluriel: 'éléphants',
    couleur: 0xFF4A3A78, accent: 0xFFC9B6FF,
    un: ['*Un éléphant* adulte.\nIl s\'en souviendra.'],
    plusieurs: [
      '*{n}* soulevés.\nIls s\'en souviendront.',
      '*{n}*, trompes comprises.\nLa savane est sous le choc.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.tRex, kg: 8000, nom: 'tyrannosaure', pluriel: 'tyrannosaures',
    couleur: 0xFF1F5D2C, accent: 0xFFB9F27A,
    un: ['*Un tyrannosaure* entier.\nSes petits bras n\'ont pas aidé.'],
    plusieurs: [
      '*{n}* soulevés.\nLeurs petits bras n\'ont pas aidé.',
      '*{n}*.\nIls ont arrêté de rugir.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.bus, kg: 11000, nom: 'bus', pluriel: 'bus',
    couleur: 0xFF7A5A0C, accent: 0xFFFFD84D,
    un: ['*Un bus* entier.\nPassagers non compris.'],
    plusieurs: [
      '*{n}* soulevés.\nTerminus, tout le monde descend.',
      '*{n}*, passagers non compris.\nLe chauffeur a klaxonné.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.moai, kg: 11000, nom: 'statue de l\'île de Pâques', pluriel: 'statues de l\'île de Pâques', feminin: true,
    couleur: 0xFF3A3F4A, accent: 0xFFD6DDE8,
    un: ['*Une statue de l\'île de Pâques*.\nElle n\'a pas bronché.'],
    plusieurs: [
      '*{n}*.\nElles n\'ont pas bronché.',
      '*{n}*.\nToujours aussi peu bavardes.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.camionPompiers, kg: 14000, nom: 'camion de pompiers', pluriel: 'camions de pompiers',
    couleur: 0xFF8A1F1F, accent: 0xFFFFB199,
    un: ['*Un camion de pompiers*.\nÉchelle et sirène comprises.'],
    plusieurs: [
      '*{n}*.\nÉchelles et sirènes comprises.',
      '*{n}*.\nLa caserne te cherche.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.sauropode, kg: 15000, nom: 'diplodocus', pluriel: 'diplodocus',
    couleur: 0xFF2A5A4A, accent: 0xFFA8F0C8,
    un: ['*Un diplodocus* adulte.\nDe la tête à la queue.'],
    plusieurs: [
      '*{n}* soulevés.\nIl a fallu pousser les murs.',
      '*{n}*, de la tête à la queue.\nLa salle était trop petite.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.fusee, kg: 26000, nom: 'fusée', pluriel: 'fusées', feminin: true,
    couleur: 0xFF1B1650, accent: 0xFFFFB02E,
    un: ['*Une fusée* à vide.\nDécollage réussi.'],
    plusieurs: [
      '*{n}* à vide.\nDécollage réussi.',
      '*{n}* à vide.\nLa tour de contrôle n\'a rien compris.',
    ],
    mois: 'C\'est comme soulever\n*{n}* à vide !',
  ),
  ObjetEquivalent(
    asset: Objets3D.baleine, kg: 30000, nom: 'baleine à bosse', pluriel: 'baleines à bosse', feminin: true,
    couleur: 0xFF12406B, accent: 0xFF6FD0FF,
    un: ['*Une baleine à bosse*.\nElle a apprécié la balade.'],
    plusieurs: [
      '*{n}*.\nElles chantent encore.',
      '*{n}*.\nL\'océan a baissé d\'un cran.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.avion, kg: 41000, nom: 'avion de ligne', pluriel: 'avions de ligne',
    couleur: 0xFF1F5D7A, accent: 0xFF9FE3FF,
    un: ['*Un avion de ligne*.\nSans les bagages.'],
    plusieurs: [
      '*{n}*.\nSans les bagages.',
      '*{n}*.\nMerci d\'attacher ta ceinture.',
    ],
  ),
  ObjetEquivalent(
    asset: Objets3D.statueLiberte, kg: 225000, nom: 'statue de la Liberté', pluriel: 'statues de la Liberté', feminin: true,
    pourcent: true,
    couleur: 0xFF0F5A52, accent: 0xFF7FF0D8,
    un: ['*La statue de la Liberté*.\nEntière, flambeau compris.'],
    plusieurs: [
      '*{n}*.\nNew York commence à s\'inquiéter.',
    ],
  ),
];

/// Phrases en pourcentage (statue de la Liberté).
const _pourcent = [
  'Tu as soulevé *{p} %*\nde la statue de la Liberté !',
  '*{p} %* de la statue de la Liberté.\nLe flambeau, ce sera pour la prochaine.',
];

/// Nombre à la française : milliers séparés par une espace insécable, au
/// plus une décimale après la virgule.
String _nombre(double v, {bool decimale = false}) {
  final entier = decimale ? v.floor() : v.round();
  final s = entier.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  if (decimale) {
    final d = ((v - entier) * 10).round();
    if (d > 0) b.write(',$d');
  }
  return b.toString();
}

/// Un multiple tel qu'il sera affiché.
class _Multiple {
  const _Multiple(this.valeur, this.decimale, this.erreur);

  /// Valeur affichée (déjà arrondie).
  final double valeur;
  final bool decimale;

  /// Écart relatif entre la valeur affichée et le vrai rapport.
  final double erreur;
}

/// Arrondit [r] : un entier quand il ne trahit pas le rapport (8 % d'écart au
/// plus), sinon une décimale sous 10.
_Multiple _arrondir(double r) {
  final e = r.roundToDouble();
  final erreurEntier = e <= 0 ? 1.0 : (e - r).abs() / r;
  if (erreurEntier <= 0.08 || r >= 10) return _Multiple(e, false, erreurEntier);
  final d = (r * 10).roundToDouble() / 10;
  if (d == d.roundToDouble()) return _Multiple(d, false, (d - r).abs() / r);
  return _Multiple(d, true, (d - r).abs() / r);
}

Equivalent _composer(ObjetEquivalent o, String gabarit, {String n = '', String p = '', required String etiquette, required double multiple, bool pourcentage = false}) {
  final texte = gabarit.replaceAll('{n}', n).replaceAll('{p}', p);
  final a = texte.indexOf('*');
  final b = a < 0 ? -1 : texte.indexOf('*', a + 1);
  final fort = b < 0 ? '' : texte.substring(a + 1, b);
  return Equivalent(
    asset: o.asset,
    nom: o.nom,
    etiquette: etiquette,
    phrase: texte.replaceAll('*', ''),
    fort: fort,
    couleur: Color(o.couleur),
    accent: Color(o.accent),
    multiple: multiple,
    pourcentage: pourcentage,
  );
}

/// L'objet seul avec son article, en minuscule : « un tracteur », « des
/// toilettes », « la statue de la Liberté » (le passage fort de sa phrase).
String _avecArticle(ObjetEquivalent o) {
  final t = o.un.first;
  final a = t.indexOf('*');
  final b = a < 0 ? -1 : t.indexOf('*', a + 1);
  if (b < 0) return '${o.feminin ? 'une' : 'un'} ${o.nom}';
  final fort = t.substring(a + 1, b);
  return fort[0].toLowerCase() + fort.substring(1);
}

Equivalent _enMultiple(ObjetEquivalent o, _Multiple m, int graine, bool mois) {
  final un = !m.decimale && m.valeur == 1;
  final chiffre = _nombre(m.valeur, decimale: m.decimale);
  final n = '$chiffre ${m.valeur >= 2 ? o.pluriel : o.nom}';
  final etiquette = '× $chiffre';
  final nombreux = !m.decimale && m.valeur >= 3;
  if (mois) {
    // Un seul : l'article de la phrase propre à l'objet (« des toilettes »,
    // « la statue de la Liberté »), jamais « une toilettes ».
    return _composer(
      o,
      nombreux ? (o.moisNombreux ?? o.mois) : o.mois,
      n: un ? _avecArticle(o) : n,
      etiquette: etiquette,
      multiple: m.valeur,
    );
  }
  final List<String> choix;
  if (un) {
    choix = o.un;
  } else if (m.valeur < 2) {
    choix = _neutres;
  } else {
    choix = nombreux ? [...o.nombreux, ...o.plusieurs] : o.plusieurs;
  }
  return _composer(o, choix[graine % choix.length], n: n, etiquette: etiquette, multiple: m.valeur);
}

/// L'objet qui raconte [kg] soulevés.
///
/// Retient les objets dont le multiple reste lisible (de 1 à 99), du plus
/// juste au moins juste ; [graine] fait tourner l'objet et la phrase (une
/// graine sur six sort un objet minuscule au multiple absurde, burger ou
/// baguette). La même graine redonne toujours la même carte. [mois] donne
/// les phrases du bilan du mois (« C'est comme soulever... »).
Equivalent equivalentPour(double kg, {int graine = 0, bool mois = false}) {
  final g = graine.abs();
  final chat = objetsEquivalents.firstWhere((o) => o.asset == Objets3D.chat);
  if (!kg.isFinite || kg < 0.25) {
    return _composer(
      chat,
      'Aucun kilo au compteur.\n*Le chat* reste par terre.',
      etiquette: '× 0',
      multiple: 0,
    );
  }

  // Objets lisibles, avec leur multiple.
  final lisibles = <(ObjetEquivalent, _Multiple)>[];
  for (final o in objetsEquivalents) {
    if (o.absurde) continue;
    final r = kg / o.kg;
    if (o.pourcent && r < 0.93) continue;
    if (r < 0.93 || r >= 99.5) continue;
    lisibles.add((o, _arrondir(r)));
  }
  // Les multiples entiers d'abord, du plus juste au moins juste ; à justesse
  // égale, le plus petit multiple.
  lisibles.sort((a, b) {
    if (a.$2.decimale != b.$2.decimale) return a.$2.decimale ? 1 : -1;
    // Justesse par tranches de 2 % : en dessous, la différence ne se voit pas.
    final e = (a.$2.erreur * 50).floor().compareTo((b.$2.erreur * 50).floor());
    return e != 0 ? e : a.$2.valeur.compareTo(b.$2.valeur);
  });

  // La statue de la Liberté, en pourcentage, à partir de 10 %.
  final liberte = objetsEquivalents.firstWhere((o) => o.pourcent);
  final part = kg / liberte.kg * 100;
  final enPourcent = part >= 10 && part < 93;

  final absurdes = objetsEquivalents.where((o) => o.absurde).toList();
  final nbChoix = lisibles.length + (enPourcent ? 1 : 0);

  // Un objet minuscule : une graine sur six, ou faute de mieux.
  if (nbChoix == 0 || (g % 6 == 5 && kg >= 50)) {
    if (nbChoix == 0 && kg / liberte.kg >= 99.5) {
      // Au-delà de tout : des statues de la Liberté, sans plafond.
      return _enMultiple(liberte, _Multiple((kg / liberte.kg).roundToDouble(), false, 0), g, mois);
    }
    final o = absurdes[(g ~/ 6) % absurdes.length];
    final r = (kg / o.kg).roundToDouble();
    return _enMultiple(o, _Multiple(r < 1 ? 1 : r, false, 0), g ~/ 12, mois);
  }

  // Les graines 0 à 4 de chaque tour de six parcourent les choix lisibles.
  final rang = (g ~/ 6) * 5 + g % 6;
  final i = rang % nbChoix;
  if (i >= lisibles.length) {
    final p = part.round().toString();
    return _composer(
      liberte,
      _pourcent[mois ? 0 : (rang ~/ nbChoix) % _pourcent.length],
      p: p,
      etiquette: '$p %',
      multiple: part.roundToDouble(),
      pourcentage: true,
    );
  }
  final (o, m) = lisibles[i];
  return _enMultiple(o, m, rang ~/ nbChoix, mois);
}
