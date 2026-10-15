import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Home-page sections, kept out of `home_page.dart` so a widget test can pump
/// them at 320px on its own instead of booting the whole catalogue.

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, this.subtitle, super.key});

  final String title;
  final String? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (trailing != null)
              TextButton(
                onPressed: () => context.go('/products'),
                child: Text(trailing!, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink400),
            ),
          ),
      ],
    );
  }
}

/// The three steps `implement.md` §6 names.
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final steps = [
      (l10n.howStep1Title, l10n.howStep1Body),
      (l10n.howStep2Title, l10n.howStep2Body),
      (l10n.howStep3Title, l10n.howStep3Body),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.howItWorks),
        const SizedBox(height: 10),
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[i].$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink400,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < steps.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Support links come from `public_settings`, so an unconfigured store shows
/// nothing rather than a dead button.
class TrustAndSupportSection extends StatelessWidget {
  const TrustAndSupportSection({required this.settings, super.key});

  final PublicSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = [
      (
        Icons.inventory_2_outlined,
        l10n.trustDeliveryTitle,
        l10n.trustDeliveryBody,
      ),
      (
        Icons.verified_user_outlined,
        l10n.trustPaymentTitle,
        l10n.trustPaymentBody,
      ),
      (
        Icons.assignment_return_outlined,
        l10n.trustRefundTitle,
        l10n.trustRefundBody,
      ),
      (Icons.support_agent, l10n.trustSupportTitle, l10n.trustSupportBody),
    ];

    final telegram = settings.supportTelegram;
    final email = settings.supportEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.trustAndSupport),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink900,
            border: Border.all(color: AppColors.ink800),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(items[i].$1, size: 17, color: AppColors.accent),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].$2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$3,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.ink400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (i < items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 11),
                    child: Divider(height: 1),
                  ),
              ],
              if (telegram != null || email != null) ...[
                const SizedBox(height: 14),
                // Wrap, not Row: two buttons must not overflow at 320px.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (telegram != null && telegram.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(telegram),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.telegram, size: 17),
                        label: Text(l10n.contactSupport),
                      ),
                    if (email != null && email.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('mailto:$email')),
                        icon: const Icon(Icons.mail_outline, size: 17),
                        label: Text(email),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class TrustRow extends StatelessWidget {
  const TrustRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = [l10n.trustInstant, l10n.trustPayment, l10n.trustSupport];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.ink900,
              border: Border.all(color: AppColors.ink800),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(item, style: const TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
      ],
    );
  }
}
