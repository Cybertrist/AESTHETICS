import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../common/sante_widgets.dart';

/// Vignette d'une photo stockée en local, avec repli si le fichier manque.
class PhotoFichier extends StatelessWidget {
  const PhotoFichier({super.key, required this.photo, this.fit = BoxFit.cover, this.cacheWidth});
  final ProgressPhoto photo;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Image.file(
      File(photo.chemin),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        color: c.surface3,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: c.text3),
            const SizedBox(height: 4),
            Text('Fichier introuvable', style: AppType.rowSubtitle()),
          ],
        ),
      ),
    );
  }
}

/// Ajoute une photo : appareil ou galerie, puis la vue.
Future<ProgressPhoto?> ajouterPhoto(BuildContext context) async {
  final source = await showActionMenu<ImageSource>(
    context,
    title: 'Nouvelle photo',
    items: const [
      ActionMenuItem(value: ImageSource.camera, label: 'Prendre une photo', icon: Icons.photo_camera_rounded),
      ActionMenuItem(value: ImageSource.gallery, label: 'Choisir dans la galerie', icon: Icons.photo_library_rounded),
    ],
  );
  if (source == null || !context.mounted) return null;
  XFile? f;
  try {
    f = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 88, preferredCameraDevice: CameraDevice.rear);
  } on PlatformException catch (e) {
    if (context.mounted) {
      Toasts.error(
        context,
        e.code.contains('denied') ? 'Accès refusé. Autorisez l\'appareil photo ou les photos dans les réglages d\'Android.' : 'Impossible d\'ouvrir ${source == ImageSource.camera ? 'l\'appareil photo' : 'la galerie'}.',
      );
    }
    return null;
  }
  if (f == null || !context.mounted) return null;
  final vue = await showChoiceDialog<PhotoVue>(
    context,
    title: 'Quelle vue ?',
    message: 'Pour comparer, gardez la même pose d\'une photo à l\'autre.',
    options: [for (final v in PhotoVue.values) (v, v.label)],
    selected: PhotoVue.face,
  );
  if (vue == null || !context.mounted) return null;
  final repo = context.read<HealthRepo>();
  try {
    final p = await repo.addPhoto(f.path, vue: vue, poidsKg: repo.latestWeight);
    if (context.mounted) Toasts.success(context, 'Photo ajoutée');
    return p;
  } catch (_) {
    if (context.mounted) Toasts.error(context, 'La photo n\'a pas pu être enregistrée.');
    return null;
  }
}

/// Galerie des photos d'évolution, filtrable par vue.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  PhotoVue? _vue;
  bool _ajout = false;

  @override
  void initState() {
    super.initState();
    _recuperer();
  }

  /// Android peut fermer l'appli pendant la prise de vue : on récupère la photo.
  Future<void> _recuperer() async {
    if (!Platform.isAndroid) return;
    try {
      final r = await ImagePicker().retrieveLostData();
      if (r.isEmpty || r.file == null || !mounted) return;
      final repo = context.read<HealthRepo>();
      await repo.addPhoto(r.file!.path, poidsKg: repo.latestWeight);
      if (mounted) Toasts.success(context, 'Photo récupérée');
    } catch (_) {}
  }

  Future<void> _ajouter() async {
    setState(() => _ajout = true);
    await ajouterPhoto(context);
    if (mounted) setState(() => _ajout = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final toutes = context.watch<HealthRepo>().photos;
    final photos = _vue == null ? toutes : toutes.where((p) => p.vue == _vue).toList();
    final colonnes = MediaQuery.sizeOf(context).width >= 700 ? 5 : 3;
    return SubPageScaffold(
      title: 'Photos d\'évolution',
      subtitle: Fmt.pluriel(toutes.length, 'photo'),
      haloColor: c.weight,
      actions: [
        if (toutes.length >= 2)
          RoundIconButton(icon: Icons.compare_rounded, filled: false, tooltip: 'Comparer', onPressed: () => context.push('/sante/corps/comparer${_vue == null ? '' : '?vue=${_vue!.name}'}')),
        const SizedBox(width: 6),
        RoundIconButton(icon: Icons.add_a_photo_rounded, tooltip: 'Ajouter', onPressed: _ajout ? null : _ajouter),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 4, AppTokens.gutter, 10),
            child: SegmentedChips<PhotoVue?>(
              segments: [(null, 'Toutes'), for (final v in PhotoVue.values) (v, v.label)],
              value: _vue,
              onChanged: (v) => setState(() => _vue = v),
            ),
          ),
          Expanded(
            child: _ajout && toutes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : photos.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.photo_camera_rounded,
                          iconColor: c.weight,
                          title: toutes.isEmpty ? 'Aucune photo' : 'Aucune photo de ${_vue!.label.toLowerCase()}',
                          message: 'Même endroit, même lumière, même pose. Les photos restent sur ce téléphone.',
                          actionLabel: 'Ajouter une photo',
                          onAction: _ajouter,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 32),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: colonnes, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3 / 4),
                        itemCount: photos.length,
                        itemBuilder: (context, i) {
                          final p = photos[i];
                          return GestureDetector(
                            onTap: () => context.push('/sante/corps/photos/${p.id}'),
                            child: ClipRRect(
                              borderRadius: AppTokens.radius12,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PhotoFichier(photo: p, cacheWidth: 360),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(Fmt.jourMois(p.date), style: AppType.rowTitle(color: Colors.white).copyWith(fontSize: 12.5)),
                                          Text(p.vue.label, style: AppType.rowSubtitle(color: Colors.white70).copyWith(fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Une photo en grand, ses informations et ses actions.
class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final p = repo.photos.firstWhereOrNull((x) => x.id == id);
    if (p == null) {
      return SubPageScaffold(
        title: 'Photo',
        body: Center(
          child: EmptyState(
            icon: Icons.image_not_supported_rounded,
            title: 'Photo introuvable',
            message: 'Elle a peut-être été supprimée.',
            actionLabel: 'Toutes les photos',
            onAction: () => context.go('/sante/corps/photos'),
          ),
        ),
      );
    }

    Future<void> modifier(ProgressPhoto n) => repo.savePhoto(n);
    ProgressPhoto avec({DateTime? date, PhotoVue? vue, String? note, double? poids, bool effacerPoids = false}) => ProgressPhoto(
          id: p.id,
          date: date ?? p.date,
          chemin: p.chemin,
          vue: vue ?? p.vue,
          poidsKg: effacerPoids ? null : (poids ?? p.poidsKg),
          note: note ?? p.note,
        );

    final autres = repo.photos.where((x) => x.id != p.id && x.vue == p.vue).toList();

    return SubPageScaffold(
      title: Fmt.jourCap(p.date),
      subtitle: p.vue.label,
      haloColor: c.weight,
      actions: [
        RoundIconButton(
          icon: Icons.delete_outline_rounded,
          filled: false,
          tooltip: 'Supprimer',
          onPressed: () async {
            final ok = await showConfirmDialog(
              context,
              title: 'Supprimer cette photo ?',
              message: 'Le fichier est effacé de ce téléphone, sans retour possible.',
              confirmLabel: 'Supprimer',
              destructive: true,
              icon: Icons.delete_outline_rounded,
            );
            if (!ok || !context.mounted) return;
            await repo.deletePhoto(p.id);
            if (context.mounted) {
              context.pop();
              Toasts.show(context, 'Photo supprimée');
            }
          },
        ),
      ],
      body: SanteVolets(
        ratio: 0.58,
        gauche: Padding(
          padding: santePad,
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: Colors.black,
              builder: (dctx) => GestureDetector(
                onTap: () => Navigator.of(dctx).pop(),
                child: InteractiveViewer(maxScale: 5, child: Center(child: PhotoFichier(photo: p, fit: BoxFit.contain))),
              ),
            ),
            child: ClipRRect(
              borderRadius: AppTokens.radius16,
              child: AspectRatio(aspectRatio: 3 / 4, child: PhotoFichier(photo: p)),
            ),
          ),
        ),
        droite: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              TileGroup(
                label: 'Informations',
                children: [
                  LigneChoix(
                    icon: Icons.event_rounded,
                    color: c.weight,
                    label: 'Date',
                    value: Fmt.date(p.date),
                    onTap: () async {
                      final d = await choisirDate(context, p.date);
                      if (d != null) await modifier(avec(date: DateTime(d.year, d.month, d.day, p.date.hour, p.date.minute)));
                    },
                  ),
                  LigneChoix(
                    icon: Icons.accessibility_new_rounded,
                    color: c.training,
                    label: 'Vue',
                    value: p.vue.label,
                    onTap: () async {
                      final v = await showChoiceDialog<PhotoVue>(context, title: 'Vue', options: [for (final v in PhotoVue.values) (v, v.label)], selected: p.vue);
                      if (v != null) await modifier(avec(vue: v));
                    },
                  ),
                  LigneChoix(
                    icon: Icons.monitor_weight_rounded,
                    color: c.weight,
                    label: 'Poids ce jour-là',
                    value: p.poidsKg == null ? 'Non renseigné' : Fmt.poids(p.poidsKg, unite),
                    onTap: () async {
                      final v = await showNumberInputDialog(context, title: 'Poids ce jour-là', initial: p.poidsKg == null ? null : Fmt.poidsAffiche(p.poidsKg!, unite), unit: unite.label);
                      if (v != null) await modifier(v <= 0 ? avec(effacerPoids: true) : avec(poids: Fmt.poidsStocke(v, unite)));
                    },
                  ),
                  LigneChoix(
                    icon: Icons.edit_note_rounded,
                    color: c.text2,
                    label: 'Note',
                    value: p.note == null || p.note!.isEmpty ? 'Ajouter' : p.note!,
                    onTap: () async {
                      final t = await showTextInputDialog(context, title: 'Note', initial: p.note ?? '', hint: 'Fin de sèche, après la séance...', maxLines: 3);
                      if (t != null) await modifier(avec(note: t));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: santePad,
                child: PillButton.secondary(
                  label: autres.isEmpty ? 'Aucune autre photo de ${p.vue.label.toLowerCase()} à comparer' : 'Comparer avec une autre',
                  icon: Icons.compare_rounded,
                  expand: true,
                  onPressed: autres.isEmpty ? null : () => context.push('/sante/corps/comparer?apres=${p.id}&vue=${p.vue.name}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
