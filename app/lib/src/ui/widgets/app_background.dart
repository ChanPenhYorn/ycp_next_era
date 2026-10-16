import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Soft coloured light behind the whole app. Two fixed radial washes, brand
/// blue top-left and violet top-right, so the dark base is never flat. Sits
/// behind the content and never scrolls with it.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: const _GlowPainter()),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _wash(
      canvas,
      center: Offset(size.width * 0.12, -size.height * 0.06),
      radius: size.width * 0.7,
      color: AppColors.brand,
      alpha: 0.20,
    );
    _wash(
      canvas,
      center: Offset(size.width * 0.92, size.height * 0.06),
      radius: size.width * 0.6,
      color: AppColors.violet,
      alpha: 0.16,
    );
  }

  void _wash(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}
