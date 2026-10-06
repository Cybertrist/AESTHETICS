import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'brand.dart';
import 'halo.dart';
import 'responsive.dart';

/// Page racine d'un onglet : fond noir pur, en-tête simple (avatar, titre
/// en Roboto medium, actions à droite) qui se replie au défilement et
/// revient au moindre geste vers le haut. Aucun halo.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.slivers,
    this.body,
    this.actions = const [],
    this.bottom,
    this.floatingActionButton,
    this.onRefresh,
    this.showAvatar = true,
    this.onAvatarTap,
    this.maxContentWidth = Breakpoints.content,
    this.controller,
    this.bottomPadding = 32,
    this.eyebrow,
    this.trailingTitle,
    this.halo = true,
    this.haloColor,
    this.centerTitle = false,
  }) : assert(slivers != null || body != null, 'slivers ou body');

  final String title;

  /// Contenu défilant (préféré).
  final List<Widget>? slivers;

  /// Contenu simple, placé sous l'en-tête.
  final Widget? body;
  final List<Widget> actions;

  /// Rangée fixée sous le titre (recherche, `IconTabBar`) : l'en-tête
  /// reste alors épinglé en haut.
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;

  /// Avatar du profil à gauche du titre (masqué quand le rail latéral l'affiche).
  final bool showAvatar;

  /// Par défaut, ouvre /profil.
  final VoidCallback? onAvatarTap;
  final double maxContentWidth;
  final ScrollController? controller;

  /// Marge sous le contenu.
  final double bottomPadding;

  /// Petite ligne grise au-dessus du titre.
  final String? eyebrow;

  /// Élément à droite du titre, avant les actions.
  final Widget? trailingTitle;

  /// Sans effet (plus de halo) ; gardés pour compatibilité.
  final bool halo;
  final Color? haloColor;

  /// Titre centré (« Home » entre deux icônes).
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatar = showAvatar && !context.isExpanded;
    final top = MediaQuery.paddingOf(context).top;
    final inset = MediaQuery.paddingOf(context).bottom;
    final toolbarHeight = eyebrow == null ? 60.0 : 74.0;

    final titleText = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (eyebrow != null)
          Text(eyebrow!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13)),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.screenTitle().copyWith(fontSize: 22)),
      ],
    );

    final header = SliverAppBar(
      pinned: bottom != null,
      floating: true,
      snap: true,
      toolbarHeight: toolbarHeight,
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: AppTokens.gutter,
      centerTitle: centerTitle,
      leading: centerTitle && avatar
          ? Center(child: UserAvatar(size: 34, onTap: onAvatarTap ?? () => context.go('/profil')))
          : null,
      title: centerTitle
          ? titleText
          : Row(
              children: [
                if (avatar) ...[
                  UserAvatar(size: 34, onTap: onAvatarTap ?? () => context.go('/profil')),
                  const SizedBox(width: 12),
                ],
                Expanded(child: titleText),
                if (trailingTitle != null) ...[const SizedBox(width: 12), trailingTitle!],
              ],
            ),
      actions: [...actions, const SizedBox(width: 6)],
      bottom: bottom,
    );

    final content = <Widget>[
      if (slivers != null)
        for (final s in slivers!) SliverContentWidth(maxWidth: maxContentWidth, sliver: s)
      else
        SliverToBoxAdapter(child: ContentWidth(maxWidth: maxContentWidth, child: body!)),
    ];

    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        header,
        ...content,
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding + inset)),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: onRefresh!,
        color: c.accent,
        backgroundColor: c.surface2,
        edgeOffset: top + toolbarHeight,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: floatingActionButton,
      body: MediaQuery.removePadding(context: context, removeBottom: true, child: scroll),
    );
  }
}

/// Sous-page : en-tête simple « ‹ Titre » sur fond noir, actions à droite,
/// contenu centré sur grand écran et zone d'actions fixée en bas (bouton
/// « Enregistrer »...).
class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.floatingActionButton,
    this.maxContentWidth = Breakpoints.content,
    this.onBack,
    this.closeIcon = false,
    this.backgroundColor,
    this.halo = true,
    this.haloColor,
    this.trailingTitle,
  });

  final String title;

  /// Petite ligne grise sous le titre.
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  /// Barre d'actions fixée en bas, au-dessus du clavier.
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  /// Retour personnalisé (confirmation avant d'abandonner une saisie...).
  final VoidCallback? onBack;

  /// Croix plutôt que chevron (« × Add exercises »).
  final bool closeIcon;
  final Color? backgroundColor;

  /// Sans effet (plus de halo) ; gardés pour compatibilité.
  final bool halo;
  final Color? haloColor;

  /// Élément à droite du titre.
  final Widget? trailingTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canPop = Navigator.of(context).canPop();
    final back = canPop || onBack != null;
    return Scaffold(
      backgroundColor: backgroundColor ?? c.bg,
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        backgroundColor: backgroundColor ?? c.bg,
        toolbarHeight: 60,
        titleSpacing: back ? 4 : AppTokens.gutter,
        leadingWidth: back ? 60 : null,
        // Bouton retour de la maquette : rond gris, chevron blanc. La cible
        // reste de 48 autour du rond de 40.
        leading: back
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: IconButton(
                    tooltip: closeIcon ? 'Fermer' : 'Retour',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                      child: Icon(closeIcon ? Icons.close_rounded : Icons.chevron_left_rounded, color: c.text, size: closeIcon ? 22 : 28),
                    ),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.screenTitle().copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle().copyWith(fontSize: 13)),
                ],
              ),
            ),
            if (trailingTitle != null) ...[const SizedBox(width: 12), trailingTitle!],
          ],
        ),
        actions: [...actions, const SizedBox(width: 4)],
      ),
      body: ContentWidth(maxWidth: maxContentWidth, child: body),
      bottomNavigationBar: bottomBar == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor ?? c.bg,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SafeArea(
                  top: false,
                  // heightFactor : sans lui la barre prend toute la hauteur.
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10),
                        child: bottomBar,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Page provisoire, remplacée par chaque module.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.tabRoot = false, this.note});

  final String title;

  /// Racine d'onglet ou sous-page.
  final bool tabRoot;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final content = Padding(
      padding: const EdgeInsets.only(top: 80),
      child: _PlaceholderBody(title: title, location: location, note: note),
    );
    if (tabRoot) return AppScaffold(title: title, body: content);
    return SubPageScaffold(title: title, body: content);
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.title, required this.location, this.note});
  final String title;
  final String? location;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconHalo(icon: Icons.construction_rounded, size: 56),
          const SizedBox(height: 18),
          Text(title, style: t.titleLarge),
          const SizedBox(height: 6),
          Text(note ?? 'Cette page arrive bientôt.', style: t.bodyMedium?.copyWith(color: c.text2)),
          const SizedBox(height: 4),
          Text(location ?? '', style: t.bodySmall?.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}
