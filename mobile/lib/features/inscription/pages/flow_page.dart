import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../inscription_controller.dart';
import '../steps/etape_view.dart';
import '../widgets/widgets.dart';

/// Parcours d'inscription : une étape plein écran à la fois.
class FlowPage extends StatelessWidget {
  const FlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => InscriptionController(context.read<Store>())..load(),
      child: const _Flow(),
    );
  }
}

class _Flow extends StatefulWidget {
  const _Flow();

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  bool _enregistrement = false;
  bool _avance = true;

  void _suivant(InscriptionController ctrl) {
    if (!ctrl.valide(ctrl.etape)) return;
    FocusScope.of(context).unfocus();
    setState(() => _avance = true);
    ctrl.suivant();
  }

  void _retour(InscriptionController ctrl) {
    FocusScope.of(context).unfocus();
    if (ctrl.premiere) {
      ctrl.sauver();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/bienvenue');
      }
      return;
    }
    setState(() => _avance = false);
    ctrl.precedent();
  }

  void _aller(InscriptionController ctrl, Etape e) {
    setState(() => _avance = e.rang > ctrl.index);
    ctrl.aller(e);
  }

  Future<void> _terminer(InscriptionController ctrl) async {
    final manque = ctrl.premiereIncomplete;
    if (manque != null) {
      _aller(ctrl, manque);
      Toasts.show(context, 'Il manque encore ta réponse ici.');
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
      context.go('/bienvenue/programme?premier=1');
    } catch (_) {
      if (mounted) {
        setState(() => _enregistrement = false);
        Toasts.error(context, 'Le profil n\'a pas pu être enregistré. Réessaie.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    if (!ctrl.loaded) {
      return const SubPageScaffold(title: 'Ton profil', body: Padding(padding: EdgeInsets.all(16), child: SkeletonList(count: 5)));
    }
    final e = ctrl.etape;
    final valide = ctrl.valide(e);
    final wide = context.isExpanded;

    final contenu = AnimatedSwitcher(
      duration: AppTokens.normal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final entrant = child.key == ValueKey(e);
        final dx = (entrant == _avance) ? 0.08 : -0.08;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim), child: child),
        );
      },
      // Pas de superposition : l'ancienne étape disparaît sous la nouvelle.
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [?current]),
      child: SingleChildScrollView(
        key: ValueKey(e),
        padding: const EdgeInsets.only(bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: EtapeView(etape: e, onSubmit: () => _suivant(ctrl), onEdit: (x) => _aller(ctrl, x)),
      ),
    );

    final barre = Row(
      children: [
        if (e.facultative && !ctrl.derniere) ...[
          PillButton.ghost(label: 'Passer', onPressed: () => _suivant(ctrl)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ctrl.derniere
              ? PillButton(
                  label: 'Créer mon profil',
                  icon: Icons.check_rounded,
                  size: PillSize.large,
                  expand: true,
                  loading: _enregistrement,
                  onPressed: _enregistrement ? null : () => _terminer(ctrl),
                )
              : PillButton(
                  label: 'Continuer',
                  trailingIcon: Icons.arrow_forward_rounded,
                  size: PillSize.large,
                  expand: true,
                  onPressed: valide ? () => _suivant(ctrl) : null,
                ),
        ),
      ],
    );

    return PopScope(
      canPop: ctrl.premiere,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ctrl.sauver();
          return;
        }
        _retour(ctrl);
      },
      child: SubPageScaffold(
        title: wide ? 'Ton profil' : e.label,
        subtitle: 'Étape ${ctrl.index + 1} sur ${ctrl.total}',
        onBack: () => _retour(ctrl),
        maxContentWidth: wide ? 1100 : Breakpoints.content,
        body: BottomActions(
        bar: wide
            ? Row(children: [const SizedBox(width: 300 + 24), Expanded(child: barre)])
            : barre,
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: _Sommaire(onTap: (x) => _aller(ctrl, x))),
                  VerticalDivider(width: 24, color: c.line),
                  Expanded(child: contenu),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 4, AppTokens.gutter + 4, 8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: ctrl.avancement),
                      duration: AppTokens.normal,
                      builder: (context, v, _) => ProgressBar(value: v, height: 5, color: c.text),
                    ),
                  ),
                  Expanded(child: contenu),
                ],
              ),
        ),
      ),
    );
  }
}

/// Liste des étapes à gauche sur le Fold déplié.
class _Sommaire extends StatelessWidget {
  const _Sommaire({required this.onTap});
  final ValueChanged<Etape> onTap;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InscriptionController>();
    final c = context.colors;
    // On peut rouvrir une étape déjà vue, ou la suivante si tout est valide jusque-là.
    final ouverts = <Etape>{};
    for (final e in Etape.parcours) {
      ouverts.add(e);
      if (!ctrl.valide(e) && !e.facultative) break;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: ProgressBar(value: ctrl.avancement, height: 5, color: c.text),
        ),
        for (final e in Etape.parcours)
          Builder(builder: (context) {
            final ouvert = ouverts.contains(e);
            final courant = e == ctrl.etape;
            final fait = e.rang < ctrl.index && ctrl.valide(e);
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color: courant ? c.surface2 : Colors.transparent,
                borderRadius: AppTokens.radius12,
                child: InkWell(
                  borderRadius: AppTokens.radius12,
                  onTap: ouvert && !courant ? () => onTap(e) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Icon(
                        fait ? Icons.check_circle_rounded : e.icon,
                        size: 20,
                        color: courant ? c.text : (fait ? c.text2 : c.text3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.label,
                          style: AppType.rowTitle(color: courant ? c.text : (ouvert ? c.text2 : c.text3)).copyWith(fontSize: 14),
                        ),
                      ),
                      if (e.facultative) Text('facultatif', style: AppType.rowSubtitle()),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
