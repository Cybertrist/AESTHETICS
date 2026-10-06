import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/data/data.dart';
import '../../../../../core/models/models.dart';
import '../../../../../core/theme/theme.dart';
import '../../../commun/corps_colore.dart';
import '../../../commun/elements.dart';
import '../../../commun/palette.dart';
import '../../../commun/traits.dart';
import '../../logic/erreurs_frequentes.dart';
import '../../logic/exercise_notes.dart';
import '../../widgets/exercise_media.dart';

/// Exercices qui partagent le muscle principal, le plus proche d'abord.
List<Exercise> exercicesAlternatifs(Exercise e, List<Exercise> tous, {int max = 8}) {
  if (e.musclesPrincipaux.isEmpty) return const [];
  final p = e.musclesPrincipaux.toSet();
  final notes = <(Exercise, int)>[];
  for (final x in tous) {
    if (x.id == e.id || !x.musclesPrincipaux.any(p.contains)) continue;
    var s = x.musclesPrincipaux.where(p.contains).length * 4;
    s += x.musclesSecondaires.where(e.musclesSecondaires.contains).length;
    if (x.categorie == e.categorie) s += 2;
    if (x.equipement != e.equipement) s += 1;
    if (x.media.isEmpty) s -= 3;
    notes.add((x, s));
  }
  notes.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.nom.length.compareTo(b.$1.nom.length));
  return notes.take(max).map((e) => e.$1).toList();
}

/// Onglet « À propos » : l'animation en grand, les raccourcis, les muscles
/// ciblés sur le corps, les étapes, puis les exercices alternatifs.
class TabAPropos extends StatelessWidget {
  const TabAPropos({
    super.key,
    required this.exercise,
    required this.onPartager,
    required this.onNote,
    required this.onRemplacer,
    required this.onExercice,
  });

  final Exercise exercise;
  final VoidCallback onPartager;
  final VoidCallback onNote;
  final VoidCallback onRemplacer;
  final ValueChanged<Exercise> onExercice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = exercise;
    final repo = context.watch<ExerciseRepo>();
    final favori = repo.isFavori(e.id);
    final alternatives = exercicesAlternatifs(e, repo.all);
    // Les erreurs écrites pour cet exercice ; à défaut (un exercice personnel), les règles générales.
    final erreurs = ExercicesPlus.erreurs(e.id) ?? ErreursFrequentes.pour(e);
    final notes = ExerciseNotes.of(context.read<Store>());
    final couleurs = <Muscle, Teinte>{
      // Les principaux se peignent en dernier : dans le pack, certains calques se recouvrent
      // (les deltoïdes antérieurs et latéraux de face) et le muscle principal doit rester lisible.
      for (final m in e.musclesSecondaires)
        if (!e.musclesPrincipaux.contains(m)) m: Teinte.secondaire,
      for (final m in e.musclesPrincipaux) m: Teinte.principal,
    };
    const marge = EdgeInsets.symmetric(horizontal: margeEcran);

    Widget titre(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(margeEcran, 25, margeEcran, 15),
          child: Text(t, style: TexteEntrainer.titreSection(context)),
        );

    Widget puces(List<String> lignes, Trait trait, Color couleur) => Padding(
          padding: marge,
          child: Column(
            children: [
              for (final t in lignes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: IconeTrait(trait, size: 17, color: couleur)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: TexteEntrainer.detail(context).copyWith(fontSize: 15))),
                    ],
                  ),
                ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(top: 17.5, bottom: 36),
      children: [
        // En paysage, le cadre ne dépasse pas les deux tiers de la hauteur :
        // sinon l'animation seule remplit plus que l'écran.
        Padding(
          padding: marge,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(240.0, MediaQuery.sizeOf(context).height * 0.62) * 1.1),
              child: AnimationExercice(e),
            ),
          ),
        ),
        const SizedBox(height: 12.5),
        SizedBox(
          height: 45 + 25,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(margeEcran, 12.5, margeEcran - 10, 12.5),
            children: [
              for (final p in [
                PuceAction(
                  trait: Trait.signet,
                  plein: favori,
                  label: 'Favoris',
                  onTap: () => repo.toggleFavori(e.id),
                ),
                PuceAction(trait: Trait.partager, label: 'Partager', onTap: onPartager),
                PuceAction(trait: Trait.crayon, label: 'Note', onTap: onNote),
                PuceAction(trait: Trait.remplacer, label: 'Remplacer', onTap: onRemplacer),
              ])
                Padding(padding: const EdgeInsets.only(right: 10), child: p),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: notes,
          builder: (context, _) {
            final n = notes.noteOf(e.id);
            if (n == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(margeEcran, 6, margeEcran, 0),
              child: Carte(
                onTap: onNote,
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Surtitre('Ma note'),
                    const SizedBox(height: 5),
                    Text(n, style: TexteEntrainer.detail(context).copyWith(fontSize: 15, color: c.text)),
                  ],
                ),
              ),
            );
          },
        ),
        titre('Muscles ciblés'),
        if (e.tousMuscles.isEmpty)
          Padding(padding: marge, child: Text('Aucun muscle renseigné pour cet exercice.', style: TexteEntrainer.detail(context)))
        else ...[
          Padding(padding: marge, child: IgnorePointer(child: CorpsFaceDos(couleurs: couleurs, hauteur: 295))),
          const SizedBox(height: 15),
          if (e.musclesPrincipaux.isNotEmpty) _Legende(titre: 'Principal', couleur: c.muscle, muscles: e.musclesPrincipaux),
          if (e.musclesSecondaires.isNotEmpty) ...[
            const SizedBox(height: 15),
            _Legende(titre: 'Secondaire', couleur: PaletteEntrainer.secondaire, muscles: e.musclesSecondaires),
          ],
        ],
        titre('Comment faire'),
        if (e.instructions.isEmpty)
          Padding(
            padding: marge,
            child: Text(
              e.perso ? 'Aucune étape. Ajoute-les en modifiant l’exercice.' : 'Pas d’explication pour cet exercice.',
              style: TexteEntrainer.detail(context),
            ),
          )
        else
          Padding(padding: marge, child: _Frise(etapes: e.instructions)),
        if (alternatives.isNotEmpty) ...[
          titre('Exercices alternatifs'),
          SizedBox(
            height: 165 / 1.05 + 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: marge,
              itemCount: alternatives.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12.5),
              itemBuilder: (context, i) => _Alternative(exercise: alternatives[i], onTap: () => onExercice(alternatives[i])),
            ),
          ),
        ],
        if (e.conseils.isNotEmpty) ...[titre('Conseils'), puces(e.conseils, Trait.coche, c.foretClair)],
        if (erreurs.isNotEmpty) ...[titre('À éviter'), puces(erreurs, Trait.fermer, c.error)],
        if (e.perso && (e.notes?.isNotEmpty ?? false)) ...[
          titre('Notes de l’exercice'),
          Padding(padding: marge, child: Text(e.notes!, style: TexteEntrainer.detail(context).copyWith(fontSize: 15))),
        ],
        if (e.media.credit != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(margeEcran, 22, margeEcran, 0),
            child: Text(e.media.credit!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 11.5, color: c.text3)),
          ),
      ],
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende({required this.titre, required this.couleur, required this.muscles});

  final String titre;
  final Color couleur;
  final List<Muscle> muscles;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: margeEcran),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12.5, height: 12.5, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(titre, style: TexteEntrainer.ligneForte(context)),
              ],
            ),
            for (final m in muscles)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m.label, style: TexteEntrainer.detail(context).copyWith(fontSize: 16)),
              ),
          ],
        ),
      );
}

/// Étapes numérotées, reliées par un trait.
class _Frise extends StatelessWidget {
  const _Frise({required this.etapes});
  final List<String> etapes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final (i, texte) in etapes.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 25,
                  child: Column(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 13, fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
                        ),
                      ),
                      if (i < etapes.length - 1) Expanded(child: Container(width: 1.9, color: c.surface2)),
                    ],
                  ),
                ),
                const SizedBox(width: 12.5),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.5, bottom: i < etapes.length - 1 ? 11 : 0),
                    child: Text(
                      texte,
                      style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15, height: 1.35, fontWeight: FontWeight.w400, color: c.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Alternative extends StatelessWidget {
  const _Alternative({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = poseDe(exercise);
    return SizedBox(
      width: 165,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17.5), side: BorderSide(color: c.surface3)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.05,
                child: ColoredBox(
                  color: c.surface2,
                  child: src == null ? const SizedBox.shrink() : mediaImage(src, cacheWidth: 420),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12.5, 11, 12.5, 0),
                child: Text(
                  exercise.nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 15.6, height: 1.25, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12.5, 2.5, 12.5, 0),
                child: Text(exercise.categorieLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TexteEntrainer.detail(context).copyWith(fontSize: 13.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'animation de l'exercice en grand, avec pause et plein écran.
/// Enchaîne les sources : animation, animation de secours, poses locales
/// alternées, puis photos en ligne.
class AnimationExercice extends StatefulWidget {
  const AnimationExercice(this.exercise, {super.key, this.rapport = 1.1, this.boutons = true});

  final Exercise exercise;

  /// Largeur sur hauteur du cadre.
  final double rapport;
  final bool boutons;

  @override
  State<AnimationExercice> createState() => _AnimationExerciceState();
}

class _AnimationExerciceState extends State<AnimationExercice> {
  static const _locales = '#locales';
  List<String> _sources = const [];
  int _index = 0;
  int _photo = 0;
  Timer? _timer;
  bool _avance = false;
  bool _pause = false;

  @override
  void initState() {
    super.initState();
    _preparer();
  }

  @override
  void didUpdateWidget(covariant AnimationExercice old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id || !identical(old.exercise.media, widget.exercise.media)) {
      _index = 0;
      _photo = 0;
      _pause = false;
      _preparer();
    }
  }

  void _preparer() {
    final m = widget.exercise.media;
    _sources = [?m.gif, ?m.gifSecours, if (m.imagesLocales.isNotEmpty) _locales, ...m.images];
    _minuteur();
  }

  void _minuteur() {
    _timer?.cancel();
    _timer = null;
    final locales = widget.exercise.media.imagesLocales;
    if (!_pause && _index < _sources.length && _sources[_index] == _locales && locales.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (mounted) setState(() => _photo = (_photo + 1) % locales.length);
      });
    }
  }

  /// Source en échec : on passe à la suivante après l'image courante.
  void _suivante() {
    if (_avance) return;
    _avance = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _avance = false;
      if (!mounted || _index >= _sources.length) return;
      setState(() => _index++);
      _minuteur();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _basculer() {
    setState(() => _pause = !_pause);
    _minuteur();
  }

  void _pleinEcran() => Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => _PleinEcran(exercise: widget.exercise),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));

  Widget _image(BuildContext context) {
    final c = context.colors;
    final m = widget.exercise.media;
    final fixe = poseDe(widget.exercise);
    final secours = Center(child: IconeTrait(Trait.image, size: 44, color: c.text3));
    if (_index >= _sources.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _sources.isEmpty ? 'Pas d’image pour cet exercice' : 'Animation indisponible',
            textAlign: TextAlign.center,
            style: TexteEntrainer.detail(context),
          ),
        ),
      );
    }
    // En pause : la pose marquante, immobile.
    if (_pause && fixe != null) return mediaImage(fixe, error: (_) => secours);
    final src = _sources[_index];
    if (src == _locales) {
      return mediaImage(m.imagesLocales[_photo % m.imagesLocales.length], error: (_) {
        _suivante();
        return const SizedBox.shrink();
      });
    }
    final attente = fixe != null ? mediaImage(fixe) : const SizedBox.shrink();
    return mediaImage(
      src,
      loading: (_) => attente,
      error: (_) {
        _suivante();
        return attente;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.exercise;
    final disponible = _index < _sources.length;
    // Une pose fixe (maintien, étirement) n'a rien à mettre en pause.
    final anime = disponible && (_sources[_index] != _locales || e.media.imagesLocales.length > 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: widget.rapport,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(22.5)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(image: true, label: '${e.nom}, animation', child: _image(context)),
                ),
                if (widget.boutons && anime)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: BoutonNu(
                      trait: _pause ? Trait.lectureCercle : Trait.pause,
                      label: _pause ? 'Relancer l’animation' : 'Mettre l’animation en pause',
                      onTap: _basculer,
                    ),
                  ),
                if (widget.boutons && disponible)
                  Positioned(bottom: 10, right: 10, child: BoutonNu(trait: Trait.pleinEcran, label: 'Plein écran', onTap: _pleinEcran)),
              ],
            ),
          ),
        ),
        if (e.media.mp4 case final video? when video.isNotEmpty && isDirectVideo(video)) ...[
          const SizedBox(height: 12),
          ExerciseVideo(url: video, maxSize: 420),
        ],
      ],
    );
  }
}

/// L'animation seule, sur fond noir, à la taille de l'écran.
class _PleinEcran extends StatelessWidget {
  const _PleinEcran({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = exercise.media;
    final src = m.gif ?? m.gifSecours ?? poseDe(exercise);
    return Scaffold(
      backgroundColor: c.bg,
      body: TexteNet(
        child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: src == null ? const SizedBox.shrink() : InteractiveViewer(maxScale: 4, child: mediaImage(src)),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: BoutonRond(icone: const IconeTrait(Trait.fermer, size: 22), label: 'Fermer', onTap: () => Navigator.of(context).pop()),
            ),
            Positioned(
              left: margeEcran,
              right: 90,
              top: 22,
              child: Text(exercise.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: TexteEntrainer.titrePage(context)),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
