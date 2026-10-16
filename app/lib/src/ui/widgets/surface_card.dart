import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The one card surface: dark fill, hairline border, shared radius. Pages build
/// their blocks from it so they read as one family. Pass [onTap] to make the
/// whole card tappable with an ink ripple.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: borderColor ?? AppColors.ink800),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
