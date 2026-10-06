import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/claude_client.dart';
import '../data/coach_prefs.dart';
import '../logic/coach_engine.dart';
import '../widgets/coach_scope.dart';

/// Réglages du coach : connexion, modèle, ton, données partagées, historique.
class CoachSettingsPage extends StatelessWidget {
  const CoachSettingsPage({super.key});

  static String masque(String k) => k.length <= 12 ? '••••' : '${k.substring(0, 7)}…${k.substring(k.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settingsRepo = context.watch<SettingsRepo>();
    final settings = settingsRepo.settings;
    final coachRepo = context.watch<CoachRepo>();
    final key = CoachEngine.cle(settings);
    final ton = CoachTon.parse(settings.coachTon);

    return CoachListen(builder: (context, prefs, engine) {
      final ctrl = context.coachPrefs;
      Widget sw(bool v, ValueChanged<bool> f) => Switch(value: v, onChanged: f);
      return SubPageScaffold(
        title: 'Réglages du coach',
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            TileGroup(
              label: 'Connexion',
              children: [
                ListTileX(
                  leading: IconHalo(icon: key == null ? Icons.key_off_rounded : Icons.key_rounded, color: key == null ? c.text3 : AppTokens.domainCoach),
                  title: 'Clé API',
                  subtitle: key == null ? 'Aucune clé : le coach fonctionne hors ligne' : 'Enregistrée sur ce téléphone, ${masque(key)}',
                  showChevron: true,
                  onTap: () => context.push('/coach/reglages/cle'),
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.memory_rounded),
                  title: 'Modèle',
                  subtitle: 'Le cerveau du coach',
                  value: CoachModels.nom(settings.coachModele),
                  showChevron: true,
                  onTap: () => context.push('/coach/reglages/modele'),
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.psychology_rounded),
                  title: 'Réflexion',
                  subtitle: prefs.reflexion.description,
                  value: prefs.reflexion.label,
                  showChevron: true,
                  onTap: () async {
                    final v = await showChoiceDialog<CoachReflexion>(
                      context,
                      title: 'Réflexion',
                      message: 'Plus le coach réfléchit, plus ses réponses sont fines, mais lentes et coûteuses.',
                      options: [for (final r in CoachReflexion.values) (r, '${r.label} : ${r.description.toLowerCase()}')],
                      selected: prefs.reflexion,
                    );
                    if (v != null) await ctrl.update((p) => p.copyWith(reflexion: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            TileGroup(
              label: 'Personnalité',
              children: [
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.record_voice_over_rounded),
                  title: 'Ton',
                  subtitle: ton.description,
                  value: ton.label,
                  showChevron: true,
                  onTap: () async {
                    final v = await showChoiceDialog<CoachTon>(
                      context,
                      title: 'Ton du coach',
                      options: [for (final t in CoachTon.values) (t, '${t.label} : ${t.description.toLowerCase()}')],
                      selected: ton,
                    );
                    if (v != null) await settingsRepo.update((s) => s.copyWith(coachTon: v.name));
                  },
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.short_text_rounded),
                  title: 'Longueur',
                  subtitle: prefs.longueur.description,
                  value: prefs.longueur.label,
                  showChevron: true,
                  onTap: () async {
                    final v = await showChoiceDialog<CoachLongueur>(
                      context,
                      title: 'Longueur des réponses',
                      options: [for (final l in CoachLongueur.values) (l, '${l.label} : ${l.description.toLowerCase()}')],
                      selected: prefs.longueur,
                    );
                    if (v != null) await ctrl.update((p) => p.copyWith(longueur: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            TileGroup(
              label: 'Ce que lit le coach',
              children: [
                ListTileX(
                  leading: IconHalo(icon: Icons.shield_rounded, color: AppTokens.domainHeart),
                  title: 'Données partagées',
                  subtitle: prefs.partage.isEmpty
                      ? 'Aucune : réponses générales'
                      : prefs.partage.length == CoachPartage.values.length
                          ? 'Toutes, sur ${prefs.periodeJours} jours'
                          : '${prefs.partage.length} sur ${CoachPartage.values.length}, sur ${prefs.periodeJours} jours',
                  showChevron: true,
                  onTap: () => context.push('/coach/reglages/donnees'),
                ),
                ListTileX(
                  leading: IconHalo(icon: Icons.visibility_rounded, color: AppTokens.domainHeart),
                  title: 'Ce que voit le coach',
                  subtitle: 'Le résumé exact envoyé avec chaque question',
                  showChevron: true,
                  onTap: () => context.push('/coach/reglages/contexte'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TileGroup(
              label: 'Rendez-vous',
              children: [
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.format_quote_rounded),
                  title: 'Phrase du jour par le coach',
                  subtitle: key == null ? 'Nécessite une clé ; sinon calculée sur le téléphone' : 'Sinon, calculée sur le téléphone',
                  trailing: sw(prefs.phraseIa, (v) => ctrl.update((p) => p.copyWith(phraseIa: v, clearPhrase: true))),
                  onTap: () => ctrl.update((p) => p.copyWith(phraseIa: !p.phraseIa, clearPhrase: true)),
                ),
                ListTileX(
                  leading: IconHalo.domain(AppDomain.coach, icon: Icons.insights_rounded),
                  title: 'Bilan du dimanche',
                  subtitle: key == null ? 'Nécessite une clé' : 'Le coach rédige ton bilan dès l\'ouverture du coach le dimanche',
                  trailing: sw(prefs.bilanDimanche, (v) => ctrl.update((p) => p.copyWith(bilanDimanche: v))),
                  onTap: () => ctrl.update((p) => p.copyWith(bilanDimanche: !p.bilanDimanche)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TileGroup(
              label: 'Historique',
              children: [
                ListTileX(
                  leading: IconHalo(icon: Icons.forum_rounded, color: AppTokens.domainCoach),
                  title: 'Conversations',
                  value: '${coachRepo.conversations.length}',
                  showChevron: true,
                  onTap: () => context.push('/coach/historique'),
                ),
                ListTileX(
                  leading: IconHalo(icon: Icons.delete_sweep_rounded, color: c.error),
                  title: 'Effacer l\'historique',
                  subtitle: 'Toutes les conversations, les bilans rédigés et la phrase du jour',
                  enabled: coachRepo.conversations.isNotEmpty || prefs.bilans.isNotEmpty,
                  onTap: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Effacer l\'historique du coach ?',
                      message: '${Fmt.pluriel(coachRepo.conversations.length, 'conversation')} et '
                          '${Fmt.pluriel(prefs.bilans.length, 'bilan rédigé', 'bilans rédigés')} seront supprimés. '
                          'Les routines et repas déjà ajoutés restent.',
                      confirmLabel: 'Tout effacer',
                      destructive: true,
                      icon: Icons.delete_sweep_rounded,
                    );
                    if (!ok || !context.mounted) return;
                    for (final conv in coachRepo.conversations) {
                      engine.stop(conv.id);
                    }
                    await coachRepo.clear();
                    await engine.effacerCaches();
                    if (context.mounted) Toasts.success(context, 'Historique du coach effacé.');
                  },
                ),
                ListTileX(
                  leading: IconHalo(icon: Icons.restart_alt_rounded, color: c.text3),
                  title: 'Réglages par défaut',
                  subtitle: 'Garde la clé et l\'historique',
                  onTap: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Revenir aux réglages par défaut ?',
                      message: 'Modèle, réflexion, ton, longueur et données partagées reviennent à leur valeur de départ.',
                      confirmLabel: 'Réinitialiser',
                    );
                    if (!ok) return;
                    await settingsRepo.update((s) => s.copyWith(coachModele: CoachModels.defaut, coachTon: CoachTon.bienveillant.name));
                    final bilans = prefs.bilans;
                    final appliquees = prefs.actionsAppliquees;
                    final modeles = prefs.modelesApi;
                    await ctrl.reset();
                    await ctrl.update((p) => p.copyWith(bilans: bilans, actionsAppliquees: appliquees, modelesApi: modeles));
                    if (context.mounted) Toasts.success(context, 'Réglages du coach réinitialisés.');
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter + 4),
              child: Text(
                'Avec une clé, tes questions et le résumé de tes données partent vers l\'API d\'Anthropic pour obtenir la réponse. '
                'Rien n\'est envoyé sans clé ; les conversations restent sur ton téléphone.',
                style: AppType.rowSubtitle().copyWith(fontSize: 12.5, color: c.text3),
              ),
            ),
          ],
        ),
      );
    });
  }
}
