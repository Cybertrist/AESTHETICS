import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Scan d'un code-barres en plein écran. Rend le code lu (ou saisi).
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive) {
      _controller.stop();
    }
  }

  static bool _valid(String? v) => v != null && RegExp(r'^\d{6,14}$').hasMatch(v);

  void _finish(String code) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (_valid(v)) {
        _finish(v!);
        return;
      }
    }
  }

  Future<void> _manual() async {
    final code = await showTextInputDialog(context, title: 'Saisir le code-barres', hint: 'Les chiffres sous les barres', confirmLabel: 'Chercher', maxLength: 14);
    if (code == null || !mounted) return;
    final t = code.replaceAll(RegExp(r'\s'), '');
    if (!_valid(t)) {
      Toasts.error(context, 'Un code-barres compte de 8 à 14 chiffres.');
      return;
    }
    _finish(t);
  }

  Future<void> _fromPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null || !mounted) return;
    try {
      final r = await _controller.analyzeImage(img.path);
      final code = r?.barcodes.map((b) => b.rawValue).firstWhere(_valid, orElse: () => null);
      if (!mounted) return;
      if (code == null) {
        Toasts.error(context, 'Aucun code-barres lisible sur cette photo.');
      } else {
        _finish(code);
      }
    } catch (_) {
      if (mounted) Toasts.error(context, 'Impossible de lire cette photo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 64).clamp(200.0, 360.0);
        final window = Rect.fromCenter(center: Offset(box.maxWidth / 2, box.maxHeight * 0.42), width: w, height: w * 0.62);
        return Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: window,
                errorBuilder: (context, error) => _ScanError(error: error, onManual: _manual),
                placeholderBuilder: (context) => ColoredBox(color: c.bg, child: Center(child: CircularProgressIndicator(color: c.accent))),
              ),
            ),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _WindowPainter(window, c.accent)))),
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _Round(icon: Icons.close_rounded, tooltip: 'Fermer', onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, s, _) {
                      if (s.torchState == TorchState.unavailable) return const SizedBox.shrink();
                      final on = s.torchState == TorchState.on;
                      return _Round(icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded, tooltip: on ? 'Éteindre la lampe' : 'Allumer la lampe', active: on, onTap: _controller.toggleTorch);
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: window.bottom + 18,
              left: 24,
              right: 24,
              child: Text(
                'Place le code-barres dans le cadre',
                textAlign: TextAlign.center,
                style: AppType.rowTitle().copyWith(shadows: const [Shadow(blurRadius: 8, color: Colors.black)]),
              ),
            ),
            Positioned(
              left: AppTokens.gutter,
              right: AppTokens.gutter,
              bottom: bottom + 16,
              child: Row(children: [
                Expanded(child: PillButton(label: 'Saisir le code', icon: Icons.keyboard_rounded, variant: PillVariant.outline, expand: true, onPressed: _manual)),
                const SizedBox(width: 10),
                Expanded(child: PillButton(label: 'Depuis une photo', icon: Icons.photo_library_rounded, variant: PillVariant.outline, expand: true, onPressed: _fromPhoto)),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onTap, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? c.accent : Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: active ? c.onAccent : Colors.white)),
        ),
      ),
    );
  }
}

/// Assombrit tout sauf le cadre de lecture, coins d'accent.
class _WindowPainter extends CustomPainter {
  _WindowPainter(this.window, this.color);
  final Rect window;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(22));
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.55));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    final w = window;
    for (final (o, dx, dy) in [
      (w.topLeft, 1.0, 1.0),
      (w.topRight, -1.0, 1.0),
      (w.bottomLeft, 1.0, -1.0),
      (w.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * l)
        ..lineTo(o.dx, o.dy + dy * 12)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * 12, o.dy)
        ..lineTo(o.dx + dx * l, o.dy);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window || old.color != color;
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.error, required this.onManual});
  final MobileScannerException error;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: denied ? Icons.no_photography_rounded : Icons.videocam_off_rounded,
            title: denied ? 'Accès à la caméra refusé' : 'Caméra indisponible',
            message: denied
                ? 'Autorise la caméra dans les réglages du téléphone pour scanner, ou saisis le code à la main.'
                : 'La caméra ne répond pas. Tu peux saisir le code à la main.',
            actionLabel: denied ? 'Ouvrir les réglages' : 'Saisir le code',
            onAction: denied ? () => openAppSettings() : onManual,
            secondaryLabel: denied ? 'Saisir le code' : null,
            onSecondary: denied ? onManual : null,
          ),
        ),
      ),
    );
  }
}
