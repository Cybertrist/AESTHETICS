import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../commun/elements.dart';
import '../logic/program_plan.dart';
import 'couverture.dart';

/// Couverture d'un programme : la photo choisie, sinon la couverture dessinée.
class CouvertureProgrammeVue extends StatelessWidget {
  const CouvertureProgrammeVue({super.key, required this.nom, this.photo, this.cote = 165});

  final String nom;
  final String? photo;
  final double cote;

  @override
  Widget build(BuildContext context) {
    final dessin = CouvertureProgramme(nom, cote: cote);
    final chemin = photo;
    if (chemin == null) return dessin;
    return ClipRRect(
      borderRadius: BorderRadius.circular(17.5),
      child: Image.file(File(chemin), width: cote, height: cote, fit: BoxFit.cover, errorBuilder: (_, _, _) => dessin),
    );
  }
}

/// Couverture d'un programme enregistré, à jour quand sa photo change.
class CouvertureDuProgramme extends StatelessWidget {
  const CouvertureDuProgramme(this.programme, {super.key, this.cote = 165});

  final Program programme;
  final double cote;

  @override
  Widget build(BuildContext context) {
    final plans = ProgramPlanRepo.of(context.read<Store>());
    return ListenableBuilder(
      listenable: plans,
      builder: (context, _) => CouvertureProgrammeVue(nom: programme.nom, photo: plans.planFor(programme.id).photo, cote: cote),
    );
  }
}

/// Tuile d'un programme dans une liste : sa photo, sinon son sigle.
class TuileDuProgramme extends StatelessWidget {
  const TuileDuProgramme(this.programme, {super.key});

  final Program programme;

  @override
  Widget build(BuildContext context) {
    final plans = ProgramPlanRepo.of(context.read<Store>());
    return ListenableBuilder(
      listenable: plans,
      builder: (context, _) {
        final sigle = TuileProgramme(programme.nom);
        final photo = plans.planFor(programme.id).photo;
        if (photo == null) return sigle;
        return Tuile(child: Image.file(File(photo), width: 65, height: 65, fit: BoxFit.cover, errorBuilder: (_, _, _) => sigle));
      },
    );
  }
}

/// Ouvre la galerie et recopie l'image dans le dossier de l'appli, pour
/// qu'elle survive au ménage de la galerie. Rend le chemin de la copie,
/// null si rien n'a été choisi. Lève une erreur si la galerie ne s'ouvre pas.
Future<String?> choisirPhotoProgramme(Store store) async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 88);
  if (f == null) return null;
  final dossier = await store.mediaDir();
  final cible = '${dossier.path}${Platform.pathSeparator}programme_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(f.path).copy(cible);
  return cible;
}
