import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Scales the child down while pressed, back up on release. Gives a tap a
/// physical feel without a full ink ripple.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.scale = 0.96, super.key});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        child: widget.child,
      ),
    );
  }
}

/// Fades and lifts a child into place, delayed by its position in the list.
/// Used so a grid arrives in sequence instead of all at once.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.maxDelay = const Duration(milliseconds: 400),
    super.key,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration maxDelay;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.step * widget.index;
    final wait = delay > widget.maxDelay ? widget.maxDelay : delay;
    Future<void>.delayed(wait, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.ease);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
