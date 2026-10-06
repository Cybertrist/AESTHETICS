import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../collection.dart';
import '../store.dart';

/// Conversations avec le coach.
class CoachRepo extends ChangeNotifier {
  CoachRepo(this.store)
      : _conversations = JsonCollection(
          store: store,
          name: 'coach_conversations',
          fromJson: Conversation.fromJson,
          toJson: (c) => c.toJson(),
          idOf: (c) => c.id,
        );

  final Store store;
  final JsonCollection<Conversation> _conversations;

  /// Épinglées d'abord, puis la plus récente.
  List<Conversation> get conversations => [..._conversations.items]
    ..sort((a, b) {
      if (a.epinglee != b.epinglee) return a.epinglee ? -1 : 1;
      return b.derniereActivite.compareTo(a.derniereActivite);
    });

  Future<void> load() async {
    await _conversations.load();
    notifyListeners();
  }

  Conversation? byId(String id) => _conversations.byId(id);

  Future<Conversation> create({String titre = 'Nouvelle conversation'}) async {
    final c = Conversation(id: newId(), titre: titre, creeLe: DateTime.now());
    await _conversations.upsert(c);
    notifyListeners();
    return c;
  }

  Future<void> save(Conversation c) async {
    await _conversations.upsert(c);
    notifyListeners();
  }

  /// Ajoute un message et renvoie son identifiant.
  Future<CoachMessage> addMessage(String conversationId, CoachRole role, String texte) async {
    final c = byId(conversationId);
    final m = CoachMessage(id: newId(), role: role, texte: texte, date: DateTime.now());
    if (c == null) return m;
    await save(c.copyWith(messages: [...c.messages, m], modifieLe: m.date));
    return m;
  }

  /// Remplace un message (réponse qui arrive par morceaux, erreur…).
  Future<void> updateMessage(String conversationId, CoachMessage m) async {
    final c = byId(conversationId);
    if (c == null) return;
    await save(c.copyWith(messages: [for (final x in c.messages) x.id == m.id ? m : x], modifieLe: DateTime.now()));
  }

  Future<void> rename(String id, String titre) async {
    final c = byId(id);
    if (c != null) await save(c.copyWith(titre: titre));
  }

  Future<void> togglePin(String id) async {
    final c = byId(id);
    if (c != null) await save(c.copyWith(epinglee: !c.epinglee));
  }

  Future<void> delete(String id) async {
    await _conversations.remove(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await _conversations.clear();
    notifyListeners();
  }
}
