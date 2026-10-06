import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Modèle proposé dans les réglages du coach.
class CoachModel {
  const CoachModel(this.id, this.nom, this.description);
  final String id;
  final String nom;
  final String description;
}

/// Modèles connus ; la liste est complétée par celle de l'API quand la clé est valide.
abstract final class CoachModels {
  static const defaut = 'claude-sonnet-5-5';

  static const connus = [
    CoachModel('claude-sonnet-5-5', 'Claude Sonnet 5.5', 'Rapide et fin, le meilleur choix au quotidien'),
    CoachModel('claude-opus-5-5', 'Claude Opus 5.5', 'Le plus réfléchi pour bâtir un programme'),
    CoachModel('claude-haiku-4-5', 'Claude Haiku 4.5', 'Le plus économique, réponses très courtes'),
    CoachModel('claude-fable-5-1', 'Claude Fable 5.1', 'Le plus puissant, nettement plus coûteux'),
  ];

  static String nom(String? id) {
    final m = id ?? defaut;
    for (final c in connus) {
      if (c.id == m) return c.nom;
    }
    return m;
  }
}

/// Erreur lisible renvoyée à l'écran.
class CoachApiException implements Exception {
  const CoachApiException(this.message, {this.status, this.cleInvalide = false, this.reessayable = true});
  final String message;
  final int? status;
  final bool cleInvalide;
  final bool reessayable;

  @override
  String toString() => message;
}

/// Morceau de réponse reçu en flux.
sealed class ClaudeEvent {
  const ClaudeEvent();
}

class ClaudeText extends ClaudeEvent {
  const ClaudeText(this.text);
  final String text;
}

class ClaudeStop extends ClaudeEvent {
  const ClaudeStop(this.reason);

  /// end_turn, max_tokens, refusal...
  final String? reason;
}

/// Message envoyé à l'API.
class ClaudeMessage {
  const ClaudeMessage(this.role, this.text);

  /// user ou assistant.
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'content': text};
}

/// Appels directs à l'API Messages d'Anthropic (pas de SDK Dart officiel).
class ClaudeClient {
  ClaudeClient({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  static final _base = Uri.parse('https://api.anthropic.com/v1/');
  static const _version = '2023-06-01';
  static const _fallbackBeta = 'server-side-fallback-2026-07-01';

  final String apiKey;
  final http.Client _client;
  bool _closed = false;

  Map<String, String> _headers({bool fallback = false}) => {
        'x-api-key': apiKey,
        'anthropic-version': _version,
        'content-type': 'application/json',
        if (fallback) 'anthropic-beta': _fallbackBeta,
      };

  /// Le niveau d'effort n'existe que sur les modèles récents.
  static bool supportsEffort(String model) {
    if (model.contains('haiku')) return false;
    final m = RegExp(r'claude-(opus|sonnet|fable|mythos)-(\d+)(?:-(\d+))?').firstMatch(model);
    if (m == null) return false;
    final major = int.parse(m.group(2)!);
    final minor = int.tryParse(m.group(3) ?? '') ?? 0;
    if (m.group(1) == 'fable' || m.group(1) == 'mythos') return true;
    return major >= 5 || (major == 4 && minor >= 6 && minor < 100);
  }

  /// Repli côté serveur si le modèle décline une demande (modèles qui l'acceptent).
  static bool supportsFallback(String model) =>
      const {'claude-sonnet-5-5', 'claude-opus-5-5', 'claude-opus-5', 'claude-fable-5-1', 'claude-fable-5'}.contains(model);

  /// Réponse en flux (SSE). Le flux se termine par un [ClaudeStop].
  Stream<ClaudeEvent> stream({
    required String model,
    required String system,
    required List<ClaudeMessage> messages,
    String? effort,
    int maxTokens = 16000,
  }) async* {
    final fallback = supportsFallback(model);
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'stream': true,
      'system': [
        {
          'type': 'text',
          'text': system,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      'messages': messages.map((m) => m.toJson()).toList(),
      if (effort != null && supportsEffort(model)) 'output_config': {'effort': effort},
      if (fallback) 'fallbacks': 'default',
    };
    final req = http.Request('POST', _base.resolve('messages'))
      ..headers.addAll(_headers(fallback: fallback))
      ..body = jsonEncode(body);

    http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const CoachApiException('Le coach met trop de temps à répondre. Vérifie ta connexion et réessaie.');
    } catch (e) {
      if (_closed) return;
      throw const CoachApiException('Pas de connexion au service du coach. Vérifie ta connexion internet.');
    }

    if (res.statusCode != 200) {
      final text = await res.stream.bytesToString().catchError((_) => '');
      throw _error(res.statusCode, text);
    }

    String? stop;
    String? event;
    try {
      final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines.timeout(const Duration(seconds: 90))) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
          continue;
        }
        if (!line.startsWith('data:')) continue;
        final raw = line.substring(5).trim();
        if (raw.isEmpty) continue;
        Map<String, dynamic> j;
        try {
          j = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final type = j['type'] as String? ?? event;
        switch (type) {
          case 'content_block_delta':
            final d = j['delta'];
            if (d is Map && d['type'] == 'text_delta') {
              final t = d['text'] as String? ?? '';
              if (t.isNotEmpty) yield ClaudeText(t);
            }
          case 'message_delta':
            final d = j['delta'];
            if (d is Map && d['stop_reason'] != null) stop = d['stop_reason'] as String;
          case 'error':
            final e = j['error'];
            final kind = e is Map ? e['type'] as String? : null;
            if (kind == 'overloaded_error') {
              throw const CoachApiException('Le service du coach est surchargé. Réessaie dans un instant.', status: 529);
            }
            throw CoachApiException(
              'Le coach a été interrompu${e is Map && e['message'] != null ? ' (${e['message']})' : ''}. Réessaie.',
            );
          case 'message_stop':
            yield ClaudeStop(stop);
            return;
        }
      }
    } on TimeoutException {
      throw const CoachApiException('La réponse s\'est interrompue. Réessaie.');
    } on CoachApiException {
      rethrow;
    } catch (_) {
      if (_closed) return;
      throw const CoachApiException('La connexion a été coupée pendant la réponse. Réessaie.');
    }
    yield ClaudeStop(stop);
  }

  /// Réponse complète (phrase du jour, bilan). Lève [CoachApiException].
  Future<String> complete({
    required String model,
    required String system,
    required String prompt,
    String? effort,
    int maxTokens = 4000,
  }) async {
    final buf = StringBuffer();
    String? stop;
    await for (final e in stream(
      model: model,
      system: system,
      messages: [ClaudeMessage('user', prompt)],
      effort: effort,
      maxTokens: maxTokens,
    )) {
      switch (e) {
        case ClaudeText(:final text):
          buf.write(text);
        case ClaudeStop(:final reason):
          stop = reason;
      }
    }
    if (stop == 'refusal') {
      throw const CoachApiException('Le coach n\'a pas pu traiter cette demande.', reessayable: false);
    }
    return buf.toString().trim();
  }

  /// Vérifie la clé et renvoie les modèles disponibles (id, nom affiché).
  Future<List<(String, String)>> listModels() async {
    http.Response res;
    try {
      res = await _client
          .get(_base.resolve('models?limit=100'), headers: _headers())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const CoachApiException('Le service ne répond pas. Vérifie ta connexion et réessaie.');
    } catch (_) {
      throw const CoachApiException('Pas de connexion au service. Vérifie ta connexion internet.');
    }
    if (res.statusCode != 200) throw _error(res.statusCode, res.body);
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    final data = j is Map ? j['data'] : null;
    if (data is! List) return const [];
    return [
      for (final m in data)
        if (m is Map && m['id'] is String) (m['id'] as String, (m['display_name'] as String?) ?? m['id'] as String),
    ];
  }

  CoachApiException _error(int status, String body) {
    String? detail;
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] is Map) detail = (j['error'] as Map)['message'] as String?;
    } catch (_) {}
    return switch (status) {
      401 => const CoachApiException('Clé API refusée. Vérifie-la dans les réglages du coach.', status: 401, cleInvalide: true, reessayable: false),
      403 => const CoachApiException('Cette clé n\'a pas accès à ce service ou à ce modèle.', status: 403, cleInvalide: true, reessayable: false),
      404 => const CoachApiException('Modèle introuvable. Choisis-en un autre dans les réglages du coach.', status: 404, reessayable: false),
      413 => const CoachApiException('La conversation est trop longue. Commence-en une nouvelle.', status: 413, reessayable: false),
      429 => const CoachApiException('Trop de demandes pour le moment. Patiente un peu avant de réessayer.', status: 429),
      402 => const CoachApiException('Crédit insuffisant sur ton compte API.', status: 402, reessayable: false),
      400 => CoachApiException(
          (detail ?? '').contains('credit')
              ? 'Crédit insuffisant sur ton compte API.'
              : 'Demande refusée par le service${detail == null ? '' : ' : $detail'}.',
          status: 400,
          reessayable: false,
        ),
      529 || 503 => CoachApiException('Le service du coach est surchargé. Réessaie dans un instant.', status: status),
      _ => CoachApiException('Le service du coach a rencontré une erreur ($status). Réessaie.', status: status),
    };
  }

  /// Coupe la requête en cours (bouton Arrêter).
  void close() {
    _closed = true;
    _client.close();
  }
}
