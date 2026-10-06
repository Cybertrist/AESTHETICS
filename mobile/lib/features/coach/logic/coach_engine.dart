import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../data/claude_client.dart';
import '../data/coach_prefs.dart';
import 'coach_prompt.dart';
import 'coach_snapshot.dart';
import 'offline_coach.dart';
import 'week_report.dart';

/// Tirets longs et moyens, bannis de l'appli : remplacés par une virgule.
final _tirets = RegExp(r'\s*[' + String.fromCharCodes(const [0x2013, 0x2014]) + r']\s*');
final _tiretsChiffres = RegExp(r'(\d)\s*[' + String.fromCharCodes(const [0x2013, 0x2014]) + r']\s*(\d)');

/// « 8 tiret 12 » devient « 8 à 12 », les autres tirets une virgule.
String sansTirets(String t) => t.replaceAllMapped(_tiretsChiffres, (m) => '${m[1]} à ${m[2]}').replaceAll(_tirets, ', ');

/// Une seule phrase lisible : ni bloc de code, ni markdown, ni guillemets, 220 caractères au plus.
String phrasePropre(String t) {
  var s = sansTirets(t).replaceAll(RegExp(r'```[\s\S]*?(```|$)'), '').replaceAll(RegExp(r'[*_#>`]'), '');
  s = s.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
  s = s.replaceAll(RegExp(r'^["«\s]+|["»\s]+$'), '').trim();
  if (s.length > 220) s = '${s.substring(0, 217).trimRight()}…';
  return s;
}

/// Réponse en train d'arriver dans une conversation.
class LiveReply {
  LiveReply(this.messageId, this.client);
  final String messageId;
  final ClaudeClient? client;
  final StringBuffer buffer = StringBuffer();
  bool annule = false;
  String get texte => buffer.toString();
}

/// Cerveau du coach : envoie les messages, reçoit les réponses en flux,
/// tient la phrase du jour et les bilans. Une instance par Store, qui
/// survit aux changements de page (une réponse continue si l'on sort du chat).
class CoachEngine extends ChangeNotifier {
  CoachEngine._(this.store);

  static final _instances = Expando<CoachEngine>('coachEngine');
  static CoachEngine of(Store store) => _instances[store] ??= CoachEngine._(store);

  /// Pour les tests : client HTTP injecté.
  @visibleForTesting
  static ClaudeClient Function(String key)? clientFactory;

  final Store store;
  final Map<String, LiveReply> _live = {};
  bool _phraseEnCours = false;
  final Set<String> _bilansEnCours = {};
  final Map<String, String> _bilansErreurs = {};

  CoachPrefsController get prefsCtrl => CoachPrefsController.of(store);

  LiveReply? live(String conversationId) => _live[conversationId];
  bool enCours(String conversationId) => _live.containsKey(conversationId);
  bool get phraseEnCours => _phraseEnCours;
  bool bilanEnCours(String cle) => _bilansEnCours.contains(cle);
  String? bilanErreur(String cle) => _bilansErreurs[cle];

  static String? cle(AppSettings s) {
    final k = s.coachApiKey?.trim();
    return (k == null || k.isEmpty) ? null : k;
  }

  static String modele(AppSettings s) {
    final m = s.coachModele?.trim();
    return (m == null || m.isEmpty) ? CoachModels.defaut : m;
  }

  ClaudeClient _client(String key) => (clientFactory ?? (k) => ClaudeClient(apiKey: k))(key);

  // Conversation

  /// Ajoute la question puis la réponse (en ligne ou hors ligne).
  Future<void> send({
    required CoachRepo repo,
    required String conversationId,
    required String texte,
    required CoachSnapshot snapshot,
    required AppSettings settings,
  }) async {
    final t = texte.trim();
    if (t.isEmpty || enCours(conversationId)) return;
    await repo.addMessage(conversationId, CoachRole.utilisateur, t);
    await _titreAuto(repo, conversationId, t);
    await _respond(repo: repo, conversationId: conversationId, snapshot: snapshot, settings: settings);
  }

  /// Relance la réponse : retire le message du coach [messageId] (et ce qui suit).
  Future<void> retry({
    required CoachRepo repo,
    required String conversationId,
    required String messageId,
    required CoachSnapshot snapshot,
    required AppSettings settings,
  }) async {
    final c = repo.byId(conversationId);
    if (c == null || enCours(conversationId)) return;
    final i = c.messages.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    await repo.save(c.copyWith(messages: c.messages.sublist(0, i), modifieLe: DateTime.now()));
    await _respond(repo: repo, conversationId: conversationId, snapshot: snapshot, settings: settings);
  }

  /// Supprime un message (et, pour une question, la réponse qui suit).
  Future<void> deleteMessage(CoachRepo repo, String conversationId, String messageId) async {
    final c = repo.byId(conversationId);
    if (c == null) return;
    final i = c.messages.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    final list = [...c.messages]..removeAt(i);
    if (c.messages[i].role == CoachRole.utilisateur && i < list.length && list[i].role == CoachRole.coach) list.removeAt(i);
    await repo.save(c.copyWith(messages: list, modifieLe: DateTime.now()));
  }

  Future<void> _titreAuto(CoachRepo repo, String id, String premiere) async {
    final c = repo.byId(id);
    if (c == null || c.titre != nouvelleConversation) return;
    var titre = premiere.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (titre.length > 48) titre = '${titre.substring(0, 46).trimRight()}…';
    await repo.rename(id, titre);
  }

  static const nouvelleConversation = 'Nouvelle conversation';

  Future<void> _respond({
    required CoachRepo repo,
    required String conversationId,
    required CoachSnapshot snapshot,
    required AppSettings settings,
  }) async {
    await prefsCtrl.ready();
    final key = cle(settings);
    final conv = repo.byId(conversationId);
    if (conv == null) return;
    final question = conv.messages.lastWhere((m) => m.role == CoachRole.utilisateur, orElse: () => conv.messages.last).texte;

    if (key == null) {
      final m = await repo.addMessage(conversationId, CoachRole.coach, '');
      final live = LiveReply(m.id, null);
      _live[conversationId] = live;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final rep = OfflineCoach.repondre(snapshot, question);
      live.buffer.write(rep);
      _live.remove(conversationId);
      await repo.updateMessage(conversationId, m.copyWith(texte: rep));
      notifyListeners();
      return;
    }

    final history = _history(conv.messages);
    final m = await repo.addMessage(conversationId, CoachRole.coach, '');
    final client = _client(key);
    final live = LiveReply(m.id, client);
    _live[conversationId] = live;
    notifyListeners();

    var dernierSave = DateTime.now();
    String? stop;
    try {
      final system = CoachPrompt.system(
        snapshot: snapshot,
        prefs: prefsCtrl.prefs,
        ton: CoachTon.parse(settings.coachTon),
      );
      await for (final e in client.stream(
        model: modele(settings),
        system: system,
        messages: history,
        effort: prefsCtrl.prefs.reflexion.effort,
      )) {
        if (live.annule) break;
        switch (e) {
          case ClaudeText(:final text):
            live.buffer.write(text);
            notifyListeners();
            if (DateTime.now().difference(dernierSave) > const Duration(seconds: 2)) {
              dernierSave = DateTime.now();
              unawaited(repo.updateMessage(conversationId, m.copyWith(texte: live.texte)));
            }
          case ClaudeStop(:final reason):
            stop = reason;
        }
      }
      var texte = sansTirets(live.texte).trim();
      if (live.annule) {
        texte = texte.isEmpty ? '' : '$texte\n\n_(Réponse interrompue.)_';
      } else if (stop == 'refusal') {
        texte = '${texte.isEmpty ? '' : '$texte\n\n'}_Je ne peux pas répondre à cette demande. Reformule-la ou pose une autre question._';
      } else if (stop == 'max_tokens') {
        texte = '$texte\n\n_(Réponse coupée car trop longue. Demande-moi la suite.)_';
      }
      if (texte.isEmpty) {
        final c = repo.byId(conversationId);
        if (c != null) await repo.save(c.copyWith(messages: c.messages.where((x) => x.id != m.id).toList()));
      } else {
        await repo.updateMessage(conversationId, m.copyWith(texte: texte));
      }
    } on CoachApiException catch (err) {
      final partiel = live.texte.trim();
      await repo.updateMessage(
        conversationId,
        m.copyWith(texte: partiel.isEmpty ? err.message : '$partiel\n\n_${err.message}_', enErreur: true),
      );
      if (err.cleInvalide) _cleRefusee = true;
    } catch (_) {
      await repo.updateMessage(
        conversationId,
        m.copyWith(texte: 'Une erreur inattendue a interrompu la réponse. Réessaie.', enErreur: true),
      );
    } finally {
      _live.remove(conversationId);
      notifyListeners();
    }
  }

  bool _cleRefusee = false;

  /// La dernière requête a été refusée pour cause de clé (bandeau dans le chat).
  bool get cleRefusee => _cleRefusee;
  void oublierRefus() {
    _cleRefusee = false;
    notifyListeners();
  }

  /// Arrête la réponse en cours.
  void stop(String conversationId) {
    final l = _live[conversationId];
    if (l == null) return;
    l.annule = true;
    l.client?.close();
    notifyListeners();
  }

  /// Historique au format de l'API : alternance stricte, sans erreurs, commence par l'utilisateur.
  static List<ClaudeMessage> _history(List<CoachMessage> messages) {
    final out = <ClaudeMessage>[];
    final utiles = messages.where((m) => !m.enErreur && m.texte.trim().isNotEmpty && m.role != CoachRole.systeme).toList();
    final debut = utiles.length > 40 ? utiles.length - 40 : 0;
    for (final m in utiles.sublist(debut)) {
      final role = m.role == CoachRole.coach ? 'assistant' : 'user';
      if (out.isNotEmpty && out.last.role == role) {
        out[out.length - 1] = ClaudeMessage(role, '${out.last.text}\n\n${m.texte}');
      } else {
        out.add(ClaudeMessage(role, m.texte));
      }
    }
    if (out.isNotEmpty && out.first.role == 'assistant') out.insert(0, const ClaudeMessage('user', 'Bonjour coach.'));
    return out;
  }

  @visibleForTesting
  static List<ClaudeMessage> historyForTest(List<CoachMessage> m) => _history(m);

  // Phrase du jour

  static String jourCle(DateTime d) => WeekReport.cleSemaine(d);

  /// Phrase du jour : le cache du jour, sinon calculée, puis rédigée en ligne si possible.
  String phraseDuJour({required CoachSnapshot snapshot, required AppSettings settings, bool rafraichir = false}) {
    final p = prefsCtrl.prefs;
    final today = jourCle(snapshot.now);
    final key = cle(settings);
    final cache = p.phraseDate == today ? p.phraseTexte : null;
    final hors = cache ?? OfflineCoach.phraseDuJour(snapshot);
    if (!prefsCtrl.loaded) return hors;
    final veutIa = key != null && p.phraseIa;
    final aJour = cache != null && (!veutIa || p.phraseParIa) && !rafraichir;
    if (aJour) return cache;
    if (veutIa) {
      final echec = _dernierEchecPhrase;
      final recent = !rafraichir && echec != null && DateTime.now().difference(echec) < const Duration(minutes: 30);
      if (!_phraseEnCours && !recent) {
        _phraseEnCours = true;
        // Hors de la construction du widget qui demande la phrase.
        scheduleMicrotask(() => _phraseIa(snapshot, settings, key, today));
      }
    } else if (cache == null) {
      scheduleMicrotask(() => prefsCtrl.update((x) => x.copyWith(phraseDate: today, phraseTexte: hors, phraseParIa: false)));
    }
    return hors;
  }

  DateTime? _dernierEchecPhrase;

  Future<void> _phraseIa(CoachSnapshot s, AppSettings settings, String key, String today) async {
    notifyListeners();
    try {
      final t = await _client(key).complete(
        model: modele(settings),
        system: CoachPrompt.system(snapshot: s, prefs: prefsCtrl.prefs, ton: CoachTon.parse(settings.coachTon)),
        prompt: CoachPrompt.phraseDuJour(s),
        effort: 'low',
        maxTokens: 2000,
      );
      final propre = phrasePropre(t);
      if (propre.isNotEmpty) {
        await prefsCtrl.update((x) => x.copyWith(phraseDate: today, phraseTexte: propre, phraseParIa: true));
      }
    } catch (_) {
      _dernierEchecPhrase = DateTime.now();
      if (prefsCtrl.prefs.phraseDate != today) {
        final t = OfflineCoach.phraseDuJour(s);
        await prefsCtrl.update((x) => x.copyWith(phraseDate: today, phraseTexte: t, phraseParIa: false));
      }
    } finally {
      _phraseEnCours = false;
      notifyListeners();
    }
  }

  // Bilan

  Future<void> redigerBilan({required WeekReport report, required CoachSnapshot snapshot, required AppSettings settings}) async {
    final key = cle(settings);
    if (key == null || _bilansEnCours.contains(report.cle)) return;
    _bilansEnCours.add(report.cle);
    _bilansErreurs.remove(report.cle);
    notifyListeners();
    try {
      final t = await _client(key).complete(
        model: modele(settings),
        system: CoachPrompt.system(snapshot: snapshot, prefs: prefsCtrl.prefs, ton: CoachTon.parse(settings.coachTon)),
        prompt: CoachPrompt.bilan(report.donnees(snapshot.exercises.nameOf)),
        effort: prefsCtrl.prefs.reflexion.effort,
        maxTokens: 8000,
      );
      final propre = sansTirets(t).replaceAll(RegExp(r'```action[\s\S]*?```'), '').trim();
      await prefsCtrl.update((x) => x.copyWith(bilans: {...x.bilans, report.cle: propre}));
    } on CoachApiException catch (e) {
      _bilansErreurs[report.cle] = e.message;
    } catch (_) {
      _bilansErreurs[report.cle] = 'Le bilan n\'a pas pu être rédigé. Réessaie.';
    } finally {
      _bilansEnCours.remove(report.cle);
      notifyListeners();
    }
  }

  /// Le dimanche (ou après), rédige tout seul le bilan de la semaine si réglé ainsi.
  void bilanAuto({required CoachSnapshot snapshot, required AppSettings settings}) {
    final p = prefsCtrl.prefs;
    if (!prefsCtrl.loaded || !p.bilanDimanche || cle(settings) == null) return;
    if (snapshot.now.weekday != DateTime.sunday) return;
    final report = WeekReport.build(snapshot, snapshot.now);
    if (report.sessions.isEmpty || p.bilans.containsKey(report.cle) || _bilansErreurs.containsKey(report.cle)) return;
    scheduleMicrotask(() => redigerBilan(report: report, snapshot: snapshot, settings: settings));
  }

  /// Oublie les bilans et la phrase (après un changement de réglages ou un effacement).
  Future<void> effacerCaches() => prefsCtrl.update((p) => p.copyWith(bilans: const {}, clearPhrase: true, actionsAppliquees: const {}));

  /// Petite aide pour les pages : jour affiché du bilan courant.
  static DateTime semaineCourante(CoachSnapshot s) => Dates.debutSemaine(s.now, premierJour: s.premierJour);
}
