import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../data/conversion.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';
import 'exercices_page.dart';

/// `/import/exercices/nouveau?nom=` : compléter un exercice perso créé à l'import.
class NouvelExercicePage extends StatefulWidget {
  const NouvelExercicePage({super.key, required this.nomSource});
  final String nomSource;

  @override
  State<NouvelExercicePage> createState() => _NouvelExercicePageState();
}

class _NouvelExercicePageState extends State<NouvelExercicePage> {
  final flow = ImportFlow.instance;
  late final TextEditingController _nom;
  late Set<Muscle> _muscles;
  late String _equipement;
  ExerciseTracking? _suivi;

  @override
  void initState() {
    super.initState();
    final d = flow.brouillon(widget.nomSource);
    _nom = TextEditingController(text: d.nom);
    _muscles = {...d.muscles};
    _equipement = d.equipement;
    _suivi = d.suivi;
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  void _enregistrer() {
    final d = PersoDraft(nom: _nom.text.trim().isEmpty ? widget.nomSource : _nom.text.trim(), muscles: _muscles, equipement: _equipement)
      ..suivi = _suivi;
    flow.creerPersonnel(widget.nomSource, d);
    Toasts.success(context, '« ${d.nom} » sera créé à l\'import');
    context.pop();
  }

  void _basculer(Muscle m) => setState(() => _muscles.contains(m) ? _muscles.remove(m) : _muscles.add(m));

  @override
  Widget build(BuildContext context) {
    final p = flow.preview;
    if (p == null) return const SansFichier(titre: 'Exercice perso');
    final r = p.rapprochements[cleNom(widget.nomSource)];
    final c = context.colors;
    final deja = r?.statut == StatutRapprochement.nouveau;

    final formulaire = <Widget>[
      padded(TextField(
        controller: _nom,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nom de l\'exercice',
          helperText: 'Dans le fichier : ${widget.nomSource}${r == null ? '' : ' · ${Fmt.pluriel(r.series, 'série')}'}',
        ),
      )),
      const SectionHeader(title: 'Matériel'),
      padded(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in Equipements.labels.entries)
            ChipFilter(label: e.value, selected: _equipement == e.key, onTap: () => setState(() => _equipement = e.key)),
        ],
      )),
      const SectionHeader(title: 'Façon de noter les séries'),
      padded(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in ExerciseTracking.values)
            ChipFilter(label: s.label, selected: _suivi == s, onTap: () => setState(() => _suivi = s)),
        ],
      )),
    ];

    final muscles = <Widget>[
      SectionHeader(
        title: 'Muscles travaillés',
        trailing: _muscles.isEmpty ? null : AccentLink(label: 'Effacer', onTap: () => setState(_muscles.clear)),
      ),
      padded(AppCard(
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, box) => BodyMapDual(
                selected: _muscles,
                onTap: _basculer,
                height: (box.maxWidth / 1.4).clamp(160, 300).toDouble(),
                labels: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('Touche un muscle sur le personnage ou dans la liste.', style: AppType.rowSubtitle()),
          ],
        ),
      )),
      const SizedBox(height: 12),
      padded(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in Muscle.values)
            ChipFilter(label: m.label, selected: _muscles.contains(m), onTap: () => _basculer(m)),
        ],
      )),
    ];

    return PageImport(
      title: 'Exercice perso',
      subtitle: widget.nomSource,
      closeIcon: true,
      bottomBar: Row(
        children: [
          Expanded(
            child: PillButton.secondary(
              label: 'Associer plutôt',
              onPressed: () => context.pushReplacement(lienChoisir(widget.nomSource)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: deja ? 'Enregistrer' : 'Créer',
              icon: Icons.check_rounded,
              onPressed: _enregistrer,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          padded(Encart(
            texte: 'L\'exercice sera ajouté à tes exercices personnels au moment de l\'import. Tu pourras le modifier ensuite.',
            action: deja
                ? PillButton.link(
                    label: 'Ne plus le créer',
                    onPressed: () {
                      flow.annulerChoix(widget.nomSource);
                      context.pop();
                    },
                  )
                : null,
          )),
          const SizedBox(height: 16),
          DeuxVolets(gauche: formulaire, droite: muscles, seuil: 760),
          if (_muscles.isEmpty) ...[
            const SizedBox(height: 12),
            padded(Text('Sans muscle, l\'exercice ne comptera pas dans la récupération ni la répartition.', style: AppType.rowSubtitle(color: c.warning))),
          ],
        ],
      ),
    );
  }
}
