import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/ui/ui.dart';
import '../../entrainer/routines/routines.dart' show routinePrevue;
import '../logic/lancement.dart';
import '../seance_paths.dart';

enum TypeLancement { vide, routine, refaire }

/// Page d'aiguillage : démarre la séance demandée puis ouvre l'écran de séance.
/// Permet aux autres modules de lancer une séance par une simple route.
class LanceurPage extends StatefulWidget {
  const LanceurPage({super.key, required this.type, this.id, this.programId});

  final TypeLancement type;
  final String? id;
  final String? programId;

  @override
  State<LanceurPage> createState() => _LanceurPageState();
}

class _LanceurPageState extends State<LanceurPage> {
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lancer());
  }

  Future<void> _lancer() async {
    final repo = context.read<SessionRepo>();
    try {
      switch (widget.type) {
        case TypeLancement.routine:
          final r = context.read<RoutineRepo>().byId(widget.id ?? '');
          if (r == null) {
            setState(() => _erreur = 'Cette routine n\'existe plus.');
            return;
          }
          // La séance de cette routine tourne déjà (le widget touché une
          // seconde fois) : on y retourne, sans rien demander.
          if (repo.active?.routineId == r.id) break;
          if (!await Lancement.libererPlace(context)) break;
          if (!mounted) break;
          // La progression du programme (charges, séries) s'applique ici.
          final prevue = routinePrevue(context, r, programId: widget.programId);
          await Lancement.routine(repo, prevue.routine, programId: widget.programId);
        case TypeLancement.refaire:
          final s = repo.byId(widget.id ?? '');
          if (s == null) {
            setState(() => _erreur = 'Cette séance n\'existe plus.');
            return;
          }
          if (!await Lancement.libererPlace(context)) break;
          await Lancement.refaire(repo, s);
        case TypeLancement.vide:
          if (!await Lancement.libererPlace(context)) break;
          await Lancement.vide(repo);
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = 'La séance n\'a pas pu démarrer.');
      return;
    }
    if (mounted) context.pushReplacement(SeancePaths.enCours);
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Séance',
      body: _erreur == null
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Impossible de démarrer',
              message: _erreur,
              actionLabel: 'Choisir une autre séance',
              onAction: () => context.pushReplacement(SeancePaths.enCours),
            ),
    );
  }
}
