import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/format.dart';
import '../../../core/models/models.dart';
import '../logic/logic.dart';
import 'conversion.dart';
import 'import_journal.dart';
import 'repo_extensions.dart';

/// D'où vient le fichier.
enum ImportSource {
  application('Une autre application de suivi (CSV)',
      'L\'export de ton ancienne appli : séances, séries, charges et répétitions.'),
  tableau('Tableau quelconque',
      'Un tableur exporté en CSV : tu indiques quelle colonne contient quoi.');

  const ImportSource(this.label, this.description);
  final String label;
  final String description;
}

/// Que faire de l'historique déjà présent.
enum ImportMode {
  fusionner('Ajouter à mon historique', 'Les séances déjà présentes à la même heure sont ignorées.'),
  remplacerImportees('Remplacer les séances importées',
      'Les séances d\'un import précédent sont supprimées, celles faites dans l\'appli restent.'),
  remplacerTout('Remplacer tout l\'historique', 'Toutes les séances enregistrées sont supprimées avant l\'import.');

  const ImportMode(this.label, this.description);
  final String label;
  final String description;
}

enum EtatAnalyse { aucun, analyse, pret, erreur }

/// Ce que l'import a produit, pour l'écran de résumé.
class ImportResult {
  ImportResult({
    required this.journalId,
    required this.seanceIds,
    required this.seances,
    required this.series,
    required this.echauffements,
    required this.exercicesCrees,
    required this.exercicesUtilises,
    required this.doublons,
    required this.remplacees,
    required this.volumeKg,
    required this.records,
    this.debut,
    this.fin,
  });

  final String journalId;
  final List<String> seanceIds;
  final int seances;
  final int series;
  final int echauffements;
  final int exercicesCrees;
  final int exercicesUtilises;
  final int doublons;
  final int remplacees;
  final double volumeKg;
  final List<RecordExercice> records;
  final DateTime? debut;
  final DateTime? fin;
}

class _Args {
  _Args(this.texte, this.catalogue, this.options, this.colonnes, this.forcer, this.memoire, this.debuts);
  final String texte;
  final List<CatalogueEntry> catalogue;
  final ImportOptions options;
  final ColumnMapping? colonnes;
  final ImportFormat? forcer;
  final Map<String, String> memoire;
  final List<DateTime> debuts;
}

ImportPreview _analyser(_Args a) => ImportAnalyzer.analyser(
      a.texte,
      catalogue: a.catalogue,
      options: a.options,
      colonnes: a.colonnes,
      forcer: a.forcer,
      memoire: a.memoire,
      debutsExistants: a.debuts,
    );

/// État partagé par les écrans de l'import, du choix du fichier au résumé.
class ImportFlow extends ChangeNotifier {
  ImportFlow();

  /// Instance du parcours en cours (un seul import à la fois).
  static final instance = ImportFlow();

  /// Analyse dans un isolat (désactivé dans les tests de widgets).
  static bool enIsolat = true;

  /// Au-delà, le fichier est refusé (un historique complet pèse rarement plus de 5 Mo).
  static const tailleMax = 40 * 1024 * 1024;

  ImportSource source = ImportSource.application;

  /// Où revenir à la fin (l'inscription, par exemple).
  String? retour;

  String? nomFichier;
  int? taille;
  String? _texte;
  EtatAnalyse etat = EtatAnalyse.aucun;
  String? erreur;
  ImportPreview? preview;

  /// Association des colonnes imposée à la main (tableau quelconque).
  ColumnMapping? colonnes;
  UniteCharge unite = UniteCharge.kg;
  bool ignorerSeriesVides = true;
  bool garderEchauffements = true;
  ImportMode mode = ImportMode.fusionner;

  /// Brouillons des exercices perso, par clé de nom normalisé.
  final Map<String, PersoDraft> persos = {};

  bool importEnCours = false;
  double progression = 0;
  String etape = '';
  String? erreurImport;
  ImportResult? resultat;

  bool get aUnFichier => _texte != null;
  CsvTable? get table => preview?.table;
  ImportReport? get rapport => preview?.rapport;

  /// Le fichier demande d'associer les colonnes à la main.
  bool get besoinColonnes {
    final p = preview;
    if (p == null) return false;
    if (colonnes != null) return !colonnes!.estUtilisable;
    if (!p.detection.reconnu) return true;
    return source == ImportSource.tableau && p.detection.format == ImportFormat.generique;
  }

  /// Nouveau parcours : tout est oublié.
  void demarrer(ImportSource s, {String? retour}) {
    source = s;
    this.retour = retour;
    nomFichier = null;
    taille = null;
    _texte = null;
    etat = EtatAnalyse.aucun;
    erreur = null;
    preview = null;
    colonnes = null;
    mode = ImportMode.fusionner;
    garderEchauffements = true;
    ignorerSeriesVides = true;
    persos.clear();
    importEnCours = false;
    progression = 0;
    etape = '';
    erreurImport = null;
    resultat = null;
    notifyListeners();
  }

  /// Lit les octets d'un fichier choisi puis l'analyse.
  Future<void> chargerFichier(String nom, List<int> octets, AppData data) async {
    nomFichier = nom;
    taille = octets.length;
    preview = null;
    colonnes = null;
    persos.clear();
    resultat = null;
    if (octets.isEmpty) {
      _texte = null;
      etat = EtatAnalyse.erreur;
      erreur = 'Le fichier est vide.';
      notifyListeners();
      return;
    }
    if (octets.length > tailleMax) {
      _texte = null;
      etat = EtatAnalyse.erreur;
      erreur = 'Le fichier est trop lourd (plus de 40 Mo). Exporte une période plus courte.';
      notifyListeners();
      return;
    }
    if (_ressembleABinaire(octets)) {
      _texte = null;
      etat = EtatAnalyse.erreur;
      erreur = 'Ce fichier n\'est pas un CSV. Un classeur Excel doit d\'abord être enregistré au format CSV.';
      notifyListeners();
      return;
    }
    _texte = CsvTable.decoder(octets);
    unite = data.profile.unite == UnitePoids.lb ? UniteCharge.lb : UniteCharge.kg;
    await analyser(data);
  }

  static bool _ressembleABinaire(List<int> o) {
    if (o.length >= 2 && o[0] == 0x50 && o[1] == 0x4B) return true; // zip, xlsx
    final n = o.length < 2048 ? o.length : 2048;
    var nuls = 0;
    for (var i = 0; i < n; i++) {
      if (o[i] == 0) nuls++;
    }
    return nuls > 4;
  }

  /// Débuts des séances déjà enregistrées, selon le mode choisi.
  List<DateTime> _debuts(AppData data) => switch (mode) {
        ImportMode.fusionner => [for (final s in data.sessions.sessions) s.debut],
        ImportMode.remplacerImportees => [
            for (final s in data.sessions.sessions)
              if (s.source != 'import') s.debut,
          ],
        ImportMode.remplacerTout => const [],
      };

  static List<CatalogueEntry> catalogueDe(AppData data) => [
        for (final e in data.exercises.all)
          CatalogueEntry(id: e.id, nom: e.nom, nomEn: e.nomEn, alias: e.alias, equipement: e.equipement),
      ];

  /// Analyse (ou refait l'analyse) du fichier chargé avec les réglages courants.
  Future<void> analyser(AppData data) async {
    final texte = _texte;
    if (texte == null) return;
    etat = EtatAnalyse.analyse;
    erreur = null;
    notifyListeners();
    try {
      final memoire = preview?.memoire ?? await ImportJournal.lireCorrespondances(data.store);
      final args = _Args(
        texte,
        catalogueDe(data),
        ImportOptions(uniteParDefaut: unite, ignorerSeriesVides: ignorerSeriesVides),
        colonnes,
        null,
        Map.of(memoire),
        _debuts(data),
      );
      final p = enIsolat ? await compute(_analyser, args) : _analyser(args);
      preview = p;
      etat = EtatAnalyse.pret;
      _completerPersos();
    } catch (e) {
      etat = EtatAnalyse.erreur;
      erreur = 'Lecture impossible : le fichier est peut-être abîmé.';
      debugPrint('Import : $e');
    }
    notifyListeners();
  }

  /// Change l'association des colonnes puis relance l'analyse.
  Future<void> appliquerColonnes(ColumnMapping m, AppData data) async {
    colonnes = m;
    await analyser(data);
  }

  /// Revient à la détection automatique des colonnes.
  Future<void> oublierColonnes(AppData data) async {
    colonnes = null;
    await analyser(data);
  }

  Future<void> changerOptions(AppData data,
      {UniteCharge? unite, bool? ignorerSeriesVides, ImportMode? mode, bool? garderEchauffements}) async {
    final relancer = (unite != null && unite != this.unite) ||
        (ignorerSeriesVides != null && ignorerSeriesVides != this.ignorerSeriesVides) ||
        (mode != null && mode != this.mode);
    this.unite = unite ?? this.unite;
    this.ignorerSeriesVides = ignorerSeriesVides ?? this.ignorerSeriesVides;
    this.mode = mode ?? this.mode;
    this.garderEchauffements = garderEchauffements ?? this.garderEchauffements;
    if (relancer) {
      await analyser(data);
    } else {
      notifyListeners();
    }
  }

  // Rapprochement des noms

  /// Toutes les séries d'un nom du fichier.
  Iterable<ImportedSet> seriesDe(String nomSource) sync* {
    final cle = cleNom(nomSource);
    for (final s in preview?.seances ?? const <ImportedSession>[]) {
      if (s.doublon) continue;
      for (final e in s.exercices) {
        if (cleNom(e.nomSource) == cle) yield* e.series;
      }
    }
  }

  void _completerPersos() {
    final r = preview?.rapport;
    if (r == null) return;
    for (final rap in r.nouveaux) {
      persos.putIfAbsent(cleNom(rap.nomSource), () => _brouillon(rap.nomSource));
    }
  }

  PersoDraft _brouillon(String nomSource) {
    final modele = preview?.rapprochements[cleNom(nomSource)]?.modele;
    final d = modele == null ? PersoDraft.depuisNom(nomSource) : PersoDraft.depuisModele(modele, nomSource);
    return d..suivi = deduireSuivi(seriesDe(nomSource));
  }

  PersoDraft brouillon(String nomSource) =>
      persos.putIfAbsent(cleNom(nomSource), () => _brouillon(nomSource));

  void confirmer(String nomSource, String exerciceId) {
    preview?.confirmer(nomSource, exerciceId);
    persos.remove(cleNom(nomSource));
    notifyListeners();
  }

  void creerPersonnel(String nomSource, [PersoDraft? draft]) {
    preview?.creerPersonnel(nomSource);
    persos[cleNom(nomSource)] = draft ?? brouillon(nomSource);
    notifyListeners();
  }

  /// Accepte les suggestions sûres ; les autres restent à confirmer une par
  /// une. [toutes] prend aussi les incertaines. Renvoie le nombre accepté.
  int accepterSuggestions({bool toutes = false}) {
    final n = preview?.accepterSuggestions(toutes: toutes) ?? 0;
    notifyListeners();
    return n;
  }

  /// Crée un exercice perso pour tous les noms encore sans correspondance.
  void creerTousLesInconnus() {
    final p = preview;
    if (p == null) return;
    for (final r in [...p.rapport.aConfirmer]) {
      if (r.statut == StatutRapprochement.inconnu) {
        p.memoire[cleNom(r.nomSource)] = '';
        persos.putIfAbsent(cleNom(r.nomSource), () => _brouillon(r.nomSource));
      }
    }
    _recalculer();
  }

  /// Oublie le choix fait pour un nom : il repasse par la détection.
  void annulerChoix(String nomSource) {
    final p = preview;
    if (p == null) return;
    p.memoire.remove(cleNom(nomSource));
    persos.remove(cleNom(nomSource));
    _recalculer();
  }

  void majBrouillon(String nomSource, PersoDraft d) {
    persos[cleNom(nomSource)] = d;
    notifyListeners();
  }

  void _recalculer() {
    final p = preview;
    if (p == null) return;
    p.rapprochements = rapprocherSeances(p.seances, p.matcher, memoire: p.memoire);
    p.rapport = ImportReport.calculer(p.parse, p.rapprochements);
    notifyListeners();
  }

  // Import

  /// Enregistre les séances. Rend le résultat (aussi gardé dans [resultat]).
  Future<ImportResult?> importer(AppData data) async {
    final p = preview;
    if (p == null || importEnCours) return null;
    importEnCours = true;
    erreurImport = null;
    progression = 0;
    etape = 'Préparation';
    notifyListeners();
    try {
      final maintenant = DateTime.now();
      final rapport = p.rapport;

      // 1. Exercices personnels.
      etape = 'Création des exercices personnels';
      _avancer(0.05);
      await _souffler();
      final aImporter = p.aImporter;
      // Seuls les noms des séances réellement ajoutées comptent : un nom qui
      // n'apparaît que dans des séances déjà présentes ne crée rien.
      final clesUtiles = {
        for (final s in aImporter)
          for (final e in s.exercices) cleNom(e.nomSource),
      };
      final idParCle = <String, String>{};
      final crees = <Exercise>[];
      for (final rap in p.rapprochements.values) {
        final cle = cleNom(rap.nomSource);
        if (rap.choisi != null) {
          idParCle[cle] = rap.choisi!.id;
        } else if (clesUtiles.contains(cle)) {
          // Nouveau, ou resté sans réponse : un exercice personnel au nom du
          // fichier plutôt que des séries perdues sans rien dire.
          final ex = brouillon(rap.nomSource).versExercice('perso-${newId()}', maintenant);
          crees.add(ex);
          idParCle[cle] = ex.id;
        }
      }
      if (crees.isNotEmpty) {
        await data.exercises.addCustomAll(crees);
        // Retenu tout de suite : si la suite échoue et que l'import est
        // relancé, les mêmes noms retombent sur ces exercices au lieu d'en
        // créer d'autres.
        for (final e in crees) {
          p.memoire[idParCle.entries.firstWhere((x) => x.value == e.id).key] = e.id;
        }
        await ImportJournal.ecrireCorrespondances(data.store, Map.of(p.memoire));
      }

      // 2. Conversion des séances.
      etape = 'Conversion des séances';
      final cardio = <String, bool>{};
      bool estCardio(String id) => cardio.putIfAbsent(id, () {
            final e = data.exercises.byId(id);
            return e != null &&
                (e.categorie.toLowerCase().contains('cardio') || e.suivi == ExerciseTracking.distanceDuree);
          });
      final seances = <WorkoutSession>[];
      for (var i = 0; i < aImporter.length; i++) {
        final s = convertirSeance(
          aImporter[i],
          idPour: (nom) => idParCle[cleNom(nom)],
          garderEchauffements: garderEchauffements,
          estCardio: estCardio,
        );
        if (s.exercices.isNotEmpty) seances.add(s);
        if (i % 25 == 0) {
          _avancer(0.1 + 0.5 * i / (aImporter.isEmpty ? 1 : aImporter.length));
          await _souffler();
        }
      }

      // 3. Remplacement éventuel.
      var remplacees = 0;
      if (mode != ImportMode.fusionner) {
        etape = 'Suppression de l\'ancien historique';
        _avancer(0.65);
        await _souffler();
        final ids = {
          for (final s in data.sessions.sessions)
            if (mode == ImportMode.remplacerTout || s.source == 'import') s.id,
        };
        remplacees = ids.length;
        await data.sessions.supprimerPlusieurs(ids);
      }

      // 4. Enregistrement.
      etape = 'Enregistrement de ${Fmt.pluriel(seances.length, 'séance')}';
      _avancer(0.75);
      await _souffler();
      await data.sessions.addAll(seances);

      // 5. Mémoire des correspondances et journal.
      etape = 'Calcul des records';
      _avancer(0.9);
      await _souffler();
      // Les exercices perso créés sont retenus par leur identifiant : au
      // prochain import, le même nom retombe sur le même exercice.
      await ImportJournal.ecrireCorrespondances(data.store, Map.of(p.memoire));

      var series = 0, echauffements = 0;
      var volume = 0.0;
      final utilises = <String>{};
      DateTime? debut, fin;
      for (final s in seances) {
        debut = debut == null || s.debut.isBefore(debut) ? s.debut : debut;
        fin = fin == null || s.debut.isAfter(fin) ? s.debut : fin;
        volume += s.volume;
        for (final e in s.exercices) {
          utilises.add(e.exerciseId);
          for (final set in e.series) {
            set.type.counts ? series++ : echauffements++;
          }
        }
      }
      final journal = ImportJournalEntry(
        id: newId(),
        date: maintenant,
        fichier: nomFichier ?? 'Fichier',
        format: rapport.format.libelle,
        mode: mode.name,
        seanceIds: [for (final s in seances) s.id],
        exercicesCrees: [for (final e in crees) e.id],
        series: series,
        debut: debut,
        fin: fin,
        remplacees: remplacees,
        doublons: rapport.seancesDoublons,
      );
      await ImportJournal.ajouter(data.store, journal);

      resultat = ImportResult(
        journalId: journal.id,
        seanceIds: journal.seanceIds,
        seances: seances.length,
        series: series,
        echauffements: echauffements,
        exercicesCrees: crees.length,
        exercicesUtilises: utilises.length,
        doublons: rapport.seancesDoublons,
        remplacees: remplacees,
        volumeKg: volume,
        records: [
          for (final r in rapport.records)
            if (r.chargeMax > 0 || r.repsMax > 0) r,
        ],
        debut: debut,
        fin: fin,
      );
      etape = 'Terminé';
      _avancer(1);
      return resultat;
    } catch (e) {
      erreurImport = 'L\'import a échoué : $e';
      return null;
    } finally {
      importEnCours = false;
      notifyListeners();
    }
  }

  void _avancer(double v) {
    progression = v.clamp(0, 1).toDouble();
    notifyListeners();
  }

  Future<void> _souffler() => Future<void>.delayed(const Duration(milliseconds: 16));

  /// Annule un import : supprime ses séances et les exercices perso
  /// créés pour lui qui ne servent plus ailleurs.
  static Future<({int seances, int exercices})> annulerImport(AppData data, ImportJournalEntry e) async {
    final ids = e.seanceIds.toSet();
    final presentes = data.sessions.sessions.where((s) => ids.contains(s.id)).length;
    await data.sessions.supprimerPlusieurs(ids);
    final utilises = <String>{
      for (final s in data.sessions.sessions)
        for (final x in s.exercices) x.exerciseId,
      for (final r in data.routines.routines)
        for (final x in r.exercices) x.exerciseId,
    };
    final n = await data.exercises.supprimerPersoInutilises(e.exercicesCrees.toSet(), utilises: utilises);
    await ImportJournal.retirer(data.store, e.id);
    return (seances: presentes, exercices: n);
  }
}

