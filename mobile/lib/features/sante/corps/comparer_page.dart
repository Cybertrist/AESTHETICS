import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_widgets.dart';
import 'photos_pages.dart';

enum _Mode { curseur, cote }

/// Avant et après : curseur glissant ou côte à côte.
class ComparerPage extends StatefulWidget {
  const ComparerPage({super.key, this.avantId, this.apresId, this.vue});
  final String? avantId;
  final String? apresId;
  final PhotoVue? vue;

  @override
  State<ComparerPage> createState() => _ComparerPageState();
}

class _ComparerPageState extends State<ComparerPage> {
  String? _avant;
  String? _apres;
  _Mode _mode = _Mode.curseur;
  double _pos = 0.5;

  @override
  void initState() {
    super.initState();
    final photos = context.read<HealthRepo>().photos;
    final pool = widget.vue == null ? photos : photos.where((p) => p.vue == widget.vue).toList();
    _apres = widget.apresId ?? pool.firstOrNull?.id;
    final apres = photos.firstWhereOrNull((p) => p.id == _apres);
    final memeVue = pool.where((p) => p.id != _apres && (apres == null || p.vue == apres.vue)).toList();
    _avant = widget.avantId ?? memeVue.lastOrNull?.id ?? pool.lastWhereOrNull((p) => p.id != _apres)?.id;
  }

  Future<void> _choisir(bool avant) async {
    final photos = context.read<HealthRepo>().photos;
    final id = await showDialog<String>(
      context: context,
      builder: (dctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(avant ? 'Photo d\'avant' : 'Photo d\'après', style: context.textStyles.titleLarge),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 3 / 4),
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      final p = photos[i];
                      final actuel = p.id == (avant ? _avant : _apres);
                      return GestureDetector(
                        onTap: () => Navigator.of(dctx).pop(p.id),
                        child: ClipRRect(
                          borderRadius: AppTokens.radius12,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PhotoFichier(photo: p, cacheWidth: 240),
                              if (actuel) DecoratedBox(decoration: BoxDecoration(border: Border.all(color: context.colors.accent, width: 3), borderRadius: AppTokens.radius12)),
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(color: Colors.black54, borderRadius: AppTokens.radiusPill),
                                  child: Text('${Fmt.jourMois(p.date)} · ${p.vue.label}', style: AppType.rowSubtitle(color: Colors.white).copyWith(fontSize: 10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: PillButton.ghost(label: 'Annuler', onPressed: () => Navigator.of(dctx).pop())),
              ],
            ),
          ),
        ),
      ),
    );
    if (id != null) setState(() => avant ? _avant = id : _apres = id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final avant = repo.photos.firstWhereOrNull((p) => p.id == _avant);
    final apres = repo.photos.firstWhereOrNull((p) => p.id == _apres);

    if (repo.photos.length < 2 || avant == null || apres == null) {
      return SubPageScaffold(
        title: 'Comparer',
        haloColor: c.weight,
        body: Center(
          child: EmptyState(
            icon: Icons.compare_rounded,
            iconColor: c.weight,
            title: 'Il faut deux photos',
            message: 'Ajoutez une photo aujourd\'hui, puis une autre dans quelques semaines.',
            actionLabel: 'Ajouter une photo',
            onAction: () => ajouterPhoto(context),
            secondaryLabel: 'Toutes les photos',
            onSecondary: () => context.go('/sante/corps/photos'),
          ),
        ),
      );
    }

    // L'avant est toujours la plus ancienne des deux.
    final (a, b) = avant.date.isAfter(apres.date) ? (apres, avant) : (avant, apres);
    final jours = Dates.jour(b.date).difference(Dates.jour(a.date)).inDays;
    final dPoids = a.poidsKg != null && b.poidsKg != null ? b.poidsKg! - a.poidsKg! : null;

    return SubPageScaffold(
      title: 'Avant, après',
      subtitle: jours == 0 ? 'Le même jour' : '${Fmt.pluriel(jours, 'jour')} d\'écart',
      haloColor: c.weight,
      actions: [
        RoundIconButton(
          icon: Icons.swap_horiz_rounded,
          filled: false,
          tooltip: 'Inverser',
          onPressed: () => setState(() {
            final t = _avant;
            _avant = _apres;
            _apres = t;
          }),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: santePad,
            child: SegmentedControl<_Mode>(
              segments: const [(_Mode.curseur, 'Curseur'), (_Mode.cote, 'Côte à côte')],
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: santePad,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _mode == _Mode.curseur ? _curseur(a, b) : _cote(a, b),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: santePad,
            child: Row(
              children: [
                Expanded(child: _Etiquette(titre: 'Avant', photo: a, onTap: () => _choisir(true))),
                const SizedBox(width: 10),
                Expanded(child: _Etiquette(titre: 'Après', photo: b, onTap: () => _choisir(false))),
              ],
            ),
          ),
          if (dPoids != null) ...[
            const SizedBox(height: 12),
            AppCard(
              margin: santePad,
              child: Row(
                children: [
                  Expanded(child: MiniChiffre(label: 'Poids avant', value: Fmt.n(Fmt.poidsAffiche(a.poidsKg!, unite)), unit: unite.label)),
                  Expanded(child: MiniChiffre(label: 'Poids après', value: Fmt.n(Fmt.poidsAffiche(b.poidsKg!, unite)), unit: unite.label)),
                  Expanded(child: MiniChiffre(label: 'Écart', value: signe(Fmt.poidsAffiche(dPoids, unite)), unit: unite.label, color: c.weight)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _curseur(ProgressPhoto a, ProgressPhoto b) {
    final c = context.colors;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: AppTokens.radius16,
        child: LayoutBuilder(builder: (context, box) {
          void bouger(double x) => setState(() => _pos = (x / box.maxWidth).clamp(0.0, 1.0));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => bouger(d.localPosition.dx),
            onTapDown: (d) => bouger(d.localPosition.dx),
            onHorizontalDragEnd: (_) => HapticFeedback.selectionClick(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoFichier(photo: b),
                ClipRect(clipper: _Gauche(_pos), child: PhotoFichier(photo: a)),
                Positioned(
                  left: box.maxWidth * _pos - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: Colors.white),
                ),
                Positioned(
                  left: box.maxWidth * _pos - 22,
                  top: box.maxHeight / 2 - 22,
                  child: Semantics(
                    slider: true,
                    value: '${(_pos * 100).round()} %',
                    label: 'Curseur avant après',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: c.accent, width: 2)),
                      child: const Icon(Icons.code_rounded, color: Colors.black, size: 22),
                    ),
                  ),
                ),
                Positioned(left: 10, top: 10, child: _Pastille('Avant')),
                Positioned(right: 10, top: 10, child: _Pastille('Après')),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _cote(ProgressPhoto a, ProgressPhoto b) {
    Widget une(ProgressPhoto p, String t) => Expanded(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: AppTokens.radius14,
              child: Stack(fit: StackFit.expand, children: [PhotoFichier(photo: p), Positioned(left: 8, top: 8, child: _Pastille(t))]),
            ),
          ),
        );
    return Row(children: [une(a, 'Avant'), const SizedBox(width: 8), une(b, 'Après')]);
  }
}

class _Gauche extends CustomClipper<Rect> {
  _Gauche(this.f);
  final double f;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);

  @override
  bool shouldReclip(_Gauche old) => old.f != f;
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const BoxDecoration(color: Colors.black54, borderRadius: AppTokens.radiusPill),
        child: Text(texte, style: AppType.rowTitle(color: Colors.white).copyWith(fontSize: 12)),
      );
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.titre, required this.photo, required this.onTap});
  final String titre;
  final ProgressPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre.toUpperCase(), style: AppType.overline(color: c.text3)),
                const SizedBox(height: 4),
                Text(Fmt.date(photo.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.rowTitle().copyWith(fontSize: 14)),
                Text(photo.vue.label, style: AppType.rowSubtitle()),
              ],
            ),
          ),
          Icon(Icons.swap_vert_rounded, color: c.accent, size: 20),
        ],
      ),
    );
  }
}
