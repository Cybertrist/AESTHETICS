import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../profil/widgets/ecusson.dart';
import '../logic/analyse.dart';
import 'habillage.dart';

/// Le record de la séance, en grand : écusson doré, exercice, valeur en très
/// gros et, quand il y en a un, l'écart avec l'ancien record.
class CarteRecord extends StatelessWidget {
  const CarteRecord({super.key, required this.nom, required this.valeur, required this.type, this.gain, this.medaille = MedailleRecord.or});

  /// Or, argent ou bronze : la couleur de l'écusson.
  final MedailleRecord medaille;

  final String nom;
  final String valeur;

  /// Nature du record (« 1RM estimé »).
  final String type;

  /// « +2,5 kg », null pour un premier record.
  final String? gain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(k(14), k(12), k(14), k(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(k(20)),
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.15,
          colors: [const Color(0xFF3A2C05), c.surface],
          stops: const [0, 0.72],
        ),
      ),
      child: Column(
        children: [
          Ecusson.record(largeur: k(104), medaille: medaille),
          Text(
            'NOUVEAU RECORD',
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10), fontWeight: FontWeight.w700, letterSpacing: k(1.4), color: const Color(0xFFFFBE0B)),
          ),
          SizedBox(height: k(3)),
          Text(
            nom,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(16), height: 1.25, fontWeight: FontWeight.w800, color: c.text),
          ),
          SizedBox(height: k(4)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valeur,
              maxLines: 1,
              style: TextStyle(fontFamily: 'Montserrat', fontSize: k(36), height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -1, color: c.text),
            ),
          ),
          if (gain != null)
            Text(
              '$gain sur ton ancien record',
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12), fontWeight: FontWeight.w700, color: c.success, fontFeatures: AppTokens.tabular),
            ),
          SizedBox(height: k(4)),
          Text(type, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), color: c.text2)),
        ],
      ),
    );
  }
}

/// Ligne d'un record battu, quand la séance en compte plusieurs : petit
/// écusson, exercice et nature du record, valeur et écart à droite.
class LigneRecord extends StatelessWidget {
  const LigneRecord({super.key, required this.nom, required this.type, required this.valeur, this.gain, this.medaille = MedailleRecord.or});

  /// Or, argent ou bronze : la couleur de l'écusson.
  final MedailleRecord medaille;

  final String nom;
  final String type;
  final String valeur;
  final String? gain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(k(8), k(6), k(12), k(6)),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
      child: Row(
        children: [
          Ecusson.record(largeur: k(40), medaille: medaille),
          SizedBox(width: k(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, fontWeight: FontWeight.w600, color: c.text),
                ),
                Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2),
                ),
              ],
            ),
          ),
          SizedBox(width: k(8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(valeur, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(14), height: 1.3, fontWeight: FontWeight.w800, color: c.text, fontFeatures: AppTokens.tabular)),
              if (gain != null)
                Text(gain!, style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.3, fontWeight: FontWeight.w700, color: c.success, fontFeatures: AppTokens.tabular)),
            ],
          ),
        ],
      ),
    );
  }
}

/// « La prochaine fois » : la charge ou les répétitions à viser par exercice.
class ProchaineFois extends StatelessWidget {
  const ProchaineFois({super.key, required this.suggestions, required this.exos});

  final List<Suggestion> suggestions;
  final ExerciseRepo exos;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Surtitre('La prochaine fois'),
        SizedBox(height: k(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: k(12)),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
          child: Column(
            children: [
              for (var i = 0; i < suggestions.length; i++)
                Container(
                  padding: EdgeInsets.symmetric(vertical: k(9)),
                  decoration: BoxDecoration(border: i < suggestions.length - 1 ? Border(bottom: BorderSide(color: c.line)) : null),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exos.nameOf(suggestions[i].exerciseId),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.35, fontWeight: FontWeight.w600, color: c.text),
                            ),
                            Text(
                              suggestions[i].raison,
                              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: k(10)),
                      Text(
                        suggestions[i].titre,
                        style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), fontWeight: FontWeight.w700, color: c.text, fontFeatures: AppTokens.tabular),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Source { seance, suggestion }

/// Proposition de mettre à jour la routine avec les charges du jour ou les
/// charges suggérées, aperçu avant et après.
class MajRoutineBloc extends StatefulWidget {
  const MajRoutineBloc({super.key, required this.routine, required this.session, required this.suggestions});

  final Routine routine;
  final WorkoutSession session;
  final List<Suggestion> suggestions;

  @override
  State<MajRoutineBloc> createState() => _MajRoutineBlocState();
}

class _MajRoutineBlocState extends State<MajRoutineBloc> {
  _Source _source = _Source.seance;
  bool _fait = false;

  /// « Garder ma routine » : le choix est fait, la routine ne bouge pas.
  bool _gardee = false;

  /// Vrai si la séance n'avait plus les exercices de la routine. Retenu à
  /// l'ouverture : une fois la routine mise à jour, la comparaison dirait non.
  late final bool _changes = MajRoutine.exercicesChanges(widget.routine, widget.session);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exos = context.watch<ExerciseRepo>();
    final unite = context.watch<ProfileRepo>().unite;
    // Des exercices ont changé : la routine reprendrait la séance telle quelle.
    final changes = _changes;
    final apres = MajRoutine.appliquer(
      widget.routine,
      widget.session,
      calquer: changes,
      suggestions: _source == _Source.suggestion ? widget.suggestions : const [],
    );
    final diffs = MajRoutine.differences(widget.routine, apres, exos, unite);
    if (diffs.isEmpty && !_fait && !_gardee && !changes) return const SizedBox.shrink();
    final gris = TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11.5), color: c.text2, fontFeatures: AppTokens.tabular);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surtitre('Routine ${widget.routine.nom}'),
        SizedBox(height: k(8)),
        if (_fait || _gardee)
          Text(
            _gardee
                ? 'Routine gardée telle quelle. La séance d’aujourd’hui reste dans ton historique.'
                : changes
                    ? 'Routine mise à jour. La prochaine séance reprendra ces exercices et ces charges.'
                    : 'Routine mise à jour. La prochaine séance partira de ces charges.',
            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
          )
        else ...[
          if (changes) ...[
            Text(
              'Tu as changé des exercices pendant la séance. Tu peux garder ta routine comme avant, ou la remplacer par ce que tu viens de faire.',
              style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.4, color: c.text2),
            ),
            SizedBox(height: k(8)),
          ],
          if (widget.suggestions.isNotEmpty) ...[
            SelecteurSegmente<_Source>(
              segments: const [(_Source.seance, 'Charges du jour'), (_Source.suggestion, 'Charges suggérées')],
              value: _source,
              onChanged: (v) => setState(() => _source = v),
            ),
            SizedBox(height: k(8)),
          ],
          Container(
            padding: EdgeInsets.symmetric(horizontal: k(12), vertical: k(4)),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in diffs)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: k(6)),
                    // Le nom sur sa ligne, en entier ; l'avant et l'après dessous
                    // (côte à côte, ils coupaient les noms longs).
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exos.nameOf(d.exerciseId),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(12.5), height: 1.35, fontWeight: FontWeight.w600, color: c.text),
                        ),
                        SizedBox(height: k(1)),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(d.avant, style: gris.copyWith(decoration: d.ajout ? null : TextDecoration.lineThrough)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: k(5)),
                              child: Trait(IconeSeance.chevronDroit, size: k(11), epaisseur: 2, color: c.text3),
                            ),
                            Text(d.apres, style: gris.copyWith(fontWeight: FontWeight.w700, color: d.retrait ? c.error : c.text)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: k(8)),
          Row(
            children: [
              if (changes) ...[
                Expanded(child: BoutonSecondaire(label: 'Garder ma routine', petit: true, onPressed: () => setState(() => _gardee = true))),
                SizedBox(width: k(8)),
              ],
              Expanded(
                child: BoutonSecondaire(
                  label: changes ? 'Mettre à jour' : 'Mettre à jour la routine',
                  petit: true,
                  onPressed: () async {
                    await context.read<RoutineRepo>().save(apres);
                    if (mounted) setState(() => _fait = true);
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Trois chiffres de la séance sous le chiffre principal : durée, séries,
/// exercices (la durée est omise quand elle est déjà le chiffre principal).
class ChiffresSeance extends StatelessWidget {
  const ChiffresSeance({super.key, required this.chiffres});

  /// (valeur, libellé).
  final List<(String, String)> chiffres;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < chiffres.length; i++) ...[
          if (i > 0) SizedBox(width: k(8)),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(k(12), k(10), k(10), k(10)),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      chiffres[i].$1,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTokens.fontUi,
                        fontSize: k(17),
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        fontFeatures: AppTokens.tabular,
                      ),
                    ),
                  ),
                  Text(
                    chiffres[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(10.5), height: 1.35, color: c.text2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ligne d'un exercice fait : nombre de séries dans un carré gris, nom, et la
/// meilleure série (« 70 kg × 6 », « × 12 » sans charge).
class LigneExerciceBilan extends StatelessWidget {
  const LigneExerciceBilan({super.key, required this.nom, required this.series, required this.meilleure, this.record, this.gain, this.medaille = MedailleRecord.or});

  /// La plus haute médaille gagnée sur l'exercice.
  final MedailleRecord medaille;

  final String nom;
  final int series;
  final String meilleure;

  /// Record battu sur cet exercice (« 1RM estimé 70 kg ») : l'écusson prend
  /// la place du nombre de séries.
  final String? record;
  final String? gain;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.all(k(8)),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(k(14))),
      child: Row(
        children: [
          if (record != null)
            // Même largeur que la case du nombre : les noms restent alignés.
            SizedBox(width: k(36), child: Center(child: Ecusson.record(largeur: k(36), medaille: medaille)))
          else
            Container(
              width: k(36),
              height: k(36),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(k(10))),
              alignment: Alignment.center,
              child: Text(
                '$series',
                style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(14), fontWeight: FontWeight.w800, color: c.text, fontFeatures: AppTokens.tabular),
              ),
            ),
          SizedBox(width: k(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(13), height: 1.35, fontWeight: FontWeight.w600, color: c.text),
                ),
                Text(
                  record == null ? '${series >= 2 ? 'séries' : 'série'} · meilleure $meilleure' : '$series ${series >= 2 ? 'séries' : 'série'} · meilleure $meilleure',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, color: c.text2, fontFeatures: AppTokens.tabular),
                ),
                if (record != null)
                  Padding(
                    padding: EdgeInsets.only(top: k(4)),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: k(5), vertical: k(1.5)),
                          decoration: BoxDecoration(color: Color(medaille.couleur), borderRadius: BorderRadius.circular(k(5))),
                          child: Text('RECORD', style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(8.5), height: 1.2, fontWeight: FontWeight.w800, letterSpacing: k(0.8), color: Colors.black)),
                        ),
                        SizedBox(width: k(6)),
                        Flexible(
                          child: Text.rich(
                            TextSpan(children: [
                              // L'écart d'abord : c'est lui qui doit rester lisible si la ligne est coupée.
                              if (gain != null) TextSpan(text: '$gain  ', style: TextStyle(color: c.success, fontWeight: FontWeight.w700)),
                              TextSpan(text: record),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: AppTokens.fontUi, fontSize: k(11), height: 1.35, fontWeight: FontWeight.w600, color: c.text, fontFeatures: AppTokens.tabular),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
