import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/ui/ui.dart';
import '../inscription_controller.dart';
import '../steps/etape_view.dart';
import '../steps/steps_fin.dart';
import '../widgets/widgets.dart';

/// Contrôleur en mode édition, chargé depuis le profil enregistré.
InscriptionController _controleurEdition(BuildContext context) {
  final ctrl = InscriptionController(context.read<Store>(), edition: true);
  ctrl.load(profil: context.read<ProfileRepo>().profile, settings: context.read<SettingsRepo>().settings);
  return ctrl;
}

/// « Modifier mon profil » : toutes les réponses, chacune modifiable.
class EditHubPage extends StatefulWidget {
  const EditHubPage({super.key});

  @override
  State<EditHubPage> createState() => _EditHubPageState();
}

class _EditHubPageState extends State<EditHubPage> {
  // Nouvelle clé après chaque modification pour relire le profil.
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ProfileRepo>().profile;
    if (profil == null) {
      return SubPageScaffold(
        title: 'Mon profil',
        body: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Pas encore de profil',
          message: 'Réponds aux questions de l\'inscription pour le créer.',
          actionLabel: 'Commencer',
          onAction: () => context.go(Paths.bienvenue),
        ),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(_version),
      create: _controleurEdition,
      child: Builder(builder: (context) {
        final ctrl = context.watch<InscriptionController>();
        return SubPageScaffold(
          title: 'Mes réponses',
          subtitle: 'Touche une ligne pour la modifier',
          body: !ctrl.loaded
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList())
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    Recapitulatif(
                      titre: false,
                      onEdit: (e) async {
                        if (!e.modifiable) return;
                        await context.push('${Paths.bienvenue}/modifier/${e.slug}');
                        if (mounted) setState(() => _version++);
                      },
                    ),
                    const SizedBox(height: 16),
                    TileGroup(label: 'Aller plus loin', children: [
                      ListTileX(
                        leading: IconHalo(icon: Icons.auto_awesome_rounded, size: 38),
                        title: 'Programme conseillé',
                        subtitle: 'Recalculé d\'après ces réponses',
                        showChevron: true,
                        onTap: () => context.push('${Paths.bienvenue}/programme'),
                      ),
                      ListTileX(
                        leading: IconHalo(icon: Icons.upload_file_rounded, size: 38),
                        title: 'Reprendre mon historique',
                        subtitle: 'Importer depuis une autre application (CSV)',
                        showChevron: true,
                        onTap: () => context.push('${Paths.import}?retour=${Paths.bienvenue}/modifier'),
                      ),
                    ]),
                  ],
                ),
        );
      }),
    );
  }
}

/// Une seule étape, ouverte depuis le profil, avec « Enregistrer ».
class EditStepPage extends StatelessWidget {
  const EditStepPage({super.key, required this.etape});
  final Etape? etape;

  @override
  Widget build(BuildContext context) {
    final e = etape;
    if (e == null || !e.modifiable) {
      return SubPageScaffold(
        title: 'Modifier',
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Cette page n\'existe pas',
          actionLabel: 'Revenir',
          onAction: () => context.canPop() ? context.pop() : context.go(Paths.aujourdhui),
        ),
      );
    }
    return ChangeNotifierProvider(create: _controleurEdition, child: _EditStep(etape: e));
  }
}

class _EditStep extends StatefulWidget {
  const _EditStep({required this.etape});
  final Etape etape;

  @override
  State<_EditStep> createState() => _EditStepState();
}

class _EditStepState extends State<_EditStep> {
  bool _enregistrement = false;
  bool get _modifie => context.read<InscriptionController>().modifie;

  /// Réponses qui changent le programme conseillé.
  static const _programme = {Etape.objectif, Etape.niveau, Etape.frequence, Etape.materiel, Etape.muscles};

  Future<void> _enregistrer() async {
    final ctrl = context.read<InscriptionController>();
    if (!ctrl.valide(widget.etape)) {
      Toasts.show(context, 'Complète la réponse avant d\'enregistrer.');
      return;
    }
    setState(() => _enregistrement = true);
    try {
      await ctrl.enregistrer(
        profils: context.read<ProfileRepo>(),
        reglages: context.read<SettingsRepo>(),
        sante: context.read<HealthRepo>(),
      );
      if (!mounted) return;
      if (_programme.contains(widget.etape)) {
        final ok = await showConfirmDialog(
          context,
          title: 'Revoir ton programme ?',
          message: 'Cette réponse change le programme conseillé. Veux-tu voir la nouvelle proposition ?',
          confirmLabel: 'Voir le programme',
          cancelLabel: 'Non merci',
        );
        if (!mounted) return;
        if (ok) {
          context.pushReplacement('${Paths.bienvenue}/programme');
          return;
        }
      }
      Toasts.success(context, 'Profil mis à jour.');
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _enregistrement = false);
        Toasts.error(context, 'La modification n\'a pas pu être enregistrée.');
      }
    }
  }

  Future<void> _fermer() async {
    if (_modifie) {
      final ok = await showConfirmDialog(
        context,
        title: 'Abandonner la modification ?',
        confirmLabel: 'Abandonner',
        cancelLabel: 'Continuer',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _fermer();
      },
      child: SubPageScaffold(
        title: widget.etape.label,
        subtitle: 'Modifier mon profil',
        closeIcon: true,
        onBack: _fermer,
        body: BottomActions(
        bar: PillButton(
          label: 'Enregistrer',
          icon: Icons.check_rounded,
          size: PillSize.large,
          expand: true,
          loading: _enregistrement,
          onPressed: !ctrl.loaded || _enregistrement || !ctrl.valide(widget.etape) ? null : _enregistrer,
        ),
        body: !ctrl.loaded
            ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 4))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: EtapeView(etape: widget.etape, onSubmit: _enregistrer, onEdit: (_) {}),
              ),
        ),
      ),
    );
  }
}
