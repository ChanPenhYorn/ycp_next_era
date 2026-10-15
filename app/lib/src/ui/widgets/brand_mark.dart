import 'package:flutter/material.dart';

/// The Chanpenh mark: a white "C" with a green bolt in its opening, on a blue
/// gradient tile. Drawn in code from the same geometry as `assets/brand/mark.svg`
/// so it stays sharp at any size and needs no image asset.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _BrandMarkPainter(),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  static const _canvas = Rect.fromLTWH(0, 0, 512, 512);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 512);

    canvas.drawRRect(
      RRect.fromRectAndRadius(_canvas, const Radius.circular(120)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D7BFF), Color(0xFF1F4BD0), Color(0xFF14206A)],
          stops: [0, 0.55, 1],
        ).createShader(_canvas),
    );

    const degrees = 3.14159265 / 180;
    final arc = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(256, 256), radius: 140),
        -50 * degrees,
        -260 * degrees,
      );
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 66
        ..color = Colors.white,
    );

    final bolt = Path()
      ..moveTo(352, 190)
      ..lineTo(298, 268)
      ..lineTo(328, 268)
      ..lineTo(312, 330)
      ..lineTo(366, 250)
      ..lineTo(336, 250)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5CF2B4), Color(0xFF17C07F)],
        ).createShader(const Rect.fromLTRB(298, 190, 366, 330)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
