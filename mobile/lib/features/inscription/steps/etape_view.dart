import 'package:flutter/material.dart';

import '../inscription_controller.dart';
import 'steps_fin.dart';
import 'steps_objectifs.dart';
import 'steps_profil.dart';

/// Contenu d'une étape.
class EtapeView extends StatelessWidget {
  const EtapeView({super.key, required this.etape, this.onSubmit, required this.onEdit});

  final Etape etape;

  /// Validation au clavier (étape du prénom).
  final VoidCallback? onSubmit;

  /// Ouvre une étape depuis le récapitulatif.
  final ValueChanged<Etape> onEdit;

  @override
  Widget build(BuildContext context) => switch (etape) {
        Etape.prenom => PrenomStep(onSubmit: onSubmit),
        Etape.sexe => const SexeStep(),
        Etape.naissance => const NaissanceStep(),
        Etape.taille => const TailleStep(),
        Etape.poids => const PoidsStep(),
        Etape.objectif => const ObjectifStep(),
        Etape.niveau => const NiveauStep(),
        Etape.activite => const ActiviteStep(),
        Etape.frequence => const FrequenceStep(),
        Etape.materiel => const MaterielStep(),
        Etape.muscles => const MusclesStep(),
        Etape.nutrition => const NutritionStep(),
        Etape.historique => const HistoriqueStep(),
        Etape.autorisations => const AutorisationsStep(),
        Etape.recapitulatif => Recapitulatif(onEdit: onEdit),
      };
}
