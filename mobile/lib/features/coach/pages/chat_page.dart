import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../data/claude_client.dart';
import '../logic/coach_actions.dart';
import '../logic/coach_engine.dart';
import '../logic/coach_snapshot.dart';
import '../logic/offline_coach.dart';
import '../widgets/action_card.dart';
import '../widgets/coach_cards.dart';
import '../widgets/coach_markdown.dart';
import '../widgets/coach_scope.dart';

/// Ouvre une conversation (nouvelle si [id] est nul), avec une question à poser tout de suite.
void openCoachChat(BuildContext context, {String? id, String? question}) {
  final q = question == null || question.trim().isEmpty ? '' : '?q=${Uri.encodeQueryComponent(question.trim())}';
  context.push('/coach/discussion/${id ?? 'nouvelle'}$q');
}

/// Conversation avec le coach : réponses en flux, markdown, actions validables.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.conversationId, this.question});

  final String? conversationId;

  /// Question envoyée dès l'ouverture.
  final String? question;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String? _id;

  @override
  void initState() {
    super.initState();
    _id = widget.conversationId;
    _input.addListener(() => setState(() {}));
    final q = widget.question;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(q);
      });
    }
  }

  @override
  void didUpdateWidget(ChatPage old) {
    super.didUpdateWidget(old);
    // Même route réutilisée pour une autre conversation ou une autre question.
    if (old.conversationId != widget.conversationId || old.question != widget.question) {
      _id = widget.conversationId;
      final q = widget.question;
      if (q != null && q.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _send(q);
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? texte]) async {
    final t = (texte ?? _input.text).trim();
    if (t.isEmpty) return;
    final repo = context.read<CoachRepo>();
    final engine = context.coachEngine;
    final settings = context.read<SettingsRepo>().settings;
    final snapshot = CoachSnapshot.read(context);
    if (_id != null && engine.enCours(_id!)) return;
    if (texte == null) _input.clear();
    if (_id == null) {
      final c = await repo.create(titre: CoachEngine.nouvelleConversation);
      if (!mounted) return;
      setState(() => _id = c.id);
    }
    _toBottom();
    await engine.send(repo: repo, conversationId: _id!, texte: t, snapshot: snapshot, settings: settings);
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: AppTokens.normal, curve: Curves.easeOut);
  }

  Future<void> _retry(CoachMessage m) async {
    final id = _id;
    if (id == null) return;
    await context.coachEngine.retry(
      repo: context.read<CoachRepo>(),
      conversationId: id,
      messageId: m.id,
      snapshot: CoachSnapshot.read(context),
      settings: context.read<SettingsRepo>().settings,
    );
  }

  Future<void> _menu(String action, Conversation c) async {
    final repo = context.read<CoachRepo>();
    switch (action) {
      case 'renommer':
        final t = await showTextInputDialog(context, title: 'Renommer la conversation', initial: c.titre, maxLength: 60);
        if (t != null && t.trim().isNotEmpty) await repo.rename(c.id, t.trim());
      case 'epingler':
        await repo.togglePin(c.id);
        if (mounted) Toasts.show(context, c.epinglee ? 'Conversation désépinglée.' : 'Conversation épinglée en haut de l\'historique.');
      case 'copier':
        final texte = c.messages
            .where((m) => !m.enErreur && m.texte.isNotEmpty)
            .map((m) => '${m.role == CoachRole.coach ? 'Coach' : 'Moi'} : ${CoachAction.parse(m.texte).texte}')
            .join('\n\n');
        await Clipboard.setData(ClipboardData(text: texte));
        if (mounted) Toasts.success(context, 'Conversation copiée.');
      case 'contexte':
        context.push('/coach/reglages/contexte');
      case 'reglages':
        context.push('/coach/reglages');
      case 'supprimer':
        final ok = await showConfirmDialog(
          context,
          title: 'Supprimer cette conversation ?',
          message: 'Les messages seront effacés du téléphone. Les routines et repas déjà ajoutés restent.',
          confirmLabel: 'Supprimer',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !mounted) return;
        context.coachEngine.stop(c.id);
        await repo.delete(c.id);
        if (mounted) context.pop();
    }
  }

  Future<void> _messageMenu(CoachMessage m, bool dernierCoach) async {
    final id = _id;
    if (id == null) return;
    final estCoach = m.role == CoachRole.coach;
    final choix = await showActionMenu<String>(
      context,
      items: [
        const ActionMenuItem(value: 'copier', label: 'Copier le texte', icon: Icons.copy_rounded),
        if (!estCoach) const ActionMenuItem(value: 'modifier', label: 'Modifier et renvoyer', icon: Icons.edit_rounded),
        if (estCoach && dernierCoach) const ActionMenuItem(value: 'regenerer', label: 'Nouvelle réponse', icon: Icons.refresh_rounded),
        ActionMenuItem(
          value: 'supprimer',
          label: estCoach ? 'Supprimer ce message' : 'Supprimer la question et sa réponse',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || choix == null) return;
    final repo = context.read<CoachRepo>();
    switch (choix) {
      case 'copier':
        await Clipboard.setData(ClipboardData(text: estCoach ? CoachAction.parse(m.texte).texte : m.texte));
        if (mounted) Toasts.success(context, 'Texte copié.');
      case 'modifier':
        await context.coachEngine.deleteMessage(repo, id, m.id);
        _input.text = m.texte;
        _input.selection = TextSelection.collapsed(offset: m.texte.length);
        _focus.requestFocus();
      case 'regenerer':
        await _retry(m);
      case 'supprimer':
        await context.coachEngine.deleteMessage(repo, id, m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<CoachRepo>();
    final settings = context.watch<SettingsRepo>().settings;
    final key = CoachEngine.cle(settings);
    final conv = _id == null ? null : repo.byId(_id!);

    if (_id != null && conv == null) {
      return SubPageScaffold(
        title: 'Conversation',
        body: EmptyState(
          icon: Icons.forum_outlined,
          title: 'Conversation introuvable',
          message: 'Elle a peut-être été supprimée.',
          actionLabel: 'Nouvelle conversation',
          onAction: () => setState(() => _id = null),
        ),
      );
    }

    return CoachListen(builder: (context, prefs, engine) {
      final live = _id == null ? null : engine.live(_id!);
      final streaming = live != null;
      final messages = conv?.messages ?? const <CoachMessage>[];
      final dernierCoachId = messages.lastWhere((m) => m.role == CoachRole.coach, orElse: () => _noMsg).id;
      final snapshot = CoachSnapshot.read(context);

      final body = messages.isEmpty && !streaming
          ? _EmptyChat(
              offline: key == null,
              suggestions: OfflineCoach.suggestions(snapshot),
              onAsk: _send,
            )
          : ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 12, AppTokens.gutter, 16),
              itemCount: messages.length + (key == null || engine.cleRefusee ? 1 : 0),
              itemBuilder: (context, i) {
                final bandeau = key == null || engine.cleRefusee;
                if (bandeau && i == messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: key == null ? const OfflineBanner(compact: true) : _KeyRefused(onDismiss: engine.oublierRefus),
                  );
                }
                final m = messages[messages.length - 1 - i];
                final enDirect = live != null && live.messageId == m.id;
                final precedent = messages.length - 2 - i >= 0 ? messages[messages.length - 2 - i] : null;
                return Padding(
                  padding: EdgeInsets.only(top: precedent != null && precedent.role != m.role ? 18 : 8),
                  child: m.role == CoachRole.utilisateur
                      ? _UserBubble(message: m, onLongPress: () => _messageMenu(m, false))
                      : _CoachMessageView(
                          message: m,
                          liveText: enDirect ? live.texte : null,
                          offline: key == null,
                          onRetry: () => _retry(m),
                          onLongPress: enDirect ? null : () => _messageMenu(m, m.id == dernierCoachId),
                          last: m.id == dernierCoachId,
                        ),
                );
              },
            );

      return SubPageScaffold(
        title: conv?.titre ?? 'Nouvelle conversation',
        subtitle: key == null ? 'Mode hors ligne' : CoachModels.nom(settings.coachModele),
        closeIcon: false,
        actions: [
          if (conv != null)
            PopupMenuButton<String>(
              tooltip: 'Options',
              icon: Icon(Icons.more_vert_rounded, color: c.text),
              onSelected: (v) => _menu(v, conv),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'renommer', child: Text('Renommer')),
                PopupMenuItem(value: 'epingler', child: Text(conv.epinglee ? 'Désépingler' : 'Épingler')),
                const PopupMenuItem(value: 'copier', child: Text('Copier la conversation')),
                const PopupMenuItem(value: 'contexte', child: Text('Ce que voit le coach')),
                const PopupMenuItem(value: 'reglages', child: Text('Réglages du coach')),
                PopupMenuItem(value: 'supprimer', child: Text('Supprimer', style: TextStyle(color: c.error))),
              ],
            )
          else
            IconButton(
              tooltip: 'Réglages du coach',
              onPressed: () => context.push('/coach/reglages'),
              icon: Icon(Icons.tune_rounded, color: c.text),
            ),
        ],
        body: Column(
          children: [
            Expanded(child: body),
            CoachBottomBar(
              child: _Composer(
                controller: _input,
                focus: _focus,
                streaming: streaming,
                onSend: () => _send(),
                onStop: () => engine.stop(_id!),
              ),
            ),
          ],
        ),
      );
    });
  }
}

final _noMsg = CoachMessage(id: '', role: CoachRole.coach, texte: '', date: DateTime(2000));

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.offline, required this.suggestions, required this.onAsk});

  final bool offline;
  final List<String> suggestions;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTokens.gutter, 24, AppTokens.gutter, 24),
      children: [
        Center(child: IconHalo.domain(AppDomain.coach, size: 64)),
        const SizedBox(height: 18),
        Text('Pose ta question', textAlign: TextAlign.center, style: AppType.screenTitle()),
        const SizedBox(height: 6),
        Text(
          offline
              ? 'Je réponds avec les règles calculées sur ton téléphone à partir de tes séances, repas et nuits.'
              : 'Je lis tes séances, records, repas, nuits et ta récupération pour te répondre au plus juste.',
          textAlign: TextAlign.center,
          style: AppType.rowSubtitle(),
        ),
        const SizedBox(height: 22),
        Text('SUGGESTIONS', style: AppType.overline(color: c.text3)),
        const SizedBox(height: 10),
        for (final q in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => onAsk(q),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(q, style: AppType.rowTitle().copyWith(fontSize: 15))),
                  Icon(Icons.north_east_rounded, size: 18, color: c.text3),
                ],
              ),
            ),
          ),
        if (offline) ...[
          const SizedBox(height: 16),
          const OfflineBanner(),
        ],
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.onLongPress});

  final CoachMessage message;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8 > 560 ? 560 : MediaQuery.sizeOf(context).width * 0.8),
        child: Material(
          color: c.surface3,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Text(message.texte, style: AppType.rowTitle().copyWith(fontSize: 15, height: 1.4)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachMessageView extends StatelessWidget {
  const _CoachMessageView({
    required this.message,
    required this.liveText,
    required this.offline,
    required this.onRetry,
    required this.onLongPress,
    required this.last,
  });

  final CoachMessage message;

  /// Texte en train d'arriver (null si le message est terminé).
  final String? liveText;
  final bool offline;
  final VoidCallback onRetry;
  final VoidCallback? onLongPress;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final streaming = liveText != null;
    final raw = liveText ?? message.texte;
    final parsed = CoachAction.parse(raw);

    Widget content;
    if (message.enErreur && !streaming) {
      final clef = message.texte.contains('Clé API') || message.texte.contains('clé');
      content = AppCard(
        color: c.error.withValues(alpha: 0.08),
        borderColor: c.error.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: c.error, size: 20),
                const SizedBox(width: 10),
                Expanded(child: CoachMarkdown(message.texte, size: 14.5)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(label: 'Réessayer', icon: Icons.refresh_rounded, size: PillSize.small, onPressed: onRetry),
                if (clef)
                  PillButton.link(label: 'Vérifier la clé', size: PillSize.small, onPressed: () => context.push('/coach/reglages/cle')),
              ],
            ),
          ],
        ),
      );
    } else if (streaming && raw.trim().isEmpty) {
      content = const _Typing();
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoachMarkdown(parsed.texte.isEmpty && !streaming ? '_(Réponse vide.)_' : parsed.texte),
          if (streaming && parsed.actionEnCours) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: c.accent)),
                const SizedBox(width: 8),
                Text('Le coach prépare une proposition…', style: AppType.rowSubtitle().copyWith(fontSize: 13)),
              ],
            ),
          ],
          if (!streaming)
            for (var i = 0; i < parsed.actions.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ActionCard(action: parsed.actions[i], actionKey: '${message.id}#$i'),
              ),
        ],
      );
    }

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconHalo.domain(AppDomain.coach, size: 26, glow: false),
              const SizedBox(width: 8),
              Text('Coach', style: AppType.rowTitle().copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
              if (offline && !message.enErreur) ...[
                const SizedBox(width: 8),
                Text('hors ligne', style: AppType.rowSubtitle().copyWith(fontSize: 12, color: c.text3)),
              ],
              const Spacer(),
              Text(Fmt.heure(message.date), style: AppType.rowSubtitle().copyWith(fontSize: 12, color: c.text3)),
            ],
          ),
          const SizedBox(height: 8),
          content,
          if (!streaming && !message.enErreur && raw.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _SmallAction(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copier',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: parsed.texte));
                      if (context.mounted) Toasts.success(context, 'Réponse copiée.');
                    },
                  ),
                  if (last) _SmallAction(icon: Icons.refresh_rounded, tooltip: 'Nouvelle réponse', onTap: onRetry),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: context.colors.text3),
      );
}

/// Trois points qui battent pendant que le coach réfléchit.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors.text2;
    return Semantics(
      label: 'Le coach réfléchit',
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Opacity(
                      opacity: 0.3 + 0.7 * (1 - ((_c.value * 3 - i) % 3 - 0.5).abs().clamp(0, 1)),
                      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('Le coach réfléchit…', style: AppType.rowSubtitle().copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _KeyRefused extends StatelessWidget {
  const _KeyRefused({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      borderColor: c.error.withValues(alpha: 0.3),
      color: c.error.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Icon(Icons.key_off_rounded, color: c.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('La clé API a été refusée.', style: AppType.rowSubtitle(color: c.text))),
          PillButton.link(label: 'Vérifier', size: PillSize.small, onPressed: () => context.push('/coach/reglages/cle')),
          IconButton(tooltip: 'Masquer', onPressed: onDismiss, icon: Icon(Icons.close_rounded, size: 18, color: c.text3)),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.streaming,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vide = controller.text.trim().isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: AppType.rowTitle().copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Écris au coach…',
              filled: true,
              fillColor: c.surface3,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              border: const OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide.none),
              enabledBorder: const OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: AppTokens.radius26, borderSide: BorderSide(color: c.accentBorder)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        streaming
            ? RoundIconButton(icon: Icons.stop_rounded, tooltip: 'Arrêter la réponse', filled: false, size: 48, onPressed: onStop)
            : RoundIconButton(icon: Icons.arrow_upward_rounded, tooltip: 'Envoyer', size: 48, onPressed: vide ? null : onSend),
      ],
    );
  }
}
