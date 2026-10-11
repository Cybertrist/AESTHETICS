import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/social_repo.dart';

/// Marge des pages, comme sur l'accueil.
const margeSociale = 22.0;

TextStyle ts(double taille, FontWeight poids, Color couleur, {double hauteur = 1.3}) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: taille,
      height: hauteur,
      fontWeight: poids,
      color: couleur,
      fontFeatures: AppTokens.tabular,
    );

/// La pastille d'une personne : sa photo, ou ses initiales sur sa couleur.
class Pastille2 extends StatelessWidget {
  const Pastille2(this.ami, {super.key, this.taille = 50});
  final Ami ami;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final photo = ami.photo;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Color(ami.couleur), shape: BoxShape.circle),
      child: photo != null && File(photo).existsSync()
          ? Image.file(File(photo), fit: BoxFit.cover, width: taille, height: taille, cacheWidth: (taille * 3).round())
          : Text(
              ami.prenom.trim().isEmpty ? '?' : String.fromCharCode(ami.prenom.trim().runes.first).toUpperCase(),
              style: ts(taille * 0.42, FontWeight.w800, Colors.white, hauteur: 1),
            ),
    );
  }
}

/// La flamme et le nombre de semaines d'affilée.
class SerieAmi extends StatelessWidget {
  const SerieAmi(this.semaines, {super.key, this.taille = 14});
  final int semaines;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TraitIcone(AppIcone.flamme, size: taille + 4, color: semaines == 0 ? c.text3 : c.orange),
        const SizedBox(width: 3),
        Text('$semaines', style: ts(taille, FontWeight.w800, semaines == 0 ? c.text3 : c.text, hauteur: 1)),
      ],
    );
  }
}

/// Une carte grise aux coins ronds, comme celles de l'accueil.
class CarteSociale extends StatelessWidget {
  const CarteSociale({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.contour = false});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Un simple trait gris sur le fond noir, sans remplissage.
  final bool contour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: contour ? Colors.transparent : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: contour ? BorderSide(color: c.surface3, width: 1.5) : BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Un intertitre de section, en petites capitales grises.
class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key, this.droite});
  final String texte;
  final String? droite;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Row(
        children: [
          Expanded(child: Text(texte, style: ts(19, FontWeight.w700, c.text))),
          if (droite != null) Text(droite!, style: ts(14, FontWeight.w600, c.text2)),
        ],
      ),
    );
  }
}

/// Le rappel que ces écrans sont un aperçu : rien n'est encore envoyé.
class BandeauApercu extends StatelessWidget {
  const BandeauApercu({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(8)),
            child: Text('APERÇU', style: ts(10.5, FontWeight.w800, c.bg, hauteur: 1.2)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Des personnes d\'exemple : rien n\'est encore envoyé.', style: ts(12.5, FontWeight.w500, c.text2))),
        ],
      ),
    );
  }
}

/// Un chiffre et son libellé dessous.
class Chiffre extends StatelessWidget {
  const Chiffre(this.valeur, this.libelle, {super.key});
  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(libelle, style: ts(12.5, FontWeight.w500, c.text2)),
        const SizedBox(height: 2),
        Text(valeur, style: ts(18, FontWeight.w800, c.text, hauteur: 1.2)),
      ],
    );
  }
}

/// Un petit bouton en pilule, plein (blanc) ou discret (gris).
class Pilule extends StatelessWidget {
  const Pilule({super.key, required this.label, required this.onTap, this.plein = false, this.icone});
  final String label;
  final VoidCallback? onTap;
  final bool plein;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fond = plein ? c.bouton : c.surface2, encre = plein ? c.onBouton : c.text;
    return Material(
      color: onTap == null ? c.surface2 : fond,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[Icon(icone, size: 17, color: onTap == null ? c.text3 : encre), const SizedBox(width: 6)],
              Text(label, style: ts(14, FontWeight.w700, onTap == null ? c.text3 : encre, hauteur: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dit qu'une action n'est pas encore branchée, sans mentir sur ce qui s'est passé.
void bientot(BuildContext context, String quoi) => Toasts.show(context, '$quoi arrive avec les comptes. Rien n\'a été envoyé.');
