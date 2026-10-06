import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/models/models.dart';

/// Jeu de données de la maquette : neuf saisies de juin à fin septembre
/// 2026, quatorze photos.
abstract final class JeuMaquette {
  static final dates = [
    DateTime(2026, 6, 8, 8),
    DateTime(2026, 6, 22, 8),
    DateTime(2026, 7, 6, 8),
    DateTime(2026, 7, 20, 8),
    DateTime(2026, 8, 3, 8),
    DateTime(2026, 8, 17, 8),
    DateTime(2026, 8, 31, 8),
    DateTime(2026, 9, 14, 8),
    DateTime(2026, 9, 28, 8),
  ];

  static const _poids = [74.1, 74.3, 74.6, 74.8, 75.1, 75.4, 75.9, 76.2, 76.7];
  static const _gras = [15.0, 14.9, 14.8, 14.7, 14.6, 14.5, 14.4, 14.3, 14.2];
  static const _cou = [38.5, 38.5, 38.5, 38.5, 39.0, 39.0, 39.0, 39.0, 39.0];
  static const _epaules = [119.0, 119.5, 120.0, 120.0, 120.5, 120.5, 121.0, 121.0, 122.0];
  static const _poitrine = [102.0, 102.0, 102.5, 102.5, 103.0, 103.0, 103.5, 103.5, 104.0];
  static const _biceps = [36.5, 36.5, 36.5, 36.5, 36.5, 37.0, 37.0, 37.5, 38.0];
  static const _avantBras = [30.5, 30.5, 30.5, 30.5, 30.5, 30.5, 31.0, 31.0, 31.0];
  static const _taille = [82.0, 82.0, 82.0, 82.0, 82.0, 82.0, 82.0, 82.0, 82.0];
  static const _cuisses = [57.0, 57.0, 57.5, 57.5, 58.0, 58.0, 58.5, 58.5, 59.0];
  static const _mollets = [37.0, 37.0, 37.0, 37.5, 37.5, 37.5, 37.5, 38.0, 38.0];

  static List<BodyMeasurement> mesures() => [
        for (var i = 0; i < dates.length; i++)
          BodyMeasurement(
            id: 'm$i',
            date: dates[i],
            poidsKg: _poids[i],
            masseGrassePct: _gras[i],
            tours: {
              TourCorps.cou: _cou[i],
              TourCorps.epaules: _epaules[i],
              TourCorps.poitrine: _poitrine[i],
              TourCorps.brasGauche: _biceps[i],
              TourCorps.brasDroit: _biceps[i],
              TourCorps.taille: _taille[i],
              TourCorps.cuisseGauche: _cuisses[i],
              TourCorps.cuisseDroite: _cuisses[i],
              // Le 17 août : six mesures seulement.
              if (i != 5) ...{
                TourCorps.avantBrasGauche: _avantBras[i],
                TourCorps.avantBrasDroit: _avantBras[i],
                TourCorps.molletGauche: _mollets[i],
                TourCorps.molletDroit: _mollets[i],
              },
            },
            source: 'manuel',
          ),
      ];

  static List<ProgressPhoto> photos() {
    ProgressPhoto p(String id, DateTime d, PhotoVue v) => ProgressPhoto(id: id, date: d, chemin: 'absente/$id.jpg', vue: v);
    final face = [DateTime(2026, 9, 28), DateTime(2026, 9, 14), DateTime(2026, 8, 31), DateTime(2026, 8, 17), DateTime(2026, 7, 20), DateTime(2026, 6, 14)];
    final autres = [DateTime(2026, 9, 28), DateTime(2026, 8, 31), DateTime(2026, 7, 20), DateTime(2026, 6, 14)];
    return [
      for (final (i, d) in face.indexed) p('f$i', d, PhotoVue.face),
      for (final (i, d) in autres.indexed) p('p$i', d, PhotoVue.profil),
      for (final (i, d) in autres.indexed) p('d$i', d, PhotoVue.dos),
    ];
  }

  /// Remplace les mesures et les photos du dépôt par celles de la maquette.
  static Future<void> poser(HealthRepo sante) async {
    for (final m in [...sante.measurements]) {
      await sante.deleteMeasurement(m.id);
    }
    for (final p in [...sante.photos]) {
      await sante.deletePhoto(p.id);
    }
    await sante.addMeasurementsAll(mesures());
    for (final p in photos()) {
      await sante.savePhoto(p);
    }
  }
}
