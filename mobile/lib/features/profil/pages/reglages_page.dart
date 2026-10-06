import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/navigation.dart';
import '../../../core/data/data.dart';
import '../../../core/env.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/health_link.dart';
import '../data/prefs.dart';
import '../widgets/maquette.dart';
import 'reglages/a_propos_section.dart';
import 'reglages/coach_section.dart';
import 'reglages/donnees_section.dart';
import 'reglages/entrainement_section.dart';
import 'reglages/notifications_section.dart';
import 'reglages/sante_section.dart';
import 'reglages/unites_section.dart';

/// Les pages de détail des réglages. Le titre de chaque page est le libellé
/// de la ligne qui y mène.
enum ReglagesSection {
  unites('unites', 'Unités'),
  entrainement('entrainement', 'Paramètres de séance'),
  notifications('notifications', 'Rappels'),
  sante('sante', 'Santé'),
  coach('coach', 'Coach'),
  donnees('donnees', 'Mes données'),
  aPropos('a-propos', 'À propos');

  const ReglagesSection(this.slug, this.titre);
  final String slug;
  final String titre;

  String get path => '${Paths.reglages}/$slug';

  Widget body() => switch (this) {
        unites => const UnitesSection(),
        entrainement => const EntrainementSection(),
        notifications => const NotificationsSection(),
        sante => const SanteSection(),
        coach => const CoachSection(),
        donnees => const DonneesSection(),
        aPropos => const AProposSection(),
      };

  static ReglagesSection? parSlug(String? s) => values.where((v) => v.slug == s).firstOrNull;
}

/// Une page de détail des réglages.
class ReglagesSectionPage extends StatelessWidget {
  const ReglagesSectionPage({super.key, required this.section});
  final ReglagesSection section;

  @override
  Widget build(BuildContext context) => PageMaquette(
        titre: section.titre,
        enfants: [section.body(), SizedBox(height: e(18))],
      );
}

/// Réglages : deux groupes, Entraînement et Données.
class ReglagesPage extends StatefulWidget {
  const ReglagesPage({super.key});

  /// Les sept jours : la semaine peut commencer n'importe lequel.
  static const jours = [
    (DateTime.monday, 'Lundi'),
    (DateTime.tuesday, 'Mardi'),
    (DateTime.wednesday, 'Mercredi'),
    (DateTime.thursday, 'Jeudi'),
    (DateTime.friday, 'Vendredi'),
    (DateTime.saturday, 'Samedi'),
    (DateTime.sunday, 'Dimanche'),
  ];

  @override
  State<ReglagesPage> createState() => _ReglagesPageState();
}

class _ReglagesPageState extends State<ReglagesPage> {
  late final Future<PrefsRepo> _prefs = PrefsRepo.ensure(context.read<Store>());

  Future<void> _repos() async {
    final repo = context.read<SettingsRepo>();
    var duree = Duration(seconds: repo.settings.reposParDefautSec);
    final ok = await showPanneauBas<bool>(
      context,
      titre: 'Repos par défaut',
      builder: (context) => StatefulBuilder(
        builder: (context, maj) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RoueMinSec(value: duree, maxMinutes: 9, pasSecondes: 5, onChanged: (d) => maj(() => duree = d)),
            SizedBox(height: e(14)),
            BoutonPrincipal(label: 'Valider', onPressed: duree.inSeconds < 5 ? null : () => Navigator.pop(context, true)),
          ],
        ),
      ),
    );
    if (ok == true) await repo.update((s) => s.copyWith(reposParDefautSec: duree.inSeconds));
  }

  Future<void> _premierJour() async {
    final repo = context.read<SettingsRepo>();
    final j = await showPanneauBas<int>(
      context,
      titre: 'Premier jour de la semaine',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (jour, nom) in ReglagesPage.jours)
            ChoixPanneau(label: nom, selected: jour == repo.settings.premierJourSemaine, onTap: () => Navigator.pop(context, jour)),
        ],
      ),
    );
    if (j != null) await repo.update((s) => s.copyWith(premierJourSemaine: j));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unite = context.watch<ProfileRepo>().unite;
    final s = context.watch<SettingsRepo>().settings;

    Widget groupe(String titre, List<Widget> lignes, {bool premier = false}) => GroupeTitre(titre: titre, lignes: lignes, premier: premier);

    return FutureBuilder<PrefsRepo>(
      future: _prefs,
      builder: (context, snap) {
        final repo = snap.data;
        return ListenableBuilder(
          listenable: repo ?? const _Rien(),
          builder: (context, _) {
            final secondes = s.reposParDefautSec;
            final rappels = [s.rappelsEntrainement, if (!Env.muscuSeule) s.rappelsComplements, if (!Env.muscuSeule) s.rappelsEau].where((x) => x).length;
            return PageMaquette(
              titre: 'Réglages',
              enfants: [
                groupe('Entraînement', premier: true, [
                  Ligne(
                    trace: Trace.unites,
                    titre: 'Unités',
                    valeur: '${unite.label}, ${Affichage.distanceLabel}, ${Affichage.longueur}',
                    onTap: () => context.push(ReglagesSection.unites.path),
                  ),
                  Ligne(
                    trace: Trace.chrono,
                    titre: 'Repos par défaut',
                    valeur: Fmt.minSec(secondes),
                    onTap: _repos,
                  ),
                  Ligne(
                    trace: Trace.calendrier,
                    titre: 'Premier jour',
                    valeur: ReglagesPage.jours.firstWhere((j) => j.$1 == s.premierJourSemaine, orElse: () => ReglagesPage.jours.first).$2,
                    onTap: _premierJour,
                  ),
                  Ligne(
                    trace: Trace.haltere,
                    titre: 'Paramètres de séance',
                    onTap: () => context.push(ReglagesSection.entrainement.path),
                  ),
                  Ligne(
                    trace: Trace.cloche,
                    titre: 'Rappels',
                    valeur: rappels == 0 ? 'Aucun' : Fmt.pluriel(rappels, 'actif'),
                    onTap: () => context.push(ReglagesSection.notifications.path),
                  ),
                ]),
                if (!Env.muscuSeule)
                  groupe('Suivi', [
                    Ligne(
                      trace: Trace.coeur,
                      titre: 'Santé',
                      valeur: HealthLink.supporte ? (s.santeConnectee ? 'Connecté' : 'Non connecté') : null,
                      onTap: () => context.push(ReglagesSection.sante.path),
                    ),
                    Ligne(
                      trace: Trace.etoile,
                      titre: 'Coach',
                      valeur: (s.coachApiKey?.isNotEmpty ?? false) ? 'Clé enregistrée' : 'Hors ligne',
                      onTap: () => context.push(ReglagesSection.coach.path),
                    ),
                  ]),
                groupe('Données', [
                  Ligne(
                    trace: Trace.donnees,
                    titre: 'Mes données',
                    detail: 'Importer, sauvegarder, exporter',
                    onTap: () => context.push(ReglagesSection.donnees.path),
                  ),
                  Ligne(
                    trace: Trace.info,
                    titre: 'À propos',
                    valeur: 'v ${appVersion.split('.').take(2).join('.')}${Env.demo ? ' · démo' : ''}',
                    onTap: () => context.push(ReglagesSection.aPropos.path),
                  ),
                ]),
                SizedBox(height: e(18) + MediaQuery.paddingOf(context).bottom),
                if (snap.hasError)
                  Bloc(child: Text('Les préférences n\'ont pas pu être lues : les valeurs par défaut sont affichées.', style: txt(11, FontWeight.w400, c.text2))),
              ],
            );
          },
        );
      },
    );
  }
}

/// Écoutable muet, tant que les préférences ne sont pas chargées.
class _Rien extends Listenable {
  const _Rien();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
