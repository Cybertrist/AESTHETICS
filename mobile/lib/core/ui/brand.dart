import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repos/profile_repo.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Logo de l'appli, toujours carré et jamais étiré.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        // Décodé à la taille affichée (le fichier fait plus de 1000 px de côté).
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      );
}

/// Nom de l'appli en capitales, tout en blanc.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTokens.fontDisplay,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size * 0.08,
      color: context.colors.text,
    );
    return Text('Aesthetics', style: style);
  }
}

/// Avatar rond : photo du profil, sinon initiale blanche sur gris, comme
/// sur la page Profil (le corail est réservé aux muscles).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 36, this.onTap, this.name, this.photoPath});

  final double size;
  final VoidCallback? onTap;

  /// Prénom et photo ; lus dans le profil s'ils ne sont pas fournis.
  final String? name;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = context.watch<ProfileRepo?>()?.profile;
    final n = (name ?? profile?.prenom ?? '').trim();
    final photo = photoPath ?? profile?.photo;
    final initial = n.isEmpty ? '' : n.characters.first.toUpperCase();

    Widget inner;
    if (photo != null && File(photo).existsSync()) {
      // Une photo d'appareil fait des dizaines de Mo une fois décodée : on la
      // demande à la taille de l'avatar.
      inner = Image.file(
        File(photo),
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      );
    } else if (initial.isNotEmpty) {
      inner = Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: AppTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.44,
            color: c.text,
            height: 1,
          ),
        ),
      );
    } else {
      inner = Icon(Icons.person_rounded, size: size * 0.6, color: c.text);
    }

    final avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface2),
      child: inner,
    );
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Profil',
      child: InkResponse(onTap: onTap, radius: size * 0.7, child: avatar),
    );
  }
}
