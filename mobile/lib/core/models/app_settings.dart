import 'json.dart';

/// Réglages de l'appli (hors accent, tenu par AccentController, et hors unités, dans le profil).
class AppSettings {
  const AppSettings({
    this.reposParDefautSec = 90,
    this.incrementPoidsKg = 2.5,
    this.sonMinuteur = true,
    this.vibrationMinuteur = true,
    this.garderEcranAllume = true,
    this.afficherRpe = false,
    this.effortRir = false,
    this.volumeMinuteur = 2,
    this.forceVibration = 1,
    this.precedentMemeRoutine = false,
    this.supersetAuto = true,
    this.alerteRecord = true,
    this.notifSeance = true,
    this.decompteVocal = false,
    this.musique,
    this.echauffementAuto = false,
    this.rappelsEntrainement = false,
    this.heureRappel = '18:00',
    this.joursRappel = const [1, 3, 5],
    this.rappelsEau = false,
    this.rappelsComplements = false,
    this.premierJourSemaine = DateTime.monday,
    this.santeConnectee = false,
    this.coachApiKey,
    this.coachModele,
    this.coachTon = 'bienveillant',
    this.langueCoach = 'fr',
  });

  final int reposParDefautSec;
  final double incrementPoidsKg;
  final bool sonMinuteur;
  final bool vibrationMinuteur;
  final bool garderEcranAllume;
  final bool afficherRpe;

  /// Effort noté en répétitions en réserve (RIR) plutôt qu'en RPE. La série
  /// garde un RPE ; seul l'affichage change (RIR = 10 − RPE).
  final bool effortRir;

  /// Volume du son de fin de repos : 0 faible, 1 moyen, 2 fort.
  final int volumeMinuteur;

  /// Force de la vibration de fin de repos : 0 légère, 1 moyenne, 2 forte.
  final int forceVibration;

  /// Colonne « Précédent » : la dernière fois dans la même routine plutôt
  /// que la dernière fois tout court.
  final bool precedentMemeRoutine;

  /// En superset, ouvrir tout seul l'exercice suivant après une série.
  final bool supersetAuto;

  /// Prévenir pendant la séance quand une série bat un record de charge.
  final bool alerteRecord;

  /// Notification permanente « Séance en cours » tant qu'une séance est ouverte.
  final bool notifSeance;

  /// Fin de repos annoncée par une voix : « five, four, three, two, one,
  /// go » à la place du son.
  final bool decompteVocal;

  /// Bouton musique de la séance : « spotify », « youtube », ou null (aucun).
  final String? musique;

  /// Propose des séries d'échauffement au début de chaque exercice lourd.
  final bool echauffementAuto;
  final bool rappelsEntrainement;
  final String heureRappel;

  /// Jours du rappel, 1 = lundi … 7 = dimanche.
  final List<int> joursRappel;
  final bool rappelsEau;
  final bool rappelsComplements;
  final int premierJourSemaine;

  /// Health Connect autorisé et synchronisé.
  final bool santeConnectee;

  /// Clé et modèle du service de coach IA (gardés sur le téléphone).
  final String? coachApiKey;
  final String? coachModele;
  final String coachTon;
  final String langueCoach;

  AppSettings copyWith({
    int? reposParDefautSec,
    double? incrementPoidsKg,
    bool? sonMinuteur,
    bool? vibrationMinuteur,
    bool? garderEcranAllume,
    bool? afficherRpe,
    bool? effortRir,
    int? volumeMinuteur,
    int? forceVibration,
    bool? precedentMemeRoutine,
    bool? supersetAuto,
    bool? alerteRecord,
    bool? notifSeance,
    bool? decompteVocal,
    String? musique,
    bool sansMusique = false,
    bool? echauffementAuto,
    bool? rappelsEntrainement,
    String? heureRappel,
    List<int>? joursRappel,
    bool? rappelsEau,
    bool? rappelsComplements,
    int? premierJourSemaine,
    bool? santeConnectee,
    String? coachApiKey,
    bool clearCoachApiKey = false,
    String? coachModele,
    String? coachTon,
    String? langueCoach,
  }) =>
      AppSettings(
        reposParDefautSec: reposParDefautSec ?? this.reposParDefautSec,
        incrementPoidsKg: incrementPoidsKg ?? this.incrementPoidsKg,
        sonMinuteur: sonMinuteur ?? this.sonMinuteur,
        vibrationMinuteur: vibrationMinuteur ?? this.vibrationMinuteur,
        garderEcranAllume: garderEcranAllume ?? this.garderEcranAllume,
        afficherRpe: afficherRpe ?? this.afficherRpe,
        effortRir: effortRir ?? this.effortRir,
        volumeMinuteur: volumeMinuteur ?? this.volumeMinuteur,
        forceVibration: forceVibration ?? this.forceVibration,
        precedentMemeRoutine: precedentMemeRoutine ?? this.precedentMemeRoutine,
        supersetAuto: supersetAuto ?? this.supersetAuto,
        alerteRecord: alerteRecord ?? this.alerteRecord,
        notifSeance: notifSeance ?? this.notifSeance,
        decompteVocal: decompteVocal ?? this.decompteVocal,
        musique: sansMusique ? null : (musique ?? this.musique),
        echauffementAuto: echauffementAuto ?? this.echauffementAuto,
        rappelsEntrainement: rappelsEntrainement ?? this.rappelsEntrainement,
        heureRappel: heureRappel ?? this.heureRappel,
        joursRappel: joursRappel ?? this.joursRappel,
        rappelsEau: rappelsEau ?? this.rappelsEau,
        rappelsComplements: rappelsComplements ?? this.rappelsComplements,
        premierJourSemaine: premierJourSemaine ?? this.premierJourSemaine,
        santeConnectee: santeConnectee ?? this.santeConnectee,
        coachApiKey: clearCoachApiKey ? null : (coachApiKey ?? this.coachApiKey),
        coachModele: coachModele ?? this.coachModele,
        coachTon: coachTon ?? this.coachTon,
        langueCoach: langueCoach ?? this.langueCoach,
      );

  factory AppSettings.fromJson(Json j) => AppSettings(
        reposParDefautSec: asInt(j['reposParDefautSec']) ?? 90,
        incrementPoidsKg: asDouble(j['incrementPoidsKg']) ?? 2.5,
        sonMinuteur: asBool(j['sonMinuteur'], true),
        vibrationMinuteur: asBool(j['vibrationMinuteur'], true),
        garderEcranAllume: asBool(j['garderEcranAllume'], true),
        afficherRpe: asBool(j['afficherRpe']),
        effortRir: asBool(j['effortRir']),
        volumeMinuteur: (asInt(j['volumeMinuteur']) ?? 2).clamp(0, 2),
        forceVibration: (asInt(j['forceVibration']) ?? 1).clamp(0, 2),
        precedentMemeRoutine: asBool(j['precedentMemeRoutine']),
        supersetAuto: asBool(j['supersetAuto'], true),
        alerteRecord: asBool(j['alerteRecord'], true),
        notifSeance: asBool(j['notifSeance'], true),
        decompteVocal: asBool(j['decompteVocal']),
        musique: asString(j['musique']),
        echauffementAuto: asBool(j['echauffementAuto']),
        rappelsEntrainement: asBool(j['rappelsEntrainement']),
        heureRappel: asString(j['heureRappel']) ?? '18:00',
        joursRappel: (j['joursRappel'] is List)
            ? (j['joursRappel'] as List).map(asInt).whereType<int>().toList()
            : const [1, 3, 5],
        rappelsEau: asBool(j['rappelsEau']),
        rappelsComplements: asBool(j['rappelsComplements']),
        premierJourSemaine: asInt(j['premierJourSemaine']) ?? DateTime.monday,
        santeConnectee: asBool(j['santeConnectee']),
        coachApiKey: asString(j['coachApiKey']),
        coachModele: asString(j['coachModele']),
        coachTon: asString(j['coachTon']) ?? 'bienveillant',
        langueCoach: asString(j['langueCoach']) ?? 'fr',
      );

  Json toJson() => compact({
        'reposParDefautSec': reposParDefautSec,
        'incrementPoidsKg': incrementPoidsKg,
        'sonMinuteur': sonMinuteur,
        'vibrationMinuteur': vibrationMinuteur,
        'garderEcranAllume': garderEcranAllume,
        'afficherRpe': afficherRpe,
        'effortRir': effortRir,
        'volumeMinuteur': volumeMinuteur,
        'forceVibration': forceVibration,
        'precedentMemeRoutine': precedentMemeRoutine,
        'supersetAuto': supersetAuto,
        'alerteRecord': alerteRecord,
        'notifSeance': notifSeance,
        'decompteVocal': decompteVocal,
        'musique': musique,
        'echauffementAuto': echauffementAuto,
        'rappelsEntrainement': rappelsEntrainement,
        'heureRappel': heureRappel,
        'joursRappel': joursRappel,
        'rappelsEau': rappelsEau,
        'rappelsComplements': rappelsComplements,
        'premierJourSemaine': premierJourSemaine,
        'santeConnectee': santeConnectee,
        'coachApiKey': coachApiKey,
        'coachModele': coachModele,
        'coachTon': coachTon,
        'langueCoach': langueCoach,
      });
}
