import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../commun/traits.dart';

/// Briques des éditeurs de programme et de routine : titres de section,
/// champs aux bords fins, cartes de choix, pastilles.

TextStyle _texte(double taille, FontWeight poids, Color couleur, {double hauteur = 1.25}) =>
    TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, height: hauteur, fontWeight: poids, color: couleur, letterSpacing: 0);

/// Titre d'un bloc : blanc, gras, avec une précision grise facultative.
class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key, this.detail, this.haut = 36});

  final String texte;
  final String? detail;
  final double haut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppTokens.gutter, haut, AppTokens.gutter, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(texte, style: _texte(19, FontWeight.w700, c.text))),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: _texte(14, FontWeight.w400, c.text2, hauteur: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// Champ de saisie au cadre fin, libellé posé sur le cadre.
class ChampBord extends StatelessWidget {
  const ChampBord({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines = 1,
    this.hint,
    this.erreur,
    this.aide,
    this.clavier,
  });

  /// Exemple affiché dans le champ vide.
  final String? hint;

  /// Message rouge sous le champ.
  final String? erreur;

  /// Message ambre sous le champ (un avertissement qui ne bloque pas).
  final String? aide;
  final TextInputType? clavier;
  final int minLines;

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final bool autofocus;
  final int? maxLength;

  /// Plus d'une ligne : le champ grandit avec le texte jusqu'à cette limite.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder bord(Color couleur, double epaisseur) => OutlineInputBorder(
          borderRadius: AppTokens.radius14,
          borderSide: BorderSide(color: couleur, width: epaisseur),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      // Toucher ailleurs rend la main : le champ ne reprend pas le curseur
      // (ni le clavier) quand on agit plus bas dans la page.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines < minLines ? minLines : maxLines,
      keyboardType: clavier,
      cursorColor: c.text,
      textCapitalization: TextCapitalization.sentences,
      style: _texte(17, FontWeight.w500, c.text, hauteur: 1.35),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: _texte(17, FontWeight.w400, c.text3),
        errorText: erreur,
        errorStyle: _texte(13, FontWeight.w500, c.error),
        errorMaxLines: 2,
        helperText: aide,
        helperStyle: _texte(13, FontWeight.w500, c.warning),
        helperMaxLines: 2,
        errorBorder: bord(c.error, 1),
        focusedErrorBorder: bord(c.error, 1.5),
        counterText: '',
        filled: false,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        labelStyle: _texte(17, FontWeight.w400, c.text2),
        floatingLabelStyle: _texte(15.5, FontWeight.w500, c.text2),
        border: bord(c.frame, 1),
        enabledBorder: bord(c.frame, 1),
        focusedBorder: bord(c.text, 1.5),
      ),
    );
  }
}

/// Cadre d'un choix : fin et gris au repos, blanc et plus épais quand il
/// est retenu. Le cadre est peint par-dessus : rien ne bouge au choix.
class CadreChoix extends StatelessWidget {
  const CadreChoix({super.key, required this.child, required this.selected, required this.onTap, required this.label, this.rayon = 18, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final String label;
  final double rayon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final forme = BorderRadius.circular(rayon);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        decoration: BoxDecoration(color: selected ? c.surface : c.bg, borderRadius: forme),
        foregroundDecoration: BoxDecoration(
          borderRadius: forme,
          border: Border.all(color: selected ? c.text : c.surface3, width: selected ? 2 : 1.2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: forme,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Carte de choix d'une grille : l'icône en haut, le libellé en bas.
class CarteChoix extends StatelessWidget {
  const CarteChoix({super.key, required this.icone, required this.label, required this.selected, required this.onTap, this.hauteur = 104, this.taille = 15.5, this.serre = false});

  final Widget icone;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double hauteur;

  /// Marges réduites (trois cartes de front sur un petit écran).
  final bool serre;

  /// Taille du libellé.
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CadreChoix(
      selected: selected,
      onTap: onTap,
      label: label,
      padding: EdgeInsets.fromLTRB(serre ? 11 : 14, 14, serre ? 5 : 10, 13),
      child: SizedBox(
        height: hauteur - 27,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icone,
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, style: _texte(taille, FontWeight.w700, c.text)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coche blanche d'un choix retenu ; un anneau gris sinon.
class CocheChoix extends StatelessWidget {
  const CocheChoix({super.key, required this.selected, this.taille = 24});

  final bool selected;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppTokens.fast,
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.bouton : null,
        border: selected ? null : Border.all(color: c.frame, width: 1.5),
      ),
      child: selected ? IconeTrait(Trait.coche, size: taille * 0.72, color: c.onBouton, epaisseur: 2.4) : null,
    );
  }
}

/// Icône posée dans un rond gris (ligne de choix, réglage).
class RondIcone extends StatelessWidget {
  const RondIcone({super.key, required this.child, this.taille = 42});

  final Widget child;
  final double taille;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.surface2),
        child: child,
      );
}

/// Choix sur toute la largeur : icône, titre, explication, coche.
class LigneChoix extends StatelessWidget {
  const LigneChoix({super.key, required this.icone, required this.titre, required this.detail, required this.selected, required this.onTap});

  final Widget icone;
  final String titre;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CadreChoix(
      selected: selected,
      onTap: onTap,
      label: '$titre. $detail',
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      child: Row(
        children: [
          RondIcone(child: icone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: _texte(16.5, FontWeight.w700, c.text)),
                const SizedBox(height: 4),
                Text(detail, style: _texte(14, FontWeight.w400, c.text2, hauteur: 1.38)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CocheChoix(selected: selected),
        ],
      ),
    );
  }
}

/// Réglage dans un cadre fin : icône, titre, précision, et la commande à droite.
class CadreReglage extends StatelessWidget {
  const CadreReglage({super.key, required this.icone, required this.titre, this.detail, required this.commande});

  final Widget icone;
  final String titre;
  final String? detail;
  final Widget commande;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.surface3, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RondIcone(child: icone),
              const SizedBox(width: 12),
              Expanded(child: Text(titre, style: _texte(16, FontWeight.w700, c.text))),
              const SizedBox(width: 4),
              commande,
            ],
          ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(left: 54, top: 6),
              child: Text(detail!, style: _texte(14, FontWeight.w400, c.text2, hauteur: 1.38)),
            ),
        ],
      ),
    );
  }
}

/// Rangée de pastilles : la choisie est blanche, son texte noir.
class RangeePastilles<T> extends StatelessWidget {
  const RangeePastilles({super.key, required this.choix, required this.choisies, required this.onChanged, this.ronde = false});

  /// Valeur, texte affiché, texte lu.
  final List<(T, String, String)> choix;
  final Set<T> choisies;
  final ValueChanged<T> onChanged;

  /// Disques (jours) plutôt que pilules (nombres).
  final bool ronde;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, box) {
      const ecart = 8.0;
      final n = choix.length;
      final largeur = (box.maxWidth - ecart * (n - 1)) / n;
      final hauteur = ronde ? largeur.clamp(34.0, 48.0) : 46.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (v, texte, lu) in choix)
            Semantics(
              button: true,
              selected: choisies.contains(v),
              label: lu,
              excludeSemantics: true,
              child: Tooltip(
                message: lu,
                excludeFromSemantics: true,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: AppTokens.fast,
                    width: ronde ? hauteur : largeur,
                    height: hauteur,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: choisies.contains(v) ? c.bouton : null,
                      shape: StadiumBorder(side: BorderSide(color: choisies.contains(v) ? c.bouton : c.surface3, width: 1.2)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                      texte,
                      maxLines: 1,
                      style: _texte(16, FontWeight.w700, choisies.contains(v) ? c.onBouton : c.text).copyWith(fontFeatures: AppTokens.tabular),
                    )),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Lien discret : icône et texte blancs.
class LienBlanc extends StatelessWidget {
  const LienBlanc({super.key, required this.label, required this.onTap, this.icone, this.couleur});

  final String label;
  final VoidCallback? onTap;
  final Widget? icone;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final col = couleur ?? context.colors.text;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.radiusPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[IconTheme.merge(data: IconThemeData(color: col), child: icone!), const SizedBox(width: 8)],
              Text(label, style: _texte(15.5, FontWeight.w600, col)),
            ],
          ),
        ),
      ),
    );
  }
}
