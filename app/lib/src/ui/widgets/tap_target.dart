import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Enforces a real tap target and a screen-reader label.
///
/// Two problems this exists to stop: icon buttons smaller than 44x44, and tiles
/// built as bare `GestureDetector`s that were invisible to assistive tech. Build
/// anything tappable through here and neither can come back.
///
/// When [label] is null the child's own text is announced, which is right for a
/// tile whose name and price already read well. Pass a label when the child is
/// an icon, a glyph, or a colour.
class TapTarget extends StatelessWidget {
  const TapTarget({
    required this.child,
    this.label,
    this.onTap,
    this.onLongPress,
    this.minSize = 44,
    this.borderRadius,
    this.cursor = SystemMouseCursors.click,
    super.key,
  });

  final Widget child;

  /// Screen-reader text. Null means the child announces itself.
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Minimum hit box. Set to 0 for a target that is deliberately smaller but
  /// still labelled, such as a footnote link.
  final double minSize;
  final BorderRadius? borderRadius;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.control);
    final interactive = onTap != null || onLongPress != null;

    Widget content = child;
    if (interactive) {
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: content,
      );
    }

    if (minSize > 0) {
      content = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: content,
      );
    }

    return Semantics(
      container: true,
      button: interactive,
      label: label,
      child: MouseRegion(
        cursor: interactive ? cursor : MouseCursor.defer,
        child: content,
      ),
    );
  }
}
