import 'dart:math' as math;

import '../models/exercise.dart';
import '../models/json.dart';
import 'format.dart';
import 'strength.dart';

/// Façon dont se règle la charge d'un exercice.
enum SorteCharges {
  /// Pile de plaques à goupille (machine, poulie), en livres ou en kilos.
  pile('Pile de plaques'),

  /// Disques par paire sur une barre, une machine guidée ou une presse.
  disques('Disques'),

  /// Haltères du râtelier.
  halteres('Haltères'),

  /// Kettlebells de la salle.
  kettlebell('Kettlebells'),

  /// Un pas fixe, sans matériel particulier (le réglage « pas des charges »).
  libre('Pas fixe');

  const SorteCharges(this.label);
  final String label;
}

/// Unité gravée sur les plaques d'une pile.
enum UniteCharges {
  kg('kg'),
  lb('lb');

  const UniteCharges(this.label);
  final String label;
}

/// Une charge qui existe vraiment sur le matériel : sa valeur notée (kg), et
/// pour une pile, la plaque de la pile et les appoints ajoutés (dans l'unité
/// de la pile).
typedef Cran = ({double kg, double pile, List<double> appoints});

/// Les charges qu'on peut réellement mettre sur un exercice.
///
/// L'appli propose la charge d'après (fin de séance, programmes, boutons +/-)
/// en restant sur ce qui existe : la plaque suivante de la pile, l'haltère
/// suivant du râtelier, deux disques de plus. Les charges se notent toujours
/// en kilos ; une pile en livres se note avec le chiffre en kilos écrit sur
/// la plaque (130 lb : « 59 »), que [etiquetteLb] retrouve exactement. Avec
/// des disques, la charge notée reste celle des disques seuls : la barre ou le
/// chariot ([base]) n'est montré qu'à part.
class Graduation {
  /// Pile de plaques : `depart + n × pas` dans l'[unite] de la pile, plus les
  /// plaques d'[appoints] qu'on ajoute par-dessus (2,5 ou 5 lb).
  const Graduation.pile({this.unite = UniteCharges.lb, this.pas = 10, this.depart = 10, this.appoints = const []})
      : sorte = SorteCharges.pile,
        base = 0,
        chariot = false,
        liste = const [];

  /// Disques par paire : la charge avance de [pas] kg (deux disques de
  /// 1,25 kg). [base] : la barre (20 kg) ou le chariot de la presse
  /// ([chariot]), qui ne compte pas dans la charge notée.
  const Graduation.disques({this.pas = 2.5, this.base = 0, this.chariot = false})
      : sorte = SorteCharges.disques,
        unite = UniteCharges.kg,
        depart = 0,
        appoints = const [],
        liste = const [];

  /// Haltères : un par kilo jusqu'à 10 kg, puis de 2 en 2.
  const Graduation.halteres()
      : sorte = SorteCharges.halteres,
        unite = UniteCharges.kg,
        pas = 1,
        depart = 1,
        appoints = const [],
        base = 0,
        chariot = false,
        liste = const [];

  /// Kettlebells : les poids de [liste].
  const Graduation.kettlebell({this.liste = kettlebells})
      : sorte = SorteCharges.kettlebell,
        unite = UniteCharges.kg,
        pas = 2,
        depart = 4,
        appoints = const [],
        base = 0,
        chariot = false;

  /// Un pas fixe de [pas] kg, sans autre contrainte.
  const Graduation.libre({this.pas = 2.5})
      : sorte = SorteCharges.libre,
        unite = UniteCharges.kg,
        depart = 0,
        appoints = const [],
        base = 0,
        chariot = false,
        liste = const [];

  final SorteCharges sorte;

  /// Unité de la pile.
  final UniteCharges unite;

  /// Écart entre deux plaques de la pile (dans son unité), entre deux charges
  /// de disques, ou pas fixe (kg).
  final double pas;

  /// Première plaque de la pile (dans son unité) : les plaques valent
  /// `depart + n × pas`.
  final double depart;

  /// Plaques d'appoint de la pile (dans son unité), plus petites que [pas].
  final List<double> appoints;

  /// Barre ou chariot (kg), à part de la charge notée.
  final double base;

  /// Vrai quand [base] est le chariot d'une presse, pas une barre.
  final bool chariot;

  /// Poids des kettlebells (kg).
  final List<double> liste;

  /// Les kettlebells d'une salle bien garnie.
  static const kettlebells = <double>[4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 36, 40, 44, 48];

  /// Résistance du chariot de la presse à cuisses Matrix (Magnum MG-PL70) :
  /// 167 lb d'après la fiche technique.
  static const chariotPresse = 75.7;

  /// Écart admis entre une charge notée et la valeur d'une plaque : les kilos
  /// écrits sur les plaques sont arrondis, et pas toujours de la même façon.
  static const tolerance = 0.6;

  /// Les kilos écrits sur une plaque de [lb] livres : à l'entier au-dessus
  /// de 18 kg environ (130 lb : 59), au dixième en dessous, à partir du
  /// quart de kilo le plus proche (15 lb : 6,8 ; 30 lb : 13,5 ; 20 lb : 9).
  static double etiquetteLb(double lb) {
    final kg = lb * Fmt.kgParLb;
    if (kg >= 17.5) return kg.roundToDouble();
    final quart = (kg * 4).round() / 4;
    return (quart * 10).round() / 10;
  }

  /// Les kilos écrits sur une plaque d'appoint : au dixième (2,5 lb : 1,1 ;
  /// 5 lb : 2,3).
  static double etiquetteAppoint(double lb) => (lb * Fmt.kgParLb * 10).round() / 10;

  static double _r(double v) => (v * 100).round() / 100;

  /// Une plaque de la pile (ou un appoint) en kilos notés.
  double _kgPlaque(double v) => unite == UniteCharges.lb ? etiquetteLb(v) : v;
  double _kgAppoint(double v) => unite == UniteCharges.lb ? etiquetteAppoint(v) : v;

  /// Toutes les combinaisons d'appoints (chacun pris au plus une fois),
  /// sans la combinaison vide.
  List<List<double>> get _combinaisons {
    final a = [...appoints]..sort();
    final out = <List<double>>[];
    for (var m = 1; m < (1 << a.length); m++) {
      out.add([for (var i = 0; i < a.length; i++) if (m & (1 << i) != 0) a[i]]);
    }
    return out;
  }

  /// Les crans déjà calculés, par graduation (elles sont constantes).
  static final _cache = Expando<List<Cran>>();

  /// Les charges réelles d'une sorte à liste (pile, haltères, kettlebells),
  /// de la plus légère à la plus lourde. Vide pour les disques et le pas fixe.
  List<Cran> get crans => _cache[this] ??= _calculerCrans();

  List<Cran> _calculerCrans() {
    switch (sorte) {
      case SorteCharges.pile:
        final p = pas <= 0 ? 10.0 : pas;
        final d = depart <= 0 ? p : depart;
        final plafond = unite == UniteCharges.lb ? 600.0 : 300.0;
        final combis = _combinaisons;
        final out = <Cran>[];
        for (var v = d; v <= plafond + 1e-9; v += p) {
          final kg = _kgPlaque(v);
          out.add((kg: _r(kg), pile: v, appoints: const []));
          for (final c in combis) {
            out.add((kg: _r(kg + c.fold(0.0, (s, a) => s + _kgAppoint(a))), pile: v, appoints: c));
          }
        }
        out.sort((a, b) => a.kg != b.kg ? a.kg.compareTo(b.kg) : a.appoints.length.compareTo(b.appoints.length));
        // Deux façons de faire la même charge : la plus simple reste.
        final uniques = <Cran>[];
        for (final c in out) {
          if (uniques.isEmpty || (c.kg - uniques.last.kg).abs() > 0.05) uniques.add(c);
        }
        return uniques;
      case SorteCharges.halteres:
        return [
          for (var kg = 1.0; kg <= 10; kg++) (kg: kg, pile: kg, appoints: const <double>[]),
          for (var kg = 12.0; kg <= 120; kg += 2) (kg: kg, pile: kg, appoints: const <double>[]),
        ];
      case SorteCharges.kettlebell:
        final l = ([...liste]..sort());
        return [for (final kg in l) (kg: kg, pile: kg, appoints: const <double>[])];
      case SorteCharges.disques || SorteCharges.libre:
        return const [];
    }
  }

  bool get _aListe => sorte == SorteCharges.pile || sorte == SorteCharges.halteres || sorte == SorteCharges.kettlebell;

  /// Écart en deçà duquel une charge notée est « sur » une valeur de la liste.
  double get _tol => sorte == SorteCharges.pile && unite == UniteCharges.lb ? tolerance : 0.05;

  double get _pasKg => pas <= 0 ? 2.5 : pas;

  /// Indice du cran le plus proche de [kg] (le plus lourd à égalité).
  int _proche(double kg) {
    final l = crans;
    var best = 0;
    for (var i = 1; i < l.length; i++) {
      if ((l[i].kg - kg).abs() <= (l[best].kg - kg).abs() + 1e-9) best = i;
    }
    return best;
  }

  /// Le cran qui correspond à [kg], s'il y en a un à la tolérance près.
  Cran? cranDe(double kg) {
    if (!_aListe || crans.isEmpty) return null;
    final c = crans[_proche(kg)];
    return (c.kg - kg).abs() <= _tol + 1e-9 ? c : null;
  }

  /// La valeur réelle la plus proche de [kg].
  double arrondir(double kg) {
    switch (sorte) {
      case SorteCharges.disques:
        return math.max(0, _r((kg / _pasKg).round() * _pasKg));
      case SorteCharges.libre:
        return Strength.arrondir(kg, pas);
      default:
        return crans.isEmpty ? kg : crans[_proche(kg)].kg;
    }
  }

  /// La charge réelle juste au-dessus de [kg]. Sans [appoint], sur une pile,
  /// la plaque suivante de la pile sans plaque d'appoint (un vrai cran).
  double suivante(double kg, {bool appoint = true}) {
    switch (sorte) {
      case SorteCharges.disques:
        return _r(((kg + 1e-6) / _pasKg).floorToDouble() * _pasKg + _pasKg);
      case SorteCharges.libre:
        return Strength.arrondir(kg + pas, pas);
      default:
        final l = crans;
        if (l.isEmpty) return kg;
        final c = cranDe(kg);
        for (final x in l) {
          if (!appoint && x.appoints.isNotEmpty) continue;
          if (c != null ? (appoint ? x.kg > c.kg + 1e-9 : x.pile > c.pile + 1e-9) : x.kg > kg + 1e-9) return x.kg;
        }
        return l.last.kg > kg ? l.last.kg : kg;
    }
  }

  /// La charge réelle juste en dessous de [kg] (jamais sous zéro ni sous la
  /// plus légère).
  double precedente(double kg, {bool appoint = true}) {
    switch (sorte) {
      case SorteCharges.disques:
        return math.max(0, _r(((kg - 1e-6) / _pasKg).ceilToDouble() * _pasKg - _pasKg));
      case SorteCharges.libre:
        return math.max(0, Strength.arrondir(kg - pas, pas));
      default:
        final l = crans;
        if (l.isEmpty) return kg;
        final c = cranDe(kg);
        for (final x in l.reversed) {
          if (!appoint && x.appoints.isNotEmpty) continue;
          if (c != null ? (appoint ? x.kg < c.kg - 1e-9 : x.pile < c.pile - 1e-9) : x.kg < kg - 1e-9) return x.kg;
        }
        return l.first.kg;
    }
  }

  /// Un cran franc au-dessus de [kg], pour les grosses charges des jambes :
  /// une plaque de pile (sans appoint), 5 ou 10 kg de plus sur une presse
  /// (10 au-delà de 100 kg), deux pas de disques sur une barre.
  double grandSaut(double kg) {
    switch (sorte) {
      case SorteCharges.pile:
        return suivante(kg, appoint: false);
      case SorteCharges.disques:
        final saut = chariot ? (kg >= 100 ? 10.0 : 5.0) : 2 * _pasKg;
        return _r(((kg + saut - 1e-6) / _pasKg).ceilToDouble() * _pasKg);
      case SorteCharges.libre:
        return Strength.arrondir(kg + 2 * pas, pas);
      case SorteCharges.halteres || SorteCharges.kettlebell:
        return suivante(kg);
    }
  }

  /// Vrai pour une pile graduée en livres : la machine affiche une autre
  /// valeur que les kilos notés.
  bool get enLivres => sorte == SorteCharges.pile && unite == UniteCharges.lb;

  /// Ce qu'affiche la machine pour [kg] notés, sur une pile en livres :
  /// « 130 lb », « 105 lb (100 + 5) » avec un appoint. Null ailleurs, ou si
  /// [kg] ne tombe sur aucune plaque.
  String? libelleMachine(double kg) {
    if (!enLivres) return null;
    final c = cranDe(kg);
    if (c == null) return null;
    final total = c.pile + c.appoints.fold(0.0, (s, a) => s + a);
    if (c.appoints.isEmpty) return '${Fmt.n(total)} lb';
    return '${Fmt.n(total)} lb (${[c.pile, ...c.appoints].map((v) => Fmt.n(v)).join(' + ')})';
  }

  /// La charge totale avec la barre ou le chariot.
  double avecBase(double kg) => _r(kg + base);

  /// Ce que l'appli utilise, en clair : « Pile de 15 lb, appoint de 5 lb ».
  String get description {
    String n(double v) => Fmt.n(v, decimals: 2);
    switch (sorte) {
      case SorteCharges.pile:
        final u = unite.label;
        final a = [...appoints]..sort();
        final app = a.isEmpty ? '' : (a.length == 1 ? ', appoint de ${n(a.first)} $u' : ', appoints de ${a.map(n).join(' et ')} $u');
        return 'Pile de ${n(pas)} $u$app';
      case SorteCharges.disques:
        final b = base <= 0 ? '' : (chariot ? ', chariot de ${n(base)} kg' : ', barre de ${n(base)} kg');
        return 'Disques de ${n(pas)} en ${n(pas)} kg$b';
      case SorteCharges.halteres:
        return 'Haltères de 1 en 1 jusqu’à 10 kg, puis de 2 en 2';
      case SorteCharges.kettlebell:
        final l = [...liste]..sort();
        return 'Kettlebells : ${l.map(n).join(', ')} kg';
      case SorteCharges.libre:
        return 'Pas fixe de ${n(pas)} kg';
    }
  }

  Graduation copyWith({SorteCharges? sorte, UniteCharges? unite, double? pas, double? depart, List<double>? appoints, double? base, bool? chariot}) {
    switch (sorte ?? this.sorte) {
      case SorteCharges.pile:
        return Graduation.pile(unite: unite ?? this.unite, pas: pas ?? this.pas, depart: depart ?? this.depart, appoints: appoints ?? this.appoints);
      case SorteCharges.disques:
        return Graduation.disques(pas: pas ?? this.pas, base: base ?? this.base, chariot: chariot ?? this.chariot);
      case SorteCharges.halteres:
        return const Graduation.halteres();
      case SorteCharges.kettlebell:
        return Graduation.kettlebell(liste: liste.isEmpty ? kettlebells : liste);
      case SorteCharges.libre:
        return Graduation.libre(pas: pas ?? this.pas);
    }
  }

  Json toJson() => {
        'sorte': sorte.name,
        if (sorte == SorteCharges.pile) ...{'unite': unite.name, 'depart': depart, 'appoints': appoints},
        if (sorte != SorteCharges.halteres && sorte != SorteCharges.kettlebell) 'pas': pas,
        if (sorte == SorteCharges.disques) ...{'base': base, 'chariot': chariot},
        if (sorte == SorteCharges.kettlebell) 'liste': liste,
      };

  static List<double> _doubles(Object? v) => v is List ? v.map(asDouble).whereType<double>().toList() : const [];

  factory Graduation.fromJson(Json j) {
    final sorte = SorteCharges.values.where((s) => s.name == j['sorte']).firstOrNull ?? SorteCharges.libre;
    final pas = asDouble(j['pas']);
    switch (sorte) {
      case SorteCharges.pile:
        return Graduation.pile(
          unite: j['unite'] == 'kg' ? UniteCharges.kg : UniteCharges.lb,
          pas: pas ?? 10,
          depart: asDouble(j['depart']) ?? pas ?? 10,
          appoints: _doubles(j['appoints']),
        );
      case SorteCharges.disques:
        return Graduation.disques(pas: pas ?? 2.5, base: asDouble(j['base']) ?? 0, chariot: j['chariot'] == true);
      case SorteCharges.halteres:
        return const Graduation.halteres();
      case SorteCharges.kettlebell:
        final l = _doubles(j['liste']);
        return Graduation.kettlebell(liste: l.isEmpty ? kettlebells : l);
      case SorteCharges.libre:
        return Graduation.libre(pas: pas ?? 2.5);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Graduation &&
      other.sorte == sorte &&
      other.unite == unite &&
      other.pas == pas &&
      other.depart == depart &&
      other.base == base &&
      other.chariot == chariot &&
      _memes(other.appoints, appoints) &&
      _memes(other.liste, liste);

  static bool _memes(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    final x = [...a]..sort(), y = [...b]..sort();
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(sorte, unite, pas, depart, base, chariot, appoints.length, liste.length);

  @override
  String toString() => 'Graduation($description, départ ${Fmt.n(depart)})';
}

/// D'où vient la graduation retenue pour un exercice.
enum OrigineCharges {
  /// Choisie sur la fiche de l'exercice.
  reglage('réglé à la main'),

  /// Devinée d'après les charges notées dans les séances.
  deduite('déduit de tes séances'),

  /// Faute d'historique, d'après le matériel de l'exercice.
  materiel('d’après le matériel');

  const OrigineCharges(this.label);
  final String label;
}

/// Deviner la graduation d'un exercice.
abstract final class Graduations {
  /// Charges distinctes qu'il faut au moins pour déduire une pile.
  static const minimum = 3;

  /// La graduation selon le matériel de [ex], sans rien savoir de plus :
  /// machine et poulie, une pile de 10 lb ; presse, des disques et le
  /// chariot ; barre, machine guidée, disque, des disques ; haltères ;
  /// kettlebells ; sinon le pas fixe [pas] des réglages.
  static Graduation parDefaut(Exercise? ex, {double pas = 2.5}) {
    final pasLibre = pas <= 0 ? 2.5 : pas;
    if (ex == null) return Graduation.libre(pas: pasLibre);
    final m = {...ex.materiels, ex.famille, ex.equipement};
    if (ex.auxHalteres) return const Graduation.halteres();
    if (m.contains('kettlebell')) return const Graduation.kettlebell();
    if (m.contains('presse')) return Graduation.disques(pas: pasLibre, base: Graduation.chariotPresse, chariot: true);
    if (m.contains('machine') || m.contains('poulie')) return const Graduation.pile(pas: 10, depart: 10);
    if (m.contains('barre')) return Graduation.disques(pas: pasLibre, base: 20);
    if (m.contains('barre ez')) return Graduation.disques(pas: pasLibre, base: 10);
    if (m.contains('smith') || m.contains('disque') || m.contains('barre trapeze')) return Graduation.disques(pas: pasLibre);
    return Graduation.libre(pas: pasLibre);
  }

  /// Vrai pour un exercice dont la charge sort d'une pile à goupille.
  static bool aPile(Exercise? ex) {
    if (ex == null) return false;
    final m = {...ex.materiels, ex.famille, ex.equipement};
    return !m.contains('presse') && (m.contains('machine') || m.contains('poulie'));
  }

  /// La graduation de [ex] d'après ses [charges] notées (une par séance et
  /// par charge : une charge faite sur quatre séries d'une même séance ne
  /// compte qu'une fois), sinon [parDefaut]. Haltères et kettlebells ne se
  /// déduisent pas : le râtelier est le même partout.
  static ({Graduation graduation, OrigineCharges origine}) pour(Exercise? ex, Iterable<double> charges, {double pas = 2.5}) {
    final defaut = parDefaut(ex, pas: pas);
    if (defaut.sorte == SorteCharges.halteres || defaut.sorte == SorteCharges.kettlebell) return (graduation: defaut, origine: OrigineCharges.materiel);
    final d = deduire(charges, machine: aPile(ex));
    return d == null ? (graduation: defaut, origine: OrigineCharges.materiel) : (graduation: d, origine: OrigineCharges.deduite);
  }

  /// Sur la grille des kilos ronds (multiples de 1,25 kg) ?
  static bool _surGrilleKg(double v) => (v / 1.25 - (v / 1.25).round()).abs() * 1.25 <= 0.03;

  /// Près d'une plaque de 5 lb en 5 lb ?
  static bool _procheLb(double v) {
    final lb = (v / Fmt.kgParLb / 5).round() * 5.0;
    for (final l in [lb - 5, lb, lb + 5]) {
      if (l > 0 && (Graduation.etiquetteLb(l) - v).abs() <= Graduation.tolerance) return true;
    }
    return false;
  }

  /// Les charges distinctes, sans les valeurs isolées aberrantes : une
  /// charge vue une seule fois, très loin de toutes les autres (un 80 kg
  /// fait dans une autre salle au milieu de charges de 18 à 54 kg).
  static List<double> retenues(Iterable<double> charges) {
    final compte = <double, int>{};
    for (final c in charges) {
      if (c <= 0) continue;
      final v = (c * 10).round() / 10;
      compte[v] = (compte[v] ?? 0) + 1;
    }
    final valeurs = compte.keys.toList()..sort();
    return [
      for (final v in valeurs)
        if (compte[v]! > 1 || valeurs.length < 2 || valeurs.where((x) => x != v).map((x) => (x - v).abs()).reduce(math.min) <= math.max(8.0, v * 0.25)) v,
    ];
  }

  /// Le nombre de [valeurs] qui tombent sur une plaque d'une pile
  /// (sans appoint).
  static int _expliquees(Graduation g, List<double> valeurs) => valeurs.where((v) {
        final c = g.cranDe(v);
        return c != null && c.appoints.isEmpty;
      }).length;

  /// La pile la plus grossière (20, 15, 10, 5 lb ; 10, 5, 2,5, 1,25 kg) qui
  /// explique la majorité des [valeurs] avec un même départ. Une pile plus
  /// fine explique toujours au moins autant : la plus grossière doit aussi
  /// en expliquer presque autant (70 %), sinon une pile de 10 lb dont on n'a
  /// fait que les dizaines paires passerait pour une pile de 20.
  static Graduation? _pile(List<double> valeurs, UniteCharges unite) {
    final pasPossibles = unite == UniteCharges.lb ? const [20.0, 15.0, 10.0, 5.0] : const [10.0, 5.0, 2.5, 1.25];
    final grain = unite == UniteCharges.lb ? 5.0 : 1.25;
    final meilleures = <(Graduation, int)>[];
    for (final pas in pasPossibles) {
      Graduation? meilleure;
      var score = 0;
      // Les départs possibles : de la plus petite plaque à un pas au-dessus.
      for (var o = grain; o <= pas + 1e-9; o += grain) {
        final g = Graduation.pile(unite: unite, pas: pas, depart: o);
        final n = _expliquees(g, valeurs);
        if (n > score) {
          score = n;
          meilleure = g;
        }
      }
      if (meilleure != null) meilleures.add((meilleure, score));
    }
    if (meilleures.isEmpty) return null;
    final max = meilleures.map((m) => m.$2).reduce(math.max);
    for (final (g, score) in meilleures) {
      if (score * 2 > valeurs.length && score >= max * 0.7) return g;
    }
    return null;
  }

  /// Devine une pile d'après les charges notées : en livres si la majorité
  /// des charges distinctes tombent sur des plaques de 5 lb sans être des
  /// kilos ronds ; le pas est le plus grand qui explique la majorité avec un
  /// même départ ; les appoints sont ceux qu'on voit (une plaque de la pile
  /// plus 2,5 ou 5 lb). Sur une [machine] notée en kilos ronds, une pile en
  /// kilos. Null quand l'historique ne suffit pas ou ne dit rien de net.
  static Graduation? deduire(Iterable<double> charges, {bool machine = false}) {
    final valeurs = retenues(charges);
    if (valeurs.length < minimum) return null;
    final enLb = valeurs.where((v) => _procheLb(v) && !_surGrilleKg(v)).length;
    if (enLb * 2 > valeurs.length) {
      final g = _pile(valeurs, UniteCharges.lb);
      if (g == null) return null;
      // Les appoints : ce qui tombe à 2,5 ou 5 lb au-dessus d'une plaque.
      final vus = <double>{};
      for (final v in valeurs) {
        final c = g.cranDe(v);
        if (c != null && c.appoints.isEmpty) continue;
        double? retenu;
        var ecart = 0.35;
        for (final x in g.crans) {
          for (final a in const [2.5, 5.0]) {
            final e = (x.kg + Graduation.etiquetteAppoint(a) - v).abs();
            if (x.appoints.isEmpty && e <= ecart) {
              ecart = e;
              retenu = a;
            }
          }
        }
        if (retenu != null) vus.add(retenu);
      }
      return g.copyWith(appoints: vus.toList()..sort());
    }
    if (machine && valeurs.where(_surGrilleKg).length * 2 > valeurs.length) return _pile(valeurs, UniteCharges.kg);
    return null;
  }
}
