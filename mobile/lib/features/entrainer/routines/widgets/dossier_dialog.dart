import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/ui/ui.dart';

/// Choisit un dossier : son id, '' pour « Sans dossier », null si annulé.
/// Propose aussi d'en créer un.
Future<String?> choisirDossier(BuildContext context, {String? actuel, String titre = 'Ranger dans un dossier'}) async {
  final repo = context.read<RoutineRepo>();
  const nouveau = '\u0000nouveau';
  final v = await showChoiceDialog<String>(
    context,
    title: titre,
    selected: actuel ?? '',
    options: [
      ('', 'Sans dossier'),
      for (final f in repo.folders) (f.id, f.nom),
      (nouveau, 'Nouveau dossier...'),
    ],
  );
  if (v != nouveau || !context.mounted) return v;
  final f = await creerDossier(context);
  return f?.id;
}

/// Demande un nom et crée le dossier.
Future<Folder?> creerDossier(BuildContext context) async {
  final nom = await showTextInputDialog(context, title: 'Nouveau dossier', hint: 'Ex. : Prise de masse', confirmLabel: 'Créer', maxLength: 40);
  if (nom == null || nom.trim().isEmpty || !context.mounted) return null;
  try {
    return await context.read<RoutineRepo>().addFolder(nom.trim());
  } catch (_) {
    if (context.mounted) Toasts.error(context, 'Impossible de créer le dossier.');
    return null;
  }
}

Future<void> renommerDossier(BuildContext context, Folder f) async {
  final nom = await showTextInputDialog(context, title: 'Renommer le dossier', initial: f.nom, maxLength: 40);
  if (nom == null || nom.trim().isEmpty || !context.mounted) return;
  await context.read<RoutineRepo>().saveFolder(f.copyWith(nom: nom.trim()));
}

enum _SupprDossier { garder, tout }

/// Supprime un dossier ; demande quoi faire de ses routines. Vrai si supprimé.
Future<bool> supprimerDossier(BuildContext context, Folder f) async {
  final repo = context.read<RoutineRepo>();
  final n = repo.routinesIn(f.id).length;
  if (n == 0) {
    final ok = await showConfirmDialog(context, title: 'Supprimer « ${f.nom} » ?', message: 'Le dossier est vide.', confirmLabel: 'Supprimer', destructive: true);
    if (!ok || !context.mounted) return false;
    await repo.deleteFolder(f.id);
    return true;
  }
  final choix = await showChoiceDialog<_SupprDossier>(
    context,
    title: 'Supprimer « ${f.nom} » ?',
    message: 'Il contient ${n == 1 ? 'une routine' : '$n routines'}.',
    options: const [
      (_SupprDossier.garder, 'Supprimer le dossier, garder les routines'),
      (_SupprDossier.tout, 'Tout supprimer, routines comprises'),
    ],
  );
  if (choix == null || !context.mounted) return false;
  if (choix == _SupprDossier.tout) {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer aussi ${n == 1 ? 'la routine' : 'les $n routines'} ?',
      message: 'L\'historique de tes séances est conservé.',
      confirmLabel: 'Tout supprimer',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
  }
  await repo.deleteFolder(f.id, withRoutines: choix == _SupprDossier.tout);
  return true;
}
