import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/body/body_map.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../../profil/data/prefs.dart';
import '../logic/analyse.dart';
import '../logic/chrono.dart';
import '../logic/editeur.dart';
import '../logic/medias.dart';
import '../logic/repos_minuteur.dart';
import '../seance_paths.dart';
import '../../profil/widgets/ecusson.dart';
import '../widgets/bandeau_record.dart';
import '../widgets/exercice_carte.dart';
import '../widgets/habillage.dart';
import '../widgets/mini_barre.dart';
import '../widgets/panneaux.dart';
import 'demarrer_vue.dart';
import 'remplacer_page.dart';
import 'reordonner_page.dart';

/// Écran de la séance en cours ; sans séance, propose d'en démarrer une.
class SeancePage extends StatelessWidget {
  const SeancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final actif = context.select<SessionRepo, bool>((r) => r.hasActive);
    return actif ? const _SeanceEnCours() : const DemarrerVue();
  }
}

/// Ferme l'écran de séance sans l'arrêter (elle reste dans la barre réduite).
void reduireSeance(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

class _SeanceEnCours extends StatefulWidget {
  const _SeanceEnCours();

  @override
  State<_SeanceEnCours> createState() => _SeanceEnCoursState();
}

class _SeanceEnCoursState extends State<_SeanceEnCours> {
  late final EditeurDirect _ed = EditeurDirect(context.read<SessionRepo>());
  bool _veille = false;

  final _defile = ScrollController();
  final _cles = <String, GlobalKey>{};

  /// L'exercice ouvert de la liste (un seul à la fois), ou aucun.
  String? _ouvert;

  /// Dernière action annulable (« Série supprimée »), montrée sous la liste.
  ({String message, VoidCallback annuler})? _annulable;
  Timer? _finAnnulable;

  /// Hauteur du clavier, et le recadrage différé qui suit son ouverture.
  double _clavier = 0;
  Timer? _finCadrage;

  @override
  void initState() {
    super.initState();
    _ouvert = _aFaire(0);
    FocusManager.instance.addListener(_cadrerSaisie);
    final seances = context.read<SessionRepo>();
    final reglages = context.read<SettingsRepo>();
    final exercices = context.read<ExerciseRepo>();
    final profil = context.read<ProfileRepo>();
    ReposMinuteur.instance.surSerieValidee = _serieValidee;
    unawaited(ReposMinuteur.instance.preparer().then((_) => ReposMinuteur.instance.suivreSeance(seances, reglages, exercices: exercices, profil: profil)));
    unawaited(PauseSeance.instance.charger(context.read<SessionRepo>()));
    unawaited(PrefsRepo.ensure(context.read<Store>()).then<void>((_) {}, onError: (_) {}));
    if (context.read<SettingsRepo>().settings.garderEcranAllume) {
      _veille = true;
      WakelockPlus.enable().catchError((_) {});
    }
  }

  @override
  void dispose() {
    if (_veille) WakelockPlus.disable().catchError((_) {});
    _finAnnulable?.cancel();
    _finCadrage?.cancel();
    FocusManager.instance.removeListener(_cadrerSaisie);
    if (ReposMinuteur.instance.surSerieValidee == _serieValidee) ReposMinuteur.instance.surSerieValidee = null;
    _annonce.dispose();
    _defile.dispose();
    _ed.dispose();
    super.dispose();
  }

  SettingsRepo get _reglages => context.read<SettingsRepo>();

  /// Premier exercice non terminé à partir de [depuis], sinon le premier de
  /// la séance qui reste à faire.
  String? _aFaire(int depuis) {
    final liste = _ed.session?.exercices ?? const <SessionExercise>[];
    for (var i = depuis; i < liste.length; i++) {
      if (!exerciceTermine(liste[i])) return liste[i].id;
    }
    for (var i = 0; i < depuis && i < liste.length; i++) {
      if (!exerciceTermine(liste[i])) return liste[i].id;
    }
    return null;
  }

  void _ouvrir(String? id) {
    if (!mounted) return;
    setState(() => _ouvert = id);
    if (id != null) _reveler(id);
  }

  /// Toucher une ligne : elle s'ouvre (et referme l'autre), ou se replie.
  void _basculer(String id) => _ouvrir(_ouvert == id ? null : id);

  /// Fait défiler la page pour montrer l'exercice [id] : sa ligne en haut de
  /// l'écran s'il est plus grand que la place, sinon juste ce qu'il faut.
  void _reveler(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ro = _cles[id]?.currentContext?.findRenderObject();
      if (ro == null || !_defile.hasClients) return;
      final vue = RenderAbstractViewport.maybeOf(ro);
      if (vue == null) return;
      final p = _defile.position;
      final haut = vue.getOffsetToReveal(ro, 0).offset;
      final bas = vue.getOffsetToReveal(ro, 1).offset;
      double? cible;
      if (bas > haut || p.pixels > haut) {
        cible = haut;
      } else if (p.pixels < bas) {
        cible = bas;
      }
      if (cible == null) return;
      final but = cible.clamp(p.minScrollExtent, p.maxScrollExtent);
      if ((but - p.pixels).abs() < 1) return;
      p.animateTo(but, duration: AppTokens.fast, curve: Curves.easeOut);
    });
  }


  /// Clavier ouvert : si l'exercice ouvert tient dans la place qui reste, on
  /// remonte jusqu'à sa ligne (son nom reste lisible) ; sinon le champ saisi
  /// garde la priorité, la page l'a déjà amené à l'écran.
  void _cadrerSaisie() {
    _finCadrage?.cancel();
    if (_clavier <= 0) return;
    _finCadrage = Timer(const Duration(milliseconds: 140), () {
      final f = FocusManager.instance.primaryFocus;
      if (!mounted || !_defile.hasClients || f == null || f is FocusScopeNode) return;
      final champ = f.context?.findRenderObject();
      final carte = _cles[_ouvert]?.currentContext?.findRenderObject();
      if (champ == null || carte == null) return;
      final vue = RenderAbstractViewport.maybeOf(carte);
      if (vue == null || RenderAbstractViewport.maybeOf(champ) != vue) return;
      final p = _defile.position;
      final haut = vue.getOffsetToReveal(carte, 0).offset.clamp(p.minScrollExtent, p.maxScrollExtent);
      // Le défilement le plus petit qui montre encore la ligne saisie en entier.
      final mini = vue.getOffsetToReveal(champ, 1).offset + k(14);
      if (haut < mini || (haut - p.pixels).abs() < 1) return;
      p.animateTo(haut, duration: AppTokens.fast, curve: Curves.easeOut);
    });
  }
  /// Après une série validée : en superset on passe au membre suivant qui a
  /// encore une série à faire ; un exercice terminé se replie et le suivant
  /// à faire s'ouvre.
  void _avancer(SessionExercise se) {
    if (_ouvert != se.id) return;
    final liste = _ed.session?.exercices ?? const <SessionExercise>[];
    final i = liste.indexWhere((e) => e.id == se.id);
    if (i < 0) return;
    if (se.supersetId != null && _reglages.settings.supersetAuto) {
      final groupe = [for (final e in liste) if (e.supersetId == se.supersetId) e];
      final j = groupe.indexWhere((e) => e.id == se.id);
      for (var n = 1; n < groupe.length; n++) {
        final e = groupe[(j + n) % groupe.length];
        if (!exerciceTermine(e)) return _ouvrir(e.id);
      }
    }
    if (exerciceTermine(liste[i])) _ouvrir(_aFaire(i + 1));
  }

  /// Montre « Série supprimée / Annuler » sous la liste, au-dessus du
  /// clavier : la liste rétrécit, aucune ligne n'est recouverte.
  void _montrerAnnulable(String message, VoidCallback annuler) {
    if (!mounted) return;
    _finAnnulable?.cancel();
    setState(() => _annulable = (message: message, annuler: annuler));
    _finAnnulable = Timer(const Duration(seconds: 4), _fermerAnnulable);
    // La liste vient de perdre de la hauteur : le champ en cours reste à l'écran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = FocusManager.instance.primaryFocus;
      if (f != null && f is! FocusScopeNode) f.context?.findRenderObject()?.showOnScreen(duration: AppTokens.fast);
    });
  }

  void _fermerAnnulable() {
    _finAnnulable?.cancel();
    if (mounted && _annulable != null) setState(() => _annulable = null);
  }

  /// Prochaine série à faire, pour la notification de fin de repos.
  String? _suivante(ExerciseRepo exos) {
    final s = _ed.session;
    if (s == null) return null;
    for (final e in s.exercices) {
      final labels = libellesSeries(e.series);
      for (var i = 0; i < e.series.length; i++) {
        if (!e.series[i].fait) return '${exos.nameOf(e.exerciseId)}, série ${labels[i]}';
      }
    }
    return null;
  }

  /// Une série vient d'être validée : le repos démarre.
  void _serieValidee(SessionExercise se, WorkoutSet set) {
    // L'écriture est finie après que l'écran a pu être refermé.
    if (!mounted) return;
    _avancer(se);
    final exos = context.read<ExerciseRepo>();
    _annoncerRecord(se, set, exos);
    final s = _ed.session;
    if (s != null && s.exercices.every((e) => e.series.every((x) => x.fait))) {
      ReposMinuteur.instance.passer();
      return;
    }
    if (!_ed.finDeSuperset(se.id)) return;
    if (PrefsRepo.maybeInstance?.prefs.minuteurAuto == false) return;
    final sec = reposApresSerie(se, set);
    if (sec <= 0) return;
    final r = _reglages.settings;
    ReposMinuteur.instance.demarrer(sec, titre: _suivante(exos), son: r.sonMinuteur, vibration: r.vibrationMinuteur, volume: r.volumeMinuteur, force: r.forceVibration, voix: r.decompteVocal, repo: context.read<SessionRepo>(), seId: se.id, setId: set.id);
  }

  /// Repères de record de chaque exercice, calculés une fois par séance.
  final _reperes = <String, ReperesRecord>{};

  ReperesRecord _reperesDe(String exerciseId) => _reperes.putIfAbsent(exerciseId, () {
        final id = _ed.session?.id;
        return ReperesRecord.de(exerciseId, context.read<SessionRepo>().sessions.where((x) => !x.enCours && x.id != id));
      });

  /// Le record à annoncer en haut de l'écran.
  final _annonce = ValueNotifier<AnnonceRecord?>(null);

  /// Une série qui bat un record : la ligne passe à l'or (voir la carte), et
  /// le bandeau du haut dit lequel, avec un son.
  void _annoncerRecord(SessionExercise se, WorkoutSet set, ExerciseRepo exos) {
    final r = _reglages.settings;
    if (!r.alerteRecord) return;
    final lignes = _reperesDe(se.exerciseId).recordsDe(set, context.read<ProfileRepo>().unite);
    if (lignes.isEmpty) return;
    if (r.sonMinuteur) unawaited(ReposMinuteur.instance.jouerRecord(r.volumeMinuteur));
    _annonce.value = AnnonceRecord(exercise: exos.byId(se.exerciseId), nom: exos.nameOf(se.exerciseId), lignes: lignes);
  }

  String? _cleRecords;
  int _nbRecordsCalcule = 0;

  /// Nombre de records battus par les séries validées de la séance : le même
  /// calcul que le bilan de fin, donc le même nombre.
  int _nbRecords(WorkoutSession s, UnitePoids u) {
    // Recalculé seulement quand une série validée change.
    final cle = [
      for (final e in s.exercices)
        for (final x in e.series)
          if (x.fait) '${e.exerciseId}:${x.type.name}:${x.poids}:${x.reps}',
    ].join('|');
    if (cle != _cleRecords) {
      _cleRecords = cle;
      _nbRecordsCalcule = Strength.newRecords(s, context.read<SessionRepo>().sessions.where((x) => !x.enCours && x.id != s.id)).length;
    }
    return _nbRecordsCalcule;
  }

  /// Ouvre l'appli de musique choisie dans les réglages.
  Future<void> _musique(String service) async {
    final adresses = service == 'spotify' ? ['spotify:', 'https://open.spotify.com'] : ['https://music.youtube.com'];
    for (final a in adresses) {
      try {
        if (await launchUrl(Uri.parse(a), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) Toasts.error(context, 'Impossible d\'ouvrir ${service == 'spotify' ? 'Spotify' : 'YouTube Music'}');
  }

  Future<void> _ajouter() async {
    final ids = await pickExercises(context, dejaPresents: {for (final e in (_ed.session?.exercices ?? const <SessionExercise>[])) e.exerciseId});
    if (ids == null || ids.isEmpty || !mounted) return;
    final avant = _ed.session?.exercices.length ?? 0;
    await _ed.ajouterExercices(ids, reposSec: _reglages.settings.reposParDefautSec);
    // Rien en cours : le premier exercice ajouté s'ouvre.
    final liste = _ed.session?.exercices ?? const <SessionExercise>[];
    final enCours = liste.where((e) => e.id == _ouvert).firstOrNull;
    if (avant < liste.length && (enCours == null || exerciceTermine(enCours))) _ouvrir(liste[avant].id);
  }

  Future<void> _remplacer(SessionExercise se) async {
    final id = await choisirRemplacant(context, se, session: _ed.session);
    if (id == null || !mounted) return;
    // Des séries déjà validées : on ne les jette pas sans le demander.
    final faites = _ed.exercice(se.id)?.seriesFaites.length ?? 0;
    var garder = false;
    if (faites > 0) {
      final ancien = context.read<ExerciseRepo>().nameOf(se.exerciseId);
      final choix = await showChoiceDialog<String>(
        context,
        title: faites > 1 ? '$faites séries validées' : 'Une série validée',
        message: '« $ancien » a déjà ${faites > 1 ? 'des séries validées' : 'une série validée'}. Que veux-tu en faire ?',
        options: [
          ('garder', faites > 1 ? 'Garder ces séries et continuer avec le nouvel exercice' : 'Garder cette série et continuer avec le nouvel exercice'),
          ('remplacer', faites > 1 ? 'Tout remplacer, ces séries sont perdues' : 'Tout remplacer, cette série est perdue'),
        ],
      );
      if (choix == null || !mounted) return;
      garder = choix == 'garder';
    }
    final etaitOuvert = _ouvert == se.id;
    await _ed.remplacerExercice(se.id, id, garderFaites: garder);
    // L'ancien exercice garde ses séries faites : le nouveau, juste après, s'ouvre.
    final liste = _ed.session?.exercices ?? const <SessionExercise>[];
    final i = liste.indexWhere((e) => e.id == se.id);
    if (etaitOuvert && i >= 0 && exerciceTermine(liste[i])) _ouvrir(_aFaire(i + 1));
  }

  void _disques(SessionExercise se) {
    final top = se.series.where((x) => x.type.counts).map((x) => x.poids ?? 0).fold(0.0, (a, b) => a > b ? a : b);
    context.push('${SeancePaths.disques}?exercice=${se.id}${top > 0 ? '&poids=$top' : ''}');
  }

  void _reordonner() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReordonnerPage(editeur: _ed)));
  }

  Future<void> _terminer() async {
    final s = _ed.session;
    if (s == null) return;
    // « Toutes les séries sont faites » ne suit pas sur le bilan.
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    final faites = s.exercices.fold(0, (a, e) => a + e.series.where((x) => x.fait).length);
    if (faites == 0) {
      final remplies = s.exercices.fold(0, (a, e) => a + e.series.where((x) => (x.reps ?? 0) > 0 || (x.dureeSec ?? 0) > 0).length);
      final choix = await showChoiceDialog<String>(
        context,
        title: 'Aucune série validée',
        message: 'Seules les séries cochées sont gardées. Que veux-tu faire ?',
        options: [
          if (remplies > 0) ('cocher', 'Cocher les ${Fmt.pluriel(remplies, 'série remplie', 'séries remplies')}'),
          ('continuer', 'Continuer la séance'),
          ('abandonner', 'Abandonner la séance'),
        ],
      );
      if (!mounted) return;
      if (choix == 'cocher') {
        await _ed.cocherRemplies();
        if (mounted) context.push(SeancePaths.terminer);
      } else if (choix == 'abandonner') {
        await _abandonner(confirmer: false);
      }
      return;
    }
    context.push(SeancePaths.terminer);
  }

  Future<void> _abandonner({bool confirmer = true}) async {
    final messager = ScaffoldMessenger.maybeOf(context);
    final fait = await abandonnerSeance(context, confirmer: confirmer);
    if (fait) messager?.showSnackBar(const SnackBar(content: Text('Séance abandonnée')));
  }

  Future<void> _partager() async {
    final s = _ed.session;
    if (s == null) return;
    final exos = context.read<ExerciseRepo>();
    final unite = context.read<ProfileRepo>().unite;
    try {
      await SharePlus.instance.share(ShareParams(text: texteSeance(s, exos, unite), subject: s.nom));
    } catch (_) {
      if (mounted) Toasts.error(context, 'Le partage n\'est pas disponible.');
    }
  }

  Future<void> _pause() async {
    final s = _ed.session;
    if (s == null) return;
    final p = PauseSeance.instance;
    if (p.enPause(s)) {
      await p.reprendre(context.read<SessionRepo>());
    } else {
      ReposMinuteur.instance.passer();
      p.mettreEnPause(s, store: context.read<Store>());
    }
  }

  Future<void> _photo() async {
    final source = await menuPanneau<ImageSource>(
      context,
      titre: 'Ajouter une photo',
      actions: const [
        ActionPanneau(ImageSource.camera, 'Prendre une photo', Trait(IconeSeance.photo)),
        ActionPanneau(ImageSource.gallery, 'Choisir dans la galerie', Icon(Icons.photo_library_outlined)),
      ],
    );
    if (source == null || !mounted) return;
    final ajoutes = await MediasSeance.choisir(source: source, video: false);
    if (ajoutes.isEmpty || !mounted) return;
    await _ed.mutate((s) => s.copyWith(medias: [...s.medias, ...ajoutes]));
    if (mounted) Toasts.show(context, ajoutes.length > 1 ? '${ajoutes.length} photos ajoutées à la séance' : 'Photo ajoutée à la séance');
  }

  Future<void> _notes() async {
    final t = await showTextInputDialog(context, title: 'Notes de la séance', initial: _ed.session?.notes ?? '', hint: 'Forme du jour, douleurs, réglages à retenir...', maxLines: 5, maxLength: 1000);
    if (t == null) return;
    await _ed.mutate(
      (s) => WorkoutSession(
        id: s.id,
        nom: s.nom,
        debut: s.debut,
        fin: s.fin,
        routineId: s.routineId,
        programId: s.programId,
        exercices: s.exercices,
        notes: t.trim().isEmpty ? null : t.trim(),
        ressenti: s.ressenti,
        photo: s.photo,
        source: s.source,
        type: s.type,
        medias: s.medias,
      ),
    );
  }

  /// Bouton « Plus » : partager, pause, photo, notes, réglages, abandonner.
  Future<void> _menu() async {
    final enPause = PauseSeance.instance.enPause(_ed.session);
    final v = await menuPanneau<String>(
      context,
      actions: [
        const ActionPanneau('partager', 'Partager la séance', Trait(IconeSeance.partager)),
        ActionPanneau('pause', enPause ? 'Reprendre la séance' : 'Mettre la séance en pause', const Trait(IconeSeance.pause)),
        const ActionPanneau('photo', 'Ajouter une photo', Trait(IconeSeance.photo)),
        const ActionPanneau('notes', 'Ajouter des notes', Trait(IconeSeance.crayon)),
        const ActionPanneau('reglages', 'Réglages de la séance', Trait(IconeSeance.reglages), filetAvant: true),
        const ActionPanneau('abandon', 'Abandonner la séance', Trait(IconeSeance.corbeille), destructif: true, filetAvant: true),
      ],
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'partager':
        await _partager();
      case 'pause':
        await _pause();
      case 'photo':
        await _photo();
      case 'notes':
        await _notes();
      case 'reglages':
        await _reglagesSeance();
      case 'abandon':
        await _abandonner();
    }
  }

  Future<void> _reglagesSeance() async {
    final r = _reglages.settings;
    final v = await menuPanneau<String>(
      context,
      titre: 'Réglages de la séance',
      actions: [
        const ActionPanneau('nom', 'Renommer la séance', Trait(IconeSeance.crayon)),
        const ActionPanneau('ordre', 'Réordonner les exercices', Icon(Icons.reorder_rounded)),
        const ActionPanneau('disques', 'Calculateur de disques', Icon(Icons.calculate_outlined)),
        ActionPanneau('rpe', r.afficherRpe ? 'Masquer la colonne ${r.effortRir ? 'RIR' : 'RPE'}' : 'Afficher la colonne ${r.effortRir ? 'RIR' : 'RPE'}', const Icon(Icons.speed_rounded)),
        const ActionPanneau('cocher', 'Cocher les séries remplies', Icon(Icons.done_all_rounded)),
        ActionPanneau(
          'musique',
          switch (r.musique) { 'spotify' => 'Bouton Spotify affiché', 'youtube' => 'Bouton YouTube Music affiché', _ => 'Afficher un bouton musique' },
          r.musique == null ? const Icon(Icons.music_note_rounded) : LogoMusique(r.musique!, size: 22),
        ),
        const ActionPanneau('historique', 'Historique des séances', Icon(Icons.history_rounded), filetAvant: true),
      ],
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'nom':
        final t = await showTextInputDialog(context, title: 'Nom de la séance', initial: _ed.session?.nom ?? '', maxLength: 60);
        if (t != null && t.trim().isNotEmpty) await _ed.mutate((s) => s.copyWith(nom: t.trim()));
      case 'ordre':
        _reordonner();
      case 'disques':
        context.push(SeancePaths.disques);
      case 'rpe':
        await _reglages.update((s) => s.copyWith(afficherRpe: !s.afficherRpe));
      case 'cocher':
        final n = await _ed.cocherRemplies();
        if (mounted) Toasts.show(context, n == 0 ? 'Aucune série remplie à cocher' : Fmt.pluriel(n, 'série cochée', 'séries cochées'));
      case 'musique':
        final m = await menuPanneau<String>(
          context,
          titre: 'Bouton musique',
          actions: const [
            ActionPanneau('spotify', 'Spotify', LogoMusique('spotify', size: 22)),
            ActionPanneau('youtube', 'YouTube Music', LogoMusique('youtube', size: 22)),
            ActionPanneau('aucun', 'Aucun bouton', Icon(Icons.close_rounded), filetAvant: true),
          ],
        );
        if (m != null) await _reglages.update((s) => m == 'aucun' ? s.copyWith(sansMusique: true) : s.copyWith(musique: m));
      case 'historique':
        context.push(SeancePaths.historique);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final rpe = context.watch<SettingsRepo>().settings.afficherRpe;
    final repo = context.read<SessionRepo>();
    final routines = context.watch<RoutineRepo>();
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    if (clavier != _clavier) {
      _clavier = clavier;
      _cadrerSaisie();
    }
    final c = context.colors;
    return ListenableBuilder(
      listenable: _ed,
      builder: (context, _) {
        final s = _ed.session;
        if (s == null) return const SizedBox.shrink();
        final routine = s.routineId == null ? null : routines.byId(s.routineId!);
        final large = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
        final liste = _liste(context, s, exos, unite, rpe, repo, routine);
        final colonne = Column(
          children: [
            _BarreHaut(onReduire: () => reduireSeance(context), onTerminer: _terminer, musique: context.watch<SettingsRepo>().settings.musique, onMusique: _musique),
            Expanded(child: liste),
            // Posé sous la liste (donc au-dessus du clavier), jamais par-dessus les séries.
            if (_annulable != null)
              _BandeauAnnuler(
                message: _annulable!.message,
                onAnnuler: () {
                  _annulable?.annuler();
                  _fermerAnnulable();
                },
              ),
          ],
        );
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
            child: large
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: colonne),
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        child: _VoletDroit(session: s, exos: exos),
                      ),
                    ],
                  )
                : colonne,
                ),
                // L'annonce d'un record, par-dessus la barre du haut.
                Positioned(top: k(6), left: 0, right: 0, child: Center(child: BandeauRecord(annonce: _annonce))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _liste(BuildContext context, WorkoutSession s, ExerciseRepo exos, UnitePoids unite, bool rpe, SessionRepo repo, Routine? routine) {
    if (!exos.loaded) return const SkeletonList(count: 4);
    final c = context.colors;
    List<PlannedSet>? plan(SessionExercise e) => routine?.exercices.where((r) => r.exerciseId == e.exerciseId).firstOrNull?.series;
    _cles.removeWhere((id, _) => !s.exercices.any((e) => e.id == id));
    // Tout défile ensemble : l'encadré, la liste des exercices, les deux boutons.
    return SingleChildScrollView(
      key: const ValueKey('defile-seance'),
      controller: _defile,
      padding: EdgeInsets.only(top: k(6), bottom: k(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, 0, margeSeance, k(14)),
          child: _Chiffres(session: s, unite: unite, records: context.watch<SettingsRepo>().settings.alerteRecord ? _nbRecords(s, unite) : 0),
        ),
        if (s.exercices.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(margeSeance * 1.5, k(36), margeSeance * 1.5, k(36)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconeHaltere(size: k(34), color: c.text3),
                SizedBox(height: k(12)),
                Text(
                  'Séance vide',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(16), fontWeight: FontWeight.w700, color: c.text),
                ),
                SizedBox(height: k(4)),
                Text(
                  'Ajoute ton premier exercice : les charges de ta dernière fois seront reprises.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
                ),
              ],
            ),
          ),
        for (var i = 0; i < s.exercices.length; i++)
          ExerciceCarte(
            key: _cles.putIfAbsent(s.exercices[i].id, GlobalKey.new),
            editeur: _ed,
            se: s.exercices[i],
            exercise: exos.byId(s.exercices[i].exerciseId),
            unite: unite,
            reperes: context.watch<SettingsRepo>().settings.alerteRecord ? _reperesDe(s.exercices[i].exerciseId) : null,
            afficherRpe: rpe,
            effortRir: context.watch<SettingsRepo>().settings.effortRir,
            precedent: repo.lastFor(s.exercices[i].exerciseId, routineId: context.watch<SettingsRepo>().settings.precedentMemeRoutine ? s.routineId : null)?.seriesFaites,
            plan: plan(s.exercices[i]),
            position: i,
            total: s.exercices.length,
            ouvert: _ouvert == s.exercices[i].id,
            onBascule: () => _basculer(s.exercices[i].id),
            onAnnulable: _montrerAnnulable,
            onSerieValidee: _serieValidee,
            onRemplacer: () => _remplacer(s.exercices[i]),
            onDisques: () => _disques(s.exercices[i]),
            onReordonner: _reordonner,
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, k(16), margeSeance, 0),
          child: BoutonSeance(label: 'Ajouter des exercices', fond: c.bouton, encre: c.onBouton, onTap: _ajouter),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, 0),
          child: BoutonSeance(label: 'Plus', fond: c.surface2, encre: c.text, onTap: _menu),
        ),
      ],
      ),
    );
  }
}

/// Repos à lancer après [set] : celui de l'exercice, une minute au plus après
/// un échauffement.
int reposApresSerie(SessionExercise se, WorkoutSet set) {
  var sec = se.reposSec;
  if (set.type == SetType.echauffement && sec > 60) sec = 60;
  return sec < 0 ? 0 : sec;
}

/// Barre du haut : réduire, pilule du minuteur, « Terminer ».
class _BarreHaut extends StatelessWidget {
  const _BarreHaut({required this.onReduire, required this.onTerminer, this.musique, this.onMusique});

  final VoidCallback onReduire;
  final VoidCallback onTerminer;

  /// Appli de musique à ouvrir (« spotify », « youtube »), null : pas de bouton.
  final String? musique;
  final ValueChanged<String>? onMusique;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margeSeance, vertical: k(10)),
      child: Row(
        children: [
          BoutonRond(
            label: 'Réduire la séance',
            onTap: onReduire,
            child: Trait(IconeSeance.chevronBas, size: k(18), epaisseur: 2),
          ),
          SizedBox(width: k(8)),
          // Sur un écran très étroit, la pilule se réduit plutôt que de pousser « Terminer » hors de l'écran.
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PiluleMinuteur()),
            ),
          ),
          SizedBox(width: k(8)),
          if (musique != null) ...[
            Semantics(
              button: true,
              label: musique == 'spotify' ? 'Ouvrir Spotify' : 'Ouvrir YouTube Music',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onMusique?.call(musique!),
                child: Padding(padding: EdgeInsets.all(k(3)), child: LogoMusique(musique!, size: k(32))),
              ),
            ),
            SizedBox(width: k(8)),
          ],
          BoutonSeance(label: 'Terminer', fond: c.bouton, encre: c.onBouton, hauteur: k(38), taille: k(13), marge: k(18), onTap: onTerminer),
        ],
      ),
    );
  }
}

/// Pilule du minuteur de repos : bleue, elle se vide vers la droite à mesure
/// que le repos passe ; grise au repos. Un toucher ouvre le minuteur en grand.
class PiluleMinuteur extends StatelessWidget {
  const PiluleMinuteur({super.key});

  @override
  Widget build(BuildContext context) {
    final m = ReposMinuteur.instance;
    final c = context.colors;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final reste = m.actif ? (1 - m.progression).clamp(0.0, 1.0) : 0.0;
        final texte = m.actif ? _court(m.restant) : 'Repos';
        return Semantics(
          button: true,
          label: m.actif ? 'Repos en cours, $texte restantes' : 'Minuteur de repos',
          child: GestureDetector(
            onTap: () => context.push(SeancePaths.repos),
            child: Container(
              height: k(36),
              padding: EdgeInsets.symmetric(horizontal: k(14)),
              decoration: BoxDecoration(
                borderRadius: AppTokens.radiusPill,
                // La part bleue est le temps qui reste.
                gradient: LinearGradient(colors: [c.minuteur, c.minuteur, c.surface3, c.surface3], stops: [0, reste, reste, 1]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Trait(IconeSeance.minuteur, size: k(16), color: c.text),
                  SizedBox(width: k(6)),
                  Text(
                    texte,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// « 1:24 ».
  static String _court(Duration d) {
    final total = (d.inMilliseconds / 1000).ceil();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}

/// Durée, volume, séries : l'encadré en tête de la page, la durée en bleu.
class _Chiffres extends StatelessWidget {
  const _Chiffres({required this.session, required this.unite, this.records = 0});
  final WorkoutSession session;
  final UnitePoids unite;

  /// Records battus pendant la séance : une quatrième colonne dès le premier.
  final int records;

  @override
  Widget build(BuildContext context) {
    final faites = seriesComptees(session);
    return ListenableBuilder(
      listenable: PauseSeance.instance,
      builder: (context, _) => EncadreChiffres(
        valeurs: [
          (
            PauseSeance.instance.enPause(session) ? 'En pause' : 'Durée',
            TexteVivant(
              () => chronoSeance(PauseSeance.instance.ecoule(session)),
              style: EncadreChiffres.chiffre(context, couleur: context.colors.minuteur),
            ),
          ),
          ('Volume', Text(volumeSeance(session.volume, unite))),
          ('Séries', Text('$faites')),
          if (records > 0)
            (
              'Records',
              Row(mainAxisSize: MainAxisSize.min, children: [Ecusson.record(largeur: k(18)), SizedBox(width: k(4)), Text('$records')]),
            ),
        ],
      ),
    );
  }
}

/// « Série supprimée / Annuler » : une bande dans la mise en page, sous la
/// liste, qui ne recouvre rien.
class _BandeauAnnuler extends StatelessWidget {
  const _BandeauAnnuler({required this.message, required this.onAnnuler});

  final String message;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(margeSeance, k(6), margeSeance, k(8)),
      child: Semantics(
        liveRegion: true,
        child: Container(
          height: k(42),
          padding: EdgeInsets.only(left: k(14), right: k(4)),
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(14))),
          child: Row(
            children: [
              Trait(IconeSeance.corbeille, size: k(17), color: c.text2),
              SizedBox(width: k(10)),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), color: c.text),
                ),
              ),
              TextButton(
                onPressed: onAnnuler,
                style: TextButton.styleFrom(foregroundColor: c.text, padding: EdgeInsets.symmetric(horizontal: k(12))),
                child: Text('Annuler', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w700, color: c.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Volet de droite sur le Fold ouvert : les muscles de la séance, en direct.
class _VoletDroit extends StatelessWidget {
  const _VoletDroit({required this.session, required this.exos});
  final WorkoutSession session;
  final ExerciseRepo exos;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parMuscle = Strength.setsParMuscle([session], exos.byId);
    final max = parMuscle.values.fold(0.0, (a, b) => a > b ? a : b);
    final intens = {for (final e in parMuscle.entries) e.key: max == 0 ? 0.0 : (0.25 + 0.75 * e.value / max)};
    // En paysage sur un écran bas, les personnages rétrécissent pour tenir
    // dans la carte au lieu d'en déborder.
    return LayoutBuilder(builder: (context, box) {
      final place = box.maxHeight.isFinite ? box.maxHeight - k(10) - k(18) - 2 * k(14) - k(10) - k(16) : 300.0;
      final hauteur = place.clamp(80.0, 300.0);
      return Padding(
      padding: EdgeInsets.fromLTRB(0, k(10), margeSeance, k(18)),
      child: Container(
        padding: EdgeInsets.all(k(14)),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(18))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MUSCLES TRAVAILLÉS',
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10), fontWeight: FontWeight.w600, letterSpacing: 1.5, color: c.text2),
            ),
            SizedBox(height: k(10)),
            if (parMuscle.isEmpty)
              Text(
                'Valide une série pour voir les muscles s\'allumer.',
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), color: c.text3),
              )
            else
              Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: BodyMapDual(key: const ValueKey('volet-muscles'), intensities: intens, height: hauteur)),
              ),
          ],
        ),
      ),
    );
    });
  }
}
