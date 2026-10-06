import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/env.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/draft.dart';
import '../inscription_controller.dart';

/// Premier écran : logo, promesse, et départ du parcours.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Draft? _brouillon;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    try {
      final j = await context.read<Store>().readObject(Draft.collection);
      _brouillon = j == null ? null : Draft.fromJson(j);
    } catch (_) {
      _brouillon = null;
    }
    if (mounted) setState(() => _charge = true);
  }

  Future<void> _commencer({bool nouveau = false}) async {
    final store = context.read<Store>();
    if (nouveau && _brouillon != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Recommencer depuis le début ?',
        message: 'Tes réponses en cours seront effacées.',
        confirmLabel: 'Recommencer',
        destructive: true,
      );
      if (!ok) return;
      await store.delete(Draft.collection);
      _brouillon = null;
    }
    if (!mounted) return;
    await context.push('/bienvenue/profil');
    if (mounted) _lire();
  }

  /// Restauration d'une sauvegarde (JSON ou ZIP complet) par les écrans du module import.
  Future<void> _restaurer() async {
    await context.push('/import/sauvegarde/restaurer');
    if (!mounted) return;
    if (context.read<ProfileRepo>().hasProfile) {
      await context.read<Store>().delete(Draft.collection);
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = _brouillon;
    final reprise = b != null && (b.etape > 0 || b.prenom.isNotEmpty);
    final atouts = <(IconData, String, String)>[
      if (Env.muscuSeule) ...[
        (Icons.fitness_center_rounded, 'Tes séances', 'Suis chaque série, bats tes records'),
        (Icons.event_note_rounded, 'Tes programmes', 'Tes routines, ou un programme prêt à suivre'),
        (Icons.insights_rounded, 'Tes progrès', 'Tes courbes, et les muscles prêts à retravailler'),
      ] else ...[
      (AppDomain.entrainement.icon, 'Tes séances', 'Crée tes routines, suis chaque série, bats tes records'),
      (AppDomain.nutrition.icon, 'Tes repas', 'Calories et macros, calculées pour ton objectif'),
      (AppDomain.sommeil.icon, 'Ta récupération', 'Sommeil et muscles prêts à retravailler'),
      (AppDomain.coach.icon, 'Ton coach', 'Des réponses qui connaissent tes chiffres'),
      ],
    ];
    final wide = context.isExpanded;

    final intro = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const AppLogo(size: 104),
        const SizedBox(height: 20),
        const AppWordmark(size: 34),
        const SizedBox(height: 12),
        Text(
          'Ton corps, ton programme, tes progrès.\nTout reste sur ton téléphone.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 15.5, height: 1.45),
        ),
      ],
    );

    final liste = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icone, t, s) in atouts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              // Une icône blanche, sans pastille de couleur.
              SizedBox.square(dimension: 40, child: Icon(icone, size: 26, color: c.text)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: AppType.rowTitle()),
                  Text(s, style: AppType.rowSubtitle()),
                ]),
              ),
            ]),
          ),
      ],
    );

    final actions = !_charge
        ? const Column(children: [Skeleton(height: 52, radius: AppTokens.rPill), SizedBox(height: 12), Skeleton(height: 20, width: 160)])
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reprise) ...[
                PillButton(
                  label: 'Reprendre où j\'en étais',
                  icon: Icons.play_arrow_rounded,
                  size: PillSize.large,
                  expand: true,
                  onPressed: _commencer,
                ),
                const SizedBox(height: 6),
                Text(
                  'Étape ${Etape.values[b.etape.clamp(0, Etape.values.length - 1)].rang + 1} sur ${Etape.parcours.length}${b.prenom.trim().isEmpty ? '' : ', ${b.prenom.trim()}'}',
                  style: AppType.rowSubtitle(),
                ),
                const SizedBox(height: 8),
                PillButton.ghost(label: 'Recommencer depuis le début', onPressed: () => _commencer(nouveau: true)),
              ] else
                PillButton(
                  label: 'Commencer',
                  icon: Icons.arrow_forward_rounded,
                  size: PillSize.large,
                  expand: true,
                  onPressed: _commencer,
                ),
              const SizedBox(height: 4),
              PillButton.ghost(
                label: 'Restaurer une sauvegarde',
                icon: Icons.settings_backup_restore_rounded,
                onPressed: _restaurer,
              ),
              const SizedBox(height: 4),
              Text('Deux minutes, ${Etape.questions} questions.', style: AppType.rowSubtitle()),
            ],
          );

    // Profil illisible au démarrage : on arrive ici comme à un premier
    // lancement. Le dire, et dire où est la copie de secours.
    final abimes = fichiersAbimes(context.read<Store>(), context.read<AppData?>());
    final bas = abimes.isEmpty
        ? actions
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [AlerteDonnees(fichiers: abimes), const SizedBox(height: 16), actions],
          );

    return SubPageScaffold(
      title: '',
      maxContentWidth: wide ? 1100 : Breakpoints.content,
      body: LayoutBuilder(builder: (context, box) {
        if (wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Row(
              children: [
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 36), liste])),
                const SizedBox(width: 56),
                SizedBox(width: 380, child: Center(child: SingleChildScrollView(child: bas))),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(children: [const SizedBox(height: 12), intro, const SizedBox(height: 32), liste]),
                const SizedBox(height: 24),
                bas,
              ],
            ),
          ),
        );
      }),
    );
  }
}
