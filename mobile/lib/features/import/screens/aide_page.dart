import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/import_flow.dart';
import '../logic/logic.dart';
import '../widgets/import_widgets.dart';

/// `/import/aide` : fichiers acceptés et conseils.
class AidePage extends StatelessWidget {
  const AidePage({super.key, this.depuisFichier = false});

  /// Ouvert depuis le choix du fichier : le bouton y revient.
  final bool depuisFichier;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget point(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.text3, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: AppType.rowSubtitle(color: c.text2).copyWith(fontSize: 14))),
            ],
          ),
        );

    return PageImport(
      title: 'Fichiers acceptés',
      bottomBar: PillButton(
        label: 'Choisir un fichier',
        icon: Icons.upload_file_rounded,
        expand: true,
        onPressed: () {
          if (depuisFichier && context.canPop()) {
            context.pop();
            return;
          }
          final f = ImportFlow.instance;
          if (!f.importEnCours) f.demarrer(f.source, retour: f.retour);
          context.pushReplacement('/import/fichier');
        },
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          padded(AppCard(
            label: 'Export d\'une autre application',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                point('Les exports CSV des applis de musculation les plus courantes sont reconnus tout seuls, en anglais comme en français.'),
                point('Séances, exercices, séries, charges, répétitions, durées, distances, RPE, notes, échauffements, séries dégressives et supersets sont repris.'),
                point('Les noms d\'exercices sont rapprochés du catalogue. Ceux qui restent flous te sont demandés une seule fois : tes choix sont retenus.'),
                point('Réimporter le même fichier ne crée pas de doublons : une séance qui commence à la même minute est ignorée.'),
              ],
            ),
          )),
          const SizedBox(height: 12),
          padded(AppCard(
            label: 'Tableau quelconque',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                point('Une ligne par série. Les séries d\'une même date et d\'un même nom de séance forment une séance.'),
                point('Séparateur virgule, point-virgule, tabulation ou barre verticale, détecté tout seul. Encodage UTF-8 ou Windows.'),
                point('Un classeur Excel doit d\'abord être enregistré au format CSV.'),
              ],
            ),
          )),
          SectionHeader(title: 'Colonnes possibles', trailing: LabelCount('* obligatoire')),
          TileGroup(
            children: [
              for (final ch in ChampImport.values)
                ListTileX(
                  dense: true,
                  title: ch.obligatoire ? '${ch.libelle} *' : ch.libelle,
                  subtitle: _exemple(ch),
                ),
            ],
          ),
          const SizedBox(height: 8),
          padded(Text('Il faut en plus au moins une charge, des répétitions, une durée ou une distance.', style: AppType.rowSubtitle())),
          const SectionHeader(title: 'Dates et unités'),
          padded(AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                point('Dates acceptées : 2026-09-30 18:30, 30/09/2026, 09/30/2026, 30 Sep 2026, 08:00. L\'ordre jour et mois est deviné, ou choisi à la main.'),
                point('Charges en kilos ou en livres : l\'unité est lue dans l\'en-tête (« Charge (kg) », « Weight (lbs) ») ou dans une colonne dédiée. Tout est enregistré en kilos.'),
                point('Durées en secondes, en « 1:05:00 » ou en « 1h 05min ». Distances en mètres ou en kilomètres selon l\'en-tête.'),
              ],
            ),
          )),
          const SectionHeader(title: 'Sauvegarde Aesthetics'),
          padded(AppCard(
            onTap: () => context.push('/import/sauvegarde'),
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: ListTileX(
              padding: ListTileX.cardPadding,
              leading: IconHalo(icon: Icons.backup_rounded),
              title: 'Un fichier .zip ou .json de l\'appli ?',
              subtitle: 'Il se restaure depuis la page Sauvegarde.',
              showChevron: true,
            ),
          )),
        ],
      ),
    );
  }

  static String _exemple(ChampImport c) => switch (c) {
        ChampImport.date => 'Date et heure de la séance',
        ChampImport.seance => 'Push, Jambes, Haut du corps…',
        ChampImport.exercice => 'Développé couché, Squat…',
        ChampImport.poids => 'Charge soulevée',
        ChampImport.unite => 'kg ou lb, ligne par ligne',
        ChampImport.reps => 'Nombre de répétitions',
        ChampImport.typeSerie => 'Échauffement, normale, dégressive, échec',
        ChampImport.dureeSeance => 'Durée totale de la séance',
        ChampImport.dureeSerie => 'Gainage, cardio',
        ChampImport.distance => 'Course, rameur, vélo',
        ChampImport.rpe => 'Effort ressenti de 1 à 10',
        ChampImport.rir => 'Répétitions en réserve',
        ChampImport.notes => 'Notes sur l\'exercice',
        ChampImport.notesSeance => 'Notes sur la séance',
      };
}
