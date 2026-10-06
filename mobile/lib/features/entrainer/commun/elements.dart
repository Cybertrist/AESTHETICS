import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../bibliotheque/widgets/exercise_media.dart';
import 'traits.dart';
import '../../profil/data/grades.dart';
import '../../profil/widgets/ecusson.dart';

/// Marge latérale des écrans de l'onglet (18 sur la maquette).
const margeEcran = 22.0;

/// Largeur maximale du contenu sur un écran large.
const largeurContenu = 620.0;

TextStyle _txt(double taille, FontWeight poids, Color couleur, {double? hauteur, double? espacement}) => TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: taille,
      fontWeight: poids,
      color: couleur,
      height: hauteur,
      letterSpacing: espacement,
    );

/// Styles de texte de la maquette, à l'échelle du téléphone.
abstract final class TexteEntrainer {
  static TextStyle titreOnglet(BuildContext c) => _txt(25, FontWeight.w700, c.colors.text, hauteur: 1.3);
  static TextStyle titrePage(BuildContext c) => _txt(21, FontWeight.w700, c.colors.text, hauteur: 1.3);
  static TextStyle titreSection(BuildContext c) => _txt(20, FontWeight.w700, c.colors.text, hauteur: 1.3);
  static TextStyle ligne(BuildContext c) => _txt(16, FontWeight.w600, c.colors.text, hauteur: 1.35);
  static TextStyle ligneForte(BuildContext c) => _txt(17.5, FontWeight.w700, c.colors.text, hauteur: 1.35);
  static TextStyle detail(BuildContext c) => _txt(14, FontWeight.w400, c.colors.text2, hauteur: 1.4);
  static TextStyle surtitre(BuildContext c) => _txt(12.5, FontWeight.w600, c.colors.text2, hauteur: 1.35, espacement: 1.5);
}

/// Le thème Material écarte un peu les lettres du texte courant ; la
/// maquette non. À poser autour d'un écran ou du contenu d'un panneau.
class TexteNet extends StatelessWidget {
  const TexteNet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(style: const TextStyle(letterSpacing: 0), child: child);
}

/// Petite étiquette en capitales grises au-dessus d'un bloc.
class Surtitre extends StatelessWidget {
  const Surtitre(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) =>
      Text(texte.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.surtitre(context));
}

/// Bouton rond de 55 : gris plein (en-têtes), voilé (sur une image) ou nu.
class BoutonRond extends StatelessWidget {
  const BoutonRond({super.key, required this.icone, required this.label, required this.onTap, this.fond, this.taille = 55, this.largeur});

  final Widget icone;

  /// Texte lu et affiché en infobulle.
  final String label;
  final VoidCallback? onTap;

  /// Couleur du disque ; transparent pour un bouton nu.
  final Color? fond;
  final double taille;

  /// Largeur de la zone touchée quand elle diffère de la hauteur.
  final double? largeur;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: fond ?? c.surface2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: largeur ?? taille,
              height: taille,
              child: Center(child: IconTheme.merge(data: IconThemeData(color: c.text), child: icone)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton nu d'en-tête ou de ligne (retour, trois points, trier...).
class BoutonNu extends StatelessWidget {
  const BoutonNu({super.key, required this.trait, required this.label, required this.onTap, this.taille = 22.5, this.largeur = 55, this.couleur});

  final Trait trait;
  final String label;
  final VoidCallback? onTap;
  final double taille;
  final double largeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => BoutonRond(
        icone: IconeTrait(trait, size: taille, color: couleur),
        label: label,
        onTap: onTap,
        fond: Colors.transparent,
        largeur: largeur,
      );
}

/// En-tête d'un volet de l'onglet : le titre en grand, un bouton rond à droite.
class EnTeteOnglet extends StatelessWidget {
  const EnTeteOnglet({super.key, required this.titre, this.action});

  final String titre;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(margeEcran, 12, margeEcran, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Expanded(child: Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.titreOnglet(context))),
              ?action,
            ],
          ),
        ),
      );
}

/// En-tête d'une page : retour dans un rond gris, titre en gras (et une
/// ligne grise dessous), actions à droite.
class EnTetePage extends StatelessWidget {
  const EnTetePage({super.key, required this.titre, this.sousTitre, this.onBack, this.actions = const [], this.retour = true, this.fermer = false, this.marge = margeEcran});

  /// Marge latérale (celle du contenu de la page).
  final double marge;

  final String titre;
  final String? sousTitre;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool retour;

  /// Croix à la place du chevron (un éditeur que l'on quitte).
  final bool fermer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(marge, 12, actions.isEmpty ? marge : (marge - 12).clamp(4.0, marge), 12),
        child: Row(
          children: [
            if (retour) ...[
              BoutonRond(
                icone: IconeTrait(fermer ? Trait.fermer : Trait.retour, size: fermer ? 21 : 22.5),
                label: fermer ? 'Fermer' : 'Retour',
                taille: 48,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Un titre long passe sur deux lignes plutôt que d'être coupé.
                  Text(
                    titre,
                    maxLines: sousTitre == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TexteEntrainer.titrePage(context).copyWith(height: 1.2),
                  ),
                  if (sousTitre != null)
                    Text(sousTitre!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context).copyWith(fontSize: 13.5, height: 1.3)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

/// Page noire avec son en-tête fixe et un contenu limité en largeur.
class PageEntrainer extends StatelessWidget {
  const PageEntrainer({super.key, required this.entete, required this.child, this.bas, this.sousEntete, this.largeur = largeurContenu, this.filetBas = false, this.marge = margeEcran});

  /// Marge latérale de la zone du bas.
  final double marge;

  /// Largeur maximale du contenu.
  final double largeur;

  /// Filet au-dessus de la zone du bas (le contenu défile dessous).
  final bool filetBas;

  final Widget entete;

  /// Rangée fixe sous l'en-tête (sélecteur, onglets).
  final Widget? sousEntete;
  final Widget child;

  /// Zone fixée en bas (bouton principal).
  final Widget? bas;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: largeur),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                entete,
                ?sousEntete,
                Expanded(child: child),
                // La zone du bas reste au-dessus de la barre de gestes.
                if (bas != null)
                  DecoratedBox(
                    decoration: BoxDecoration(border: filetBas ? Border(top: BorderSide(color: c.line)) : null),
                    child: SafeArea(
                      top: false,
                      child: Padding(padding: EdgeInsets.fromLTRB(marge, 12, marge, filetBas ? 12 : 22), child: bas),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Champ de recherche en pilule gris violacé de la maquette.
class RecherchePilule extends StatefulWidget {
  const RecherchePilule({super.key, required this.hint, this.controller, this.onChanged, this.autofocus = false});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<RecherchePilule> createState() => _RecherchePiluleState();
}

class _RecherchePiluleState extends State<RecherchePilule> {
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_maj);
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_maj);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 17, height: 1.3, fontWeight: FontWeight.w400, color: c.text);
    const bord = OutlineInputBorder(borderRadius: AppTokens.radiusPill, borderSide: BorderSide.none);
    return SizedBox(
      height: 55,
      child: TextField(
        controller: _ctrl,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: c.text,
        style: style,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: style.copyWith(color: c.text.withValues(alpha: 0.88)),
          filled: true,
          fillColor: c.searchFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: bord,
          enabledBorder: bord,
          focusedBorder: bord,
          prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 55),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 10),
            child: Align(widthFactor: 1, child: IconeTrait(Trait.loupe, size: 17.5, color: c.text.withValues(alpha: 0.88))),
          ),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  icon: IconeTrait(Trait.fermer, size: 18, color: c.text.withValues(alpha: 0.88)),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged?.call('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Puce d'action ou de filtre en pilule grise : icône au trait et libellé.
class PuceAction extends StatelessWidget {
  const PuceAction({super.key, required this.trait, required this.label, required this.onTap, this.active = false, this.plein = false});

  final Trait trait;
  final String label;
  final VoidCallback? onTap;

  /// Filtre en service : cadre blanc.
  final bool active;

  /// Icône pleine (signet d'un favori).
  final bool plein;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: c.surface2,
        shape: StadiumBorder(side: active ? BorderSide(color: c.text, width: 1.5) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 17.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                plein ? _SignetPlein(taille: 19, couleur: c.text) : IconeTrait(trait, size: 19, color: c.text),
                const SizedBox(width: 9),
                Text(label, maxLines: 1, style: _txt(15.6, FontWeight.w600, c.text, hauteur: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signet au trait, rempli quand l'élément est en favori.
class Signet extends StatelessWidget {
  const Signet({super.key, required this.plein, this.taille = 20, this.couleur});

  final bool plein;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final col = couleur ?? context.colors.text;
    return plein ? _SignetPlein(taille: taille, couleur: col) : IconeTrait(Trait.signet, size: taille, color: col);
  }
}

class _SignetPlein extends StatelessWidget {
  const _SignetPlein({required this.taille, required this.couleur});
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: taille, child: CustomPaint(painter: _SignetPeintre(couleur)));
}

class _SignetPeintre extends CustomPainter {
  _SignetPeintre(this.couleur);
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    final p = Path()
      ..moveTo(6.5, 3.5)
      ..lineTo(15.5, 3.5)
      ..lineTo(15.5, 18.5)
      ..lineTo(11, 15)
      ..lineTo(6.5, 18.5)
      ..close();
    canvas.drawPath(p, Paint()..color = couleur);
    canvas.drawPath(
      p,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SignetPeintre old) => old.couleur != couleur;
}

/// Tuile carrée grise (vignette d'une ligne) : sigle, icône ou image.
class Tuile extends StatelessWidget {
  const Tuile({super.key, required this.child, this.taille = 65, this.fond, this.rayon});

  final Widget child;
  final double taille;
  final Color? fond;
  final double? rayon;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: fond ?? context.colors.surface2, borderRadius: BorderRadius.circular(rayon ?? taille * 0.215)),
        child: child,
      );
}

/// Pose marquante d'un exercice (le sommet du mouvement), sinon sa vignette.
String? poseDe(Exercise? e) {
  if (e == null) return null;
  for (final src in e.media.imagesLocales) {
    if (src.contains('-peak')) return src;
  }
  return e.media.thumbnail;
}

/// Image d'un exercice dans une tuile grise, jamais étirée.
class TuileExercice extends StatelessWidget {
  const TuileExercice(this.exercise, {super.key, this.taille = 65, this.fond});

  final Exercise? exercise;
  final double taille;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = poseDe(exercise);
    final secours = TraitIcone(AppIcone.haltere, size: taille * 0.42, color: c.text2);
    return Tuile(
      taille: taille,
      fond: fond,
      child: src == null
          ? secours
          : mediaImage(src, cacheWidth: (taille * MediaQuery.devicePixelRatioOf(context)).round(), error: (_) => secours),
    );
  }
}

/// Bouton rond au contour gris avec le triangle de lecture : lancer une routine.
class BoutonLancer extends StatelessWidget {
  const BoutonLancer({super.key, required this.label, required this.onTap, this.taille = 50});

  final String label;
  final VoidCallback? onTap;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          shape: CircleBorder(side: BorderSide(color: c.text3, width: 1.9)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: taille,
              child: Center(child: IconeTrait(Trait.lecture, size: taille * 0.35, color: c.text)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte grise discrète aux coins ronds, avec un cadre fin en option.
class Carte extends StatelessWidget {
  const Carte({super.key, required this.child, this.padding = const EdgeInsets.all(17.5), this.rayon = 20, this.cadre = false, this.onTap, this.fond});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double rayon;
  final bool cadre;
  final VoidCallback? onTap;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: fond ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon),
        side: cadre ? BorderSide(color: c.surface3) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Marque d'un record : l'écusson « PR », doré pour le record en cours,
/// gris pour un ancien record.
class Medaille extends StatelessWidget {
  const Medaille({super.key, this.record = true, this.taille = 27});

  final bool record;
  final double taille;

  @override
  Widget build(BuildContext context) {
    // L'écusson « PR » : doré pour le record en cours, gris pour un ancien.
    return Semantics(
      label: record ? 'Record' : 'Ancien record',
      child: record
          ? Ecusson.record(largeur: taille * 1.15)
          : Ecusson(couleur: const Color(0xFF5A606A), picto: PictoGrade.trophee, texte: 'PR', largeur: taille * 1.15),
    );
  }
}

/// État vide discret, au style de l'onglet.
class Vide extends StatelessWidget {
  const Vide({super.key, required this.titre, this.message, this.action, this.onAction, this.trait});

  final String titre;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final Trait? trait;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: margeEcran + 8, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trait != null) ...[
            Tuile(taille: 65, child: IconeTrait(trait!, size: 26, color: c.text2)),
            const SizedBox(height: 18),
          ],
          Text(titre, textAlign: TextAlign.center, style: TexteEntrainer.ligneForte(context)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TexteEntrainer.detail(context)),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            BoutonSecondaire(label: action!, onPressed: onAction, petit: true),
          ],
        ],
      ),
    );
  }
}
