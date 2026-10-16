import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';
import 'app_background.dart';
import 'brand_mark.dart';
import 'search_field.dart';

/// Shared chrome. Wide screens get a full top bar with visible links and an
/// inline search; narrow screens keep the top bar slim and use bottom tabs.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _tabs = ['/', '/products', '/orders', '/account'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final index = _tabs.indexWhere(
      (tab) => tab == '/' ? location == '/' : location.startsWith(tab),
    );

    return Scaffold(
      backgroundColor: AppColors.ink950,
      appBar: AppBar(
        toolbarHeight: isWide ? 68 : 60,
        titleSpacing: isWide ? 24 : 16,
        backgroundColor: Colors.transparent,
        // Frosted glass: the glow washes behind the bar stay visible through it.
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink950.withValues(alpha: 0.72),
                border: const Border(
                  bottom: BorderSide(color: AppColors.ink800),
                ),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  const BrandMark(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    l10n.appTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: 28),
              for (var i = 0; i < _tabs.length; i++)
                _NavLink(
                  label: _labelFor(l10n, i),
                  selected: i == (index < 0 ? 0 : index),
                  onTap: () => context.go(_tabs[i]),
                ),
              const SizedBox(width: 24),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: GameSearchField(
                    hint: l10n.searchGames,
                    pill: true,
                    onSubmit: (value) {
                      final term = value.trim();
                      if (term.isEmpty) return;
                      context.go('/products?q=${Uri.encodeComponent(term)}');
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          const _CoinsChip(),
          const _LocaleButton(),
          const _CartButton(),
          if (isWide) const _AccountButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.ink800)),
                  ),
                  child: NavigationBar(
                    selectedIndex: index < 0 ? 0 : index,
                    onDestinationSelected: (value) => context.go(_tabs[value]),
                    backgroundColor: AppColors.ink950.withValues(alpha: 0.78),
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label: l10n.navHome,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.grid_view_outlined),
                        selectedIcon: const Icon(Icons.grid_view_rounded),
                        label: l10n.navGames,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.receipt_long_outlined),
                        selectedIcon: const Icon(Icons.receipt_long_rounded),
                        label: l10n.orders,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_outline_rounded),
                        selectedIcon: const Icon(Icons.person_rounded),
                        label: l10n.accountTitle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _labelFor(AppL10n l10n, int index) => switch (index) {
    0 => l10n.navHome,
    1 => l10n.navGames,
    2 => l10n.orders,
    _ => l10n.accountTitle,
  };
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : AppColors.ink400,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _CoinsChip extends ConsumerWidget {
  const _CoinsChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signed-out visitors have no balance, so the chip is not rendered at all
    // rather than showing a zero that means nothing.
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    return Tooltip(
      message: AppL10n.of(context).coins,
      child: InkWell(
        onTap: () => context.go('/wallet'),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.warn.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.warn.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 15,
                color: AppColors.warn,
              ),
              const SizedBox(width: 5),
              Text(
                '${profile.coins}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleButton extends ConsumerWidget {
  const _LocaleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final next = locale.languageCode == 'km' ? 'EN' : 'ខ្មែរ';

    return TextButton(
      onPressed: () => ref.read(localeControllerProvider.notifier).toggle(),
      style: TextButton.styleFrom(foregroundColor: AppColors.ink200),
      child: Text(
        next,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CartButton extends ConsumerWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: AppL10n.of(context).cart,
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => context.go('/cart'),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.ink950, width: 1.5),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signed-out visitors get the sign-in route instead of a dead account page.
    final signedIn = ref.watch(currentUserProvider) != null;

    return IconButton(
      tooltip: AppL10n.of(context).accountTitle,
      icon: const Icon(Icons.person_outline_rounded),
      onPressed: () => context.go(signedIn ? '/account' : '/login'),
    );
  }
}
