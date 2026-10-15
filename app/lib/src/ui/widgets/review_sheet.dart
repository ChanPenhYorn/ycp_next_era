import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/order_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// Collects a rating and an optional comment for one delivered order line.
/// Returns true when the review was accepted.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({
    required this.productId,
    required this.orderId,
    required this.productName,
    super.key,
  });

  final int productId;
  final String orderId;
  final String productName;

  static Future<bool> show(
    BuildContext context, {
    required int productId,
    required String orderId,
    required String productName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReviewSheet(
        productId: productId,
        orderId: orderId,
        productName: productName,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final _body = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.writeReview,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.productName,
            style: const TextStyle(fontSize: 12, color: AppColors.ink400),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.reviewRating,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.warn,
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            maxLines: 3,
            maxLength: 400,
            decoration: InputDecoration(
              labelText: l10n.reviewBody,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.reviewSubmit),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reviewPending,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(orderRepositoryProvider).submitReview(
            productId: widget.productId,
            orderId: widget.orderId,
            rating: _rating,
            body: _body.text,
          );

      if (!mounted) return;
      // The button for this line disappears on the next read.
      ref.invalidate(reviewedProductsProvider(widget.orderId));
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reviewThanks)));
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error.code) {
          'review_exists' => l10n.reviewThanks,
          'auth_required' => l10n.guestMustSignIn,
          _ => l10n.reviewFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.reviewFailed;
      });
    }
  }
}
