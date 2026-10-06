import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../data/coach_prefs.dart';
import 'coach_snapshot.dart';

/// Résumé des données envoyé au coach, selon ce qu'il a le droit de lire.
abstract final class CoachContext {
  static String build(CoachSnapshot s, CoachPrefs prefs) {
    final b = StringBuffer();
    b.writeln('Aujourd\'hui : ${Fmt.jour(s.now)}, ${Fmt.heure(s.now)}.');
    final u = s.user;
    final unite = s.unite;
    String poids(double? kg) => Fmt.poids(kg, unite);

    if (prefs.peut(CoachPartage.profil) && u != null) {
      b.writeln();
      b.writeln('## Profil');
      b.writeln([
        if (u.prenom.trim().isNotEmpty) 'Prénom : ${u.prenom.trim()}',
        'Sexe : ${u.sexe.label}',
        if (u.age != null) 'Âge : ${u.age} ans',
        if (u.tailleCm != null) 'Taille : ${Fmt.n(u.tailleCm, decimals: 0)} cm',
        if (s.poids != null) 'Poids : ${poids(s.poids)}',
        if (u.poidsCibleKg != null) 'Poids visé : ${poids(u.poidsCibleKg)}',
      ].join(', '));
      b.writeln('Objectif : ${u.objectif.label} (${u.objectif.description}). Niveau : ${u.niveau.label}. '
          'Activité hors sport : ${u.activite.label}.');
      b.writeln('Disponibilité : ${u.joursParSemaine} séances par semaine, ${u.dureeSeanceMin} minutes par séance.');
      if (u.materiel.isNotEmpty) b.writeln('Matériel : ${u.materiel.map((m) => m.label).join(', ')}.');
      b.writeln('Unité de poids : ${unite.label}.');
    }

    final depuis = s.today.subtract(Duration(days: prefs.periodeJours));
    if (prefs.peut(CoachPartage.seances)) {
      final list = s.sessionsSince(depuis);
      b.writeln();
      b.writeln('## Séances des ${prefs.periodeJours} derniers jours');
      if (list.isEmpty) {
        b.writeln('Aucune séance enregistrée sur la période.');
      } else {
        b.writeln('${list.length} séances, ${s.semaine.length} cette semaine (objectif ${s.objectifSemaine}), '
            '${s.sessionsRepo.streakWeeks(now: s.now)} semaines d\'affilée avec au moins une séance.');
        for (final x in list.take(14)) {
          b.writeln('- ${Fmt.dateCourte(x.debut)} ${x.nom} (${Fmt.duree(x.duree)}${x.ressenti == null ? '' : ', ressenti ${x.ressenti}/5'}) :');
          for (final e in x.exercices) {
            final faites = e.seriesFaites.where((z) => z.type.counts).toList();
            if (faites.isEmpty) continue;
            final series = faites.map((z) {
              final p = (z.poids ?? 0) > 0 ? ' x ${Fmt.n(Fmt.poidsAffiche(z.poids!, unite))}' : '';
              if (z.reps != null) return '${z.reps}$p${z.rpe == null ? '' : ' RPE ${Fmt.n(z.rpe)}'}';
              if (z.dureeSec != null) return '${z.dureeSec} s';
              return 'fait';
            }).join(', ');
            b.writeln('  ${s.exercises.nameOf(e.exerciseId)} : $series');
          }
        }
        if (list.length > 14) b.writeln('(et ${list.length - 14} séances plus anciennes)');
      }
    }

    if (prefs.peut(CoachPartage.routines)) {
      final routines = s.routines.routines;
      b.writeln();
      b.writeln('## Routines enregistrées');
      if (routines.isEmpty) {
        b.writeln('Aucune routine.');
      } else {
        for (final r in routines.take(12)) {
          final ex = r.exercices.map((e) {
            final set = e.series.where((p) => p.type.counts).toList();
            final charge = set.isNotEmpty && set.first.poids != null ? ' @ ${poids(set.first.poids)}' : '';
            final reps = set.isNotEmpty && set.first.repsLabel.isNotEmpty ? ' x ${set.first.repsLabel}' : '';
            return '${s.exercises.nameOf(e.exerciseId)} ${set.length}$reps$charge';
          }).join(' ; ');
          b.writeln('- ${r.nom} : $ex');
        }
      }
      final p = s.programs.active;
      if (p != null) {
        b.writeln('Programme actif : ${p.nom}, semaine ${p.semaineCourante} sur ${p.dureeSemaines}, '
            '${p.seancesFaites} séances faites sur ${p.seancesTotal}.');
      }
    }

    if (prefs.peut(CoachPartage.records)) {
      final ids = s.sessionsRepo.recentExerciseIds(limit: 12);
      final lignes = <String>[];
      for (final id in ids) {
        final best = s.sessionsRepo.bestsFor(id);
        if (best.isEmpty) continue;
        final parts = [
          if (best.poidsMax != null) 'charge max ${poids(best.poidsMax!.valeur)} (${Fmt.dateCourte(best.poidsMax!.date)})',
          if (best.unRm != null) '1RM estimé ${poids(best.unRm!.valeur)}',
          if (best.repsMax != null && best.poidsMax == null) '${best.repsMax!.valeur.round()} répétitions max',
        ];
        if (parts.isNotEmpty) lignes.add('- ${s.exercises.nameOf(id)} : ${parts.join(', ')}');
      }
      final tendances = s.tendances;
      if (lignes.isNotEmpty || tendances.isNotEmpty) {
        b.writeln();
        b.writeln('## Records et tendances');
        lignes.forEach(b.writeln);
        for (final t in tendances) {
          b.writeln('- Tendance ${t.exercice.nom} : 1RM estimé ${poids(t.avant)} il y a 3 à 8 semaines, ${poids(t.recent)} ces 3 dernières semaines'
              '${t.stagne ? ' (plateau)' : ''}.');
        }
      }
    }

    if (prefs.peut(CoachPartage.recuperation) && s.sessions.isNotEmpty) {
      b.writeln();
      b.writeln('## Récupération estimée');
      final fat = s.fatigue.entries.where((e) => e.value > 0.05).toList()..sort((a, c) => c.value.compareTo(a.value));
      if (fat.isEmpty) {
        b.writeln('Tous les muscles sont récupérés.');
      } else {
        b.writeln(fat.map((e) => '${e.key.label} ${((1 - e.value) * 100).round()} %').join(', '));
        b.writeln('(100 % = entièrement récupéré ; les muscles absents sont à 100 %.)');
      }
      if (s.derniere != null) b.writeln('Dernière séance : ${Fmt.relatif(s.derniere!.debut, now: s.now).toLowerCase()} (${s.derniere!.nom}).');
    }

    if (prefs.peut(CoachPartage.nutrition)) {
      final o = s.objectifs;
      b.writeln();
      b.writeln('## Nutrition');
      b.writeln('Objectifs : ${Fmt.kcal(o.kcal)}, protéines ${Fmt.n(o.proteinesG, decimals: 0)} g, glucides ${Fmt.n(o.glucidesG, decimals: 0)} g, '
          'lipides ${Fmt.n(o.lipidesG, decimals: 0)} g, eau ${Fmt.n(o.eauMl / 1000, decimals: 1)} L.');
      final moy = s.moyenneNutrition;
      if (moy == null) {
        b.writeln('Aucun repas enregistré ces 7 derniers jours.');
      } else {
        b.writeln('Moyenne sur ${s.joursNutritionRenseignes} jours renseignés : ${Fmt.kcal(moy.kcal)}, protéines ${Fmt.n(moy.proteines, decimals: 0)} g, '
            'glucides ${Fmt.n(moy.glucides, decimals: 0)} g, lipides ${Fmt.n(moy.lipides, decimals: 0)} g.');
      }
      final a = s.aujourdhui;
      b.writeln(a.renseigne
          ? 'Aujourd\'hui pour l\'instant : ${Fmt.kcal(a.macros.kcal)}, protéines ${Fmt.n(a.macros.proteines, decimals: 0)} g, eau ${Fmt.n(a.eauMl / 1000, decimals: 1)} L.'
          : 'Rien de noté aujourd\'hui${a.eauMl > 0 ? ' (eau ${Fmt.n(a.eauMl / 1000, decimals: 1)} L)' : ''}.');
    }

    if (prefs.peut(CoachPartage.sommeil)) {
      final nuits = s.health.sleep.take(7).toList();
      b.writeln();
      b.writeln('## Sommeil');
      if (nuits.isEmpty) {
        b.writeln('Aucune nuit enregistrée.');
      } else {
        final moy = s.sommeilMoyen;
        if (moy != null) b.writeln('Moyenne sur 7 jours : ${Fmt.sommeil(moy)}.');
        b.writeln(nuits
            .map((n) => '${Fmt.dateCourte(n.lever)} ${Fmt.sommeil(n.duree)}${n.qualite == null ? '' : ' (qualité ${n.qualite}/5)'}')
            .join(', '));
      }
    }

    if (prefs.peut(CoachPartage.mesures)) {
      final m = s.health.measurements;
      b.writeln();
      b.writeln('## Poids et mensurations');
      if (m.isEmpty) {
        b.writeln('Aucune mesure enregistrée.');
      } else {
        if (s.health.latestWeight != null) {
          b.writeln('Dernière pesée : ${poids(s.health.latestWeight)} (${Fmt.dateCourte(s.health.latestWeightEntry!.date)}).');
        }
        final v = s.variationPoids28j;
        if (v != null) b.writeln('Variation sur 4 semaines : ${v >= 0 ? 'plus' : 'moins'} ${poids(v.abs())}.');
        if (s.health.latestBodyFat != null) b.writeln('Masse grasse : ${Fmt.n(s.health.latestBodyFat)} %.');
        final tours = [
          for (final t in TourCorps.values)
            if (s.health.latestTour(t) != null) '${t.label} ${Fmt.n(s.health.latestTour(t))} cm',
        ];
        if (tours.isNotEmpty) b.writeln('Tours : ${tours.join(', ')}.');
      }
    }

    if (prefs.partage.isEmpty) {
      b.writeln();
      b.writeln('(L\'utilisateur n\'a partagé aucune donnée : réponds de façon générale.)');
    }
    return b.toString().trim();
  }
}

/// Consignes envoyées au modèle.
abstract final class CoachPrompt {
  static String system({required CoachSnapshot snapshot, required CoachPrefs prefs, required CoachTon ton}) {
    final contexte = CoachContext.build(snapshot, prefs);
    final tonTexte = switch (ton) {
      CoachTon.bienveillant => 'Ton bienveillant et encourageant, positif sans être mielleux.',
      CoachTon.direct => 'Ton direct et franc, phrases courtes, pas de politesses inutiles.',
      CoachTon.exigeant => 'Ton exigeant de préparateur physique : tu pousses à se dépasser et tu relèves les manques sans détour, toujours avec respect.',
      CoachTon.pedagogue => 'Ton pédagogue : tu expliques brièvement le pourquoi physiologique de chaque conseil.',
    };
    final longueur = prefs.longueur == CoachLongueur.courte
        ? 'Réponses courtes : l\'essentiel en 3 à 8 lignes, sauf si on te demande un programme ou un bilan.'
        : 'Réponses détaillées avec explications et exemples, bien structurées.';
    return '''
Tu es le coach de l'application Aesthetics, une appli personnelle de musculation, nutrition et sommeil. Tu t'adresses à l'utilisateur en le tutoyant, en français.
$tonTexte
$longueur

Règles d'écriture :
- Markdown léger : paragraphes courts, listes à puces, **gras** pour l'essentiel, titres de niveau 3 au plus. Pas de tableaux.
- N'utilise jamais de tiret long ni de tiret moyen : des virgules, des deux-points ou des parenthèses à la place.
- Chiffres concrets tirés des données ci-dessous quand c'est pertinent (charges, séries, grammes). Unité de poids de l'utilisateur.
- Ne cite aucune autre application de suivi sportif.
- Pas de diagnostic médical : en cas de douleur vive, de blessure ou de symptôme inquiétant, conseille de consulter un professionnel.
- Si une donnée manque, dis-le simplement et propose de l'enregistrer dans l'appli.

Actions : quand tu proposes quelque chose que l'appli peut appliquer, ajoute à la toute fin de ta réponse un ou plusieurs blocs de code de langage "action" contenant un objet JSON, un par action. L'utilisateur les valide d'un geste. N'en mets que si c'est utile et demandé ou clairement bénéfique. Formats :
```action
{"type": "routine", "nom": "Jambes 45 min", "notes": "facultatif", "exercices": [{"nom": "Squat barre", "series": 4, "reps": 6, "repsMax": 8, "poids": 80, "repos": 150, "muscles": ["quadriceps", "fessiers"]}]}
```
```action
{"type": "charge", "exercice": "Développé couché", "poids": 82.5, "reps": 8, "routine": "Push (facultatif)"}
```
```action
{"type": "repas", "nom": "Skyr et flocons d'avoine", "repas": "collation", "quantite": 250, "kcal": 320, "proteines": 28, "glucides": 40, "lipides": 5}
```
Précisions : noms d'exercices en français usuel de salle (Développé couché, Tirage vertical, Squat barre, Soulevé de terre roumain...), en reprenant de préférence ceux des séances et routines ci-dessous. "poids" en ${snapshot.unite.label} (facultatif, laisse-le de côté si tu ne sais pas), "repos" en secondes, "repas" parmi petitDejeuner, dejeuner, collation, diner. "muscles" (facultatif) parmi : ${Muscle.values.map((m) => m.name).join(', ')}. Mentionne l'action dans ton texte (par exemple « je te propose de l'ajouter ci-dessous »), sans recopier le JSON.

Données de l'utilisateur, tirées de l'appli (à jour) :
<donnees>
$contexte
</donnees>
''';
  }

  static String phraseDuJour(CoachSnapshot s) =>
      'Écris la phrase du jour pour mon écran d\'accueil : une seule phrase de 20 mots au plus, concrète et personnelle, '
      'tirée de mes données (récupération, régularité, progression, nutrition ou sommeil du moment). '
      'Pas de guillemets, pas d\'emoji, pas de bloc action, rien d\'autre que la phrase.';

  static String bilan(String donnees) =>
      'Rédige le bilan de ma semaine à partir de ces chiffres :\n\n$donnees\n'
      'Structure : une phrase d\'ouverture, puis ### Ce qui va bien, ### À améliorer, ### Pour la semaine prochaine (3 objectifs concrets et chiffrés). '
      '15 lignes au plus, pas de bloc action.';
}
