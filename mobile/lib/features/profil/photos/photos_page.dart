import 'dart:io';

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
import '../data/mensurations.dart';
import '../routes.dart';
import '../widgets/maquette.dart';
import 'ajout_page.dart';
import 'import_photos.dart';

/// Vignette d'une photo de progression : l'image (ou une silhouette grise
/// si le fichier manque) et sa date en étiquette.
class VignettePhoto extends StatelessWidget {
  const VignettePhoto({super.key, required this.photo, this.ratio = 3 / 4, this.onTap, this.choisie = false});

  final ProgressPhoto? photo;
  final double ratio;
  final VoidCallback? onTap;

  /// Cadre blanc (photo retenue dans un choix).
  final bool choisie;

  /// Largeur, en pixels, à laquelle décoder la photo d'une vignette de
  /// [taille] : assez pour couvrir le cadre même avec une photo en paysage
  /// (4:3) recadrée, jamais plus de 2048.
  static int largeurDecodage(Size taille, double densite) {
    final cote = (taille.longestSide.isFinite ? taille.longestSide : 400.0) * densite * 4 / 3;
    return cote.ceil().clamp(64, 2048);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = photo;
    final fichier = p == null ? null : File(p.chemin);
    final existe = fichier != null && fichier.existsSync();
    return AspectRatio(
      aspectRatio: ratio,
      child: Semantics(
        button: onTap != null,
        image: true,
        label: p == null ? 'Pas de photo' : 'Photo du ${Mensurations.jourLong(p.date)}, ${p.vue.label.toLowerCase()}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(e(12)),
              border: choisie ? Border.all(color: c.text, width: e(1.5)) : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (existe)
                  // Décodée à la taille de la vignette, pas en pleine
                  // résolution : une grille de photos de 12 Mpx tient en
                  // mémoire.
                  LayoutBuilder(
                    builder: (context, cadre) => Image.file(
                      fichier,
                      fit: BoxFit.cover,
                      cacheWidth: largeurDecodage(cadre.biggest, MediaQuery.devicePixelRatioOf(context)),
                      errorBuilder: (context, _, _) => const _Silhouette(),
                    ),
                  )
                else
                  const _Silhouette(),
                if (p != null)
                  Positioned(
                    left: e(6),
                    bottom: e(6),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: e(6), vertical: e(2)),
                      decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(e(6))),
                      child: Text(Mensurations.etiquette(p.date), style: txt(9.5, FontWeight.w600, c.text)),
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

class _Silhouette extends StatelessWidget {
  const _Silhouette();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Center(
          child: IconeTrait(Trace.silhouette, taille: box.maxWidth * 0.34, couleur: context.colors.text3, epaisseur: 1.5),
        ),
      );
}

enum _Source { appareil, galerie }

/// Ouvre l'écran de confirmation des photos choisies dans la galerie.
/// Rend les photos ajoutées.
Future<List<ProgressPhoto>> _confirmer(BuildContext context, List<FichierPhoto> fichiers, PhotoVue vue) async {
  final import = await ImportPhotos.lire(fichiers, vue: vue);
  if (!context.mounted) return const [];
  final r = await Navigator.of(context, rootNavigator: true).push<List<ProgressPhoto>>(
    MaterialPageRoute(builder: (_) => AjoutPhotosPage(import: import)),
  );
  return r ?? const [];
}

/// Propose de prendre une photo ou d'en choisir plusieurs dans la galerie.
/// Une photo prise sur le moment est enregistrée tout de suite pour
/// l'angle [vue] ; celles de la galerie passent par l'écran de
/// confirmation (date de prise de vue, angle). Rend les photos ajoutées.
Future<List<ProgressPhoto>> ajouterPhotos(BuildContext context, PhotoVue vue) async {
  final source = await showPanneauBas<_Source>(
    context,
    titre: 'Ajouter une photo',
    builder: (context) => Column(
      children: [
        LigneAction(
          icone: const IconeTrait(Trace.photo, taille: 24),
          label: 'Prendre une photo',
          onTap: () => Navigator.pop(context, _Source.appareil),
        ),
        LigneAction(
          icone: const IconeTrait(Trace.galerie, taille: 24),
          label: 'Choisir dans la galerie',
          onTap: () => Navigator.pop(context, _Source.galerie),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return const [];
  final sante = context.read<HealthRepo>();
  final galerie = source == _Source.galerie;
  try {
    final List<ProgressPhoto> faites;
    if (galerie) {
      final fichiers = await SelecteurPhotos.galerie();
      if (fichiers.isEmpty || !context.mounted) return const [];
      faites = await _confirmer(context, fichiers, vue);
    } else {
      final f = await SelecteurPhotos.appareil();
      if (f == null) return const [];
      faites = [await sante.addPhoto(f.chemin, vue: vue, poidsKg: Mensurations.poidsA(sante.measurements, DateTime.now()))];
    }
    if (faites.isNotEmpty && context.mounted) {
      Toasts.success(context, faites.length == 1 ? 'Photo ajoutée' : '${faites.length} photos ajoutées');
    }
    return faites;
  } on PlatformException catch (err) {
    if (context.mounted) {
      Toasts.error(
        context,
        galerie
            ? 'Impossible d\'ouvrir la galerie.'
            : err.code.contains('denied')
                ? 'Accès refusé : autorise l\'appareil photo dans les réglages du téléphone.'
                : 'Photo impossible pour l\'instant.',
      );
    }
    return const [];
  } catch (_) {
    if (context.mounted) Toasts.error(context, galerie ? 'Impossible d\'ouvrir la galerie.' : 'Photo impossible pour l\'instant.');
    return const [];
  }
}

/// Photos de progression : par angle, en grille datée, avec l'accès à la
/// comparaison.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  PhotoVue _vue = PhotoVue.face;

  @override
  void initState() {
    super.initState();
    _retrouver();
  }

  /// Android peut fermer l'appli pendant la prise de vue ou le choix dans
  /// la galerie : on récupère alors les photos au retour.
  Future<void> _retrouver() async {
    if (!Platform.isAndroid) return;
    try {
      final r = await ImagePicker().retrieveLostData();
      final perdus = r.files ?? [?r.file];
      if (r.isEmpty || perdus.isEmpty || !mounted) return;
      final fichiers = [for (final x in perdus) (chemin: x.path, nom: x.name)];
      final sante = context.read<HealthRepo>();
      if (fichiers.length == 1) {
        // Une seule photo sans date lisible : elle vient d'être prise.
        final lue = await ImportPhotos.lire(fichiers, vue: _vue);
        if (!lue.pret) {
          await sante.addPhoto(fichiers.single.chemin, vue: _vue, poidsKg: Mensurations.poidsA(sante.measurements, DateTime.now()));
          return;
        }
      }
      if (!mounted) return;
      _montrer(await _confirmer(context, fichiers, _vue));
    } catch (_) {
      // Rien à récupérer.
    }
  }

  Future<void> _ajouter() async => _montrer(await ajouterPhotos(context, _vue));

  /// Passe sur l'angle des photos ajoutées si aucune n'est dans l'onglet
  /// affiché.
  void _montrer(List<ProgressPhoto> faites) {
    if (!mounted || faites.isEmpty || faites.any((p) => p.vue == _vue)) return;
    setState(() => _vue = faites.first.vue);
  }

  @override
  Widget build(BuildContext context) {
    final toutes = context.watch<HealthRepo>().photos;
    final photos = Mensurations.photosDe(toutes, _vue);
    final n = toutes.length;

    return PageMaquette(
      titre: 'Photos',
      sousTitre: n == 0
          ? 'Aucune photo pour l\'instant'
          : '$n ${n >= 2 ? 'photos' : 'photo'} depuis ${Mensurations.moisDe(toutes.last.date)}',
      action: BoutonRond(trace: Trace.plus, label: 'Ajouter une photo', onTap: _ajouter),
      bas: BoutonPrincipal(
        label: 'Comparer deux photos',
        onPressed: photos.length < 2 ? null : () => context.push(ProfilPaths.comparer(vue: _vue)),
      ),
      enfants: [
        Bloc(
          child: SelecteurSegmente<PhotoVue>(
            segments: [for (final v in PhotoVue.values) (v, v.label)],
            value: _vue,
            onChanged: (v) => setState(() => _vue = v),
          ),
        ),
        if (photos.isEmpty)
          Vide(
            titre: 'Pas encore de photo de ${_vue.label.toLowerCase()}',
            message: 'Touche « + » pour en ajouter une. Même lumière et même pose à chaque fois : la comparaison n\'en sera que plus parlante.',
          )
        else
          Bloc(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: e(6),
              crossAxisSpacing: e(6),
              childAspectRatio: 3 / 4,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final p in photos) VignettePhoto(photo: p, onTap: () => context.push(ProfilPaths.photo(p.id))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Une photo en grand : zoom, poids, date et angle modifiables, comparer,
/// supprimer.
class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sante = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final p = sante.photos.where((x) => x.id == id).firstOrNull;
    if (p == null) {
      return const PageMaquette(
        titre: 'Photo introuvable',
        enfants: [Vide(titre: 'Cette photo n\'existe plus', message: 'Elle a peut-être été supprimée.')],
      );
    }
    final fichier = File(p.chemin);
    final poids = Mensurations.poidsPhoto(p, sante.measurements);
    final autres = Mensurations.photosDe(sante.photos, p.vue).where((x) => x.id != p.id).toList();
    return PageMaquette(
      titre: Mensurations.jourLong(p.date),
      sousTitre: [p.vue.label, if (poids != null) Fmt.poids(poids, unite)].join(' · '),
      action: BoutonRond(
        trace: Trace.poubelle,
        label: 'Supprimer la photo',
        tailleIcone: e(18),
        onTap: () async {
          final ok = await showPanneauBas<bool>(
            context,
            titre: 'Supprimer cette photo ?',
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BoutonDestructif(label: 'Supprimer', fond: AppTokens.surface3, onPressed: () => Navigator.pop(context, true)),
                SizedBox(height: e(8)),
                BoutonSecondaire(label: 'Annuler', fond: AppTokens.surface3, onPressed: () => Navigator.pop(context, false)),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await context.read<HealthRepo>().deletePhoto(p.id);
          if (context.mounted) Navigator.of(context).maybePop();
        },
      ),
      bas: autres.isEmpty
          ? null
          : BoutonPrincipal(
              label: 'Comparer avec une autre',
              onPressed: () {
                final anciennes = autres.where((x) => x.date.isBefore(p.date));
                final autre = anciennes.isNotEmpty ? anciennes.last : autres.first;
                final (a, b) = autre.date.isBefore(p.date) ? (autre, p) : (p, autre);
                context.push(ProfilPaths.comparer(vue: p.vue, avant: a.id, apres: b.id));
              },
            ),
      enfants: [
        Bloc(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(e(16)),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: fichier.existsSync()
                  ? ColoredBox(
                      color: c.surface2,
                      child: InteractiveViewer(
                        maxScale: 4,
                        // Une photo de la galerie garde sa taille d'origine :
                        // décodée au double de l'écran, assez pour zoomer.
                        child: Image.file(
                          fichier,
                          fit: BoxFit.contain,
                          cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) * 2).ceil().clamp(64, 2400),
                          errorBuilder: (context, _, _) => const _Silhouette(),
                        ),
                      ),
                    )
                  : VignettePhoto(photo: null, ratio: 3 / 4),
            ),
          ),
        ),
        Bloc(
          child: Groupe(
            lignes: [
              Ligne(
                trace: Trace.calendrier,
                titre: 'Date',
                valeur: Mensurations.jourComplet(p.date),
                onTap: () async {
                  final jour = await choisirDatePhoto(context, p.date);
                  if (jour == null || !context.mounted) return;
                  final ok = await changerDatePhoto(context.read<HealthRepo>(), p, jour);
                  if (!ok && context.mounted) Toasts.error(context, 'Cette date est dans le futur.');
                },
              ),
              Ligne(
                trace: Trace.silhouette,
                titre: 'Angle',
                valeur: p.vue.label,
                onTap: () async {
                  final v = await showPanneauBas<PhotoVue>(
                    context,
                    titre: 'Angle de la photo',
                    builder: (context) => Column(
                      children: [
                        for (final v in PhotoVue.values)
                          ChoixPanneau(label: v.label, selected: v == p.vue, onTap: () => Navigator.pop(context, v)),
                      ],
                    ),
                  );
                  if (v == null || !context.mounted) return;
                  await changerVuePhoto(context.read<HealthRepo>(), p, v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
