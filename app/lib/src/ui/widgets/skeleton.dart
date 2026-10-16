import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme.dart';

/// A pulsing placeholder block. Shown while data loads so the page keeps its
/// shape instead of jumping from a spinner to content.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({this.height = 14, this.width, this.radius, super.key});

  final double height;
  final double? width;
  final double? radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.ink800,
          borderRadius: BorderRadius.circular(widget.radius ?? AppRadius.tile),
        ),
      ),
    );
  }
}

/// Stand-in for a list of cards, used by pages that show a stack of rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 3, this.itemHeight = 84, super.key});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          SkeletonBlock(height: itemHeight, radius: AppRadius.card),
          if (i < count - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Stand-in for the product grid, sized to match [ProductCardTile].
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: productGridDelegate,
      itemCount: count,
      itemBuilder: (context, index) => const _ProductCardSkeleton(),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: kProductArtRatio,
            child: ColoredBox(color: AppColors.ink850),
          ),
          // Flexible rather than fixed: the skeleton must fit whatever height the
          // grid gives it, so it can never overflow the way the real tile did.
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 10, width: 70),
                  SizedBox(height: 8),
                  SkeletonBlock(height: 13),
                  SizedBox(height: 6),
                  SkeletonBlock(height: 13, width: 110),
                  Spacer(),
                  SkeletonBlock(height: 16, width: 60),
                  SizedBox(height: 6),
                  SkeletonBlock(height: 10, width: 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Art is a fixed 4:3 box in every product tile. Everything under it is a text
/// block whose height does not scale with the column width.
const kProductArtRatio = 4 / 3;

/// How much room the text block under the art needs: padding, the category, a
/// two-line name, the price row and the stock row. Sized for the taller of the
/// two locales, because Khmer needs a bigger line box than Latin, so one grid
/// fits both.
const kProductTextBlockHeight = 122.0;

/// Sizes each product cell to its content: a 4:3 art box plus
/// [kProductTextBlockHeight].
///
/// A fixed `childAspectRatio` cannot work here. The art scales with the column
/// width but the text under it does not, so a ratio tuned for a wide column
/// clips the text in a narrow one, and the other way round. This is why the
/// skeleton used to overflow once the ratio was tightened.
class ProductGridDelegate extends SliverGridDelegate {
  const ProductGridDelegate({
    this.maxCrossAxisExtent = 220,
    this.spacing = 12,
    this.textBlockHeight = kProductTextBlockHeight,
  });

  final double maxCrossAxisExtent;
  final double spacing;
  final double textBlockHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = (constraints.crossAxisExtent / maxCrossAxisExtent)
        .ceil()
        .clamp(1, 8);
    final tileWidth =
        (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;

    // The art is measured inside the 1px border, so take that off first.
    final tileHeight = (tileWidth - 2) / kProductArtRatio + 2 + textBlockHeight;

    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: tileHeight + spacing,
      crossAxisStride: tileWidth + spacing,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant ProductGridDelegate oldDelegate) =>
      maxCrossAxisExtent != oldDelegate.maxCrossAxisExtent ||
      spacing != oldDelegate.spacing ||
      textBlockHeight != oldDelegate.textBlockHeight;
}

/// Shared by every product grid so home and the catalogue share one layout.
const productGridDelegate = ProductGridDelegate();
