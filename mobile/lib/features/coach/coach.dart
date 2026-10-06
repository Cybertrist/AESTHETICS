/// Ce que le module coach offre aux autres modules.
///
/// - `CoachDailyCard` : phrase du jour (écran d'accueil).
/// - `CoachWeekCard` : bilan de la semaine en une carte.
/// - `openCoachChat(context, question: ...)` : ouvre le coach sur une question.
library;

export 'pages/chat_page.dart' show openCoachChat;
export 'widgets/coach_cards.dart' show CoachDailyCard, CoachWeekCard;
