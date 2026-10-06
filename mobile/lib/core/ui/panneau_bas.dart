import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Ouvre un panneau du bas pour un choix court (type de série, durée, type
/// d'activité, actions sur un élément). Les formulaires restent en pleine
/// page. Le panneau se ferme avec `Navigator.pop(context, valeur)`.
///
/// ```dart
/// final type = await showPanneauBas<TypeSeance>(
///   context,
///   titre: 'Type d\'activité',
///   builder: (context) => Column(children: [
///     for (final t in TypeSeance.values)
///       ChoixPanneau(
///         icone: IconeTypeSeance(t),
///         label: t.label,
///         selected: t == actuel,
///         onTap: () => Navigator.pop(context, t),
///       ),
///   ]),
/// );
/// ```
Future<T?> showPanneauBas<T>(
  BuildContext context, {
  String? titre,
  Widget? entete,
  required WidgetBuilder builder,
  bool fermable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: fermable,
    enableDrag: fermable,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => PanneauBas(titre: titre, entete: entete, child: builder(context)),
  );
}

/// Le panneau lui-même : fond gris, coins hauts de 26, poignée, titre centré
/// (ou [entete] libre) suivi d'un filet, puis le contenu. S'utilise par
/// [showPanneauBas] ; on peut aussi le poser tel quel en bas d'un `Stack`.
class PanneauBas extends StatelessWidget {
  const PanneauBas({super.key, this.titre, this.entete, required this.child});

  /// Titre centré.
  final String? titre;

  /// En-tête libre à la place du titre (vignette et nom d'une routine...).
  final Widget? entete;
  final Widget child;

  /// Filet sous le titre, et cadre des choix non retenus.
  static const filet = AppTokens.surface3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9, maxWidth: 640),
        child: Material(
          color: c.surface2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r26)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: const BoxDecoration(color: AppTokens.poignee, borderRadius: AppTokens.radiusPill),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (titre != null || entete != null) ...[
                    entete ??
                        Text(
                          titre!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTokens.fontUi,
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: filet),
                    const SizedBox(height: 12),
                  ],
                  Flexible(child: SingleChildScrollView(child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'action d'un panneau du bas : icône, libellé. [destructif] la
/// passe en rouge (« Supprimer »).
class LigneAction extends StatelessWidget {
  const LigneAction({super.key, required this.icone, required this.label, required this.onTap, this.destructif = false});

  /// Un `TraitIcone` ou un `Icon` ; il prend la couleur de la ligne.
  final Widget icone;
  final String label;
  final VoidCallback? onTap;
  final bool destructif;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final couleur = destructif ? c.error : c.text;
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.radius12,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconTheme.merge(data: IconThemeData(color: couleur, size: 24), child: icone),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: couleur,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix encadré d'un panneau du bas (type de série, type d'activité) : le
/// choix retenu a le cadre blanc et une coche à droite.
class ChoixPanneau extends StatelessWidget {
  const ChoixPanneau({
    super.key,
    required this.label,
    required this.onTap,
    this.icone,
    this.selected = false,
    this.detail,
  });

  final String label;
  final VoidCallback? onTap;

  /// Icône ou lettre à gauche.
  final Widget? icone;
  final bool selected;

  /// Précision grise après le libellé.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTokens.radius16,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: AppTokens.radius16,
              border: Border.all(color: selected ? c.text : AppTokens.frame, width: 1.5),
            ),
            child: Row(
              children: [
                if (icone != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: c.text, size: 22),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontFamily: AppTokens.fontUi,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                      child: icone!,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text.rich(
                    TextSpan(text: label, children: [
                      if (detail != null) TextSpan(text: '  $detail', style: TextStyle(color: c.text3)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTokens.fontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 22, color: c.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
