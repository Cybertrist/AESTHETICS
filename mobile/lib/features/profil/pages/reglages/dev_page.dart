import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/navigation.dart';
import '../../../../core/data/data.dart';
import '../../../../core/demo/demo_data.dart';
import '../../../../core/env.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/ui.dart';
import '../../data/backup_service.dart';
import '../../data/prefs.dart';
import '../../data/reminders.dart';
import '../../widgets/setting_rows.dart';
import 'a_propos_section.dart';

/// Une collection du Store, vue de la page développeur.
class _Collection {
  const _Collection(this.nom, this.taille, this.elements);
  final String nom;
  final int taille;
  final int? elements;
}

/// Page cachée du développeur (sept appuis sur la version).
class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  late Future<List<_Collection>> _collections = _lire();
  late Future<int> _attente = Reminders.enAttente().then((l) => l.length);

  Future<List<_Collection>> _lire() async {
    final store = context.read<Store>();
    final out = <_Collection>[];
    for (final n in (await store.names())..sort()) {
      final f = File('${store.dir.path}${Platform.pathSeparator}$n.json');
      final taille = await f.exists() ? await f.length() : 0;
      final v = await store.read(n);
      out.add(_Collection(n, taille, v is List ? v.length : (v is Map ? v.length : null)));
    }
    return out;
  }

  void _recharger() => setState(() {
        _collections = _lire();
        _attente = Reminders.enAttente().then((l) => l.length);
      });

  Future<void> _essayer(String ok, Future<void> Function() f) async {
    try {
      await f();
      if (mounted) Toasts.success(context, ok);
    } catch (e) {
      if (mounted) Toasts.error(context, '$e');
    }
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = context.read<AppData>();
    final sessions = context.watch<SessionRepo>().sessions.length;
    return SubPageScaffold(
      title: 'Développeur',
      subtitle: 'Outils cachés, à manier avec soin',
      haloColor: c.coach,
      body: SettingsList(
        children: [
          TileGroup(
            label: 'Environnement',
            children: [
              ValueRow(title: 'Version', icon: Icons.tag_rounded, value: '$appVersion ($appBuild)'),
              ValueRow(title: 'Variante', icon: Icons.science_rounded, value: Env.demo ? 'Démo' : 'Complète'),
              ValueRow(title: 'Flutter en mode', icon: Icons.bug_report_rounded, value: kModeLabel),
              ListTileX(
                title: 'Dossier des données',
                subtitle: data.store.dir.path,
                subtitleMaxLines: 3,
                leading: IconHalo(icon: Icons.folder_rounded, color: c.text2, size: 36, glow: false),
                trailing: IconButton(
                  tooltip: 'Copier le chemin',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: data.store.dir.path));
                    if (context.mounted) Toasts.show(context, 'Chemin copié');
                  },
                ),
              ),
            ],
          ),
          FutureBuilder<List<_Collection>>(
            future: _collections,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(icon: Icons.error_outline_rounded, iconColor: c.error, title: 'Lecture impossible', message: '${snap.error}', actionLabel: 'Réessayer', onAction: _recharger, compact: true);
              }
              if (!snap.hasData) return const SkeletonList(count: 4);
              final liste = snap.data!;
              return TileGroup(
                label: 'Collections',
                labelTrailing: LabelCount('${liste.length}'),
                children: [
                  if (liste.isEmpty) const EmptyState(icon: Icons.inbox_rounded, title: 'Aucune collection', compact: true),
                  for (final col in liste)
                    ListTileX(
                      dense: true,
                      title: col.nom,
                      subtitle: col.elements == null ? null : '${col.elements} éléments',
                      value: formatOctets(col.taille),
                      valueColor: c.text3,
                      showChevron: true,
                      onTap: () => context.push('/reglages/dev/collection/${Uri.encodeComponent(col.nom)}'),
                    ),
                ],
              );
            },
          ),
          TileGroup(
            label: 'Outils',
            children: [
              ValueRow(title: 'Vitrine des composants', icon: Icons.widgets_rounded, color: c.coach, onTap: () => context.push(Paths.composants)),
              ValueRow(
                title: 'Remplir avec des données de démo',
                subtitle: sessions > 0 ? 'Réservé à une appli sans séance' : 'Six mois de séances, repas et nuits inventés',
                icon: Icons.auto_fix_high_rounded,
                enabled: sessions == 0,
                onTap: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Remplir avec la démo ?',
                    message: 'Des données inventées vont s\'ajouter à cette appli, profil compris.',
                    confirmLabel: 'Remplir',
                  );
                  if (ok) await _essayer('Données de démo ajoutées', () => DemoData.seed(data));
                },
              ),
              ValueRow(
                title: 'Rejouer l\'inscription',
                subtitle: 'Efface seulement le profil',
                icon: Icons.replay_rounded,
                onTap: () async {
                  final ok = await showConfirmDialog(context, title: 'Effacer le profil ?', message: 'Les séances et le reste sont gardés.', confirmLabel: 'Effacer', destructive: true);
                  if (!ok) return;
                  await data.profile.clear();
                  if (context.mounted) context.go(Paths.bienvenue);
                },
              ),
              ValueRow(
                title: 'Recharger toutes les données',
                icon: Icons.refresh_rounded,
                chevron: false,
                onTap: () => _essayer('Données relues depuis le disque', () async {
                  await data.loadAll();
                  await PrefsRepo.maybeInstance?.load();
                }),
              ),
            ],
          ),
          FutureBuilder<int>(
            future: _attente,
            builder: (context, snap) => TileGroup(
              label: 'Notifications',
              labelTrailing: LabelCount(snap.hasData ? '${snap.data} en attente' : '...'),
              children: [
                ValueRow(title: 'Envoyer un essai', icon: Icons.notifications_active_rounded, chevron: false, onTap: () => _essayer('Essai envoyé', Reminders.essai)),
                ValueRow(
                  title: 'Replanifier les rappels',
                  icon: Icons.schedule_send_rounded,
                  chevron: false,
                  onTap: () => _essayer('Rappels replanifiés', () async {
                    final prefs = await PrefsRepo.ensure(data.store);
                    await Reminders.planifier(data.settings.settings, prefs.prefs, complements: data.health.supplements);
                  }),
                ),
                ValueRow(title: 'Annuler tous les rappels', icon: Icons.notifications_off_rounded, chevron: false, onTap: () => _essayer('Rappels annulés', Reminders.toutAnnuler)),
              ],
            ),
          ),
          PrefsBuilder(
            builder: (context, prefs, repo) => TileGroup(
              children: [
                ValueRow(
                  title: 'Masquer le mode développeur',
                  icon: Icons.visibility_off_rounded,
                  chevron: false,
                  onTap: () async {
                    await repo.update((p) => p.copyWith(devDebloque: false));
                    if (context.mounted) context.pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const kModeLabel = bool.fromEnvironment('dart.vm.product') ? 'publication' : (bool.fromEnvironment('dart.vm.profile') ? 'profil' : 'débogage');

/// Contenu brut d'une collection.
class DevCollectionPage extends StatefulWidget {
  const DevCollectionPage({super.key, required this.nom});
  final String nom;

  @override
  State<DevCollectionPage> createState() => _DevCollectionPageState();
}

class _DevCollectionPageState extends State<DevCollectionPage> {
  late final Future<String> _future = context.read<Store>().read(widget.nom).then((v) => const JsonEncoder.withIndent('  ').convert(v));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nom = widget.nom;
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        final txt = snap.data;
        return SubPageScaffold(
          title: nom,
          subtitle: txt == null ? null : '${txt.length} caractères',
          actions: [
            if (txt != null)
              IconButton(
                tooltip: 'Copier',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: txt));
                  if (context.mounted) Toasts.show(context, 'JSON copié');
                },
              ),
          ],
          body: snap.hasError
              ? EmptyState(icon: Icons.error_outline_rounded, iconColor: c.error, title: 'Lecture impossible', message: '${snap.error}')
              : txt == null
                  ? const SkeletonList(count: 8, leading: false)
                  : txt == 'null'
                      ? const EmptyState(icon: Icons.inbox_rounded, title: 'Collection vide')
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(AppTokens.gutter),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SelectableText(
                              txt.length > 200000 ? '${txt.substring(0, 200000)}\n...' : txt,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: c.text2, height: 1.4),
                            ),
                          ),
                        ),
        );
      },
    );
  }
}
