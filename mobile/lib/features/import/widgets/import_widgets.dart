import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

const _pad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);

/// Marge latérale standard.
Widget padded(Widget child) => Padding(padding: _pad, child: child);

/// Étapes de l'import, en tête des écrans du parcours.
class EtapesImport extends StatelessWidget {
  const EtapesImport({super.key, required this.courante});

  /// 0 fichier, 1 aperçu, 2 exercices, 3 options, 4 import.
  final int courante;

  static const libelles = ['Fichier', 'Aperçu', 'Exercices', 'Options', 'Import'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 4, AppTokens.gutter + 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < libelles.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppTokens.normal,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= courante ? c.text : c.veilActive,
                      borderRadius: AppTokens.radiusPill,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ÉTAPE ${courante + 1} SUR ${libelles.length} · ${libelles[courante].toUpperCase()}',
            style: AppType.overline(),
          ),
        ],
      ),
    );
  }
}

/// Grille de chiffres (2 colonnes sur le Fold fermé, 3 ou 4 ouvert).
class GrilleStats extends StatelessWidget {
  const GrilleStats({super.key, required this.items});

  final List<({String label, String valeur, String? unite, IconData icon})> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 640 ? 4 : (box.maxWidth >= 420 ? 3 : 2);
      const gap = 10.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconHalo(icon: it.icon, size: 32),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: it.valeur, style: AppType.number(22)),
                        if (it.unite != null)
                          TextSpan(text: ' ${it.unite}', style: AppType.rowSubtitle().copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowSubtitle()),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Barres des séances par mois (clé `aaaa-mm`).
class BarresMois extends StatelessWidget {
  const BarresMois({super.key, required this.parMois, this.hauteur = 110});

  final Map<String, int> parMois;
  final double hauteur;

  static const _abr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (parMois.isEmpty) return const SizedBox.shrink();
    // Tous les mois de la période, même vides.
    final cles = parMois.keys.toList()..sort();
    final d0 = DateTime.parse('${cles.first}-01');
    final d1 = DateTime.parse('${cles.last}-01');
    final mois = <DateTime>[];
    for (var d = d0; !d.isAfter(d1); d = DateTime(d.year, d.month + 1)) {
      mois.add(d);
    }
    final vus = mois.length > 18 ? mois.sublist(mois.length - 18) : mois;
    final max = vus.map((m) => parMois[_cle(m)] ?? 0).fold(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: hauteur,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in vus)
                Expanded(
                  child: Tooltip(
                    message: '${Fmt.mois(m)} : ${Fmt.pluriel(parMois[_cle(m)] ?? 0, 'séance')}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 26,
                            height: ((parMois[_cle(m)] ?? 0) / max * (hauteur - 4)).clamp(3, hauteur),
                            decoration: BoxDecoration(
                              color: (parMois[_cle(m)] ?? 0) == 0 ? c.veilActive : c.text,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('${_abr[vus.first.month - 1]} ${vus.first.year}', style: AppType.rowSubtitle()),
            const Spacer(),
            Text('${_abr[vus.last.month - 1]} ${vus.last.year}', style: AppType.rowSubtitle()),
          ],
        ),
      ],
    );
  }

  static String _cle(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// Carte d'un choix exclusif (mode d'import, format de sauvegarde).
class CarteChoix extends StatelessWidget {
  const CarteChoix({
    super.key,
    required this.titre,
    required this.selectionne,
    required this.onTap,
    this.description,
    this.icon,
    this.trailing,
  });

  final String titre;
  final String? description;
  final bool selectionne;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        border: true,
        borderColor: selectionne ? c.text : c.line,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            if (icon != null) ...[
              IconHalo(icon: icon!, size: 38),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: AppType.rowTitle()),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(description!, style: AppType.rowSubtitle()),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: AppTokens.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectionne ? c.bouton : Colors.transparent,
                border: Border.all(color: selectionne ? c.bouton : c.text3, width: 2),
              ),
              child: selectionne ? Icon(Icons.check_rounded, size: 14, color: c.onBouton) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Encadré d'information, d'avertissement ou d'erreur.
class Encart extends StatelessWidget {
  const Encart({super.key, required this.texte, this.titre, this.ton = TonEncart.info, this.action});

  final String? titre;
  final String texte;
  final TonEncart ton;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (couleur, icon) = switch (ton) {
      TonEncart.info => (c.text2, Icons.info_outline_rounded),
      TonEncart.attention => (c.warning, Icons.warning_amber_rounded),
      TonEncart.erreur => (c.error, Icons.error_outline_rounded),
      TonEncart.succes => (c.success, Icons.check_circle_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: AppTokens.radius16,
        border: Border.all(color: couleur.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titre != null) ...[
                  Text(titre!, style: AppType.rowTitle().copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                ],
                Text(texte, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 13)),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TonEncart { info, attention, erreur, succes }

/// Écran ouvert sans fichier analysé (lien direct, appli relancée).
class SansFichier extends StatelessWidget {
  const SansFichier({super.key, required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: titre,
      body: Center(
        child: EmptyState(
          icon: Icons.upload_file_rounded,
          title: 'Aucun fichier en cours',
          message: 'Choisis d\'abord le fichier à importer : l\'analyse se fait en quelques secondes.',
          actionLabel: 'Choisir un fichier',
          onAction: () => context.go('/import/fichier'),
          secondaryLabel: 'Retour à l\'import',
          onSecondary: () => context.go('/import'),
        ),
      ),
    );
  }
}

/// Deux volets côte à côte sur le Fold ouvert, empilés sinon.
class DeuxVolets extends StatelessWidget {
  const DeuxVolets({super.key, required this.gauche, required this.droite, this.seuil = 820});

  final List<Widget> gauche;
  final List<Widget> droite;
  final double seuil;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < seuil) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...gauche, ...droite]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gauche)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: droite)),
        ],
      );
    });
  }
}

/// Période lisible : « du 3 janv. 2025 au 28 sept. 2026 ».
String periode(DateTime? debut, DateTime? fin) {
  if (debut == null || fin == null) return 'Aucune date';
  if (Fmt.dateCourte(debut) == Fmt.dateCourte(fin)) return 'Le ${Fmt.date(debut)}';
  return 'Du ${Fmt.date(debut)} au ${Fmt.date(fin)}';
}

/// Volume lisible en tonnes au-delà de 10 t.
({String valeur, String unite}) volumeLisible(double kg) {
  if (kg >= 10000) return (valeur: Fmt.n(kg / 1000), unite: 't');
  return (valeur: Fmt.n(kg, decimals: 0), unite: 'kg');
}

/// Sous-page du module. La barre du bas est posée dans le corps : dans
/// `SubPageScaffold(bottomBar:)`, le `Center` de `ContentWidth` prend toute la
/// hauteur (bogue signalé à la fondation). Une fois corrigé, remplacer par
/// `SubPageScaffold` suffit.
class PageImport extends StatelessWidget {
  const PageImport({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.onBack,
    this.closeIcon = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;
  final VoidCallback? onBack;
  final bool closeIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final barre = bottomBar;
    return SubPageScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      onBack: onBack,
      closeIcon: closeIcon,
      body: barre == null
          ? body
          : Column(
              children: [
                Expanded(child: body),
                DecoratedBox(
                  decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10),
                      child: barre,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
