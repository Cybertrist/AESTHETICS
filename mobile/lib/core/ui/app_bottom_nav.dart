import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../env.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'brand.dart';
import 'icones.dart';

/// Les onglets, dans l'ordre de la barre.
enum AppTab {
  aujourdhui('Accueil', '/', Icons.home_outlined, Icons.home_rounded, AppIcone.accueil),
  entrainer('Entraînement', '/entrainer', Icons.fitness_center_outlined, Icons.fitness_center_rounded, AppIcone.haltere),
  coach('Coach', '/coach', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  nutrition('Nutrition', '/nutrition', Icons.restaurant_outlined, Icons.restaurant_rounded),
  progres('Progrès', '/progres', Icons.bar_chart_outlined, Icons.bar_chart_rounded, AppIcone.progres),
  profil('Profil', '/profil', Icons.person_outline_rounded, Icons.person_rounded, AppIcone.profil);

  const AppTab(this.label, this.path, this.icon, this.selectedIcon, [this.trait]);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  /// Icône au trait de la maquette ; sans elle, on retombe sur [icon].
  final AppIcone? trait;

  /// Onglets affichés, dans l'ordre des branches de la coquille : Accueil,
  /// Entraîner, Progrès, Profil. Coach et Nutrition s'intercalent avec
  /// `--dart-define=COMPLET=true`.
  static const List<AppTab> visibles =
      Env.muscuSeule ? [aujourdhui, entrainer, progres, profil] : [aujourdhui, entrainer, coach, nutrition, progres, profil];

  /// Rang de l'onglet dans la barre, -1 s'il est rangé.
  int get rang => visibles.indexOf(this);

  /// L'icône de l'onglet, à la taille et à la couleur voulues.
  Widget icone({required double size, required Color color, bool selected = false}) => trait != null
      ? TraitIcone(trait!, size: size, color: color)
      : Icon(selected ? selectedIcon : icon, size: size, color: color);
}

/// Gris des onglets au repos.
const _idle = AppTokens.text2;

/// Place à laisser sous le contenu pour la barre du bas. La barre est
/// pleine (le contenu s'arrête au-dessus), donc sous la coquille ce n'est
/// que la zone système, déjà comptée par `AppScaffold`.
double bottomNavSpace(BuildContext context) => MediaQuery.paddingOf(context).bottom;

/// Barre du bas : noire, pleine largeur, un filet fin au-dessus, quatre
/// onglets (icône au trait au-dessus du libellé), l'actif en blanc, les
/// autres en gris.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Hauteur de la barre, hors zone système.
  static const height = 62.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final (i, tab) in AppTab.visibles.indexed)
                Expanded(
                  child: _NavItem(tab: tab, selected: currentIndex == i, onTap: () => _tap(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _tap(int i) {
    HapticFeedback.selectionClick();
    onTap(i);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.text : _idle;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            tab.icone(size: 26, color: color, selected: selected),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTokens.fontUi,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rail latéral pour l'écran large du Fold ouvert : de la couleur de la
/// page, l'avatar en haut, les onglets au milieu de la hauteur, là où tombe
/// le pouce.
class AppNavRail extends StatelessWidget {
  const AppNavRail({super.key, required this.currentIndex, required this.onTap, this.onAvatarTap});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gauche = MediaQuery.paddingOf(context).left;
    return Container(
      width: 92 + gauche,
      padding: EdgeInsets.only(left: gauche),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(right: BorderSide(color: c.surface)),
      ),
      child: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Zone d'appui de 48 autour de l'avatar de 40.
            Semantics(
              button: true,
              label: 'Profil',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onAvatarTap,
                radius: 28,
                child: const SizedBox(width: 48, height: 48, child: Center(child: UserAvatar(size: 40))),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, contraintes) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: contraintes.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final (i, tab) in AppTab.visibles.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: _RailItem(tab: tab, selected: currentIndex == i, onTap: () => onTap(i)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.text : _idle;
    final iconColor = color;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radius18,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppTokens.normal,
                curve: Curves.easeOutCubic,
                width: 60,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(child: tab.icone(size: 25, color: iconColor, selected: selected)),
              ),
              const SizedBox(height: 6),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppTokens.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
