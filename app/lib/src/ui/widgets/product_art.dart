import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// What a product looks like before it has art, or when the art will not load.
///
/// A blank box reads as a broken page, and an icon tile reads as an unfinished
/// catalogue. This draws the product's own name on the house gradient instead,
/// which is what the customer came for anyway.
///
/// The demo products in `supabase/seed/demo.sql` have no art on purpose: a
/// bundled image would be dead weight for four rows, and a hotlinked one would
/// break the day the third party moved it.
class ProductArtFallback extends StatelessWidget {
  const ProductArtFallback({this.name, super.key});

  /// Shown when there is room for it. A 50x50 thumbnail falls back to the icon.
  final String? name;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 72 && constraints.maxHeight >= 60;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.ink800, AppColors.ink950],
            ),
          ),
          child: Center(
            child: roomy && name != null
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.brand, AppColors.violet],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: Text(
                            name!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.ink200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Icon(
                    Icons.sports_esports_outlined,
                    size: roomy ? 44 : 18,
                    color: AppColors.ink400,
                  ),
          ),
        );
      },
    );
  }
}
