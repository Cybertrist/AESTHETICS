import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/chrono.dart';
import '../logic/editeur.dart';
import '../logic/envoi_sante.dart';
import '../logic/medias.dart';
import '../logic/repos_minuteur.dart';
import '../seance_paths.dart';
import '../widgets/habillage.dart';
import '../widgets/mini_barre.dart';
import '../widgets/panneaux.dart';

/// Maquette « Terminer la séance » : un seul écran pour clore. Le nom, une
/// note, des photos et des vidéos, la date, la durée, le type d'activité,
/// l'envoi vers Health Connect, puis « Enregistrer ».
class TerminerPage extends StatefulWidget {
  const TerminerPage({super.key});

  @override
  State<TerminerPage> createState() => _TerminerPageState();
}

class _TerminerPageState extends State<TerminerPage> {
  late final TextEditingController _nom;
  final _notes = TextEditingController();
  final _focusNom = FocusNode();

  /// Corrections faites à la main ; sans elles, le début et la durée réels.
  DateTime? _debut;
  Duration? _duree;
  late final DateTime _ouverture = DateTime.now();
  late TypeSeance _type;
  late List<SessionMedia> _medias;
  late bool _envoiSante;
  bool _enCours = false;

  /// Corrections de date et de durée gardées le temps de la séance : revenir
  /// à la saisie puis rouvrir cet écran ne les perd pas.
  static final _corrections = <String, ({DateTime? debut, Duration? duree})>{};

  late final SessionRepo _repo;

  /// La séance telle qu'elle était au moment d'enregistrer : l'écran la garde
  /// à l'affichage pendant que le dépôt la range dans l'historique.
  WorkoutSession? _figee;

  @override
  void initState() {
    super.initState();
    _repo = context.read<SessionRepo>();
    final a = _repo.active;
    _nom = TextEditingController(text: a?.nom ?? 'Séance');
    _notes.text = a?.notes ?? '';
    _type = a?.type ?? TypeSeance.musculation;
    _medias = [...?a?.medias];
    _envoiSante = context.read<SettingsRepo>().settings.santeConnectee;
    final c = a == null ? null : _corrections[a.id];
    _debut = c?.debut;
    _duree = c?.duree;
  }

  /// Nom saisi, ou celui de la séance si le champ est vide.
  String _nomSaisi(WorkoutSession a) => _nom.text.trim().isEmpty ? a.nom : _nom.text.trim();

  /// Note saisie ; une note effacée devient vide (et non l'ancienne note).
  String? _noteSaisie(WorkoutSession a) {
    final t = _notes.text.trim();
    return t.isEmpty && a.notes == null ? null : t;
  }

  /// Range dans la séance en cours ce qui a été saisi ici (nom, note, type,
  /// médias), pour le retrouver après un retour en arrière ou une fermeture
  /// de l'appli.
  Future<void> _garder() async {
    final a = _repo.active;
    if (a == null || _enCours) return;
    _corrections[a.id] = (debut: _debut, duree: _duree);
    final memes = a.medias.length == _medias.length && [for (var i = 0; i < _medias.length; i++) a.medias[i] == _medias[i]].every((x) => x);
    if (a.nom == _nomSaisi(a) && a.notes == _noteSaisie(a) && a.type == _type && memes) return;
    await _repo.updateActive(a.copyWith(nom: _nomSaisi(a), notes: _noteSaisie(a), type: _type, medias: _medias));
  }

  @override
  void dispose() {
    _nom.dispose();
    _notes.dispose();
    _focusNom.dispose();
    super.dispose();
  }

  /// Début de la séance : la correction, sinon le début réel ; reculé au
  /// besoin pour qu'une durée allongée ne fasse pas finir la séance dans le
  /// futur.
  DateTime _debutDe(WorkoutSession s) {
    final d = _debut ?? s.debut;
    final auPlusTard = DateTime.now().subtract(_dureeDe(s));
    return d.isAfter(auPlusTard) ? auPlusTard : d;
  }

  /// Durée d'entraînement : la correction, sinon le temps écoulé (pauses
  /// déduites) à l'ouverture de l'écran.
  Duration _dureeDe(WorkoutSession s) => _duree ?? PauseSeance.instance.ecoule(s, maintenant: _ouverture);

  Future<void> _choisirDate(WorkoutSession s) async {
    final depart = _debutDe(s);
    final now = DateTime.now();
    final jour = await showDatePicker(
      context: context,
      initialDate: depart,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Jour de la séance',
    );
    if (jour == null || !mounted) return;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(depart), helpText: 'Heure de début');
    if (h == null || !mounted) return;
    var d = DateTime(jour.year, jour.month, jour.day, h.hour, h.minute);
    if (d.isAfter(now)) d = now;
    setState(() {
      // La durée affichée ne doit pas bouger quand on déplace le début.
      _duree ??= _dureeDe(s);
      _debut = d;
    });
    await _garder();
  }

  Future<void> _choisirDuree(WorkoutSession s) async {
    final d = await choisirDuree(context, _dureeDe(s));
    if (d == null || !mounted) return;
    if (d.inSeconds <= 0) {
      Toasts.error(context, 'La durée doit dépasser zéro.');
      return;
    }
    setState(() => _duree = d);
    await _garder();
  }

  Future<void> _choisirType() async {
    final t = await choisirTypeSeance(context, _type);
    if (t == null || !mounted) return;
    setState(() => _type = t);
    await _garder();
  }

  Future<void> _ajouterMedia() async {
    final choix = await menuPanneau<(ImageSource, bool)>(
      context,
      titre: 'Photos et vidéos',
      actions: const [
        ActionPanneau((ImageSource.camera, false), 'Prendre une photo', Trait(IconeSeance.photo)),
        ActionPanneau((ImageSource.gallery, false), 'Choisir des photos', Icon(Icons.photo_library_outlined)),
        ActionPanneau((ImageSource.camera, true), 'Filmer une vidéo', Icon(Icons.videocam_outlined), filetAvant: true),
        ActionPanneau((ImageSource.gallery, true), 'Choisir une vidéo', Icon(Icons.video_library_outlined)),
      ],
    );
    if (choix == null || !mounted) return;
    final ajoutes = await MediasSeance.choisir(source: choix.$1, video: choix.$2);
    if (ajoutes.isEmpty || !mounted) return;
    setState(() => _medias = [..._medias, ...ajoutes]);
    await _garder();
  }

  Future<void> _retirerMedia(SessionMedia m) async {
    setState(() => _medias = [for (final x in _medias) if (x != m) x]);
    // La séance en cours oublie le média avant que son fichier disparaisse.
    await _garder();
    await MediasSeance.supprimer(m);
  }

  Future<void> _abandonner() async {
    final fait = await abandonnerSeance(context);
    if (fait && mounted) context.go('/');
  }

  Future<void> _enregistrer() async {
    final repo = context.read<SessionRepo>();
    final programmes = context.read<ProgramRepo>();
    final a = repo.active;
    if (a == null || _enCours) return;
    setState(() {
      _enCours = true;
      _figee = a;
    });
    try {
      ReposMinuteur.instance.passer();
      final debut = _debutDe(a);
      final fin = debut.add(_dureeDe(a));
      PauseSeance.instance.oublier();
      final res = await repo.finishActive(
        nom: _nomSaisi(a),
        notes: _noteSaisie(a),
        debut: debut,
        fin: fin,
        type: _type,
        medias: _medias,
      );
      if (res == null) {
        if (mounted) context.go('/');
        return;
      }
      _corrections.remove(a.id);
      final pid = res.session.programId;
      if (pid != null) {
        // La séance est déjà rangée : un programme qui n'avance pas ne doit
        // pas la faire passer pour perdue.
        try {
          await programmes.advance(pid);
        } catch (_) {}
      }
      // L'envoi vers Health Connect ne retarde ni ne bloque la suite.
      if (_envoiSante) {
        EnvoiSante.envoyer(res.session).ignore();
      }
      if (!mounted) return;
      // D'abord la carte « l'équivalent », puis le bilan ; sans charge
      // soulevée, le bilan directement.
      context.go(res.session.volume > 0 ? SeancePaths.equivalent(res.session.id) : SeancePaths.resume(res.session.id, nouveau: true));
    } catch (_) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _figee = null;
        });
        Toasts.error(context, 'La séance n\'a pas pu être enregistrée. Réessaie.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SessionRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final s = repo.active ?? (_enCours ? _figee : null);
    if (s == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              const EnTeteSeance(titre: 'Terminer la séance'),
              Expanded(
                child: EmptyState(
                  icon: Icons.flag_rounded,
                  title: 'Aucune séance en cours',
                  message: 'Elle a peut-être déjà été enregistrée.',
                  actionLabel: 'Voir l\'historique',
                  onAction: () => context.pushReplacement(SeancePaths.historique),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final faites = s.exercices.fold(0, (a, e) => a + e.series.where((x) => x.fait).length);
    // Même règle que `cocherRemplies` : répétitions, durée ou distance.
    final remplies = s.exercices.fold(
        0, (a, e) => a + e.series.where((x) => !x.fait && ((x.reps ?? 0) > 0 || (x.dureeSec ?? 0) > 0 || (x.distanceM ?? 0) > 0)).length);
    final debut = _debutDe(s);
    final gras = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w600, color: c.text);

    return PopScope(
      // Retour à la saisie : ce qui a été écrit ici est gardé dans la séance.
      onPopInvokedWithResult: (parti, _) {
        if (parti) _garder();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  EnTeteSeance(
                    titre: 'Terminer la séance',
                    // Même compte que l'encadré de la séance : sans les échauffements.
                    sousTitre: '${Fmt.pluriel(seriesComptees(s), 'série')} · ${volumeSeance(s.volume, unite)}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(10)),
                      children: [
                        // Nom de la séance.
                        _Champ(
                          onTap: _focusNom.requestFocus,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nom,
                                  focusNode: _focusNom,
                                  maxLength: 60,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(14), fontWeight: FontWeight.w700, color: c.text),
                                  decoration: _nu('Nom de la séance', c),
                                ),
                              ),
                              Trait(IconeSeance.crayon, size: k(18), color: c.text2),
                            ],
                          ),
                        ),
                        SizedBox(height: k(8)),
                        // Note libre.
                        _Champ(
                          child: TextField(
                            controller: _notes,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, color: c.text),
                            decoration: _nu('Comment s\'est passée ta séance ?', c),
                          ),
                        ),
                        SizedBox(height: k(8)),
                        if (_medias.isEmpty)
                          _ZoneMedias(onTap: _ajouterMedia)
                        else
                          _BandeMedias(medias: _medias, onAjouter: _ajouterMedia, onRetirer: _retirerMedia),
                        SizedBox(height: k(8)),
                        _Champ(
                          onTap: () => _choisirDate(s),
                          child: Row(
                            children: [
                              Trait(IconeSeance.calendrier, size: k(18), color: c.text2),
                              SizedBox(width: k(12)),
                              Expanded(child: Text('${Fmt.relatif(debut)} à ${Fmt.heure(debut)}', style: gras)),
                              Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                            ],
                          ),
                        ),
                        SizedBox(height: k(8)),
                        _Champ(
                          onTap: () => _choisirDuree(s),
                          child: Row(
                            children: [
                              Trait(IconeSeance.minuteur, size: k(18), color: c.text2),
                              SizedBox(width: k(12)),
                              Expanded(child: Text(dureeLongue(_dureeDe(s)), style: gras)),
                              Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                            ],
                          ),
                        ),
                        SizedBox(height: k(8)),
                        _Champ(
                          onTap: _choisirType,
                          child: Row(
                            children: [
                              IconeTypeSeance(_type, size: k(18), color: c.text2),
                              SizedBox(width: k(12)),
                              Expanded(child: Text(_type.label, style: gras)),
                              Trait(IconeSeance.chevronDroit, size: k(14), epaisseur: 2, color: c.text3),
                            ],
                          ),
                        ),
                        SizedBox(height: k(8)),
                        _Champ(
                          onTap: () => setState(() => _envoiSante = !_envoiSante),
                          child: Row(
                            children: [
                              IconeCoeur(size: k(18), color: c.text2),
                              SizedBox(width: k(12)),
                              Expanded(child: Text('Envoyer vers Health Connect', style: gras.copyWith(height: 1.35))),
                              SizedBox(width: k(8)),
                              Interrupteur(
                                value: _envoiSante,
                                label: _envoiSante ? 'Envoi activé' : 'Envoi désactivé',
                                onChanged: (v) => setState(() => _envoiSante = v),
                              ),
                            ],
                          ),
                        ),
                        if (remplies > 0) ...[
                          SizedBox(height: k(12)),
                          Center(
                            child: InkWell(
                              borderRadius: AppTokens.radius8,
                              onTap: () async {
                                final ed = EditeurDirect(repo);
                                await ed.cocherRemplies();
                                ed.dispose();
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: k(6), vertical: k(4)),
                                child: Text(
                                  remplies > 1 ? '$remplies séries remplies ne sont pas cochées : les garder' : 'Une série remplie n\'est pas cochée : la garder',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w600, color: c.text2),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Center(
                          child: InkWell(
                            borderRadius: AppTokens.radius8,
                            onTap: _abandonner,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(k(10), k(12), k(10), k(6)),
                              child: Text(
                                'Abandonner la séance',
                                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w600, color: c.error),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(margeSeance, k(10), margeSeance, k(18)),
                    child: BoutonSeance(
                      label: faites == 0 ? 'Valide au moins une série' : 'Enregistrer',
                      fond: c.bouton,
                      encre: c.onBouton,
                      onTap: _enCours || faites == 0 ? null : _enregistrer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Champ de saisie sans habillage : le cadre est celui de [_Champ].
  InputDecoration _nu(String hint, AppColors c) => InputDecoration(
        isDense: true,
        isCollapsed: true,
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), fontWeight: FontWeight.w400, color: c.text2),
        filled: false,
        contentPadding: EdgeInsets.symmetric(vertical: k(4)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );
}

/// Ligne encadrée de la maquette (`.fld`) : 48 de haut, cadre fin, coins de 14.
class _Champ extends StatelessWidget {
  const _Champ({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rayon = BorderRadius.circular(k(14));
    return InkWell(
      borderRadius: rayon,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: k(48)),
        padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(4)),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(borderRadius: rayon, border: Border.all(color: c.surface3, width: 1.5)),
        child: child,
      ),
    );
  }
}

/// Zone en pointillés « Ajouter des photos ou des vidéos » (`.drop`).
class _ZoneMedias extends StatelessWidget {
  const _ZoneMedias({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rayon = k(16);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(rayon),
        onTap: onTap,
        child: CustomPaint(
          painter: _PointillesPainter(color: c.frame, rayon: rayon),
          child: SizedBox(
            height: k(72),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Trait(IconeSeance.photo, size: k(22), color: c.text2),
                SizedBox(height: k(6)),
                Text(
                  'Ajouter des photos ou des vidéos',
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w600, color: c.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointillesPainter extends CustomPainter {
  _PointillesPainter({required this.color, required this.rayon});
  final Color color;
  final double rayon;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final contour = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(rayon)));
    const trait = 5.0;
    const vide = 4.0;
    for (final m in contour.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += trait + vide) {
        canvas.drawPath(m.extractPath(d, (d + trait).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PointillesPainter old) => old.color != color || old.rayon != rayon;
}

/// Les photos et vidéos déjà jointes, à faire défiler, suivies d'une tuile
/// pour en ajouter.
class _BandeMedias extends StatelessWidget {
  const _BandeMedias({required this.medias, required this.onAjouter, required this.onRetirer});

  final List<SessionMedia> medias;
  final VoidCallback onAjouter;
  final ValueChanged<SessionMedia> onRetirer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cote = k(72);
    final rayon = BorderRadius.circular(k(12));
    return SizedBox(
      height: cote,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final m in medias)
            Padding(
              padding: EdgeInsets.only(right: k(8)),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: rayon,
                    child: Container(
                      width: cote,
                      height: cote,
                      color: c.surface2,
                      child: m.video
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: k(26),
                                  height: k(26),
                                  decoration: BoxDecoration(color: c.bouton, shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Trait(IconeSeance.lecture, size: k(11), plein: true, color: c.onBouton),
                                ),
                                SizedBox(height: k(4)),
                                Text(
                                  m.dureeSec == null ? 'Vidéo' : Fmt.chrono(Duration(seconds: m.dureeSec!)),
                                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10), fontWeight: FontWeight.w600, color: c.text2),
                                ),
                              ],
                            )
                          : Image.file(
                              File(m.chemin),
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, _, _) => Center(child: Trait(IconeSeance.photo, size: k(22), color: c.text3)),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: m.video ? 'Retirer la vidéo' : 'Retirer la photo',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onRetirer(m),
                        child: Padding(
                          padding: EdgeInsets.all(k(4)),
                          child: Container(
                            width: k(20),
                            height: k(20),
                            decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.6), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Trait(IconeSeance.croix, size: k(10), epaisseur: 2.4, color: c.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Semantics(
            button: true,
            label: 'Ajouter une photo ou une vidéo',
            child: InkWell(
              borderRadius: rayon,
              onTap: onAjouter,
              child: CustomPaint(
                painter: _PointillesPainter(color: c.frame, rayon: k(12)),
                child: SizedBox(width: cote, height: cote, child: Center(child: Trait(IconeSeance.plus, size: k(18), epaisseur: 2, color: c.text2))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
