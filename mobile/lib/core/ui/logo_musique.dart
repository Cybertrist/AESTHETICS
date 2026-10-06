import 'package:flutter/material.dart';

/// Logo de l'appli de musique ouverte par le bouton de la séance :
/// « spotify » ou « youtube » (YouTube Music).
class LogoMusique extends StatelessWidget {
  const LogoMusique(this.service, {super.key, this.size = 24});

  final String service;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _LogoPainter(service == 'spotify')));
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.spotify);
  final bool spotify;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    const centre = Offset(12, 12);
    if (spotify) {
      canvas.drawCircle(centre, 12, Paint()..color = const Color(0xFF1ED760));
      Paint trait(double ep) => Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = ep
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(Path()..moveTo(5.6, 9.0)..quadraticBezierTo(12.2, 6.4, 18.6, 10.1), trait(2.2));
      canvas.drawPath(Path()..moveTo(6.5, 12.6)..quadraticBezierTo(12.1, 10.5, 17.4, 13.5), trait(1.9));
      canvas.drawPath(Path()..moveTo(7.3, 15.9)..quadraticBezierTo(12, 14.3, 16.1, 16.6), trait(1.6));
      return;
    }
    canvas.drawCircle(centre, 12, Paint()..color = const Color(0xFFFF0000));
    canvas.drawCircle(
      centre,
      6.4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawPath(Path()..moveTo(10.1, 8.7)..lineTo(15.6, 12)..lineTo(10.1, 15.3)..close(), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.spotify != spotify;
}
