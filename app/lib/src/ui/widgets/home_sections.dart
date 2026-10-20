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

/// The slim band at the top of home: what the store promises, the one action
/// that starts the funnel, and the trust claims under it.
///
/// This replaced a full-width gradient hero panel. That panel held a pill, a
/// heading, a subtitle and a button, left-aligned in a box up to 1140px wide, so
/// roughly 60% of it was bare gradient with a single orb parked off-panel. It was
/// also stacked directly above the spotlight, which is already a wide product
/// banner: two big panels, both mostly empty, before the first real game.
///
/// The pitch and the action moved here, and the trust claims came up from the row
/// that used to sit under the hero. The spotlight is now the page's one anchor.
/// Dropping the old panel also deleted its 7-second orb loop, which repainted two
/// large radial gradients every frame with no `RepaintBoundary`.
class HomeIntroBand extends StatelessWidget {
  const HomeIntroBand({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.ink800),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2B63), AppColors.ink900],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Text(
            l10n.heroTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          );

          final action = FilledButton.icon(
            onPressed: () => context.go('/products'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(l10n.heroCta),
          );

          // Side by side while there is room; stacked on a phone, where the
          // action would otherwise squeeze the heading to one word per line.
          // The action sitting opposite the heading is also what keeps the band
          // from having the hero's empty right half.
          final sideBySide = constraints.maxWidth >= 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sideBySide)
                Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: AppSpace.lg),
                    action,
                  ],
                )
              else ...[
                heading,
                const SizedBox(height: AppSpace.md),
                action,
              ],
              const SizedBox(height: AppSpace.sm),
              Text(l10n.heroSubtitle, style: AppType.bodySmall(context)),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final claim in <String>[
                    l10n.trustInstant,
                    l10n.trustPayment,
                    l10n.trustSupport,
                  ])
                    _TrustPill(label: claim),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One trust claim. Private because the band is the only place these appear, and
/// the claims are deliberately not repeated anywhere else on the page.
class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          // Flexible, or a claim longer than the available line overflows: the
          // Row cannot shrink a bare Text below its intrinsic width. Loose fit
          // keeps short labels snug and lets a long one wrap (or a Khmer label,
          // where every claim is longer, wrap rather than clip).
          Flexible(child: Text(label, style: AppType.caption(context))),
        ],
      ),
    );
  }
}

/// One category in the scroll row. Lifts the home chips off plain ActionChip
/// styling: neon border and a tight glow under the pointer, a physical press
/// on touch, and a real button semantic for screen readers.
class CategoryPill extends StatefulWidget {
  const CategoryPill({required this.category, super.key});

  final Category category;

  @override
  State<CategoryPill> createState() => _CategoryPillState();
}

class _CategoryPillState extends State<CategoryPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.category.name(
      Localizations.localeOf(context).languageCode,
    );

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(
            '/products?category=${Uri.encodeComponent(widget.category.slug)}',
          ),
          child: AnimatedScale(
            scale: _hovered ? 1.05 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.ease,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.ease,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _hovered ? AppColors.ink850 : AppColors.ink900,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: _hovered
                      ? AppColors.brand.withValues(alpha: 0.6)
                      : AppColors.ink700,
                ),
                boxShadow: _hovered ? AppGlow.tight(AppColors.brand) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _hovered ? Colors.white : AppColors.ink200,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
