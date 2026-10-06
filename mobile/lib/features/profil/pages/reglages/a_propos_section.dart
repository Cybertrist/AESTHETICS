import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/env.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/prefs.dart';
import '../../widgets/maquette.dart';
import '../../widgets/setting_rows.dart';

/// Version affichée (suit `version:` de pubspec.yaml).
const appVersion = '1.0.0';
const appBuild = 1;
const depotUrl = 'https://github.com/Cybertrist/Aesthetic';

/// Réglages > À propos : logo, version, code source, licences, accès caché
/// à la page développeur (sept appuis sur la version).
class AProposSection extends StatefulWidget {
  const AProposSection({super.key});

  /// Phrase sous le logo : elle ne cite que les modules visibles.
  static const accroche = Env.muscuSeule ? 'Ta musculation, sur ton téléphone.' : 'Muscu, nutrition, sommeil et coach, sur ton téléphone.';

  /// Promesse de confidentialité : le coach n'est cité que s'il est là.
  static const confidentialite = Env.muscuSeule
      ? 'Aucun compte, aucun serveur, aucune publicité. Tout est rangé sur ce téléphone.'
      : 'Aucun compte, aucun serveur, aucune publicité. Tout est rangé sur ce téléphone ; seul le coach, si tu lui donnes une clé, envoie ce que tu choisis de partager.';

  @override
  State<AProposSection> createState() => _AProposSectionState();
}

class _AProposSectionState extends State<AProposSection> {
  int _appuis = 0;

  Future<void> _appuiVersion(PrefsRepo repo) async {
    if (repo.prefs.devDebloque) {
      context.push('/reglages/dev');
      return;
    }
    _appuis++;
    if (_appuis >= 7) {
      _appuis = 0;
      await repo.update((p) => p.copyWith(devDebloque: true));
      if (!mounted) return;
      Toasts.success(context, 'Mode développeur activé');
      context.push('/reglages/dev');
    } else if (_appuis >= 3) {
      final reste = 7 - _appuis;
      Toasts.show(context, 'Encore $reste appui${reste > 1 ? 's' : ''} pour le mode développeur', duration: const Duration(milliseconds: 900));
    }
  }

  Future<void> _ouvrir(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) Toasts.error(context, 'Impossible d\'ouvrir le lien');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PrefsBuilder(
      builder: (context, prefs, repo) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Bloc(
            haut: 8,
            bas: 14,
            child: Column(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(e(18)), child: const AppLogo(size: 84)),
                SizedBox(height: e(12)),
                const AppWordmark(size: 24),
                SizedBox(height: e(4)),
                Text(AProposSection.accroche, textAlign: TextAlign.center, style: txt(12, FontWeight.w400, c.text2)),
              ],
            ),
          ),
          GroupeTitre(
            lignes: [
              Ligne(
                trace: Trace.info,
                titre: 'Version',
                valeur: '$appVersion ($appBuild)${Env.demo ? ' · démo' : ''}',
                chevron: false,
                onTap: () => _appuiVersion(repo),
              ),
              if (prefs.devDebloque) Ligne(trace: Trace.code, titre: 'Mode développeur', onTap: () => context.push('/reglages/dev')),
              Ligne(trace: Trace.code, titre: 'Code source', detail: 'github.com/Cybertrist/Aesthetic', onTap: () => _ouvrir(depotUrl)),
              Ligne(
                trace: Trace.document,
                titre: 'Licences',
                detail: 'Bibliothèques libres utilisées',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Aesthetics',
                  applicationVersion: '$appVersion ($appBuild)',
                  applicationIcon: const Padding(padding: EdgeInsets.all(12), child: AppLogo(size: 64)),
                  applicationLegalese: 'Cybertrist',
                ),
              ),
            ],
          ),
          GroupeTitre(
            titre: 'Confidentialité',
            lignes: [
              Ligne(trace: Trace.bouclier, titre: 'Tes données restent ici', detail: AProposSection.confidentialite, detailLignes: 6),
            ],
          ),
        ],
      ),
    );
  }
}
