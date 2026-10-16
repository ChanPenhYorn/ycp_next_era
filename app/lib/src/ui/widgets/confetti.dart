import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A one-shot confetti burst. Particles fall under their own gravity and fade
/// out, then the widget stops animating. It never repeats, so it cannot spin
/// forever in a test or burn frames once it is done.
class Confetti extends StatefulWidget {
  const Confetti({
    this.pieces = 70,
    this.duration = const Duration(seconds: 2),
    this.onDone,
    super.key,
  });

  final int pieces;
  final Duration duration;

  /// Called once the last piece has fallen.
  final VoidCallback? onDone;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Fixed seed so the burst looks the same every time and a golden image or a
  /// test can rely on it.
  late final List<_Piece> _pieces = _build(math.Random(7), widget.pieces);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Piece> _build(math.Random random, int count) {
    const palette = [
      AppColors.brand,
      AppColors.violet,
      AppColors.cyan,
      AppColors.pink,
      AppColors.accent,
      AppColors.warn,
    ];

    return List.generate(count, (index) {
      return _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        drift: (random.nextDouble() - 0.5) * 0.4,
        spin: (random.nextDouble() - 0.5) * 14,
        size: 5 + random.nextDouble() * 6,
        color: palette[random.nextInt(palette.length)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(pieces: _pieces, t: _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double delay;
  final double drift;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.t});

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      // Each piece waits its own turn, so the burst spreads out.
      final progress = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (progress <= 0) continue;

      final fall = Curves.easeIn.transform(progress);
      final x = (piece.x + piece.drift * progress) * size.width;
      final y = (-0.1 + fall * 1.15) * size.height;
      final opacity = progress < 0.15
          ? progress / 0.15
          : (1 - ((progress - 0.15) / 0.85)).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * progress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 1.6,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = piece.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// Drops a burst over the current screen and removes it when it finishes.
void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Confetti(
      key: const ValueKey('confetti'),
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}
