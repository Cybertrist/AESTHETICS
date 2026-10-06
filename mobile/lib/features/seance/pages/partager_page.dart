import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/analyse.dart';
import '../logic/partage.dart';
import '../widgets/cartes_partage.dart';

/// Les cartes du carrousel. Le rang sert d'adresse (`?carte=3`) : les cinq
/// premières gardent le leur, la carte des records vient après.
enum CartePartage { resume, equivalent, detail, serie, autocollant, records }

/// Carrousel « Partager » (écrans 24 à 28 de la maquette) : cinq cartes à
/// faire défiler, chacune exportée en image, plus celle des records quand la
/// séance en a battu.
class PartagerPage extends StatefulWidget {
  const PartagerPage({super.key, required this.sessionId, this.carte = 0});

  final String sessionId;

  /// Carte montrée en premier (0 : résumé, 1 : équivalent, 2 : détail,
  /// 3 : série de semaines, 4 : autocollant sur photo, 5 : records), quelle
  /// que soit sa place dans le carrousel.
  final int carte;

  /// Les cartes toujours présentes ; celle des records s'y ajoute.
  static const nombre = 5;

  /// Les cartes à l'écran, dans l'ordre : les records suivent le résumé.
  static List<CartePartage> ordre({required bool records}) => [
        CartePartage.resume,
        if (records) CartePartage.records,
        CartePartage.equivalent,
        CartePartage.detail,
        CartePartage.serie,
        CartePartage.autocollant,
      ];

  @override
  State<PartagerPage> createState() => PartagerPageState();
}

class PartagerPageState extends State<PartagerPage> {
  /// Les cartes à l'écran ; connues au premier affichage, avec la séance.
  List<CartePartage> _ordre = PartagerPage.ordre(records: false);
  int _page = 0;
  PageController? _pages;
  final _cles = {for (final c in CartePartage.values) c: GlobalKey()};
  String? _photo;
  bool _photoChoisie = false;

  /// La photo a été retirée : la carte revient au damier « Ta photo ici ».
  bool _sansPhoto = false;
  bool _envoi = false;

  /// Clé du `RepaintBoundary` de la carte affichée (pour l'export).
  GlobalKey get cleCourante => _cles[_ordre[_page]]!;

  /// Nombre de cartes à faire défiler (cinq, six avec les records).
  int get nombreCartes => _ordre.length;

  /// Range les cartes et, la première fois, ouvre sur celle demandée.
  PageController _controleur(List<CartePartage> ordre) {
    _ordre = ordre;
    final dernier = ordre.length - 1;
    if (_pages == null) {
      final voulue = CartePartage.values[widget.carte.clamp(0, CartePartage.values.length - 1)];
      final i = ordre.indexOf(voulue);
      // Records demandés sur une séance sans record : la dernière carte, comme
      // pour tout rang trop grand.
      _page = i < 0 ? dernier : i;
    } else if (_page > dernier) {
      _page = dernier;
    }
    return _pages ??= PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _fermer() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// Choisit la photo de la carte « sur ta photo », puis l'affiche.
  Future<void> _choisirPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 92);
      if (x == null || !mounted) return;
      setState(() {
        _photo = x.path;
        _photoChoisie = true;
        _sansPhoto = false;
      });
      _pages?.animateToPage(_ordre.length - 1, duration: AppTokens.normal, curve: Curves.easeOut);
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible d\'ouvrir tes photos.');
    }
  }

  Future<void> _partager(String nom) async {
    if (_envoi) return;
    setState(() => _envoi = true);
    try {
      final png = await capturerCarte(cleCourante);
      if (png == null) throw StateError('carte absente');
      await partagerImage(png, nom: 'aesthetic-seance-${_page + 1}', texte: nom);
    } catch (_) {
      if (mounted) Toasts.error(context, 'Le partage n\'est pas disponible.');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<SessionRepo>();
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final s = repo.byId(widget.sessionId);
    if (s == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Séance introuvable',
            message: 'Elle a peut-être été supprimée.',
            actionLabel: 'Fermer',
            onAction: _fermer,
          ),
        ),
      );
    }
    final bilan = BilanSeance.calculer(s, repo, exos);
    final intensites = bilan.intensites;
    final volume = volumeEntier(s.volume, unite);
    final duree = Fmt.duree(s.duree);
    final series = s.nbSeriesFaites;
    final semaines = repo.streakWeeks();
    final (libelle, phrase) = textesSerie(semaines);
    final photoSeance = s.medias.where((m) => !m.video).map((m) => m.chemin).firstOrNull;
    // La photo choisie ici, sinon celle de la séance ; aucune : le damier.
    final photo = _sansPhoto ? null : (_photoChoisie ? _photo : photoSeance);
    final e = equivalentPour(s.volume, graine: graineEquivalent(s), mois: true);
    final records = recordsPartage(bilan, exos, unite);
    final ordre = PartagerPage.ordre(records: records.isNotEmpty);
    final pages = _controleur(ordre);
    final retirable = photo != null && ordre[_page] == CartePartage.autocollant;

    final parCarte = <CartePartage, Widget>{
      CartePartage.resume: CarteResume(
        volume: s.volume > 0 ? volume : null,
        exercices: s.exercices.where((e) => e.seriesFaites.any((x) => x.type.counts)).length,
        duree: duree,
        series: series,
        intensites: intensites,
      ),
      CartePartage.records: CarteRecords(records: records),
      CartePartage.equivalent: CarteEquivalent(volume: volume, equivalent: e),
      CartePartage.detail: CarteDetail(
        date: Fmt.date(s.debut),
        nom: s.nom,
        resume: '$volume · $duree',
        lignes: lignesDetail(s, exos),
        intensites: intensites,
      ),
      CartePartage.serie: CarteSerie(semaines: semaines, libelle: libelle, phrase: phrase),
      CartePartage.autocollant: CarteAutocollant(nom: s.nom, volume: volume, series: series, duree: duree, photo: photo, type: s.type),
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18 * kEchelle, 10 * kEchelle, 18 * kEchelle, 10 * kEchelle),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BoutonRond(icone: Icons.close_rounded, label: 'Fermer', onTap: _fermer),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (retirable) ...[
                        BoutonRond(icone: Icons.hide_image_outlined, label: 'Retirer la photo', onTap: () => setState(() => _sansPhoto = true)),
                        const SizedBox(width: 10 * kEchelle),
                      ],
                      BoutonRond(icone: Icons.add_rounded, label: 'Choisir une photo', onTap: _choisirPhoto),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pages,
                itemCount: ordre.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(18 * kEchelle, 4 * kEchelle, 18 * kEchelle, 0),
                  // Fond opaque sous la carte : l'image exportée n'a pas de coins
                  // transparents (que chaque appli remplirait à sa façon).
                  child: RepaintBoundary(key: _cles[ordre[i]], child: ColoredBox(color: c.bg, child: parCarte[ordre[i]])),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12 * kEchelle, bottom: 2 * kEchelle),
              child: PointsPagination(nombre: ordre.length, actif: _page),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18 * kEchelle, 10 * kEchelle, 18 * kEchelle, 18 * kEchelle),
              child: SizedBox(
                width: 190 * kEchelle,
                height: 46 * kEchelle,
                child: Material(
                  color: c.bouton,
                  borderRadius: AppTokens.radiusPill,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _envoi ? null : () => _partager(s.nom),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconePartager(size: 18 * kEchelle, color: c.onBouton),
                        const SizedBox(width: 8 * kEchelle),
                        Text(
                          'Partager',
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: 14 * kEchelle, fontWeight: FontWeight.w700, color: c.onBouton),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
