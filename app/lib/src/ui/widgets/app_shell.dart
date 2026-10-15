import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// Shared chrome: top bar with search + locale toggle + cart badge, and a
/// bottom navigation bar on narrow screens.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    // Four tabs, as `implement.md` §5 names them. The cart keeps its home in
    // the app bar, and the wallet is reached from Account, so neither is lost
    // by dropping it from here.
    const tabs = ['/', '/products', '/orders', '/account'];
    final index = tabs.indexWhere(
      (tab) => tab == '/' ? location == '/' : location.startsWith(tab),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                Brand.monogram,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.appTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.searchHint,
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(context),
          ),
          const _LocaleButton(),
          const _CartButton(),
          const _AccountButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (value) => context.go(tabs[value]),
              backgroundColor: AppColors.ink900,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_outlined),
                  selectedIcon: const Icon(Icons.grid_view),
                  label: l10n.navGames,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: l10n.orders,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.accountTitle,
                ),
              ],
            ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final controller = TextEditingController();
    final term = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink900,
        title: Text(AppL10n.of(context).searchHint),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppL10n.of(context).searchHint),
          ),
        ],
      ),
    );

    if (term != null && term.trim().isNotEmpty && context.mounted) {
      context.go('/products?q=${Uri.encodeComponent(term.trim())}');
    }
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
      child: Text(next, style: const TextStyle(fontSize: 12)),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(9),
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
      icon: const Icon(Icons.person_outline),
      onPressed: () => context.go(signedIn ? '/account' : '/login'),
    );
  }
}
