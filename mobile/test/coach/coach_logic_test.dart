import 'dart:convert';

import 'package:aesthetic/core/data/data.dart';
import 'package:aesthetic/core/demo/demo_data.dart';
import 'package:aesthetic/core/models/models.dart';
import 'package:aesthetic/features/coach/data/claude_client.dart';
import 'package:aesthetic/features/coach/data/coach_prefs.dart';
import 'package:aesthetic/features/coach/logic/coach_actions.dart';
import 'package:aesthetic/features/coach/logic/coach_engine.dart';
import 'package:aesthetic/features/coach/logic/coach_prompt.dart';
import 'package:aesthetic/features/coach/logic/coach_snapshot.dart';
import 'package:aesthetic/features/coach/logic/offline_coach.dart';
import 'package:aesthetic/features/coach/logic/week_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

String sse(List<String> morceaux, {String stop = 'end_turn'}) {
  final b = StringBuffer();
  void ev(String type, Map<String, dynamic> data) => b
    ..writeln('event: $type')
    ..writeln('data: ${jsonEncode({'type': type, ...data})}')
    ..writeln();
  ev('message_start', {'message': {'id': 'msg_1'}});
  ev('content_block_start', {'index': 0, 'content_block': {'type': 'text', 'text': ''}});
  for (final m in morceaux) {
    ev('content_block_delta', {'index': 0, 'delta': {'type': 'text_delta', 'text': m}});
  }
  ev('content_block_stop', {'index': 0});
  ev('message_delta', {'delta': {'stop_reason': stop}});
  ev('message_stop', {});
  return b.toString();
}

MockClient fauxService(String reponse, {int status = 200, void Function(http.BaseRequest r, String body)? onRequest}) =>
    MockClient.streaming((req, body) async {
      final txt = await body.bytesToString();
      onRequest?.call(req, txt);
      if (req.url.path.endsWith('/models')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'data': [
              {'id': 'claude-sonnet-5-5', 'display_name': 'Claude Sonnet 5.5'},
              {'id': 'claude-opus-5-5', 'display_name': 'Claude Opus 5.5'},
            ],
          }))),
          status,
        );
      }
      return http.StreamedResponse(Stream.value(utf8.encode(reponse)), status);
    });

Future<AppData> demo() async {
  final data = AppData(Store.memory(), demo: true);
  await data.loadAll();
  await DemoData.seed(data, now: DateTime(2026, 9, 29, 20));
  return data;
}

CoachSnapshot snap(AppData d, [DateTime? now]) => CoachSnapshot(
      profile: d.profile,
      settings: d.settings,
      sessionsRepo: d.sessions,
      exercises: d.exercises,
      routines: d.routines,
      programs: d.programs,
      nutrition: d.nutrition,
      health: d.health,
      now: now ?? DateTime(2026, 9, 29, 20),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('actions du coach', () {
    test('sépare le texte et les blocs, masque un bloc non fermé', () {
      const raw = 'Voici ta routine.\n\n```action\n{"type": "routine", "nom": "Jambes", "exercices": ['
          '{"nom": "Squat barre", "series": 4, "reps": 6, "repsMax": 8, "poids": 80, "repos": 150}]}\n```\n'
          '```action\n{"type": "repas", "nom": "Skyr", "repas": "collation", "kcal": 150, "proteines": 20}\n```';
      final p = CoachAction.parse(raw);
      expect(p.texte, 'Voici ta routine.');
      expect(p.actions, hasLength(2));
      final r = p.actions.first as RoutineAction;
      expect(r.nom, 'Jambes');
      expect(r.exercices.single.series, 4);
      expect(r.exercices.single.repsMax, 8);
      expect((p.actions[1] as RepasAction).repas, MealType.collation);

      final partiel = CoachAction.parse('Je te propose :\n```action\n{"type": "rout');
      expect(partiel.texte, 'Je te propose :');
      expect(partiel.actionEnCours, isTrue);
      expect(partiel.actions, isEmpty);
    });

    test('bloc invalide ignoré sans casser le texte', () {
      final p = CoachAction.parse('Salut\n```action\npas du json\n```');
      expect(p.texte, 'Salut');
      expect(p.actions, isEmpty);
    });

    test('applique une routine, une charge et un repas', () async {
      final d = await demo();
      final runner = CoachActionRunner(exercises: d.exercises, routines: d.routines, nutrition: d.nutrition, unite: UnitePoids.kg);
      final avant = d.routines.routines.length;
      await runner.apply(const RoutineAction(nom: 'Test coach', exercices: [
        RoutineExerciceProp(nom: 'Développé couché', series: 3, reps: 8, poids: 70),
        RoutineExerciceProp(nom: 'Exercice imaginaire du coach', series: 2),
      ]));
      expect(d.routines.routines.length, avant + 1);
      final r = d.routines.routines.firstWhere((x) => x.nom == 'Test coach');
      expect(r.exercices, hasLength(2));
      expect(r.exercices.first.series.first.poids, 70);
      expect(d.exercises.byId(r.exercices[1].exerciseId)!.perso, isTrue);

      final charge = ChargeAction(exercice: 'Développé couché', poids: 72.5, routine: 'Test coach');
      expect(runner.blocage(charge), isNull);
      await runner.apply(charge);
      final r2 = d.routines.byId(r.id)!;
      expect(r2.exercices.first.series.every((s) => s.poids == 72.5), isTrue);

      final n = d.nutrition.entries.length;
      await runner.apply(RepasAction.fromJson({'nom': 'Skyr', 'repas': 'collation', 'kcal': 150, 'proteines': 20}));
      expect(d.nutrition.entries.length, n + 1);
    });
  });

  group('client API', () {
    test('lit le flux SSE et envoie les bons en-têtes', () async {
      Map<String, dynamic>? envoye;
      Map<String, String>? entetes;
      final c = ClaudeClient(
        apiKey: 'sk-ant-test',
        client: fauxService(sse(['Bon', 'jour']), onRequest: (r, b) {
          envoye = jsonDecode(b) as Map<String, dynamic>;
          entetes = r.headers;
        }),
      );
      final events = await c.stream(model: 'claude-sonnet-5-5', system: 'x', messages: const [ClaudeMessage('user', 'Salut')], effort: 'low').toList();
      final texte = events.whereType<ClaudeText>().map((e) => e.text).join();
      expect(texte, 'Bonjour');
      expect((events.last as ClaudeStop).reason, 'end_turn');
      expect(envoye!['stream'], isTrue);
      expect(envoye!['output_config'], {'effort': 'low'});
      expect(envoye!['fallbacks'], 'default');
      expect(entetes!['x-api-key'], 'sk-ant-test');
      expect(entetes!['anthropic-version'], '2023-06-01');
      expect(entetes!['anthropic-beta'], 'server-side-fallback-2026-07-01');
    });

    test('pas d\'effort ni de repli sur Haiku', () async {
      Map<String, dynamic>? envoye;
      final c = ClaudeClient(apiKey: 'k', client: fauxService(sse(['ok']), onRequest: (r, b) => envoye = jsonDecode(b) as Map<String, dynamic>));
      await c.stream(model: 'claude-haiku-4-5', system: 'x', messages: const [ClaudeMessage('user', 'a')], effort: 'low').toList();
      expect(envoye!.containsKey('output_config'), isFalse);
      expect(envoye!.containsKey('fallbacks'), isFalse);
    });

    test('clé refusée', () async {
      final c = ClaudeClient(apiKey: 'k', client: fauxService('{"error":{"type":"authentication_error","message":"invalid x-api-key"}}', status: 401));
      expect(
        () => c.stream(model: 'claude-sonnet-5-5', system: 'x', messages: const [ClaudeMessage('user', 'a')]).toList(),
        throwsA(isA<CoachApiException>().having((e) => e.cleInvalide, 'cleInvalide', isTrue)),
      );
    });

    test('liste des modèles', () async {
      final c = ClaudeClient(apiKey: 'k', client: fauxService(''));
      final list = await c.listModels();
      expect(list.first.$1, 'claude-sonnet-5-5');
    });
  });

  group('moteur', () {
    test('historique en alternance stricte, sans erreurs, commence par l\'utilisateur', () {
      final d = DateTime(2026);
      final h = CoachEngine.historyForTest([
        CoachMessage(id: '1', role: CoachRole.coach, texte: 'Bilan', date: d),
        CoachMessage(id: '2', role: CoachRole.utilisateur, texte: 'A', date: d),
        CoachMessage(id: '3', role: CoachRole.utilisateur, texte: 'B', date: d),
        CoachMessage(id: '4', role: CoachRole.coach, texte: 'Erreur', date: d, enErreur: true),
      ]);
      expect(h.map((m) => m.role), ['user', 'assistant', 'user']);
      expect(h.last.text, 'A\n\nB');
    });

    test('tirets remplacés', () {
      final tl = String.fromCharCode(0x2014);
      final tm = String.fromCharCode(0x2013);
      expect(sansTirets('8${tm}12 reps $tl facile'), '8 à 12 reps, facile');
    });

    test('phrase du jour nettoyée', () {
      expect(phrasePropre('**Bois** un verre.\n\n```action\n{}\n```'), 'Bois un verre.');
      expect(phrasePropre('« Allez ! »'), 'Allez !');
    });

    test('conversation en ligne puis hors ligne', () async {
      final d = await demo();
      final engine = CoachEngine.of(d.store);
      CoachEngine.clientFactory = (k) => ClaudeClient(apiKey: k, client: fauxService(sse(['Pense ', 'à boire.'])));
      addTearDown(() => CoachEngine.clientFactory = null);
      final conv = await d.coach.create(titre: CoachEngine.nouvelleConversation);
      await engine.send(
        repo: d.coach,
        conversationId: conv.id,
        texte: 'Que travailler aujourd\'hui ?',
        snapshot: snap(d),
        settings: d.settings.settings.copyWith(coachApiKey: 'sk-ant-x'),
      );
      final c = d.coach.byId(conv.id)!;
      expect(c.titre, 'Que travailler aujourd\'hui ?');
      expect(c.messages.last.texte, 'Pense à boire.');
      expect(engine.enCours(conv.id), isFalse);

      await engine.send(repo: d.coach, conversationId: conv.id, texte: 'Et mes protéines ?', snapshot: snap(d), settings: d.settings.settings);
      expect(d.coach.byId(conv.id)!.messages.last.texte, contains('mode hors ligne'));
    });
  });

  group('règles hors ligne et contexte', () {
    test('démo : conseils, suggestions, phrase, contexte, bilan', () async {
      final d = await demo();
      final s = snap(d);
      final a = OfflineCoach.advices(s);
      expect(a, isNotEmpty);
      expect(OfflineCoach.suggestions(s), isNotEmpty);
      expect(OfflineCoach.phraseDuJour(s), isNotEmpty);
      expect(OfflineCoach.repondre(s, 'Comment récupérer ?'), contains('hors ligne'));

      final ctx = CoachContext.build(s, const CoachPrefs());
      expect(ctx, contains('## Séances'));
      expect(ctx, contains('## Nutrition'));
      final sans = CoachContext.build(s, const CoachPrefs(partage: {}));
      expect(sans, isNot(contains('## Séances')));
      final sys = CoachPrompt.system(snapshot: s, prefs: const CoachPrefs(), ton: CoachTon.direct);
      expect(sys, contains('```action'));

      final r = WeekReport.build(s, s.now);
      expect(r.sessions, isNotEmpty);
      expect(r.donnees(d.exercises.nameOf), contains('Séances'));
      expect(r.texteHorsLigne(), isNotEmpty);

      final tl = String.fromCharCode(0x2014);
      final tm = String.fromCharCode(0x2013);
      for (final t in [ctx, sys, r.texteHorsLigne(), ...a.map((x) => x.texte), ...a.map((x) => x.titre)]) {
        expect(t.contains(tl) || t.contains(tm), isFalse, reason: t);
      }
    });

    test('profil vide : invite à démarrer', () async {
      final data = AppData(Store.memory());
      await data.loadAll();
      final s = snap(data);
      expect(s.vide, isTrue);
      expect(OfflineCoach.advices(s).first.id, 'demarrage');
    });
  });

  test('réglages : aller-retour JSON', () {
    const p = CoachPrefs(
      partage: {CoachPartage.seances},
      periodeJours: 60,
      reflexion: CoachReflexion.approfondie,
      bilans: {'2026-09-28': 'ok'},
      actionsAppliquees: {'m#0'},
      modelesApi: [('claude-opus-5-5', 'Opus')],
    );
    final q = CoachPrefs.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(q.partage, {CoachPartage.seances});
    expect(q.periodeJours, 60);
    expect(q.reflexion, CoachReflexion.approfondie);
    expect(q.bilans['2026-09-28'], 'ok');
    expect(q.actionsAppliquees, {'m#0'});
    expect(q.modelesApi.single.$1, 'claude-opus-5-5');
  });
}
