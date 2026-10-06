import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';
import 'photos_page.dart';

/// Comparer deux photos : avant et après côte à côte, le poids à chaque
/// date et l'écart entre les deux.
class ComparerPhotosPage extends StatefulWidget {
  const ComparerPhotosPage({super.key, this.vue, this.avantId, this.apresId});

  final PhotoVue? vue;
  final String? avantId;
  final String? apresId;

  @override
  State<ComparerPhotosPage> createState() => _ComparerPhotosPageState();
}

class _ComparerPhotosPageState extends State<ComparerPhotosPage> {
  final _cle = GlobalKey();
  late final PhotoVue _vue = widget.vue ?? PhotoVue.face;
  late String? _avant = widget.avantId;
  late String? _apres = widget.apresId;
  bool _partage = false;

  /// Les deux photos retenues, dans l'ordre des dates : par défaut la plus
  /// ancienne et la plus récente de l'angle.
  (ProgressPhoto?, ProgressPhoto?) _paire(List<ProgressPhoto> photos) {
    ProgressPhoto? par(String? id) => photos.where((p) => p.id == id).firstOrNull;
    var a = par(_avant) ?? photos.lastOrNull;
    var b = par(_apres);
    // Jamais une photo comparée à elle-même.
    if (b == null || b.id == a?.id) b = photos.where((p) => p.id != a?.id).firstOrNull;
    if (a != null && b != null && a.date.isAfter(b.date)) (a, b) = (b, a);
    return (a, b);
  }

  Future<void> _changer(List<ProgressPhoto> photos, ProgressPhoto? a, ProgressPhoto? b) async {
    final r = await showPanneauBas<(String, String)>(
      context,
      titre: 'Choisir les deux photos',
      builder: (context) => _ChoixPhotos(photos: photos, avant: a?.id, apres: b?.id),
    );
    if (r == null || !mounted) return;
    setState(() {
      _avant = r.$1;
      _apres = r.$2;
    });
  }

  Future<void> _partager(String texte) async {
    if (_partage) return;
    setState(() => _partage = true);
    try {
      final ro = _cle.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return;
      final image = await ro.toImage(pixelRatio: 3);
      final octets = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (octets == null) return;
      final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}avant-apres.png');
      await f.writeAsBytes(octets.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png', name: 'avant-apres.png')], text: texte));
    } catch (_) {
      if (mounted) Toasts.error(context, 'Partage impossible pour l\'instant.');
    } finally {
      if (mounted) setState(() => _partage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sante = context.watch<HealthRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final photos = Mensurations.photosDe(sante.photos, _vue);
    final (a, b) = _paire(photos);

    if (a == null || b == null) {
      return PageMaquette(
        titre: 'Avant / après',
        sousTitre: 'Vue de ${_vue.label.toLowerCase()}',
        enfants: const [
          Vide(titre: 'Il faut deux photos du même angle', message: 'Ajoute une deuxième photo pour voir le chemin parcouru.'),
        ],
      );
    }

    final bilan = Mensurations.comparer(a, b, sante.measurements);
    final kg = bilan.ecartKg;
    // Null quand les deux photos sont du même jour : jamais « 0 jour ».
    final duree = Mensurations.duree(a.date, b.date);
    final String titreEcart;
    if (kg != null) {
      final ecart = '${kg > 0 ? '+' : '−'}${Fmt.n(Fmt.poidsAffiche(kg.abs(), unite))} ${unite.label}';
      titreEcart = duree == null ? '$ecart le même jour' : '$ecart en $duree';
    } else if (bilan.poidsAvant == null || bilan.poidsApres == null) {
      titreEcart = duree == null ? 'Deux photos du même jour' : '$duree d\'écart';
    } else {
      titreEcart = duree == null ? 'Même poids, le même jour' : 'Même poids, $duree plus tard';
    }
    final zone = bilan.zone;
    final texteZone = zone == null ? null : '${zone.label} ${Mensurations.ecartTexte(Affichage.ecartLongueur(bilan.ecartZone), unite: Affichage.longueur)}';

    Widget cote(ProgressPhoto p, double? poids, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VignettePhoto(photo: p, ratio: 9 / 16),
              SizedBox(height: e(8)),
              Text(poids == null ? 'Poids inconnu' : Fmt.poids(poids, unite), style: txt(15, FontWeight.w700, poids == null ? c.text2 : c.text)),
              Text(label, style: txt(11, FontWeight.w400, c.text2)),
            ],
          ),
        );

    return PageMaquette(
      titre: 'Avant / après',
      sousTitre: 'Vue de ${_vue.label.toLowerCase()}',
      bas: Row(
        children: [
          Expanded(child: BoutonDuo(label: 'Changer les dates', secondaire: true, onPressed: () => _changer(photos, a, b))),
          SizedBox(width: e(8)),
          Expanded(child: BoutonDuo(label: 'Partager', onPressed: _partage ? null : () => _partager(titreEcart))),
        ],
      ),
      enfants: [
        RepaintBoundary(
          key: _cle,
          child: ColoredBox(
            color: c.bg,
            child: Column(
              children: [
                Bloc(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cote(a, bilan.poidsAvant, 'Avant'),
                      SizedBox(width: e(8)),
                      cote(b, bilan.poidsApres, 'Après'),
                    ],
                  ),
                ),
                Bloc(
                  child: Carte(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Surtitre('Écart'),
                              SizedBox(height: e(3)),
                              Text(titreEcart, style: txt(15, FontWeight.w700, c.text)),
                            ],
                          ),
                        ),
                        if (texteZone != null) ...[
                          SizedBox(width: e(8)),
                          Pastille(texteZone, ton: (bilan.ecartZone ?? 0) > 0 ? TonPastille.ok : TonPastille.neutre),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Grille de choix : on touche la photo d'avant puis celle d'après.
class _ChoixPhotos extends StatefulWidget {
  const _ChoixPhotos({required this.photos, this.avant, this.apres});
  final List<ProgressPhoto> photos;
  final String? avant;
  final String? apres;

  @override
  State<_ChoixPhotos> createState() => _ChoixPhotosState();
}

class _ChoixPhotosState extends State<_ChoixPhotos> {
  late final List<String> _choix = [?widget.avant, ?widget.apres];

  void _toucher(String id) => setState(() {
        if (_choix.contains(id)) {
          _choix.remove(id);
        } else {
          if (_choix.length == 2) _choix.removeAt(0);
          _choix.add(id);
        }
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Touche deux photos : la plus ancienne sera « avant ».', textAlign: TextAlign.center, style: txt(12, FontWeight.w400, c.text2)),
        SizedBox(height: e(12)),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: e(6),
          crossAxisSpacing: e(6),
          childAspectRatio: 3 / 4,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final p in widget.photos) VignettePhoto(photo: p, choisie: _choix.contains(p.id), onTap: () => _toucher(p.id)),
          ],
        ),
        SizedBox(height: e(14)),
        BoutonPrincipal(
          label: 'Comparer',
          onPressed: _choix.length < 2
              ? null
              : () {
                  final a = widget.photos.firstWhere((p) => p.id == _choix[0]);
                  final b = widget.photos.firstWhere((p) => p.id == _choix[1]);
                  Navigator.pop(context, a.date.isAfter(b.date) ? (b.id, a.id) : (a.id, b.id));
                },
        ),
      ],
    );
  }
}
