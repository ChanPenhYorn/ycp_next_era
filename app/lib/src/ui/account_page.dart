import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/brand.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/order_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final profile = ref.watch(profileProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.accountTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        AsyncValueView(
          value: profile,
          onRetry: () => ref.invalidate(profileProvider),
          builder: (value) {
            if (value == null) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.ink900,
                    border: Border.all(color: AppColors.ink800),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.accountEmail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.ink400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isEmpty ? '—' : email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Stat(
                            label: l10n.walletBalance,
                            value: money(value.walletBalance),
                            onTap: () => context.go('/wallet'),
                          ),
                          const SizedBox(width: 10),
                          _Stat(label: l10n.coins, value: '${value.coins}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _TelegramCard(profile: value),
                if (value.isStaff) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin'),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(l10n.adminTitle),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(supabaseProvider).auth.signOut();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(Icons.logout, size: 18),
          label: Text(l10n.signOut),
        ),
        const SizedBox(height: 30),
        Center(
          child: Text(
            '${Brand.name} · ${Brand.displayName(Localizations.localeOf(context).languageCode)}',
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.ink850,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.ink400),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Telegram linking lives here because the bot is the only thing allowed to
/// write `telegram_chat_id`; the app only asks for a code and shows it.
class _TelegramCard extends ConsumerStatefulWidget {
  const _TelegramCard({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_TelegramCard> createState() => _TelegramCardState();
}

class _TelegramCardState extends ConsumerState<_TelegramCard> {
  TelegramLinkCode? _code;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final linked = widget.profile.telegramLinked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(
          color: linked
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.ink800,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                linked ? Icons.check_circle : Icons.telegram,
                size: 18,
                color: linked ? AppColors.accent : AppColors.brand,
              ),
              const SizedBox(width: 8),
              Text(
                linked ? l10n.telegramConnected : l10n.connectTelegram,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            linked && widget.profile.telegramUsername != null
                ? '@${widget.profile.telegramUsername}'
                : l10n.telegramHint,
            style: const TextStyle(fontSize: 12, color: AppColors.ink400),
          ),
          const SizedBox(height: 14),
          if (linked)
            Text(
              'Send /unlink in the chat to disconnect.',
              style: TextStyle(fontSize: 11, color: AppColors.ink400),
            )
          else if (_code == null)
            FilledButton.icon(
              onPressed: _busy ? null : _requestCode,
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.connectTelegram),
            )
          else
            _CodeBlock(code: _code!),
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    final l10n = AppL10n.of(context);
    setState(() => _busy = true);

    try {
      final code = await ref
          .read(orderRepositoryProvider)
          .createTelegramLinkCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _busy = false;
      });
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'auth_required'
                ? l10n.guestMustSignIn
                : l10n.telegramLinkFailed,
          ),
        ),
      );
    }
  }
}

class _CodeBlock extends ConsumerWidget {
  const _CodeBlock({required this.code});

  final TelegramLinkCode code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.telegramCodeHint,
          style: const TextStyle(fontSize: 11, color: AppColors.ink400),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.ink850,
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SelectableText(
                code.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.copyCode,
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code.code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (code.deepLink != null)
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(code.deepLink!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.openTelegram),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(profileProvider),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.telegramRefresh),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.telegramWait,
          style: const TextStyle(fontSize: 11, color: AppColors.ink400),
        ),
      ],
    );
  }
}
