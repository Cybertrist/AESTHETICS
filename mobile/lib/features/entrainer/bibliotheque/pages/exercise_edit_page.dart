import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/data.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../commun/elements.dart';
import '../../commun/traits.dart';
import '../../routines/widgets/formulaire.dart';
import '../../routines/widgets/sous_page.dart';
import '../widgets/exercise_media.dart';
import '../../commun/corps_colore.dart' show Teinte;
import '../widgets/choix_exercice.dart';
import 'exercise_actions.dart';

/// Création ou modification d'un exercice perso. Rend l'exercice
/// enregistré (ou null si abandon, ou l'exercice supprimé n'existe plus).
class ExerciseEditPage extends StatefulWidget {
  const ExerciseEditPage({super.key, this.existing, this.initialName = ''});

  final Exercise? existing;
  final String initialName;

  static Future<Exercise?> open(BuildContext context, {Exercise? existing, String initialName = ''}) =>
      Navigator.of(context, rootNavigator: true).push<Exercise>(MaterialPageRoute(
        builder: (_) => ExerciseEditPage(existing: existing, initialName: initialName),
      ));

  @override
  State<ExerciseEditPage> createState() => _ExerciseEditPageState();
}

class _ExerciseEditPageState extends State<ExerciseEditPage> {
  late final Exercise? _e = widget.existing;
  late final _nom = TextEditingController(text: _e?.nom ?? widget.initialName);
  late final _video = TextEditingController(text: _e?.media.mp4 != null && _e!.media.mp4!.startsWith('http') ? _e.media.mp4 : '');
  late final _instructions = TextEditingController(text: _e?.instructions.join('\n') ?? '');
  late final _notes = TextEditingController(text: _e?.notes ?? '');
  late List<Muscle> _principaux = [...?_e?.musclesPrincipaux];
  late List<Muscle> _secondaires = [...?_e?.musclesSecondaires];
  late String? _equipement = _e?.equipement;
  late String _categorie = _e != null && Categories.labels.containsKey(_e.categorie) ? _e.categorie : 'pectoraux';
  late ExerciseTracking _suivi = _e?.suivi ?? ExerciseTracking.poidsReps;
  late String? _photo = _e?.media.images.firstOrNull ?? _e?.media.imagesLocales.firstOrNull;
  late String? _videoFichier = _e?.media.mp4 != null && !_e!.media.mp4!.startsWith('http') ? _e.media.mp4 : null;
  bool _dirty = false;
  bool _saving = false;
  bool _tried = false;
  bool _categorieTouchee = false;

  bool get _creation => _e == null;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_nom, _video, _instructions, _notes]) {
      ctrl.addListener(_touch);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [_nom, _video, _instructions, _notes]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _change(VoidCallback f) {
    setState(() {
      f();
      _dirty = true;
    });
  }

  /// Catégorie déduite du premier muscle principal, tant qu'on ne l'a pas choisie.
  static String? _categorieDe(Muscle m) => switch (m) {
        Muscle.pectoraux => 'pectoraux',
        Muscle.deltoidesAnterieurs || Muscle.deltoidesLateraux || Muscle.deltoidesPosterieurs => 'epaules',
        Muscle.biceps => 'biceps',
        Muscle.triceps => 'triceps',
        Muscle.avantBras => 'avantBras',
        Muscle.trapezes || Muscle.grandDorsal || Muscle.rhomboides || Muscle.lombaires => 'dos',
        Muscle.abdominaux || Muscle.obliques => 'abdos',
        Muscle.fessiers => 'fessiers',
        Muscle.ischios => 'ischios',
        Muscle.quadriceps || Muscle.adducteurs || Muscle.abducteurs => 'jambes',
        Muscle.mollets => 'mollets',
        Muscle.cou => 'cou',
      };

  Future<String?> _copier(String source, String prefixe) async {
    final dir = await context.read<Store>().mediaDir();
    final ext = source.contains('.') ? source.substring(source.lastIndexOf('.')) : '.jpg';
    final dest = '${dir.path}${Platform.pathSeparator}${prefixe}_${newId()}$ext';
    await File(source).copy(dest);
    return dest;
  }

  Future<void> _choisirPhoto(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 1080, imageQuality: 85);
      if (f == null) return;
      final path = await _copier(f.path, 'exercice');
      _change(() => _photo = path);
    } catch (_) {
      if (mounted) Toasts.error(context, src == ImageSource.camera ? 'Appareil photo indisponible' : 'Impossible d\'ouvrir la galerie');
    }
  }

  Future<void> _choisirVideo() async {
    try {
      final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      if (f == null) return;
      final path = await _copier(f.path, 'exercice_video');
      _change(() {
        _videoFichier = path;
        _video.text = '';
      });
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d\'ouvrir la galerie');
    }
  }

  String? get _erreurNom => _nom.text.trim().isEmpty ? 'Donne un nom à l\'exercice' : null;
  String? get _erreurMuscles => _principaux.isEmpty ? 'Choisis au moins un muscle principal' : null;
  String? get _erreurVideo {
    final v = _video.text.trim();
    if (v.isEmpty) return null;
    final u = Uri.tryParse(v);
    return u == null || !u.hasScheme || !v.startsWith('http') ? 'Colle une adresse complète (https://...)' : null;
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_erreurNom != null || _erreurMuscles != null || _erreurVideo != null) {
      Toasts.error(context, _erreurNom ?? _erreurMuscles ?? _erreurVideo!);
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<ExerciseRepo>();
    final lien = _video.text.trim();
    final old = _e?.media;
    final e = Exercise(
      id: _e?.id ?? '',
      nom: _nom.text.trim(),
      nomEn: _e?.nomEn,
      alias: _e?.alias ?? const [],
      musclesPrincipaux: _principaux,
      musclesSecondaires: _secondaires,
      equipement: _equipement ?? 'autre',
      categorie: _categorie,
      mecanique: _e?.mecanique ?? (_principaux.length + _secondaires.length > 2 ? 'polyarticulaire' : 'isolation'),
      niveau: _e?.niveau,
      instructions: _instructions.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList(),
      conseils: _e?.conseils ?? const [],
      media: ExerciseMedia(
        gif: old?.gif,
        gifSecours: old?.gifSecours,
        credit: old?.credit,
        // Une variante garde les poses du catalogue (vignette de la grille) ;
        // la photo choisie, elle, n'est jamais une de ces poses.
        imagesLocales: old?.imagesLocales ?? const [],
        images: [if (_photo != null && !(old?.imagesLocales.contains(_photo) ?? false)) _photo!],
        mp4: lien.isNotEmpty ? lien : _videoFichier,
      ),
      source: _e?.source ?? 'perso',
      perso: true,
      suiviExplicite: _suivi,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      creeLe: _e?.creeLe,
    );
    try {
      Exercise saved = e;
      if (_creation) {
        saved = await repo.addCustom(e);
      } else {
        await repo.updateCustom(e);
      }
      if (!mounted) return;
      Toasts.success(context, _creation ? 'Exercice créé' : 'Modifications enregistrées');
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        Toasts.error(context, 'Enregistrement impossible, réessaie');
      }
    }
  }

  Future<void> _back() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final quitter = await showConfirmDialog(
      context,
      title: 'Abandonner les modifications ?',
      message: 'Ce que tu as saisi ne sera pas enregistré.',
      confirmLabel: 'Abandonner',
      cancelLabel: 'Continuer',
      destructive: true,
    );
    if (quitter && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = _e;
    if (e == null) return;
    final ok = await ExerciseActions.supprimer(context, e);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Widget _bloc(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter), child: child);

  /// La photo ou la vidéo : un panneau du bas avec les trois sources.
  Future<void> _ajouterMedia() async {
    final choix = await showPanneauBas<int>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LigneAction(icone: const IconeTrait(Trait.appareil, size: 25), label: 'Prendre une photo', onTap: () => Navigator.pop(context, 0)),
          LigneAction(icone: const IconeTrait(Trait.image, size: 25), label: 'Choisir une photo', onTap: () => Navigator.pop(context, 1)),
          LigneAction(icone: const IconeTrait(Trait.lectureCercle, size: 25), label: 'Choisir une vidéo', onTap: () => Navigator.pop(context, 2)),
        ],
      ),
    );
    if (choix == null || !mounted) return;
    switch (choix) {
      case 0:
        await _choisirPhoto(ImageSource.camera);
      case 1:
        await _choisirPhoto(ImageSource.gallery);
      default:
        await _choisirVideo();
    }
  }

  Future<void> _choisirLesMuscles({required bool principaux}) async {
    final r = await choisirMuscles(
      context,
      titre: principaux ? 'Sélectionner les muscles principaux' : 'Sélectionner les muscles secondaires',
      choisis: principaux ? _principaux : _secondaires,
      teinte: principaux ? Teinte.principal : Teinte.secondaire,
    );
    if (r == null || !mounted) return;
    _change(() {
      // Un muscle n'a qu'un rôle : le dernier choisi l'emporte.
      if (principaux) {
        _principaux = r;
        _secondaires = [for (final m in _secondaires) if (!r.contains(m)) m];
        if (!_categorieTouchee && r.isNotEmpty) _categorie = _categorieDe(r.first) ?? _categorie;
      } else {
        _secondaires = r;
        _principaux = [for (final m in _principaux) if (!r.contains(m)) m];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final existant = _nom.text.trim().isEmpty ? null : context.read<ExerciseRepo>().findByName(_nom.text.trim());
    final doublon = existant != null && existant.id != _e?.id;
    final detail = TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, height: 1.38, color: c.text2);
    String? noms(List<Muscle> l) => l.isEmpty ? null : l.map((m) => m.label).join(', ');

    final media = <Widget>[
      const SizedBox(height: 10),
      Center(
        child: _photo != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 150,
                      height: 150,
                      color: c.surface2,
                      child: mediaImage(_photo!, fit: BoxFit.cover, error: (_) => Center(child: IconeTrait(Trait.image, size: 30, color: c.text3))),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: BoutonRond(
                      icone: const IconeTrait(Trait.fermer, size: 16),
                      label: 'Retirer la photo',
                      taille: 34,
                      fond: c.bg.withValues(alpha: 0.6),
                      onTap: () => _change(() => _photo = null),
                    ),
                  ),
                ],
              )
            : Semantics(
                button: true,
                label: 'Ajouter une photo ou une vidéo',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AccentChoice.bleu.color, width: 1.4)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _ajouterMedia,
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconeTrait(Trait.appareil, size: 28, color: AccentChoice.bleu.color),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ajouter une photo ou une vidéo',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500, color: AccentChoice.bleu.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
      if (_videoFichier != null) ...[
        const SizedBox(height: 14),
        _bloc(
          Row(
            children: [
              const Tuile(taille: 46, child: IconeTrait(Trait.lectureCercle, size: 22)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vidéo du téléphone', style: TexteEntrainer.ligne(context)),
                    Text('Lue en boucle sur la fiche', style: detail),
                  ],
                ),
              ),
              BoutonNu(trait: Trait.fermer, label: 'Retirer la vidéo', taille: 18, largeur: 46, couleur: c.text2, onTap: () => _change(() => _videoFichier = null)),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
    ];

    final identite = <Widget>[
      _bloc(
        ChampBord(
          controller: _nom,
          label: 'Nom de l\'exercice',
          hint: 'Développé incliné à la machine',
          autofocus: _creation && widget.initialName.isEmpty,
          // Le plus long nom du catalogue fait 62 caractères, et une variante y ajoute « (perso) ».
          maxLength: 80,
          erreur: _tried ? _erreurNom : null,
          aide: doublon ? 'Un exercice porte déjà ce nom : ${existant.nom}' : null,
        ),
      ),
      const SizedBox(height: 16),
      _bloc(ChampBord(controller: _instructions, label: 'Instructions (facultatif)', hint: 'Une étape par ligne', minLines: 3, maxLines: 8)),
    ];

    Widget ligne(Widget l) => Padding(padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 0, AppTokens.gutter, 10), child: l);
    final details = <Widget>[
      const TitreSection('Détails'),
      ligne(LigneDetail(
        label: 'Type d\'exercice',
        valeur: _suivi.label,
        vide: 'À choisir',
        onTap: () async {
          final t = await choisirType(context, choisi: _suivi);
          if (t != null && mounted) _change(() => _suivi = t);
        },
      )),
      ligne(LigneDetail(
        label: 'Partie du corps',
        valeur: Categories.label(_categorie),
        vide: 'À choisir',
        onTap: () async {
          final v = await choisirPartie(context, choisie: _categorie);
          if (v != null && mounted) {
            _change(() {
              _categorie = v;
              _categorieTouchee = true;
            });
          }
        },
      )),
      ligne(LigneDetail(
        label: 'Équipement',
        valeur: _equipement == null ? null : Equipements.label(_equipement!),
        vide: 'Facultatif',
        onTap: () async {
          final v = await choisirEquipement(context, choisi: _equipement ?? '');
          if (v != null && mounted) _change(() => _equipement = v);
        },
      )),
      ligne(LigneDetail(
        label: 'Muscles principaux',
        valeur: noms(_principaux),
        vide: 'À choisir',
        erreur: _tried ? _erreurMuscles : null,
        onTap: () => _choisirLesMuscles(principaux: true),
      )),
      ligne(LigneDetail(
        label: 'Muscles secondaires',
        valeur: noms(_secondaires),
        vide: 'Facultatif',
        onTap: () => _choisirLesMuscles(principaux: false),
      )),
    ];

    final texte = <Widget>[
      const TitreSection('Compléments', detail: 'Facultatif.'),
      _bloc(ChampBord(controller: _notes, label: 'Notes', hint: 'Réglages de la machine, prise...', minLines: 2, maxLines: 5)),
      const SizedBox(height: 16),
      _bloc(
        ChampBord(
          controller: _video,
          label: 'Lien d\'une vidéo',
          hint: 'https://...',
          clavier: TextInputType.url,
          erreur: _tried ? _erreurVideo : null,
        ),
      ),
    ];

    final supprimer = <Widget>[
      if (!_creation) ...[
        const SizedBox(height: 32),
        _bloc(
          BoutonDestructif(
            label: 'Supprimer l\'exercice',
            icone: const IconeTrait(Trait.corbeille, size: 19),
            onPressed: _delete,
          ),
        ),
      ],
    ];

    const marge = EdgeInsets.only(bottom: 32);
    final body = LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 700) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ListView(padding: marge, children: [...media, ...identite, ...texte])),
            const SizedBox(width: 16),
            Expanded(child: ListView(padding: marge, children: [...details, ...supprimer])),
          ],
        );
      }
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: marge,
        children: [...media, ...identite, ...details, ...texte, ...supprimer],
      );
    });

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SousPage(
        title: _creation ? 'Nouvel exercice' : 'Modifier l\'exercice',
        subtitle: _creation ? 'Exercice perso' : _e!.nom,
        closeIcon: true,
        onBack: _back,
        maxContentWidth: 1100,
        bottomBar: BoutonPrincipal(label: _creation ? 'Créer l\'exercice' : 'Enregistrer', onPressed: _saving ? null : _save),
        body: body,
      ),
    );
  }
}
