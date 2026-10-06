import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../profil/widgets/maquette.dart';
import '../routes.dart';

/// La flamme de l'accueil : le nombre de semaines d'affilée, une grande
/// flamme, et le calendrier de la série. Une semaine tenue (au moins une
/// séance) est soulignée d'une bande sombre ; chaque jour de séance est un
/// disque orange qu'on touche pour ouvrir la séance.
class SeriePage extends StatefulWidget {
  const SeriePage({super.key, this.maintenant});

  /// Pour les tests.
  final DateTime? maintenant;

  @override
  State<SeriePage> createState() => _SeriePageState();
}

class _SeriePageState extends State<SeriePage> {
  late final DateTime _aujourdhui = widget.maintenant ?? DateTime.now();
  late DateTime _mois = DateTime(_aujourdhui.year, _aujourdhui.month);

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<SessionRepo>();
    final premier = context.watch<SettingsRepo>().settings.premierJourSemaine;
    final semaines = Dates.semainesConsecutives(repo.sessions.map((s) => s.debut), now: _aujourdhui, premierJour: premier);
    final premiereSeance = repo.sessions.isEmpty ? null : repo.sessions.map((s) => s.debut).reduce((a, b) => a.isBefore(b) ? a : b);
    final moisMin = premiereSeance == null ? _mois : DateTime(premiereSeance.year, premiereSeance.month);
    final moisMax = DateTime(_aujourdhui.year, _aujourdhui.month);

    return PageMaquette(
      titre: 'Série',
      enfants: [
        Bloc(haut: 6, child: _Entete(semaines: semaines)),
        Bloc(child: _Message(semaines: semaines)),
        Padding(
          padding: EdgeInsets.only(top: e(8)),
          child: Divider(height: 1, thickness: e(4), color: context.colors.surface),
        ),
        Bloc(haut: 16, child: Text('Calendrier de la série', style: txt(19, FontWeight.w700, context.colors.text))),
        Bloc(
          bas: 24,
          child: _Calendrier(
            mois: _mois,
            aujourdhui: _aujourdhui,
            premierJour: premier,
            sessions: repo.sessions,
            avant: _mois.isAfter(moisMin) ? () => setState(() => _mois = DateTime(_mois.year, _mois.month - 1)) : null,
            apres: _mois.isBefore(moisMax) ? () => setState(() => _mois = DateTime(_mois.year, _mois.month + 1)) : null,
          ),
        ),
      ],
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.semaines});
  final int semaines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semaines <= 1 ? '$semaines semaine d\'affilée' : '$semaines semaines d\'affilée',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$semaines', style: txt(96, FontWeight.w800, c.text, interligne: 1, espacement: -0.04)),
                ),
              ),
              Opacity(
                opacity: semaines == 0 ? 0.35 : 1,
                child: Flamme(taille: e(118)),
              ),
            ],
          ),
          SizedBox(height: e(10)),
          Text(semaines <= 1 ? 'semaine d\'affilée !' : 'semaines d\'affilée !', style: txt(22, FontWeight.w700, c.text)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.semaines});
  final int semaines;

  String get _texte => switch (semaines) {
    0 => 'Une séance cette semaine et ta série démarre.',
    1 => 'Première semaine de ta série. Reviens la semaine prochaine pour la faire grandir.',
    _ => 'Tu as tenu $semaines semaines d\'affilée.\nBien vu !',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Carte(
      padding: EdgeInsets.fromLTRB(e(14), e(14), e(16), e(14)),
      child: Row(
        children: [
          Flamme(taille: e(34)),
          SizedBox(width: e(14)),
          Expanded(child: Text(_texte, style: txt(14, FontWeight.w400, c.text, interligne: 1.45))),
        ],
      ),
    );
  }
}

class _Calendrier extends StatelessWidget {
  const _Calendrier({
    required this.mois,
    required this.aujourdhui,
    required this.premierJour,
    required this.sessions,
    required this.avant,
    required this.apres,
  });

  final DateTime mois;
  final DateTime aujourdhui;
  final int premierJour;
  final List<WorkoutSession> sessions;
  final VoidCallback? avant;
  final VoidCallback? apres;

  static const _initiales = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);
    final parJour = <DateTime, List<WorkoutSession>>{};
    for (final s in sessions) {
      (parJour[jour(s.debut)] ??= []).add(s);
    }
    final semainesTenues = {for (final d in parJour.keys) Dates.debutSemaine(d, premierJour: premierJour)};

    final premierDuMois = DateTime(mois.year, mois.month);
    final dernier = DateTime(mois.year, mois.month + 1, 0);
    final semainesDuMois = <DateTime>[];
    for (var s = Dates.debutSemaine(premierDuMois, premierJour: premierJour); !s.isAfter(dernier); s = DateTime(s.year, s.month, s.day + 7)) {
      semainesDuMois.add(s);
    }
    final ordre = [for (var i = 0; i < 7; i++) (premierJour - 1 + i) % 7];

    Widget fleche(IconData icone, String label, VoidCallback? onTap) => Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icone, size: e(22)),
        color: c.text,
        disabledColor: c.text3.withValues(alpha: 0.35),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(e(10), e(8), e(10), e(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(e(20)),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              fleche(Icons.chevron_left_rounded, 'Mois précédent', avant),
              Expanded(
                child: Text(Fmt.mois(mois), textAlign: TextAlign.center, style: txt(15, FontWeight.w700, c.text)),
              ),
              fleche(Icons.chevron_right_rounded, 'Mois suivant', apres),
            ],
          ),
          SizedBox(height: e(10)),
          Row(
            children: [
              for (final i in ordre)
                Expanded(
                  child: Text(_initiales[i], textAlign: TextAlign.center, style: txt(13, FontWeight.w500, c.text2)),
                ),
            ],
          ),
          SizedBox(height: e(6)),
          for (final debut in semainesDuMois)
            Padding(
              padding: EdgeInsets.only(top: e(6)),
              child: Container(
                height: e(42),
                decoration: semainesTenues.contains(debut) ? BoxDecoration(color: AppTokens.feuBande, borderRadius: BorderRadius.circular(e(21))) : null,
                child: Row(
                  children: [
                    for (var k = 0; k < 7; k++)
                      Expanded(
                        child: _Jour(
                          jour: DateTime(debut.year, debut.month, debut.day + k),
                          dansLeMois: DateTime(debut.year, debut.month, debut.day + k).month == mois.month,
                          aujourdhui: jour(aujourdhui),
                          seances: parJour[DateTime(debut.year, debut.month, debut.day + k)] ?? const [],
                          bande: semainesTenues.contains(debut),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Jour extends StatelessWidget {
  const _Jour({required this.jour, required this.dansLeMois, required this.aujourdhui, required this.seances, required this.bande});

  final DateTime jour;
  final bool dansLeMois;
  final DateTime aujourdhui;
  final List<WorkoutSession> seances;
  final bool bande;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final estAujourdhui = jour == aujourdhui;
    final seance = seances.isNotEmpty;
    final numero = Text(
      '${jour.day}',
      style: txt(
        15,
        seance || estAujourdhui ? FontWeight.w700 : FontWeight.w500,
        // Les jours du mois voisin restent visibles dans leur semaine, plus effacés.
        seance ? AppTokens.bg : (estAujourdhui ? c.text : (dansLeMois ? c.text2 : c.text3)),
      ),
    );
    final contenu = LayoutBuilder(
      builder: (context, box) {
        // Le disque laisse un écart avec ses voisins, même en petit écran.
        final d = (box.maxWidth - 4).clamp(24.0, e(34));
        return Center(
          child: seance
              ? Container(
                  width: d,
                  height: d,
                  decoration: const BoxDecoration(color: AppTokens.feu, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: numero,
                )
              : numero,
        );
      },
    );
    if (!seance) return contenu;
    final derniere = seances.reduce((a, b) => a.debut.isAfter(b.debut) ? a : b);
    return Semantics(
      button: true,
      label: '${Fmt.date(jour)}, ${seances.length >= 2 ? '${seances.length} séances' : derniere.nom}',
      excludeSemantics: true,
      child: InkResponse(radius: e(22), onTap: () => context.push(AujourdhuiPaths.seanceDetail(derniere.id)), child: contenu),
    );
  }
}

/// Flamme pleine à deux tons, orange autour d'un coeur jaune.
class Flamme extends StatelessWidget {
  const Flamme({super.key, required this.taille});
  final double taille;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: taille * 0.82,
    height: taille,
    child: const CustomPaint(painter: _FlammePainter()),
  );
}

class _FlammePainter extends CustomPainter {
  const _FlammePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Dessinée sur une grille de 82 sur 100.
    canvas.scale(size.width / 82, size.height / 100);
    final dehors = Path()
      ..moveTo(44, 2)
      ..cubicTo(56, 18, 80, 36, 80, 62)
      ..cubicTo(80, 84, 63, 98, 41, 98)
      ..cubicTo(19, 98, 2, 84, 2, 62)
      ..cubicTo(2, 46, 10, 33, 20, 24)
      ..lineTo(23, 38)
      ..cubicTo(30, 26, 36, 14, 44, 2)
      ..close();
    final coeur = Path()
      ..moveTo(41, 50)
      ..cubicTo(52, 60, 64, 70, 64, 82)
      ..cubicTo(64, 92, 54, 98, 41, 98)
      ..cubicTo(28, 98, 18, 92, 18, 82)
      ..cubicTo(18, 70, 30, 60, 41, 50)
      ..close();
    canvas.drawPath(dehors, Paint()..color = AppTokens.feu);
    canvas.save();
    canvas.clipPath(dehors);
    canvas.drawPath(coeur, Paint()..color = AppTokens.feuJaune);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlammePainter oldDelegate) => false;
}
