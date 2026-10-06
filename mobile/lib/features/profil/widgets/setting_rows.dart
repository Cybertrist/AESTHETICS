import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/prefs.dart';

/// Ligne de réglage avec interrupteur.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.color,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListTileX(
        title: title,
        subtitle: subtitle,
        enabled: enabled,
        leading: icon == null ? null : IconHalo(icon: icon!, color: color ?? context.colors.text2, size: 36, glow: color != null),
        trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
        onTap: enabled ? () => onChanged(!value) : null,
      ),
    );
  }
}

/// Ligne de réglage qui ouvre un choix : valeur à droite et chevron.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
    this.valueColor,
    this.chevron = true,
    this.enabled = true,
  });

  final String title;
  final String? value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final Color? valueColor;
  final bool chevron;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTileX(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      leading: icon == null ? null : IconHalo(icon: icon!, color: color ?? context.colors.text2, size: 36, glow: color != null),
      value: value,
      valueColor: valueColor ?? context.colors.text2,
      showChevron: chevron && onTap != null,
      onTap: onTap,
    );
  }
}

/// Texte d'explication sous un groupe de réglages.
class GroupNote extends StatelessWidget {
  const GroupNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppTokens.gutter + 4, 8, AppTokens.gutter + 4, 0),
        child: Text(text, style: AppType.rowSubtitle()),
      );
}

/// Reconstruit quand les préférences du module changent, après les avoir
/// chargées (squelette pendant le chargement).
class PrefsBuilder extends StatefulWidget {
  const PrefsBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, ProfilPrefs prefs, PrefsRepo repo) builder;

  @override
  State<PrefsBuilder> createState() => _PrefsBuilderState();
}

class _PrefsBuilderState extends State<PrefsBuilder> {
  late Future<PrefsRepo> _future = PrefsRepo.ensure(context.read<Store>());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrefsRepo>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            iconColor: context.colors.error,
            title: 'Réglages illisibles',
            message: 'Le fichier des préférences n\'a pas pu être lu.',
            actionLabel: 'Réessayer',
            onAction: () => setState(() => _future = PrefsRepo.ensure(context.read<Store>())),
          );
        }
        final repo = snap.data;
        if (repo == null) return const SkeletonList(count: 5);
        return ListenableBuilder(
          listenable: repo,
          builder: (context, _) => widget.builder(context, repo.prefs, repo),
        );
      },
    );
  }
}

/// Liste défilante des réglages d'une section (marges et place du bas).
class SettingsList extends StatelessWidget {
  const SettingsList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      );
}

/// Formate « 18:00 » depuis un TimeOfDay et inversement.
String heureTexte(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay heureDepuis(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.tryParse(p.first) ?? 8, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

/// Choisit une heure avec le sélecteur du thème.
Future<String?> choisirHeure(BuildContext context, String initiale, {String? titre}) async {
  final t = await showTimePicker(
    context: context,
    initialTime: heureDepuis(initiale),
    helpText: titre,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  return t == null ? null : heureTexte(t);
}

/// Contenu défilant avec un bouton fixé en bas (au-dessus du clavier).
/// Remplace `SubPageScaffold.bottomBar`, qui prend aujourd'hui toute la
/// hauteur (voir la demande de ROUTINES à la fondation).
class AvecBoutonBas extends StatelessWidget {
  const AvecBoutonBas({super.key, required this.body, required this.bouton});
  final Widget body;
  final Widget bouton;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(child: body),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.line))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 10, AppTokens.gutter, 10),
              child: bouton,
            ),
          ),
        ],
      );
}
