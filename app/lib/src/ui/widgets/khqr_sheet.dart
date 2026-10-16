import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../features/payments/domain/payment_entities.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// Native KHQR sheet.
///
/// The QR string comes from the `payway-init` Edge Function, which holds the
/// PayWay API key. This widget renders it and polls `payway-verify`; it never
/// sees a secret and never decides on its own that a payment succeeded.
class KhqrSheet extends ConsumerStatefulWidget {
  const KhqrSheet({required this.orderId, required this.payment, super.key});

  final String orderId;
  final KhqrPayment payment;

  static Future<bool> show(
    BuildContext context, {
    required String orderId,
    required KhqrPayment payment,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => KhqrSheet(orderId: orderId, payment: payment),
    );
    return result ?? false;
  }

  @override
  ConsumerState<KhqrSheet> createState() => _KhqrSheetState();
}

class _KhqrSheetState extends ConsumerState<KhqrSheet> {
  StreamSubscription<SettleResult>? _subscription;
  Timer? _ticker;
  String _state = 'PENDING';
  String? _failure;

  @override
  void initState() {
    super.initState();
    _startPolling();
    // Repaints the countdown once a second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startPolling() {
    _subscription?.cancel();
    _subscription = ref
        .read(paymentRepositoryProvider)
        .poll(widget.orderId, deadline: widget.payment.expiresAt)
        .listen((result) {
          if (!mounted) return;

          setState(() {
            _state = result.state;
            _failure = result.reason;
          });

          if (result.ok) {
            Navigator.of(context).pop(true);
          } else if (result.isFinal) {
            Navigator.of(context).pop(false);
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final remaining = widget.payment.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;

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
            l10n.scanQr,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money(widget.payment.totalUsd),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: widget.payment.qrString,
              size: 232,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            expired
                ? l10n.khqrExpired
                : '${l10n.waitingPayment}  ${_formatRemaining(remaining)}',
            style: TextStyle(
              fontSize: 12,
              color: expired ? AppColors.danger : AppColors.ink400,
            ),
          ),
          if (_failure != null && expired) ...[
            const SizedBox(height: 4),
            Text(
              _failure!,
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
          ],
          const SizedBox(height: 18),
          if (widget.payment.deepLink != null)
            OutlinedButton.icon(
              onPressed: () => _openAba(widget.payment.deepLink!),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.openAbaMobile),
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

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _openAba(String deepLink) async {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
