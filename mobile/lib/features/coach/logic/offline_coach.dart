import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import 'coach_snapshot.dart';

enum ThemeConseil {
  recuperation('Récupération'),
  regularite('Régularité'),
  progression('Progression'),
  volume('Volume'),
  proteines('Protéines'),
  energie('Calories'),
  hydratation('Hydratation'),
  sommeil('Sommeil'),
  poids('Poids'),
  demarrage('Pour commencer');

  const ThemeConseil(this.label);
  final String label;
}

/// Conseil calculé sur le téléphone, sans service en ligne.
class CoachAdvice {
  const CoachAdvice({
    required this.id,
    required this.theme,
    required this.domain,
    required this.icon,
    required this.titre,
    required this.texte,
    required this.phrase,
    this.question,
    this.priorite = 1,
    this.positif = false,
  });

  final String id;
  final ThemeConseil theme;
  final AppDomain domain;
  final IconData icon;
  final String titre;
  final String texte;

  /// Version d'une phrase, pour la phrase du jour.
  final String phrase;

  /// Question à poser au coach pour creuser.
  final String? question;

  /// 0 à 3 : 3 = à voir en premier.
  final int priorite;
  final bool positif;
}

String _n(num v, [int d = 0]) => Fmt.n(v, decimals: d);

String _liste(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} et ${items.last}';
}

/// Règles simples : récupération, régularité, progression, protéines, sommeil.
abstract final class OfflineCoach {
  static List<CoachAdvice> advices(CoachSnapshot s) {
    final out = <CoachAdvice>[];
    _demarrage(s, out);
    _recuperation(s, out);
    _regularite(s, out);
    _progression(s, out);
    _volume(s, out);
    _proteines(s, out);
    _energie(s, out);
    _hydratation(s, out);
    _sommeil(s, out);
    _poids(s, out);
    out.sort((a, b) => b.priorite.compareTo(a.priorite));
    return out;
  }

  static void _demarrage(CoachSnapshot s, List<CoachAdvice> out) {
    if (s.sessions.isNotEmpty) return;
    out.add(const CoachAdvice(
      id: 'demarrage',
      theme: ThemeConseil.demarrage,
      domain: AppDomain.entrainement,
      icon: Icons.flag_rounded,
      titre: 'Enregistre ta première séance',
      texte: 'Je m\'appuie sur tes séances pour suivre ta récupération et ta progression. '
          'Lance une séance libre ou crée une routine depuis l\'onglet Entraînement, ou importe ton historique.',
      phrase: 'Le premier pas compte le plus : lance ta première séance aujourd\'hui.',
      question: 'Propose-moi une première routine adaptée à mon niveau.',
      priorite: 3,
    ));
  }

  static void _recuperation(CoachSnapshot s, List<CoachAdvice> out) {
    if (s.sessions.isEmpty) return;
    final fatigues = s.fatigues;
    if (fatigues.isNotEmpty) {
      final noms = fatigues.take(3).map((e) => e.key.label.toLowerCase()).toList();
      final pct = ((1 - fatigues.first.value) * 100).round();
      out.add(CoachAdvice(
        id: 'recup-fatigue',
        theme: ThemeConseil.recuperation,
        domain: AppDomain.coeur,
        icon: Icons.battery_2_bar_rounded,
        titre: 'À ménager : ${_liste(noms)}',
        texte: '${pct < 10 ? 'Récupération à peine entamée' : 'Récupération estimée à $pct %'} (${noms.first}). '
            'Si tu t\'entraînes aujourd\'hui, vise d\'autres groupes ou garde une séance légère sur ceux-là.',
        phrase: 'Récupération en cours (${noms.first}) : place à d\'autres muscles aujourd\'hui.',
        question: 'Que puis-je travailler aujourd\'hui vu ma récupération ?',
        priorite: 2,
      ));
    }
    // Grands groupes reposés et non travaillés depuis longtemps.
    final grands = [Muscle.pectoraux, Muscle.grandDorsal, Muscle.quadriceps, Muscle.ischios, Muscle.deltoidesLateraux, Muscle.fessiers];
    final oublies = <Muscle>[];
    for (final m in grands) {
      final dernier = _dernierTravail(s, m);
      if (dernier == null || s.today.difference(Dates.jour(dernier)).inDays >= 7) oublies.add(m);
    }
    if (oublies.isNotEmpty && s.sessions.length >= 3) {
      final noms = oublies.take(3).map((m) => m.label.toLowerCase()).toList();
      out.add(CoachAdvice(
        id: 'recup-prets',
        theme: ThemeConseil.recuperation,
        domain: AppDomain.entrainement,
        icon: Icons.bolt_rounded,
        titre: 'Prêts et oubliés : ${_liste(noms)}',
        texte: 'Ces muscles sont entièrement récupérés et n\'ont pas été travaillés depuis au moins une semaine. '
            'C\'est le bon moment pour les solliciter.',
        phrase: 'Reposé et oublié depuis une semaine : ${noms.first}. C\'est le moment.',
        question: 'Propose-moi une séance pour ${_liste(noms)}.',
        priorite: 1,
      ));
    }
  }

  static DateTime? _dernierTravail(CoachSnapshot s, Muscle m) {
    for (final session in s.sessions) {
      for (final e in session.exercices) {
        final ex = s.lookup(e.exerciseId);
        if (ex != null && ex.musclesPrincipaux.contains(m) && e.seriesFaites.isNotEmpty) return session.debut;
      }
    }
    return null;
  }

  static void _regularite(CoachSnapshot s, List<CoachAdvice> out) {
    if (s.sessions.isEmpty) return;
    final faites = s.semaine.length;
    final objectif = s.objectifSemaine;
    final jours = s.joursDepuisDerniere ?? 0;
    final streak = s.sessionsRepo.streakWeeks();
    if (jours >= 4) {
      out.add(CoachAdvice(
        id: 'regularite-pause',
        theme: ThemeConseil.regularite,
        domain: AppDomain.entrainement,
        icon: Icons.event_busy_rounded,
        titre: 'Dernière séance il y a $jours jours',
        texte: 'Une pause fait du bien, mais au-delà de quelques jours la régularité prime. '
            'Une séance courte de 30 minutes suffit à relancer la machine.',
        phrase: 'Ça fait $jours jours : une séance courte aujourd\'hui et c\'est reparti.',
        question: 'Propose-moi une séance de reprise de 30 minutes.',
        priorite: 3,
      ));
    } else if (faites >= objectif) {
      out.add(CoachAdvice(
        id: 'regularite-ok',
        theme: ThemeConseil.regularite,
        domain: AppDomain.entrainement,
        icon: Icons.verified_rounded,
        titre: 'Objectif de la semaine atteint',
        texte: '$faites séances sur $objectif prévues${streak > 1 ? ', et $streak semaines d\'affilée' : ''}. '
            'Le repos fait partie du programme.',
        phrase: 'Objectif de la semaine atteint${streak > 1 ? ', $streak semaines de suite' : ''}. Bravo.',
        priorite: 1,
        positif: true,
      ));
    } else {
      final reste = objectif - faites;
      final joursRestants = 7 - Dates.jour(s.now).difference(Dates.debutSemaine(s.now, premierJour: s.premierJour)).inDays;
      out.add(CoachAdvice(
        id: 'regularite-reste',
        theme: ThemeConseil.regularite,
        domain: AppDomain.entrainement,
        icon: Icons.calendar_month_rounded,
        titre: 'Encore ${Fmt.pluriel(reste, 'séance')} cette semaine',
        texte: '$faites sur $objectif pour l\'instant, il reste ${Fmt.pluriel(joursRestants, 'jour')}. '
            '${reste > joursRestants ? 'Difficile de tout caser : mieux vaut une séance de qualité que deux bâclées.' : 'C\'est jouable, garde le rythme.'}',
        phrase: 'Encore ${Fmt.pluriel(reste, 'séance')} pour boucler ta semaine.',
        priorite: reste > joursRestants ? 1 : 2,
      ));
    }
  }

  static void _progression(CoachSnapshot s, List<CoachAdvice> out) {
    final stagnes = s.tendances.where((t) => t.stagne).toList();
    final hausses = s.tendances.where((t) => t.variation >= 0.02).toList()..sort((a, b) => b.variation.compareTo(a.variation));
    if (stagnes.isNotEmpty) {
      final t = stagnes.first;
      out.add(CoachAdvice(
        id: 'progression-stagne-${t.exercice.id}',
        theme: ThemeConseil.progression,
        domain: AppDomain.entrainement,
        icon: Icons.trending_flat_rounded,
        titre: 'Plateau : ${t.exercice.nom}',
        texte: '1RM estimé à ${Fmt.poids(t.recent, s.unite)} sur trois semaines, pas mieux qu\'avant. '
            'Pistes : une semaine plus légère (moins 10 %), puis changer de plage de répétitions ou ajouter une variante.',
        phrase: 'Plateau sur « ${t.exercice.nom} » : une semaine plus légère peut tout débloquer.',
        question: 'Je stagne sur « ${t.exercice.nom} », que faire ?',
        priorite: 2,
      ));
    }
    if (hausses.isNotEmpty) {
      final t = hausses.first;
      out.add(CoachAdvice(
        id: 'progression-hausse-${t.exercice.id}',
        theme: ThemeConseil.progression,
        domain: AppDomain.entrainement,
        icon: Icons.trending_up_rounded,
        titre: '${t.exercice.nom} : plus ${_n(t.variation * 100)} %',
        texte: 'Ton 1RM estimé passe de ${Fmt.poids(t.avant, s.unite)} à ${Fmt.poids(t.recent, s.unite)} en quelques semaines. '
            'Continue d\'ajouter un peu de charge ou une répétition à chaque séance.',
        phrase: '${t.exercice.nom} en hausse de ${_n(t.variation * 100)} % : continue comme ça.',
        question: 'Comment continuer à progresser sur « ${t.exercice.nom} » ?',
        priorite: 1,
        positif: true,
      ));
    }
  }

  static void _volume(CoachSnapshot s, List<CoachAdvice> out) {
    if (s.sessions.length < 3 || s.semaine.isEmpty) return;
    final groupes = {
      'le dos': [Muscle.grandDorsal, Muscle.rhomboides],
      'les pectoraux': [Muscle.pectoraux],
      'les jambes': [Muscle.quadriceps, Muscle.ischios, Muscle.fessiers],
      'les épaules': [Muscle.deltoidesLateraux, Muscle.deltoidesAnterieurs, Muscle.deltoidesPosterieurs],
    };
    final faibles = <String>[];
    for (final g in groupes.entries) {
      final v = g.value.map((m) => s.seriesSemaine[m] ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
      if (v < 6) faibles.add(g.key);
    }
    if (faibles.isEmpty) return;
    out.add(CoachAdvice(
      id: 'volume-faible',
      theme: ThemeConseil.volume,
      domain: AppDomain.entrainement,
      icon: Icons.stacked_bar_chart_rounded,
      titre: 'Peu de séries pour ${_liste(faibles)}',
      texte: 'Moins de 6 séries effectives sur les 7 derniers jours. '
          'Pour progresser, vise 10 à 20 séries par semaine et par grand groupe musculaire.',
      phrase: 'Pense à ${faibles.first} cette semaine : peu de séries pour l\'instant.',
      question: 'Comment répartir mon volume pour ${_liste(faibles)} ?',
      priorite: 1,
    ));
  }

  static void _proteines(CoachSnapshot s, List<CoachAdvice> out) {
    final cible = s.objectifs.proteinesG;
    final moy = s.moyenneNutrition;
    if (moy == null || s.joursNutritionRenseignes < 2) return;
    final ratio = moy.proteines / cible;
    final parKg = s.poids == null ? null : moy.proteines / s.poids!;
    if (ratio < 0.85) {
      final manque = cible - moy.proteines;
      out.add(CoachAdvice(
        id: 'proteines-bas',
        theme: ThemeConseil.proteines,
        domain: AppDomain.nutrition,
        icon: Icons.egg_alt_rounded,
        titre: 'Protéines un peu justes',
        texte: 'Moyenne de ${_n(moy.proteines)} g par jour pour un objectif de ${_n(cible)} g'
            '${parKg == null ? '' : ' (${_n(parKg, 1)} g par kg)'}. '
            'Il manque environ ${_n(manque)} g : un skyr, deux œufs ou une boîte de thon suffisent.',
        phrase: 'Il te manque environ ${_n(manque)} g de protéines par jour : un skyr et c\'est réglé.',
        question: 'Donne-moi des idées pour ajouter ${_n(manque)} g de protéines par jour.',
        priorite: 2,
      ));
    } else {
      out.add(CoachAdvice(
        id: 'proteines-ok',
        theme: ThemeConseil.proteines,
        domain: AppDomain.nutrition,
        icon: Icons.egg_alt_rounded,
        titre: 'Protéines au rendez-vous',
        texte: 'Moyenne de ${_n(moy.proteines)} g par jour pour ${_n(cible)} g visés. Parfait pour construire du muscle.',
        phrase: 'Tes protéines sont au rendez-vous, tes muscles te remercient.',
        priorite: 0,
        positif: true,
      ));
    }
    final today = s.aujourdhui;
    if (today.renseigne && s.now.hour >= 17) {
      final reste = cible - today.macros.proteines;
      if (reste > 30) {
        out.add(CoachAdvice(
          id: 'proteines-jour',
          theme: ThemeConseil.proteines,
          domain: AppDomain.nutrition,
          icon: Icons.restaurant_rounded,
          titre: 'Encore ${_n(reste)} g de protéines aujourd\'hui',
          texte: 'Un dîner avec 150 g de viande blanche ou de poisson couvre déjà une bonne partie.',
          phrase: 'Encore ${_n(reste)} g de protéines à caser ce soir.',
          question: 'Propose-moi un dîner riche en protéines.',
          priorite: 2,
        ));
      }
    }
  }

  static void _energie(CoachSnapshot s, List<CoachAdvice> out) {
    final moy = s.moyenneNutrition;
    final u = s.user;
    if (moy == null || u == null || s.joursNutritionRenseignes < 3) return;
    final cible = s.objectifs.kcal;
    final ecart = moy.kcal - cible;
    if (ecart.abs() < cible * 0.1) return;
    final trop = ecart > 0;
    final objectifMasse = u.objectif == Objectif.prendreDuMuscle;
    final objectifSeche = u.objectif == Objectif.secher;
    if ((trop && objectifMasse) || (!trop && objectifSeche)) return;
    out.add(CoachAdvice(
      id: 'energie',
      theme: ThemeConseil.energie,
      domain: AppDomain.nutrition,
      icon: Icons.local_fire_department_rounded,
      titre: trop ? 'Au-dessus de ton objectif calorique' : 'En dessous de ton objectif calorique',
      texte: 'Moyenne de ${Fmt.kcal(moy.kcal)} par jour pour ${Fmt.kcal(cible)} visées, '
          'soit ${_n(ecart.abs())} kcal ${trop ? 'de trop' : 'de moins'}. '
          '${trop ? 'Surveille les grignotages et les boissons sucrées.' : 'Pour prendre du muscle, il faut un léger surplus : ajoute une collation.'}',
      phrase: trop ? 'Un peu au-dessus de tes calories cette semaine : on resserre.' : 'Mange un peu plus : tes muscles ont besoin d\'énergie.',
      question: trop ? 'Comment réduire mes calories sans avoir faim ?' : 'Comment manger un peu plus sans me forcer ?',
      priorite: 1,
    ));
  }

  static void _hydratation(CoachSnapshot s, List<CoachAdvice> out) {
    if (s.now.hour < 15) return;
    final eau = s.aujourdhui.eauMl;
    final cible = s.objectifs.eauMl;
    if (eau == 0 && !s.aujourdhui.renseigne) return;
    if (eau >= cible * 0.6) return;
    out.add(CoachAdvice(
      id: 'hydratation',
      theme: ThemeConseil.hydratation,
      domain: AppDomain.nutrition,
      icon: Icons.water_drop_rounded,
      titre: 'Pense à boire',
      texte: '${_n(eau / 1000, 1)} L sur ${_n(cible / 1000, 1)} L visés aujourd\'hui. Un grand verre maintenant, un autre à l\'entraînement.',
      phrase: 'Un grand verre d\'eau maintenant : tu n\'es qu\'à ${_n(eau / 1000, 1)} L.',
      priorite: 1,
    ));
  }

  static void _sommeil(CoachSnapshot s, List<CoachAdvice> out) {
    final moy = s.sommeilMoyen;
    final nuit = s.derniereNuit;
    if (nuit != null && Dates.memeJour(nuit.jour, s.today) && nuit.duree.inMinutes < 360) {
      out.add(CoachAdvice(
        id: 'sommeil-nuit',
        theme: ThemeConseil.sommeil,
        domain: AppDomain.sommeil,
        icon: Icons.bedtime_rounded,
        titre: 'Nuit courte : ${Fmt.sommeil(nuit.duree)}',
        texte: 'Après une nuit de moins de 6 heures, garde tes charges habituelles mais retire une série, '
            'ou fais une séance technique. Évite de chercher un record aujourd\'hui.',
        phrase: 'Nuit courte : séance plus légère aujourd\'hui, les records attendront.',
        question: 'J\'ai mal dormi, comment adapter ma séance ?',
        priorite: 3,
      ));
    }
    if (moy == null) return;
    if (moy.inMinutes < 420) {
      out.add(CoachAdvice(
        id: 'sommeil-moyen',
        theme: ThemeConseil.sommeil,
        domain: AppDomain.sommeil,
        icon: Icons.nights_stay_rounded,
        titre: 'Sommeil moyen : ${Fmt.sommeil(moy)}',
        texte: 'Sous 7 heures, la récupération et la prise de muscle ralentissent. '
            'Couche-toi 30 minutes plus tôt cette semaine et coupe les écrans une heure avant.',
        phrase: 'Tu dors ${Fmt.sommeil(moy)} en moyenne : trente minutes de plus changeraient tout.',
        question: 'Comment mieux dormir pour mieux récupérer ?',
        priorite: 2,
      ));
    } else {
      out.add(CoachAdvice(
        id: 'sommeil-ok',
        theme: ThemeConseil.sommeil,
        domain: AppDomain.sommeil,
        icon: Icons.nights_stay_rounded,
        titre: 'Bon sommeil : ${Fmt.sommeil(moy)} en moyenne',
        texte: 'Tes nuits soutiennent ta récupération. Garde des horaires réguliers, même le week-end.',
        phrase: '${Fmt.sommeil(moy)} de sommeil en moyenne : ta récupération suit.',
        priorite: 0,
        positif: true,
      ));
    }
  }

  static void _poids(CoachSnapshot s, List<CoachAdvice> out) {
    final u = s.user;
    final v = s.variationPoids28j;
    final p = s.poids;
    if (u == null || v == null || p == null || p <= 0) return;
    final parSemaine = v / 4;
    final pct = parSemaine / p * 100;
    String? titre;
    String? texte;
    var positif = false;
    switch (u.objectif) {
      case Objectif.prendreDuMuscle:
        if (pct < 0.05) {
          titre = 'Poids stable, la prise ralentit';
          texte = 'Tu prends ${Fmt.poids(parSemaine.abs(), s.unite)} par semaine environ. Pour construire du muscle, vise 0,25 à 0,5 % du poids par semaine : ajoute 150 à 200 kcal par jour.';
        } else if (pct > 0.75) {
          titre = 'Prise de poids rapide';
          texte = 'Plus ${Fmt.poids(parSemaine, s.unite)} par semaine : au-delà de 0,5 %, une partie sera du gras. Retire 150 kcal par jour.';
        } else {
          titre = 'Prise de poids idéale';
          texte = 'Plus ${Fmt.poids(parSemaine, s.unite)} par semaine, pile dans la fourchette pour prendre du muscle sans trop de gras.';
          positif = true;
        }
      case Objectif.secher:
        if (pct > -0.2) {
          titre = 'La sèche marque le pas';
          texte = 'Ton poids bouge peu sur quatre semaines. Retire 150 kcal par jour ou ajoute 3 000 pas quotidiens.';
        } else if (pct < -1.0) {
          titre = 'Perte de poids très rapide';
          texte = 'Plus de 1 % par semaine : attention à la perte musculaire. Remonte un peu les calories et garde les protéines hautes.';
        } else {
          titre = 'Sèche bien réglée';
          texte = 'Moins ${Fmt.poids(parSemaine.abs(), s.unite)} par semaine : une perte régulière qui préserve le muscle.';
          positif = true;
        }
      case Objectif.recomposition || Objectif.force || Objectif.forme:
        if (pct.abs() > 0.5) {
          titre = parSemaine > 0 ? 'Poids en hausse' : 'Poids en baisse';
          texte = '${parSemaine > 0 ? 'Plus' : 'Moins'} ${Fmt.poids(parSemaine.abs(), s.unite)} par semaine sur quatre semaines. Vérifie que c\'est voulu.';
        }
    }
    if (titre == null || texte == null) return;
    out.add(CoachAdvice(
      id: 'poids',
      theme: ThemeConseil.poids,
      domain: AppDomain.poids,
      icon: Icons.monitor_weight_rounded,
      titre: titre,
      texte: texte,
      phrase: texte.split('. ').first.replaceAll(RegExp(r'\.$'), '.'),
      question: 'Mon poids évolue-t-il bien pour mon objectif ?',
      priorite: positif ? 0 : 1,
      positif: positif,
    ));
  }

  static const _motivation = [
    'La régularité bat l\'intensité : une bonne séance aujourd\'hui vaut mieux qu\'une parfaite demain.',
    'Chaque série compte. Reste concentré sur la technique, la charge suivra.',
    'Ton corps change entre les séances : mange bien, dors bien, reviens plus fort.',
    'Une répétition de plus que la dernière fois, et tu as progressé.',
    'Le plus dur, c\'est d\'y aller. Le reste, tu sais faire.',
    'Pas besoin d\'être motivé tous les jours : il suffit d\'être régulier.',
    'Des protéines à chaque repas, et ta récupération suit.',
  ];

  /// Phrase du jour calculée : le conseil le plus utile, sinon une phrase d'élan.
  static String phraseDuJour(CoachSnapshot s) {
    final list = advices(s);
    final utile = list.where((a) => a.priorite >= 2).toList();
    if (utile.isNotEmpty) return utile.first.phrase;
    final doy = s.today.difference(DateTime(s.today.year)).inDays;
    if (list.isNotEmpty && doy.isEven) return list.first.phrase;
    return _motivation[doy % _motivation.length];
  }

  /// Questions proposées dans le chat, tirées des données.
  static List<String> suggestions(CoachSnapshot s) {
    final out = <String>[];
    if (s.sessions.isEmpty) {
      out.addAll([
        'Propose-moi une première routine adaptée à mon niveau.',
        'Comment bien débuter en musculation ?',
        'Combien de protéines dois-je manger par jour ?',
      ]);
    } else {
      out.add('Que travailler aujourd\'hui ?');
      final stagne = s.tendances.where((t) => t.stagne).firstOrNull;
      if (stagne != null) out.add('Je stagne sur « ${stagne.exercice.nom} », que faire ?');
      out.add('Fais le bilan de ma semaine.');
      out.add('Crée-moi une routine jambes de 45 minutes.');
      final top = s.tendances.firstOrNull;
      if (top != null && stagne == null) out.add('Comment progresser sur « ${top.exercice.nom} » ?');
    }
    out.add('Idée de collation riche en protéines.');
    final sommeil = s.sommeilMoyen;
    if (sommeil != null && sommeil.inMinutes < 420) out.add('Comment mieux dormir pour récupérer ?');
    return out.take(6).toList();
  }

  /// Réponse hors ligne dans le chat, à partir des règles.
  static String repondre(CoachSnapshot s, String question) {
    final q = TextSearch.normalize(question);
    bool has(List<String> mots) => mots.any(q.contains);
    final all = advices(s);
    final themes = <ThemeConseil>{
      if (has(['recup', 'fatigu', 'courbatur', 'repos', 'travailler aujourd', 'quoi faire', 'aujourd'])) ThemeConseil.recuperation,
      if (has(['regul', 'semaine', 'frequen', 'combien de seance', 'motiv'])) ThemeConseil.regularite,
      if (has(['stagn', 'progress', 'plateau', 'record', 'charge', 'force', '1rm'])) ThemeConseil.progression,
      if (has(['volume', 'serie', 'series'])) ThemeConseil.volume,
      if (has(['protein', 'prot', 'collation', 'repas', 'manger', 'nutrition', 'diner', 'dejeuner'])) ThemeConseil.proteines,
      if (has(['calori', 'kcal', 'manger', 'nutrition', 'seche', 'masse'])) ThemeConseil.energie,
      if (has(['eau', 'boire', 'hydrat'])) ThemeConseil.hydratation,
      if (has(['dorm', 'sommeil', 'nuit', 'fatigu'])) ThemeConseil.sommeil,
      if (has(['poids', 'balance', 'grossi', 'maigri', 'seche', 'masse'])) ThemeConseil.poids,
    };
    final buf = StringBuffer();
    buf.writeln('Je suis en **mode hors ligne** : je te réponds avec les règles calculées sur ton téléphone.');
    buf.writeln();

    if (has(['bilan'])) {
      buf.writeln(_resumeSemaine(s));
      buf.writeln();
    }
    if (has(['routine', 'programme', 'seance de', 'cree', 'crée'])) {
      buf.writeln('Pour générer une routine sur mesure, j\'ai besoin d\'être connecté. '
          'En attendant, voici une base solide : 3 à 4 séries de 6 à 12 répétitions par exercice, '
          '2 à 3 minutes de repos sur les gros mouvements, 60 à 90 secondes sur l\'isolation, '
          'et une répétition ou un peu de charge en plus à chaque séance.');
      buf.writeln();
    }

    var choisis = themes.isEmpty ? all.take(3).toList() : all.where((a) => themes.contains(a.theme)).toList();
    if (choisis.isEmpty && themes.isNotEmpty) {
      buf.writeln(_pasDeDonnees(themes.first));
      buf.writeln();
      choisis = all.take(2).toList();
      if (choisis.isNotEmpty) buf.writeln('Ce que je vois par ailleurs :');
    }
    for (final a in choisis.take(4)) {
      buf.writeln('- **${a.titre}.** ${a.texte}');
    }
    if (choisis.isEmpty && !has(['bilan', 'routine'])) {
      buf.writeln('Tout est au vert de mon côté : rien à signaler sur ta récupération, ta régularité ni ta nutrition.');
    }
    buf.writeln();
    buf.write('Ajoute une clé API dans les réglages du coach pour une vraie conversation, des routines générées et des conseils sur mesure.');
    return buf.toString();
  }

  static String _pasDeDonnees(ThemeConseil t) => switch (t) {
        ThemeConseil.proteines || ThemeConseil.energie || ThemeConseil.hydratation =>
          'Je n\'ai pas assez de repas enregistrés sur les derniers jours pour juger ta nutrition. Note tes repas dans l\'onglet Nutrition.',
        ThemeConseil.sommeil => 'Je n\'ai pas de nuits enregistrées récemment. Ajoute ton sommeil ou connecte Health Connect.',
        ThemeConseil.poids => 'Il me faut au moins deux pesées sur quatre semaines pour suivre ton poids.',
        _ => 'Je n\'ai pas assez de séances récentes pour répondre précisément.',
      };

  static String _resumeSemaine(CoachSnapshot s) {
    final sem = s.semaine;
    final volume = sem.fold(0.0, (a, x) => a + x.volume);
    final series = sem.fold(0, (a, x) => a + x.nbSeriesFaites);
    if (sem.isEmpty) return 'Aucune séance enregistrée cette semaine pour l\'instant.';
    return 'Cette semaine : **${Fmt.pluriel(sem.length, 'séance')}**, ${Fmt.pluriel(series, 'série')} '
        'et ${Fmt.volume(volume, s.unite)} soulevés.';
  }
}
