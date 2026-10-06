// Pont vers la bibliothèque d'exercices : sélecteur et fiche viennent de
// son module, la vignette portrait vient du noyau.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/ui/ui.dart';

export '../../bibliotheque/bibliotheque.dart' show pickExercises, pickExercise, ouvrirFicheExercice;

/// Vignette portrait d'un exercice (carte grise, image contenue).
class ExerciseVignette extends StatelessWidget {
  const ExerciseVignette(this.exercise, {super.key, this.width = 48, this.help = true});

  final Exercise? exercise;
  final double width;
  final bool help;

  @override
  Widget build(BuildContext context) {
    final src = exercise?.media.thumbnail;
    final ImageProvider? img = src == null ? null : (src.startsWith('http') ? CachedNetworkImageProvider(src) : AssetImage(src));
    return ExerciseThumbnail(image: img, width: width, height: width * 1.5, help: help);
  }
}
