import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'habillage.dart';

/// Page pleine du module au design validé : en-tête au bouton retour rond,
/// contenu, et bouton du bas posé au-dessus de la zone système.
class PageSeance extends StatelessWidget {
  const PageSeance({
    super.key,
    required this.titre,
    required this.body,
    this.sousTitre,
    this.fin,
    this.bas,
    this.onRetour,
    this.largeurMax = 640,
  });

  final String titre;
  final String? sousTitre;

  /// Élément à droite de l'en-tête.
  final Widget? fin;
  final Widget body;

  /// Bouton fixé en bas (au-dessus du clavier et de la barre de gestes).
  final Widget? bas;
  final VoidCallback? onRetour;
  final double largeurMax;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: largeurMax),
            child: Column(
              children: [
                EnTeteSeance(titre: titre, sousTitre: sousTitre, fin: fin, onRetour: onRetour),
                Expanded(child: body),
                if (bas != null) Padding(padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(18)), child: bas),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lien en texte blanc gras (« Historique », « Réordonner »), zone d'appui
/// de 44 de haut.
class LienTexte extends StatelessWidget {
  const LienTexte({super.key, required this.label, required this.onTap, this.couleur});

  final String label;
  final VoidCallback onTap;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: AppTokens.radius8,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: k(36)),
          padding: EdgeInsets.symmetric(horizontal: k(6)),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), fontWeight: FontWeight.w700, color: couleur ?? c.text),
          ),
        ),
      ),
    );
  }
}

/// Icône blanche au trait dans un carré gris arrondi.
class CarreIcone extends StatelessWidget {
  const CarreIcone({super.key, required this.child, this.taille, this.rond = false});

  final Widget child;
  final double? taille;
  final bool rond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = taille ?? k(36);
    return Container(
      width: t,
      height: t,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface2,
        shape: rond ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: rond ? null : BorderRadius.circular(t * 0.28),
      ),
      child: IconTheme.merge(data: IconThemeData(color: c.text, size: t * 0.5), child: child),
    );
  }
}

/// Ligne encadrée (`.fld` de la maquette « Terminer la séance ») : icône
/// grise, libellé en gras, valeur ou chevron à droite.
class LigneCadre extends StatelessWidget {
  const LigneCadre({super.key, required this.label, this.icone, this.valeur, this.fin, this.onTap, this.estompe = false, this.lignes = 1});

  final Widget? icone;
  final String label;

  /// Valeur à droite, en gris.
  final String? valeur;

  /// Élément de fin ; par défaut un chevron si la ligne est cliquable.
  final Widget? fin;
  final VoidCallback? onTap;

  /// Libellé en gris (rien de saisi).
  final bool estompe;
  final int lignes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rayon = BorderRadius.circular(k(14));
    return Semantics(
      button: onTap != null,
      child: InkWell(
        borderRadius: rayon,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: k(48)),
          padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(8)),
          decoration: BoxDecoration(borderRadius: rayon, border: Border.all(color: c.surface3, width: 1.5)),
          child: Row(
            children: [
              if (icone != null) ...[
                IconTheme.merge(data: IconThemeData(color: c.text2, size: k(18)), child: icone!),
                SizedBox(width: k(12)),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: lignes,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTokens.fontUi,
                    fontSize: k(13),
                    height: 1.35,
                    fontWeight: estompe ? FontWeight.w400 : FontWeight.w600,
                    color: estompe ? c.text2 : c.text,
                  ),
                ),
              ),
              if (valeur != null) ...[
                SizedBox(width: k(8)),
                Text(
                  valeur!,
                  maxLines: 1,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), color: c.text2, fontFeatures: AppTokens.tabular),
                ),
              ],
              if (fin != null) ...[SizedBox(width: k(8)), fin!] else if (onTap != null) ...[
                SizedBox(width: k(8)),
                Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne en carte (liste de séances, de routines) : vignette, titre, détail
/// gris, élément de fin.
class LigneCarte extends StatelessWidget {
  const LigneCarte({super.key, required this.titre, this.tete, this.detail, this.fin, this.onTap, this.chevron = true});

  final Widget? tete;
  final String titre;
  final String? detail;
  final Widget? fin;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rayon = BorderRadius.circular(k(14));
    return Semantics(
      button: onTap != null,
      child: Material(
        color: c.surface,
        borderRadius: rayon,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(k(8)),
            child: Row(
              children: [
                if (tete != null) ...[tete!, SizedBox(width: k(12))] else SizedBox(width: k(4)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, fontWeight: FontWeight.w700, color: c.text),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2, fontFeatures: AppTokens.tabular),
                        ),
                    ],
                  ),
                ),
                if (fin != null) ...[SizedBox(width: k(8)), fin!] else if (chevron && onTap != null) ...[
                  SizedBox(width: k(8)),
                  Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                  SizedBox(width: k(4)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile d'un chiffre (`.stat` du calendrier) : gros chiffre, libellé gris.
class TuileChiffre extends StatelessWidget {
  const TuileChiffre({super.key, required this.valeur, required this.label});

  final String valeur;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(10)),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              maxLines: 1,
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(17), height: 1.3, fontWeight: FontWeight.w800, color: c.text, fontFeatures: AppTokens.tabular),
            ),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10.5), height: 1.35, color: c.text2)),
        ],
      ),
    );
  }
}

/// État vide au design validé : icône blanche dans un rond gris, titre,
/// explication, bouton blanc.
class VideSeance extends StatelessWidget {
  const VideSeance({super.key, required this.icone, required this.titre, this.message, this.action, this.onAction});

  final Widget icone;
  final String titre;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: margeSeance * 1.5, vertical: k(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarreIcone(rond: true, taille: k(56), child: icone),
              SizedBox(height: k(14)),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(16), height: 1.3, fontWeight: FontWeight.w700, color: c.text),
              ),
              if (message != null) ...[
                SizedBox(height: k(4)),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
                ),
              ],
              if (action != null && onAction != null) ...[
                SizedBox(height: k(18)),
                BoutonSeance(label: action!, fond: c.bouton, encre: c.onBouton, marge: k(22), onTap: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
