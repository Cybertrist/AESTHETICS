import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/claude_client.dart';
import '../logic/coach_engine.dart';
import '../widgets/coach_scope.dart';

/// Choix du modèle utilisé par le coach.
class ModelPage extends StatefulWidget {
  const ModelPage({super.key});

  @override
  State<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends State<ModelPage> {
  bool _chargement = false;
  String? _erreur;

  Future<void> _actualiser(String key) async {
    final prefs = context.coachPrefs;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final client = ClaudeClient(apiKey: key);
    try {
      final list = await client.listModels();
      await prefs.update((p) => p.copyWith(modelesApi: list.where((m) => m.$1.startsWith('claude')).toList()));
      if (mounted) Toasts.success(context, 'Liste des modèles à jour.');
    } on CoachApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      client.close();
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _choisir(String id) async {
    await context.read<SettingsRepo>().update((s) => s.copyWith(coachModele: id));
    if (mounted) Toasts.success(context, 'Le coach utilise maintenant ${CoachModels.nom(id)}.');
  }

  Future<void> _saisir(String actuel) async {
    final t = await showTextInputDialog(
      context,
      title: 'Identifiant du modèle',
      initial: actuel,
      hint: 'claude-…',
      confirmLabel: 'Utiliser',
    );
    final v = t?.trim();
    if (v != null && v.isNotEmpty) await _choisir(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = context.watch<SettingsRepo>().settings;
    final key = CoachEngine.cle(settings);
    final actuel = CoachEngine.modele(settings);

    return CoachListen(builder: (context, prefs, engine) {
      final connus = {for (final m in CoachModels.connus) m.id};
      final autres = prefs.modelesApi.where((m) => !connus.contains(m.$1)).toList();
      final dispo = {for (final m in prefs.modelesApi) m.$1};
      final personnalise = !connus.contains(actuel) && !autres.any((m) => m.$1 == actuel);

      Widget tuile(String id, String nom, String? description) {
        final sel = id == actuel;
        final absent = dispo.isNotEmpty && !dispo.contains(id);
        return ListTileX(
          selected: sel,
          leading: IconHalo(icon: Icons.memory_rounded, color: sel ? c.accent : AppTokens.domainCoach, size: 40),
          title: nom,
          subtitle: [
            ?description,
            if (absent) 'Non listé pour ta clé',
          ].join(' · '),
          subtitleColor: absent ? c.warning : null,
          trailing: sel ? Icon(Icons.check_circle_rounded, color: c.accent) : null,
          onTap: () => _choisir(id),
        );
      }

      return SubPageScaffold(
        title: 'Modèle',
        subtitle: CoachModels.nom(actuel),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            if (key == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 0, AppTokens.gutter, 12),
                child: Text('Le modèle servira dès que tu auras ajouté une clé API.', style: AppType.rowSubtitle()),
              ),
            TileGroup(
              label: 'Conseillés',
              children: [for (final m in CoachModels.connus) tuile(m.id, m.nom, m.description)],
            ),
            if (autres.isNotEmpty) ...[
              const SizedBox(height: 14),
              TileGroup(
                label: 'Disponibles avec ta clé',
                labelTrailing: LabelCount('${autres.length}'),
                children: [for (final m in autres) tuile(m.$1, m.$2, m.$1)],
              ),
            ],
            if (personnalise) ...[
              const SizedBox(height: 14),
              TileGroup(label: 'Personnalisé', children: [tuile(actuel, actuel, 'Saisi à la main')]),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (key != null)
                    PillButton.secondary(
                      label: 'Actualiser la liste',
                      icon: Icons.refresh_rounded,
                      size: PillSize.small,
                      loading: _chargement,
                      onPressed: _chargement ? null : () => _actualiser(key),
                    ),
                  PillButton.ghost(label: 'Saisir un identifiant', icon: Icons.edit_rounded, size: PillSize.small, onPressed: () => _saisir(actuel)),
                ],
              ),
            ),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 12, AppTokens.gutter, 0),
                child: Text(_erreur!, style: AppType.rowSubtitle(color: c.error)),
              ),
          ],
        ),
      );
    });
  }
}
