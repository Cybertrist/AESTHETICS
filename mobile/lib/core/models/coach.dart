import 'json.dart';

enum CoachRole { utilisateur, coach, systeme }

/// Message échangé avec le coach.
class CoachMessage {
  const CoachMessage({required this.id, required this.role, required this.texte, required this.date, this.enErreur = false});

  final String id;
  final CoachRole role;
  final String texte;
  final DateTime date;
  final bool enErreur;

  CoachMessage copyWith({String? texte, bool? enErreur}) =>
      CoachMessage(id: id, role: role, texte: texte ?? this.texte, date: date, enErreur: enErreur ?? this.enErreur);

  factory CoachMessage.fromJson(Json j) => CoachMessage(
        id: asString(j['id']) ?? '',
        role: enumByName(CoachRole.values, j['role'], CoachRole.utilisateur),
        texte: asString(j['texte']) ?? '',
        date: asDate(j['date']) ?? DateTime.now(),
        enErreur: asBool(j['enErreur']),
      );

  Json toJson() => compact({
        'id': id,
        'role': role.name,
        'texte': texte,
        'date': dateOut(date),
        'enErreur': enErreur ? true : null,
      });
}

/// Conversation avec le coach.
class Conversation {
  const Conversation({required this.id, required this.titre, this.messages = const [], required this.creeLe, this.modifieLe, this.epinglee = false});

  final String id;
  final String titre;
  final List<CoachMessage> messages;
  final DateTime creeLe;
  final DateTime? modifieLe;
  final bool epinglee;

  DateTime get derniereActivite => modifieLe ?? creeLe;

  Conversation copyWith({String? titre, List<CoachMessage>? messages, DateTime? modifieLe, bool? epinglee}) => Conversation(
        id: id,
        titre: titre ?? this.titre,
        messages: messages ?? this.messages,
        creeLe: creeLe,
        modifieLe: modifieLe ?? this.modifieLe,
        epinglee: epinglee ?? this.epinglee,
      );

  factory Conversation.fromJson(Json j) => Conversation(
        id: asString(j['id']) ?? '',
        titre: asString(j['titre']) ?? 'Conversation',
        messages: asList(j['messages'], CoachMessage.fromJson),
        creeLe: asDate(j['creeLe']) ?? DateTime.now(),
        modifieLe: asDate(j['modifieLe']),
        epinglee: asBool(j['epinglee']),
      );

  Json toJson() => compact({
        'id': id,
        'titre': titre,
        'messages': messages.map((m) => m.toJson()).toList(),
        'creeLe': dateOut(creeLe),
        'modifieLe': dateOut(modifieLe),
        'epinglee': epinglee ? true : null,
      });
}
