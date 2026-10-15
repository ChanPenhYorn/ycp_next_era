import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Small helper so pages do not repeat the loading / error / data dance.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.ink900,
          border: Border.all(color: AppColors.ink800),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppL10n.of(context).somethingWentWrong,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(AppL10n.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
