import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';

enum _Source { camera, galerie, retirer }

/// Profil sans photo (copyWith ne sait pas remettre un champ à null).
UserProfile sansPhoto(UserProfile p) => UserProfile(
      id: p.id,
      prenom: p.prenom,
      sexe: p.sexe,
      naissance: p.naissance,
      tailleCm: p.tailleCm,
      poidsKg: p.poidsKg,
      poidsCibleKg: p.poidsCibleKg,
      objectif: p.objectif,
      niveau: p.niveau,
      activite: p.activite,
      joursParSemaine: p.joursParSemaine,
      dureeSeanceMin: p.dureeSeanceMin,
      materiel: p.materiel,
      unitePoids: p.unitePoids,
      objectifsNutrition: p.objectifsNutrition,
      creeLe: p.creeLe,
    );

/// Propose de prendre, choisir ou retirer la photo de profil, puis
/// l'enregistre dans le dossier privé. Rend vrai si le profil a changé.
Future<bool> changerPhotoProfil(BuildContext context, ProfileRepo repo, Store store) async {
  final p = repo.profile;
  if (p == null) return false;
  final a = await showActionMenu<_Source>(
    context,
    title: 'Photo de profil',
    items: [
      const ActionMenuItem(value: _Source.camera, label: 'Prendre une photo', icon: Icons.photo_camera_rounded),
      const ActionMenuItem(value: _Source.galerie, label: 'Choisir dans la galerie', icon: Icons.photo_library_rounded),
      if (p.photo != null) const ActionMenuItem(value: _Source.retirer, label: 'Retirer la photo', icon: Icons.delete_rounded, destructive: true),
    ],
  );
  if (a == null) return false;
  try {
    if (a == _Source.retirer) {
      await _supprimer(p.photo);
      await repo.save(sansPhoto(p));
      return true;
    }
    final x = await ImagePicker().pickImage(
      source: a == _Source.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x == null) return false;
    final dir = await store.mediaDir();
    // L'extension se lit sur le nom du fichier, pas sur ses dossiers.
    final nom = x.path.split(RegExp(r'[/\\]')).last;
    final ext = nom.lastIndexOf('.') > 0 ? nom.substring(nom.lastIndexOf('.')) : '.jpg';
    final dest = '${dir.path}${Platform.pathSeparator}profil-${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(x.path).copy(dest);
    await _supprimer(p.photo);
    await repo.update((q) => q.copyWith(photo: dest));
    return true;
  } catch (e) {
    if (context.mounted) Toasts.error(context, 'Photo impossible : $e');
    return false;
  }
}

Future<void> _supprimer(String? chemin) async {
  if (chemin == null) return;
  try {
    final f = File(chemin);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
