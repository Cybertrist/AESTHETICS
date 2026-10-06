import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/data.dart';
import '../../../../core/logic/logic.dart';
import '../../../../core/ui/ui.dart';
import '../../data/backup_service.dart';
import '../../widgets/maquette.dart';
import 'donnees_section.dart';

/// Réglages > Données > Sauvegardes du téléphone.
class SauvegardesPage extends StatefulWidget {
  const SauvegardesPage({super.key});

  @override
  State<SauvegardesPage> createState() => _SauvegardesPageState();
}

enum _Action { restaurer, partager, supprimer }

class _SauvegardesPageState extends State<SauvegardesPage> {
  late Future<List<SauvegardeLocale>> _liste = BackupService.sauvegardesLocales();
  bool _occupe = false;

  void _recharger() => setState(() => _liste = BackupService.sauvegardesLocales());

  Future<void> _nouvelle() async {
    setState(() => _occupe = true);
    try {
      await BackupService(context.read<AppData>()).sauvegarderSurTelephone();
      if (mounted) Toasts.success(context, 'Sauvegarde enregistrée');
    } catch (e) {
      if (mounted) Toasts.error(context, 'Sauvegarde impossible : $e');
    } finally {
      if (mounted) setState(() => _occupe = false);
      _recharger();
    }
  }

  Future<void> _ouvrir(SauvegardeLocale s) async {
    final a = await showActionMenu<_Action>(
      context,
      title: 'Sauvegarde du ${Fmt.date(s.date)}',
      items: const [
        ActionMenuItem(value: _Action.restaurer, label: 'Restaurer', icon: Icons.restore_rounded),
        ActionMenuItem(value: _Action.partager, label: 'Envoyer', icon: Icons.share_rounded),
        ActionMenuItem(value: _Action.supprimer, label: 'Supprimer', icon: Icons.delete_rounded, destructive: true),
      ],
    );
    if (a == null || !mounted) return;
    try {
      switch (a) {
        case _Action.restaurer:
          final raw = await s.fichier.readAsString();
          if (!mounted) return;
          if (!await confirmerRestauration(context, raw)) return;
          if (!mounted) return;
          setState(() => _occupe = true);
          await BackupService(context.read<AppData>()).restaurer(raw);
          if (mounted) Toasts.success(context, 'Données restaurées');
        case _Action.partager:
          await SharePlus.instance.share(ShareParams(files: [XFile(s.fichier.path, mimeType: 'application/json')], subject: 'Sauvegarde Aesthetics'));
        case _Action.supprimer:
          final ok = await showConfirmDialog(context, title: 'Supprimer cette sauvegarde ?', confirmLabel: 'Supprimer', destructive: true);
          if (ok) await s.fichier.delete();
      }
    } catch (e) {
      if (mounted) Toasts.error(context, 'Échec : $e');
    } finally {
      if (mounted) setState(() => _occupe = false);
      _recharger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageMaquette(
      titre: 'Copies du téléphone',
      sousTitre: 'Les 10 dernières copies rapides',
      bas: BoutonPrincipal(label: _occupe ? 'Sauvegarde...' : 'Sauvegarder maintenant', onPressed: _occupe ? null : _nouvelle),
      enfants: [
        FutureBuilder<List<SauvegardeLocale>>(
          future: _liste,
          builder: (context, snap) {
            if (snap.hasError) {
              return Column(
                children: [
                  Vide(titre: 'Dossier illisible', message: '${snap.error}'),
                  SizedBox(width: e(140), child: BoutonDuo(label: 'Réessayer', secondaire: true, onPressed: _recharger)),
                ],
              );
            }
            if (!snap.hasData) return const SizedBox.shrink();
            final liste = snap.data!;
            if (liste.isEmpty) {
              return const Vide(
                titre: 'Aucune copie',
                message: 'Fais-en une maintenant : elle reste sur le téléphone, même si tu effaces les données.',
              );
            }
            return GroupeTitre(
              premier: true,
              lignes: [
                for (final (i, s) in liste.indexed)
                  Ligne(
                    trace: Trace.boite,
                    titre: '${Fmt.relatif(s.date)} à ${Fmt.heure(s.date)}',
                    detail: i == 0 ? 'La plus récente · ${Fmt.date(s.date)}' : Fmt.date(s.date),
                    valeur: formatOctets(s.taille),
                    actif: !_occupe,
                    onTap: () => _ouvrir(s),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
