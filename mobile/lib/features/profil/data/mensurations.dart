import 'dart:ui' show Offset;

import 'package:intl/intl.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Les huit mesures de l'écran Mensurations. Chacune regroupe un ou deux
/// tours du modèle (gauche et droite) et vise une zone du corps de face.
enum ZoneMesure {
  cou('Cou', 'Sous la pomme d\'Adam', [TourCorps.cou], true, Offset(0.435, 0.142), 38),
  poitrine('Poitrine', 'Au niveau des pectoraux', [TourCorps.poitrine], true, Offset(0.351, 0.232), 100),
  taille('Taille', 'Au niveau du nombril', [TourCorps.taille], true, Offset(0.333, 0.398), 82),
  cuisses('Cuisses', 'Au plus large de la cuisse', [TourCorps.cuisseGauche, TourCorps.cuisseDroite], true, Offset(0.333, 0.658), 56),
  epaules('Épaules', 'Tour complet, au plus large', [TourCorps.epaules], false, Offset(0.834, 0.193), 115),
  biceps('Biceps', 'Bras contracté', [TourCorps.brasGauche, TourCorps.brasDroit], false, Offset(0.797, 0.287), 35),
  avantBras('Avant-bras', 'Au plus large, poing serré', [TourCorps.avantBrasGauche, TourCorps.avantBrasDroit], false, Offset(0.844, 0.406), 29),
  mollets('Mollets', 'Au plus large du mollet', [TourCorps.molletGauche, TourCorps.molletDroit], false, Offset(0.686, 0.831), 37);

  const ZoneMesure(this.label, this.precision, this.tours, this.aGauche, this.ancre, this.defaut);

  final String label;

  /// Où poser le mètre ruban.
  final String precision;
  final List<TourCorps> tours;

  /// Étiquette à gauche du corps (sinon à droite).
  final bool aGauche;

  /// Point visé sur l'image du corps de face, en fractions de sa largeur
  /// et de sa hauteur.
  final Offset ancre;

  /// Valeur de départ quand la zone n'a jamais été mesurée, en cm.
  final double defaut;

  static List<ZoneMesure> get gauche => [cou, poitrine, taille, cuisses];
  static List<ZoneMesure> get droite => [epaules, biceps, avantBras, mollets];

  /// Ordre du formulaire de saisie, de haut en bas du corps.
  static List<ZoneMesure> get ordreSaisie => [cou, epaules, poitrine, biceps, avantBras, taille, cuisses, mollets];

  static ZoneMesure? parNom(String? nom) => values.where((z) => z.name == nom).firstOrNull;
}

/// Une valeur datée, liée à sa saisie.
typedef PointMesure = ({String id, DateTime date, double valeur});

/// Dernière valeur d'une zone et écart depuis la première saisie.
class EtatZone {
  const EtatZone({this.derniere, this.premiere});
  final PointMesure? derniere;
  final PointMesure? premiere;

  /// Null quand la mesure n'a pas bougé (on n'affiche alors rien).
  double? get ecart => derniere == null || premiere == null ? null : Mensurations.ecart(premiere!.valeur, derniere!.valeur);
}

/// Périodes de l'écran d'une mesure.
enum PeriodeMesure {
  troisMois('3 mois', 3),
  sixMois('6 mois', 6),
  unAn('1 an', 12),
  tout('Tout', null);

  const PeriodeMesure(this.label, this.mois);
  final String label;
  final int? mois;

  /// Début de la période, null pour tout l'historique.
  DateTime? debut(DateTime maintenant) {
    if (mois == null) return null;
    // Un 31 mai moins trois mois : le 28 février, pas le 3 mars.
    final premier = DateTime(maintenant.year, maintenant.month - mois!);
    final dernierJour = DateTime(premier.year, premier.month + 1, 0).day;
    return DateTime(premier.year, premier.month, maintenant.day < dernierJour ? maintenant.day : dernierJour);
  }
}

/// Bilan entre deux photos : poids à chaque date, écart, mesure qui a le
/// plus bougé.
class Comparaison {
  const Comparaison({this.poidsAvant, this.poidsApres, required this.semaines, this.zone, this.ecartZone});
  final double? poidsAvant;
  final double? poidsApres;
  final int semaines;
  final ZoneMesure? zone;
  final double? ecartZone;

  double? get ecartKg => poidsAvant == null || poidsApres == null ? null : Mensurations.ecart(poidsAvant!, poidsApres!);
}

/// Calculs des mensurations, sans écran.
abstract final class Mensurations {
  static double _arrondi(double v) => (v * 10).round() / 10;

  /// Valeur d'une zone dans une saisie : la moyenne des côtés mesurés.
  static double? valeur(BodyMeasurement m, ZoneMesure z) {
    final vs = [for (final t in z.tours) if (m.tours[t] != null) m.tours[t]!];
    if (vs.isEmpty) return null;
    return _arrondi(vs.reduce((a, b) => a + b) / vs.length);
  }

  /// Nombre de zones mesurées dans une saisie.
  static int nbMesures(BodyMeasurement m) => ZoneMesure.values.where((z) => valeur(m, z) != null).length;

  /// Saisies de la plus récente à la plus ancienne.
  static List<BodyMeasurement> historique(Iterable<BodyMeasurement> ms) => [...ms]..sort((a, b) => b.date.compareTo(a.date));

  /// Valeurs d'une zone, de la plus ancienne à la plus récente.
  static List<PointMesure> serie(Iterable<BodyMeasurement> ms, ZoneMesure z, {DateTime? depuis}) {
    final out = <PointMesure>[
      for (final m in ms)
        if (valeur(m, z) != null && (depuis == null || !m.date.isBefore(depuis))) (id: m.id, date: m.date, valeur: valeur(m, z)!),
    ];
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Poids, du plus ancien au plus récent.
  static List<PointMesure> seriePoids(Iterable<BodyMeasurement> ms, {DateTime? depuis}) {
    final out = <PointMesure>[
      for (final m in ms)
        if (m.poidsKg != null && (depuis == null || !m.date.isBefore(depuis))) (id: m.id, date: m.date, valeur: m.poidsKg!),
    ];
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Taux de gras, du plus ancien au plus récent.
  static List<PointMesure> serieGras(Iterable<BodyMeasurement> ms) {
    final out = <PointMesure>[
      for (final m in ms)
        if (m.masseGrassePct != null) (id: m.id, date: m.date, valeur: m.masseGrassePct!),
    ];
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Écart entre deux valeurs, null quand rien n'a bougé.
  static double? ecart(double avant, double apres) {
    final d = _arrondi(apres - avant);
    return d.abs() < 0.05 ? null : d;
  }

  /// « +1,5 » ou « −0,5 » ; null quand il n'y a rien à afficher.
  static String? ecartTexte(double? e, {String unite = ''}) {
    if (e == null || e.abs() < 0.05) return null;
    final s = '${e > 0 ? '+' : '−'}${Fmt.n(e.abs())}';
    return unite.isEmpty ? s : '$s $unite';
  }

  static EtatZone etat(Iterable<BodyMeasurement> ms, ZoneMesure z) {
    final s = serie(ms, z);
    return s.isEmpty ? const EtatZone() : EtatZone(derniere: s.last, premiere: s.first);
  }

  /// Nombre de zones déjà mesurées au moins une fois.
  static int nbZones(Iterable<BodyMeasurement> ms) => ZoneMesure.values.where((z) => ms.any((m) => valeur(m, z) != null)).length;

  /// Écart de chaque valeur avec la saisie d'avant (null si inchangée ou
  /// première). [serie] du plus ancien au plus récent.
  static List<double?> ecartsSuccessifs(List<PointMesure> serie) => [
        for (var i = 0; i < serie.length; i++) i == 0 ? null : ecart(serie[i - 1].valeur, serie[i].valeur),
      ];

  /// Nombre moyen de jours entre deux saisies, null avec moins de deux.
  static int? joursEntreSaisies(Iterable<BodyMeasurement> ms) {
    final jours = {for (final m in ms) Dates.jour(m.date)}.toList()..sort();
    if (jours.length < 2) return null;
    return (jours.last.difference(jours.first).inHours / 24 / (jours.length - 1)).round();
  }

  /// Saisie du même jour, autre que [saufId].
  static BodyMeasurement? duJour(Iterable<BodyMeasurement> ms, DateTime jour, {String? saufId}) =>
      ms.where((m) => m.id != saufId && Dates.memeJour(m.date, jour)).firstOrNull;

  /// Poids connu à une date : la dernière pesée jusqu'à ce jour, sinon la
  /// première d'après.
  static double? poidsA(Iterable<BodyMeasurement> ms, DateTime date) {
    final s = seriePoids(ms);
    if (s.isEmpty) return null;
    final fin = Dates.jour(date).add(const Duration(days: 1));
    final avant = s.where((p) => p.date.isBefore(fin));
    return avant.isNotEmpty ? avant.last.valeur : s.first.valeur;
  }

  /// Écart maximal, en jours, entre une photo et la pesée qu'on lui associe.
  static const joursPoidsPhoto = 7;

  /// Pesée la plus proche d'une date, avant ou après ; null s'il n'y en a
  /// aucune à [joursMax] jours ou moins. À écart égal, la pesée d'avant.
  static double? poidsProche(Iterable<BodyMeasurement> ms, DateTime date, {int joursMax = joursPoidsPhoto}) {
    final jour = Dates.jour(date);
    int ecart(PointMesure p) => (Dates.jour(p.date).difference(jour).inHours / 24).round().abs();
    PointMesure? proche;
    // La série va du plus ancien au plus récent : jusqu'au jour visé, la
    // dernière pesée gagne à écart égal ; après, la première.
    for (final p in seriePoids(ms)) {
      if (ecart(p) > joursMax) continue;
      if (proche == null || ecart(p) < ecart(proche) || (ecart(p) == ecart(proche) && !Dates.jour(p.date).isAfter(jour))) proche = p;
    }
    return proche?.valeur;
  }

  /// Poids affiché à côté d'une photo : celui noté à la prise de vue,
  /// sinon la pesée la plus proche de sa date.
  static double? poidsPhoto(ProgressPhoto p, Iterable<BodyMeasurement> ms) => p.poidsKg ?? poidsProche(ms, p.date);

  /// Valeur d'une zone connue à une date (dernière saisie jusqu'à ce jour).
  static double? valeurA(Iterable<BodyMeasurement> ms, ZoneMesure z, DateTime date) {
    final fin = Dates.jour(date).add(const Duration(days: 1));
    final s = serie(ms, z).where((p) => p.date.isBefore(fin));
    return s.isEmpty ? null : s.last.valeur;
  }

  /// Bilan entre deux photos. Les deux dates sont remises dans l'ordre.
  static Comparaison comparer(ProgressPhoto a, ProgressPhoto b, Iterable<BodyMeasurement> ms) {
    final avant = a.date.isAfter(b.date) ? b : a;
    final apres = identical(avant, a) ? b : a;
    ZoneMesure? zone;
    double? meilleur;
    for (final z in ZoneMesure.values) {
      final v1 = valeurA(ms, z, avant.date);
      final v2 = valeurA(ms, z, apres.date);
      if (v1 == null || v2 == null) continue;
      final d = ecart(v1, v2);
      if (d != null && (meilleur == null || d.abs() > meilleur.abs())) {
        meilleur = d;
        zone = z;
      }
    }
    final jours = Dates.jour(apres.date).difference(Dates.jour(avant.date)).inHours / 24;
    return Comparaison(
      poidsAvant: poidsPhoto(avant, ms),
      poidsApres: poidsPhoto(apres, ms),
      semaines: (jours / 7).round(),
      zone: zone,
      ecartZone: meilleur,
    );
  }

  /// Temps écoulé entre deux dates : « 4 jours », « 15 semaines » ; null
  /// quand les deux dates tombent le même jour.
  static String? duree(DateTime avant, DateTime apres) {
    final jours = (Dates.jour(apres).difference(Dates.jour(avant)).inHours / 24).round().abs();
    if (jours == 0) return null;
    return jours < 7 ? Fmt.pluriel(jours, 'jour') : Fmt.pluriel((jours / 7).round(), 'semaine');
  }

  /// Photos d'un angle, la plus récente d'abord.
  static List<ProgressPhoto> photosDe(Iterable<ProgressPhoto> photos, PhotoVue vue) =>
      photos.where((p) => p.vue == vue).toList()..sort((a, b) => b.date.compareTo(a.date));

  // Dates de la maquette.

  /// « 28 septembre », avec l'année si ce n'est pas celle en cours.
  static String jourLong(DateTime d, {DateTime? maintenant}) =>
      DateFormat((maintenant ?? DateTime.now()).year == d.year ? 'd MMMM' : 'd MMMM y', 'fr_FR').format(d);

  /// « 14 juin 2025 », toujours avec l'année.
  static String jourComplet(DateTime d) => DateFormat('d MMMM y', 'fr_FR').format(d);

  /// « 28 sept. 2026 ».
  static String jourCourt(DateTime d) => DateFormat('d MMM y', 'fr_FR').format(d);

  /// « 28 sept. », avec l'année si ce n'est pas celle en cours.
  static String etiquette(DateTime d, {DateTime? maintenant}) =>
      DateFormat((maintenant ?? DateTime.now()).year == d.year ? 'd MMM' : 'd MMM y', 'fr_FR').format(d);

  /// « juin », avec l'année si ce n'est pas celle en cours.
  static String moisDe(DateTime d, {DateTime? maintenant}) =>
      DateFormat((maintenant ?? DateTime.now()).year == d.year ? 'MMMM' : 'MMMM y', 'fr_FR').format(d);
}

/// Un champ du formulaire de saisie.
class ChampSaisie {
  const ChampSaisie({required this.cle, required this.label, required this.unite, required this.pas, required this.defaut, this.zone, this.min = 0, this.max = 400, this.facteur = 1});

  final String cle;
  final String label;
  final String unite;

  /// Pas des boutons « − » et « + ».
  final double pas;
  final double defaut;
  final ZoneMesure? zone;
  final double min;
  final double max;

  /// Valeur stockée = valeur affichée × facteur (livres vers kilos).
  final double facteur;

  static const clePoids = 'poids';
  static const cleGras = 'gras';

  /// Les champs du formulaire, dans l'ordre : poids, taux de gras, puis les
  /// huit tours.
  static List<ChampSaisie> tous({UnitePoids unite = UnitePoids.kg, double? poidsProfilKg}) {
    final f = unite == UnitePoids.kg ? 1.0 : Fmt.kgParLb;
    return [
      ChampSaisie(cle: clePoids, label: 'Poids', unite: unite.label, pas: 0.1, defaut: (poidsProfilKg ?? 75) / f, min: 20, max: 700, facteur: f),
      const ChampSaisie(cle: cleGras, label: 'Taux de gras', unite: '%', pas: 0.1, defaut: 15, min: 2, max: 70),
      for (final z in ZoneMesure.ordreSaisie)
        Affichage.pouces
            ? ChampSaisie(cle: z.name, label: z.label, unite: 'po', pas: 0.25, defaut: (z.defaut / Affichage.cmParPouce * 4).round() / 4, zone: z, min: 2, max: 100, facteur: Affichage.cmParPouce)
            : ChampSaisie(cle: z.name, label: z.label, unite: 'cm', pas: 0.5, defaut: z.defaut, zone: z, min: 5, max: 250),
    ];
  }
}

/// Saisie en cours : sert à créer une saisie comme à en corriger une.
class BrouillonSaisie {
  BrouillonSaisie._(this.champs, this.origine, this.date, this.valeurs, this.saisis);

  /// Nouvelle saisie : chaque champ reprend la dernière valeur connue, en
  /// attente (elle n'est enregistrée que si on la touche).
  factory BrouillonSaisie.nouvelle(List<ChampSaisie> champs, Iterable<BodyMeasurement> historique, {DateTime? date}) =>
      BrouillonSaisie._(champs, null, date ?? DateTime.now(), _dernieres(champs, historique), {});

  /// Correction d'une saisie : ses valeurs sont déjà retenues.
  factory BrouillonSaisie.depuis(List<ChampSaisie> champs, BodyMeasurement m, Iterable<BodyMeasurement> historique) {
    final v = _dernieres(champs, historique);
    final saisis = <String>{};
    for (final c in champs) {
      final x = _lire(m, c);
      if (x != null) {
        v[c.cle] = x;
        saisis.add(c.cle);
      }
    }
    return BrouillonSaisie._(champs, m, m.date, v, saisis);
  }

  final List<ChampSaisie> champs;
  final BodyMeasurement? origine;
  DateTime date;

  /// Valeurs affichées, dans l'unité du champ.
  final Map<String, double> valeurs;

  /// Champs retenus pour l'enregistrement.
  final Set<String> saisis;

  bool get modification => origine != null;
  bool get vide => saisis.isEmpty;

  static double? _lire(BodyMeasurement m, ChampSaisie c) {
    final v = switch (c.cle) {
      ChampSaisie.clePoids => m.poidsKg,
      ChampSaisie.cleGras => m.masseGrassePct,
      _ => Mensurations.valeur(m, c.zone!),
    };
    return v == null ? null : _net(v / c.facteur);
  }

  static double _net(double v) => (v * 10).round() / 10;

  static Map<String, double> _dernieres(List<ChampSaisie> champs, Iterable<BodyMeasurement> historique) {
    final h = Mensurations.historique(historique);
    final out = <String, double>{};
    for (final c in champs) {
      for (final m in h) {
        final v = _lire(m, c);
        if (v != null) {
          out[c.cle] = v;
          break;
        }
      }
    }
    return out;
  }

  /// Valeur affichée d'un champ (la dernière connue, sinon celle de départ).
  double valeur(ChampSaisie c) => valeurs[c.cle] ?? _net(c.defaut);

  bool estSaisi(ChampSaisie c) => saisis.contains(c.cle);

  /// Un cran vers le haut ([sens] = 1) ou le bas (−1), sur la grille du pas.
  void cran(ChampSaisie c, int sens) {
    final crans = valeur(c) / c.pas;
    final proche = crans.roundToDouble();
    final surGrille = (crans - proche).abs() < 1e-6;
    final cible = surGrille ? proche + sens : (sens > 0 ? crans.ceilToDouble() : crans.floorToDouble());
    fixer(c, cible * c.pas);
  }

  /// Valeur tapée au clavier.
  void fixer(ChampSaisie c, double v) {
    valeurs[c.cle] = _net(v.clamp(c.min, c.max).toDouble());
    saisis.add(c.cle);
  }

  /// Retire un champ de la saisie.
  void retirer(ChampSaisie c) => saisis.remove(c.cle);

  /// La saisie à enregistrer. [fusion] : saisie déjà présente ce jour-là,
  /// complétée plutôt que doublée. Les tours hors formulaire (hanches) et
  /// la différence gauche et droite d'une zone non modifiée sont gardés.
  BodyMeasurement construire({BodyMeasurement? fusion}) {
    final base = origine ?? fusion;
    final tours = <TourCorps, double>{...?base?.tours};
    double? poids = origine == null ? fusion?.poidsKg : null;
    double? gras = origine == null ? fusion?.masseGrassePct : null;
    for (final c in champs) {
      final retenu = saisis.contains(c.cle);
      final v = retenu ? _net(valeurs[c.cle]! * c.facteur * 100) / 100 : null;
      switch (c.cle) {
        case ChampSaisie.clePoids:
          if (retenu) {
            // Sans changement à l'écran, on garde le poids exact d'origine.
            final avant = origine == null ? null : _lire(origine!, c);
            poids = avant == valeurs[c.cle] ? origine!.poidsKg : v;
          }
        case ChampSaisie.cleGras:
          if (retenu) gras = v;
        default:
          final z = c.zone!;
          if (!retenu) {
            if (origine != null) {
              for (final t in z.tours) {
                tours.remove(t);
              }
            }
            continue;
          }
          final avant = base == null ? null : Mensurations.valeur(base, z);
          if (avant != null && (avant - v!).abs() < 0.05) continue;
          for (final t in z.tours) {
            tours[t] = v!;
          }
      }
    }
    final jour = base != null && Dates.memeJour(base.date, date) ? base.date : DateTime(date.year, date.month, date.day, 12);
    return BodyMeasurement(
      id: base?.id ?? '',
      date: jour,
      poidsKg: poids,
      masseGrassePct: gras,
      masseMusculaireKg: base?.masseMusculaireKg,
      tours: tours,
      source: base?.source ?? 'manuel',
    );
  }
}

/// Saisie déjà présente le jour visé par [b], avec laquelle il sera réuni :
/// nouvelle saisie un jour déjà saisi, ou saisie déplacée sur un tel jour.
BodyMeasurement? saisieAReunir(Iterable<BodyMeasurement> ms, BrouillonSaisie b) {
  final o = b.origine;
  if (o != null && Dates.memeJour(o.date, b.date)) return null;
  return Mensurations.duJour(ms, b.date, saufId: o?.id);
}

/// Enregistre la saisie en cours. Une seule saisie par jour : une nouvelle
/// saisie complète celle du jour ; une saisie déplacée sur un jour déjà
/// saisi est réunie avec elle (ses valeurs priment, le reste est gardé).
Future<BodyMeasurement> enregistrerSaisie(HealthRepo sante, BrouillonSaisie b) async {
  final autre = saisieAReunir(sante.measurements, b);
  if (!b.modification) return sante.saveMeasurement(b.construire(fusion: autre));
  final m = b.construire();
  if (autre == null) return sante.saveMeasurement(m);
  final tours = <TourCorps, double>{...autre.tours};
  for (final z in ZoneMesure.values) {
    // Une zone portée par la saisie déplacée remplace les deux côtés.
    if (z.tours.any(m.tours.containsKey)) z.tours.forEach(tours.remove);
  }
  tours.addAll(m.tours);
  final r = await sante.saveMeasurement(BodyMeasurement(
    id: m.id,
    date: autre.date,
    poidsKg: m.poidsKg ?? autre.poidsKg,
    masseGrassePct: m.masseGrassePct ?? autre.masseGrassePct,
    masseMusculaireKg: m.masseMusculaireKg ?? autre.masseMusculaireKg,
    tours: tours,
    source: m.source ?? autre.source,
  ));
  await sante.deleteMeasurement(autre.id);
  return r;
}
