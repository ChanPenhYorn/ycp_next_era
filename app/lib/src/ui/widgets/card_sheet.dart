import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../features/payments/domain/payment_entities.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// Hosted card checkout.
///
/// The URL comes from `dodo-checkout`, which holds the Dodo API key. This
/// widget opens it in another tab/window and polls `dodo-verify` while the
/// buyer pays. It never reads the browser's return URL as proof: the server
/// asks Dodo and settles the order.
class CardSheet extends ConsumerStatefulWidget {
  const CardSheet({required this.orderId, required this.checkout, super.key});

  final String orderId;
  final CardCheckout checkout;

  static Future<bool> show(
    BuildContext context, {
    required String orderId,
    required CardCheckout checkout,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CardSheet(orderId: orderId, checkout: checkout),
    );
    return result ?? false;
  }

  @override
  ConsumerState<CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends ConsumerState<CardSheet> {
  StreamSubscription<SettleResult>? _subscription;
  bool _opened = false;
  bool _openFailed = false;
  bool _finished = false;
  String _state = 'PENDING';

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Opening is a user gesture, so it happens from the button. Polling starts
  /// only after the tab is open: before that there is no payment to ask about.
  Future<void> _openCheckout() async {
    setState(() {
      _openFailed = false;
      _opened = true;
    });

    final ok = await launchUrl(
      widget.checkout.uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _openFailed = true;
        _opened = false;
      });
      return;
    }

    _startPolling();
  }

  void _startPolling() {
    if (_subscription != null) return;

    _subscription = ref
        .read(paymentRepositoryProvider)
        .pollCard(widget.orderId, deadline: widget.checkout.expiresAt)
        .listen(
          (result) {
            if (!mounted) return;

            setState(() => _state = result.state);

            if (result.ok) {
              Navigator.of(context).pop(true);
            } else if (result.isFinal) {
              Navigator.of(context).pop(false);
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _finished = true;
              _opened = false;
            });
          },
        );
  }

  String _statusText(AppL10n l10n) {
    if (_openFailed) return l10n.cardOpenFailed;
    if (_finished || DateTime.now().isAfter(widget.checkout.expiresAt)) {
      return l10n.cardExpired;
    }
    if (!_opened) return l10n.cardSheetIntro;
    return switch (_state) {
      'DECLINED' || 'CANCELLED' => l10n.cardDeclined,
      'EXPIRED' => l10n.cardExpired,
      'APPROVED' => l10n.cardPaid,
      _ => l10n.cardWaiting,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.cardSheetTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money(widget.checkout.totalUsd),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _statusText(l10n),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: _openFailed ? AppColors.danger : AppColors.ink300,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!_opened && !_finished)
            FilledButton.icon(
              onPressed: _openCheckout,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.cardOpenCheckout),
            )
          else if (_opened)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 10),
          Text(
            _state,
            style: const TextStyle(fontSize: 10, color: AppColors.ink400),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cart),
          ),
        ],
      ),
    );
  }
}
