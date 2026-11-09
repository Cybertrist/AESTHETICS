import '../../../core/models/models.dart';
import '../../profil/data/grades.dart';
import 'modeles.dart';
import 'source.dart';

/// La communauté en aperçu : des personnes d'exemple, tout en mémoire.
///
/// Rien n'est lu ni envoyé à un serveur ; les gestes (bravo, demande,
/// invitation) changent l'écran et s'oublient à la fermeture. Elle sert au
/// mode démo, aux tests, et aux constructions sans serveur.
class SourceExemple extends SourceSociale {
  SourceExemple({DateTime? maintenant}) : _creation = maintenant ?? DateTime.now() {
    _fil = _publications(_creation);
  }

  /// Les dates d'exemple se comptent depuis l'ouverture de l'appli.
  final DateTime _creation;

  @override
  bool get apercu => true;

  /// Toujours « connecté » : les exemples n'ont pas besoin de compte.
  @override
  String? get moi => 'moi';

  static const _vert = 0xFF2E7D4F, _bleu = 0xFF2F6FB5, _violet = 0xFF7A4FB5, _orange = 0xFFB5702F, _rose = 0xFFB54F7A, _gris = 0xFF4A4F5A, _sarcelle = 0xFF2F8F95, _brique = 0xFFA5483C;
  static const _tout = {Visible.seances, Visible.charges, Visible.serie, Visible.badges, Visible.records, Visible.lieu, ...Visible.recents};

  /// Tout le monde, une seule fois : le lien avec chacun est dans [_liens].
  static const List<Ami> _personnes = [
    // Ouvert à tous, tout montré : le profil le plus complet.
    Ami(
      id: 'lea',
      prenom: 'Léa',
      pseudo: 'lea.mrt',
      couleur: _violet,
      phrase: 'Un pas après l\'autre.',
      ville: 'Brest',
      salle: 'Basic-Fit Kergaradec',
      depuis: 2021,
      acces: AccesProfil.tous,
      montre: _tout,
      serieSemaines: 31,
      seances: 412,
      heures: 468,
      objectif: 'Prendre du muscle',
      niveau: 'Avancée',
      jours: [0, 1, 3, 4, 6, 8, 9, 10, 13, 15, 16, 17, 20, 22, 23, 24, 27, 29],
      records: [RecordAmi('squat', 100, 3), RecordAmi('hip-thrust', 160, 6), RecordAmi('souleve-de-terre', 120, 2), RecordAmi('tractions', 15, 5)],
      badges: {Grade.serie: 31, Grade.semaineParfaite: 44, Grade.leveTot: 118, Grade.explorateur: 96, Grade.records: 61, Grade.weekEnd: 80},
      fetiches: ['squat', 'hip-thrust', 'souleve-de-terre-roumain'],
      amis: 48,
      enCommun: ['malo', 'ines'],
    ),
    // Réservé aux amis ; il cache ses charges.
    Ami(
      id: 'malo',
      prenom: 'Malo',
      pseudo: 'malo_29',
      couleur: _bleu,
      phrase: 'Force d\'abord.',
      ville: 'Quimper',
      salle: 'L\'Orange Bleue',
      depuis: 2023,
      montre: {Visible.seances, Visible.serie, Visible.badges, Visible.records, Visible.lieu, Visible.nbSeances, Visible.nbAmis, Visible.heures, Visible.objectif},
      serieSemaines: 12,
      seances: 141,
      heures: 172,
      objectif: 'Gagner en force',
      niveau: 'Intermédiaire',
      jours: [1, 3, 5, 8, 10, 12, 15, 17, 19, 22, 24],
      records: [RecordAmi('developpe-couche', 110, 1), RecordAmi('souleve-de-terre', 200, 1), RecordAmi('squat', 160, 2)],
      badges: {Grade.serie: 14, Grade.marathon: 12, Grade.records: 38, Grade.noctambule: 9},
      fetiches: ['developpe-couche', 'souleve-de-terre', 'squat'],
      amis: 17,
      enCommun: ['lea'],
    ),
    // Réservé aux amis ; elle ne montre que ses séances et sa série.
    Ami(
      id: 'ines',
      prenom: 'Inès',
      pseudo: 'ines.fit',
      couleur: _rose,
      phrase: 'Trois séances, pas une de moins.',
      depuis: 2025,
      montre: {Visible.seances, Visible.serie, Visible.nbSeances, Visible.objectif},
      serieSemaines: 4,
      seances: 38,
      heures: 31,
      objectif: 'Sécher',
      niveau: 'Débutante',
      jours: [2, 5, 7, 9, 12, 14, 16, 19, 21],
      fetiches: ['tractions', 'rowing-barre', 'curl-marteau'],
      amis: 9,
      enCommun: ['lea'],
    ),
    // Privé : même ses amis ne voient que son prénom.
    Ami(
      id: 'yann',
      prenom: 'Yann',
      pseudo: 'yann.lg',
      couleur: _vert,
      phrase: 'Reprise après blessure.',
      ville: 'Morlaix',
      depuis: 2019,
      acces: AccesProfil.personne,
      seances: 267,
      heures: 301,
      objectif: 'Reprendre',
      niveau: 'Avancé',
      jours: [9, 16],
      amis: 6,
    ),
    // Deux demandes reçues : un profil ouvert à tous, un profil réservé.
    Ami(
      id: 'tom',
      prenom: 'Tom',
      pseudo: 'tom.brz',
      couleur: _orange,
      phrase: 'Full body, trois fois par semaine.',
      ville: 'Brest',
      salle: 'Fitness Park Brest',
      depuis: 2024,
      acces: AccesProfil.tous,
      montre: {Visible.seances, Visible.charges, Visible.serie, Visible.badges, Visible.lieu, ...Visible.recents},
      serieSemaines: 8,
      seances: 61,
      heures: 58,
      objectif: 'Prendre du muscle',
      niveau: 'Débutant',
      jours: [1, 3, 6, 8, 10, 13, 15, 17, 20],
      badges: {Grade.serie: 8, Grade.semaineParfaite: 6, Grade.explorateur: 31},
      fetiches: ['squat', 'developpe-couche', 'rowing-barre'],
      amis: 12,
      enCommun: ['lea', 'malo'],
    ),
    Ami(
      id: 'sarah',
      prenom: 'Sarah',
      pseudo: 'sarah.k',
      couleur: _gris,
      phrase: 'Haut, bas, haut, bas.',
      depuis: 2022,
      montre: {Visible.seances, Visible.serie, Visible.badges, Visible.records, Visible.nbSeances, Visible.nbAmis, Visible.niveau},
      serieSemaines: 19,
      seances: 140,
      heures: 133,
      objectif: 'Se sentir en forme',
      niveau: 'Intermédiaire',
      jours: [0, 2, 4, 7, 9, 11, 14, 16, 18, 21, 23],
      records: [RecordAmi('hip-thrust', 120, 5), RecordAmi('developpe-militaire', 37.5, 4)],
      badges: {Grade.serie: 19, Grade.semaineParfaite: 21, Grade.weekEnd: 34},
      fetiches: ['hip-thrust', 'tirage-vertical', 'developpe-militaire'],
      amis: 23,
      enCommun: ['ines'],
    ),
    // Trois contacts : ouvert à tous, réservé aux amis, privé.
    Ami(
      id: 'hugo',
      prenom: 'Hugo',
      pseudo: 'hugo.dvl',
      couleur: _sarcelle,
      phrase: 'Force athlétique, moins de 83 kg.',
      ville: 'Rennes',
      salle: 'Iron Factory',
      depuis: 2018,
      acces: AccesProfil.tous,
      montre: _tout,
      serieSemaines: 22,
      seances: 836,
      heures: 1260,
      objectif: 'Gagner en force',
      niveau: 'Avancé',
      jours: [0, 2, 3, 5, 7, 9, 10, 12, 14, 16, 17, 19, 21, 23, 24, 26, 28],
      records: [RecordAmi('squat', 215, 1), RecordAmi('developpe-couche', 142.5, 1), RecordAmi('souleve-de-terre', 260, 1), RecordAmi('developpe-militaire', 85, 2)],
      badges: {Grade.serie: 61, Grade.marathon: 143, Grade.records: 214, Grade.semaineParfaite: 78, Grade.noctambule: 52, Grade.explorateur: 74},
      fetiches: ['squat', 'developpe-couche', 'souleve-de-terre'],
      amis: 214,
      enCommun: ['malo'],
    ),
    Ami(
      id: 'clara',
      prenom: 'Clara',
      pseudo: 'clara.run',
      couleur: _rose,
      phrase: 'Course le matin, salle le soir.',
      ville: 'Brest',
      serieSemaines: 6,
      seances: 44,
      heures: 36,
      objectif: 'Se sentir en forme',
      amis: 31,
      enCommun: ['lea', 'ines'],
    ),
    Ami(id: 'nolan', prenom: 'Nolan', pseudo: 'nolan.pl', couleur: _brique, acces: AccesProfil.personne, serieSemaines: 40, seances: 310, heures: 290, amis: 4),
  ];

  final Map<String, Lien> _liens = {
    'lea': Lien.ami,
    'malo': Lien.ami,
    'ines': Lien.ami,
    'yann': Lien.ami,
    'tom': Lien.demandeRecue,
    'sarah': Lien.demandeRecue,
  };

  static List<Publication> _publications(DateTime n) {
    Publication p(String id, String ami, String titre, Duration ilYa, int minutes, double volume, int series, List<String> exos, {int records = 0, int bravos = 0, String? note}) => Publication(
          id: id,
          amiId: ami,
          titre: titre,
          date: n.subtract(ilYa),
          duree: Duration(minutes: minutes),
          volumeKg: volume,
          series: series,
          exercices: exos,
          records: records,
          bravos: bravos,
          note: note,
        );
    return [
      p('p1', 'lea', 'Jambes', const Duration(hours: 2), 72, 14320, 22, ['squat', 'souleve-de-terre-roumain', 'presse-a-cuisses'], records: 1, bravos: 6, note: '100 kg au squat, enfin.'),
      p('h1', 'hugo', 'Squat lourd', const Duration(hours: 5), 124, 18650, 19, ['squat', 'presse-a-cuisses', 'leg-extension'], records: 1, bravos: 41, note: '215 kg. Trois ans que je la visais.'),
      p('s1', 'sarah', 'Bas du corps', const Duration(hours: 9), 63, 7420, 18, ['hip-thrust', 'presse-a-cuisses', 'leg-extension'], bravos: 8),
      p('p2', 'malo', 'Push', const Duration(days: 1, hours: 3), 58, 5120, 18, ['developpe-couche', 'developpe-incline-halteres', 'developpe-militaire'], bravos: 3),
      p('t1', 'tom', 'Full body A', const Duration(days: 1, hours: 6), 52, 4210, 15, ['squat', 'developpe-couche', 'rowing-barre'], bravos: 2),
      p('p3', 'ines', 'Haut du corps', const Duration(days: 2, hours: 1), 47, 3890, 16, ['tractions', 'rowing-barre', 'curl-marteau'], records: 2, bravos: 9),
      p('h2', 'hugo', 'Développé couché', const Duration(days: 2, hours: 4), 96, 9840, 21, ['developpe-couche', 'developpe-militaire', 'pompes'], bravos: 18),
      p('p4', 'lea', 'Pull', const Duration(days: 3, hours: 2), 65, 5869, 20, ['tractions', 'tirage-vertical', 'face-pull'], bravos: 4),
      p('p5', 'malo', 'Soulevé de terre', const Duration(days: 3, hours: 5), 81, 8230, 14, ['souleve-de-terre', 'rowing-barre', 'gainage'], records: 1, bravos: 7, note: '200 kg, propre.'),
      p('t2', 'tom', 'Full body B', const Duration(days: 3, hours: 7), 49, 3980, 15, ['souleve-de-terre', 'developpe-militaire', 'tirage-vertical'], bravos: 1),
      p('p6', 'lea', 'Fessiers', const Duration(days: 4, hours: 1), 61, 11240, 19, ['hip-thrust', 'souleve-de-terre-roumain', 'leg-extension'], bravos: 5),
      p('p7', 'ines', 'Bas du corps', const Duration(days: 5), 44, 4630, 15, ['squat', 'presse-a-cuisses', 'gainage'], bravos: 6),
    ];
  }

  static List<Commentaire> _exemples(List<Publication> fil) {
    final dates = {for (final p in fil) p.id: p.date};
    var n = 0;
    Commentaire c(String pub, String ami, int minutes, String texte) => Commentaire(id: 'c${n++}', publicationId: pub, amiId: ami, texte: texte, date: dates[pub]!.add(Duration(minutes: minutes)));
    return [
      c('p1', 'malo', 14, 'Les trois chiffres, enfin. Bravo.'),
      c('p1', 'ines', 41, 'Tu me donnes envie d\'y retourner demain.'),
      c('h1', 'malo', 9, 'Monstrueux.'),
      c('h1', 'lea', 22, 'Trois ans de patience, ça paie.'),
      c('h1', 'tom', 65, 'Tu descends à quelle profondeur ?'),
      c('s1', 'ines', 30, 'Le hip thrust monte bien.'),
      c('p3', 'lea', 12, 'Deux records d\'un coup, bien joué.'),
      c('h2', 'malo', 18, 'On en reparle samedi à la salle.'),
      c('h2', 'sarah', 50, 'Propre.'),
      c('p5', 'lea', 6, '200 ! Félicitations.'),
      c('p5', 'ines', 25, 'Et sans sangles ?'),
      c('p5', 'hugo', 90, 'Bienvenue au club.'),
    ];
  }

  late final List<Publication> _fil;
  late final List<Commentaire> _commentaires = _exemples(_fil);
  final Map<String, Reaction> _reactions = {'p3': Reaction.feu};

  @override
  Lien lien(String id) => _liens[id] ?? Lien.aucun;
  bool _estAmi(String id) => lien(id) == Lien.ami;

  @override
  List<Ami> avec(Lien l) => [
        for (final a in _personnes)
          if (lien(a.id) == l) a,
      ];

  @override
  List<Ami> get suggestions => [
        for (final a in _personnes)
          if (lien(a.id) == Lien.aucun || lien(a.id) == Lien.demandeEnvoyee) a,
      ];

  @override
  Ami? ami(String id) => _personnes.where((a) => a.id == id).firstOrNull;

  @override
  List<Publication> get publications => _fil;

  @override
  Publication? publication(String id) => _fil.where((p) => p.id == id).firstOrNull;

  /// Les séances de mes amis qui me les montrent.
  List<Publication> get _filAmis => [
        for (final p in _fil)
          if (_estAmi(p.amiId) && (ami(p.amiId)!.acces != AccesProfil.personne) && ami(p.amiId)!.montre.contains(Visible.seances)) p,
      ];

  @override
  Set<DateTime> joursDe(Ami a) => {
        for (final j in a.jours) DateTime(_creation.year, _creation.month, _creation.day - j),
        for (final p in _fil.where((p) => p.amiId == a.id)) DateTime(p.date.year, p.date.month, p.date.day),
      };

  @override
  Reaction? reaction(String publicationId) => _reactions[publicationId];

  @override
  int bravos(Publication p) => p.bravos + (_reactions.containsKey(p.id) ? 1 : 0);

  @override
  Future<void> reagir(String publicationId, Reaction? r) async {
    if (r == null) {
      _reactions.remove(publicationId);
    } else {
      _reactions[publicationId] = r;
    }
    notifyListeners();
  }

  @override
  List<Commentaire> commentaires(String publicationId) => [
        for (final c in _commentaires)
          if (c.publicationId == publicationId) c,
      ];

  @override
  Future<void> commenter(String publicationId, String texte, {DateTime? maintenant}) async {
    _commentaires.add(Commentaire(id: 'm${_commentaires.length}', publicationId: publicationId, texte: texte, date: maintenant ?? DateTime.now()));
    notifyListeners();
  }

  @override
  Future<void> retirerCommentaire(String id) async {
    _commentaires.removeWhere((c) => c.id == id && c.mien);
    notifyListeners();
  }

  @override
  List<Activite> activites({String? maSeance, String? nomSeance, DateTime? finSeance}) {
    // Rien ne peut arriver après maintenant.
    DateTime apres(DateTime d, Duration ecart) {
      final t = d.add(ecart);
      return t.isAfter(_creation) ? _creation : t;
    }

    bool ami(String id) => _estAmi(id);
    return [
      if (maSeance != null && finSeance != null) ...[
        if (ami('lea') || ami('malo'))
          Activite(
            type: TypeActivite.reaction,
            amis: [if (ami('lea')) 'lea', if (ami('malo')) 'malo'],
            date: apres(finSeance, const Duration(minutes: 48)),
            seanceId: maSeance,
            reaction: Reaction.feu,
            texte: nomSeance,
          ),
        if (ami('ines')) Activite(type: TypeActivite.commentaire, amis: const ['ines'], date: apres(finSeance, const Duration(minutes: 25)), seanceId: maSeance, texte: 'Solide. Tu progresses vite.'),
      ],
      if (ami('yann')) Activite(type: TypeActivite.accepte, amis: const ['yann'], date: _creation.subtract(const Duration(days: 3, hours: 4))),
      for (final p in _filAmis)
        if (p.records > 0) Activite(type: TypeActivite.record, amis: [p.amiId], date: p.date, publicationId: p.id, texte: p.titre),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  void _lier(String id, Lien l) {
    if (ami(id) == null) return;
    _liens[id] = l;
    notifyListeners();
  }

  @override
  Future<void> accepter(String id) async {
    if (lien(id) == Lien.demandeRecue) _lier(id, Lien.ami);
  }

  @override
  Future<void> refuser(String id) async {
    if (lien(id) == Lien.demandeRecue) _lier(id, Lien.aucun);
  }

  @override
  Future<void> inviter(String id) async {
    if (lien(id) == Lien.aucun) _lier(id, Lien.demandeEnvoyee);
  }

  @override
  Future<void> annulerInvitation(String id) async {
    if (lien(id) == Lien.demandeEnvoyee) _lier(id, Lien.aucun);
  }

  @override
  Future<void> retirer(String id) async {
    if (lien(id) == Lien.ami) _lier(id, Lien.aucun);
  }

  @override
  Future<void> bloquer(String id) async => _lier(id, Lien.bloque);

  @override
  Future<void> debloquer(String id) async {
    if (lien(id) == Lien.bloque) _lier(id, Lien.aucun);
  }

  /// Les personnes dont le prénom ou le pseudo contient [texte], amis compris.
  @override
  List<Ami> chercher(String texte) => [
        for (final a in _personnes)
          if (lien(a.id) != Lien.bloque && (aPlat(a.prenom).contains(texte) || aPlat(a.pseudo).contains(texte))) a,
      ];

  @override
  Future<String?> trouverPseudo(String pseudo) async {
    final t = aPlat(pseudo);
    return _personnes.where((a) => a.pseudo == t).firstOrNull?.id;
  }
}
