import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import 'halo.dart';
import 'pill_button.dart';

/// État vide : icône dans un rond gris, titre, explication, action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  /// Couleur de l'icône ; blanc par défaut.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.textStyles;
    final disc = compact ? 52.0 : 68.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 20 : 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconHalo(icon: icon, size: disc, color: iconColor),
              SizedBox(height: compact ? 14 : 20),
              Text(title, textAlign: TextAlign.center, style: compact ? t.titleMedium : t.titleLarge),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: c.text2)),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? 16 : 24),
                PillButton(label: actionLabel!, onPressed: onAction),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 8),
                PillButton.ghost(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum ToastKind { info, success, error }

/// Messages éphémères en bas de l'écran.
abstract final class Toasts {
  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final c = context.colors;
    final (IconData ic, Color col) = switch (kind) {
      ToastKind.info => (icon ?? Icons.info_outline_rounded, c.text2),
      ToastKind.success => (icon ?? Icons.check_circle_rounded, c.foretClair),
      ToastKind.error => (icon ?? Icons.error_outline_rounded, c.error),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: duration,
        // Avec un bouton, Flutter garde le message à l'écran indéfiniment : il
        // part quand même au bout de sa durée.
        persist: false,
        content: Row(
          children: [
            Icon(ic, color: col, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: context.textStyles.bodyMedium)),
          ],
        ),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ));
  }

  static void success(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(context, message, kind: ToastKind.success, actionLabel: actionLabel, onAction: onAction);

  static void error(BuildContext context, String message) => show(context, message, kind: ToastKind.error);
}

/// Bloc de chargement animé (reflet qui glisse).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = AppTokens.r8, this.circle = false});

  const Skeleton.circle({super.key, double size = 40})
      : width = size,
        height = size,
        radius = size,
        circle = true;

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final x = _ctrl.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [c.surface, c.surface2, c.surface],
            ),
          ),
        );
      },
    );
  }
}

/// Liste factice pendant un chargement.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.leading = true});

  final int count;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter, vertical: 10),
            child: Row(
              children: [
                if (leading) ...[const Skeleton(width: 48, height: 48, radius: 8), const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: 0.4 + (i % 3) * 0.15, child: const Skeleton(height: 14)),
                      const SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: 0.3 + (i % 2) * 0.2, child: const Skeleton(height: 10)),
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
