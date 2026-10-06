import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import 'analyse.dart';

/// Graine de l'équivalent d'une séance : la même partout (carte de fin de
/// séance, carte de partage) et d'un lancement à l'autre.
int graineEquivalent(WorkoutSession s) => (s.debut.millisecondsSinceEpoch ~/ 1000).abs() % 1000003;

/// L'équivalent d'une séance, toujours le même pour une séance donnée.
Equivalent equivalentDeSeance(WorkoutSession s) => equivalentPour(s.volume, graine: graineEquivalent(s));

/// Lignes « 4 × Mollets assis » de la carte « détail » : une par exercice
/// qui a au moins une série faite, dans l'ordre de la séance. Comme partout,
/// les échauffements ne comptent pas dans le nombre de séries.
List<String> lignesDetail(WorkoutSession s, ExerciseRepo exos, {int max = 8}) {
  int comptees(SessionExercise e) => e.seriesFaites.where((x) => x.type.counts).length;
  final lignes = <String>[
    for (final e in s.exercices)
      if (comptees(e) > 0) '${comptees(e)} × ${exos.nameOf(e.exerciseId)}',
  ];
  if (lignes.length <= max) return lignes;
  final reste = lignes.length - (max - 1);
  return [...lignes.take(max - 1), 'et $reste autres exercices'];
}

/// Un record battu, prêt à écrire sur la carte de partage.
class RecordPartage {
  const RecordPartage({required this.nom, required this.type, required this.valeur, this.gain, this.medaille = MedailleRecord.or});

  /// Nom de l'exercice.
  final String nom;

  /// Nature du record (« Charge maximale »).
  final String type;

  /// « 100 kg × 5 ».
  final String valeur;

  /// « +2,5 kg », null pour un premier record.
  final String? gain;

  /// Or, argent ou bronze : la couleur de l'écusson.
  final MedailleRecord medaille;
}

/// Les records de la carte « records » : ceux du bilan de fin de séance,
/// chacun avec sa médaille, dans l'ordre de la séance. Vide : pas de carte.
List<RecordPartage> recordsPartage(BilanSeance bilan, ExerciseRepo exos, UnitePoids u) => [
      for (final r in bilan.records)
        RecordPartage(
          nom: exos.nameOf(r.exerciseId),
          type: titreRecord(r, u),
          medaille: r.type.medaille,
          valeur: texteRecord(r, u),
          gain: texteGainRecord(r, bilan.ancienne(r), u),
        ),
    ];

/// Volume en entier avec son unité : « 10 348 kg » (jamais en tonnes).
String volumeEntier(double kg, UnitePoids u) => '${Fmt.n(Fmt.poidsAffiche(kg, u), decimals: 0)} ${u.label}';

/// Textes de la carte « série de semaines » : (libellé, phrase).
(String, String) textesSerie(int semaines) {
  if (semaines <= 0) return ('semaine d\'affilée', 'Ta série commence à la prochaine séance.');
  if (semaines == 1) return ('semaine d\'affilée !', 'Première semaine de ta série : reviens la semaine prochaine.');
  return ('semaines d\'affilée !', 'Tu t\'entraînes depuis $semaines semaines sans pause.');
}

/// Rend en PNG le contenu du `RepaintBoundary` porté par [cle].
/// Nul si la carte n'est pas à l'écran.
Future<Uint8List?> capturerCarte(GlobalKey cle, {double pixelRatio = 3}) async {
  final ro = cle.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary) return null;
  final image = await ro.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Écrit l'image dans le dossier temporaire et ouvre le partage du système.
Future<void> partagerImage(Uint8List png, {required String nom, String? texte}) async {
  final dossier = await getTemporaryDirectory();
  final fichier = File('${dossier.path}/$nom.png');
  await fichier.writeAsBytes(png, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(fichier.path, mimeType: 'image/png')], text: texte));
}
