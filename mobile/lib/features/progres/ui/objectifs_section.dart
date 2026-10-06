import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/bibliotheque/bibliotheque.dart';
import '../../profil/data/grades.dart';
import '../../profil/data/mensurations.dart';
import '../../profil/widgets/ecusson.dart';
import '../logic/objectifs.dart';
import 'communs.dart';

/// Badge secret gagné en atteignant un objectif de ce type : nom, couleur
/// et pictogramme de son écusson.
({String nom, Color couleur, PictoGrade picto}) badgeObjectif(TypeObjectif t) => switch (t) {
      TypeObjectif.poids => (nom: 'Poids tenu', couleur: const Color(0xFF0FC9AE), picto: PictoGrade.cible),
      TypeObjectif.charge => (nom: 'Charge tenue', couleur: const Color(0xFFFF3347), picto: PictoGrade.haltere),
      TypeObjectif.seances => (nom: 'Rythme tenu', couleur: const Color(0xFFFF8419), picto: PictoGrade.flamme),
      TypeObjectif.mensuration => (nom: 'Mesure tenue', couleur: const Color(0xFF8B55FF), picto: PictoGrade.regle),
    };

/// Cible et valeur d'un objectif, dans l'unité affichée.
String texteValeurObjectif(ObjectifPerso o, double v, UnitePoids unite) => switch (o.type) {
      TypeObjectif.charge || TypeObjectif.poids => Fmt.poids(v, unite),
      TypeObjectif.seances => '${v.round()}',
      TypeObjectif.mensuration => Affichage.longueurTexte(v),
    };

/// Nom d'un objectif : l'exercice, « Poids du corps », la zone mesurée.
String titreObjectif(ObjectifPerso o, ExerciseRepo exos) => switch (o.type) {
      TypeObjectif.charge => o.exerciseId == null ? 'Charge' : exos.nameOf(o.exerciseId!),
      TypeObjectif.poids => 'Poids du corps',
      TypeObjectif.seances => 'Séances cette semaine',
      TypeObjectif.mensuration => 'Tour : ${o.zone?.label.toLowerCase() ?? 'mesure'}',
    };

/// Section « Objectifs » de l'onglet Progrès : une carte par objectif en
/// cours, les objectifs atteints dessous, et « Nouvel objectif ».
class ObjectifsSection extends StatefulWidget {
  const ObjectifsSection({super.key});

  @override
  State<ObjectifsSection> createState() => _ObjectifsSectionState();
}

class _ObjectifsSectionState extends State<ObjectifsSection> {
  late final Future<ObjectifsRepo> _repo = ObjectifsRepo.ensure(context.read<Store>());
  bool _verification = false;

  /// Marque atteints les objectifs qui viennent de l'être et fête le badge.
  Future<void> _verifier(ObjectifsRepo repo, List<WorkoutSession> sessions, List<BodyMeasurement> mesures, int premierJour) async {
    if (_verification) return;
    _verification = true;
    try {
      for (final o in repo.liste.where((o) => !o.atteint).toList()) {
        final v = Objectifs.valeur(o, sessions: sessions, mesures: mesures, premierJour: premierJour);
        if (!Objectifs.atteint(o, v)) continue;
        final avant = Objectifs.atteintsParType(repo.liste)[o.type] ?? 0;
        await repo.remplacer(o.avecAtteinte(DateTime.now()));
        if (!mounted) return;
        await montrerBadgeSecret(context, o, avant + 1);
        if (!mounted) return;
      }
    } finally {
      _verification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = context.watch<SessionRepo>().sessions;
    final mesures = context.watch<HealthRepo>().measurements;
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    final premierJour = context.watch<SettingsRepo>().settings.premierJourSemaine;
    return FutureBuilder<ObjectifsRepo>(
      future: _repo,
      builder: (context, snap) {
        final repo = snap.data;
        if (repo == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: repo,
          builder: (context, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _verifier(repo, sessions, mesures, premierJour);
            });
            final enCours = repo.liste.where((o) => !o.atteint).toList();
            final atteints = repo.liste.where((o) => o.atteint).toList()..sort((a, b) => b.atteintLe!.compareTo(a.atteintLe!));
            Widget carte(ObjectifPerso o) {
              final v = Objectifs.valeur(o, sessions: sessions, mesures: mesures, premierJour: premierJour);
              final part = o.atteint ? 1.0 : Objectifs.part(o, v);
              final reste = v == null ? null : (o.cible - v).abs();
              final detail = o.atteint
                  ? 'Atteint le ${Fmt.date(o.atteintLe!)}'
                  : v == null
                      ? 'Rien de noté pour l\'instant'
                      : o.type == TypeObjectif.seances
                          ? Fmt.pluriel(v.round(), 'faite')
                          : '${texteValeurObjectif(o, v, unite)} · il reste ${texteValeurObjectif(o, reste!, unite)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: Cotes.gouttiere),
                child: Carte(
                  rayon: Cotes.rTuile,
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  semantique: '${titreObjectif(o, exos)}, $detail',
                  onTap: () => _actions(repo, o, exos),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(titreObjectif(o, exos), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15.5, FontWeight.w700, c.text)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, o.atteint ? FontWeight.w700 : FontWeight.w400, o.atteint ? c.success : c.text2)),
                          ),
                          Text(texteValeurObjectif(o, o.cible, unite), style: ts(15, FontWeight.w800, c.text)),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(value: part, minHeight: 7, backgroundColor: c.surface2, color: o.atteint ? c.success : c.text),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitreBloc('Objectifs', lien: enCours.isEmpty ? null : Fmt.pluriel(enCours.length, 'en cours', 'en cours')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Cotes.marge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in enCours) carte(o),
                      Semantics(
                        button: true,
                        label: 'Nouvel objectif',
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Cotes.rTuile), side: BorderSide(color: c.surface2, width: 1.5)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _creer(repo),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(child: Text('+ Nouvel objectif', style: ts(14.5, FontWeight.w600, c.text2))),
                            ),
                          ),
                        ),
                      ),
                      if (atteints.isNotEmpty) ...[
                        Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 10), child: Text('Atteints', style: ts(15.5, FontWeight.w700, c.text))),
                        for (final o in atteints) carte(o),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _actions(ObjectifsRepo repo, ObjectifPerso o, ExerciseRepo exos) async {
    final supprimer = await showPanneauBas<bool>(
      context,
      titre: titreObjectif(o, exos),
      builder: (context) => ChoixPanneau(label: 'Supprimer cet objectif', onTap: () => Navigator.pop(context, true)),
    );
    if (supprimer == true) await repo.supprimer(o.id);
  }

  Future<void> _creer(ObjectifsRepo repo) async {
    final sessions = context.read<SessionRepo>().sessions;
    final mesures = context.read<HealthRepo>().measurements;
    final o = await showPanneauBas<ObjectifPerso>(
      context,
      titre: 'Nouvel objectif',
      builder: (context) => _Creation(sessions: sessions, mesures: mesures),
    );
    if (o != null) await repo.ajouter(o);
  }
}

/// Carte « Badge secret débloqué » : l'écusson, son nom et l'objectif tenu.
Future<void> montrerBadgeSecret(BuildContext context, ObjectifPerso o, int niveau) {
  final exos = context.read<ExerciseRepo>();
  final unite = context.read<ProfileRepo>().unite;
  final b = badgeObjectif(o.type);
  return showPanneauBas<void>(
    context,
    titre: 'Badge secret débloqué',
    builder: (context) {
      final c = context.colors;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Ecusson(couleur: b.couleur, picto: b.picto, nombre: niveau, largeur: 150)),
          const SizedBox(height: 4),
          Text(b.nom, textAlign: TextAlign.center, style: ts(21, FontWeight.w800, c.text)),
          const SizedBox(height: 5),
          Text(
            '${titreObjectif(o, exos)} : ${texteValeurObjectif(o, o.cible, unite)}. C\'était ton objectif, tu viens de le tenir.',
            textAlign: TextAlign.center,
            style: ts(14, FontWeight.w400, c.text2, hauteur: 1.45),
          ),
          const SizedBox(height: 16),
          BoutonPrincipal(label: 'Continuer', onPressed: () => Navigator.pop(context)),
        ],
      );
    },
  );
}

/// Création d'un objectif : le type, puis sa cible.
class _Creation extends StatefulWidget {
  const _Creation({required this.sessions, required this.mesures});
  final List<WorkoutSession> sessions;
  final List<BodyMeasurement> mesures;

  @override
  State<_Creation> createState() => _CreationState();
}

class _CreationState extends State<_Creation> {
  TypeObjectif? _type;
  String? _exerciseId;
  ZoneMesure _zone = ZoneMesure.biceps;
  double _cible = 0;

  ObjectifPerso _brouillon() => ObjectifPerso(id: newId(), type: _type!, cible: _cible, creeLe: DateTime.now(), exerciseId: _exerciseId, zone: _type == TypeObjectif.mensuration ? _zone : null);

  double? get _actuelle => _type == null ? null : Objectifs.valeur(_brouillon(), sessions: widget.sessions, mesures: widget.mesures);

  /// Cible proposée d'après la valeur du moment.
  void _proposer() {
    final unite = context.read<ProfileRepo>().unite;
    final objectif = context.read<ProfileRepo>().profile?.objectif;
    final v = _actuelle;
    _cible = switch (_type!) {
      TypeObjectif.charge => Fmt.poidsAffiche((v ?? 40) + 5, unite),
      TypeObjectif.poids => Fmt.poidsAffiche((v ?? 75) + (objectif == Objectif.secher ? -5 : 3), unite),
      TypeObjectif.seances => (context.read<ProfileRepo>().profile?.joursParSemaine ?? 4).toDouble(),
      TypeObjectif.mensuration => Affichage.longueurAffichee((v ?? _zone.defaut.toDouble()) + (_zone == ZoneMesure.taille ? -2 : 1)),
    };
    _cible = (_cible * 2).round() / 2;
  }

  Future<void> _exercice() async {
    final ids = await pickExercises(context, multi: false, titre: 'Choisir l\'exercice');
    if (ids == null || ids.isEmpty || !mounted) return;
    setState(() {
      _exerciseId = ids.first;
      _proposer();
    });
  }

  void _valider() {
    final unite = context.read<ProfileRepo>().unite;
    // La cible revient en unités de stockage.
    final cible = switch (_type!) {
      TypeObjectif.charge || TypeObjectif.poids => Fmt.poidsStocke(_cible, unite),
      TypeObjectif.seances => _cible,
      TypeObjectif.mensuration => Affichage.longueurStockee(_cible),
    };
    final b = _brouillon();
    Navigator.pop(
      context,
      ObjectifPerso(id: b.id, type: b.type, cible: cible, creeLe: b.creeLe, exerciseId: b.exerciseId, zone: b.zone, depart: _type == TypeObjectif.seances ? 0 : (_actuelle ?? cible)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unite = context.watch<ProfileRepo>().unite;
    final exos = context.watch<ExerciseRepo>();
    final type = _type;
    if (type == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in TypeObjectif.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: c.surface2,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() {
                    _type = t;
                    _proposer();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.label, style: ts(15, FontWeight.w700, c.text)),
                              Text(t.detail, style: ts(12.5, FontWeight.w400, c.text2)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.text2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final v = _actuelle;
    final uniteTexte = switch (type) {
      TypeObjectif.charge || TypeObjectif.poids => unite.label,
      TypeObjectif.seances => 'par semaine',
      TypeObjectif.mensuration => Affichage.longueur,
    };
    final pret = type != TypeObjectif.charge || _exerciseId != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(type.label, textAlign: TextAlign.center, style: ts(15, FontWeight.w700, c.text)),
        const SizedBox(height: 12),
        if (type == TypeObjectif.charge)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BoutonSecondaire(label: _exerciseId == null ? 'Choisir l\'exercice' : exos.nameOf(_exerciseId!), onPressed: _exercice),
          ),
        if (type == TypeObjectif.mensuration)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final z in ZoneMesure.values)
                  ChoiceChip(
                    label: Text(z.label),
                    selected: z == _zone,
                    onSelected: (_) => setState(() {
                      _zone = z;
                      _proposer();
                    }),
                  ),
              ],
            ),
          ),
        if (pret) ...[
          Center(
            child: NumberStepper(
              value: _cible,
              min: type == TypeObjectif.seances ? 1 : 0,
              max: type == TypeObjectif.seances ? 7 : 999,
              step: type == TypeObjectif.seances ? 1 : 0.5,
              decimals: type == TypeObjectif.seances ? 0 : 1,
              unit: uniteTexte,
              label: 'Cible',
              onChanged: (x) => setState(() => _cible = x),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            type == TypeObjectif.seances
                ? 'L\'objectif est atteint la semaine où tu fais ce nombre de séances.'
                : v == null
                    ? 'Rien de noté pour l\'instant : la jauge démarrera à ta première valeur.'
                    : 'Aujourd\'hui : ${texteValeurObjectif(_brouillon(), v, unite)}.',
            textAlign: TextAlign.center,
            style: ts(13, FontWeight.w400, c.text2, hauteur: 1.4),
          ),
        ],
        const SizedBox(height: 14),
        BoutonPrincipal(label: 'Créer l\'objectif', onPressed: pret && _cible > 0 ? _valider : null),
      ],
    );
  }
}
