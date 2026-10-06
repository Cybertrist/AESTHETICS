import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/muscle.dart';
import '../../core/models/workout.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/body/body_map.dart';
import '../../core/ui/ui.dart';

/// Page cachée (/dev/composants) : vitrine de tous les composants partagés.
class ComposantsPage extends StatefulWidget {
  const ComposantsPage({super.key});

  @override
  State<ComposantsPage> createState() => _ComposantsPageState();
}

class _ComposantsPageState extends State<ComposantsPage> {
  String _onglet = 'programmes';
  final Set<int> _faites = {0, 1};
  final Set<String> _zones = {'pecs', 'dos', 'abdos'};
  final Set<String> _favoris = {};
  Set<String> _filtres = {'Poitrine'};
  String _periode = '3m';
  String _vue = 'seances';
  int _silhouette = 0;
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  double _poids = 80;
  int _nav = 0;
  bool _switch = true;
  double _slider = 0.6;
  Duration _duree = const Duration(hours: 1, minutes: 4, seconds: 12);
  Duration _repos = const Duration(minutes: 2);
  String _unite = 'kg';
  TypeSeance _type = TypeSeance.musculation;

  /// Jour de référence de la vitrine : vendredi 2 octobre 2026.
  static final _auj = DateTime(2026, 10, 2);

  /// Séances inventées pour la semaine et le calendrier.
  static TypeSeance? _seance(DateTime j) {
    if (j.isAfter(_auj)) return null;
    if (j.month == 10) return j.day == 1 ? TypeSeance.musculation : null;
    if (j.month != 9) return null;
    if (const {9, 16, 29}.contains(j.day)) return TypeSeance.cardio;
    if (const {1, 4, 7, 8, 10, 14, 15, 21, 22, 26, 28}.contains(j.day)) return TypeSeance.musculation;
    return null;
  }

  void _panneauType() => showPanneauBas<TypeSeance>(
        context,
        titre: 'Type d\'activité',
        builder: (context) => Column(
          children: [
            for (final t in TypeSeance.values)
              ChoixPanneau(
                icone: IconeTypeSeance(t),
                label: t.label,
                selected: t == _type,
                onTap: () {
                  setState(() => _type = t);
                  Navigator.pop(context, t);
                },
              ),
          ],
        ),
      );

  void _panneauActions() => showPanneauBas<void>(
        context,
        titre: 'PECS / TRICEPS',
        builder: (context) => Column(
          children: [
            LigneAction(icone: const Icon(Icons.edit_outlined), label: 'Modifier', onTap: () => Navigator.pop(context)),
            LigneAction(icone: const Icon(Icons.copy_rounded), label: 'Dupliquer', onTap: () => Navigator.pop(context)),
            LigneAction(icone: const Icon(Icons.delete_outline_rounded), label: 'Supprimer', destructif: true, onTap: () => Navigator.pop(context)),
          ],
        ),
      );

  void _panneauDuree() => showPanneauBas<void>(
        context,
        titre: 'Durée',
        builder: (context) => StatefulBuilder(
          builder: (context, maj) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoueDuree(
                value: _duree,
                onChanged: (d) {
                  setState(() => _duree = d);
                  maj(() {});
                },
              ),
              const SizedBox(height: 14),
              BoutonPrincipal(label: 'Terminé', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    final accent = context.watch<AccentController>();

    const pad = EdgeInsets.symmetric(horizontal: AppTokens.gutter);
    Widget padded(Widget child) => Padding(padding: pad, child: child);

    Widget corps(Muscle m, {BodyView vue = BodyView.front}) =>
        BodyMap(view: vue, intensities: {m: 1}, height: 88);

    return SubPageScaffold(
      title: 'Composants',
      actions: [
        IconButton(tooltip: 'Rechercher', onPressed: () {}, icon: const Icon(Icons.search_rounded)),
        IconButton(tooltip: 'Ajouter', onPressed: () {}, icon: const Icon(Icons.add_rounded)),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // Design du 2 octobre : les composants de la nouvelle maquette.
          const SectionHeader(title: 'Résumé mensuel'),
          padded(CarteResumeMensuel(mois: 'septembre 2026', onTap: () {})),

          const SectionHeader(title: 'Semaine'),
          AppCard(
            margin: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cette semaine', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SemaineJours(jours: SemaineJours.semaineDe(_auj), seance: _seance, aujourdhui: _auj, onJour: (_) {}),
              ],
            ),
          ),

          const SectionHeader(title: 'Mois'),
          AppCard(
            margin: pad,
            child: GrilleMois(mois: DateTime(2026, 9), seance: _seance, aujourdhui: _auj, onJour: (_) {}),
          ),

          const SectionHeader(title: 'Types de séance et icônes'),
          padded(
            Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final ty in TypeSeance.values) PastilleTypeSeance(ty),
                const IconeHaltere(size: 26),
                const IconeCoeur(size: 26),
                for (final i in [AppIcone.accueil, AppIcone.progres, AppIcone.profil, AppIcone.coche]) TraitIcone(i, size: 26),
              ],
            ),
          ),

          const SectionHeader(title: 'Boutons'),
          padded(
            Column(
              children: [
                BoutonPrincipal(label: 'Lancer la séance', onPressed: () {}),
                const SizedBox(height: 10),
                BoutonSecondaire(label: 'Ajouter un exercice', icone: const Icon(Icons.add_rounded), onPressed: () {}),
                const SizedBox(height: 10),
                BoutonDestructif(label: 'Abandonner la séance', onPressed: () {}),
              ],
            ),
          ),

          const SectionHeader(title: 'Sélecteur segmenté et pastilles'),
          padded(
            SelecteurSegmente<String>(
              segments: const [('kg', 'Kilos'), ('lb', 'Livres')],
              value: _unite,
              onChanged: (v) => setState(() => _unite = v),
            ),
          ),
          const SizedBox(height: 12),
          padded(
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pastille('65 min'),
                Pastille('Récupéré', ton: TonPastille.ok),
                Pastille('Fatigué', ton: TonPastille.alerte),
                Pastille('Pectoraux', ton: TonPastille.musclePlein),
                Pastille('Triceps', ton: TonPastille.muscle),
                Pastille('92 %', ton: TonPastille.ok, grande: true),
              ],
            ),
          ),

          const SectionHeader(title: 'Panneaux du bas'),
          padded(
            Row(
              children: [
                Expanded(child: BoutonSecondaire(label: 'Type', petit: true, onPressed: _panneauType)),
                const SizedBox(width: 8),
                Expanded(child: BoutonSecondaire(label: 'Actions', petit: true, onPressed: _panneauActions)),
                const SizedBox(width: 8),
                Expanded(child: BoutonSecondaire(label: 'Durée', petit: true, onPressed: _panneauDuree)),
              ],
            ),
          ),

          const SectionHeader(title: 'Roues'),
          padded(RoueMinSec(value: _repos, onChanged: (d) => setState(() => _repos = d))),
          const SizedBox(height: 12),
          AppCard(
            margin: pad,
            color: c.surface2,
            child: RoueDuree(value: _duree, onChanged: (d) => setState(() => _duree = d)),
          ),

          const SectionHeader(title: 'Objet 3D'),
          padded(const Objet3D(asset: Objets3D.baleine, multiple: 2)),
          const SizedBox(height: 8),
          padded(const Objet3D(asset: Objets3D.chat, multiple: 80, halo: Color(0xFFFFB347), hauteur: 220)),

          const SectionHeader(title: 'Anciens composants'),
          // Séance en cours.
          padded(const StatBox(items: [('Durée', '0:00:54', AppTokens.domainTraining), ('Volume', '2 050 kg', null), ('Séries', '6', null)])),
          const SizedBox(height: 18),
          ListTileX(
            leading: const ExerciseThumbnail(),
            title: 'Développé couché',
            trailing: IconButton(onPressed: () {}, icon: Icon(Icons.more_horiz_rounded, color: c.accent)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 2, AppTokens.gutter, 6),
            child: Text('Ajouter une note...', style: AppType.rowSubtitle(color: c.text2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(alignment: Alignment.centerLeft, child: AccentLink(label: 'Repos : 2 min', icon: Icons.timer_outlined, onTap: () {})),
          ),
          const SetTableHeader(),
          for (var i = 0; i < 3; i++)
            SetRow(
              label: '${i + 1}',
              previous: i == 0 ? '40 kg x 10' : '60 kg x 10',
              weight: i == 0 ? '40' : '60',
              reps: '10',
              hint: i == 2,
              done: _faites.contains(i),
              onToggle: () => setState(() => _faites.contains(i) ? _faites.remove(i) : _faites.add(i)),
            ),
          const SizedBox(height: 10),
          padded(PillButton.secondary(label: 'Ajouter une série', icon: Icons.add_rounded, size: PillSize.small, expand: true, onPressed: () {})),
          const SizedBox(height: 10),
          const ListTileX(leading: ExerciseThumbnail(), title: 'Développé incliné', subtitle: '0/3 faites'),
          const ListTileX(leading: ExerciseThumbnail(), title: 'Développé militaire debout', subtitle: '0/3 faites'),

          // Programmes.
          const SizedBox(height: 16),
          padded(const SearchField(hint: 'Rechercher un programme')),
          const SizedBox(height: 6),
          IconTabBar<String>(
            value: _onglet,
            onChanged: (v) => setState(() => _onglet = v),
            tabs: const [
              IconTab('programmes', 'Programmes', Icons.calendar_today_outlined),
              IconTab('exercices', 'Exercices', Icons.fitness_center_rounded),
              IconTab('coachs', 'Coachs', Icons.person_outline_rounded),
            ],
          ),

          // Filtres par muscle et grille d'exercices.
          const SizedBox(height: 12),
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: pad,
              children: [
                SizedBox(width: 40, child: Icon(Icons.bookmark_border_rounded, color: c.text, size: 28)),
                for (final (i, m) in [Muscle.pectoraux, Muscle.deltoidesAnterieurs, Muscle.biceps, Muscle.abdominaux, Muscle.quadriceps].indexed)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SelectSquare(
                      selected: _silhouette == i,
                      onTap: () => setState(() => _silhouette = i),
                      child: BodyMap(intensities: {m: 1}, height: 56),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Tous les exercices',
            padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 12, 4, 8),
            trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.format_list_bulleted_rounded)),
          ),
          padded(
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: ExerciseCard.gridDelegate,
              children: [
                for (final (nom, muscle) in [('Développé couché', 'Pectoraux'), ('Butterfly', 'Pectoraux')])
                  ExerciseCard(
                    title: nom,
                    subtitle: muscle,
                    image: BodyMap(intensities: const {Muscle.pectoraux: 1}),
                    bookmarked: _favoris.contains(nom),
                    onBookmark: () => setState(() => _favoris.contains(nom) ? _favoris.remove(nom) : _favoris.add(nom)),
                    onHelp: () {},
                    onTap: () {},
                  ),
              ],
            ),
          ),

          // Zones ciblées.
          const SectionHeader(title: 'Zones ciblées'),
          padded(
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 18,
              spacing: 8,
              children: [
                for (final (id, nom, m, vue) in [
                  ('bras', 'Bras', Muscle.biceps, BodyView.front),
                  ('pecs', 'Poitrine', Muscle.pectoraux, BodyView.front),
                  ('dos', 'Dos', Muscle.grandDorsal, BodyView.back),
                  ('abdos', 'Abdos', Muscle.abdominaux, BodyView.front),
                  ('jambes', 'Jambes', Muscle.quadriceps, BodyView.front),
                  ('fessiers', 'Fessiers', Muscle.fessiers, BodyView.back),
                ])
                  SelectCircle(
                    label: nom,
                    selected: _zones.contains(id),
                    onTap: () => setState(() => _zones.contains(id) ? _zones.remove(id) : _zones.add(id)),
                    child: corps(m, vue: vue),
                  ),
              ],
            ),
          ),

          // Progrès.
          const SectionHeader(title: 'Progrès', large: true),
          padded(
            BigNumber(
              label: 'Volume',
              value: '197 248',
              unit: 'kg',
              caption: '29 juin 2025 - 20 sept. 2025',
            ),
          ),
          const SizedBox(height: 18),
          padded(const SimpleBarChart(values: [16000, 18500, 23000, 17000, 22500, 26000, 28000, 32500, 39500, 45000, 41000, 47500])),
          const SizedBox(height: 20),
          padded(const WeekDots(days: [('Dim', true), ('Lun', true), ('Mar', true), ('Mer', true), ('Jeu', false), ('Ven', true), ('Sam', true)])),

          // Répartition par muscle.
          const SectionHeader(title: 'Muscles principaux', large: true),
          MuscleBar(
            large: true,
            name: 'Grand dorsal',
            value: 1,
            valueLabel: '4 080kg',
            secondary: 1,
            secondaryLabel: '6 séries',
            leading: BodyMap(view: BodyView.back, intensities: const {Muscle.grandDorsal: 1}),
          ),
          MuscleBar(
            name: 'Deltoïdes postérieurs',
            value: 0.3,
            valueLabel: '1 246kg',
            secondary: 0.5,
            secondaryLabel: '3 séries',
            leading: BodyMap(view: BodyView.back, intensities: const {Muscle.deltoidesPosterieurs: 1}),
          ),

          const SectionHeader(title: 'Accent'),
          padded(
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                for (final a in AccentChoice.values)
                  GestureDetector(
                    onTap: () => accent.set(a),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: a.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.choice == a ? c.text : Colors.transparent, width: 2.5),
                          ),
                          child: accent.choice == a ? Icon(Icons.check_rounded, color: a.onColor) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(a.label, style: t.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SectionHeader(title: 'Boutons'),
          padded(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(label: 'Terminer', onPressed: () {}),
                const PillButton(label: 'Terminer', onPressed: null),
                PillButton.secondary(label: 'Secondaire', onPressed: () {}),
                PillButton.link(label: 'Voir tout', onPressed: () {}),
                PillButton(label: 'Contour', variant: PillVariant.outline, onPressed: () {}),
                PillButton.ghost(label: 'Texte', onPressed: () {}),
                PillButton(label: 'Supprimer', variant: PillVariant.danger, icon: Icons.delete_outline_rounded, onPressed: () {}),
                PillButton(label: 'Chargement', loading: true, onPressed: () {}),
                RoundIconButton(icon: Icons.add_rounded, onPressed: () {}),
                RoundIconButton(icon: Icons.search_rounded, filled: false, onPressed: () {}),
              ],
            ),
          ),

          const SectionHeader(title: 'Sélecteurs'),
          padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthSelector(month: _mois, onChanged: (m) => setState(() => _mois = m)),
                const SizedBox(height: 10),
                SegmentedChips<String>(
                  segments: const [('1m', '1 mois'), ('3m', '3 mois'), ('1a', '1 an')],
                  value: _periode,
                  onChanged: (v) => setState(() => _periode = v),
                ),
                const SizedBox(height: 10),
                SegmentedControl<String>(
                  segments: const [('seances', 'Séances'), ('muscles', 'Muscles'), ('records', 'Records')],
                  value: _vue,
                  onChanged: (v) => setState(() => _vue = v),
                ),
                const SizedBox(height: 12),
                ChipFilterBar<String>(
                  padding: EdgeInsets.zero,
                  allLabel: 'Tout',
                  multi: true,
                  options: const [('Poitrine', 'Poitrine'), ('Dos', 'Dos'), ('Jambes', 'Jambes'), ('Épaules', 'Épaules')],
                  selected: _filtres,
                  onChanged: (v) => setState(() => _filtres = v),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Lignes et cartes'),
          TileGroup(
            label: 'Réglages',
            children: [
              ListTileX(leading: IconHalo(icon: Icons.timer_outlined, color: c.accent, size: 38), title: 'Repos par défaut', value: '2 min', showChevron: true, onTap: () {}),
              ListTileX(
                leading: IconHalo.domain(AppDomain.sommeil, size: 38),
                title: 'Sommeil',
                subtitle: '7 h 32 cette nuit',
                trailing: const TagPill('Record', icon: Icons.emoji_events_rounded),
              ),
              ListTileX(
                leading: const IconHalo(icon: Icons.notifications_none_rounded, size: 38),
                title: 'Rappels',
                trailing: Switch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          padded(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatTile(label: 'Calories', value: '1 840', caption: 'restantes sur 2 600', footer: const ProgressBar(value: 0.7)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    label: 'Protéines',
                    child: Center(child: ProgressRing(value: 0.72, size: 84, center: Text('72 %', style: AppType.number(17)))),
                  ),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Saisie'),
          padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TextField(decoration: InputDecoration(labelText: 'Prénom')),
                const SizedBox(height: 16),
                Center(
                  child: NumberStepper(label: 'Poids', value: _poids, step: 2.5, decimals: 1, unit: 'kg', onChanged: (v) => setState(() => _poids = v)),
                ),
                Slider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
              ],
            ),
          ),

          const SectionHeader(title: 'Dialogues et messages'),
          padded(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton.secondary(
                  label: 'Confirmer',
                  size: PillSize.small,
                  onPressed: () => showConfirmDialog(context, title: 'Abandonner la séance ?', message: 'Les séries déjà faites seront perdues.', confirmLabel: 'Abandonner', destructive: true),
                ),
                PillButton.secondary(label: 'Texte', size: PillSize.small, onPressed: () => showTextInputDialog(context, title: 'Nom de la routine', initial: 'Push')),
                PillButton.secondary(label: 'Nombre', size: PillSize.small, onPressed: () => showNumberInputDialog(context, title: 'Poids', initial: 77.5, unit: 'kg')),
                PillButton.secondary(
                  label: 'Choix',
                  size: PillSize.small,
                  onPressed: () => showChoiceDialog(context, title: 'Repos', options: const [(60, '1 min'), (90, '1 min 30'), (120, '2 min')], selected: 90),
                ),
                PillButton.secondary(label: 'Message', size: PillSize.small, onPressed: () => Toasts.success(context, 'Séance enregistrée')),
              ],
            ),
          ),

          const SectionHeader(title: 'Typographie et marque'),
          padded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Titre d\'écran', style: AppType.screenTitle().copyWith(fontSize: 22)),
                Text('Titre de section', style: t.titleLarge),
                Text('Texte courant, lisible et sobre.', style: t.bodyMedium),
                Text('Texte secondaire', style: t.bodySmall),
                const SizedBox(height: 12),
                const Row(children: [AppLogo(size: 48), SizedBox(width: 14), AppWordmark(), Spacer(), UserAvatar(size: 40, name: 'Tristan')]),
              ],
            ),
          ),

          const SectionHeader(title: 'État vide'),
          AppCard(
            margin: pad,
            child: EmptyState(
              compact: true,
              icon: Icons.fitness_center_rounded,
              title: 'Aucune routine',
              message: 'Crée ta première routine pour démarrer une séance en un geste.',
              actionLabel: 'Créer une routine',
              onAction: () {},
            ),
          ),

          const SectionHeader(title: 'Barre du bas'),
          AppBottomNav(currentIndex: _nav, onTap: (i) => setState(() => _nav = i)),
        ],
      ),
    );
  }
}
