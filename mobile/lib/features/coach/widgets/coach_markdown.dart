import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/theme.dart';

/// Texte du coach en markdown, aux couleurs de l'appli.
class CoachMarkdown extends StatelessWidget {
  const CoachMarkdown(this.data, {super.key, this.selectable = false, this.size = 15, this.color});

  final String data;
  final bool selectable;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(
      fontFamily: AppTokens.fontUi,
      fontSize: size,
      height: 1.5,
      color: color ?? c.text,
      fontWeight: FontWeight.w400,
    );
    final sheet = MarkdownStyleSheet(
      p: base,
      pPadding: EdgeInsets.zero,
      strong: const TextStyle(fontWeight: FontWeight.w800),
      em: TextStyle(fontStyle: FontStyle.italic, color: c.text2),
      a: TextStyle(color: c.accent, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: c.accent),
      h1: base.copyWith(fontSize: size + 4, fontWeight: FontWeight.w800, height: 1.3),
      h2: base.copyWith(fontSize: size + 2, fontWeight: FontWeight.w800, height: 1.3),
      h3: base.copyWith(fontSize: size + 1, fontWeight: FontWeight.w800, height: 1.3),
      h4: base.copyWith(fontWeight: FontWeight.w800),
      h1Padding: const EdgeInsets.only(top: 6),
      h2Padding: const EdgeInsets.only(top: 6),
      h3Padding: const EdgeInsets.only(top: 6),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: size - 2,
        color: c.text,
        backgroundColor: c.surface3,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(color: c.surface3, borderRadius: AppTokens.radius12),
      blockquote: base.copyWith(color: c.text2),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      blockquoteDecoration: BoxDecoration(
        color: AppTokens.veil2,
        borderRadius: AppTokens.radius12,
      ),
      listBullet: base.copyWith(color: c.accent, fontWeight: FontWeight.w800),
      listIndent: 22,
      blockSpacing: 10,
      horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      tableHead: base.copyWith(fontWeight: FontWeight.w800),
      tableBody: base,
      tableBorder: TableBorder.all(color: c.line),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: sheet,
      softLineBreak: true,
      onTapLink: (text, href, title) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
