import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';
import 'motion.dart';
import 'product_art.dart';

/// How many top games the spotlight rotates through. Four is one loop in about
/// half a minute: enough to show the shelf has breadth, short enough that
/// nobody waits long to see the game they came for.
const spotlightSlides = 4;

/// Height of the spotlight panel at this width. Shared by the tile and the
/// carousel that wraps it, so the two cannot drift apart.
///
/// A [PageView] has to be bounded, so this is computed rather than measured.
/// Khmer's looser line box makes the two-line game name taller than the Latin
/// design assumed, so the panel is given that height back instead of
/// ellipsising the name.
double spotlightHeight(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final base = wide ? 260.0 : 200.0;
  final khmer = Localizations.localeOf(context).languageCode == 'km';
  return khmer ? base + (wide ? 40 : 26) : base;
}

/// The one big tile at the top of home. Full-bleed art, a gradient scrim, and
/// the price and action over it, so the first thing on the page is a game
/// rather than a row of text.
class SpotlightTile extends StatelessWidget {
  const SpotlightTile({required this.product, this.badge, super.key});

  final ProductCard product;

  /// Text in the top-left pill. Defaults to "Featured" for a curated slot; the
  /// home shelf passes its own heading so the label matches the section.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return PressScale(
      child: GestureDetector(
        onTap: () => context.go('/products/${product.slug}'),
        child: Container(
          height: spotlightHeight(context),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.hero),
            border: Border.all(color: AppColors.ink800),
            boxShadow: AppGlow.of(AppColors.violet, strength: 0.22, blur: 40),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A real banner (IGDB key art, mirrored by `game-banner`) is
              // already the right shape: show it sharp, full-bleed. The square
              // supplier art needs the blurred backdrop and a contained copy.
              if (product.bannerUrl != null)
                CachedNetworkImage(
                  imageUrl: product.bannerUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.medium,
                  placeholder: (_, _) =>
                      _SpotlightBackdrop(url: product.imageUrl),
                  errorWidget: (_, _, _) =>
                      _SpotlightBackdrop(url: product.imageUrl),
                )
              else ...[
                // Backdrop: the game's own art, blown up and blurred, so the
                // panel is a colour field drawn from the game itself. Without
                // it the uncropped art sat as a rectangle on one side of a
                // flat panel, with a hard vertical seam and dead space beside
                // it.
                _SpotlightBackdrop(url: product.imageUrl),
                // The art itself, uncropped, anchored right. Its left edge is
                // masked into the scrim, so the panel reads as one surface
                // instead of a photo pasted onto a card.
                if (product.imageUrl != null)
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.38, 0.62],
                    ).createShader(rect),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.medium,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
              ],
              // Darkens the left half so the copy always clears the art.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.ink950.withValues(alpha: 0.94),
                      AppColors.ink950.withValues(alpha: 0.62),
                      AppColors.ink950.withValues(alpha: 0.08),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              // A soft floor, so the bottom edge is not a flat line of art.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x40000000)],
                    stops: [0.72, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.brand, AppColors.violet],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        badge ?? l10n.featured,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Flexible, not a bare box: the panel height is fixed so the
                    // PageView stays bounded, and this is what stops a longer
                    // name from overflowing it.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 420 : 230),
                        child: Text(
                          product.name(locale),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: wide ? 30 : 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${l10n.from} ',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink400,
                          ),
                        ),
                        Text(
                          money(product.minPriceUsd),
                          style: TextStyle(
                            fontSize: wide ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/products/${product.slug}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(l10n.buyNow),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colour field behind the spotlight's art: the same image, upscaled and
/// blurred, over a brand gradient so a missing or very dark image still leaves
/// a lit panel.
///
/// Decoded small (`memCacheWidth`) on purpose: the blur throws the detail away,
/// and the source can be a 1200px poster that would otherwise be held in memory
/// at full size behind a 260px band.
class _SpotlightBackdrop extends StatelessWidget {
  const _SpotlightBackdrop({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F6B), AppColors.ink950],
        ),
      ),
    );
    if (url == null) return fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 32,
            sigmaY: 32,
            tileMode: ui.TileMode.clamp,
          ),
          // The blur is the expensive part; the layer is static per slide, so
          // keep it out of the carousel's repaint path.
          child: RepaintBoundary(
            child: CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              memCacheWidth: 240,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Keeps the blur from washing the copy out.
        const ColoredBox(color: Color(0x8C0B0F19)),
      ],
    );
  }
}

/// The big panel under the shelf heading, rotating through the top few games on
/// its own. A single static game made the store look like it sold one thing,
/// and that slot is the most valuable space on the page.
///
/// Auto-advance stops under a finger or a pointer and is switched off entirely
/// when the platform asks for reduced motion; it then becomes a swipeable page
/// view with dots and nothing moving by itself.
class SpotlightCarousel extends StatefulWidget {
  const SpotlightCarousel({required this.products, this.badge, super.key});

  final List<ProductCard> products;
  final String? badge;

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel> {
  final _page = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _reduce = false;

  /// Dwell per slide. Long enough to read the name and the price.
  static const _dwell = Duration(seconds: 6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce == _reduce && _timer != null) return;
    _reduce = reduce;
    _restart();
  }

  @override
  void didUpdateWidget(SpotlightCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length == widget.products.length) return;
    _index = _index.clamp(0, widget.products.length - 1);
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    // One slide, or a reduced-motion setting: nothing advances on its own.
    if (_reduce || widget.products.length < 2) return;
    _timer = Timer.periodic(_dwell, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _paused || !_page.hasClients) return;
    _page.animateToPage(
      (_index + 1) % widget.products.length,
      duration: AppMotion.slow,
      curve: AppMotion.ease,
    );
  }

  void _goTo(int index) {
    _page.animateToPage(index, duration: AppMotion.fast, curve: AppMotion.ease);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.products;
    if (slides.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: spotlightHeight(context),
          child: MouseRegion(
            onEnter: (_) => _paused = true,
            onExit: (_) => _paused = false,
            child: Listener(
              onPointerDown: (_) => _paused = true,
              onPointerUp: (_) => _paused = false,
              onPointerCancel: (_) => _paused = false,
              child: PageView.builder(
                controller: _page,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => Padding(
                  // A gap so the incoming slide reads as a separate card
                  // rather than a repaint of the same panel.
                  padding: EdgeInsets.only(right: slides.length > 1 ? 10 : 0),
                  child: SpotlightTile(
                    product: slides[index],
                    badge: widget.badge,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 12),
          // Dots in a glass pill, with a real tap target: a bare 6px dot is
          // both hard to see and nearly impossible to hit on touch.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink900.withValues(alpha: 0.72),
              border: Border.all(color: AppColors.ink800),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < slides.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _index,
                    label: slides[i].name(
                      Localizations.localeOf(context).languageCode,
                    ),
                    child: GestureDetector(
                      onTap: () => _goTo(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        curve: AppMotion.ease,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? AppColors.brand
                              : AppColors.ink700,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: i == _index
                              ? [
                                  BoxShadow(
                                    color: AppColors.brand.withValues(
                                      alpha: 0.55,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Games this buyer has ordered before, newest first. One tap back to the game
/// they already know. Hidden entirely for a signed-out visitor or a first
/// order, rather than showing an empty shelf.
class BuyAgainRow extends ConsumerWidget {
  const BuyAgainRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final orders = ref.watch(ordersProvider).valueOrNull;
    if (orders == null || orders.isEmpty) return const SizedBox.shrink();

    final catalogue = ref.watch(productsProvider(const ProductQuery()));
    final byId = <int, ProductCard>{
      for (final product in catalogue.valueOrNull ?? const <ProductCard>[])
        product.id: product,
    };

    final seen = <int>{};
    final recent = <ProductCard>[];
    for (final order in orders) {
      for (final line in order.items) {
        final id = line.productId;
        if (id == null || !seen.add(id)) continue;
        final product = byId[id];
        if (product != null) recent.add(product);
        if (recent.length == 6) break;
      }
      if (recent.length == 6) break;
    }

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.buyAgain, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = recent[index];

              return PressScale(
                child: GestureDetector(
                  onTap: () => context.go('/products/${product.slug}'),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.ink900,
                      border: Border.all(color: AppColors.ink800),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: product.imageUrl == null
                                ? const ProductArtFallback()
                                : CachedNetworkImage(
                                    imageUrl: product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const ProductArtFallback(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.name(
                                  Localizations.localeOf(context).languageCode,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                money(product.minPriceUsd),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.replay_rounded,
                          size: 16,
                          color: AppColors.ink400,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// What is actually selling, from the real `sold_count` on each product. This
/// is a ranking, not a live feed: the store exposes no recent-purchase stream,
/// so nothing here claims to be happening right now.
///
/// The strip drifts on its own, marquee-style, and pauses under a finger or a
/// pointer. A reduced-motion setting switches the drift off and leaves an
/// ordinary scrollable list.
class TrendingTicker extends StatefulWidget {
  const TrendingTicker({required this.products, super.key});

  final List<ProductCard> products;

  @override
  State<TrendingTicker> createState() => _TrendingTickerState();
}

class _TrendingTickerState extends State<TrendingTicker>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_onTick);
  Duration? _last;
  bool _paused = false;

  /// Drift speed in logical pixels per second: slow enough to read, fast
  /// enough to notice.
  static const _speed = 26.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      if (_ticker.isActive) _ticker.stop();
      // Drop the carried timestamp, or the first frame after a resume would
      // apply the whole paused gap as one jump.
      _last = null;
    } else if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  void _onTick(Duration now) {
    final dt = now - (_last ?? now);
    _last = now;
    if (_paused || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    // The list holds two copies of the same items, so wrapping after one
    // copy-width is a seamless loop.
    final copyWidth =
        (position.maxScrollExtent + position.viewportDimension) / 2;
    var next = position.pixels + dt.inMicroseconds / 1e6 * _speed;
    if (next >= copyWidth) next -= copyWidth;
    _scroll.jumpTo(next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final selling = widget.products.where((p) => p.soldCount > 0).toList()
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final top = selling.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final loop = [...top, ...top];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: AppGlow.tight(AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.trendingNow,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _paused = true),
              onExit: (_) => setState(() => _paused = false),
              child: Listener(
                onPointerDown: (_) => setState(() => _paused = true),
                onPointerUp: (_) => setState(() => _paused = false),
                onPointerCancel: (_) => setState(() => _paused = false),
                child: SizedBox(
                  height: 26,
                  // Duplicated names would be read out twice; the visible
                  // label beside the strip already says what this is.
                  child: ExcludeSemantics(
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: loop.length,
                      separatorBuilder: (_, _) => const VerticalDivider(
                        width: 18,
                        thickness: 1,
                        color: AppColors.ink800,
                      ),
                      itemBuilder: (context, index) {
                        final product = loop[index];
                        final rank = (index % top.length) + 1;

                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RankChip(rank),
                              const SizedBox(width: 6),
                              Text(
                                '${product.name(locale)} · '
                                '${compactCount(product.soldCount)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.ink200,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The position badge in the ticker. The top three get the house gradient;
/// the rest stay quiet so the podium actually reads as a podium.
class _RankChip extends StatelessWidget {
  const _RankChip(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.ink400,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.violet],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppGlow.tight(AppColors.violet),
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
