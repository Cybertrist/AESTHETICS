import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Base des boutons pleine largeur de la maquette : pilule de 56, libellé
/// en gras.
class _BoutonPlein extends StatelessWidget {
  const _BoutonPlein({
    required this.label,
    required this.onPressed,
    required this.fond,
    required this.encre,
    this.icone,
    this.petit = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fond;
  final Color encre;
  final Widget? icone;
  final bool petit;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    final couleur = actif ? encre : encre.withValues(alpha: 0.4);
    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: actif ? fond : fond.withValues(alpha: 0.5),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: petit ? 50 : 56,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[
                  IconTheme.merge(data: IconThemeData(color: couleur, size: 20), child: icone!),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTokens.fontUi,
                      fontSize: petit ? 15.5 : 17,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: couleur,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal : blanc, texte noir, pleine largeur. Un seul par écran.
/// (`PillButton` reste disponible pour un bouton qui épouse son libellé.)
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal({super.key, required this.label, required this.onPressed, this.icone, this.petit = false});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icone;

  /// Hauteur de 50 au lieu de 56 (deux boutons côte à côte).
  final bool petit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _BoutonPlein(label: label, onPressed: onPressed, fond: c.bouton, encre: c.onBouton, icone: icone, petit: petit);
  }
}

/// Bouton secondaire : gris, texte blanc, pleine largeur. Sur un panneau du
/// bas (déjà gris), passer `fond: AppTokens.surface3`.
class BoutonSecondaire extends StatelessWidget {
  const BoutonSecondaire({super.key, required this.label, required this.onPressed, this.icone, this.petit = false, this.fond});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icone;
  final bool petit;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _BoutonPlein(label: label, onPressed: onPressed, fond: fond ?? c.surface2, encre: c.text, icone: icone, petit: petit);
  }
}

/// Bouton destructif : gris, texte rouge (« Abandonner la séance »,
/// « Supprimer »). Jamais de fond rouge.
class BoutonDestructif extends StatelessWidget {
  const BoutonDestructif({super.key, required this.label, required this.onPressed, this.icone, this.petit = false, this.fond});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icone;
  final bool petit;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _BoutonPlein(label: label, onPressed: onPressed, fond: fond ?? c.surface2, encre: c.error, icone: icone, petit: petit);
  }
}

/// Sélecteur segmenté de la maquette : bac gris aux coins de 12, le segment
/// choisi en noir, texte blanc. Pour deux à quatre choix courts.
///
/// ```dart
/// SelecteurSegmente<String>(
///   segments: const [('kg', 'Kilos'), ('lb', 'Livres')],
///   value: unite,
///   onChanged: (v) => setState(() => unite = v),
/// )
/// ```
class SelecteurSegmente<T> extends StatelessWidget {
  const SelecteurSegmente({super.key, required this.segments, required this.value, required this.onChanged});

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Le bac garde ses 4 de marge, mais elle fait partie de la zone d'appui :
    // 46 de haut au lieu de 38.
    return Container(
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const SizedBox(width: 4),
          for (final (v, label) in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AnimatedContainer(
                      duration: AppTokens.fast,
                      height: 38,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: v == value ? c.bg : c.bg.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // Rétrécit plutôt que de couper (texte agrandi, écran étroit).
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTokens.fontUi,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: v == value ? c.text : c.text2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Ton d'une [Pastille].
enum TonPastille {
  /// Grise, texte gris : une information (« 65 min »).
  neutre,

  /// Verte : c'est bon (« Récupéré »).
  ok,

  /// Ambre : à surveiller (« Fatigué »).
  alerte,

  /// Corail atténué : muscle secondaire, étiquette de muscle.
  muscle,

  /// Corail plein, texte blanc : muscle principal.
  musclePlein,
}

/// Petite étiquette en pilule de la maquette. Le corail est réservé aux
/// muscles : pour tout le reste, rester sur neutre, ok ou alerte.
class Pastille extends StatelessWidget {
  const Pastille(this.label, {super.key, this.ton = TonPastille.neutre, this.grande = false});

  final String label;
  final TonPastille ton;

  /// Un cran plus grande (pourcentage de récupération).
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fond, Color encre) = switch (ton) {
      TonPastille.neutre => (c.surface2, c.text2),
      TonPastille.ok => (c.success.withValues(alpha: 0.14), c.success),
      TonPastille.alerte => (c.warning.withValues(alpha: 0.14), c.warning),
      TonPastille.muscle => (c.accent.withValues(alpha: 0.16), c.accent),
      TonPastille.musclePlein => (c.accent, Colors.white),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: grande ? 12 : 11, vertical: 4),
      decoration: BoxDecoration(color: fond, borderRadius: AppTokens.radiusPill),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: AppTokens.fontUi,
          fontSize: grande ? 13.5 : 12.5,
          height: 1.35,
          fontWeight: grande ? FontWeight.w700 : FontWeight.w600,
          color: encre,
          fontFeatures: AppTokens.tabular,
        ),
      ),
    );
  }
}
