import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/mensurations.dart';
import '../widgets/maquette.dart';
import 'import_photos.dart';

/// Calendrier de la date d'une photo : jamais dans le futur.
Future<DateTime?> choisirDatePhoto(BuildContext context, DateTime? actuelle) {
  final now = DateTime.now();
  final depart = actuelle == null || actuelle.isAfter(now) ? now : actuelle;
  return showDatePicker(
    context: context,
    initialDate: depart.isBefore(ImportPhotos.premierJour) ? ImportPhotos.premierJour : depart,
    firstDate: ImportPhotos.premierJour,
    lastDate: now,
    helpText: 'Date de la photo',
    cancelText: 'Annuler',
    confirmText: 'Valider',
  );
}

/// Confirmation d'un ajout depuis la galerie : pour chaque photo, sa date
/// (lue dans la photo ou à choisir) et son angle. Rend les photos ajoutées.
class AjoutPhotosPage extends StatefulWidget {
  const AjoutPhotosPage({super.key, required this.import});
  final ImportPhotos import;

  @override
  State<AjoutPhotosPage> createState() => _AjoutPhotosPageState();
}

class _AjoutPhotosPageState extends State<AjoutPhotosPage> {
  bool _enCours = false;

  /// Dernière photo dont l'angle a été touché : c'est elle qui propose
  /// « Appliquer à toutes ».
  PhotoAAjouter? _touchee;

  ImportPhotos get _i => widget.import;

  Future<void> _date(PhotoAAjouter p) async {
    final jour = await choisirDatePhoto(context, p.date);
    if (jour == null || !mounted) return;
    if (!_i.fixerDate(p, jour)) {
      Toasts.error(context, 'Cette date est dans le futur.');
      return;
    }
    setState(() {});
  }

  void _vue(PhotoAAjouter p, PhotoVue v) => setState(() {
        _i.fixerVue(p, v);
        _touchee = p;
      });

  void _retirer(PhotoAAjouter p) {
    setState(() => _i.retirer(p));
    if (_i.photos.isEmpty) Navigator.of(context).maybePop();
  }

  Future<void> _ajouter() async {
    if (_enCours || !_i.pret) return;
    setState(() => _enCours = true);
    final sante = context.read<HealthRepo>();
    final faites = <ProgressPhoto>[];
    try {
      faites.addAll(await _i.enregistrer(sante));
    } catch (_) {
      // Les photos déjà copiées sont gardées ; les autres restent à l'écran.
    }
    if (!mounted) return;
    if (_i.photos.isEmpty) {
      Navigator.of(context).pop(faites);
      return;
    }
    setState(() => _enCours = false);
    Toasts.error(context, 'Ajout impossible pour ${Fmt.pluriel(_i.photos.length, 'photo')}.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = _i.photos.length;
    final manque = _i.sansDate;
    return PageMaquette(
      titre: 'Ajouter ${Fmt.pluriel(n, 'photo')}',
      sousTitre: manque == 0 ? 'Vérifie la date et l\'angle' : '${Fmt.pluriel(manque, 'photo')} sans date',
      bas: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (manque > 0)
            Padding(
              padding: EdgeInsets.only(bottom: e(8)),
              child: Text(
                manque == 1 ? 'Choisis la date de la photo sans date pour continuer.' : 'Choisis la date des $manque photos sans date pour continuer.',
                textAlign: TextAlign.center,
                style: txt(11.5, FontWeight.w400, c.text2),
              ),
            ),
          BoutonPrincipal(label: 'Ajouter', onPressed: _i.pret && !_enCours ? _ajouter : null),
        ],
      ),
      enfants: [
        for (final p in _i.photos)
          Bloc(
            haut: 5,
            bas: 5,
            child: _LignePhoto(
              key: ObjectKey(p),
              photo: p,
              onDate: () => _date(p),
              onVue: (v) => _vue(p, v),
              onRetirer: n > 1 && !_enCours ? () => _retirer(p) : null,
              onAppliquer: n > 1 && identical(p, _touchee) && _i.anglesDifferents
                  ? () => setState(() {
                        _i.appliquerATous(p.vue);
                        _touchee = null;
                      })
                  : null,
            ),
          ),
        SizedBox(height: e(10)),
      ],
    );
  }
}

/// Une photo à ajouter : vignette, date, angle.
class _LignePhoto extends StatelessWidget {
  const _LignePhoto({super.key, required this.photo, required this.onDate, required this.onVue, this.onRetirer, this.onAppliquer});

  final PhotoAAjouter photo;
  final VoidCallback onDate;
  final ValueChanged<PhotoVue> onVue;
  final VoidCallback? onRetirer;
  final VoidCallback? onAppliquer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = photo.date;
    final largeur = e(66);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(e(16)),
        // La photo sans date se voit : cadre ambre.
        border: Border.all(color: d == null ? c.warning.withValues(alpha: 0.6) : c.surface, width: 1),
      ),
      padding: EdgeInsets.all(e(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: largeur,
            height: largeur * 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(e(10)),
                  child: ColoredBox(
                    color: c.surface2,
                    child: Image.file(
                      File(photo.chemin),
                      fit: BoxFit.cover,
                      // Décodée à la taille de la vignette, pas en 12 Mpx.
                      cacheWidth: (largeur * MediaQuery.devicePixelRatioOf(context) * 4 / 3).ceil(),
                      excludeFromSemantics: true,
                      errorBuilder: (context, _, _) => Center(child: IconeTrait(Trace.silhouette, taille: e(24), couleur: c.text3, epaisseur: 1.5)),
                    ),
                  ),
                ),
                if (onRetirer != null)
                  // Croix dans le coin de la vignette ; la zone d'appui
                  // déborde largement la pastille.
                  Align(
                    alignment: Alignment.topLeft,
                    child: Semantics(
                      button: true,
                      label: 'Retirer cette photo',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRetirer,
                        child: SizedBox.square(
                          dimension: e(36),
                          child: Center(
                            child: Container(
                              width: e(20),
                              height: e(20),
                              decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.6), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Transform.rotate(angle: math.pi / 4, child: IconeTrait(Trace.plus, taille: e(11), couleur: c.text, epaisseur: 2)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: e(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d == null) ...[
                  Padding(
                    padding: EdgeInsets.only(top: e(2), bottom: e(6)),
                    child: Text('Date inconnue', style: txt(13.5, FontWeight.w700, c.warning, interligne: 1.25)),
                  ),
                  _BoutonDate(onTap: onDate),
                ] else
                  Semantics(
                    button: true,
                    label: 'Prise le ${Mensurations.jourComplet(d)}, ${photo.origine.mention}. Toucher pour changer la date',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onDate,
                      borderRadius: BorderRadius.circular(e(8)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: e(40)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Une date longue passe sur deux lignes
                                  // plutôt que d'être coupée.
                                  Text('Prise le ${Mensurations.jourComplet(d)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(13, FontWeight.w700, c.text, interligne: 1.25)),
                                  Text(photo.origine.mention, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(11, FontWeight.w400, c.text2)),
                                ],
                              ),
                            ),
                            SizedBox(width: e(6)),
                            Padding(
                              padding: EdgeInsets.only(top: e(2)),
                              child: IconeTrait(Trace.crayon, taille: e(13), couleur: c.text2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: e(4)),
                Wrap(
                  spacing: e(6),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final v in PhotoVue.values) Puce(label: v.label, choisie: v == photo.vue, onTap: () => onVue(v)),
                  ],
                ),
                if (onAppliquer != null)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAppliquer,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: e(7)),
                        child: Text('Appliquer à toutes', style: txt(12, FontWeight.w700, c.text)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Choisir la date » : pilule grise, pour la photo sans date.
class _BoutonDate extends StatelessWidget {
  const _BoutonDate({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Choisir la date',
      excludeSemantics: true,
      child: Material(
        color: c.surface2,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: e(34),
            padding: EdgeInsets.symmetric(horizontal: e(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconeTrait(Trace.calendrier, taille: e(15), couleur: c.text),
                SizedBox(width: e(6)),
                Flexible(child: Text('Choisir la date', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(12, FontWeight.w700, c.text, interligne: 1.2))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
