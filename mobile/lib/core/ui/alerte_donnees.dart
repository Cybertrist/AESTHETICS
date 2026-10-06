import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';

/// Un fichier de données que l'appli n'a pas pu relire au démarrage.
class FichierAbime {
  const FichierAbime(this.nom, this.copie);

  /// Nom de la collection (« seances », « routines »...).
  final String nom;

  /// Chemin de la copie de secours ; vide s'il n'y en a pas (fichier
  /// impossible à ouvrir, ou dépôt qui a échoué en se chargeant).
  final String copie;

  /// Ce que le fichier contient, dit simplement.
  String get libelle => _libelles[nom] ?? '« $nom »';

  static const _libelles = {
    'profil': 'ton profil',
    'reglages': 'tes réglages',
    'seances': 'tes séances',
    'seance_active': 'la séance en cours',
    'routines': 'tes routines',
    'dossiers': 'tes dossiers de routines',
    'programmes': 'tes programmes',
    'exercices': 'tes exercices',
    'exercices_perso': 'tes exercices personnels',
    'exercices_favoris': 'tes exercices favoris',
    'mesures': 'tes mensurations',
    'photos': 'tes photos de progression',
    'sommeil': 'ton sommeil',
    'sante': 'tes données de santé',
    'nutrition': 'ta nutrition',
    'coach': 'tes échanges avec le coach',
  };
}

/// Fichiers trouvés illisibles depuis l'ouverture ([Store.abimes]) et dépôts
/// qui n'ont pas pu se charger ([AppData.erreursChargement]). Liste vide
/// quand tout a été lu.
List<FichierAbime> fichiersAbimes(Store store, [AppData? data]) => [
      for (final e in store.abimes.entries) FichierAbime(e.key, e.value),
      if (data != null)
        for (final nom in data.erreursChargement.keys)
          if (!store.abimes.containsKey(nom)) FichierAbime(nom, ''),
    ];

/// « mesures.json.abime » : le nom du fichier, sans son dossier.
String _nomFichier(String chemin) => chemin.split(RegExp(r'[\\/]')).last;

String _dossier(String chemin) {
  final i = chemin.lastIndexOf(RegExp(r'[\\/]'));
  return i <= 0 ? '' : chemin.substring(0, i);
}

/// Carte d'alerte : dit quelles données n'ont pas pu être relues, que rien
/// n'a été effacé, et où se trouve la copie de secours.
class AlerteDonnees extends StatelessWidget {
  const AlerteDonnees({super.key, required this.fichiers, this.onFermer});

  final List<FichierAbime> fichiers;

  /// « Compris » : referme l'alerte (absent : pas de bouton).
  final VoidCallback? onFermer;

  static String _liste(List<String> mots) {
    if (mots.length <= 1) return mots.join();
    return '${mots.sublist(0, mots.length - 1).join(', ')} et ${mots.last}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    TextStyle txt(double taille, FontWeight poids, Color couleur) =>
        TextStyle(fontFamily: AppTokens.fontUi, fontSize: taille, height: 1.4, fontWeight: poids, color: couleur);
    final copies = [
      for (final f in fichiers)
        if (f.copie.isNotEmpty) f.copie,
    ];
    final dossiers = {for (final p in copies) _dossier(p)}..remove('');
    final quoi = _liste([for (final f in fichiers) f.libelle]);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.error.withValues(alpha: 0.55)),
        ),
        padding: const EdgeInsets.fromLTRB(17.5, 16, 17.5, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                  child: Icon(Icons.priority_high_rounded, color: c.text, size: 22),
                ),
                const SizedBox(width: 12.5),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      fichiers.length > 1 ? 'Des fichiers de données sont abîmés' : 'Un fichier de données est abîmé',
                      style: txt(17.5, FontWeight.w700, c.text),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'L\'appli n\'a pas pu relire $quoi et a démarré sans. Rien n\'a été effacé.',
              style: txt(15, FontWeight.w400, c.text2),
            ),
            const SizedBox(height: 8),
            if (copies.isEmpty)
              Text(
                'Aucune copie de secours n\'a pu être faite. Si tu as une sauvegarde, tu peux la restaurer dans Profil, Réglages, Mes données.',
                style: txt(15, FontWeight.w400, c.text2),
              )
            else ...[
              Text(
                copies.length > 1 ? 'Les copies de secours sont gardées ici :' : 'La copie de secours est gardée ici :',
                style: txt(15, FontWeight.w400, c.text2),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: SelectableText(
                  [
                    for (final p in copies) _nomFichier(p),
                    for (final d in dossiers) 'Dossier : $d',
                  ].join('\n'),
                  style: txt(13.5, FontWeight.w500, c.text),
                ),
              ),
            ],
            if (onFermer != null) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: 'Compris',
                excludeSemantics: true,
                child: Material(
                  color: c.surface2,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onFermer,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: Text('Compris', style: txt(15.5, FontWeight.w700, c.text).copyWith(height: 1.2)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
