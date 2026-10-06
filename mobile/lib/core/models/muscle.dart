/// Grandes zones, pour filtrer et regrouper.
enum MuscleRegion {
  poitrine('Poitrine'),
  dos('Dos'),
  epaules('Épaules'),
  bras('Bras'),
  abdos('Abdos'),
  jambes('Jambes'),
  cou('Cou');

  const MuscleRegion(this.label);
  final String label;

  List<Muscle> get muscles => Muscle.values.where((m) => m.region == this).toList();
}

/// Face du personnage où le muscle se voit le mieux.
enum MuscleSide { face, dos, lesDeux }

/// Identifiants des muscles : contrat entre catalogue, personnage, récupération et stats.
enum Muscle {
  pectoraux('Pectoraux', MuscleRegion.poitrine, MuscleSide.face),
  deltoidesAnterieurs('Deltoïdes antérieurs', MuscleRegion.epaules, MuscleSide.face),
  deltoidesLateraux('Deltoïdes latéraux', MuscleRegion.epaules, MuscleSide.lesDeux),
  deltoidesPosterieurs('Deltoïdes postérieurs', MuscleRegion.epaules, MuscleSide.dos),
  biceps('Biceps', MuscleRegion.bras, MuscleSide.face),
  triceps('Triceps', MuscleRegion.bras, MuscleSide.dos),
  avantBras('Avant-bras', MuscleRegion.bras, MuscleSide.lesDeux),
  trapezes('Trapèzes', MuscleRegion.dos, MuscleSide.dos),
  grandDorsal('Grand dorsal', MuscleRegion.dos, MuscleSide.dos),
  rhomboides('Rhomboïdes', MuscleRegion.dos, MuscleSide.dos),
  lombaires('Lombaires', MuscleRegion.dos, MuscleSide.dos),
  abdominaux('Abdominaux', MuscleRegion.abdos, MuscleSide.face),
  obliques('Obliques', MuscleRegion.abdos, MuscleSide.face),
  fessiers('Fessiers', MuscleRegion.jambes, MuscleSide.dos),
  quadriceps('Quadriceps', MuscleRegion.jambes, MuscleSide.face),
  ischios('Ischio-jambiers', MuscleRegion.jambes, MuscleSide.dos),
  adducteurs('Adducteurs', MuscleRegion.jambes, MuscleSide.face),
  abducteurs('Abducteurs', MuscleRegion.jambes, MuscleSide.lesDeux),
  mollets('Mollets', MuscleRegion.jambes, MuscleSide.dos),
  cou('Cou', MuscleRegion.cou, MuscleSide.face);

  const Muscle(this.label, this.region, this.side);
  final String label;
  final MuscleRegion region;
  final MuscleSide side;

  /// Identifiant du groupe dans les SVG du personnage.
  String get svgId => 'm-$name';

  /// Lecture tolérante : nom exact, libellé français ou nom anglais courant.
  static Muscle? tryParse(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    for (final m in Muscle.values) {
      if (m.name == s) return m;
    }
    final k = _normalize(s);
    for (final m in Muscle.values) {
      if (_normalize(m.name) == k || _normalize(m.label) == k) return m;
    }
    return _synonyms[k];
  }

  static List<Muscle> parseList(Object? raw) {
    if (raw is! List) return const [];
    final out = <Muscle>[];
    for (final e in raw) {
      final m = tryParse(e);
      if (m != null && !out.contains(m)) out.add(m);
    }
    return out;
  }

  static String _normalize(String s) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    };
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final c = accents[ch] ?? ch;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
    }
    return b.toString();
  }

  static final Map<String, Muscle> _synonyms = {
    'chest': pectoraux, 'pecs': pectoraux, 'pectoral': pectoraux, 'pectoralis': pectoraux,
    'frontdelts': deltoidesAnterieurs, 'anteriordeltoid': deltoidesAnterieurs, 'shoulders': deltoidesAnterieurs, 'epaules': deltoidesAnterieurs,
    'sidedelts': deltoidesLateraux, 'lateraldeltoid': deltoidesLateraux,
    'reardelts': deltoidesPosterieurs, 'posteriordeltoid': deltoidesPosterieurs,
    'bicep': biceps, 'triceps': triceps, 'tricep': triceps,
    'forearms': avantBras, 'forearm': avantBras, 'avantbras': avantBras,
    'traps': trapezes, 'trapezius': trapezes, 'trapeze': trapezes,
    'lats': grandDorsal, 'latissimusdorsi': grandDorsal, 'dorsaux': grandDorsal, 'dos': grandDorsal,
    'middleback': rhomboides, 'upperback': rhomboides, 'rhomboids': rhomboides,
    'lowerback': lombaires, 'erectors': lombaires, 'lombaire': lombaires,
    'abs': abdominaux, 'abdominals': abdominaux, 'abdos': abdominaux, 'core': abdominaux,
    'oblique': obliques,
    'glutes': fessiers, 'gluteus': fessiers, 'fessier': fessiers,
    'quads': quadriceps, 'quadricep': quadriceps,
    'hamstrings': ischios, 'ischiojambiers': ischios, 'ischio': ischios,
    'adductors': adducteurs, 'abductors': abducteurs,
    'calves': mollets, 'calf': mollets, 'mollet': mollets,
    'neck': cou,
  };
}
