import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';
import 'brand_mark.dart';

/// Site footer: identity, the tagline, and the links a buyer actually needs.
class StoreFooter extends ConsumerWidget {
  const StoreFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final telegram = ref.watch(settingsProvider).valueOrNull?.supportTelegram;
    final tagline = locale == 'km' ? Brand.taglineKm : Brand.taglineEn;

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Brand.displayName(locale),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            l10n.aboutText,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.ink400,
              height: 1.6,
            ),
          ),
        ),
      ],
    );

    final links = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickLinks,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _FooterLink(
          label: l10n.allProducts,
          onTap: () => context.go('/products'),
        ),
        _FooterLink(label: l10n.orders, onTap: () => context.go('/orders')),
        _FooterLink(
          label: l10n.accountTitle,
          onTap: () => context.go('/account'),
        ),
        if (telegram != null && telegram.isNotEmpty)
          _FooterLink(
            label: l10n.contact,
            onTap: () => launchUrl(
              Uri.parse(telegram),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ink800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                links,
              ],
            )
          else ...[
            identity,
            const SizedBox(height: 24),
            links,
          ],
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} ${Brand.displayName(locale)} · ${l10n.rights}',
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.ink400),
        ),
      ),
    );
  }
}
