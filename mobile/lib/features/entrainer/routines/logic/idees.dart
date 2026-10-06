import '../../../../core/logic/text_search.dart';
import '../../../../core/models/models.dart';
import 'program_catalogue.dart';
import 'program_templates.dart';

/// Rayon d'une idée : une rangée de la page des idées.
enum Rayon {
  debuter('Pour débuter'),
  muscle('Prendre du muscle'),
  force('Gagner en force'),
  seche('Sécher et se tonifier'),
  maison('À la maison, sans matériel'),
  halteres('Avec des haltères'),
  kettlebell('Avec une kettlebell'),
  elastiques('Élastiques et voyage'),
  barres('Barres, dips et anneaux'),
  cible('Cibler une zone'),
  express('Quand le temps manque'),
  sport('Pour ton sport'),
  mobilite('Mobilité et bien-être'),
  cardio('Cardio');

  const Rayon(this.label);
  final String label;

  /// Faisable chez soi sans rien d'autre que le sol (ou un élastique).
  bool get sansMateriel => this == maison || this == elastiques || this == mobilite;
}

/// Habillage d'une idée de programme : sa couverture et ses libellés.
class IdeeProgramme {
  const IdeeProgramme({
    required this.modeleId,
    required this.gros,
    required this.titre,
    this.bandeau,
    this.face = const {},
    this.dos = const {},
    this.poses = const [],
    this.classique = false,
    this.rayon = Rayon.muscle,
  });

  final String modeleId;

  /// Titre en gros sur la couverture (« Full body »), affiché en capitales.
  final String gros;

  /// Bandeau blanc sous le titre (« Push · Pull · Legs »).
  final String? bandeau;

  /// Nom sous la couverture.
  final String titre;

  /// Couverture au personnage : muscles allumés de face et de dos.
  final Set<Muscle> face;
  final Set<Muscle> dos;

  /// Couverture à la pose : exercices candidats, le premier trouvé gagne.
  final List<String> poses;

  /// Rangée « Les classiques ».
  final bool classique;

  /// Rangée où l'idée est rangée.
  final Rayon rayon;

  bool get auPersonnage => face.isNotEmpty || dos.isNotEmpty;

  ModeleProgramme get modele => modeleParId(modeleId)!;
}

/// Les idées, dans l'ordre d'affichage : chaque modèle a la sienne.
final List<IdeeProgramme> ideesProgrammes = [..._ideesDeBase, ...ideesCatalogue];

final Map<String, IdeeProgramme> _ideesParModele = {for (final i in ideesProgrammes) i.modeleId: i};

const _ideesDeBase = <IdeeProgramme>[
  IdeeProgramme(
    modeleId: 'full-body-3j',
    gros: 'Full body',
    titre: 'Corps entier',
    classique: true,
    face: {Muscle.pectoraux, Muscle.abdominaux, Muscle.quadriceps, Muscle.biceps, Muscle.deltoidesLateraux},
    dos: {Muscle.grandDorsal, Muscle.fessiers, Muscle.ischios, Muscle.trapezes},
  ),
  IdeeProgramme(
    modeleId: 'push-pull-legs-6j',
    gros: 'PPL',
    bandeau: 'Push · Pull · Legs',
    titre: 'Push / Pull / Legs',
    classique: true,
    face: {Muscle.pectoraux, Muscle.deltoidesAnterieurs, Muscle.triceps},
    dos: {Muscle.grandDorsal, Muscle.trapezes},
  ),
  IdeeProgramme(
    modeleId: 'haut-bas-4j',
    gros: 'Haut / Bas',
    bandeau: '4 jours',
    titre: 'Haut du corps / Bas du corps',
    classique: true,
    // Le haut allumé de face, le bas allumé de dos : les deux moitiés du titre.
    face: {Muscle.pectoraux, Muscle.deltoidesAnterieurs, Muscle.biceps, Muscle.abdominaux},
    dos: {Muscle.fessiers, Muscle.ischios, Muscle.mollets},
  ),
  IdeeProgramme(modeleId: 'split-5j', gros: 'Split 5 jours', bandeau: 'Prise de muscle', titre: 'Un groupe par jour', poses: ['developpe-couche']),
  IdeeProgramme(modeleId: 'maison-3j', gros: 'À la maison', bandeau: 'Sans matériel', titre: 'Poids du corps', rayon: Rayon.maison, poses: ['pompes-archer', 'pompes']),
  IdeeProgramme(modeleId: 'cinq-par-cinq', gros: 'Force', bandeau: '5 × 5', titre: 'Force 5 × 5', rayon: Rayon.force, poses: ['souleve-de-terre', 'squat']),
  IdeeProgramme(modeleId: 'debutant-3j', gros: 'Débuter', bandeau: 'Les bases', titre: 'Débutant 3 jours', rayon: Rayon.debuter, poses: ['squat-goblet', 'presse-a-cuisses']),
  IdeeProgramme(modeleId: 'arnold-split', gros: 'Arnold', bandeau: 'Split 6 jours', titre: 'Arnold split', poses: ['developpe-arnold']),
];

IdeeProgramme? ideeParModele(String? modeleId) => modeleId == null ? null : _ideesParModele[modeleId];

/// « 3 jours par semaine » dans la rangée des classiques, « 5 jours » ailleurs.
String rythmeIdee(ModeleProgramme m, {bool long = false}) => '${m.joursParSemaine} jours${long ? ' par semaine' : ''}';

/// Une idée avec la ligne écrite dessous.
typedef IdeeClassee = ({IdeeProgramme idee, String detail});

/// Les classiques, toujours les mêmes et dans le même ordre.
List<IdeeClassee> ideesClassiques() => [
      for (final i in ideesProgrammes)
        if (i.classique) (idee: i, detail: '${rythmeIdee(i.modele, long: i.bandeau == null)} · ${i.modele.niveau.label}'),
    ];

bool _sansMateriel(Set<Materiel> m) =>
    m.isNotEmpty && m.every((x) => x == Materiel.poidsDuCorps || x == Materiel.elastiques || x == Materiel.barreTraction);

/// Nombre d'idées de la rangée « Recommandé pour toi ».
const nbRecommandees = 12;

/// Les idées d'un rayon, dans l'ordre du catalogue.
List<IdeeClassee> ideesDuRayon(Rayon r) => [
      for (final i in ideesProgrammes)
        if (i.rayon == r) (idee: i, detail: '${rythmeIdee(i.modele)} · ${i.modele.niveau.label}'),
    ];

/// « Recommandé pour toi » : les idées qui collent le mieux au profil
/// (rythme, niveau, matériel), avec la raison quand il y en a une :
/// « Proche de ton programme actuel », « Ton rythme »...
List<IdeeClassee> ideesRecommandees({UserProfile? profil, Program? actif}) {
  final sansMateriel = profil != null && _sansMateriel(profil.materiel);
  final rythme = actif?.joursParSemaine ?? profil?.joursParSemaine;
  final notes = <(IdeeProgramme, double, String)>[];
  for (final (rang, i) in ideesProgrammes.where((i) => !i.classique).indexed) {
    final m = i.modele;
    // À égalité, l'ordre du catalogue départage.
    var score = -rang / 1000;
    String raison = m.niveau.label;
    if (profil != null && m.niveau == profil.niveau) score += 3;
    if (rythme != null) {
      final ecart = (m.joursParSemaine - rythme).abs();
      score += 6 - 2 * ecart;
      if (ecart <= 1) raison = actif != null ? 'Proche de ton programme actuel' : 'Ton rythme';
    }
    final maison = i.rayon.sansMateriel;
    if (maison && sansMateriel) {
      score += 20;
      raison = 'Sans matériel, comme chez toi';
    } else if (!maison && sansMateriel) {
      score -= 10;
    }
    notes.add((i, score, raison));
  }
  notes.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (i, _, raison) in notes.take(nbRecommandees)) (idee: i, detail: '${rythmeIdee(i.modele)} · $raison')];
}

/// Filtre de la recherche : nom, titres de couverture, objectif, niveau.
bool ideeCorrespond(IdeeProgramme i, String recherche) {
  final q = TextSearch.normalize(recherche);
  if (q.isEmpty) return true;
  final m = i.modele;
  final texte = TextSearch.normalize([i.gros, i.bandeau ?? '', i.titre, i.rayon.label, m.nom, m.resume, m.objectif, m.niveau.label, '${m.joursParSemaine} jours'].join(' '));
  return q.split(' ').every(texte.contains);
}

/// Mots qui disent un rythme ou une durée (« 4 jours », « 12 semaines ») et
/// petits mots de liaison : ils ne comptent ni dans le sigle ni dans le
/// titre de la couverture.
final _motRythme = RegExp(r'^(jours?|j|semaines?|sem|fois|mois|séances?|seances?|x|par|sur)$', caseSensitive: false);
final _motLiaison = RegExp(r"^(de|du|des|le|la|les|et|ou|à|a|au|aux|en|pour|d|l)$", caseSensitive: false);
final _nombre = RegExp(r'^\d+$');
final _version = RegExp(r'^[vV]?(\d{1,2})$');

/// Les mots qui nomment vraiment le programme : « Haut/Bas 4 jours » donne
/// (Haut, Bas), « Push Pull Legs, 12 semaines » donne (Push, Pull, Legs).
List<String> _motsDuNom(String nom) => nom
    .trim()
    .split(RegExp(r"[\s,/·'’()+-]+"))
    .where((m) => m.isNotEmpty && !_nombre.hasMatch(m) && !_motRythme.hasMatch(m) && !_motLiaison.hasMatch(m))
    .toList();

/// Vrai si le nom finit par un numéro de version (« ... V3 », « ... 2 »),
/// et non par un rythme (« ... 4 jours »).
RegExpMatch? _versionDe(List<String> mots) => mots.length > 1 ? _version.firstMatch(mots.last) : null;

/// Sigle d'un programme pour sa tuile : la version s'il y en a une
/// (« DT COACH Tristan V3 » donne « V3 »), sinon les initiales des mots qui
/// le nomment (« Haut/Bas 4 jours » donne « HB », jamais « HBJ »).
String sigleProgramme(String nom) {
  final mots = nom.trim().split(RegExp(r'[\s,/]+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '?';
  final v = _versionDe(mots);
  if (v != null) return 'V${v.group(1)}';
  final lettres = _motsDuNom(nom).where((m) => RegExp(r'^[A-Za-zÀ-ÿ]').hasMatch(m)).toList();
  if (lettres.isEmpty) return mots.first.substring(0, mots.first.length.clamp(1, 2)).toUpperCase();
  if (lettres.length == 1) return lettres.first.substring(0, lettres.first.length.clamp(1, 2)).toUpperCase();
  return lettres.take(3).map((m) => m[0]).join().toUpperCase();
}

/// Couverture d'un programme : une ligne au-dessus, un gros signe dessous.
/// « DT COACH Tristan V3 » donne (« DT COACH », « 3 ») ; « Haut/Bas 4 jours »
/// donne (« HAUT/BAS », « HB »), sans le rythme.
({String haut, String gros}) couvertureProgramme(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  final v = _versionDe(mots);
  if (v != null) return (haut: mots.take(mots.length - 1).take(2).join(' ').toUpperCase(), gros: v.group(1)!);
  // On garde l'écriture du nom (« Haut/Bas ») mais on s'arrête au rythme.
  final garde = <String>[];
  for (final m in mots) {
    final nu = m.replaceAll(RegExp(r'[,()]'), '');
    if (_nombre.hasMatch(nu) || _motRythme.hasMatch(nu)) break;
    garde.add(nu);
    if (garde.length == 2) break;
  }
  final haut = (garde.isEmpty ? mots.take(2).join(' ').replaceAll(',', '') : garde.join(' ')).toUpperCase();
  return (haut: haut, gros: sigleProgramme(nom));
}

/// Premier nom libre : « Full body 3 jours », puis « Full body 3 jours (2) »...
String nomLibre(String nom, Set<String> pris) {
  if (!pris.contains(nom)) return nom;
  for (var n = 2;; n++) {
    final essai = '$nom ($n)';
    if (!pris.contains(essai)) return essai;
  }
}
